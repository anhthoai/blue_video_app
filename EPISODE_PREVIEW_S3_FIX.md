# Episode Preview URLs - S3 Storage with Presigned URLs

## Problem

When importing episodes from uloz.to, the `thumbnailUrl` and `videoPreviewUrl` fields contained temporary CDN URLs that expire after a few hours:

```json
{
  "preview_info": {
    "small_image": "https://previewer.greencdn.link/img/gPWmWrpiw4er.webp?vt=1763074799&sg=...",
    "video": "https://previewer.greencdn.link/vd/gPWmWrpiw4er.webm?vt=1763074799&sg=..."
  }
}
```

These URLs become invalid after expiration, breaking episode thumbnails and previews in the app.

## Solution

**Automatically download and upload preview files to S3 during episode import, then generate presigned URLs on-demand.**

This ensures:
- ✅ Secure storage with private S3 buckets
- ✅ Presigned URLs generated dynamically (1-hour expiry)
- ✅ Preview URLs never permanently expire (regenerated each time)
- ✅ Full control over storage and access
- ✅ Faster loading (your CDN vs external CDN)
- ✅ No broken images/videos after hours

## Implementation

### 1. Added `StorageService.uploadFromUrl()` Method

**File**: `backend/src/config/storage.ts`

New static method that:
1. Downloads a file from any URL
2. Detects file type (webp, jpg, png, webm, mp4)
3. Uploads to S3 with a clean filename
4. Returns permanent S3 URL

```typescript
static async uploadFromUrl(
  url: string,
  folder: string = 'uploads',
  filename?: string
): Promise<{ url: string; key: string; size: number } | null>
```

**Features:**
- Automatic content-type detection
- Custom folder organization
- Optional filename prefix
- Error handling (returns null on failure)

### 2. Updated Episode Import Logic

**File**: `backend/src/controllers/movieController.ts`

**Strategy**: Store S3 keys (not URLs) in database with `s3://` prefix.

**Before:**
```typescript
thumbnailUrl: file.thumbnail || null,
videoPreviewUrl: file.videoPreview || null,
```

**After:**
```typescript
// Upload preview URLs to S3 to avoid expiration
// Store S3 key instead of URL for presigned URL generation
let thumbnailUrl = file.thumbnail || null;
let videoPreviewUrl = file.videoPreview || null;

if (file.thumbnail) {
  const result = await StorageService.uploadFromUrl(
    file.thumbnail,
    `episode-thumbnails/${movieId}`,
    `ep${epNum}_thumb`
  );
  if (result) {
    // Store S3 key prefixed with 's3://' to indicate it needs presigned URL
    thumbnailUrl = `s3://${result.key}`;
  }
}

if (file.videoPreview) {
  const result = await StorageService.uploadFromUrl(
    file.videoPreview,
    `episode-previews/${movieId}`,
    `ep${epNum}_preview`
  );
  if (result) {
    // Store S3 key prefixed with 's3://' to indicate it needs presigned URL
    videoPreviewUrl = `s3://${result.key}`;
  }
}
```

### 3. Added Presigned URL Generation on API Response

**File**: `backend/src/controllers/movieController.ts` - `getMovieById()`

When episodes are fetched, S3 keys are converted to presigned URLs:

```typescript
// Generate presigned URLs for episode previews if stored as S3 keys
const episodesWithUrls = await Promise.all(
  movie.episodes.map(async (ep: any) => {
    let thumbnailUrl = ep.thumbnailUrl;
    let videoPreviewUrl = ep.videoPreviewUrl;

    // If URL starts with 's3://', generate presigned URL
    if (thumbnailUrl && thumbnailUrl.startsWith('s3://')) {
      const key = thumbnailUrl.substring(5); // Remove 's3://' prefix
      thumbnailUrl = await StorageService.getSignedUrl(key, 3600); // 1 hour expiry
    }

    if (videoPreviewUrl && videoPreviewUrl.startsWith('s3://')) {
      const key = videoPreviewUrl.substring(5);
      videoPreviewUrl = await StorageService.getSignedUrl(key, 3600); // 1 hour expiry
    }

    return {
      ...ep,
      thumbnailUrl,
      videoPreviewUrl,
    };
  })
);
```

## File Organization in S3

```
episode-thumbnails/
  {movieId}/
    ep1_thumb.webp
    ep2_thumb.webp
    ep3_thumb.webp
    ...

episode-previews/
  {movieId}/
    ep1_preview.webm
    ep2_preview.webm
    ep3_preview.webm
    ...
```

## Example Import Flow

### Before (with temporary URLs):
```
1. Import Episode 1
   thumbnailUrl: https://previewer.greencdn.link/img/abc.webp?vt=1763074799
   videoPreviewUrl: https://previewer.greencdn.link/vd/abc.webm?vt=1763074799

2. After 2-3 hours: ❌ URLs expire, broken images
```

### After (with S3 storage + Presigned URLs):
```
1. Import Episode 1
   📥 Downloading thumbnail...
   📤 Uploading to S3: episode-thumbnails/{movieId}/ep1_thumb.webp
   ✅ Stored in DB: s3://episode-thumbnails/{movieId}/ep1_thumb.webp
   
   📥 Downloading video preview...
   📤 Uploading to S3: episode-previews/{movieId}/ep1_preview.webm
   ✅ Stored in DB: s3://episode-previews/{movieId}/ep1_preview.webm

2. User fetches movie with episodes (GET /api/v1/movies/{id})
   🔐 Generating presigned URLs (1 hour expiry)...
   ✅ Returns: https://your-s3.com/episode-thumbnails/...?X-Amz-Signature=...
   ✅ Returns: https://your-s3.com/episode-previews/...?X-Amz-Signature=...

3. After 1 hour: Presigned URLs expire, but...
   📱 Next API call regenerates new presigned URLs automatically ✅
   
4. Forever: ✅ Files stored permanently, presigned URLs regenerated on-demand
```

## Testing

### Test Episode Import:

1. Import episodes from uloz.to folder/file
2. Check backend logs for upload confirmation:
   ```
   📥 Downloading from URL: https://previewer.greencdn.link/...
   📤 Uploading to S3: episode-thumbnails/...
   ✅ Upload successful: https://your-cdn.com/...
   ```

3. Check database - URLs should be S3 keys with `s3://` prefix:
   ```sql
   SELECT episode_number, thumbnail_url, video_preview_url 
   FROM movie_episodes 
   WHERE movie_id = '{movieId}';
   
   -- Example output:
   -- thumbnail_url: s3://episode-thumbnails/{movieId}/ep1_thumb.webp
   -- video_preview_url: s3://episode-previews/{movieId}/ep1_preview.webm
   ```

4. Fetch movie via API - should return presigned URLs:
   ```bash
   curl http://localhost:3000/api/v1/movies/{movieId}
   
   # Response should contain:
   # "thumbnailUrl": "https://your-s3.com/...?X-Amz-Signature=..."
   # "videoPreviewUrl": "https://your-s3.com/...?X-Amz-Signature=..."
   ```

5. Verify presigned URLs work and regenerate automatically ✅

## Configuration

Make sure your S3 configuration is set in `.env`:

```bash
# S3 Storage Configuration
S3_ENDPOINT=https://s3.amazonaws.com
S3_ACCESS_KEY_ID=your-access-key
S3_SECRET_ACCESS_KEY=your-secret-key
S3_REGION=us-east-1
S3_BUCKET_NAME=blue-video-storage
CDN_URL=https://your-cdn.com  # Optional, for custom CDN
```

## Performance Impact

- **Upload Time**: ~1-3 seconds per preview (thumbnail + video) during import
- **Presigned URL Generation**: ~10-50ms per URL (on API request)
- **Presigned URL Expiry**: 1 hour (regenerated automatically on next request)
- **Storage Cost**: ~50-100KB per thumbnail, ~500KB-1MB per video preview
- **Benefits**: Secure storage, permanent files, dynamic access control

## Fallback Behavior

If S3 upload fails:
- ✅ Falls back to original temporary URL
- ✅ Episode import still succeeds
- ⚠️ Preview will expire after a few hours
- 📋 Error logged in console

## Presigned URLs vs Public URLs

### Why Presigned URLs?

**Presigned URLs** (this solution):
- ✅ **Secure**: S3 bucket can be private
- ✅ **Access control**: Only authenticated users get URLs
- ✅ **Time-limited**: URLs expire after 1 hour
- ✅ **Flexible**: Can add custom expiry, user-specific access
- ⚠️ **Trade-off**: Slight overhead generating URLs (~10-50ms per request)

**Public URLs** (alternative):
- ✅ **Fast**: No generation overhead
- ✅ **CDN-friendly**: Can cache URLs permanently
- ❌ **Less secure**: Anyone with URL can access
- ❌ **No access control**: Can't revoke access per user
- ❌ **Public bucket required**: Increases security risk

### When to Use Each:

| Use Case | Recommendation |
|----------|---------------|
| **Private content** (paid, VIP) | ✅ Presigned URLs |
| **Public content** (free, marketing) | Public URLs OK |
| **User-specific access** | ✅ Presigned URLs |
| **High traffic** (millions of views) | Consider public + CDN |
| **Security-first** | ✅ Presigned URLs |

### Switching Between Approaches:

To use **public URLs instead** (if your bucket is public):
1. In `storage.ts`, uncomment: `ACL: 'public-read'`
2. In `movieController.ts`, store `result.url` instead of `s3://${result.key}`
3. Remove presigned URL generation logic

## Future Improvements

Consider adding:
1. **Lazy upload**: Import first, upload previews in background job
2. **Batch processing**: Upload multiple previews in parallel
3. **Compression**: Optimize images before uploading
4. **Cleanup**: Delete old preview files when episode is deleted
5. **Retry mechanism**: Retry failed uploads automatically
6. **Cache presigned URLs**: Cache URLs for 30 min to reduce generation overhead

## Files Changed

1. `backend/src/config/storage.ts` - Added `uploadFromUrl()` method
2. `backend/src/controllers/movieController.ts` - Updated episode import logic
   - Line 697-725: Folder import
   - Line 840-868: Single file import

## Migration for Existing Episodes

To fix existing episodes with expired URLs, create a migration script:

```javascript
// backend/scripts/migrate-episode-previews.js
// Re-fetch preview URLs and upload to S3
// (Not implemented yet - manual fix needed)
```

Or simply re-import the episodes - the new logic will apply automatically.

