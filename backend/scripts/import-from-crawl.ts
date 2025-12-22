import 'dotenv/config';

import fs from 'node:fs';
import crypto from 'node:crypto';
import axios, { AxiosError } from 'axios';

import { StorageService } from '../src/config/storage';

const API_BASE_URL = process.env['API_URL'] || 'http://127.0.0.1:8000';
const LOGIN_EMAIL = process.env['ADMIN_EMAIL'] || 'admin@example.com';
const LOGIN_PASSWORD = process.env['ADMIN_PASSWORD'] || '123456';

// Color codes for console output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
  magenta: '\x1b[35m',
} as const;

interface CrawledMovie {
  title: string;
  sourceUrl: string;
  thumbnailUrl?: string;
  releaseDate?: string;
}

interface TMDbResult {
  tmdbId: string | number;
  title?: string;
  name?: string;
  contentType: 'MOVIE' | 'TV_SERIES';
  media_type?: string;
}

interface Movie {
  id: string;
  title: string;
  [key: string]: unknown;
}

interface ImportResult {
  success: boolean;
  movie?: Movie;
  source?: 'tmdb' | 'manual';
  message?: string;
  alreadyExists?: boolean;
}

interface BatchOptions {
  skip?: number;
  limit?: number;
}

interface BatchResults {
  tmdb: number;
  manual: number;
  skipped: number;
  failed: number;
}

function log(message: string, color: string = colors.reset): void {
  console.log(`${color}${message}${colors.reset}`);
}

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Generate a hash-based subfolder path to distribute files across multiple folders.
 * This prevents hitting S3's 10,000 files per folder limit.
 * Uses first 2 characters of MD5 hash to create 256 subfolders (00-ff).
 */
function getHashSubfolder(filename: string): string {
  const hash = crypto.createHash('md5').update(filename).digest('hex');
  // Use first 2 characters to create 256 subfolders (00-ff)
  return hash.substring(0, 2);
}

/**
 * Build a storage path with optional date and hash-based subfolder partitioning.
 * Format: {baseFolder}/{datePath}/{hashSubfolder} or {baseFolder}/{hashSubfolder} if datePath is not provided
 * This ensures files are distributed across multiple folders to avoid S3's 10,000 file limit.
 */
function buildStoragePath(baseFolder: string, filename: string, datePath?: string): string {
  const hashSubfolder = getHashSubfolder(filename);
  if (datePath) {
    return `${baseFolder}/${datePath}/${hashSubfolder}`;
  }
  return `${baseFolder}/${hashSubfolder}`;
}

/**
 * Login and get authentication token
 */
async function login(): Promise<string> {
  try {
    log('🔐 Logging in...', colors.cyan);
    
    const response = await axios.post(`${API_BASE_URL}/api/v1/auth/login`, {
      email: LOGIN_EMAIL,
      password: LOGIN_PASSWORD,
    });

    const token = response.data.data?.accessToken || response.data.accessToken;
    if (token) {
      log('✅ Login successful!', colors.green);
      return token;
    } else {
      throw new Error('Login failed: No access token received');
    }
  } catch (error) {
    log('❌ Login failed!', colors.red);
    const axiosError = error as AxiosError;
    if (axiosError.response) {
      const message = (axiosError.response.data as any)?.message || axiosError.message;
      log(`Error: ${message}`, colors.red);
    } else {
      log(`Error: ${axiosError.message}`, colors.red);
    }
    process.exit(1);
  }
}

/**
 * Search TMDb by title
 */
async function searchTmdb(token: string, title: string): Promise<TMDbResult | null> {
  try {
    const response = await axios.get(`${API_BASE_URL}/api/v1/movies/external/tmdb/search`, {
      params: { query: title },
      headers: { 'Authorization': `Bearer ${token}` },
    });

    if (response.data.success && response.data.data && response.data.data.length > 0) {
      return response.data.data[0] as TMDbResult; // Return first result
    }
    return null;
  } catch (error) {
    const axiosError = error as AxiosError;
    console.error(`   TMDb search error: ${axiosError.message}`);
    return null;
  }
}

/**
 * Import movie by TMDb ID
 */
async function importFromTmdb(token: string, tmdbResult: TMDbResult): Promise<ImportResult> {
  try {
    // tmdbResult has: tmdbId, title, contentType
    const isTvSeries = tmdbResult.contentType === 'TV_SERIES';
    const identifier = isTvSeries 
      ? `tv:${tmdbResult.tmdbId}`
      : `movie:${tmdbResult.tmdbId}`;

    const response = await axios.post(
      `${API_BASE_URL}/api/v1/movies/import/imdb`,
      {
        identifiers: [identifier],
        preferredType: isTvSeries ? 'TV_SERIES' : 'MOVIE',
      },
      {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      }
    );

    if (response.data.success && response.data.results[0]?.success) {
      return { 
        success: true, 
        movie: response.data.results[0].movie as Movie, 
        source: 'tmdb' 
      };
    }
    return { success: false, message: response.data.message };
  } catch (error) {
    const axiosError = error as AxiosError;
    if (axiosError.response?.status === 409 || 
        (axiosError.response?.data as any)?.message?.includes('already exists')) {
      return { success: false, message: 'Already exists', alreadyExists: true };
    }
    return { success: false, message: axiosError.message };
  }
}

/**
 * Create manual movie entry
 */
async function createManualEntry(token: string, crawledMovie: CrawledMovie): Promise<ImportResult> {
  try {
    let posterUrl: string | null = null;

    // Upload thumbnail to S3 if available
    if (crawledMovie.thumbnailUrl && !crawledMovie.thumbnailUrl.startsWith('s3://')) {
      try {
        log(`   📥 Uploading thumbnail to S3...`, colors.blue);
        
        // Build date-based storage prefix using current date
        //const now = new Date();
        //const year = now.getFullYear();
        //const month = String(now.getMonth() + 1).padStart(2, '0');
        //const day = String(now.getDate()).padStart(2, '0');
        //const datePath = `${year}/${month}/${day}`;

        // Use movie title as filename (sanitized)
        const filenameId = crawledMovie.title
          .normalize('NFKD')
          .replace(/[\u0300-\u036f]/g, '') // remove diacritics
          .replace(/[^a-zA-Z0-9]+/g, '-')
          .replace(/^-+|-+$/g, '')
          .toLowerCase() || 'poster';

        const thumbnailPath = buildStoragePath('posters', filenameId);
        
        const thumbnailResult = await StorageService.uploadFromUrl(
          crawledMovie.thumbnailUrl,
          thumbnailPath,
          filenameId
        );
        
        if (thumbnailResult) {
          posterUrl = `s3://${thumbnailResult.key}`;
          log(`   ✅ Thumbnail uploaded: ${thumbnailResult.key}`, colors.green);
        } else {
          log(`   ⚠️  Failed to upload thumbnail, using original URL`, colors.yellow);
          posterUrl = crawledMovie.thumbnailUrl;
        }
      } catch (error) {
        const err = error as Error;
        log(`   ⚠️  Error uploading thumbnail: ${err.message}, using original URL`, colors.yellow);
        posterUrl = crawledMovie.thumbnailUrl;
      }
    } else if (crawledMovie.thumbnailUrl?.startsWith('s3://')) {
      // Already an S3 URL, use as-is
      posterUrl = crawledMovie.thumbnailUrl;
    } else {
      // No thumbnail URL provided
      posterUrl = null;
    }

    const payload = {
      contentType: 'MOVIE',
      title: crawledMovie.title,
      posterUrl: posterUrl,
      sourceUrl: crawledMovie.sourceUrl,
      releaseDate: crawledMovie.releaseDate,
      // Optional fields
      overview: null,
      genres: null,
      countries: null,
      languages: null,
      runtime: null,
      trailerUrl: null,
    };

    const response = await axios.post(
      `${API_BASE_URL}/api/v1/movies`,
      payload,
      {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      }
    );

    if (response.data.success) {
      return { success: true, movie: response.data.data as Movie, source: 'manual' };
    }
    return { success: false, message: response.data.message };
  } catch (error) {
    const axiosError = error as AxiosError;
    if (axiosError.response?.status === 409 || 
        (axiosError.response?.data as any)?.message?.includes('already exists')) {
      return { success: false, message: 'Already exists', alreadyExists: true };
    }
    const message = (axiosError.response?.data as any)?.message || axiosError.message;
    return { success: false, message };
  }
}

/**
 * Normalize title for comparison (lowercase, trim, remove special chars)
 * More aggressive normalization to catch more duplicates
 */
function normalizeTitle(title: string | null | undefined): string {
  if (!title) return '';
  return title
    .toLowerCase()
    .trim()
    .normalize('NFKD') // Normalize unicode characters
    .replace(/[\u0300-\u036f]/g, '') // Remove diacritics
    .replace(/[^\w\s]/g, '') // Remove special characters
    .replace(/\s+/g, ' ') // Normalize whitespace
    .replace(/^(the|a|an)\s+/i, '') // Remove articles
    .trim();
}

/**
 * Check if movie already exists by sourceUrl
 */
async function checkExistsBySourceUrl(token: string, sourceUrl: string): Promise<Movie | null> {
  try {
    const response = await axios.get(`${API_BASE_URL}/api/v1/movies`, {
      params: { sourceUrl, limit: 1 },
      headers: { 'Authorization': `Bearer ${token}` },
    });

    if (response.data.success && response.data.data?.length > 0) {
      return response.data.data[0] as Movie;
    }
    return null;
  } catch (error) {
    return null;
  }
}

/**
 * Check if movie already exists by TMDb ID
 */
async function checkExistsByTmdbId(
  token: string, 
  tmdbId: string | number, 
  contentType?: string
): Promise<Movie | null> {
  try {
    const response = await axios.get(`${API_BASE_URL}/api/v1/movies/by-identifiers`, {
      params: { 
        tmdbId: tmdbId.toString(),
        contentType: contentType || undefined,
      },
      headers: { 'Authorization': `Bearer ${token}` },
    });

    if (response.data.success && response.data.data?.length > 0) {
      return response.data.data[0] as Movie;
    }
    return null;
  } catch (error) {
    return null;
  }
}

/**
 * Check if movie already exists by title (normalized comparison)
 * Also checks for similar titles with higher limit
 */
async function checkExistsByTitle(token: string, title: string): Promise<Movie | null> {
  try {
    const normalizedTitle = normalizeTitle(title);
    if (!normalizedTitle) return null;

    // Search with a higher limit to catch more potential matches
    const response = await axios.get(`${API_BASE_URL}/api/v1/movies`, {
      params: { 
        search: title,
        limit: 50, // Increased limit to catch more matches
      },
      headers: { 'Authorization': `Bearer ${token}` },
    });

    if (response.data.success && response.data.data?.length > 0) {
      // Check for exact normalized title match
      const movies = response.data.data as Movie[];
      for (const movie of movies) {
        const movieTitleNormalized = normalizeTitle(movie.title);
        if (movieTitleNormalized === normalizedTitle) {
          return movie;
        }
        
        // Also check if titles are very similar (one contains the other)
        // This catches cases like "Movie Title" vs "Movie Title (2024)"
        if (normalizedTitle.length > 5 && movieTitleNormalized.length > 5) {
          const shorter = normalizedTitle.length < movieTitleNormalized.length 
            ? normalizedTitle 
            : movieTitleNormalized;
          const longer = normalizedTitle.length >= movieTitleNormalized.length 
            ? normalizedTitle 
            : movieTitleNormalized;
          
          // If the shorter title is at least 80% of the longer one and is contained in it
          if (longer.includes(shorter) && (shorter.length / longer.length) >= 0.8) {
            return movie;
          }
        }
      }
    }
    return null;
  } catch (error) {
    return null;
  }
}

/**
 * Import a single movie from crawled data
 */
async function importMovie(
  token: string, 
  crawledMovie: CrawledMovie, 
  index: number, 
  total: number
): Promise<ImportResult> {
  log(`\n[${index}/${total}] Processing: ${crawledMovie.title}`, colors.bright);
  log(`   Source: ${crawledMovie.sourceUrl}`, colors.cyan);

  try {
    // Step 1: Check if already imported by sourceUrl
    const existingByUrl = await checkExistsBySourceUrl(token, crawledMovie.sourceUrl);
    if (existingByUrl) {
      log(`   ⏭️  Already imported by sourceUrl (ID: ${existingByUrl.id})`, colors.yellow);
      return { success: false, alreadyExists: true };
    }

    // Step 2: Check if already exists by title (normalized)
    const existingByTitle = await checkExistsByTitle(token, crawledMovie.title);
    if (existingByTitle) {
      log(`   ⏭️  Already exists by title: "${existingByTitle.title}" (ID: ${existingByTitle.id})`, colors.yellow);
      return { success: false, alreadyExists: true };
    }

    // Step 3: Search TMDb by title
    log(`   🔍 Searching TMDb...`, colors.blue);
    const tmdbResult = await searchTmdb(token, crawledMovie.title);

    if (tmdbResult) {
      log(`   ✅ Found on TMDb: ${tmdbResult.title || tmdbResult.name} (${tmdbResult.media_type})`, colors.green);
      
      // Step 4: Check if TMDb ID already exists in database
      const isTvSeries = tmdbResult.contentType === 'TV_SERIES';
      const existingByTmdbId = await checkExistsByTmdbId(
        token, 
        tmdbResult.tmdbId, 
        isTvSeries ? 'TV_SERIES' : 'MOVIE'
      );
      
      if (existingByTmdbId) {
        log(`   ⏭️  Already exists by TMDb ID: ${tmdbResult.tmdbId} (ID: ${existingByTmdbId.id})`, colors.yellow);
        return { success: false, alreadyExists: true };
      }
      
      log(`   📥 Importing from TMDb...`, colors.blue);
      const result = await importFromTmdb(token, tmdbResult);
      
      if (result.success) {
        // Re-check for duplicates after import (in case it was created between our check and import)
        const verifyByTmdbId = await checkExistsByTmdbId(
          token, 
          tmdbResult.tmdbId, 
          isTvSeries ? 'TV_SERIES' : 'MOVIE'
        );
        
        if (verifyByTmdbId && verifyByTmdbId.id !== result.movie!.id) {
          log(`   ⚠️  Duplicate detected after import (ID: ${verifyByTmdbId.id})`, colors.yellow);
          return { success: false, alreadyExists: true };
        }
        
        log(`   ✅ Imported from TMDb (ID: ${result.movie!.id})`, colors.green);
        return result;
      } else if (result.alreadyExists) {
        log(`   ⏭️  Already exists in database`, colors.yellow);
        return { success: false, alreadyExists: true };
      } else {
        log(`   ⚠️  TMDb import failed: ${result.message}`, colors.yellow);
        
        // Re-check for duplicates before creating manual entry
        // (movie might have been created by another process or the TMDb import might have partially succeeded)
        const recheckByTitle = await checkExistsByTitle(token, crawledMovie.title);
        if (recheckByTitle) {
          log(`   ⏭️  Movie already exists by title: "${recheckByTitle.title}" (ID: ${recheckByTitle.id})`, colors.yellow);
          return { success: false, alreadyExists: true };
        }
        
        const recheckByUrl = await checkExistsBySourceUrl(token, crawledMovie.sourceUrl);
        if (recheckByUrl) {
          log(`   ⏭️  Movie already exists by sourceUrl (ID: ${recheckByUrl.id})`, colors.yellow);
          return { success: false, alreadyExists: true };
        }
        
        log(`   📝 Creating manual entry...`, colors.blue);
        const manualResult = await createManualEntry(token, crawledMovie);
        
        if (manualResult.success) {
          log(`   ✅ Created manual entry (ID: ${manualResult.movie!.id})`, colors.green);
          return manualResult;
        } else if (manualResult.alreadyExists) {
          log(`   ⏭️  Already exists in database`, colors.yellow);
          return { success: false, alreadyExists: true };
        } else {
          const errorMessage = manualResult.message || 'Unknown error';
          log(`   ❌ Manual entry failed: ${errorMessage}`, colors.red);
          return { success: false, message: errorMessage };
        }
      }
    } else {
      log(`   ⚠️  Not found on TMDb`, colors.yellow);
      
      // Re-check for duplicates before creating manual entry
      // (movie might have been created by another process)
      const recheckByTitle = await checkExistsByTitle(token, crawledMovie.title);
      if (recheckByTitle) {
        log(`   ⏭️  Movie already exists by title: "${recheckByTitle.title}" (ID: ${recheckByTitle.id})`, colors.yellow);
        return { success: false, alreadyExists: true };
      }
      
      const recheckByUrl = await checkExistsBySourceUrl(token, crawledMovie.sourceUrl);
      if (recheckByUrl) {
        log(`   ⏭️  Movie already exists by sourceUrl (ID: ${recheckByUrl.id})`, colors.yellow);
        return { success: false, alreadyExists: true };
      }
      
      log(`   📝 Creating manual entry...`, colors.blue);
      const manualResult = await createManualEntry(token, crawledMovie);
      
      if (manualResult.success) {
        log(`   ✅ Created manual entry (ID: ${manualResult.movie!.id})`, colors.green);
        return manualResult;
      } else if (manualResult.alreadyExists) {
        log(`   ⏭️  Already exists in database`, colors.yellow);
        return { success: false, alreadyExists: true };
      } else {
        const errorMessage = manualResult.message || 'Unknown error';
        log(`   ❌ Manual entry failed: ${errorMessage}`, colors.red);
        return { success: false, message: errorMessage };
      }
    }
  } catch (error) {
    const err = error as Error;
    log(`   ❌ Error: ${err.message}`, colors.red);
    return { success: false, message: err.message };
  }
}

/**
 * Import batch of movies
 */
async function importBatch(
  token: string, 
  movies: CrawledMovie[], 
  options: BatchOptions = {}
): Promise<BatchResults> {
  const { skip = 0, limit = Infinity } = options;
  
  const moviesToImport = movies.slice(skip, skip + (limit === Infinity ? movies.length : limit));
  const total = moviesToImport.length;
  
  log(`\n📦 Importing ${total} movies (skip: ${skip}, limit: ${limit === Infinity ? 'unlimited' : limit})...`, colors.bright);
  log('='.repeat(70), colors.cyan);
  
  const results: BatchResults = {
    tmdb: 0,
    manual: 0,
    skipped: 0,
    failed: 0,
  };

  for (let i = 0; i < moviesToImport.length; i++) {
    const movie = moviesToImport[i];
    if (!movie) {
      continue;
    }
    const globalIndex = skip + i + 1;
    
    const result = await importMovie(token, movie, globalIndex, skip + total);
    
    if (result.success) {
      if (result.source === 'tmdb') {
        results.tmdb++;
      } else if (result.source === 'manual') {
        results.manual++;
      }
    } else if (result.alreadyExists) {
      results.skipped++;
    } else {
      results.failed++;
    }

    // Progress update every 10 movies
    if ((i + 1) % 10 === 0) {
      log(`\n📊 Progress: ${i + 1}/${total} | TMDb: ${results.tmdb} | Manual: ${results.manual} | Skipped: ${results.skipped} | Failed: ${results.failed}`, colors.magenta);
    }

    // Delay between imports to avoid rate limiting
    if (i < moviesToImport.length - 1) {
      await sleep(10); // 1 second delay
    }
  }

  return results;
}

/**
 * Get current movie count
 */
async function getMovieCount(token: string): Promise<number> {
  try {
    const response = await axios.get(`${API_BASE_URL}/api/v1/movies`, {
      params: { limit: 1 },
      headers: { 'Authorization': `Bearer ${token}` },
    });

    if (response.data.success) {
      return response.data.pagination.total as number;
    }
    return 0;
  } catch (error) {
    return 0;
  }
}

/**
 * Main execution
 */
async function main(): Promise<void> {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    log('❌ No input file provided!', colors.red);
    log('\nUsage:', colors.bright);
    log('  ts-node scripts/import-from-crawl.ts movies-full.json');
    log('  ts-node scripts/import-from-crawl.ts movies-full.json --limit=100');
    log('  ts-node scripts/import-from-crawl.ts movies-full.json --skip=50 --limit=50');
    log('\nOptions:', colors.bright);
    log('  --skip=N    Skip first N movies');
    log('  --limit=N   Import maximum N movies');
    process.exit(1);
  }

  // Parse arguments
  const filename = args.find(arg => !arg.startsWith('--'));
  const skipArg = args.find(arg => arg.startsWith('--skip='));
  const limitArg = args.find(arg => arg.startsWith('--limit='));
  
  const skip = skipArg ? parseInt(skipArg.split('=')[1] || '0', 10) : 0;
  const limit = limitArg ? (() => {
    const limitValue = limitArg.split('=')[1];
    if (!limitValue) return Infinity;
    const parsed = parseInt(limitValue, 10);
    return isNaN(parsed) ? Infinity : parsed;
  })() : Infinity;

  if (!filename) {
    log('❌ No input file provided!', colors.red);
    process.exit(1);
  }

  // Read input file
  log(`\n📄 Reading movies from ${filename}...`, colors.cyan);
  
  let movies: CrawledMovie[];
  try {
    const fileContent = fs.readFileSync(filename, 'utf-8');
    const parsed = JSON.parse(fileContent) as unknown;
    
    if (!Array.isArray(parsed)) {
      log('❌ Invalid file format: expected JSON array', colors.red);
      process.exit(1);
    }
    
    movies = parsed as CrawledMovie[];
    log(`✅ Loaded ${movies.length} movies from file`, colors.green);
  } catch (error) {
    const err = error as Error;
    log(`❌ Error reading file: ${err.message}`, colors.red);
    process.exit(1);
  }

  // Login
  const token = await login();

  // Check current movie count
  const initialCount = await getMovieCount(token);
  log(`\n📊 Current library: ${initialCount} movie(s)`, colors.cyan);

  // Import movies
  const startTime = Date.now();
  const results = await importBatch(token, movies, { skip, limit });
  const endTime = Date.now();
  const duration = ((endTime - startTime) / 1000 / 60).toFixed(2);

  // Summary
  log('\n' + '='.repeat(70), colors.cyan);
  log('📊 Import Summary:', colors.bright);
  log(`   ✅ Imported from TMDb: ${results.tmdb}`, colors.green);
  log(`   ✅ Created manual entries: ${results.manual}`, colors.green);
  log(`   ⏭️  Skipped (already exists): ${results.skipped}`, colors.yellow);
  if (results.failed > 0) {
    log(`   ❌ Failed: ${results.failed}`, colors.red);
  }
  log(`   ⏱️  Time taken: ${duration} minutes`, colors.cyan);

  // Check final count
  const finalCount = await getMovieCount(token);
  const newMovies = finalCount - initialCount;
  log(`\n📚 Total movies in library: ${finalCount} (+${newMovies} new)`, colors.cyan);

  log('\n🎉 Import complete! Refresh your mobile app to see the movies.', colors.green);
}

// Run main function
main()
  .catch(error => {
    const err = error as Error;
    log(`\n❌ Fatal error: ${err.message}`, colors.red);
    console.error(error);
    process.exit(1);
  });

