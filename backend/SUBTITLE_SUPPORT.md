# Subtitle Support Implementation ✅ COMPLETED

## Overview
Full subtitle support has been implemented for the Library feature, including:
- ✅ Auto-detection and import of subtitle files from uloz.to folders
- ✅ Database schema with Subtitle model
- ✅ Backend API for subtitle stream URL extraction
- ✅ Mobile app subtitle selection and display
- ✅ Subtitle rendering with HTML tag support and non-Latin characters
- ✅ Direct subtitle download to device storage
- ✅ Always-visible subtitle overlay (independent of player controls)

## Database Changes

### New Table: `subtitles`
```prisma
model Subtitle {
  id        String   @id @default(uuid())
  episodeId String   @map("episode_id")
  
  // Subtitle Info
  language  String   // ISO 639-2 code (eng, tha, jpn, etc.)
  label     String   // Display name (English, Thai, Japanese, etc.)
  
  // File Info
  slug      String
  fileUrl   String
  source    ContentSource @default(ULOZ)
  
  // Relations
  episode   MovieEpisode @relation(fields: [episodeId], references: [id], onDelete: Cascade)
}
```

### Updated: `MovieEpisode`
- Added `subtitles` relation: `Subtitle[]`

## Migration Steps

1. **Run Prisma migration:**
   ```bash
   cd backend
   npx prisma db push
   ```

2. **Verify schema:**
   ```bash
   npx prisma studio
   ```

## Subtitle File Naming Convention

Subtitles must follow this naming pattern:
- `<video_filename>.<language_code>.srt`
- `<video_filename>.srt` (defaults to English)

**Examples:**
- Video: `movie.mp4`
- English subtitle: `movie.eng.srt`
- Thai subtitle: `movie.tha.srt`
- Japanese subtitle: `movie.jpn.srt`

**Supported Languages:**
Over 100+ languages are supported with automatic detection and flag emoji display. Common examples:
- `eng` 🇬🇧 - English
- `tha` 🇹🇭 - Thai
- `jpn` 🇯🇵 - Japanese
- `kor` 🇰🇷 - Korean
- `chi/zho` 🇨🇳🇹🇼 - Chinese
- `spa` 🇪🇸 - Spanish
- `fre/fra` 🇫🇷 - French
- `ger/deu` 🇩🇪 - German
- `ita` 🇮🇹 - Italian
- `por` 🇵🇹 - Portuguese
- `rus` 🇷🇺 - Russian
- `ara` 🇸🇦 - Arabic
- `hin` 🇮🇳 - Hindi
- `vie` 🇻🇳 - Vietnamese
- And 80+ more languages...

## Backend Features

### Auto-Detection ✅
- Scans folder for `.srt` files (primary support)
- Matches subtitles to videos by base filename
- Extracts language code from filename (e.g., `.eng.srt`, `.tha.srt`)
- Imports all matching subtitles automatically
- Prevents duplicate imports based on episodeId + slug
- File URL format: `https://uloz.to/file/SLUG`

### Stream URL Extraction ✅
New endpoint: `GET /api/v1/movies/:movieId/episodes/:episodeId/subtitles/:subtitleId/stream`
- Extracts actual download/stream URL from uloz.to using the subtitle slug
- Uses same authentication flow as video episodes
- Returns streamUrl for direct subtitle file download

### API Response
Episode data now includes subtitles array:
```json
{
  "id": "...",
  "title": "Episode 1",
  "subtitles": [
    {
      "id": "...",
      "language": "eng",
      "label": "English",
      "slug": "...",
      "fileUrl": "..."
    },
    {
      "id": "...",
      "language": "tha",
      "label": "Thai",
      "slug": "...",
      "fileUrl": "..."
    }
  ]
}
```

## Import Behavior

When importing episodes:
1. Video files are detected
2. Subtitle files (.srt) are filtered
3. Subtitles are matched to videos by base filename
4. All matching subtitles are created with the episode
5. Console shows subtitle import status

**Example Output:**
```
📁 Importing folder as episodes...
   Found 13 video files and 39 subtitle files
   ✅ Creating episode 1: video.mp4
      📝 Creating 3 subtitle(s)
      - English (eng)
      - Thai (tha)
      - Japanese (jpn)
```

## Mobile App Features ✅

### 1. Data Models ✅
- `Subtitle` class in `movie_model.dart` with all fields
- `MovieEpisode` includes `subtitles` list
- Flag emoji mapping for 100+ languages via `flagEmoji` getter

### 2. Movie Detail Screen ✅
- Displays flag emojis for available subtitles (no download at this stage)
- Compact display with 14px flag size
- Pull-to-refresh support

### 3. Movie Player Screen ✅
**Player Controls:**
- CC (Closed Caption) button in bottom controls
- Button turns yellow when subtitle is active
- Opens scrollable modal bottom sheet for subtitle selection
- Auto-loads English subtitle (or first available) by default

**Episode List in Player:**
- Download icon for episode video
- Flag emojis with download icons for each subtitle
- Direct download to device storage with progress tracking

**Subtitle Display:**
- Always-visible subtitle overlay (independent of control visibility)
- Positioned near bottom of screen
- Moves up slightly when controls are visible
- Semi-transparent background (55% opacity)
- Large, readable font (17px) with shadow for contrast

**Subtitle Rendering:**
- HTML tag stripping (`<i>`, `<b>`, `<br>`, etc.)
- HTML entity unescaping using `html_unescape` package
- UTF-8 encoding support for non-Latin characters (Chinese, Japanese, Thai, etc.)
- Multi-line support with proper text wrapping

### 4. Direct Download Feature ✅
**File Downloads:**
- Episodes and subtitles can be downloaded directly
- Saves to public "Download" folder on Android
- Saves to app documents on iOS
- Requires `MANAGE_EXTERNAL_STORAGE` permission on Android 11+

**Progress Tracking:**
- Persistent SnackBar at bottom during download
- Real-time progress bar with percentage
- Downloaded bytes / Total bytes display
- Cancel button to abort download
- User can continue watching while downloading

**Implementation:**
- Uses `dio` package for downloads with progress callbacks
- Uses `path_provider` for directory resolution
- Uses `permission_handler` for storage permissions
- Automatic file name sanitization and uniqueness

## Testing

1. **Import with subtitles:**
   ```bash
   node import-episodes.js <movie-id> <folder-slug>
   ```

2. **Check database:**
   - Open Prisma Studio
   - Navigate to `Subtitle` table
   - Verify subtitles are linked to episodes

3. **Check API:**
   ```bash
   curl http://localhost:3000/api/v1/movies/<movie-id>
   ```
   - Verify `subtitles` array in episode data

## Implementation Summary

### Completed Features ✅
- [x] Database schema with Subtitle model
- [x] Backend auto-detection and import of subtitles
- [x] Backend API for subtitle stream URL extraction
- [x] Mobile app data models
- [x] Subtitle selection UI in player
- [x] Subtitle display with proper rendering
- [x] Direct subtitle download to device
- [x] Progress tracking for downloads
- [x] HTML tag and entity support
- [x] Non-Latin character support (UTF-8)
- [x] Always-visible subtitle overlay
- [x] Auto-load English subtitle by default
- [x] Duplicate prevention during import

### Technical Stack
**Backend:**
- Node.js + TypeScript
- Express.js
- Prisma ORM
- PostgreSQL
- Uloz.to API integration

**Mobile:**
- Flutter + Dart
- Riverpod (state management)
- video_player (playback)
- dio (downloads)
- path_provider (file system)
- permission_handler (storage access)
- html_unescape (subtitle rendering)

### Known Limitations
- Primary support for `.srt` format (most common)
- Subtitle sync offset adjustment not yet implemented (future enhancement)
- Cloud storage/caching not implemented (downloads are to local device only)

### Future Enhancements (Optional)
- [ ] Subtitle sync controls (offset adjustment in player)
- [ ] Support for .vtt, .ass, .ssa subtitle formats
- [ ] Cloud backup of downloaded subtitles
- [ ] Subtitle search/download from external sources
- [ ] User-uploaded subtitle support

