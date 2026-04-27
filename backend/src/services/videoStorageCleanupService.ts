import type { Video } from '@prisma/client';

import { StorageService } from '../config/storage';
import { makeS3Ref } from './s3Registry';

const SUBTITLE_EXTENSIONS = ['srt', 'vtt', 'ass', 'ssa'];
const THUMBNAIL_EXTENSIONS = ['jpg', 'jpeg', 'png', 'webp'];

type VideoStorageCleanupTarget = Pick<
  Video,
  | 'id'
  | 'fileName'
  | 'fileDirectory'
  | 's3StorageId'
  | 'thumbnailUrl'
  | 'thumbnails'
  | 'videoUrl'
  | 'remotePlayUrl'
  | 'subtitles'
>;

function normalizeString(value: string | null | undefined): string | null {
  const trimmedValue = value?.trim();
  return trimmedValue ? trimmedValue : null;
}

function addRef(refs: Set<string>, value: string | null | undefined): void {
  const normalizedValue = normalizeString(value);
  if (normalizedValue) {
    refs.add(normalizedValue);
  }
}

function resolveStoredAssetRef(
  value: string | null | undefined,
  storageId: number,
  fileDirectory: string | null | undefined,
  folderHint?: string,
): string | null {
  const normalizedValue = normalizeString(value);
  if (!normalizedValue) {
    return null;
  }

  if (normalizedValue.startsWith('s3://')) {
    return normalizedValue;
  }

  if (/^https?:\/\//i.test(normalizedValue)) {
    return null;
  }

  if (normalizedValue.includes('/')) {
    return makeS3Ref(storageId, normalizedValue.replace(/^\/+/, ''));
  }

  const normalizedDirectory = normalizeString(fileDirectory);
  if (folderHint && normalizedDirectory) {
    return makeS3Ref(
      storageId,
      `${folderHint}/${normalizedDirectory}/${normalizedValue}`,
    );
  }

  if (folderHint) {
    return makeS3Ref(storageId, `${folderHint}/${normalizedValue}`);
  }

  return null;
}

function buildDerivedVideoRef(video: VideoStorageCleanupTarget): string | null {
  const fileName = normalizeString(video.fileName);
  const fileDirectory = normalizeString(video.fileDirectory);
  if (!fileName || !fileDirectory) {
    return null;
  }

  return makeS3Ref(video.s3StorageId, `videos/${fileDirectory}/${fileName}`);
}

function buildDerivedThumbnailRefs(video: VideoStorageCleanupTarget): string[] {
  const fileName = normalizeString(video.fileName);
  const fileDirectory = normalizeString(video.fileDirectory);
  if (!fileName || !fileDirectory) {
    return [];
  }

  const baseFileName = fileName.replace(/\.[^.]+$/, '');
  return THUMBNAIL_EXTENSIONS.map((extension) =>
    makeS3Ref(
      video.s3StorageId,
      `thumbnails/${fileDirectory}/${baseFileName}.${extension}`,
    ),
  );
}

function buildDerivedSubtitleRefs(video: VideoStorageCleanupTarget): string[] {
  const fileName = normalizeString(video.fileName);
  const fileDirectory = normalizeString(video.fileDirectory);
  if (!fileName || !fileDirectory || !video.subtitles.length) {
    return [];
  }

  const baseFileName = fileName.replace(/\.[^.]+$/, '');

  return video.subtitles.flatMap((language) => {
    const normalizedLanguage = normalizeString(language);
    if (!normalizedLanguage) {
      return [];
    }

    return SUBTITLE_EXTENSIONS.map((extension) => {
      const suffix = normalizedLanguage === 'eng' || normalizedLanguage === 'en'
        ? ''
        : `.${normalizedLanguage}`;

      return makeS3Ref(
        video.s3StorageId,
        `subtitles/${fileDirectory}/${baseFileName}${suffix}.${extension}`,
      );
    });
  });
}

async function deleteAssetRef(assetRef: string): Promise<void> {
  try {
    await StorageService.deleteFile(assetRef);
  } catch (error) {
    console.warn(`⚠️ Failed to delete storage asset ${assetRef}:`, error);
  }
}

export async function cleanupVideoStorageAssets(
  video: VideoStorageCleanupTarget,
): Promise<void> {
  const refs = new Set<string>();

  addRef(refs, buildDerivedVideoRef(video));
  addRef(
    refs,
    resolveStoredAssetRef(
      video.videoUrl,
      video.s3StorageId,
      video.fileDirectory,
      'videos',
    ),
  );
  addRef(
    refs,
    resolveStoredAssetRef(
      video.remotePlayUrl,
      video.s3StorageId,
      video.fileDirectory,
      'videos',
    ),
  );
  addRef(
    refs,
    resolveStoredAssetRef(
      video.thumbnailUrl,
      video.s3StorageId,
      video.fileDirectory,
      'thumbnails',
    ),
  );

  for (const thumbnail of video.thumbnails) {
    addRef(
      refs,
      resolveStoredAssetRef(
        thumbnail,
        video.s3StorageId,
        video.fileDirectory,
        'thumbnails',
      ),
    );
  }

  for (const thumbnailRef of buildDerivedThumbnailRefs(video)) {
    addRef(refs, thumbnailRef);
  }

  for (const subtitleRef of buildDerivedSubtitleRefs(video)) {
    addRef(refs, subtitleRef);
  }

  await Promise.all([...refs].map(deleteAssetRef));
}