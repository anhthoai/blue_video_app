/**
 * File URL utilities for building CDN URLs dynamically
 */

const CDN_URL = process.env['CDN_URL'] || '';

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
 * Build avatar URL from user data
 * Priority: avatar (storage) > avatarUrl (external)
 */
export function buildAvatarUrl(user: {
  avatar?: string | null;
  avatarUrl?: string | null;
  fileDirectory?: string | null;
}): string | null {
  // If storage-based avatar exists
  if (user.avatar && user.fileDirectory) {
    const cdnUrl = CDN_URL.replace(/\/$/, ''); // Remove trailing slash
    return `${cdnUrl}/avatars/${user.fileDirectory}/${user.avatar}`;
  }
  
  // Fallback to external URL
  return user.avatarUrl || null;
}

/**
 * Build banner URL from user data
 * Priority: banner (storage) > bannerUrl (external)
 */
export function buildBannerUrl(user: {
  banner?: string | null;
  bannerUrl?: string | null;
  fileDirectory?: string | null;
}): string | null {
  // If storage-based banner exists
  if (user.banner && user.fileDirectory) {
    const cdnUrl = CDN_URL.replace(/\/$/, ''); // Remove trailing slash
    return `${cdnUrl}/banners/${user.fileDirectory}/${user.banner}`;
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

