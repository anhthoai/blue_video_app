import { Request, Response } from 'express';
import { ContentSource } from '@prisma/client';
import axios from 'axios';
import { pipeline } from 'stream';
import http from 'http';
import https from 'https';
import prisma from '../lib/prisma';
import { StorageService } from '../config/storage';
import { getUlozService, getUlozStorageConfig, resolveUlozStorageId } from '../services/ulozRegistry';

const MAX_PAGE_SIZE = 200;
const MAX_VIDEO_FEED_PAGE_SIZE = 120;
const LIBRARY_VIDEO_EXTENSIONS = ['mp4', 'm4v', 'mkv', 'mov', 'webm', 'avi'];
const LIBRARY_VIDEO_EXTENSION_VARIANTS = Array.from(
  new Set(
    LIBRARY_VIDEO_EXTENSIONS.flatMap((extension) => [
      extension,
      extension.toUpperCase(),
    ])
  )
);
const LIBRARY_ITEM_BASE_SELECT = {
  id: true,
  title: true,
  description: true,
  contentType: true,
  section: true,
  isFolder: true,
  extension: true,
  fileSize: true,
  fileUrl: true,
  ulozStorageId: true,
  filePath: true,
  slugPath: true,
  parentId: true,
  thumbnailUrl: true,
  coverUrl: true,
  videoPreviewUrl: true,
  mimeType: true,
  duration: true,
  metadata: true,
  source: true,
  ulozSlug: true,
  author: true,
  views: true,
  downloads: true,
  updatedAt: true,
  createdAt: true,
} as const;

// Keep-alive agents for upstream CDN requests.
// mpv/libmpv tends to issue many Range requests; reusing connections reduces TLS overhead.
const upstreamHttpAgent = new http.Agent({
  keepAlive: true,
  maxSockets: 50,
  keepAliveMsecs: 15_000,
});
const upstreamHttpsAgent = new https.Agent({
  keepAlive: true,
  maxSockets: 50,
  keepAliveMsecs: 15_000,
});

function guessMimeTypeFromExtension(extension: string | null | undefined): string | null {
  const ext = (extension || '').toString().trim().toLowerCase().replace(/^\./, '');
  if (!ext) return null;
  const map: Record<string, string> = {
    mp4: 'video/mp4',
    m4v: 'video/x-m4v',
    mov: 'video/quicktime',
    mkv: 'video/x-matroska',
    webm: 'video/webm',
    avi: 'video/x-msvideo',
    mp3: 'audio/mpeg',
    aac: 'audio/aac',
    m4a: 'audio/mp4',
    wav: 'audio/wav',
    flac: 'audio/flac',
    srt: 'application/x-subrip',
    vtt: 'text/vtt',
    pdf: 'application/pdf',
    epub: 'application/epub+zip',
    jpg: 'image/jpeg',
    jpeg: 'image/jpeg',
    png: 'image/png',
    webp: 'image/webp',
    gif: 'image/gif',
  };
  return map[ext] || null;
}

function pickBestMimeType(item: { mimeType?: string | null; extension?: string | null }): string {
  const mt = (item.mimeType || '').toString().trim();
  if (mt && mt.includes('/')) {
    return mt;
  }
  const guessed = guessMimeTypeFromExtension(item.extension);
  return guessed || 'application/octet-stream';
}

function normalizeSection(sectionParam: string | undefined | null): string | null {
  if (!sectionParam || typeof sectionParam !== 'string') {
    return null;
  }

  const trimmed = sectionParam.trim();
  if (trimmed.length === 0) {
    return null;
  }

  return trimmed.toLowerCase();
}

async function resolveMediaUrl(url?: string | null): Promise<string | null> {
  if (!url) {
    return null;
  }

  if (url.startsWith('s3://')) {
    try {
      return await StorageService.getSignedUrl(url);
    } catch (error) {
      console.warn(`⚠️  Failed to generate signed URL for ${url}:`, (error as Error).message);
      return null;
    }
  }

  return url;
}

function buildProxyCdnUrl(baseUrl: string, filePath: string): string {
  const base = String(baseUrl || '').trim().replace(/\/+$/g, '');
  const rawPath = String(filePath || '')
    .trim()
    .replace(/\\/g, '/')
    .replace(/^\/+/, '');

  const encodedPath = rawPath
    .split('/')
    .filter(Boolean)
    .map((segment) => encodeURIComponent(segment))
    .join('/');

  return `${base}/${encodedPath}`;
}

function wantsBackendProxy(req?: Request): boolean {
  if (!req) return false;
  const streamMode = String(req.query['streamMode'] ?? '').toLowerCase();
  if (streamMode === 'proxy') return true;

  const proxy = String(req.query['proxy'] ?? '').toLowerCase();
  if (proxy === '1' || proxy === 'true' || proxy === 'yes') return true;

  return false;
}

function buildPublicUrl(req: Request, path: string): string {
  const host = req.get('host');
  if (!host) {
    return path;
  }
  const base = `${req.protocol}://${host}`;
  return `${base}${path.startsWith('/') ? '' : '/'}${path}`;
}

async function resolveFileStreamUrl(item: {
  id?: string | null;
  fileUrl?: string | null;
  filePath?: string | null;
  isFolder?: boolean | null;
  source: ContentSource;
  ulozStorageId?: number | null;
  ulozSlug?: string | null;
  metadata?: any;
}, req?: Request): Promise<string | null> {
  const { id, fileUrl, filePath, isFolder, source, ulozStorageId, ulozSlug, metadata } = item;

  // Handle S3 stored content
  if (fileUrl?.startsWith('s3://')) {
    try {
      return await StorageService.getSignedUrl(fileUrl);
    } catch (error) {
      console.warn(`⚠️  Failed to generate signed URL for ${fileUrl}:`, (error as Error).message);
      return null;
    }
  }

  // Handle uloz.to proxy CDN content (skip uloz stream API entirely)
  if (source === ContentSource.ULOZ && filePath && !isFolder) {
    const resolvedUlozStorageId =
      typeof ulozStorageId === 'number' && ulozStorageId > 0 ? ulozStorageId : resolveUlozStorageId(req);
    const cfg = getUlozStorageConfig(resolvedUlozStorageId);
    if (cfg.proxyCdnUrl) {
      if (req && id && wantsBackendProxy(req)) {
        return buildPublicUrl(req, `/api/v1/library/item/${encodeURIComponent(id)}/stream`);
      }
      return buildProxyCdnUrl(cfg.proxyCdnUrl, filePath);
    }
  }

  // If metadata already contains a stream/download URL, use it
  const metadataUrl =
    (metadata && typeof metadata === 'object'
      ? metadata.streamUrl ||
        metadata.downloadUrl ||
        metadata.directUrl ||
        metadata.direct_link
      : null) ?? null;
  if (metadataUrl && typeof metadataUrl === 'string' && metadataUrl.length > 4) {
    return metadataUrl;
  }

  // Handle uloz.to content
  if (source === ContentSource.ULOZ) {
    const resolvedUlozStorageId =
      typeof ulozStorageId === 'number' && ulozStorageId > 0 ? ulozStorageId : resolveUlozStorageId(req);
    const ulozService = getUlozService(resolvedUlozStorageId);
    const candidate = ulozSlug || fileUrl || metadataUrl;
    if (candidate) {
      try {
        const streamUrl = await ulozService.getStreamUrl(candidate);
        if (streamUrl) {
          return streamUrl;
        }
      } catch (error) {
        console.warn(
          `⚠️  Failed to fetch uloz stream URL for ${candidate}:`,
          (error as Error).message
        );
      }
    }
  }

  // If already an accessible URL, return as-is
  if (fileUrl && /^https?:\/\//i.test(fileUrl)) {
    return fileUrl;
  }

  return null;
}

async function buildBreadcrumbs(item: {
  id: string;
  parentId: string | null;
}) {
  const breadcrumbs: Array<{ id: string; title: string; filePath: string | null }> = [];
  let currentParentId: string | null = item.parentId;

  while (currentParentId) {
    const parent = await prisma.libraryContent.findUnique({
      where: { id: currentParentId },
      select: {
        id: true,
        title: true,
        filePath: true,
        parentId: true,
      },
    });

    if (!parent) {
      break;
    }

    breadcrumbs.unshift({
      id: parent.id,
      title: parent.title,
      filePath: parent.filePath,
    });

    currentParentId = parent.parentId;
  }

  return breadcrumbs;
}

function normalizeLibraryVideoSort(sortByParam: unknown): string {
  const value = String(sortByParam || '').trim().toLowerCase();
  switch (value) {
    case 'trending':
    case 'toprated':
    case 'mostviewed':
    case 'random':
    case 'newest':
      return value;
    default:
      return 'newest';
  }
}

function parseDurationCandidate(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) {
    if (value <= 0) {
      return null;
    }

    if (value > 1000 * 60 * 60 * 24) {
      return Math.round(value / 1000);
    }

    return Math.round(value);
  }

  if (typeof value !== 'string') {
    return null;
  }

  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }

  const hhmmssMatch = trimmed.match(/^(\d+):(\d{1,2})(?::(\d{1,2}))?$/);
  if (hhmmssMatch) {
    const first = parseInt(hhmmssMatch[1] || '0', 10);
    const second = parseInt(hhmmssMatch[2] || '0', 10);
    const third = parseInt(hhmmssMatch[3] || '0', 10);
    if (hhmmssMatch[3] != null) {
      return first * 3600 + second * 60 + third;
    }
    return first * 60 + second;
  }

  const numeric = Number(trimmed.replace(/s$/i, ''));
  if (!Number.isFinite(numeric) || numeric <= 0) {
    return null;
  }

  if (numeric > 1000 * 60 * 60 * 24) {
    return Math.round(numeric / 1000);
  }

  return Math.round(numeric);
}

function normalizeLibraryDuration(
  duration: unknown,
  metadata: unknown,
): number | null {
  const objectMetadata =
    metadata && typeof metadata === 'object'
      ? (metadata as Record<string, unknown>)
      : null;

  const primary = parseDurationCandidate(duration);
  const metadataCandidates = [
    objectMetadata?.['durationSeconds'],
    objectMetadata?.['videoDurationSeconds'],
    objectMetadata?.['duration'],
    objectMetadata?.['videoDuration'],
    objectMetadata?.['mediaDuration'],
    objectMetadata?.['durationMs'],
    objectMetadata?.['videoDurationMs'],
    objectMetadata?.['runtime'],
    objectMetadata?.['length'],
    objectMetadata?.['ffprobeDuration'],
    objectMetadata?.['formattedDuration'],
  ]
    .map(parseDurationCandidate)
    .filter((value): value is number => value != null && value > 0);

  if (primary != null && primary !== 43201) {
    return primary;
  }

  const alternative = metadataCandidates.find((value) => value !== 43201);
  if (alternative != null) {
    return alternative;
  }

  if (primary === 43201) {
    return null;
  }

  return primary;
}

function buildLibraryVideoWhere(section?: string | null): Record<string, any> {
  const whereClause: Record<string, any> = {
    isAvailable: true,
    isFolder: false,
    OR: [
      {
        contentType: {
          contains: 'video',
          mode: 'insensitive',
        },
      },
      {
        mimeType: {
          startsWith: 'video/',
          mode: 'insensitive',
        },
      },
      {
        extension: {
          in: LIBRARY_VIDEO_EXTENSION_VARIANTS,
        },
      },
    ],
  };

  if (section) {
    whereClause['section'] = section;
  }

  return whereClause;
}

function buildLibraryVideoOrderBy(sortBy: string): Array<Record<string, 'asc' | 'desc'>> {
  switch (sortBy) {
    case 'trending':
      return [
        { views: 'desc' },
        { downloads: 'desc' },
        { updatedAt: 'desc' },
      ];
    case 'mostviewed':
      return [
        { views: 'desc' },
        { updatedAt: 'desc' },
      ];
    case 'toprated':
      return [
        { downloads: 'desc' },
        { views: 'desc' },
        { updatedAt: 'desc' },
      ];
    case 'random':
      return [
        { updatedAt: 'desc' },
        { createdAt: 'desc' },
      ];
    case 'newest':
    default:
      return [
        { updatedAt: 'desc' },
        { createdAt: 'desc' },
      ];
  }
}

async function serializeLibraryItem(
  item: any,
  req: Request,
  options: {
    includeStreams: boolean;
    includeChildrenCount?: boolean;
  },
) {
  const thumbnailUrl = item.thumbnailUrl?.startsWith('s3://')
    ? await resolveMediaUrl(item.thumbnailUrl)
    : item.thumbnailUrl;

  const coverUrl = item.coverUrl?.startsWith('s3://')
    ? await resolveMediaUrl(item.coverUrl)
    : item.coverUrl;

  const videoPreviewUrl = item.videoPreviewUrl?.startsWith('s3://')
    ? await resolveMediaUrl(item.videoPreviewUrl)
    : item.videoPreviewUrl;

  const streamUrl = options.includeStreams
    ? await resolveFileStreamUrl(
        {
          id: item.id,
          fileUrl: item.fileUrl,
          filePath: item.filePath,
          isFolder: item.isFolder,
          source: item.source,
          ulozStorageId: item.ulozStorageId,
          ulozSlug: item.ulozSlug ?? null,
          metadata: item.metadata ?? undefined,
        },
        req,
      )
    : null;

  const mergedMetadata =
    item.metadata && typeof item.metadata === 'object'
      ? { ...(item.metadata as Record<string, unknown>) }
      : {};

  if (typeof item.author === 'string' && item.author.trim().length > 0) {
    mergedMetadata['author'] = mergedMetadata['author'] ?? item.author;
  }
  if (typeof item.views === 'number') {
    mergedMetadata['viewCount'] = mergedMetadata['viewCount'] ?? item.views;
    mergedMetadata['views'] = mergedMetadata['views'] ?? item.views;
  }
  if (typeof item.downloads === 'number') {
    mergedMetadata['downloadCount'] =
      mergedMetadata['downloadCount'] ?? item.downloads;
    mergedMetadata['downloads'] = mergedMetadata['downloads'] ?? item.downloads;
  }

  return {
    id: item.id,
    title: item.title,
    description: item.description,
    contentType: item.contentType,
    section: item.section,
    isFolder: item.isFolder,
    extension: item.extension,
    fileSize: item.fileSize ? Number(item.fileSize) : null,
    fileUrl: item.fileUrl,
    streamUrl,
    filePath: item.filePath,
    slugPath: item.slugPath,
    mimeType: item.mimeType,
    duration: normalizeLibraryDuration(item.duration, item.metadata),
    metadata: mergedMetadata,
    thumbnailUrl,
    coverUrl,
    videoPreviewUrl,
    source: item.source,
    ulozSlug: item.ulozSlug,
    hasChildren: options.includeChildrenCount ? item._count.children > 0 : false,
    createdAt: item.createdAt,
    updatedAt: item.updatedAt,
  };
}

export async function listLibrarySections(_req: Request, res: Response) {
  try {
    const grouped = await prisma.libraryContent.groupBy({
      by: ['section'],
      where: {
        section: {
          not: null,
        },
      },
      _count: {
        section: true,
      },
    });

    const sectionSummaries = grouped
      .map((group) => {
        const section = (group.section || '').toString().toLowerCase();
        return {
          section,
          totalItems: group._count.section,
        };
      })
      .sort((a, b) => a.section.localeCompare(b.section));

    res.json({
      success: true,
      data: sectionSummaries,
    });
  } catch (error: any) {
    console.error('Error listing library sections:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to load library sections',
      error: error.message,
    });
  }
}

export async function listLibraryItems(req: Request, res: Response) {
  try {
    const section = normalizeSection(req.params['section']);
    if (!section) {
      res.status(400).json({
        success: false,
        message: 'Invalid library section',
      });
      return;
    }

    const parentIdParam = (req.query['parentId'] as string) || null;
    const pathParam = (req.query['path'] as string) || null;

    let parentId: string | null = null;
    let parentItem: { id: string; title: string; parentId: string | null; filePath: string | null } | null = null;

    if (parentIdParam) {
      const parent = await prisma.libraryContent.findUnique({
        where: { id: parentIdParam },
        select: {
          id: true,
          title: true,
          parentId: true,
          filePath: true,
          section: true,
        },
      });

      if (!parent || (parent.section || '').toLowerCase() !== section) {
        res.status(404).json({
          success: false,
          message: 'Parent folder not found in this section',
        });
        return;
      }

      parentId = parent.id;
      parentItem = parent;
    } else if (pathParam) {
      const parent = await prisma.libraryContent.findFirst({
        where: {
          section,
          filePath: pathParam,
        },
        select: {
          id: true,
          title: true,
          parentId: true,
          filePath: true,
        },
      });

      if (!parent) {
        res.status(404).json({
          success: false,
          message: 'Folder path not found',
        });
        return;
      }

      parentId = parent.id;
      parentItem = parent;
    }

    if (!parentId) {
      const rootFolder = await prisma.libraryContent.findFirst({
        where: {
          section,
          parentId: null,
          isFolder: true,
        },
        select: {
          id: true,
          title: true,
          parentId: true,
          filePath: true,
        },
      });

      if (rootFolder) {
        parentId = rootFolder.id;
        parentItem = rootFolder;
      }
    }

    const page = Math.max(1, parseInt((req.query['page'] as string) || '1', 10));
    const limit = Math.min(
      MAX_PAGE_SIZE,
      Math.max(1, parseInt((req.query['limit'] as string) || '50', 10))
    );
    const skip = (page - 1) * limit;
    const includeStreams =
      (req.query['includeStreams'] as string | undefined)?.toLowerCase() === 'true';
    const search = (req.query['search'] as string) || null;

    const whereClause: Record<string, any> = {
      section,
    };

    // If searching, don't filter by parentId (search across all items in section)
    // Otherwise, filter by parentId to show items in the current folder
    if (!search || !search.trim()) {
      // Only add parentId filter if it's not null
      // If parentId is null, we want items with parentId = null (root level)
      whereClause['parentId'] = parentId;
    } else {
      // When searching, add search filter
      const searchTerm = search.trim();
      whereClause['OR'] = [
        { title: { contains: searchTerm, mode: 'insensitive' } },
        { filePath: { contains: searchTerm, mode: 'insensitive' } },
      ];
    }

    const [items, total] = await Promise.all([
      prisma.libraryContent.findMany({
        where: whereClause,
        orderBy: [
          { isFolder: 'desc' },
          { title: 'asc' },
        ],
        skip,
        take: limit,
        select: {
          ...LIBRARY_ITEM_BASE_SELECT,
          _count: {
            select: {
              children: true,
            },
          },
        },
      }),
      prisma.libraryContent.count({
        where: whereClause,
      }),
    ]);

    const resolvedItems = await Promise.all(
      items.map((item) =>
        serializeLibraryItem(item, req, {
          includeStreams,
          includeChildrenCount: true,
        })
      )
    );

    const breadcrumbs = parentItem
      ? await buildBreadcrumbs(parentItem)
      : [];

    res.json({
      success: true,
      data: {
        section,
        parent: parentItem
          ? {
            id: parentItem.id,
            title: parentItem.title,
            filePath: parentItem.filePath,
          }
          : null,
        breadcrumbs,
        pagination: {
          page,
          limit,
          total,
          totalPages: Math.ceil(total / limit),
        },
        items: resolvedItems,
      },
    });
  } catch (error: any) {
    console.error('Error listing library items:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to load library items',
      error: error.message,
    });
  }
}

export async function listLibraryVideoFeed(req: Request, res: Response) {
  try {
    const section = normalizeSection((req.query['section'] as string) || null);
    const sortBy = normalizeLibraryVideoSort(req.query['sortBy']);
    const page = Math.max(1, parseInt((req.query['page'] as string) || '1', 10));
    const limit = Math.min(
      MAX_VIDEO_FEED_PAGE_SIZE,
      Math.max(1, parseInt((req.query['limit'] as string) || '60', 10))
    );
    const skip = (page - 1) * limit;
    const includeStreams =
      (req.query['includeStreams'] as string | undefined)?.toLowerCase() === 'true';

    const whereClause = buildLibraryVideoWhere(section);
    const orderBy = buildLibraryVideoOrderBy(sortBy);

    const [items, total] = await Promise.all([
      prisma.libraryContent.findMany({
        where: whereClause,
        orderBy,
        skip,
        take: limit,
        select: LIBRARY_ITEM_BASE_SELECT,
      }),
      prisma.libraryContent.count({
        where: whereClause,
      }),
    ]);

    const resolvedItems = await Promise.all(
      items.map((item) =>
        serializeLibraryItem(item, req, {
          includeStreams,
        })
      )
    );

    res.json({
      success: true,
      data: {
        items: resolvedItems,
        pagination: {
          page,
          limit,
          total,
          totalPages: Math.ceil(total / limit),
        },
      },
    });
  } catch (error: any) {
    console.error('Error listing library video feed:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to load library video feed',
      error: error.message,
    });
  }
}

export async function getLibraryItem(req: Request, res: Response) {
  try {
    const itemId = req.params['id'];

    if (!itemId) {
      res.status(400).json({
        success: false,
        message: 'Item id is required',
      });
      return;
    }

    const includeStreams =
      (req.query['includeStreams'] as string | undefined)?.toLowerCase() ===
      'true';

    const item = await prisma.libraryContent.findUnique({
      where: { id: itemId },
      select: LIBRARY_ITEM_BASE_SELECT,
    });

    if (!item) {
      res.status(404).json({
        success: false,
        message: 'Library item not found',
      });
      return;
    }

    const breadcrumbs = await buildBreadcrumbs(item);
    const resolvedItem = await serializeLibraryItem(item, req, {
      includeStreams,
    });

    res.json({
      success: true,
      data: {
        ...resolvedItem,
        breadcrumbs,
      },
    });
  } catch (error: any) {
    console.error('Error fetching library item:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to load library item',
      error: error.message,
    });
  }
}

export async function streamLibraryItem(req: Request, res: Response) {
  try {
    const itemId = req.params['id'];
    if (!itemId) {
      res.status(400).json({ success: false, message: 'Item id is required' });
      return;
    }

    const item = await prisma.libraryContent.findUnique({
      where: { id: itemId },
      select: {
        id: true,
        source: true,
        isFolder: true,
        filePath: true,
        ulozStorageId: true,
        fileSize: true,
        mimeType: true,
        extension: true,
      },
    });

    if (!item) {
      res.status(404).json({ success: false, message: 'Library item not found' });
      return;
    }

    if (item.isFolder) {
      res.status(400).json({ success: false, message: 'Cannot stream a folder' });
      return;
    }

    if (item.source !== ContentSource.ULOZ || !item.filePath) {
      res.status(400).json({ success: false, message: 'Streaming proxy is only available for ULOZ items' });
      return;
    }

    const resolvedUlozStorageId =
      typeof item.ulozStorageId === 'number' && item.ulozStorageId > 0
        ? item.ulozStorageId
        : resolveUlozStorageId(req);
    const cfg = getUlozStorageConfig(resolvedUlozStorageId);
    if (!cfg.proxyCdnUrl) {
      res.status(400).json({ success: false, message: 'ULOZ proxy CDN URL is not configured for this storage id' });
      return;
    }

    const upstreamUrl = buildProxyCdnUrl(cfg.proxyCdnUrl, item.filePath);
    const range = req.header('range');

    const debug = String(process.env['STREAM_PROXY_DEBUG'] || '').toLowerCase();
    const debugEnabledByEnv = debug === '1' || debug === 'true' || debug === 'yes';
    const debugEnabledByQuery = ['1', 'true', 'yes'].includes(
      String(req.query['streamDebug'] ?? '').toLowerCase()
    );
    const debugEnabled = debugEnabledByEnv || debugEnabledByQuery;
    if (debugEnabled) {
      const ua = req.header('user-agent') || '-';
      const referer = req.header('referer') || '-';
      console.log(
        `➡️  stream proxy req method=${req.method} item=${itemId} range=${range || '-'} ua=${JSON.stringify(ua)} referer=${JSON.stringify(referer)}`
      );
    }

    // Browser-like headers for Cloudflare-protected CDN.
    const headers: Record<string, string> = {
      'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': 'https://ulcdn.onlybl.com/',
      'Accept': '*/*',
      'Accept-Encoding': 'identity',
    };

    const ifRange = req.header('if-range');
    if (ifRange) headers['If-Range'] = ifRange;
    const ifNoneMatch = req.header('if-none-match');
    if (ifNoneMatch) headers['If-None-Match'] = ifNoneMatch;
    const ifModifiedSince = req.header('if-modified-since');
    if (ifModifiedSince) headers['If-Modified-Since'] = ifModifiedSince;

    const isHead = req.method === 'HEAD';

    // Allow aborting upstream work if the client disconnects.
    const upstreamAbort = new AbortController();
    const abortUpstream = () => {
      try {
        upstreamAbort.abort();
      } catch {
        // ignore
      }
    };
    res.on('close', abortUpstream);

    // Fast-path HEAD: avoid calling upstream CDN (can hang or be rate-limited).
    if (isHead) {
      const sizeRaw: unknown = (item as any).fileSize;
      const size =
        typeof sizeRaw === 'bigint'
          ? sizeRaw
          : typeof sizeRaw === 'number'
            ? BigInt(Math.max(0, Math.floor(sizeRaw)))
            : typeof sizeRaw === 'string'
              ? BigInt(parseInt(sizeRaw, 10) || 0)
              : 0n;

      res.setHeader('accept-ranges', 'bytes');
      if (!res.getHeader('content-type')) {
        res.setHeader('content-type', pickBestMimeType({ mimeType: item.mimeType, extension: item.extension }));
      }

      if (size > 0n) {
        res.setHeader('content-length', size.toString());
        res.status(200);
        res.end();
        return;
      }

      // If fileSize is unknown in DB, try a tiny upstream range request with a short timeout
      // to infer total length without downloading the whole file.
      try {
        const headProbe = await axios.request({
          url: upstreamUrl,
          method: 'GET',
          headers: {
            ...headers,
            Range: 'bytes=0-0',
          },
          responseType: 'stream',
          maxRedirects: 5,
          httpAgent: upstreamHttpAgent,
          httpsAgent: upstreamHttpsAgent,
          timeout: 8000,
          signal: upstreamAbort.signal,
          validateStatus: () => true,
        });

        const probeType = (headProbe.headers as any)?.['content-type'];
        if (probeType && !res.getHeader('content-type')) {
          res.setHeader('content-type', probeType);
        }

        const contentRange = (headProbe.headers as any)?.['content-range'];
        const match = typeof contentRange === 'string' ? contentRange.match(/\/(\d+)$/) : null;
        const totalSize = match ? Number(match[1]) : null;
        if (Number.isFinite(totalSize) && totalSize != null && totalSize > 0) {
          res.setHeader('content-length', String(totalSize));
        } else {
          const len = (headProbe.headers as any)?.['content-length'];
          if (len) {
            // If we didn't get Content-Range, best effort.
            res.setHeader('content-length', String(len));
          }
        }

        const probeStream: any = headProbe.data;
        if (probeStream && typeof probeStream.destroy === 'function') {
          probeStream.destroy();
        }
      } catch {
        // ignore probe failures; just respond without Content-Length
      }

      res.status(200);
      res.end();
      return;
    }
    // Some CDNs don't properly support HEAD. Use a tiny ranged GET to fetch headers.
    if (range) {
      headers['Range'] = range;
    }

    const upstream = await axios.request({
      url: upstreamUrl,
      method: 'GET',
      headers,
      responseType: 'stream',
      maxRedirects: 5,
      httpAgent: upstreamHttpAgent,
      httpsAgent: upstreamHttpsAgent,
      // Don't hang forever if upstream stalls.
      timeout: 60_000,
      signal: upstreamAbort.signal,
      validateStatus: () => true,
    });

    if (debugEnabled) {
      const upstreamRange = (upstream.headers as any)?.['content-range'];
      const upstreamLen = (upstream.headers as any)?.['content-length'];
      console.log(
        `📡 stream proxy ${req.method} item=${itemId} range=${range || '-'} -> ${upstream.status} content-range=${upstreamRange || '-'} content-length=${upstreamLen || '-'}`
      );
    }

    // Always advertise Range support to clients.
    res.setHeader('accept-ranges', 'bytes');

    // For HEAD requests, respond 200 with the full Content-Length.
    // Many players expect this behavior even if we use Range internally.
    if (isHead) {
      const contentRange = (upstream.headers as any)?.['content-range'];
      const match = typeof contentRange === 'string' ? contentRange.match(/\/(\d+)$/) : null;
      const totalSize = match ? Number(match[1]) : null;
      if (Number.isFinite(totalSize) && totalSize != null && totalSize > 0) {
        res.setHeader('content-length', String(totalSize));
      }
      // Avoid sending Content-Range on HEAD to keep semantics simple.
      res.removeHeader('content-range');
      res.status(200);
    } else {
      res.status(upstream.status);
    }

    const passthroughHeaderNames = [
      'content-type',
      'content-length',
      'content-range',
      'accept-ranges',
      'etag',
      'last-modified',
      'cache-control',
    ];

    for (const name of passthroughHeaderNames) {
      if (isHead && (name === 'content-length' || name === 'content-range')) {
        continue;
      }
      const value = (upstream.headers as any)?.[name];
      if (value != null) {
        res.setHeader(name, value);
      }
    }

    if (!res.getHeader('content-type')) {
      const fallbackType = item.mimeType || 'application/octet-stream';
      res.setHeader('content-type', fallbackType);
    }

    const data: any = upstream.data;

    let bytesSent = 0;
    if (debugEnabled) {
      try {
        data.on('data', (chunk: any) => {
          if (chunk && typeof chunk.length === 'number') {
            bytesSent += chunk.length;
          }
        });
      } catch {
        // ignore
      }
    }

    const cleanup = () => {
      try {
        if (data && typeof data.destroy === 'function') {
          data.destroy();
        }
      } catch {
        // ignore
      }
    };

    data.on('error', cleanup);
    // Note: res 'close' already aborts upstream request.
    res.on('close', cleanup);
    res.on('finish', cleanup);

    // HEAD responses should not include a body.
    if (isHead) {
      cleanup();
      res.end();
      return;
    }

    // If CDN returned an error, don't pipe its HTML/error body as media.
    if (upstream.status >= 400) {
      cleanup();
      if (debugEnabled) {
        console.warn(`⚠️  stream proxy upstream error item=${itemId} status=${upstream.status}`);
      }
      res.end();
      return;
    }

    pipeline(data, res, (err) => {
      if (err) {
        if (debugEnabled) {
          console.warn(`⚠️  stream proxy pipeline error item=${itemId}:`, err.message);
        }
        cleanup();
        return;
      }

      if (debugEnabled) {
        console.log(`✅ stream proxy done item=${itemId} bytesSent=${bytesSent}`);
      }
    });
  } catch (error: any) {
    console.error('Error proxy streaming library item:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to stream library item',
      error: error?.message ?? String(error),
    });
  }
}

