# Subtitle Import - Fixes Applied

## Issues Fixed

### 1. ✅ Subtitle URL Format
**Issue:** Subtitle URLs were using full path format:
```
/file/T5BgUsnYE5ZX/craving-you-s01e03-2020-1080p-viki-web-dl-aac-x264-rsg-hin-srt#!ZGt2...
```

**Fix:** Now using simple format like MovieEpisode:
```
https://uloz.to/file/T5BgUsnYE5ZX
```

**Code Location:** `ulozService.ts` line 473
```typescript
url: `https://uloz.to/file/${subtitleFile.slug}`, // Use simple format for subtitles
```

### 2. ✅ Comprehensive Language Support
**Issue:** Only 15 languages were supported

**Fix:** Added 100+ languages including:
- **European:** English, French, German, Italian, Spanish, Portuguese, Dutch, Polish, Czech, Hungarian, Greek, Romanian, Turkish, Swedish, Norwegian, Danish, Finnish, Ukrainian, Slovak, Bulgarian, Croatian, Serbian, Slovenian, Estonian, Latvian, Lithuanian, Icelandic, Irish, Welsh, Scots Gaelic, Basque, Catalan, Galician, Maltese, Luxembourgish, Afrikaans
- **Asian:** Japanese, Korean, Chinese (Simplified), Chinese (Traditional), Thai, Vietnamese, Hindi, Bengali, Tamil, Telugu, Urdu, Malayalam, Kannada, Marathi, Gujarati, Punjabi, Odia, Assamese, Nepali, Sinhala, Mongolian, Tibetan, Burmese, Khmer, Lao, Filipino, Indonesian, Malay
- **Middle Eastern:** Arabic, Hebrew, Persian, Georgian, Armenian, Azerbaijani, Kazakh, Uzbek, Tajik, Pashto, Kurdish, Turkish
- **African:** Amharic, Swahili, Hausa, Yoruba, Zulu, Afrikaans
- **Pacific:** Maori, Hawaiian, Samoan, Tongan, Fijian

**Fallback:** If language code is not in map, it displays as uppercase (e.g., "XYZ" → "XYZ")

**Code Location:** `ulozService.ts` lines 546-675

### 3. ✅ Duplicate Subtitle Prevention
**Issue:** No duplicate checking for subtitles

**Fix:** Implemented two-level duplicate checking:

#### A. For New Episodes
When creating a new episode:
```typescript
// Check if subtitle already exists (by episodeId + slug)
const existingSubtitle = await prisma.subtitle.findFirst({
  where: {
    episodeId: newEpisode.id,
    slug: sub.slug,
  },
});

if (existingSubtitle) {
  skippedSubtitles++;
  continue; // Skip this subtitle
}
```

#### B. For Existing Episodes
When episode already exists but might have new subtitles:
```typescript
// Check if subtitle already exists in episode
const hasSubtitle = existingEpisode.subtitles.some(
  existing => existing.slug === sub.slug
);

if (!hasSubtitle) {
  // Add the new subtitle to existing episode
  await prisma.subtitle.create({ ... });
}
```

**Benefits:**
- No duplicate subtitles created
- Can add new subtitles to existing episodes
- Re-importing same folder won't create duplicates

**Code Location:** `movieController.ts` lines 260-323

---

## How It Works Now

### Import Flow

1. **Detect Files:**
   ```
   📁 Importing folder as episodes...
      Found 13 video files and 39 subtitle files
   ```

2. **Match Subtitles to Videos:**
   - Base filename matching: `video.mp4` ↔ `video.eng.srt`, `video.tha.srt`
   - Extract language code from filename (`.eng.`, `.tha.`, etc.)
   - Create subtitle URL: `https://uloz.to/file/{slug}`

3. **Import Episode (New):**
   ```
   ✅ Creating episode 1: video.mp4
      📝 Added 17 subtitle(s)
      - English (eng)
      - Thai (tha)
      - Japanese (jpn)
      ...
   ```

4. **Import Episode (Existing):**
   ```
   ⏭️  Episode already exists: video.mp4 (slug: ABC123)
      📝 Added 2 new subtitle(s) to existing episode
   ```

5. **Duplicate Subtitle Detection:**
   ```
   ⏭️  Episode already exists: video.mp4
      ⏭️  Skipped 15 duplicate subtitle(s)
      📝 Added 2 new subtitle(s) to existing episode
   ```

---

## Database Structure

### Subtitle Table
```sql
CREATE TABLE "subtitles" (
  "id" UUID PRIMARY KEY,
  "episode_id" UUID NOT NULL,
  "language" VARCHAR(10) NOT NULL,  -- ISO 639-2 code
  "label" VARCHAR(100) NOT NULL,    -- Display name
  "slug" VARCHAR(500) NOT NULL,
  "file_url" TEXT NOT NULL,         -- https://uloz.to/file/{slug}
  "source" VARCHAR(50) DEFAULT 'ULOZ',
  "created_at" TIMESTAMP DEFAULT NOW(),
  "updated_at" TIMESTAMP DEFAULT NOW(),
  
  FOREIGN KEY ("episode_id") REFERENCES "movie_episodes"("id") ON DELETE CASCADE
);

CREATE INDEX ON "subtitles" ("episode_id");
CREATE INDEX ON "subtitles" ("slug");
```

---

## API Response

### GET /api/v1/movies/:id

```json
{
  "success": true,
  "data": {
    "id": "...",
    "title": "Movie Title",
    "episodes": [
      {
        "id": "...",
        "title": "Episode 1",
        "subtitles": [
          {
            "id": "...",
            "language": "eng",
            "label": "English",
            "slug": "T5BgUsnYE5ZX",
            "fileUrl": "https://uloz.to/file/T5BgUsnYE5ZX",
            "source": "ULOZ"
          },
          {
            "id": "...",
            "language": "tha",
            "label": "Thai",
            "slug": "X2AbCdEfGh5I",
            "fileUrl": "https://uloz.to/file/X2AbCdEfGh5I",
            "source": "ULOZ"
          }
        ]
      }
    ]
  }
}
```

---

## Testing

### 1. Test with New Episodes
```bash
cd backend
node import-episodes.js <movie-id> <folder-slug>
```

**Expected:**
- Episode created
- All subtitles added
- Console shows subtitle count

### 2. Test with Existing Episodes (No New Subtitles)
Run same command again:

**Expected:**
```
⏭️  Episode already exists: video.mp4
   (no subtitle messages - all exist)
```

### 3. Test with Existing Episodes (New Subtitles Added)
Add new `.fra.srt` file to folder, then run import:

**Expected:**
```
⏭️  Episode already exists: video.mp4
   📝 Added 1 new subtitle(s) to existing episode
   - French (fra)
```

### 4. Verify Database
```bash
npx prisma studio
```

- Check `Subtitle` table
- Verify `fileUrl` format: `https://uloz.to/file/{slug}`
- Check `language` and `label` fields
- No duplicates

### 5. Test API
```bash
curl http://localhost:3000/api/v1/movies/<movie-id>
```

- Verify `subtitles` array in episodes
- Check URL format
- Verify all languages present

---

## Examples

### Supported Filename Patterns
```
video.eng.srt  → English
video.tha.srt  → Thai
video.jpn.srt  → Japanese
video.fra.srt  → French
video.deu.srt  → German
video.pol.srt  → Polish
video.cze.srt  → Czech
video.hun.srt  → Hungarian
video.tur.srt  → Turkish
video.ara.srt  → Arabic
video.hin.srt  → Hindi
video.chi.srt  → Chinese (Simplified)
video.zho.srt  → Chinese (Traditional)
video.kor.srt  → Korean
video.vie.srt  → Vietnamese
video.srt      → English (default)
```

### Console Output Example
```
📁 Importing folder as episodes...
   Found 13 video files and 221 subtitle files

   ✅ Creating episode 1: Craving.You.S01E01.mkv
      📝 Added 17 subtitle(s)
      - Arabic (ara)
      - Czech (cze)
      - Dutch (dut)
      - French (fre)
      - German (ger)
      - Greek (gre)
      - Hindi (hin)
      - Hungarian (hun)
      - Chinese (chi)
      - Italian (ita)
      - Japanese (jpn)
      - Polish (pol)
      - Portuguese (por)
      - Romanian (rum)
      - Spanish (spa)
      - English (eng)
      - Turkish (tur)

   ✅ Creating episode 2: Craving.You.S01E02.mkv
      📝 Added 17 subtitle(s)
      ...

✅ Successfully imported 13 new episode(s) from folder
```

---

## Summary

✅ **URL Format:** Simple `https://uloz.to/file/{slug}` format  
✅ **Languages:** 100+ languages supported with fallback  
✅ **Duplicates:** Complete duplicate prevention at subtitle level  
✅ **Smart Import:** Adds new subtitles to existing episodes  
✅ **Console Logs:** Clear feedback on what's being imported/skipped  

All fixes are backwards compatible and work seamlessly with existing import workflow! 🎬✨

