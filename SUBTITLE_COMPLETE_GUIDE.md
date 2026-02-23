# Subtitle Support - Complete Implementation Guide

**Doc status:** Canonical (current source of truth)

Older backend-only summary (may contain outdated TODOs):
- [SUBTITLE_FEATURE_SUMMARY.md](./SUBTITLE_FEATURE_SUMMARY.md) (archived stub; previous content in git history)

## ✅ Implementation Complete!

### **Backend** ✅
- Database schema with `Subtitle` table
- Auto-detection of subtitle files (.srt, .vtt, .ass, .ssa)
- Matching subtitles to videos by filename
- Language extraction from filename
- 100+ language support
- Duplicate prevention for subtitles
- API returns subtitles with episodes

### **Mobile App** ✅
- Subtitle model with flag emojis
- Download buttons in movie detail screen
- Subtitle selection in movie player
- Real-time subtitle display during playback
- SRT/VTT parser
- Subtitle sync with video position

### Fixes Included
- ✅ Subtitle selector bottom sheet overflow resolved
- ✅ Subtitle loading via backend stream URL (avoids direct `fileUrl` 404s)
- ✅ Auto-loads English subtitles when available

---

## 🎬 Features

### 1. **Movie Detail Screen**
- Shows subtitle download buttons below each episode
- Displays flag emoji + language code + download icon
- Example: `🇬🇧 ENG ⬇️  🇹🇭 THA ⬇️  🇯🇵 JPN ⬇️`
- Clicking downloads subtitle file from uloz.to

### 2. **Movie Player Screen**
- Subtitle button (CC icon) in player controls
- Icon turns **yellow** when subtitle is active
- Opens subtitle selector bottom sheet
- Shows all available languages with flag emojis
- Displays subtitle text at bottom of video
- Auto-syncs with video playback

---

## 📁 File Naming Convention

**Required format for auto-detection:**

```
video.mp4           ← Video file
video.eng.srt       ← English subtitle
video.tha.srt       ← Thai subtitle
video.jpn.srt       ← Japanese subtitle
video.ara.srt       ← Arabic subtitle
video.srt           ← Default (English)
```

**Naming rules:**
- Base filename must match (case-insensitive)
- Language code must be 3 letters
- Supported formats: `.srt`, `.vtt`, `.ass`, `.ssa`

---

## 🌍 Supported Languages (100+)

### Common (17)
- 🇬🇧 English (eng)
- 🇹🇭 Thai (tha)
- 🇯🇵 Japanese (jpn)
- 🇰🇷 Korean (kor)
- 🇨🇳 Chinese Simplified (chi)
- 🇹🇼 Chinese Traditional (zho)
- 🇪🇸 Spanish (spa)
- 🇫🇷 French (fre/fra)
- 🇩🇪 German (ger/deu)
- 🇮🇹 Italian (ita)
- 🇵🇹 Portuguese (por)
- 🇷🇺 Russian (rus)
- 🇸🇦 Arabic (ara)
- 🇮🇳 Hindi (hin)
- 🇻🇳 Vietnamese (vie)
- 🇳🇱 Dutch (dut/nld)
- 🇵🇱 Polish (pol)

### European (30+)
Czech, Hungarian, Greek, Romanian, Turkish, Swedish, Norwegian, Danish, Finnish, Ukrainian, Slovak, Bulgarian, Croatian, Serbian, Slovenian, Estonian, Latvian, Lithuanian, Icelandic, Irish, Welsh, Scots Gaelic, Basque, Catalan, Galician, Maltese, Luxembourgish, and more

### Asian (20+)
Filipino, Indonesian, Malay, Burmese, Khmer, Lao, Bengali, Tamil, Telugu, Urdu, Malayalam, Kannada, Marathi, Gujarati, Punjabi, Odia, Assamese, Nepali, Sinhala, Mongolian, Tibetan

### Other (20+)
Hebrew, Persian, Georgian, Armenian, Azerbaijani, Kazakh, Uzbek, Tajik, Pashto, Kurdish, Amharic, Swahili, Hausa, Yoruba, Zulu, Afrikaans, Maori, Hawaiian, Samoan, Tongan, Fijian

**Fallback:** Any unrecognized 3-letter code displays as uppercase

---

## 🧪 Testing Guide

### **Step 1: Prepare Test Data**

Upload to uloz.to folder with this structure:
```
my-folder/
  ├── episode01.mp4
  ├── episode01.eng.srt
  ├── episode01.tha.srt
  ├── episode01.jpn.srt
  ├── episode02.mp4
  ├── episode02.eng.srt
  ├── episode02.tha.srt
  └── ...
```

### **Step 2: Import Episodes**

```bash
cd backend
node import-episodes.js <movie-id> <folder-slug>
```

**Expected console output:**
```
📁 Importing folder as episodes...
   Found 2 video files and 6 subtitle files

   ✅ Creating episode 1: episode01.mp4
      📝 Added 3 subtitle(s)
      - English (eng)
      - Thai (tha)
      - Japanese (jpn)

   ✅ Creating episode 2: episode02.mp4
      📝 Added 3 subtitle(s)
      - English (eng)
      - Thai (tha)
      - Japanese (jpn)

✅ Successfully imported 2 new episode(s) from folder
```

### **Step 3: Verify Database**

```bash
npx prisma studio
```

1. Open `Subtitle` table
2. Verify records exist
3. Check fields:
   - `language`: eng, tha, jpn, etc.
   - `label`: English, Thai, Japanese, etc.
   - `fileUrl`: https://uloz.to/file/{slug}
   - `episodeId`: matches episode

### **Step 4: Test Mobile App**

#### A. Check Movie Detail Screen
1. Open movie with subtitles
2. Pull to refresh
3. **You should see subtitle buttons below each episode:**
   ```
   Episode 1: Episode Title
   40m
   
   🇬🇧 ENG ⬇️  🇹🇭 THA ⬇️  🇯🇵 JPN ⬇️
   ```
4. Tap a subtitle button → Opens uloz.to in browser to download

#### B. Test Movie Player
1. Tap an episode to play
2. **Check player controls:**
   - Mute button (🔊)
   - **Subtitle button (CC)** ← Should be visible
   - Fullscreen button (⛶)

3. **Tap the subtitle button (CC)**
   - Bottom sheet opens
   - Shows "Select Subtitle" title
   - Lists all available subtitles:
     ```
     ✕ Off
     ─────────────
     🇬🇧 English
        ENG
     🇹🇭 Thai
        THA
     🇯🇵 Japanese
        JPN
     ```

4. **Select a subtitle (e.g., English)**
   - Bottom sheet closes
   - SnackBar shows: "Loaded English subtitle"
   - **CC icon turns yellow** 🟡
   - **Subtitle text appears at bottom of video**

5. **Play the video**
   - Subtitle text updates as video plays
   - Text is synchronized with video position
   - Text has black background for readability

6. **Turn off subtitle**
   - Tap CC button again
   - Select "Off"
   - Subtitle text disappears
   - CC icon turns white

7. **Switch subtitles**
   - Tap CC button
   - Select different language (e.g., Thai)
   - New subtitle loads and displays

8. **Change episode**
   - Tap different episode from list
   - Subtitle persists (or shows message if not available)
   - Can select subtitle for new episode

---

## 🎨 UI Elements

### Movie Detail Screen - Episode Card
```
┌────────────────────────────────────┐
│ [Thumbnail]  Episode Title         │
│ [Play Icon]  40m                   │
│                                    │
│  🇬🇧 ENG ⬇️  🇹🇭 THA ⬇️  🇯🇵 JPN ⬇️  │  ← Subtitle buttons
└────────────────────────────────────┘
```

### Movie Player - Controls
```
Progress Bar ═══════════░░░░░░

0:45 / 1:30:00   [🔊] [CC]🟡 [⛶]
                       ↑
                  Yellow when active
```

### Movie Player - Subtitle Selector
```
┌───────────────────────────┐
│ Select Subtitle           │
├───────────────────────────┤
│ ✕  Off                ✓   │  ← Currently off
├───────────────────────────┤
│ 🇬🇧 English               │
│    ENG                    │
│                           │
│ 🇹🇭 Thai                  │
│    THA                    │
│                           │
│ 🇯🇵 Japanese              │
│    JPN                    │
│                           │
│ 🇦🇪 Arabic                │
│    ARA                    │
└───────────────────────────┘
```

### Movie Player - Subtitle Display
```
┌─────────────────────────────────┐
│                                 │
│      [Video Playing]            │
│                                 │
│  ┌───────────────────────────┐  │
│  │   This is subtitle text   │  │  ← Subtitle overlay
│  └───────────────────────────┘  │
│                                 │
│  ═══════════░░░░  0:45 / 1:30   │
└─────────────────────────────────┘
```

---

## 🔧 Technical Details

### Subtitle Parsing
- **Format:** SRT (SubRip) and VTT (WebVTT)
- **Encoding:** UTF-8
- **Time sync:** Millisecond precision
- **Display:** Auto-updates based on video position

### File Download
- **Method:** Opens uloz.to in external browser
- **Package:** `url_launcher`
- **Mode:** External application
- **Feedback:** SnackBar confirmation

### Data Flow
```
uloz.to folder
    ↓
Backend detects subtitle files
    ↓
Matches to videos by filename
    ↓
Saves to database
    ↓
API returns with episodes
    ↓
Mobile app displays download buttons
    ↓
User taps CC in player
    ↓
Downloads subtitle from uloz.to
    ↓
Parses SRT format
    ↓
Displays synchronized with video
```

---

## 🐛 Troubleshooting

### Subtitles not detected during import?
**Check:**
- ✅ Filename pattern: `video.eng.srt`, `video.tha.srt`
- ✅ Files in same folder as video
- ✅ Console logs show subtitle detection
- ✅ Language code is 3 letters

**Solution:**
- Rename files to match pattern
- Re-import folder

### Subtitles not showing in mobile app?
**Check:**
- ✅ Pull to refresh movie detail screen
- ✅ Database has subtitle records (Prisma Studio)
- ✅ API response includes subtitles array
- ✅ Model parsing is working (check console logs)

**Solution:**
- Restart mobile app
- Check API response in browser
- Verify model includes subtitles field

### Subtitle button not visible in player?
**Check:**
- ✅ Episode has subtitles
- ✅ `_currentEpisode.subtitles` is not null/empty
- ✅ CC button is in controls

**Solution:**
- Ensure episode was imported with subtitles
- Check episode data in database

### Subtitle text not appearing?
**Check:**
- ✅ Subtitle file downloaded successfully
- ✅ Parser returned items
- ✅ `_subtitleItems` is not empty
- ✅ Video position is within subtitle time range

**Solution:**
- Check console logs for parsing errors
- Verify SRT format is valid
- Test with different subtitle file

### Subtitle out of sync?
**Possible causes:**
- Video has intro/credits that subtitle doesn't account for
- SRT file has incorrect timing
- Different video version

**Solution:**
- Use matching subtitle file for video version
- Edit SRT file timing if needed

---

## 📋 Import Script Enhancement

**Console output now shows:**
```bash
$ node import-episodes.js <movie-id> <folder-slug>

✅ Logged in successfully

🎬 Movie: My Series (TV_SERIES)

📥 Importing from uloz.to...
   URL/Slug: <folder-slug>
   Season: 1

🔍 Auto-detecting type for: <folder-slug>
   ✅ Detected as: FOLDER

📁 Importing folder as episodes...
   Found 13 video files and 221 subtitle files  ← Total counts

   ✅ Creating episode 1: video01.mp4
      📝 Added 17 subtitle(s)                    ← Per-episode count
      - English (eng)
      - Thai (tha)
      - Japanese (jpn)
      - Arabic (ara)
      - French (fre)
      - German (ger)
      - Greek (gre)
      - Hindi (hin)
      - Chinese (chi)
      - Italian (ita)
      - Polish (pol)
      - Portuguese (por)
      - Romanian (rum)
      - Spanish (spa)
      - Turkish (tur)
      - Czech (cze)
      - Dutch (dut)

   ✅ Creating episode 2: video02.mp4
      📝 Added 17 subtitle(s)
      ...

✅ Successfully imported 13 new episode(s) from folder

📊 Total files imported: 13

🎉 Import complete! Refresh your mobile app to see the files.
```

---

## 🎯 User Workflow

### **Workflow 1: Download Subtitle**
1. Open movie detail screen
2. Find episode
3. See subtitle buttons: `🇬🇧 ENG ⬇️  🇹🇭 THA ⬇️`
4. Tap desired language
5. Browser opens uloz.to
6. Download subtitle file
7. Use in external player

### **Workflow 2: Watch with Subtitles (In-App)**
1. Tap episode to open player
2. Tap **CC button** in controls
3. Select language from list
4. Subtitle appears at bottom
5. Watch with subtitles!
6. Tap CC again to change or turn off

---

## 📦 Files Modified

### Backend
- ✅ `prisma/schema.prisma` - Added Subtitle model
- ✅ `src/services/ulozService.ts` - Subtitle detection
- ✅ `src/controllers/movieController.ts` - Subtitle import

### Mobile App
- ✅ `lib/models/movie_model.dart` - Added Subtitle class
- ✅ `lib/utils/subtitle_parser.dart` - NEW: SRT/VTT parser
- ✅ `lib/screens/library/movie_detail_screen.dart` - Download buttons
- ✅ `lib/screens/library/movie_player_screen.dart` - Subtitle display

### Documentation
- ✅ `backend/SUBTITLE_SUPPORT.md`
- ⚠️ `SUBTITLE_FEATURE_SUMMARY.md` (archived stub; previous content in git history)
- ✅ `backend/SUBTITLE_IMPORT_FIXES.md`
- ✅ `SUBTITLE_COMPLETE_GUIDE.md`

---

## 🧪 Complete Testing Checklist

### Backend Testing
- [ ] Import folder with subtitles
- [ ] Console shows subtitle detection
- [ ] Database has subtitle records (Prisma Studio)
- [ ] API includes subtitles in response
- [ ] No duplicate subtitles on re-import
- [ ] New subtitles added to existing episodes
- [ ] All languages detected correctly
- [ ] fileUrl format: `https://uloz.to/file/{slug}`

### Mobile App - Movie Detail
- [ ] Hot reload app
- [ ] Open movie with subtitles
- [ ] Pull to refresh
- [ ] Subtitle buttons appear below episodes
- [ ] Flag emojis display correctly
- [ ] Tapping button opens browser
- [ ] uloz.to download page opens

### Mobile App - Player Controls
- [ ] Open player
- [ ] CC button visible in controls
- [ ] CC button is white (no subtitle)
- [ ] Tap CC button
- [ ] Bottom sheet opens
- [ ] "Off" option visible
- [ ] All subtitle languages listed
- [ ] Flag emojis correct
- [ ] Language codes shown

### Mobile App - Subtitle Display
- [ ] Select a subtitle language
- [ ] Bottom sheet closes
- [ ] SnackBar shows "Loaded [language] subtitle"
- [ ] CC button turns yellow
- [ ] Play video
- [ ] Subtitle text appears at bottom
- [ ] Text synchronized with video
- [ ] Text readable (black background, white text)
- [ ] Text updates as video plays

### Mobile App - Subtitle Management
- [ ] Tap CC button while subtitle active
- [ ] Current subtitle has checkmark
- [ ] Select different language
- [ ] New subtitle loads and displays
- [ ] Select "Off"
- [ ] Subtitle disappears
- [ ] CC button turns white
- [ ] Change to next episode
- [ ] Subtitle resets (or persists if available)

---

## 💡 Pro Tips

### For Best Results:
1. **Name files consistently:** Use same base name for video and subtitles
2. **Use standard codes:** Stick to ISO 639-2 codes (eng, tha, jpn, etc.)
3. **Test one file first:** Import single episode before batch import
4. **Check logs:** Console shows exactly what's being detected
5. **Refresh mobile app:** After import, pull to refresh movie detail

### Common File Patterns:
```
✅ GOOD:
   video.mp4, video.eng.srt, video.tha.srt
   Movie.2021.1080p.mkv
   Movie.2021.1080p.eng.srt
   Movie.2021.1080p.tha.srt

❌ BAD:
   video.mp4, video_eng.srt (underscore instead of dot)
   video.mp4, video.english.srt (full word instead of code)
   video.mp4, video-eng.srt (dash instead of dot)
```

---

## 🚀 What's Next?

### Optional Enhancements:
1. **Subtitle offset adjustment** - Allow users to adjust timing
2. **Subtitle styling** - Font size, color, background opacity
3. **Multiple subtitle display** - Show two languages simultaneously
4. **Auto-select subtitle** - Remember last used language
5. **Embedded subtitles** - Extract from MKV files
6. **Subtitle search** - Find and download from OpenSubtitles.org

---

## 📝 Summary

**Subtitle support is now fully functional!**

✅ **Auto-import** from uloz.to folders  
✅ **100+ languages** supported  
✅ **Download buttons** in detail screen  
✅ **In-app display** in video player  
✅ **Real-time sync** with playback  
✅ **No duplicates** on re-import  
✅ **Smart matching** by filename  
✅ **Clean URLs** for compatibility  

**Everything is ready to use! Import a folder with subtitle files and test it out!** 🎬✨

