# B4Watch Crawler

Web scraper for extracting movie data from b4watch.com (Recently Added section only).

## Features

- ✅ Extracts only "Recently Added" section (excludes "Featured Movies")
- ✅ Automatic retry with exponential backoff
- ✅ Rate limiting with configurable delays
- ✅ Progress checkpoints every 50 pages
- ✅ Deduplication by source URL
- ✅ Release date parsing and normalization
- ✅ Continues on errors instead of stopping

## Usage

### Basic Usage

```bash
npx ts-node scripts/crawl-b4watch.ts --maxPages=292 --output=movies.json
```

### All Options

```bash
npx ts-node scripts/crawl-b4watch.ts \
  --start=https://b4watch.com/movies/ \
  --maxPages=292 \
  --output=movies.json \
  --delay=2000 \
  --retries=3 \
  --timeout=30000
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `--start` | `https://b4watch.com/movies/` | Starting URL to crawl |
| `--maxPages` | `10` | Maximum number of pages to crawl |
| `--output` | `b4watch-lgbtq.json` | Output JSON file path |
| `--delay` | `2000` | Delay between requests (milliseconds) |
| `--retries` | `3` | Number of retry attempts for failed requests |
| `--timeout` | `30000` | Request timeout (milliseconds) |

## Optimization Tips

### For Large Crawls (200+ pages)

1. **Increase delay** to avoid rate limiting:
   ```bash
   --delay=3000  # 3 seconds between requests
   ```

2. **Increase timeout** for slow responses:
   ```bash
   --timeout=60000  # 60 second timeout
   ```

3. **Monitor checkpoints**: Progress is automatically saved every 50 pages to `*.checkpoint.json`

4. **Resume from failure**: If the crawler fails, you can manually merge the checkpoint file with partial results

### Example: Crawl All 292 Pages

```bash
npx ts-node scripts/crawl-b4watch.ts \
  --start=https://b4watch.com/movies/ \
  --maxPages=292 \
  --output=movies-full.json \
  --delay=3000 \
  --retries=5 \
  --timeout=60000
```

**Estimated time**: ~15-20 minutes (with 3-second delays)

## Error Handling

The crawler implements several robustness features:

1. **Automatic Retries**: Failed requests are retried up to 3 times (configurable) with exponential backoff
2. **Skip on Error**: If a page fails after all retries, the crawler continues to the next page instead of stopping
3. **Connection Errors**: `ECONNRESET` and timeout errors are caught and retried
4. **Progress Checkpoints**: Data is saved every 50 pages, so you don't lose progress on long crawls

## Output Format

```json
[
  {
    "title": "Movie Title",
    "thumbnailUrl": "https://b4watch.com/wp-content/uploads/...",
    "sourceUrl": "https://b4watch.com/movies/movie-slug/",
    "releaseDate": "2024-01-15T00:00:00.000Z"
  }
]
```

## Troubleshooting

### "ECONNRESET" errors

**Cause**: Server closing connection due to too many requests

**Solution**: 
- Increase `--delay` to 3000-5000ms
- Reduce `--maxPages` and run multiple smaller crawls
- Check your internet connection

### High memory usage

**Cause**: Collecting too many results in memory

**Solution**: Use checkpoint files (automatic every 50 pages)

### Missing release dates

**Cause**: Website may not always include dates for all movies

**Solution**: This is normal - `releaseDate` will be `null` for movies without dates

## Notes

- The crawler only extracts from the `#archive-content` section
- "Featured Movies" in sliders are automatically excluded
- Duplicate entries (by URL) are automatically filtered
- Progress is shown with page count: "page X/Y"

