# Episode Import - Now Works for Movies! 🎬

## ✅ What's Fixed

### 1. **Supports MOVIE Type**
- ✅ Previously only worked for TV_SERIES
- ✅ Now works for MOVIE and SHORT types too
- ✅ Movies can have multiple files (main, behind scenes, teasers, etc.)

### 2. **Flexible URL/Slug Input**
- ✅ Full URLs: `https://uloz.to/file/xyz123`
- ✅ Just slugs: `YINK3siyuOvV`
- ✅ Auto-detects file vs folder
- ✅ Handles URL fragments (#!...)

### 3. **Full Filename Display**
- ✅ Shows complete filename if no title
- ✅ Example: "2gether-the-movie-2021-web-dl-1080p-aac-h-264-darrensstarkid.mkv"
- ✅ Useful for identifying different versions/qualities

### 4. **Movie Detail Screen Updated**
- ✅ Shows "Files" section for movies
- ✅ Shows "Episodes" section for TV series
- ✅ Flat list for movies (no season grouping)
- ✅ Grouped by season for TV series

---

## 🧪 Test Import Now!

### For Your Movie (2gether: The Movie)

You can use either:

**Option 1: Full URL**
```bash
node import-episodes.js ed5d01af-74ae-4943-b490-a25cc8a1966d https://uloz.to/file/YINK3siyuOvV/2gether-the-movie-2021-web-dl-1080p-aac-h-264-darrensstarkid-mkv 1 1
```

**Option 2: Just Slug (Easier!)**
```bash
node import-episodes.js ed5d01af-74ae-4943-b490-a25cc8a1966d YINK3siyuOvV 1 1
```

**Parameters:**
- `ed5d01af...` - Movie ID
- `YINK3siyuOvV` - uloz.to file slug
- `1` - Episode number (for movies, can use 1, 2, 3 for different files)
- `1` - Season number (default 1)

---

## 📱 What You'll See in Mobile App

### Before Import:
```
┌──────────────────────────────────┐
│   [Backdrop]                     │
│   "2gether: The Movie"           │
├──────────────────────────────────┤
│ [Poster] │ Type: Movie           │
│          │ ⭐ 7.3/10            │
│          │ 2021                 │
│          │ Music Romance Drama  │
├──────────────────────────────────┤
│ Overview                         │
│ (movie description...)           │
│                                  │
│ Cast                             │
│ (actors...)                      │
└──────────────────────────────────┘
```

### After Import:
```
┌──────────────────────────────────┐
│   [Backdrop]                     │
│   "2gether: The Movie"           │
├──────────────────────────────────┤
│ [Poster] │ Type: Movie           │
│          │ ⭐ 7.3/10            │
│          │ 2021                 │
│          │ Music Romance Drama  │
├──────────────────────────────────┤
│ Overview                         │
│ (movie description...)           │
│                                  │
│ Files ⭐ NEW!                    │
│ ┌────────────────────────────┐  │
│ │[Icon] 2gether-the-movie... │  │
│ │       1080p-aac-h-264...   │  │
│ │       2:15:30          [▶] │  │
│ └────────────────────────────┘  │
│                                  │
│ Cast                             │
│ (actors...)                      │
└──────────────────────────────────┘
```

---

## 💡 Use Cases for Multiple Files

### Movie with Extras:
```bash
# Main movie
node import-episodes.js <movie-id> slug-main-movie 1 1

# Behind the scenes
node import-episodes.js <movie-id> slug-behind-scenes 2 1

# Deleted scenes
node import-episodes.js <movie-id> slug-deleted-scenes 3 1

# Teaser/Trailer
node import-episodes.js <movie-id> slug-teaser 4 1
```

All will show in the "Files" section!

### TV Series with Seasons:
```bash
# Season 1 (entire folder)
node import-episodes.js <series-id> folder-season-1 1

# Season 2 (entire folder)  
node import-episodes.js <series-id> folder-season-2 2

# Add missing episode to season 1
node import-episodes.js <series-id> episode-5-slug 5 1
```

---

## 🔧 Technical Changes

### Backend (`importEpisodesFromUloz`)
- ✅ Added `url` parameter (universal)
- ✅ Auto-detects file vs folder
- ✅ Supports slugs without full URLs
- ✅ Keeps full filename as title
- ✅ Works for all content types

### ulozService
- ✅ `extractSlug()` now handles slugs directly
- ✅ `detectType()` method added
- ✅ Better URL parsing with # fragments

### Movie Detail Screen
- ✅ Shows "Files" for movies
- ✅ Shows "Episodes" for TV series
- ✅ Full filename display
- ✅ 2-line title support for long filenames

---

## 📝 Updated Import Command Format

### New Simplified Format:
```bash
node import-episodes.js <movie-id> <url-or-slug> [episode-number] [season-number]
```

### Examples:
```bash
# URL with fragments
node import-episodes.js abc-123 "https://uloz.to/file/xyz#!hash" 1 1

# Just slug
node import-episodes.js abc-123 xyz 1 1

# Folder URL
node import-episodes.js abc-123 https://uloz.to/folder/abc 1

# Folder slug
node import-episodes.js abc-123 abc 1
```

---

## 🎯 Your Next Steps

### 1. Import File for "2gether: The Movie"
```bash
node import-episodes.js ed5d01af-74ae-4943-b490-a25cc8a1966d YINK3siyuOvV 1 1
```

### 2. Refresh Mobile App
- Pull down to refresh
- Or restart app

### 3. Open Movie Details
- Tap on "2gether: The Movie"
- Scroll down
- See "Files" section with your video!
- Full filename displayed
- Tap to play (shows placeholder message)

---

## ✅ All Fixed!

| Issue | Status |
|-------|--------|
| Import for MOVIE type | ✅ Fixed |
| URL vs Slug support | ✅ Both work |
| Full filename display | ✅ Shows complete name |
| Auto-detect file/folder | ✅ Working |
| Movie detail screen | ✅ Updated |

**Try importing your movie file now!** 🎬

