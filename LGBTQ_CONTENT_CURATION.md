# LGBTQ+ Content Curation System 🏳️‍🌈

## Understanding the System

### ✅ What TMDb Provides (Automatic)
- Title, Overview, Tagline
- Poster, Backdrop, Photos
- **Genres** (Drama, Comedy, Romance, etc.)
- Release dates, Runtime
- Cast, Crew, Directors
- Ratings, Popularity

### ❌ What TMDb Doesn't Provide (Manual)
- **LGBTQ+ Classifications** ← You need to tag these yourself!

This is why you have the separate LGBTQ+ filter system.

---

## 🏷️ Your Tagged Library (Current)

Based on the tagging we just did:

### Gay Content (3 movies):
1. **Love, Simon** (2018) - Comedy, Drama, Romance
2. **Call Me by Your Name** (2017) - Romance, Drama
3. **Moonlight** (2016) - Drama

### Lesbian Content (1 movie):
1. **Portrait of a Lady on Fire** (2019) - Drama, Romance, History

### Not Tagged (3 movies):
1. **Anne Boleyn** (2021) - Historical drama, not LGBTQ+
2. **The Bear** (2022) - Restaurant drama, not LGBTQ+
3. **The Fabelmans** (2022) - Family drama, not LGBTQ+

---

## 📱 Test in Mobile App NOW!

### Step 1: Refresh Mobile App
- Go to **Library > Movies**
- **Pull down to refresh**

### Step 2: Check LGBTQ+ Filters
You should now see:
- All
- **Gay** ⭐ (NEW - 3 movies)
- **Lesbian** ⭐ (NEW - 1 movie)

### Step 3: Test Filters
- **Tap "Gay"** → See Love, Simon, Call Me by Your Name, Moonlight
- **Tap "Lesbian"** → See Portrait of a Lady on Fire
- **Combine with Genre**: "Gay" + "Romance" → See Love, Simon, Call Me by Your Name

---

## 🎬 Import & Tag More Content

### Recommended Gay/BoyLove Movies to Import:

```bash
# Import movies
node import-movies.js tt13406036 tt14208870 tt10648342 tt1856101

# Tag them
node tag-lgbtq.js --search "Young Royals" gay
node tag-lgbtq.js --search "Red, White" gay
node tag-lgbtq.js --search "Queer as Folk" gay queer
node tag-lgbtq.js --search "Fire Island" gay
```

### Recommended Lesbian Movies:

```bash
# Import
node import-movies.js tt1648112 tt0404238 tt7374948

# Tag
node tag-lgbtq.js --search "Carol" lesbian
node tag-lgbtq.js --search "The L Word" lesbian
node tag-lgbtq.js --search "Happiest Season" lesbian
```

---

## 🔄 Complete Workflow

### Step 1: Research Content
Find LGBTQ+ movies on:
- IMDb (search "gay movies", "lesbian movies")
- Letterboxd LGBTQ+ lists
- Queer cinema databases
- LGBTQ+ film festivals

### Step 2: Import by IMDb ID
```bash
node import-movies.js tt14452776
```

### Step 3: Tag LGBTQ+ Type
```bash
node tag-lgbtq.js --search "Heartstopper" gay
```

### Step 4: Refresh Mobile App
- Pull down to refresh
- New content appears with proper tagging!

---

## 📋 Tagging Best Practices

### Multiple Tags Are OK!
Some content can have multiple tags:
```bash
# Show has multiple LGBTQ+ representations
node tag-lgbtq.js --search "Pose" gay transgender queer

# Character explores multiple identities
node tag-lgbtq.js --search "The Miseducation" bisexual queer
```

### Use "Queer" for General Content
When content has LGBTQ+ themes but doesn't fit specific categories:
```bash
node tag-lgbtq.js --search "Paris is Burning" queer
```

### Re-tagging is Allowed
If you tagged incorrectly, just tag again:
```bash
# First tag
node tag-lgbtq.js --search "Movie" gay

# Oops, it's actually lesbian content, retag:
node tag-lgbtq.js --search "Movie" lesbian

# This REPLACES the tags (doesn't add to them)
```

---

## 🔍 Finding Movie IDs

### Method 1: Search by Title
```bash
node tag-lgbtq.js --search "Heartstopper" gay
```

The script finds it automatically!

### Method 2: List All Movies
```bash
node -e "const axios = require('axios'); axios.get('http://localhost:3000/api/v1/movies').then(r => r.data.data.forEach((m, i) => console.log((i+1) + '.', m.title, '(' + m.id + ')')))"
```

### Method 3: Filter First
```bash
# Get only TV Series
node -e "const axios = require('axios'); axios.get('http://localhost:3000/api/v1/movies?contentType=TV_SERIES').then(r => r.data.data.forEach(m => console.log(m.id, '-', m.title)))"
```

---

## 💾 Create Your Own Curated List

Create `lgbtq-content.txt`:
```
# My Curated LGBTQ+ Content
# Format: IMDbID TAG1 TAG2

tt14452776 gay          # Heartstopper
tt13406036 gay          # Young Royals
tt5164432 gay           # Love, Simon
tt5726616 gay           # Call Me by Your Name
tt4975722 gay           # Moonlight
tt8613070 lesbian       # Portrait of a Lady on Fire
tt10648342 gay queer    # Queer as Folk
```

Then create a batch script to import and tag:
```bash
# Import all
cat lgbtq-content.txt | grep "^tt" | awk '{print $1}' | xargs node import-movies.js

# Tag all (would need custom script)
```

---

## 🎯 Current Status

| Feature | Status | Notes |
|---------|--------|-------|
| TMDb Import | ✅ Automatic | Genres, cast, ratings |
| LGBTQ+ Tagging | ✅ Manual | Use tagging script |
| Dynamic Filters | ✅ Automatic | All genres/tags show |
| Search & Tag | ✅ Working | Easy workflow |
| Multiple Tags | ✅ Supported | gay + queer, etc. |

---

## 🚀 Quick Commands Reference

```bash
# Import movie
node import-movies.js <imdbId>

# Tag by search (EASIEST)
node tag-lgbtq.js --search "Movie Title" gay

# Tag by ID
node tag-lgbtq.js <movie-id> gay

# Multiple tags
node tag-lgbtq.js --search "Movie" gay queer

# Check filters
curl http://localhost:3000/api/v1/movies/filters/options
```

---

## 🎉 You Now Have

- ✅ 6 imported movies
- ✅ 3 tagged as "gay"
- ✅ 1 tagged as "lesbian"
- ✅ Dynamic filter system
- ✅ Easy tagging workflow

**Refresh your mobile app and the LGBTQ+ filters will appear with "Gay" and "Lesbian" options!** 🏳️‍🌈

Your BoyLove/LGBTQ+ content library is fully functional! ✨

