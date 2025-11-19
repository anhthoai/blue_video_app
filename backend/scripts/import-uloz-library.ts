import 'dotenv/config';

import path from 'node:path';
import { PrismaClient, ContentSource } from '@prisma/client';
import type { Prisma } from '@prisma/client';

import { UlozService } from '../src/services/ulozService';
import { StorageService } from '../src/config/storage';

interface SectionConfig {
  section: string;
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

interface UploadJob {
  slug: string;
  name: string;
  thumbnailUrl?: string;
  videoPreviewUrl?: string;
  datePath: string;
  filenameId: string;
}

const prisma = new PrismaClient();
const ulozService = new UlozService();

type LibraryContentEntity = Awaited<ReturnType<typeof prisma.libraryContent.upsert>>;

interface CliOptions {
  folderSlug?: string;
  section?: string;
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
  const section = sectionValue ? sectionValue.trim().toLowerCase() : undefined;

  const displayName = options['name'] ?? options['display'] ?? options['label'];

  return {
    folderSlug,
    section: section ?? 'other',
    ...(displayName !== undefined ? { displayName } : {}),
  };
}

function buildEnvSections(): SectionConfig[] {
  const configs: SectionConfig[] = [];
  const envEntries = Object.entries(process.env);

  for (const [key, value] of envEntries) {
    if (!key || !value) {
      continue;
    }

    const match = key.match(/^ULOZ_LIBRARY_(.+)_FOLDER$/i);
    if (!match) {
      continue;
    }

    const rawSection = match[1] || '';
    const folderSlug = value.trim();
    if (!folderSlug) {
      continue;
    }

    const section = rawSection
      .toLowerCase()
      .replace(/__+/g, '_')
      .replace(/_/g, '-');

    const displayName = section
      .split('-')
      .map(part => part.charAt(0).toUpperCase() + part.slice(1))
      .join(' ');

    configs.push({
      section,
      folderSlug,
      displayName,
    });
  }

  return configs;
}

function resolveSectionConfigs(): SectionConfig[] {
  const cliOptions = parseCliArgs();
  if (cliOptions?.folderSlug) {
    console.log('⚙️  Using CLI arguments for library import');
    return [
      {
        section: (cliOptions.section ?? 'other').toLowerCase(),
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

function resolveContentType(extension?: string | null, section?: string): string {
  const ext = (extension || '').toLowerCase();
  const sectionLower = section?.toLowerCase();

  if (sectionLower === 'magazines') {
    return 'magazine';
  }

  if (sectionLower === 'comics') {
    return 'comic';
  }

  if (sectionLower === 'videos' && VIDEO_EXTENSIONS.has(ext)) {
    return 'video';
  }

  if (sectionLower === 'audio' && AUDIO_EXTENSIONS.has(ext)) {
    return 'audio';
  }

  if (sectionLower === 'ebooks') {
    if (ext === 'pdf') {
      return 'pdf';
    }
    if (EBOOK_EXTENSIONS.has(ext)) {
      return 'epub';
    }
  }

  if (!ext) {
    return 'other';
  }

  if (VIDEO_EXTENSIONS.has(ext)) {
    return 'video';
  }

  if (AUDIO_EXTENSIONS.has(ext)) {
    return 'audio';
  }

  if (IMAGE_EXTENSIONS.has(ext)) {
    return 'image';
  }

  if (COMIC_EXTENSIONS.has(ext)) {
    return 'comic';
  }

  if (EBOOK_EXTENSIONS.has(ext)) {
    return 'epub';
  }

  if (ARCHIVE_EXTENSIONS.has(ext)) {
    return 'archive';
  }

  if (DOCUMENT_EXTENSIONS.has(ext)) {
    if (ext === 'pdf') {
      return 'pdf';
    }
    return 'document';
  }

  return 'other';
}

async function upsertFolder(params: {
  section: string;
  slug: string;
  name: string;
  parentId: string | null;
  parentFolderSlug: string | null;
  filePath: string;
  slugPath: string;
  description?: string;
  url?: string;
}): Promise<{ status: 'created' | 'updated'; record: LibraryContentEntity }> {
  const sectionValue = params.section.toLowerCase();

  const createData: any = {
    slug: params.slug,
    title: params.name,
    description: params.description || null,
    contentType: 'folder',
    section: sectionValue,
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
    contentType: 'folder',
    section: sectionValue,
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
  section: string;
  slug: string;
  name: string;
  parentId: string | null;
  parentFolderSlug: string | null;
  filePath: string;
  slugPath: string;
  size: number;
  description?: string;
  uploadQueue?: UploadJob[];
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

    // Build date-based storage prefix using current date
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    const datePath = `${year}/${month}/${day}`;

    // Use file slug as filenameid (same for thumbnail and video preview)
    const filenameId = params.slug;

    // If upload queue is provided, add to queue instead of uploading immediately
    let thumbnailUrl: string | null = null;
    let videoPreviewUrl: string | null = null;

    if (params.uploadQueue) {
      // Queue uploads for batch processing
      if (fileInfo.thumbnail && !fileInfo.thumbnail.startsWith('s3://')) {
        params.uploadQueue.push({
          slug: params.slug,
          name: params.name,
          thumbnailUrl: fileInfo.thumbnail,
          datePath,
          filenameId,
        });
        // Set temporary URL - will be updated after batch upload
        thumbnailUrl = fileInfo.thumbnail;
      } else if (fileInfo.thumbnail?.startsWith('s3://')) {
        thumbnailUrl = fileInfo.thumbnail;
      }

      if (fileInfo.videoPreview && !fileInfo.videoPreview.startsWith('s3://')) {
        const existingJob = params.uploadQueue.find(job => job.slug === params.slug);
        if (existingJob) {
          existingJob.videoPreviewUrl = fileInfo.videoPreview;
        } else {
          params.uploadQueue.push({
            slug: params.slug,
            name: params.name,
            videoPreviewUrl: fileInfo.videoPreview,
            datePath,
            filenameId,
          });
        }
        // Set temporary URL - will be updated after batch upload
        videoPreviewUrl = fileInfo.videoPreview;
      } else if (fileInfo.videoPreview?.startsWith('s3://')) {
        videoPreviewUrl = fileInfo.videoPreview;
      }
    } else {
      // Upload immediately (backward compatibility)
      if (fileInfo.thumbnail && !fileInfo.thumbnail.startsWith('s3://')) {
        console.log(`   📥 Uploading thumbnail to S3 for ${params.name}...`);
        const thumbnailResult = await StorageService.uploadFromUrl(
          fileInfo.thumbnail,
          `thumbnails/${datePath}`,
          filenameId
        );
        
        if (thumbnailResult) {
          thumbnailUrl = `s3://${thumbnailResult.key}`;
          console.log(`   ✅ Thumbnail uploaded: ${thumbnailResult.key}`);
        } else {
          console.warn(`   ⚠️  Failed to upload thumbnail for ${params.name}`);
        }
      } else if (fileInfo.thumbnail?.startsWith('s3://')) {
        thumbnailUrl = fileInfo.thumbnail;
      }

      if (fileInfo.videoPreview && !fileInfo.videoPreview.startsWith('s3://')) {
        console.log(`   📥 Uploading video preview to S3 for ${params.name}...`);
        const videoPreviewResult = await StorageService.uploadFromUrl(
          fileInfo.videoPreview,
          `previews/${datePath}`,
          filenameId
        );
        
        if (videoPreviewResult) {
          videoPreviewUrl = `s3://${videoPreviewResult.key}`;
          console.log(`   ✅ Video preview uploaded: ${videoPreviewResult.key}`);
        } else {
          console.warn(`   ⚠️  Failed to upload video preview for ${params.name}`);
        }
      } else if (fileInfo.videoPreview?.startsWith('s3://')) {
        videoPreviewUrl = fileInfo.videoPreview;
      }
    }

    const sectionValue = params.section.toLowerCase();
    const contentTypeValue = fileContentType.toLowerCase();

    const createData: any = {
      slug: params.slug,
      title: params.name,
      description: params.description || fileInfo.description || null,
      contentType: contentTypeValue,
      section: sectionValue,
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
      thumbnailUrl: thumbnailUrl,
      videoPreviewUrl: videoPreviewUrl,
      coverUrl: null, // Remove coverUrl as requested
      mimeType: fileInfo.contentType || null,
      duration: durationSeconds,
      metadata: metadataPayload,
      isAvailable: true,
    };

    const updateData: any = {
      title: params.name,
      description: params.description || fileInfo.description || null,
      contentType: contentTypeValue,
      section: sectionValue,
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
      thumbnailUrl: thumbnailUrl,
      videoPreviewUrl: videoPreviewUrl,
      coverUrl: null, // Remove coverUrl as requested
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

async function processUploadQueue(uploadQueue: UploadJob[], concurrency: number = 5): Promise<void> {
  if (uploadQueue.length === 0) {
    return;
  }

  console.log(`\n📦 Processing ${uploadQueue.length} upload job(s) in batches of ${concurrency}...`);

  // Deduplicate jobs by slug (keep the most recent one)
  const uniqueJobs = new Map<string, UploadJob>();
  for (const job of uploadQueue) {
    const existing = uniqueJobs.get(job.slug);
    if (!existing) {
      uniqueJobs.set(job.slug, job);
    } else {
      // Merge URLs if both have them
      if (job.thumbnailUrl && !existing.thumbnailUrl) {
        existing.thumbnailUrl = job.thumbnailUrl;
      }
      if (job.videoPreviewUrl && !existing.videoPreviewUrl) {
        existing.videoPreviewUrl = job.videoPreviewUrl;
      }
      // Use the most recent datePath
      if (job.datePath > existing.datePath) {
        existing.datePath = job.datePath;
      }
    }
  }

  const deduplicatedQueue = Array.from(uniqueJobs.values());
  if (deduplicatedQueue.length !== uploadQueue.length) {
    console.log(`   🔄 Deduplicated: ${uploadQueue.length} → ${deduplicatedQueue.length} unique job(s)`);
  }

  // Prepare batch upload jobs
  const thumbnailJobs: Array<{ url: string; folder: string; filename: string; slug: string }> = [];
  const previewJobs: Array<{ url: string; folder: string; filename: string; slug: string }> = [];
  const jobMap = new Map<string, UploadJob>();

  for (const job of deduplicatedQueue) {
    jobMap.set(job.slug, job);
    
    if (job.thumbnailUrl) {
      thumbnailJobs.push({
        url: job.thumbnailUrl,
        folder: `thumbnails/${job.datePath}`,
        filename: job.filenameId,
        slug: job.slug,
      });
    }
    
    if (job.videoPreviewUrl) {
      previewJobs.push({
        url: job.videoPreviewUrl,
        folder: `previews/${job.datePath}`,
        filename: job.filenameId,
        slug: job.slug,
      });
    }
  }

  // Process thumbnail uploads in batches
  // Use exact same method as previews
  if (thumbnailJobs.length > 0) {
    console.log(`   📸 Uploading ${thumbnailJobs.length} thumbnail(s)...`);
    const thumbnailResults = await StorageService.uploadFromUrlBatch(
      thumbnailJobs.map(job => ({ url: job.url, folder: job.folder, filename: job.filename })),
      concurrency,
      true // Skip if already exists in S3 - same as previews
    );

    // Update database with S3 keys
    for (let i = 0; i < thumbnailJobs.length; i++) {
      const job = thumbnailJobs[i];
      const result = thumbnailResults[i];
      
      if (!job) {
        console.warn(`   ⚠️  No job found at index ${i}`);
        continue;
      }
      
      if (!result) {
        console.warn(`   ⚠️  Thumbnail upload failed for ${job.slug} (${jobMap.get(job.slug)?.name || 'unknown'})`);
        continue;
      }
      
      const s3Key = `s3://${result.key}`;
      try {
        await prisma.libraryContent.update({
          where: { slug: job.slug },
          data: { thumbnailUrl: s3Key },
        });
        console.log(`   ✅ Updated thumbnail for ${jobMap.get(job.slug)?.name || job.slug}`);
      } catch (error: any) {
        console.warn(`   ⚠️  Failed to update thumbnail for ${job.slug}: ${error.message}`);
      }
    }
  }

  // Process video preview uploads in batches
  if (previewJobs.length > 0) {
    console.log(`   🎬 Uploading ${previewJobs.length} video preview(s)...`);
    const previewResults = await StorageService.uploadFromUrlBatch(
      previewJobs.map(job => ({ url: job.url, folder: job.folder, filename: job.filename })),
      concurrency,
      true // Skip if already exists in S3
    );

    // Update database with S3 keys
    for (let i = 0; i < previewJobs.length; i++) {
      const job = previewJobs[i];
      const result = previewResults[i];
      
      if (!job) continue;
      
      if (result) {
        const s3Key = `s3://${result.key}`;
        try {
          await prisma.libraryContent.update({
            where: { slug: job.slug },
            data: { videoPreviewUrl: s3Key } as any,
          });
          console.log(`   ✅ Updated video preview for ${jobMap.get(job.slug)?.name || job.slug}`);
        } catch (error: any) {
          console.warn(`   ⚠️  Failed to update video preview for ${job.slug}: ${error.message}`);
        }
      }
    }
  }

  console.log(`✅ Completed batch upload processing\n`);
}

async function syncFolder(options: {
  section: string;
  folderSlug: string;
  parentId: string | null;
  parentFolderSlug: string | null;
  pathSegments: string[];
  stats: SyncStats;
  uploadQueue?: UploadJob[];
}): Promise<void> {
  console.log(`📁 Syncing folder: ${options.folderSlug} (section: ${options.section})`);

  const folderUrl = `https://uloz.to/folder/${options.folderSlug}`;
  const entries = await ulozService.getFolderContents(folderUrl);

  if (!entries || entries.length === 0) {
    console.log(`   ⚠️  No entries found in folder ${options.folderSlug}`);
    return;
  }

  // Rate limiting: add delay between file processing to avoid overwhelming Uloz.to
  const delayBetweenFiles = 100; // 100ms delay between files (reduced for faster processing)
  
  for (let i = 0; i < entries.length; i++) {
    const entry = entries[i];
    
    // Add delay between files (except for the first one)
    if (i > 0) {
      await new Promise(resolve => setTimeout(resolve, delayBetweenFiles));
    }
    
    const childPathSegments = [...options.pathSegments, entry.name];
    const filePath = childPathSegments.join('/');
    const slugPath = buildSlugPath(childPathSegments);

    if (entry.isFolder) {
      const folderParams: {
        section: string;
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
        ...(options.uploadQueue ? { uploadQueue: options.uploadQueue } : {}),
      });
    } else {
      const fileParams: {
        section: string;
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

      const status = await upsertFile({
        ...fileParams,
        ...(options.uploadQueue ? { uploadQueue: options.uploadQueue } : {}),
      });

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

async function addExistingFilesToUploadQueue(
  section: string,
  uploadQueue: UploadJob[]
): Promise<void> {
  console.log(`\n🔍 Checking existing files in section "${section}" for missing S3 uploads...`);

  // Build date-based storage prefix using current date
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  const datePath = `${year}/${month}/${day}`;

  // Find all files in this section that have thumbnail or video preview URLs
  // Note: Using 'as any' because Prisma client needs to be regenerated after adding videoPreviewUrl
  const allFiles = await (prisma.libraryContent.findMany as any)({
    where: {
      section: section.toLowerCase(),
      isFolder: false,
      OR: [
        { thumbnailUrl: { not: null } },
        { videoPreviewUrl: { not: null } },
      ],
    },
    select: {
      slug: true,
      title: true,
      thumbnailUrl: true,
      videoPreviewUrl: true,
    },
  });

  // Filter to only files with temporary URLs (not S3 keys)
  const filesNeedingUpload = (allFiles as any[]).filter((file: any) => {
    const hasTempThumbnail = file.thumbnailUrl && !file.thumbnailUrl.startsWith('s3://');
    const hasTempPreview = file.videoPreviewUrl && !file.videoPreviewUrl.startsWith('s3://');
    return hasTempThumbnail || hasTempPreview;
  });

  if (filesNeedingUpload.length === 0) {
    console.log(`   ✅ All files already have S3 keys`);
    return;
  }

  console.log(`   📋 Found ${filesNeedingUpload.length} file(s) with temporary URLs. Fetching fresh URLs from uloz.to...`);
  console.log(`   ⚡ Processing in batches of 20 with 200ms delay between requests...`);

  // Fetch fresh URLs from uloz.to for each file with rate limiting
  let successCount = 0;
  let errorCount = 0;
  
  // Process in batches to avoid overwhelming Uloz.to
  // Optimized for faster processing while still being safe
  const batchSize = 20; // Larger batches for faster processing
  const delayBetweenRequests = 200; // 200ms delay between requests
  const delayBetweenBatches = 1000; // 1 second delay between batches
  
  for (let i = 0; i < filesNeedingUpload.length; i += batchSize) {
    const batch = filesNeedingUpload.slice(i, i + batchSize);
    const batchNumber = Math.floor(i / batchSize) + 1;
    const totalBatches = Math.ceil(filesNeedingUpload.length / batchSize);
    
    console.log(`   📦 Processing batch ${batchNumber}/${totalBatches} (${batch.length} files)...`);
    
    // Process batch with controlled concurrency
    const batchPromises = batch.map(async (file, index) => {
      // Add delay between requests within batch
      if (index > 0) {
        await new Promise(resolve => setTimeout(resolve, delayBetweenRequests));
      }
      
      const fileAny = file as any; // Type assertion for Prisma client compatibility
      const filenameId = fileAny.slug;
      
      try {
        // Fetch fresh file info from uloz.to to get new thumbnail/preview URLs
        // Note: This may fail if the file's folder was deleted, but we'll handle it gracefully
        const fileInfo = await ulozService.getFileInfo(fileAny.slug);
      
      // Update database with fresh URLs first
      const updateData: any = {};
      if (fileInfo.thumbnail && !fileInfo.thumbnail.startsWith('s3://')) {
        updateData.thumbnailUrl = fileInfo.thumbnail;
      }
      if (fileInfo.videoPreview && !fileInfo.videoPreview.startsWith('s3://')) {
        updateData.videoPreviewUrl = fileInfo.videoPreview;
      }
      
      if (Object.keys(updateData).length > 0) {
        await prisma.libraryContent.update({
          where: { slug: fileAny.slug },
          data: updateData,
        });
      }
      
      // Add to upload queue with fresh URLs (deduplicate by slug)
      let existingJob = uploadQueue.find(job => job.slug === fileAny.slug);

      if (fileInfo.thumbnail && !fileInfo.thumbnail.startsWith('s3://')) {
        if (existingJob) {
          existingJob.thumbnailUrl = fileInfo.thumbnail;
          existingJob.datePath = datePath;
          existingJob.filenameId = filenameId;
        } else {
          uploadQueue.push({
            slug: fileAny.slug,
            name: fileAny.title,
            thumbnailUrl: fileInfo.thumbnail,
            datePath,
            filenameId,
          });
        }
      }

      if (fileInfo.videoPreview && !fileInfo.videoPreview.startsWith('s3://')) {
        if (!existingJob) {
          existingJob = uploadQueue.find(job => job.slug === fileAny.slug);
        }
        if (existingJob) {
          existingJob.videoPreviewUrl = fileInfo.videoPreview;
          existingJob.datePath = datePath;
          existingJob.filenameId = filenameId;
        } else {
          uploadQueue.push({
            slug: fileAny.slug,
            name: fileAny.title,
            videoPreviewUrl: fileInfo.videoPreview,
            datePath,
            filenameId,
          });
        }
      }
      
      return { success: true };
    } catch (error: any) {
      const errorMsg = error.message || String(error);
      const fullError = error.stack || errorMsg;
      
      // Check if this is a folder-related error (expected for files in deleted folders)
      const isFolderError = 
        errorMsg.includes('folder') || 
        errorMsg.includes('Folder') ||
        errorMsg.includes('failed to get folder slug') ||
        errorMsg.includes('failed to list folders') ||
        fullError.includes('folder') ||
        fullError.includes('Folder');
      
      // Only log if it's not a folder-related error
      if (!isFolderError) {
        console.warn(`   ⚠️  Failed to fetch fresh URLs for ${fileAny.title} (${fileAny.slug}): ${errorMsg}`);
      }
      
      // For files in deleted folders, skip them entirely (can't get fresh URLs)
      if (isFolderError) {
        // Don't add to upload queue - the file's folder is gone, so we can't get fresh URLs
        return { success: false, isFolderError: true };
      }
      
      // For other errors, still try to use existing URLs if available (they might still work)
      let existingJob = uploadQueue.find(job => job.slug === fileAny.slug);
      
      if (fileAny.thumbnailUrl && typeof fileAny.thumbnailUrl === 'string' && !fileAny.thumbnailUrl.startsWith('s3://')) {
        if (existingJob) {
          existingJob.thumbnailUrl = fileAny.thumbnailUrl;
          existingJob.datePath = datePath;
          existingJob.filenameId = filenameId;
        } else {
          uploadQueue.push({
            slug: fileAny.slug,
            name: fileAny.title,
            thumbnailUrl: fileAny.thumbnailUrl,
            datePath,
            filenameId,
          });
        }
      }
      if (fileAny.videoPreviewUrl && typeof fileAny.videoPreviewUrl === 'string' && !fileAny.videoPreviewUrl.startsWith('s3://')) {
        if (!existingJob) {
          existingJob = uploadQueue.find(job => job.slug === fileAny.slug);
        }
        if (existingJob) {
          existingJob.videoPreviewUrl = fileAny.videoPreviewUrl;
          existingJob.datePath = datePath;
          existingJob.filenameId = filenameId;
        } else {
          uploadQueue.push({
            slug: fileAny.slug,
            name: fileAny.title,
            videoPreviewUrl: fileAny.videoPreviewUrl,
            datePath,
            filenameId,
          });
        }
      }
      
      return { success: false, isFolderError: false };
    }
    });
    
    // Wait for all requests in batch to complete
    const batchResults = await Promise.all(batchPromises);
    
    // Count successes and errors
    for (const result of batchResults) {
      if (result.success) {
        successCount++;
      } else if (!result.isFolderError) {
        errorCount++;
      }
    }
    
    // Add delay between batches to avoid overwhelming Uloz.to
    if (i + batchSize < filesNeedingUpload.length) {
      await new Promise(resolve => setTimeout(resolve, delayBetweenBatches));
    }
  }
  
  if (errorCount > 0) {
    console.log(`   ⚠️  ${errorCount} file(s) had errors fetching fresh URLs (may be in deleted folders)`);
  }

  console.log(`   ✅ Successfully processed ${successCount} file(s), added to upload queue with fresh URLs`);
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

  const sectionLower = config.section.toLowerCase();
  const displayName = config.displayName || sectionLower;

  console.log(`\n🚀 Syncing section ${sectionLower} (folder slug: ${config.folderSlug})`);

  const resolvedTarget = await resolveFolderTarget({
    ...config,
    section: sectionLower,
  });
  const rootPathSegments = resolvedTarget.pathSegments.length > 0 ? resolvedTarget.pathSegments : [displayName];
  const slugPath = buildSlugPath(rootPathSegments);

  if (resolvedTarget.slug !== config.folderSlug) {
    console.log(`   ➡️  Resolved folder slug: ${resolvedTarget.slug} (from input "${config.folderSlug}")`);
  }

  const { status, record } = await upsertFolder({
    section: sectionLower,
    slug: resolvedTarget.slug,
    name: rootPathSegments[rootPathSegments.length - 1] || displayName,
    parentId: null,
    parentFolderSlug: null,
    filePath: rootPathSegments.join('/'),
    slugPath,
    description: `Root folder for ${sectionLower} library`,
    url: `https://uloz.to/folder/${resolvedTarget.slug}`,
  });

  if (status === 'created') {
    stats.foldersCreated += 1;
  } else {
    stats.foldersUpdated += 1;
  }

  // Create upload queue for batch processing
  const uploadQueue: UploadJob[] = [];

  // First, add existing files with temporary URLs to the queue
  await addExistingFilesToUploadQueue(sectionLower, uploadQueue);

  // Then sync folder (which will add new/updated files to the queue)
  await syncFolder({
    section: sectionLower,
    folderSlug: resolvedTarget.slug,
    parentId: record.id,
    parentFolderSlug: resolvedTarget.slug,
    pathSegments: rootPathSegments,
    stats,
    uploadQueue,
  });

  // Process all uploads in batches after syncing is complete
  await processUploadQueue(uploadQueue, 5); // Process 5 uploads at a time

  console.log(`\n✅ Finished section ${sectionLower}`);
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

