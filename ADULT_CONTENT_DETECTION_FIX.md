# Adult Content Detection Fix

## Problem

Movies marked as 18+ on TMDb (like "Naked" 1993 with UK rating 18) were being imported with `isAdult: false` in our database.

## Root Cause

**TMDb's `adult` field does NOT mean what we thought!**

- **TMDb `adult` field** = Only for **pornographic content** (XXX movies)
- **Regular 18+ movies** (R-rated, NC-17, UK:18, etc.) have `adult: false`

For actual age ratings, we need to check:
- **Movies**: `release_dates` endpoint → certifications by country
- **TV Shows**: `content_ratings` endpoint → ratings by country

## Example: "Naked" (1993)

```
TMDb ID: 21450
Adult field: false ← (for porn detection only)
UK Rating: 18 ← (actual age rating)
Result: Should be marked as Adult ✅
```

## Solution

### 1. Updated TMDb Service

**File**: `backend/src/services/tmdbService.ts`

Added `release_dates` and `content_ratings` to API requests:

```typescript
// Movies
append_to_response: 'credits,videos,images,external_ids,alternative_titles,release_dates'

// TV Shows
append_to_response: 'credits,videos,images,external_ids,alternative_titles,content_ratings'
```

### 2. Created `isAdultContent()` Function

**File**: `backend/src/controllers/movieController.ts`

New helper function that checks:

1. **Pornographic content**: `data.adult === true`
2. **Age certifications**: Checks country-specific ratings

Supported certifications (18+ only):
- **UK (GB)**: 18, 18A
- **US**: NC-17, X (excludes TV-MA/R which are 17+)
- **Australia (AU)**: R18+, X18+, RC (excludes MA15+ which is 15+)
- **Germany (DE)**: 18, 18+
- **France (FR)**: -18, 18
- **South Korea (KR)**: 청소년관람불가, 제한상영가, 18
- **Finland (FI)**: K-18
- **Norway (NO)**: 18
- **Generic**: Any rating containing "18" (except "15-18")

### 3. Updated Movie Import Logic

Changed from:
```typescript
isAdult: movieData.adult || false,
```

To:
```typescript
isAdult: isAdultContent(movieData),
```

## Testing

Run this to verify:

```bash
cd backend

# Check current status
node -e "
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
prisma.movie.findFirst({ where: { tmdbId: '21450' } })
  .then(m => {
    console.log('Naked (1993) isAdult:', m?.isAdult);
    prisma.\$disconnect();
  });
"
```

## Impact

- ✅ **New imports**: Will correctly detect adult content based on certifications
- ⚠️ **Existing movies**: Need to be re-imported to update `isAdult` field

## Re-importing Existing Movies

To fix existing movies, delete and re-import them:

```bash
# Example: Re-import "Naked" (1993)
curl -X DELETE "http://localhost:3000/api/v1/movies/{movieId}" \
  -H "Authorization: Bearer {token}"

curl -X POST "http://localhost:3000/api/v1/movies/import/imdb" \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{"identifiers": ["movie:21450"], "preferredType": "MOVIE"}'
```

Or use the mobile app's "Add Movie" feature to re-import.

## Files Changed

1. `backend/src/services/tmdbService.ts`
   - Added `release_dates` to movie requests
   - Added `content_ratings` to TV show requests

2. `backend/src/controllers/movieController.ts`
   - Added `isAdultContent()` helper function
   - Updated movie creation to use new function

## Notes

- This fix applies to **both movies and TV shows**
- The detection is based on **international ratings**, not just US
- Prioritizes UK and US ratings, but also checks other countries
- Falls back to generic "18" check for unknown countries

## Future Improvements

Consider adding:
- Configuration to customize which ratings trigger "adult" flag
- Bulk re-import script for existing movies
- Admin UI to manually mark/unmark adult content
- Store the actual certification in database (not just boolean)

