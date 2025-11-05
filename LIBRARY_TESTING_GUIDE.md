# Library Feature Testing Guide 🎬

## ✅ What's Fixed

### 1. Header Visibility
- ✅ Tab labels now **white and bold** (previously hard to see)
- ✅ Unselected tabs: white with 60% opacity
- ✅ Selected tab: bright white with bold font
- ✅ White indicator line under selected tab
- ✅ Much better contrast on blue background

### 2. API Integration
- ✅ Created `MovieService` to fetch movies from backend
- ✅ Added API methods to `ApiService`:
  - `getMovies()` - with filters
  - `getMovieById()` - movie details
  - `getEpisodeStreamUrl()` - streaming URLs
- ✅ Movies screen now fetches real data from backend
- ✅ Loading states, error handling, retry button
- ✅ Grid updates when filters change

---

## 🧪 Testing Steps

### Step 1: Verify Backend is Running

```bash
# Should show "📚 Movie/Library routes registered"
# Check terminal where backend is running
```

You should see:
```
📚 Movie/Library routes registered at /api/v1/movies
✅ Blue Video API server running on port 3000
```

### Step 2: Test API Manually

```bash
# Test movies endpoint (should return empty array for now)
curl http://localhost:3000/api/v1/movies
```

Expected response:
```json
{
  "success": true,
  "data": [],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 0,
    "totalPages": 0
  }
}
```

### Step 3: Import a Test Movie

First, login to get auth token:
```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "your_email@example.com",
    "password": "your_password"
  }'
```

Copy the `accessToken` from response, then import a movie:

```bash
curl -X POST http://localhost:3000/api/v1/movies/import/imdb \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "imdbId": "tt14452776"
  }'
```

This imports **Heartstopper** (popular gay teen romance series).

### Step 4: Run Mobile App

```bash
cd blue_video_app/mobile-app
flutter run
```

### Step 5: Navigate to Library

1. Tap **Library** icon in bottom navigation (2nd icon)
2. You should see the **Movies** tab (white text on blue)
3. If you imported movies, they will appear in a 2-column grid
4. If no movies yet, you'll see "No movies yet" message

### Step 6: Test Filters

Try different filter combinations:
- Tap **TV Series** in Type filter
- Tap **Gay** in LGBTQ+ filter
- Tap **Drama** in Genre filter
- Movies will refresh automatically with each filter change

---

## 🎬 Popular BoyLove/Gay Content for Testing

Import these IMDb IDs to populate your library:

### TV Series (BoyLove/Gay)
```bash
# Heartstopper - British teen romance
curl -X POST http://localhost:3000/api/v1/movies/import/imdb \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"imdbId": "tt14452776"}'

# Young Royals - Swedish teen romance
curl -X POST http://localhost:3000/api/v1/movies/import/imdb \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"imdbId": "tt13406036"}'

# Batch import multiple
curl -X POST http://localhost:3000/api/v1/movies/import/imdb \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "imdbIds": ["tt14452776", "tt13406036", "tt10648342", "tt5164432"]
  }'
```

### Movies (BoyLove/Gay)
- **Love, Simon**: `tt5164432`
- **Call Me By Your Name**: `tt5726616`
- **Red, White & Royal Blue**: `tt14208870`
- **Moonlight**: `tt4975722`

---

## 🎨 Visual Improvements

### Before:
- Tab labels barely visible (grey on blue)
- Hard to see which tab is selected

### After:
- ✅ White, bold text for tabs
- ✅ Clear indicator line
- ✅ Easy to see active/inactive tabs
- ✅ Professional appearance

---

## 📱 Mobile App Features Working

- ✅ Library screen with 4 tabs (Movies active, others coming soon)
- ✅ Movies screen with 3-tier filters
- ✅ API integration with loading states
- ✅ 2-column grid layout
- ✅ Movie cards with posters
- ✅ Pull to refresh
- ✅ Error handling with retry
- ✅ Filter updates refresh data automatically

---

## 🐛 Troubleshooting

### "No movies yet" even after importing
- Check backend terminal for import success message
- Verify API call: `curl http://localhost:3000/api/v1/movies`
- Check mobile app console for API errors
- Ensure backend is running on port 3000

### Movies not loading in app
- Check mobile app API base URL configuration
- Verify network connectivity
- Check backend CORS settings
- Look at backend logs for 404/500 errors

### Import fails
- Verify TMDb API key is correct in `.env`
- Check if IMDb ID is valid
- Look at backend terminal for error messages
- Ensure you have valid auth token

---

## ✨ Next Steps

Once you have movies imported:

1. **Add Episodes** (for TV Series):
   ```bash
   curl -X POST http://localhost:3000/api/v1/movies/MOVIE_ID/episodes/import/uloz \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "folderUrl": "https://uloz.to/folder/YOUR_FOLDER",
       "seasonNumber": 1
     }'
   ```

2. **Create Movie Detail Screen**
   - Show full movie information
   - Display episode list (for TV series)
   - Play button to start watching

3. **Enhance Video Player**
   - Episode selector
   - Auto-play next episode
   - Episode navigation controls

---

## 🎉 Summary

**Both Issues Fixed:**
1. ✅ Header tabs now clearly visible (white text on blue)
2. ✅ App now calls `/api/v1/movies` and displays data
3. ✅ Filters work and refresh data automatically
4. ✅ Complete backend-to-frontend integration

**Your Library feature is now fully functional!** 🚀

Import some movies and enjoy browsing your BoyLove/LGBTQ+ content library!

