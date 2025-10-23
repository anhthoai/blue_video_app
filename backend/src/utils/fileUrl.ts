/**
 * File URL utilities for building CDN URLs and S3 presigned URLs dynamically
 */

import { GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import s3Client from '../services/s3Service';

const CDN_URL = process.env['CDN_URL'] || '';
const S3_ENDPOINT = process.env['S3_ENDPOINT'] || '';
const S3_BUCKET_NAME = process.env['S3_BUCKET_NAME'] || '';

/**
 * Get file directory based on user's creation date
 * Format: yyyy/mm/dd
 */
export function getUserFileDirectory(createdAt: Date): string {
  const year = createdAt.getFullYear();
  const month = String(createdAt.getMonth() + 1).padStart(2, '0');
  const day = String(createdAt.getDate()).padStart(2, '0');
  return `${year}/${month}/${day}`;
}

/**
 * Build file URL - uses CDN if available, otherwise generates S3 presigned URL
 * @param fileDirectory - File directory path (e.g., "2025/10/02")
 * @param fileName - File name (e.g., "uuid.jpg")
 * @param folder - Optional folder prefix (e.g., "avatars", "videos", "chat/photo")
 * @returns Full URL to access the file
 */
export async function buildFileUrl(
  fileDirectory: string | null | undefined,
  fileName: string | null | undefined,
  folder?: string
): Promise<string | null> {
  if (!fileDirectory || !fileName) {
    return null;
  }

  // Build object key
  const objectKey = folder
    ? `${folder}/${fileDirectory}/${fileName}`
    : `${fileDirectory}/${fileName}`;

  // If CDN URL is configured, use it (public access)
  if (CDN_URL && CDN_URL.trim() !== '') {
    const cdnUrl = CDN_URL.replace(/\/$/, ''); // Remove trailing slash
    return `${cdnUrl}/${objectKey}`;
  }

  // Otherwise, generate S3 presigned URL (works with any S3-compatible storage)
  try {
    const command = new GetObjectCommand({
      Bucket: S3_BUCKET_NAME,
      Key: objectKey,
    });

    // Generate presigned URL valid for 1 hour
    const presignedUrl = await getSignedUrl(s3Client, command, {
      expiresIn: 3600, // 1 hour
    });

    return presignedUrl;
  } catch (error) {
    console.error('Error generating presigned URL:', error);
    // Fallback to direct S3 URL (may not work if bucket is private)
    return `${S3_ENDPOINT}/${S3_BUCKET_NAME}/${objectKey}`;
  }
}

/**
 * Build file URL synchronously - uses CDN or returns object path for presigned URL generation
 * Use this for responses that must be synchronous
 */
export function buildFileUrlSync(
  fileDirectory: string | null | undefined,
  fileName: string | null | undefined,
  folder?: string
): string | null {
  if (!fileDirectory || !fileName) {
    return null;
  }

  // Build object key
  const objectKey = folder
    ? `${folder}/${fileDirectory}/${fileName}`
    : `${fileDirectory}/${fileName}`;

  // If CDN URL is configured, use it (public access)
  if (CDN_URL && CDN_URL.trim() !== '') {
    const cdnUrl = CDN_URL.replace(/\/$/, '');
    return `${cdnUrl}/${objectKey}`;
  }

  // If no CDN, return object key path
  // Frontend will use this to request a presigned URL from the backend
  return objectKey;
}

/**
 * Get object key from fileDirectory and fileName
 */
export function getObjectKey(
  fileDirectory: string | null | undefined,
  fileName: string | null | undefined,
  folder?: string
): string | null {
  if (!fileDirectory || !fileName) {
    return null;
  }

  return folder
    ? `${folder}/${fileDirectory}/${fileName}`
    : `${fileDirectory}/${fileName}`;
}

/**
 * Build avatar URL from user data
 * Returns CDN URL if CDN_URL is set, otherwise returns object key for presigned URL
 */
export function buildAvatarUrl(user: {
  avatar?: string | null;
  avatarUrl?: string | null;
  fileDirectory?: string | null;
}): string | null {
  console.log(`🔍 buildAvatarUrl - user:`, {
    avatar: user.avatar,
    avatarUrl: user.avatarUrl,
    fileDirectory: user.fileDirectory,
    hasAvatar: !!user.avatar,
    hasFileDirectory: !!user.fileDirectory,
    hasAvatarUrl: !!user.avatarUrl
  });
  
  // If storage-based avatar exists
  if (user.avatar && user.fileDirectory) {
    const objectKey = getObjectKey(user.fileDirectory, user.avatar, 'avatars');
    if (objectKey) {
      console.log(`🖼️ Built avatar object key: ${objectKey}`);
      // Return object key - frontend will use this to request presigned URL
      return objectKey;
    }
  }
  
  // Check if avatarUrl is a storage URL that needs presigned URL generation
  if (user.avatarUrl && !user.avatarUrl.startsWith('http')) {
    console.log(`🖼️ Avatar URL appears to be object key: ${user.avatarUrl}`);
    return user.avatarUrl;
  }
  
  // Fallback to external URL
  const fallbackUrl = user.avatarUrl || null;
  console.log(`🖼️ Using fallback avatar URL: ${fallbackUrl}`);
  return fallbackUrl;
}

/**
 * Build banner URL from user data
 * Returns CDN URL if CDN_URL is set, otherwise returns object key for presigned URL
 */
export function buildBannerUrl(user: {
  banner?: string | null;
  bannerUrl?: string | null;
  fileDirectory?: string | null;
}): string | null {
  // If storage-based banner exists
  if (user.banner && user.fileDirectory) {
    const result = buildFileUrlSync(user.fileDirectory, user.banner, 'banners');
    // If buildFileUrlSync returns object key (no CDN), return it for presigned URL generation
    return result;
  }
  
  // Fallback to external URL
  return user.bannerUrl || null;
}

/**
 * Serialize user object with computed avatar/banner URLs
 */
export function serializeUserWithUrls(user: any): any {
  return {
    ...user,
    avatarUrl: buildAvatarUrl(user),
    bannerUrl: buildBannerUrl(user),
    // Remove storage fields from API response for security
    avatar: undefined,
    banner: undefined,
    fileDirectory: undefined,
  };
}

/**
 * Async version of buildAvatarUrl that generates presigned URLs
 */
export async function buildAvatarUrlAsync(user: {
  avatar?: string | null;
  avatarUrl?: string | null;
  fileDirectory?: string | null;
}): Promise<string | null> {
  console.log(`🔍 buildAvatarUrlAsync - user:`, {
    avatar: user.avatar,
    avatarUrl: user.avatarUrl,
    fileDirectory: user.fileDirectory,
    hasAvatar: !!user.avatar,
    hasFileDirectory: !!user.fileDirectory,
    hasAvatarUrl: !!user.avatarUrl
  });
  
  // If storage-based avatar exists, generate presigned URL
  if (user.avatar && user.fileDirectory) {
    const objectKey = getObjectKey(user.fileDirectory, user.avatar, 'avatars');
    if (objectKey) {
      console.log(`🖼️ Built avatar object key: ${objectKey}`);
      // Generate presigned URL
      const presignedUrl = await buildFileUrl(user.fileDirectory, user.avatar, 'avatars');
      console.log(`🖼️ Generated presigned avatar URL: ${presignedUrl}`);
      return presignedUrl;
    }
  }
  
  // Check if avatarUrl is a storage URL that needs presigned URL generation
  if (user.avatarUrl && !user.avatarUrl.startsWith('http')) {
    console.log(`🖼️ Avatar URL appears to be object key: ${user.avatarUrl}`);
    // This is an object key, generate presigned URL
    if (user.fileDirectory) {
      const presignedUrl = await buildFileUrl(user.fileDirectory, user.avatarUrl, 'avatars');
      console.log(`🖼️ Generated presigned URL from object key: ${presignedUrl}`);
      return presignedUrl;
    }
  }
  
  // Fallback to external URL
  const fallbackUrl = user.avatarUrl || null;
  console.log(`🖼️ Using fallback avatar URL: ${fallbackUrl}`);
  return fallbackUrl;
}

/**
 * Async version of serializeUserWithUrls that generates presigned URLs
 */
export async function serializeUserWithUrlsAsync(user: any): Promise<any> {
  return {
    ...user,
    avatarUrl: await buildAvatarUrlAsync(user),
    bannerUrl: buildBannerUrl(user), // Keep banner sync for now
    // Remove storage fields from API response for security
    avatar: undefined,
    banner: undefined,
    fileDirectory: undefined,
  };
}

/**
 * Build community post file URL
 * @param fileDirectory - File directory path (e.g., "2025/10/02/post-id")
 * @param fileName - File name (e.g., "uuid.jpg")
 * @returns Full URL to access the community post file
 */
export async function buildCommunityPostFileUrl(
  fileDirectory: string | null | undefined,
  fileName: string | null | undefined
): Promise<string | null> {
  if (!fileDirectory || !fileName) {
    return null;
  }

  // Build object key with "community-posts" prefix
  const objectKey = `community-posts/${fileDirectory}/${fileName}`;

  // If CDN URL is configured, use it (public access)
  if (CDN_URL && CDN_URL.trim() !== '') {
    const cdnUrl = CDN_URL.replace(/\/$/, ''); // Remove trailing slash
    return `${cdnUrl}/${objectKey}`;
  }

  // Otherwise, generate S3 presigned URL
  try {
    const command = new GetObjectCommand({
      Bucket: S3_BUCKET_NAME,
      Key: objectKey,
    });

    const presignedUrl = await getSignedUrl(s3Client, command, {
      expiresIn: 3600, // 1 hour
    });

    return presignedUrl;
  } catch (error) {
    console.error('Error generating presigned URL for community post file:', error);
    return null;
  }
}

