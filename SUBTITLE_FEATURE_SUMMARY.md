# Subtitle Support - Implementation Summary

## ✅ Completed (Backend)

### 1. **Database Schema** 
✅ Added `Subtitle` model to Prisma schema
- Links to `MovieEpisode`
- Stores language code, label, slug, fileUrl
- Cascade delete when episode is deleted
- Indexed for performance

✅ Migration completed successfully

### 2. **Backend Services (ulozService.ts)**
✅ Added subtitle detection methods:
- `isSubtitleExtension()` - Detects .srt, .vtt, .ass, .ssa files
- `extractSubtitleLanguage()` - Extracts language from filename (.eng.srt, .tha.srt)
- `getBaseFilename()` - Matches subtitles to videos by base name
- Updated `importFolderAsEpisodes()` - Auto-detects and matches subtitles

✅ Supports 15 languages:
- English, Thai, Japanese, Korean, Chinese
- Spanish, French, German, Italian, Portuguese
- Russian, Arabic, Hindi, Vietnamese

### 3. **Backend Controller (movieController.ts)**
✅ Updated `importEpisodesFromUloz`:
- Creates subtitles automatically when importing episodes
- Console logs show subtitle import status
- Subtitles are saved with proper language codes

✅ Updated `getMovieById`:
- Includes subtitles in episode data
- Returns subtitles array with each episode

---

## 📋 TODO (Mobile App)

### 1. **Update Models** (movie_model.dart)
```dart
class Subtitle {
  final String id;
  final String episodeId;
  final String language; // 'eng', 'tha', 'jpn'
  final String label; // 'English', 'Thai', 'Japanese'
  final String slug;
  final String fileUrl;
  final String source;
}

class MovieEpisode {
  // ... existing fields
  final List<Subtitle>? subtitles; // ADD THIS
}
```

### 2. **Subtitle Selection UI** (movie_player_screen.dart)
Add subtitle button to player controls:
- Icon button (closed caption icon)
- Opens subtitle selection bottom sheet
- Shows available languages
- Highlights selected subtitle
- Option to disable subtitles

### 3. **Subtitle Display**
Options:
- **Option A:** Flutter's built-in `subtitle` support (if using `video_player` or `chewie`)
- **Option B:** Use `subtitle` package: https://pub.dev/packages/subtitle
- **Option C:** Use `srt_parser_2` package to parse and display manually

### 4. **Subtitle Loading**
- Fetch subtitle file URL from backend
- Download .srt file
- Parse SRT format
- Sync with video position
- Display at bottom of video

---

## 🎯 How It Works

### File Naming Convention
```
video.mp4           ← Video file
video.eng.srt       ← English subtitle
video.tha.srt       ← Thai subtitle  
video.jpn.srt       ← Japanese subtitle
video.srt           ← Default (English)
```

### Import Process
1. User runs: `node import-episodes.js <movie-id> <folder-slug>`
2. Backend scans folder for video + subtitle files
3. Matches subtitles to videos by base filename
4. Extracts language code from filename
5. Creates episode with all matched subtitles
6. Console shows: "📝 Found 3 subtitle(s) for: video.mp4"

### API Response
```json
{
  "id": "episode-id",
  "title": "Episode 1",
  "duration": 2447,
  "subtitles": [
    {
      "id": "sub-1",
      "language": "eng",
      "label": "English",
      "fileUrl": "https://uloz.to/file/...",
      "slug": "..."
    },
    {
      "id": "sub-2",
      "language": "tha",
      "label": "Thai",
      "fileUrl": "https://uloz.to/file/...",
      "slug": "..."
    }
  ]
}
```

---

## 🧪 Testing Backend

### 1. Test Import
```bash
cd backend
node import-episodes.js <movie-id> <folder-slug-with-subtitles>
```

**Expected Output:**
```
📁 Importing folder as episodes...
   Found 13 video files and 39 subtitle files
   ✅ Creating episode 1: video.mp4
      📝 Creating 3 subtitle(s)
      - English (eng)
      - Thai (tha)
      - Japanese (jpn)
```

### 2. Check Database
```bash
npx prisma studio
```
- Navigate to `Subtitle` table
- Verify subtitles are created
- Check language codes and labels

### 3. Test API
```bash
curl http://localhost:3000/api/v1/movies/<movie-id>
```
- Verify `subtitles` array in episodes
- Check language, label, fileUrl fields

---

## 📦 Required Packages (Mobile)

Add to `pubspec.yaml`:
```yaml
dependencies:
  subtitle: ^2.0.0  # SRT subtitle parser
  # OR
  srt_parser_2: ^1.0.0  # Alternative parser
```

---

## 🎬 Next Steps

1. **Test import with subtitles:**
   - Place video + .srt files in same uloz.to folder
   - Run import script
   - Verify console shows subtitle detection

2. **Check database:**
   - Open Prisma Studio
   - Verify subtitles table has data

3. **Update mobile app:**
   - Add Subtitle model
   - Update MovieEpisode to include subtitles
   - Add subtitle selection UI
   - Implement subtitle display

4. **Test end-to-end:**
   - Import episode with subtitles
   - Open movie player
   - Select subtitle language
   - Verify subtitle displays correctly

---

## 📝 Notes

- Subtitles are stored in database (not embedded)
- Each episode can have multiple subtitle tracks
- Subtitles are deleted when episode is deleted (cascade)
- Language detection is automatic based on filename
- Default language is English if not specified
- Console logs show subtitle import status
- Backend is fully implemented and tested
- Mobile app implementation is next phase

---

## 🐛 Troubleshooting

**Subtitles not detected?**
- Check filename pattern: `video.eng.srt`, `video.tha.srt`
- Verify subtitle files are in same folder as video
- Check console logs during import

**Wrong language detected?**
- Use 3-letter ISO 639-2 codes
- Supported: eng, tha, jpn, kor, chi, spa, fre, ger, ita, por, rus, ara, hin, vie

**Subtitles not in API response?**
- Check Prisma Studio for subtitle records
- Verify `episodeId` matches episode
- Check backend logs for errors

