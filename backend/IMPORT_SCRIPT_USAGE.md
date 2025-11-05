# Movie Import Script Usage 🎬

## Quick Start

### Import Single Movie

```bash
node import-movies.js tt14452776
```

### Import Multiple Movies

```bash
node import-movies.js tt14452776 tt13406036 tt5164432
```

### Import from File (Batch)

```bash
node import-movies.js --batch movies.txt
```

---

## Configuration

### Default Settings (Edit if needed)

The script uses these defaults:
- **API URL**: `http://localhost:3000` (or `$API_URL` env var)
- **Email**: `admin@example.com` (or `$ADMIN_EMAIL` env var)
- **Password**: `123456` (or `$ADMIN_PASSWORD` env var)

### Custom Configuration

```bash
# Set via environment variables
API_URL=http://localhost:3000 ADMIN_EMAIL=your@email.com ADMIN_PASSWORD=yourpass node import-movies.js tt14452776
```

---

## Examples

### Example 1: Import Heartstopper

```bash
node import-movies.js tt14452776
```

**Output:**
```
🔐 Logging in...
✅ Login successful!

📊 Current library: 1 movie(s)

🎬 Importing 1 movie(s)...
==================================================

📥 Importing tt14452776...
✅ Successfully imported: Heartstopper
   Type: TV_SERIES
   Genres: Drama, Comedy
   Year: 2022
   Rating: 8.5/10
   Movie ID: uuid-here

==================================================
📊 Import Summary:
   ✅ Successfully imported: 1

📚 Total movies in library: 2 (+1 new)

🎉 Import complete! Refresh your mobile app to see the movies.
```

---

### Example 2: Batch Import from File

**Step 1**: Edit `movies.txt` with IMDb IDs you want to import

**Step 2**: Run batch import
```bash
node import-movies.js --batch movies.txt
```

**Output:**
```
📄 Reading IMDb IDs from movies.txt...
✅ Found 9 IMDb IDs

🎬 Importing 9 movie(s)...
==================================================

[1/9] tt14452776
📥 Importing tt14452776...
✅ Successfully imported: Heartstopper
   ...

[2/9] tt13406036
📥 Importing tt13406036...
✅ Successfully imported: Young Royals
   ...

... (continues for all movies)

==================================================
📊 Import Summary:
   ✅ Successfully imported: 7
   ⏭️  Skipped (already exists): 2
   ❌ Failed: 0

📚 Total movies in library: 9 (+7 new)
```

---

## movies.txt Format

The `movies.txt` file I created has popular BoyLove/Gay content:

```
# BoyLove / Gay Content - Popular Series & Movies
# Lines starting with # are comments

# TV Series (BoyLove/Gay)
tt14452776  # Heartstopper
tt13406036  # Young Royals
tt10648342  # Queer as Folk (2022)

# Movies (BoyLove/Gay)
tt5164432   # Love, Simon
tt5726616   # Call Me By Your Name
tt14208870  # Red, White & Royal Blue

# Lesbian Content
tt8613070   # Portrait of a Lady on Fire
```

---

## Features

### ✅ Smart Features
- Automatic login with credentials
- Shows detailed movie information on import
- Detects duplicates (won't import twice)
- Batch import with progress tracking
- Handles errors gracefully
- Shows before/after library count
- Color-coded output
- Small delay between imports (avoid rate limits)

### 📊 Output Information
For each movie, shows:
- Title
- Content type (Movie/TV Series/Short)
- Genres
- Release year
- Rating
- Movie ID (for reference)

---

## Troubleshooting

### "Login failed"
- Check your email/password in script
- Or set: `ADMIN_EMAIL=your@email.com ADMIN_PASSWORD=yourpass`
- Verify user exists: Try logging in via mobile app first

### "Connection refused"
- Make sure backend server is running: `npm run dev`
- Check you see: "✅ Blue Video API server running on port 3000"

### "Movie not found in TMDb"
- Verify IMDb ID is correct (check on imdb.com)
- Some very new or obscure titles might not be in TMDb yet

### "Rate limit exceeded"
- Wait a few seconds
- Script already has 500ms delay between imports

---

## Quick Commands Reference

```bash
# Single import
node import-movies.js tt14452776

# Multiple imports
node import-movies.js tt14452776 tt13406036 tt5164432

# Batch from file
node import-movies.js --batch movies.txt

# With custom credentials
ADMIN_EMAIL=user@email.com ADMIN_PASSWORD=pass123 node import-movies.js tt14452776
```

---

## After Importing

### Backend - Check Import
```bash
# Get all movies
curl http://localhost:3000/api/v1/movies

# Filter by genre
curl "http://localhost:3000/api/v1/movies?genre=drama"

# Filter by LGBTQ+ type
curl "http://localhost:3000/api/v1/movies?lgbtqType=gay"
```

### Mobile App - View Movies
1. Open mobile app
2. Tap **Library** icon
3. **Pull down to refresh**
4. Movies appear in grid!
5. Try filtering by Drama, Gay, TV Series, etc.

---

## 🎬 Popular BoyLove/Gay IMDb IDs

### Must-Watch TV Series
- `tt14452776` - Heartstopper ⭐⭐⭐
- `tt13406036` - Young Royals ⭐⭐⭐
- `tt10648342` - Queer as Folk (2022) ⭐⭐
- `tt2243973` - Hannibal (has gay subtext) ⭐⭐⭐

### Must-Watch Movies
- `tt5726616` - Call Me By Your Name ⭐⭐⭐⭐
- `tt4975722` - Moonlight ⭐⭐⭐⭐
- `tt5164432` - Love, Simon ⭐⭐⭐
- `tt14208870` - Red, White & Royal Blue ⭐⭐⭐
- `tt1856101` - Blade Runner 2049 (has themes)

### Lesbian Content
- `tt8613070` - Portrait of a Lady on Fire ⭐⭐⭐⭐
- `tt0404238` - The L Word (TV Series) ⭐⭐⭐
- `tt10931542` - The Handmaid's Tale (has themes)

---

## 🚀 Quick Demo

Try this to get started quickly:

```bash
# Import 3 popular movies
node import-movies.js tt14452776 tt5164432 tt5726616

# Or import all from the pre-made list
node import-movies.js --batch movies.txt
```

Then refresh your mobile app and enjoy! 🎉

