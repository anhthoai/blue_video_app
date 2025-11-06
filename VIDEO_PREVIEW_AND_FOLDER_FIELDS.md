# Video Preview & Folder Slug Fields Added ✅

## New Database Fields

Added two new fields to the `MovieEpisode` table for future use:

### 1. `videoPreviewUrl` (video_preview_url)
- **Type**: `String` (TEXT)
- **Nullable**: Yes
- **Purpose**: Stores the animated video preview URL from uloz.to
- **Source**: Extracted from `preview_info.video` in uloz.to API response
- **Example**: `https://previewer.greencdn.link/vd/YINK3siyuOvV.webm?vt=1762556399&sg=...`

**Use Cases:**
- Display animated preview on hover in the UI
- Quick preview before playing full video
- Faster loading preview for low bandwidth users
- Video thumbnails in grid views

### 2. `folderSlug` (folder_slug)
- **Type**: `String` (VARCHAR 500)
- **Nullable**: Yes
- **Purpose**: Stores the parent folder slug where the file is located on uloz.to
- **Source**: Extracted from `folder_slug` in uloz.to API response
- **Example**: `GEFnb4LJpFyS`

**Use Cases:**
- Navigate to the original folder on uloz.to
- Organize episodes by folder structure
- Batch operations on files in the same folder
- Maintain folder hierarchy for multi-season shows
- Quick access to related files in the same folder

## Schema Changes

### Database (Prisma)
```prisma
model MovieEpisode {
  // ... existing fields ...
  
  // Media
  thumbnailUrl     String? @map("thumbnail_url") @db.Text
  videoPreviewUrl  String? @map("video_preview_url") @db.Text  // ← NEW
  duration         Int?    // In seconds
  
  // File Source (uloz.to)
  source           ContentSource @default(ULOZ)
  slug             String?       @db.VarChar(500)
  folderSlug       String?       @map("folder_slug") @db.VarChar(500)  // ← NEW
  parentFolderSlug String?       @map("parent_folder_slug") @db.VarChar(500)
  
  // ... other fields ...
}
```

### Backend (TypeScript)
```typescript
interface UlozFile {
  slug: string;
  name: string;
  extension: string;
  size: number;
  contentType: string;
  description?: string;
  duration?: number;
  thumbnail?: string;
  videoPreview?: string;  // ← NEW
  folderSlug?: string;    // ← NEW
  url: string;
}
```

### Mobile App (Dart)
```dart
class MovieEpisode {
  final String? thumbnailUrl;
  final String? videoPreviewUrl;  // ← NEW
  final int? duration;
  
  final String? slug;
  final String? folderSlug;       // ← NEW
  final String? parentFolderSlug;
  
  // ... other fields ...
}
```

## Data Flow

### 1. uloz.to API Response
```json
{
  "slug": "YINK3siyuOvV",
  "folder_slug": "GEFnb4LJpFyS",
  "preview_info": {
    "small_image": "https://previewer.greencdn.link/img/YINK3siyuOvV.webp",
    "video": "https://previewer.greencdn.link/vd/YINK3siyuOvV.webm",
    "large_image": "..."
  }
}
```

### 2. Backend Extraction (ulozService.ts)
```typescript
// Extract video preview (animated preview)
const videoPreview = fileData.preview_info?.video || null;

// Extract folder slug
const folderSlug = fileData.folder_slug || null;

return {
  // ... other fields ...
  videoPreview: videoPreview,
  folderSlug: folderSlug,
};
```

### 3. Backend Storage (movieController.ts)
```typescript
const newEpisode = await prisma.movieEpisode.create({
  data: {
    // ... other fields ...
    thumbnailUrl: fileInfo.thumbnail || null,
    videoPreviewUrl: fileInfo.videoPreview || null,  // ← NEW
    folderSlug: fileInfo.folderSlug || null,          // ← NEW
    source: 'ULOZ',
  },
});
```

### 4. Mobile App Display (MovieEpisode)
```dart
final episode = MovieEpisode(
  thumbnailUrl: json['thumbnailUrl'],
  videoPreviewUrl: json['videoPreviewUrl'],  // ← NEW
  folderSlug: json['folderSlug'],             // ← NEW
  // ... other fields ...
);
```

## Migration Applied

```bash
npx prisma db push
```

**Result:**
- ✅ Added `video_preview_url` column to `movie_episodes` table
- ✅ Added `folder_slug` column to `movie_episodes` table
- ✅ Existing data preserved
- ✅ Prisma Client regenerated

## Testing

### Import Episode with New Fields
```bash
node import-episodes.js ed5d01af-74ae-4943-b490-a25cc8a1966d YINK3siyuOvV
```

**Expected Output:**
```json
{
  "success": true,
  "message": "Imported 1 episode(s)",
  "data": [{
    "id": "...",
    "title": "2gether The Movie 2021 WEB-DL 1080p...",
    "thumbnailUrl": "https://previewer.greencdn.link/img/YINK3siyuOvV.webp",
    "videoPreviewUrl": "https://previewer.greencdn.link/vd/YINK3siyuOvV.webm",
    "folderSlug": "GEFnb4LJpFyS",
    "duration": 6680,
    "fileSize": "1237080383"
  }]
}
```

### Verify in Database
```sql
SELECT 
  title, 
  thumbnail_url, 
  video_preview_url, 
  folder_slug, 
  duration, 
  file_size
FROM movie_episodes
WHERE slug = 'YINK3siyuOvV';
```

## Future Use Cases

### Video Preview (videoPreviewUrl)
1. **Hover Preview**: Show animated preview when hovering over episode cards
2. **Quick Preview**: "Peek" button to preview without opening player
3. **Preview Mode**: Watch multiple previews in a carousel
4. **Bandwidth Saver**: Use preview for slow connections

### Folder Slug (folderSlug)
1. **Folder Navigation**: Link to browse all files in the folder
2. **Batch Import**: Import all episodes from the same folder
3. **Related Content**: Show other files from the same folder
4. **Organization**: Group episodes by folder structure
5. **Season Detection**: Use folder structure to detect seasons

## Example Implementation

### Display Video Preview on Hover
```dart
// In movie detail screen
Widget _buildEpisodeCard(MovieEpisode episode) {
  return MouseRegion(
    onEnter: (_) {
      if (episode.videoPreviewUrl != null) {
        // Start playing video preview
        _showPreview(episode.videoPreviewUrl!);
      }
    },
    onExit: (_) {
      // Stop video preview, show thumbnail
      _hidePreview();
    },
    child: EpisodeCard(episode: episode),
  );
}
```

### Browse Folder Contents
```dart
// In episode options menu
if (episode.folderSlug != null) {
  ListTile(
    leading: Icon(Icons.folder),
    title: Text('Browse Folder'),
    onTap: () {
      // Fetch all files in this folder
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FolderBrowserScreen(
            folderSlug: episode.folderSlug!,
          ),
        ),
      );
    },
  );
}
```

## Files Changed

### Backend
- ✅ `prisma/schema.prisma` - Added fields to MovieEpisode model
- ✅ `src/services/ulozService.ts` - Extract videoPreview and folderSlug
- ✅ `src/controllers/movieController.ts` - Save new fields to database

### Mobile App
- ✅ `lib/models/movie_model.dart` - Added fields to MovieEpisode class

### Documentation
- ✅ `VIDEO_PREVIEW_AND_FOLDER_FIELDS.md` - This file

## Summary

These two fields provide additional metadata from uloz.to that can be used for:
- **Enhanced UX**: Animated video previews
- **Better Navigation**: Folder structure preservation
- **Future Features**: Batch operations, related content discovery
- **Performance**: Preview options for different network conditions

All fields are optional and won't break existing functionality. The server and mobile app are now ready to use these fields when implementing new features!

