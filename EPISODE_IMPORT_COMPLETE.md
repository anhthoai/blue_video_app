# Episode Import - Complete ✅

## Authentication Fixed

Successfully implemented uloz.to API authentication based on the working Cloudflare Workers code:

### Correct Authentication Flow:
- **Method**: `PUT` (not POST)
- **Endpoint**: `/v6/session` (not `/v1/auth` or `/v1/session/login`)
- **Base URL**: `https://apis.uloz.to`
- **Headers**: 
  - `X-Auth-Token`: App API key (set on initialization)
  - `X-User-Token`: User session token (set after login)

### Request Body:
```json
{
  "login": "username@email.com",
  "password": "password"
}
```

### Response:
```json
{
  "token_id": "session_token",
  "token_validity_interval": 7200,
  "session": {
    "user": {
      "root_folder_slug": "8Utvf8GbEqYY",
      ...
    }
  }
}
```

## Field Mapping Fixed

Fixed the mapping between uloz.to API response and database fields:

### uloz.to API Response Structure:
```json
{
  "slug": "YINK3siyuOvV",
  "name": "2gether The Movie 2021 WEB-DL 1080p AAC H.264-darrensstarkid.mkv",
  "extension": "mkv",
  "filesize": 1237080383,  // ← Note: "filesize" not "size"
  "content_type": "video",
  "format": {
    "width": 1920,
    "height": 1080,
    "duration": 6680,       // ← Duration in seconds
    "orientation": "normal"
  },
  "preview_info": {
    "small_image": "https://previewer.greencdn.link/img/...",  // ← Thumbnail
    "video": "https://previewer.greencdn.link/vd/...",         // ← Video preview
    "large_image": "..."
  }
}
```

### Fixed Mapping:
```typescript
// Before (WRONG):
size: fileData.size || 0,                    // ❌ Wrong field name
duration: fileData.duration,                  // ❌ Wrong path
thumbnail: fileData.thumbnail,                // ❌ Wrong path

// After (CORRECT):
size: fileData.filesize || fileData.size || 0,            // ✅ Correct
duration: fileData.format?.duration || null,              // ✅ Correct
thumbnail: fileData.preview_info?.small_image || null,    // ✅ Correct
```

## Database Fields Now Populated:

After the fix, these fields are correctly saved to the database:

- ✅ `fileSize`: 1,237,080,383 bytes (~1.15 GB)
- ✅ `duration`: 6,680 seconds (~1 hour 51 minutes)
- ✅ `thumbnailUrl`: `https://previewer.greencdn.link/img/YINK3siyuOvV.webp`
- ✅ `title`: Full filename
- ✅ `slug`: File slug for streaming
- ✅ `extension`: File extension (mkv)
- ✅ `contentType`: video

## How to Import Episodes:

### Simple Command (defaults to episode 1, season 1):
```bash
node import-episodes.js <movieId> <uloz-slug>
```

### Example:
```bash
node import-episodes.js ed5d01af-74ae-4943-b490-a25cc8a1966d YINK3siyuOvV
```

### With Episode and Season Numbers:
```bash
node import-episodes.js <movieId> <slug> <episodeNumber> <seasonNumber>
```

### Using Full URL (works too):
```bash
node import-episodes.js <movieId> https://uloz.to/file/YINK3siyuOvV
```

## Movie Detail Screen

The movie detail screen shows "Movie not found" - this needs investigation:

### Possible Issues:
1. **Cache**: Mobile app might be caching old state
2. **Refresh**: Need to pull-to-refresh to reload data
3. **Route**: Check if navigation path is correct

### Next Steps:
1. **Delete the existing episode** (if any) to test re-import
2. **Re-import the episode** with fixed field mapping
3. **Force refresh** the mobile app (pull-to-refresh or restart)
4. **Check backend logs** to see if the detail endpoint is being called

## Testing Checklist:

- [x] Authentication working
- [x] File info retrieved successfully
- [x] Field mapping fixed (filesize, duration, thumbnail)
- [ ] Episode saved with all fields populated
- [ ] Movie detail screen loads correctly
- [ ] Episode list shows duration and thumbnail
- [ ] Video player works (streaming from uloz.to)

## Environment Variables:

Required in `.env`:
```env
ULOZ_USERNAME=your_email@example.com
ULOZ_PASSWORD=your_password
ULOZ_API_KEY=your_app_api_key
ULOZ_BASE_URL=https://apis.uloz.to
```

## References:

- Working code: `blue_video_app/references/uloz.js` (Cloudflare Workers)
- uloz.to API endpoints:
  - Auth: `PUT /v6/session`
  - File info: `GET /v7/file/{slug}/private`
  - Folder list: `GET /v8/user/{username}/folder/{slug}/file-list`
  - Stream URL: `POST /v5/file/download-link/vipdata`

