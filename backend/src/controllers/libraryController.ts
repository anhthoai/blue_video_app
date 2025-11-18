import { Request, Response } from 'express';
import { ContentSource } from '@prisma/client';
import prisma from '../lib/prisma';
import { StorageService } from '../config/storage';
import ulozService from '../services/ulozService';

const MAX_PAGE_SIZE = 200;

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
    const key = url.substring(5);
    try {
      return await StorageService.getSignedUrl(key);
    } catch (error) {
      console.warn(`⚠️  Failed to generate signed URL for ${key}:`, (error as Error).message);
      return null;
    }
  }

  return url;
}

async function resolveFileStreamUrl(item: {
  fileUrl?: string | null;
  source: ContentSource;
  ulozSlug?: string | null;
  metadata?: any;
}): Promise<string | null> {
  const { fileUrl, source, ulozSlug, metadata } = item;

  // Handle S3 stored content
  if (fileUrl?.startsWith('s3://')) {
    const key = fileUrl.substring(5);
    try {
      return await StorageService.getSignedUrl(key);
    } catch (error) {
      console.warn(`⚠️  Failed to generate signed URL for ${key}:`, (error as Error).message);
      return null;
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
          id: true,
          title: true,
          description: true,
          contentType: true,
          section: true,
          isFolder: true,
          extension: true,
          fileSize: true,
          fileUrl: true,
          filePath: true,
          slugPath: true,
          parentId: true,
          thumbnailUrl: true,
          coverUrl: true,
          mimeType: true,
          duration: true,
          metadata: true,
          source: true,
          ulozSlug: true,
          updatedAt: true,
          createdAt: true,
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
      items.map(async (item) => {
        const thumbnailUrl = item.thumbnailUrl?.startsWith('s3://')
          ? await resolveMediaUrl(item.thumbnailUrl)
          : item.thumbnailUrl;

        const coverUrl = item.coverUrl?.startsWith('s3://')
          ? await resolveMediaUrl(item.coverUrl)
          : item.coverUrl;

        const streamUrl = includeStreams
          ? await resolveFileStreamUrl({
              fileUrl: item.fileUrl,
              source: item.source,
              ulozSlug: item.ulozSlug ?? null,
              metadata: item.metadata ?? undefined,
            })
          : null;

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
          duration: item.duration,
          metadata: item.metadata,
          thumbnailUrl,
          coverUrl,
          source: item.source,
          ulozSlug: item.ulozSlug,
          hasChildren: item._count.children > 0,
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
        };
      })
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
      select: {
        id: true,
        title: true,
        description: true,
        contentType: true,
        section: true,
        isFolder: true,
        extension: true,
        fileSize: true,
        fileUrl: true,
        filePath: true,
        slugPath: true,
        parentId: true,
        thumbnailUrl: true,
        coverUrl: true,
        mimeType: true,
        duration: true,
        metadata: true,
        source: true,
        ulozSlug: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    if (!item) {
      res.status(404).json({
        success: false,
        message: 'Library item not found',
      });
      return;
    }

    const thumbnailUrl = item.thumbnailUrl?.startsWith('s3://')
      ? await resolveMediaUrl(item.thumbnailUrl)
      : item.thumbnailUrl;

    const coverUrl = item.coverUrl?.startsWith('s3://')
      ? await resolveMediaUrl(item.coverUrl)
      : item.coverUrl;

    const streamUrl = includeStreams
      ? await resolveFileStreamUrl({
          fileUrl: item.fileUrl,
          source: item.source,
          ulozSlug: item.ulozSlug ?? null,
          metadata: item.metadata ?? undefined,
        })
      : null;

    const breadcrumbs = await buildBreadcrumbs(item);

    res.json({
      success: true,
      data: {
        ...item,
        fileSize: item.fileSize ? Number(item.fileSize) : null,
        thumbnailUrl,
        coverUrl,
        streamUrl,
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

