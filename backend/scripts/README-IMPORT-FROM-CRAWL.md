# Import from Crawled Data Guide

This guide explains how to import movies from crawled JSON data (e.g., from `b4watch.com`) into the Blue Video database.

## Overview

The `scripts/import-from-crawl.ts` script imports movies from a JSON file by:
1. Checking if the movie already exists (by `sourceUrl`)
2. Searching TMDb by title
3. If found on TMDb → imports full data from TMDb
4. If not found → creates a manual entry with crawled data

## Prerequisites

1. **Backend server must be running**:
   ```bash
   npm run dev
   ```

2. **Admin credentials** (default from `.env`):
   - Email: `admin@example.com`
   - Password: `123456`

3. **Crawled JSON file** with movies in this format:
   ```json
   [
     {
       "title": "Movie Title",
       "thumbnailUrl": "https://example.com/poster.jpg",
       "sourceUrl": "https://source-website.com/movie-slug/",
       "releaseDate": "2024-01-15T00:00:00.000Z"
     }
   ]
   ```

## Usage

### Basic Usage

```bash
# Import all movies from a JSON file
npx ts-node scripts/import-from-crawl.ts movies-full.json
```

### Import with Limits

```bash
# Import only first 100 movies
npx ts-node scripts/import-from-crawl.ts movies-full.json --limit=100

# Skip first 100, import next 100 movies
npx ts-node scripts/import-from-crawl.ts movies-full.json --skip=100 --limit=100
```

### Batch Import Strategy

For large files (e.g., 7000+ movies), it's recommended to import in batches:

```bash
# Batch 1: First 1000 movies
npx ts-node scripts/import-from-crawl.ts movies-full.json --skip=0 --limit=1000

# Batch 2: Next 1000 movies
npx ts-node scripts/import-from-crawl.ts movies-full.json --skip=1000 --limit=1000

# Batch 3: Next 1000 movies
npx ts-node scripts/import-from-crawl.ts movies-full.json --skip=2000 --limit=1000

# Continue until all movies are imported...
```

## Options

| Option | Description | Example |
|--------|-------------|---------|
| `--skip=N` | Skip first N movies | `--skip=100` |
| `--limit=N` | Import maximum N movies | `--limit=50` |

## Import Process

### Step 1: Duplicate Check
- Checks if movie already exists by `sourceUrl`
- Checks if movie already exists by normalized `title`
- If exists → skips

### Step 2: TMDb ID Check
- If TMDb result found, checks if TMDb ID already exists
- If exists → skips

### Step 3: TMDb Search
- Searches TMDb by title
- If found → imports from TMDb (with full metadata)

### Step 4: Manual Entry
- If not found on TMDb → creates manual entry with:
  - `title` (from crawled data)
  - `posterUrl` (from `thumbnailUrl`)
  - `sourceUrl` (original source URL)
  - `releaseDate` (if available)
  - `contentType` = `MOVIE`

## Output

The script provides detailed logging:

```bash
[1/100] Processing: Movie Title
   Source: https://source-website.com/movie-slug/
   🔍 Searching TMDb...
   ✅ Found on TMDb: Movie Title (movie)
   📥 Importing from TMDb...
   ✅ Imported from TMDb (ID: abc-123-def)
```

### Status Icons

- `🔍` - Searching TMDb
- `✅` - Success (imported or created)
- `⏭️` - Skipped (already exists)
- `⚠️` - Warning (not found on TMDb, creating manual entry)
- `❌` - Failed

### Progress Updates

Every 10 movies, the script shows a progress summary:

```bash
📊 Progress: 50/100 | TMDb: 35 | Manual: 12 | Skipped: 3 | Failed: 0
```

### Final Summary

```bash
======================================================================
📊 Import Summary:
   ✅ Imported from TMDb: 35
   ✅ Created manual entries: 12
   ⏭️  Skipped (already exists): 3
   ❌ Failed: 0
   ⏱️  Time taken: 2.45 minutes

📚 Total movies in library: 150 (+50 new)
```

## Rate Limiting

The script includes a 1-second delay between imports to avoid:
- Backend rate limiting
- TMDb API rate limits
- Database overload

**Estimated time:**
- 100 movies = ~2-3 minutes
- 1000 movies = ~20-25 minutes
- 7000 movies = ~2-3 hours

## Error Handling

### Common Errors

#### 1. "Login failed"
**Cause**: Backend not running or wrong credentials

**Solution**:
```bash
# Start backend
npm run dev

# Or set correct credentials in .env
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=123456
```

#### 2. "Error reading file"
**Cause**: JSON file not found or invalid format

**Solution**:
- Check file path is correct
- Verify JSON format is valid
- Ensure file is an array of movie objects

#### 3. High failure rate
**Cause**: TMDb API issues or network problems

**Solution**:
- Check internet connection
- Wait a few minutes and retry
- Use smaller batches (`--limit=50`)

## Examples

### Example 1: Import First 50 Movies

```bash
npx ts-node scripts/import-from-crawl.ts movies-full.json --limit=50
```

### Example 2: Resume from Page 5 (skip 100)

```bash
npx ts-node scripts/import-from-crawl.ts movies-full.json --skip=100 --limit=100
```

### Example 3: Import All Movies (7025 total)

```bash
# Option A: All at once (takes ~3 hours)
npx ts-node scripts/import-from-crawl.ts movies-full.json

# Option B: In batches (safer)
npx ts-node scripts/import-from-crawl.ts movies-full.json --limit=1000
npx ts-node scripts/import-from-crawl.ts movies-full.json --skip=1000 --limit=1000
npx ts-node scripts/import-from-crawl.ts movies-full.json --skip=2000 --limit=1000
# ... continue until complete
```

## Database Schema

The `sourceUrl` field is stored in the `Movie` table:

```prisma
model Movie {
  // ... other fields
  sourceUrl String? @map("source_url") @db.Text
  // ... other fields
}
```

This allows:
- Tracking original source of the movie
- Preventing duplicate imports
- Future features (e.g., link back to source website)

## Tips

1. **Start small**: Test with `--limit=10` first
2. **Use batches**: For large imports, use batches of 500-1000 movies
3. **Monitor logs**: Watch for patterns in failures
4. **Check duplicates**: The script automatically handles duplicates by `sourceUrl`, normalized title, and TMDb ID
5. **TMDb matches**: Movies found on TMDb will have complete metadata (genres, cast, etc.)
6. **Manual entries**: Movies not on TMDb will have basic info only (title, poster, release date)

## Next Steps

After importing:
1. **Verify in database**: Check that movies were imported correctly
2. **Refresh mobile app**: Pull to refresh the library screen
3. **Add episodes**: Use episode import scripts to add video files
4. **Update metadata**: Edit manual entries to add genres, cast, etc.

## Support

For issues or questions:
- Check the console output for detailed error messages
- Verify backend server is running (`npm run dev`)
- Ensure database is accessible
- Check `.env` file for correct credentials

