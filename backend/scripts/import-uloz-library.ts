import 'dotenv/config';

import path from 'node:path';
import { PrismaClient, ContentSource } from '@prisma/client';
import type { Prisma } from '@prisma/client';

import { UlozService } from '../src/services/ulozService';

interface SectionConfig {
  section: LibrarySectionValue;
  folderSlug: string;
  displayName?: string;
}

interface SyncStats {
  foldersCreated: number;
  foldersUpdated: number;
  filesCreated: number;
  filesUpdated: number;
  skipped: number;
}

const prisma = new PrismaClient();
const ulozService = new UlozService();

const LIBRARY_SECTION = {
  VIDEOS: 'VIDEOS',
  AUDIO: 'AUDIO',
  EBOOKS: 'EBOOKS',
  MAGAZINES: 'MAGAZINES',
  COMICS: 'COMICS',
  IMAGES: 'IMAGES',
  DOCUMENTS: 'DOCUMENTS',
  ARCHIVES: 'ARCHIVES',
  OTHER: 'OTHER',
} as const;

type LibrarySectionValue = typeof LIBRARY_SECTION[keyof typeof LIBRARY_SECTION];

const LIBRARY_CONTENT_TYPE = {
  FOLDER: 'FOLDER',
  VIDEO: 'VIDEO',
  AUDIO: 'AUDIO',
  IMAGE: 'IMAGE',
  EBOOK: 'EBOOK',
  MAGAZINE: 'MAGAZINE',
  COMIC: 'COMIC',
  PDF: 'PDF',
  EPUB: 'EPUB',
  ARCHIVE: 'ARCHIVE',
  DOCUMENT: 'DOCUMENT',
  PLAYLIST: 'PLAYLIST',
  OTHER: 'OTHER',
} as const;

type LibraryContentTypeValue = typeof LIBRARY_CONTENT_TYPE[keyof typeof LIBRARY_CONTENT_TYPE];

type LibraryContentEntity = Awaited<ReturnType<typeof prisma.libraryContent.upsert>>;

interface CliOptions {
  folderSlug?: string;
  section?: LibrarySectionValue;
  displayName?: string;
}

function parseCliArgs(): CliOptions | null {
  const args = process.argv.slice(2);
  if (args.length === 0) {
    return null;
  }

  const options: Record<string, string> = {};
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (!arg) {
      continue;
    }

    if (!arg.startsWith('--')) {
      continue;
    }

    const [rawKey, rawValue] = arg.includes('=') ? arg.substring(2).split('=') : [arg.substring(2), undefined];
    const key = rawKey.trim().toLowerCase();
    if (!key) continue;

    if (rawValue !== undefined) {
      options[key] = rawValue.trim();
      continue;
    }

    const next = args[i + 1];
    if (next && !next.startsWith('--')) {
      options[key] = next.trim();
      i += 1;
    } else {
      options[key] = 'true';
    }
  }

  const folderSlug = options['folder'] || options['folderslug'];
  if (!folderSlug) {
    return null;
  }

  const sectionValue = options['section'];
  let section: LibrarySectionValue | undefined;
  if (sectionValue) {
    const normalized = sectionValue.trim().toUpperCase();
    if ((LIBRARY_SECTION as Record<string, string>)[normalized]) {
      section = (LIBRARY_SECTION as Record<string, string>)[normalized] as LibrarySectionValue;
    } else {
      console.warn(`⚠️  Unknown section "${sectionValue}". Falling back to OTHER.`);
      section = LIBRARY_SECTION.OTHER;
    }
  }

  const displayName = options['name'] ?? options['display'] ?? options['label'];

  return {
    folderSlug,
    section: section ?? LIBRARY_SECTION.OTHER,
    ...(displayName !== undefined ? { displayName } : {}),
  };
}

function buildEnvSections(): SectionConfig[] {
  return [
    {
      section: LIBRARY_SECTION.VIDEOS,
      folderSlug: process.env['ULOZ_LIBRARY_VIDEOS_FOLDER'] || '',
      displayName: 'Videos',
    },
    {
      section: LIBRARY_SECTION.AUDIO,
      folderSlug: process.env['ULOZ_LIBRARY_AUDIO_FOLDER'] || '',
      displayName: 'Audio',
    },
    {
      section: LIBRARY_SECTION.EBOOKS,
      folderSlug: process.env['ULOZ_LIBRARY_EBOOKS_FOLDER'] || '',
      displayName: 'eBooks',
    },
    {
      section: LIBRARY_SECTION.MAGAZINES,
      folderSlug: process.env['ULOZ_LIBRARY_MAGAZINES_FOLDER'] || '',
      displayName: 'Magazines',
    },
    {
      section: LIBRARY_SECTION.COMICS,
      folderSlug: process.env['ULOZ_LIBRARY_COMICS_FOLDER'] || '',
      displayName: 'Comics',
    },
  ].filter(config => Boolean(config.folderSlug));
}

function resolveSectionConfigs(): SectionConfig[] {
  const cliOptions = parseCliArgs();
  if (cliOptions?.folderSlug) {
    console.log('⚙️  Using CLI arguments for library import');
    return [
      {
        section: cliOptions.section ?? LIBRARY_SECTION.OTHER,
        folderSlug: cliOptions.folderSlug,
        displayName: cliOptions.displayName || cliOptions.section || cliOptions.folderSlug,
      },
    ];
  }

  console.log('⚙️  Using environment variables for section configuration');
  return buildEnvSections();
}

const SECTION_CONFIGS: SectionConfig[] = resolveSectionConfigs();

const VIDEO_EXTENSIONS = new Set(['mp4', 'mkv', 'avi', 'mov', 'm4v', 'webm', 'flv', 'wmv']);
const AUDIO_EXTENSIONS = new Set(['mp3', 'flac', 'wav', 'aac', 'm4a', 'ogg', 'wma', 'm4b', 'opus']);
const IMAGE_EXTENSIONS = new Set(['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'tiff', 'svg']);
const COMIC_EXTENSIONS = new Set(['cbz', 'cbr', 'cb7', 'cba', 'cbt']);
const EBOOK_EXTENSIONS = new Set(['epub', 'mobi', 'azw', 'azw3']);
const ARCHIVE_EXTENSIONS = new Set(['zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz']);
const DOCUMENT_EXTENSIONS = new Set(['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt', 'rtf', 'odt', 'ods']);

if (SECTION_CONFIGS.length === 0) {
  console.error('❌ No section configuration found.');
  console.error('   Provide CLI arguments, e.g.:');
  console.error('     ts-node scripts/import-uloz-library.ts --folder <slug> --section videos --name "My Videos"');
  console.error('   or set environment variables:');
  console.error('     ULOZ_LIBRARY_VIDEOS_FOLDER, ULOZ_LIBRARY_AUDIO_FOLDER, etc.');
  process.exit(1);
}

const folderContentsCache = new Map<string, any[]>();

function normalizeFolderName(value?: string): string {
  if (!value) {
    return '';
  }

  return value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim()
    .toLowerCase();
}

function isNotFoundError(error: any): boolean {
  if (!error) {
    return false;
  }

  const status = error.status ?? error.response?.status;
  const code = error.code ?? error.response?.data?.code ?? error.response?.data?.error;
  const message = typeof error.message === 'string' ? error.message : '';

  return status === 404 || code === 110001 || message.includes('404');
}

async function fetchFolderContents(slug: string): Promise<any[]> {
  return await ulozService.getFolderContents(`https://uloz.to/folder/${slug}`);
}

async function getFolderContentsCached(slug: string): Promise<any[]> {
  if (folderContentsCache.has(slug)) {
    return folderContentsCache.get(slug)!;
  }

  const contents = await fetchFolderContents(slug);
  folderContentsCache.set(slug, contents);
  return contents;
}

function findFolderMatch(contents: any[], target: string): any | undefined {
  const normalizedTarget = normalizeFolderName(target);
  const lowerTarget = target.toLowerCase();

  return contents.find(item => {
    if (!item || !item.isFolder) {
      return false;
    }

    const slug = (item.slug || '').toString();
    const name = (item.name || '').toString();
    const slugLower = slug.toLowerCase();
    const nameNormalized = normalizeFolderName(name);

    return (
      slug === target ||
      slugLower === lowerTarget ||
      (normalizedTarget !== '' && nameNormalized === normalizedTarget)
    );
  });
}

async function resolveBySegments(rootSlug: string, segments: string[]): Promise<{ slug: string; names: string[] } | null> {
  let currentSlug = rootSlug;
  const names: string[] = [];

  for (const segment of segments) {
    let contents: any[];
    try {
      contents = await getFolderContentsCached(currentSlug);
    } catch (error) {
      if (isNotFoundError(error)) {
        return null;
      }
      throw error;
    }

    const match = findFolderMatch(contents, segment);
    if (!match) {
      return null;
    }

    const folderName = (match.name || match.slug || segment).toString().trim();
    names.push(folderName);
    currentSlug = match.slug;
  }

  return {
    slug: currentSlug,
    names,
  };
}

async function findFolderBySlugOrName(rootSlug: string, target: string, maxDepth: number = 8): Promise<{ slug: string; pathNames: string[] } | null> {
  const targetLower = target.toLowerCase();
  const normalizedTarget = normalizeFolderName(target);

  const queue: Array<{ slug: string; pathNames: string[]; depth: number }> = [
    { slug: rootSlug, pathNames: [], depth: 0 },
  ];
  const visited = new Set<string>();

  while (queue.length > 0) {
    const node = queue.shift()!;

    if (visited.has(node.slug)) {
      continue;
    }
    visited.add(node.slug);

    if (node.depth > maxDepth) {
      continue;
    }

    let contents: any[];
    try {
      contents = await getFolderContentsCached(node.slug);
    } catch (error) {
      if (isNotFoundError(error)) {
        continue;
      }
      throw error;
    }

    for (const item of contents) {
      if (!item || !item.isFolder) {
        continue;
      }

      const name = (item.name || item.slug || '').toString().trim();
      const slugLower = (item.slug || '').toLowerCase();
      const nameNormalized = normalizeFolderName(name);
      const nextPath = [...node.pathNames, name];

      if (
        item.slug === target ||
        slugLower === targetLower ||
        (normalizedTarget !== '' && nameNormalized === normalizedTarget)
      ) {
        return {
          slug: item.slug,
          pathNames: nextPath,
        };
      }

      if (node.depth + 1 <= maxDepth) {
        queue.push({
          slug: item.slug,
          pathNames: nextPath,
          depth: node.depth + 1,
        });
      }
    }
  }

  return null;
}

async function resolveFolderTarget(config: SectionConfig): Promise<{ slug: string; pathSegments: string[] }> {
  const input = config.folderSlug.trim();
  const displayName = config.displayName || config.section.toLowerCase() || input;

  try {
    await fetchFolderContents(input);
    return {
      slug: input,
      pathSegments: [displayName],
    };
  } catch (error) {
    if (isNotFoundError(error)) {
      console.warn(`⚠️  Direct access to folder "${input}" failed (404). Attempting to resolve within account tree...`);
    } else {
      throw error;
    }
  }

  const rootSlug = await ulozService.getRootFolderSlug();
  if (!rootSlug) {
    throw new Error('Unable to determine uloz.to root folder slug. Please verify credentials.');
  }

  let rootContents: any[] = [];
  try {
    rootContents = await getFolderContentsCached(rootSlug);
  } catch (error) {
    if (!isNotFoundError(error)) {
      throw error;
    }
  }

  const rootFolderNames = rootContents
    .filter(item => item?.isFolder)
    .map((item: any) => (item.name || item.slug || '').toString().trim())
    .filter(Boolean);

  if (rootFolderNames.length > 0) {
    console.log(`   📂 Top-level folders available: ${rootFolderNames.join(', ')}`);
  } else {
    console.log('   📂 No top-level folders detected under your root folder.');
  }

  const segments = input.split('/').map(segment => segment.trim()).filter(Boolean);

  if (segments.length > 1) {
    const resolved = await resolveBySegments(rootSlug, segments);
    if (!resolved) {
      throw new Error(`Unable to locate folder path "${input}" within your uloz.to account.`);
    }

    const pathSegments = resolved.names.length > 0 ? [...resolved.names] : [displayName];
    pathSegments[pathSegments.length - 1] = displayName;

    return {
      slug: resolved.slug,
      pathSegments,
    };
  }

  const target = segments[0] ?? input;
  const found = await findFolderBySlugOrName(rootSlug, target);

  if (!found) {
    throw new Error(`Folder "${input}" was not found in your uloz.to account. Provide a valid slug or folder path.`);
  }

  const pathSegments = found.pathNames.length > 0 ? [...found.pathNames] : [displayName];
  pathSegments[pathSegments.length - 1] = displayName;

  return {
    slug: found.slug,
    pathSegments,
  };
}

function sanitizeSlugSegment(input: string): string {
  return input
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '') // remove diacritics
    .replace(/[^a-zA-Z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .toLowerCase() || 'item';
}

function buildSlugPath(segments: string[]): string {
  return segments.map(segment => sanitizeSlugSegment(segment)).join('/');
}

function resolveContentType(extension?: string | null, section?: LibrarySectionValue): LibraryContentTypeValue {
  const ext = (extension || '').toLowerCase();

  if (section === LIBRARY_SECTION.MAGAZINES) {
    return LIBRARY_CONTENT_TYPE.MAGAZINE;
  }

  if (section === LIBRARY_SECTION.COMICS) {
    return LIBRARY_CONTENT_TYPE.COMIC;
  }

  if (section === LIBRARY_SECTION.VIDEOS && VIDEO_EXTENSIONS.has(ext)) {
    return LIBRARY_CONTENT_TYPE.VIDEO;
  }

  if (section === LIBRARY_SECTION.AUDIO && AUDIO_EXTENSIONS.has(ext)) {
    return LIBRARY_CONTENT_TYPE.AUDIO;
  }

  if (section === LIBRARY_SECTION.EBOOKS) {
    if (ext === 'pdf') {
      return LIBRARY_CONTENT_TYPE.PDF;
    }
    if (EBOOK_EXTENSIONS.has(ext)) {
      return LIBRARY_CONTENT_TYPE.EPUB;
    }
  }

  if (!ext) {
    return LIBRARY_CONTENT_TYPE.OTHER;
  }

  if (VIDEO_EXTENSIONS.has(ext)) {
    return LIBRARY_CONTENT_TYPE.VIDEO;
  }

  if (AUDIO_EXTENSIONS.has(ext)) {
    return LIBRARY_CONTENT_TYPE.AUDIO;
  }

  if (IMAGE_EXTENSIONS.has(ext)) {
    return LIBRARY_CONTENT_TYPE.IMAGE;
  }

  if (COMIC_EXTENSIONS.has(ext)) {
    return LIBRARY_CONTENT_TYPE.COMIC;
  }

  if (EBOOK_EXTENSIONS.has(ext)) {
    return LIBRARY_CONTENT_TYPE.EPUB;
  }

  if (ARCHIVE_EXTENSIONS.has(ext)) {
    return LIBRARY_CONTENT_TYPE.ARCHIVE;
  }

  if (DOCUMENT_EXTENSIONS.has(ext)) {
    if (ext === 'pdf') {
      return LIBRARY_CONTENT_TYPE.PDF;
    }
    return LIBRARY_CONTENT_TYPE.DOCUMENT;
  }

  return LIBRARY_CONTENT_TYPE.OTHER;
}

async function upsertFolder(params: {
  section: LibrarySectionValue;
  slug: string;
  name: string;
  parentId: string | null;
  parentFolderSlug: string | null;
  filePath: string;
  slugPath: string;
  description?: string;
  url?: string;
}): Promise<{ status: 'created' | 'updated'; record: LibraryContentEntity }> {
  const createData: any = {
    slug: params.slug,
    title: params.name,
    description: params.description || null,
    contentType: LIBRARY_CONTENT_TYPE.FOLDER,
    section: params.section,
    isFolder: true,
    source: ContentSource.ULOZ,
    parentId: params.parentId,
    parentFolderSlug: params.parentFolderSlug,
    filePath: params.filePath,
    slugPath: params.slugPath,
    fileUrl: params.url || `https://uloz.to/folder/${params.slug}`,
    ulozSlug: params.slug,
    ulozFolderSlug: params.slug,
    isAvailable: true,
  };

  const updateData: any = {
    title: params.name,
    description: params.description || null,
    contentType: LIBRARY_CONTENT_TYPE.FOLDER,
    section: params.section,
    isFolder: true,
    parentId: params.parentId,
    parentFolderSlug: params.parentFolderSlug,
    filePath: params.filePath,
    slugPath: params.slugPath,
    fileUrl: params.url || `https://uloz.to/folder/${params.slug}`,
    ulozSlug: params.slug,
    ulozFolderSlug: params.slug,
    source: ContentSource.ULOZ,
    isAvailable: true,
  };

  const result = await prisma.libraryContent.upsert({
    where: { slug: params.slug },
    create: createData,
    update: updateData,
  });

  const status = result.createdAt.getTime() === result.updatedAt.getTime() ? 'created' : 'updated';

  return { status, record: result };
}

async function upsertFile(params: {
  section: LibrarySectionValue;
  slug: string;
  name: string;
  parentId: string | null;
  parentFolderSlug: string | null;
  filePath: string;
  slugPath: string;
  size: number;
  description?: string;
}): Promise<'created' | 'updated' | 'skipped'> {
  try {
    const fileInfo = await ulozService.getFileInfo(params.slug);
    const extension = fileInfo.extension || path.extname(fileInfo.name || '').replace('.', '') || null;
    const fileContentType = resolveContentType(extension, params.section);

    const metadata: Record<string, unknown> = {};
    if (fileInfo.videoPreview) {
      metadata['videoPreview'] = fileInfo.videoPreview;
    }
    if (fileInfo.thumbnail) {
      metadata['thumbnail'] = fileInfo.thumbnail;
    }
    if (fileInfo.description) {
      metadata['description'] = fileInfo.description;
    }

    const durationSeconds =
      fileInfo.duration !== null && fileInfo.duration !== undefined
        ? Math.round(Number(fileInfo.duration))
        : null;

    const metadataPayload: Prisma.JsonObject | undefined =
      Object.keys(metadata).length > 0 ? (metadata as Prisma.JsonObject) : undefined;

    const createData: any = {
      slug: params.slug,
      title: params.name,
      description: params.description || fileInfo.description || null,
      contentType: fileContentType,
      section: params.section,
      isFolder: false,
      extension: extension,
      fileSize:
        fileInfo.size !== undefined && fileInfo.size !== null
          ? BigInt(fileInfo.size)
          : params.size !== undefined && params.size !== null
            ? BigInt(params.size)
            : null,
      source: ContentSource.ULOZ,
      parentId: params.parentId,
      parentFolderSlug: params.parentFolderSlug,
      filePath: params.filePath,
      slugPath: params.slugPath,
      fileUrl: fileInfo.url,
      ulozSlug: fileInfo.slug,
      ulozFolderSlug: fileInfo.folderSlug || params.parentFolderSlug || null,
      thumbnailUrl: fileInfo.thumbnail || null,
      coverUrl: fileInfo.thumbnail || null,
      mimeType: fileInfo.contentType || null,
      duration: durationSeconds,
      metadata: metadataPayload,
      isAvailable: true,
    };

    const updateData: any = {
      title: params.name,
      description: params.description || fileInfo.description || null,
      contentType: fileContentType,
      section: params.section,
      isFolder: false,
      extension: extension,
      fileSize:
        fileInfo.size !== undefined && fileInfo.size !== null
          ? BigInt(fileInfo.size)
          : params.size !== undefined && params.size !== null
            ? BigInt(params.size)
            : null,
      source: ContentSource.ULOZ,
      parentId: params.parentId,
      parentFolderSlug: params.parentFolderSlug,
      filePath: params.filePath,
      slugPath: params.slugPath,
      fileUrl: fileInfo.url,
      ulozSlug: fileInfo.slug,
      ulozFolderSlug: fileInfo.folderSlug || params.parentFolderSlug || null,
      thumbnailUrl: fileInfo.thumbnail || null,
      coverUrl: fileInfo.thumbnail || null,
      mimeType: fileInfo.contentType || null,
      duration: durationSeconds,
      metadata: metadataPayload,
      isAvailable: true,
    };

    const result = await prisma.libraryContent.upsert({
      where: { slug: params.slug },
      create: createData,
      update: updateData,
    });

    return result.createdAt.getTime() === result.updatedAt.getTime() ? 'created' : 'updated';
  } catch (error: any) {
    console.error(`❌ Failed to fetch uloz file info for ${params.slug}: ${error.message}`);
    return 'skipped';
  }
}

async function syncFolder(options: {
  section: LibrarySectionValue;
  folderSlug: string;
  parentId: string | null;
  parentFolderSlug: string | null;
  pathSegments: string[];
  stats: SyncStats;
}): Promise<void> {
  console.log(`📁 Syncing folder: ${options.folderSlug} (section: ${options.section})`);

  const folderUrl = `https://uloz.to/folder/${options.folderSlug}`;
  const entries = await ulozService.getFolderContents(folderUrl);

  if (!entries || entries.length === 0) {
    console.log(`   ⚠️  No entries found in folder ${options.folderSlug}`);
    return;
  }

  for (const entry of entries) {
    const childPathSegments = [...options.pathSegments, entry.name];
    const filePath = childPathSegments.join('/');
    const slugPath = buildSlugPath(childPathSegments);

    if (entry.isFolder) {
      const folderParams: {
        section: LibrarySectionValue;
        slug: string;
        name: string;
        parentId: string | null;
        parentFolderSlug: string | null;
        filePath: string;
        slugPath: string;
        description?: string;
        url?: string;
      } = {
        section: options.section,
        slug: entry.slug,
        name: entry.name,
        parentId: options.parentId,
        parentFolderSlug: options.folderSlug,
        filePath,
        slugPath,
      };

      if (entry.description !== undefined && entry.description !== null) {
        folderParams.description = entry.description;
      }
      if (entry.url) {
        folderParams.url = entry.url;
      }

      const { status: folderStatus, record } = await upsertFolder(folderParams);

      if (folderStatus === 'created') {
        options.stats.foldersCreated += 1;
      } else {
        options.stats.foldersUpdated += 1;
      }

      await syncFolder({
        section: options.section,
        folderSlug: entry.slug,
        parentId: record.id,
        parentFolderSlug: entry.slug,
        pathSegments: childPathSegments,
        stats: options.stats,
      });
    } else {
      const fileParams: {
        section: LibrarySectionValue;
        slug: string;
        name: string;
        parentId: string | null;
        parentFolderSlug: string | null;
        filePath: string;
        slugPath: string;
        size: number;
        description?: string;
      } = {
        section: options.section,
        slug: entry.slug,
        name: entry.name,
        parentId: options.parentId,
        parentFolderSlug: options.folderSlug,
        filePath,
        slugPath,
        size: entry.size || 0,
      };

      if (entry.description !== undefined && entry.description !== null) {
        fileParams.description = entry.description;
      }

      const status = await upsertFile(fileParams);

      if (status === 'created') {
        options.stats.filesCreated += 1;
      } else if (status === 'updated') {
        options.stats.filesUpdated += 1;
      } else {
        options.stats.skipped += 1;
      }
    }
  }
}

async function syncSection(config: SectionConfig): Promise<SyncStats> {
  const stats: SyncStats = {
    foldersCreated: 0,
    foldersUpdated: 0,
    filesCreated: 0,
    filesUpdated: 0,
    skipped: 0,
  };

  folderContentsCache.clear();

  const displayName = config.displayName || config.section.toLowerCase();

  console.log(`\n🚀 Syncing section ${config.section} (folder slug: ${config.folderSlug})`);

  const resolvedTarget = await resolveFolderTarget(config);
  const rootPathSegments = resolvedTarget.pathSegments.length > 0 ? resolvedTarget.pathSegments : [displayName];
  const slugPath = buildSlugPath(rootPathSegments);

  if (resolvedTarget.slug !== config.folderSlug) {
    console.log(`   ➡️  Resolved folder slug: ${resolvedTarget.slug} (from input "${config.folderSlug}")`);
  }

  const { status, record } = await upsertFolder({
    section: config.section,
    slug: resolvedTarget.slug,
    name: rootPathSegments[rootPathSegments.length - 1] || displayName,
    parentId: null,
    parentFolderSlug: null,
    filePath: rootPathSegments.join('/'),
    slugPath,
    description: `Root folder for ${config.section.toLowerCase()} library`,
    url: `https://uloz.to/folder/${resolvedTarget.slug}`,
  });

  if (status === 'created') {
    stats.foldersCreated += 1;
  } else {
    stats.foldersUpdated += 1;
  }

  await syncFolder({
    section: config.section,
    folderSlug: resolvedTarget.slug,
    parentId: record.id,
    parentFolderSlug: resolvedTarget.slug,
    pathSegments: rootPathSegments,
    stats,
  });

  console.log(`\n✅ Finished section ${config.section}`);
  console.log(`   Folders created: ${stats.foldersCreated}`);
  console.log(`   Folders updated: ${stats.foldersUpdated}`);
  console.log(`   Files created: ${stats.filesCreated}`);
  console.log(`   Files updated: ${stats.filesUpdated}`);
  if (stats.skipped > 0) {
    console.log(`   Files skipped: ${stats.skipped}`);
  }

  return stats;
}

async function main() {
  const overall: SyncStats = {
    foldersCreated: 0,
    foldersUpdated: 0,
    filesCreated: 0,
    filesUpdated: 0,
    skipped: 0,
  };

  for (const config of SECTION_CONFIGS) {
    const sectionStats = await syncSection(config);
    overall.foldersCreated += sectionStats.foldersCreated;
    overall.foldersUpdated += sectionStats.foldersUpdated;
    overall.filesCreated += sectionStats.filesCreated;
    overall.filesUpdated += sectionStats.filesUpdated;
    overall.skipped += sectionStats.skipped;
  }

  console.log('\n📊 Overall summary');
  console.log(`   Folders created: ${overall.foldersCreated}`);
  console.log(`   Folders updated: ${overall.foldersUpdated}`);
  console.log(`   Files created: ${overall.filesCreated}`);
  console.log(`   Files updated: ${overall.filesUpdated}`);
  if (overall.skipped > 0) {
    console.log(`   Files skipped: ${overall.skipped}`);
  }
}

main()
  .catch(error => {
    console.error('❌ Sync failed:', error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

