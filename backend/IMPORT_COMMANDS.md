# Movie Import Commands (Windows PowerShell)

## ⚠️ IMPORTANT: Make sure backend server is running first!

Check your backend terminal - you should see:
```
📚 Movie/Library routes registered at /api/v1/movies
✅ Blue Video API server running on port 3000
```

If not running, start it:
```powershell
npm run dev
```

---

## 🎬 Import Movies (Simple Commands)

### Import Heartstopper (Gay Teen Romance Series)

```powershell
$body = '{"imdbId": "tt14452776"}' 
Invoke-RestMethod -Uri "http://localhost:3000/api/v1/movies/import/imdb" -Method Post -ContentType "application/json" -Body $body
```

### Import Young Royals (Gay Teen Drama Series)

```powershell
$body = '{"imdbId": "tt13406036"}' 
Invoke-RestMethod -Uri "http://localhost:3000/api/v1/movies/import/imdb" -Method Post -ContentType "application/json" -Body $body
```

### Import Multiple Movies at Once

```powershell
$body = '{"imdbIds": ["tt14452776", "tt13406036", "tt5164432", "tt5726616"]}' 
Invoke-RestMethod -Uri "http://localhost:3000/api/v1/movies/import/imdb" -Method Post -ContentType "application/json" -Body $body
```

### Check Movies List

```powershell
Invoke-RestMethod -Uri "http://localhost:3000/api/v1/movies"
```

### Filter Gay Content

```powershell
Invoke-RestMethod -Uri "http://localhost:3000/api/v1/movies?lgbtqType=gay"
```

### Filter TV Series

```powershell
Invoke-RestMethod -Uri "http://localhost:3000/api/v1/movies?contentType=TV_SERIES"
```

---

## 📋 Quick IMDb IDs Reference

### TV Series (BoyLove/Gay)
- **Heartstopper**: `tt14452776` ⭐ (British teen romance)
- **Young Royals**: `tt13406036` ⭐ (Swedish prince romance)
- **Queer as Folk (2022)**: `tt14688858`
- **Special (2019)**: `tt8976696`

### Movies (BoyLove/Gay)
- **Love, Simon**: `tt5164432` ⭐
- **Call Me By Your Name**: `tt5726616` ⭐⭐
- **Red, White & Royal Blue**: `tt14208870` ⭐
- **Moonlight**: `tt4975722` ⭐⭐
- **Portrait of a Lady on Fire**: `tt8613070` ⭐⭐ (Lesbian)

---

## 🔧 Troubleshooting

### "Connection refused" error
- **Problem**: Backend server is not running
- **Solution**: Run `npm run dev` in backend folder

### "Invalid JSON" or parsing error
- **Problem**: TMDb API returned unexpected data
- **Solution**: Check TMDb API key in `.env` file

### Movies imported but not showing in mobile app
- **Problem**: Mobile app not refreshing
- **Solution**: Pull down to refresh in the Library > Movies screen

### Import succeeds but returns "not found"
- **Problem**: Invalid IMDb ID
- **Solution**: Double-check IMDb ID on https://www.imdb.com

---

## ✅ Expected Success Response

```json
{
  "success": true,
  "message": "Imported 1 of 1 movies",
  "results": [
    {
      "imdbId": "tt14452776",
      "success": true,
      "message": "Movie imported successfully",
      "movieId": "some-uuid-here",
      "movie": {
        "id": "some-uuid-here",
        "title": "Heartstopper",
        "contentType": "TV_SERIES",
        ...
      }
    }
  ]
}
```

---

## 🚀 After Importing

1. **Open mobile app**
2. **Go to Library tab** (2nd icon)
3. **Tap Movies** tab
4. **Pull down to refresh**
5. **Movies appear!** 🎉

You can then:
- Filter by Type (Movie/TV Series/Short)
- Filter by Genre (Drama/Comedy/Romance)
- Filter by LGBTQ+ Type (Gay/Lesbian/etc)

---

**Note**: Import endpoint is temporarily public for easy testing. In production, add authentication back by uncommenting the `authenticateToken` middleware in `routes/movies.ts`.

