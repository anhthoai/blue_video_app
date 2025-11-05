# Quick Start Guide - Library Feature

## 🚀 Step-by-Step Setup

### Step 1: Start Backend Server

Open a **NEW PowerShell terminal** in the backend folder:

```powershell
cd C:\Users\mrcool\Downloads\Programs\xlp_4.9.5_250929_1\blue_video_app\backend
npm run dev
```

**Wait for these messages:**
```
📚 Movie/Library routes registered at /api/v1/movies
✅ Blue Video API server running on port 3000
```

**KEEP THIS TERMINAL OPEN!**

---

### Step 2: Test API (New Terminal)

Open a **SECOND PowerShell terminal**, run:

```powershell
# Test server is responding
Invoke-RestMethod -Uri "http://localhost:3000/api/v1/movies"
```

**Expected response:**
```
success data    pagination
------- ----    ----------
   True {}      @{page=1; limit=20; total=0; totalPages=0}
```

---

### Step 3: Import Your First Movie

In the **SECOND terminal**, run this **single command**:

```powershell
Invoke-RestMethod -Uri "http://localhost:3000/api/v1/movies/import/imdb" -Method Post -ContentType "application/json" -Body '{"imdbId": "tt14452776"}'
```

**This imports Heartstopper** - a popular gay teen romance series.

**Expected response:**
```
Imported 1 of 1 movies
```

---

### Step 4: Verify Import

```powershell
Invoke-RestMethod -Uri "http://localhost:3000/api/v1/movies"
```

You should now see **1 movie** in the response!

---

### Step 5: Run Mobile App

Open a **THIRD terminal**:

```powershell
cd C:\Users\mrcool\Downloads\Programs\xlp_4.9.5_250929_1\blue_video_app\mobile-app
flutter run
```

---

### Step 6: View in App

1. Wait for app to launch on your device
2. Tap **Library** icon (2nd from left)
3. You'll see the **Movies** tab
4. **Pull down to refresh**
5. **Heartstopper** should appear!

---

## 🎬 Import More Movies

Once you have Heartstopper, try importing more:

### Single Import:
```powershell
# Young Royals (Swedish gay prince romance)
Invoke-RestMethod -Uri "http://localhost:3000/api/v1/movies/import/imdb" -Method Post -ContentType "application/json" -Body '{"imdbId": "tt13406036"}'

# Love, Simon (Gay coming-of-age movie)
Invoke-RestMethod -Uri "http://localhost:3000/api/v1/movies/import/imdb" -Method Post -ContentType "application/json" -Body '{"imdbId": "tt5164432"}'
```

### Batch Import (4 movies at once):
```powershell
$batchBody = '{"imdbIds": ["tt14452776", "tt13406036", "tt5164432", "tt5726616"]}'
Invoke-RestMethod -Uri "http://localhost:3000/api/v1/movies/import/imdb" -Method Post -ContentType "application/json" -Body $batchBody
```

---

## 🔍 Test Filters

After importing movies, test the filters in the mobile app:

1. Tap **TV Series** filter → Shows only TV series
2. Tap **Gay** in LGBTQ+ filter → Shows gay-themed content
3. Tap **Drama** in Genre filter → Shows dramas
4. Combine filters for precise results!

---

## ✅ What Should Work Now

- ✅ Clear white tab labels in Library header
- ✅ Movies screen with 3-tier filters
- ✅ Movie import from IMDb
- ✅ 2-column grid display
- ✅ Movie posters, titles, years
- ✅ Pull to refresh
- ✅ Filter combinations

---

## 🐛 Troubleshooting

### "Connection refused"
- Make sure Step 1 terminal is still running
- Check you see "Server running on port 3000"

### Import returns "Failed to import"
- Check backend terminal for error messages
- Verify TMDb API key is set in `.env`
- Try a different IMDb ID

### Movies don't show in app
- Make sure you pull down to refresh
- Check backend terminal shows successful import
- Try running: `Invoke-RestMethod -Uri "http://localhost:3000/api/v1/movies"`

---

## 📱 App Screenshots Expected

After importing Heartstopper:
1. Library screen shows "Movies" tab (white, bold)
2. Pull down to refresh
3. 2-column grid appears
4. Heartstopper poster shows with title "Heartstopper"
5. Shows "TV_SERIES" badge
6. Filter by "Gay" → Still shows Heartstopper
7. Filter by "Movie" → Heartstopper disappears (it's a TV series)

---

**Ready to test!** 🚀

Follow the steps above and you should have movies importing successfully!

