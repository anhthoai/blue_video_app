#!/usr/bin/env node

/**
 * Import Movies from Crawled Data
 * 
 * This script imports movies from a JSON file (e.g., movies-full.json from b4watch crawler).
 * It searches TMDb by title first, and if not found, creates a manual entry.
 * 
 * Usage:
 *   node import-from-crawl.js movies-full.json
 *   node import-from-crawl.js movies-full.json --limit=100
 *   node import-from-crawl.js movies-full.json --skip=50 --limit=50
 */

const axios = require('axios');
const fs = require('fs');

const API_BASE_URL = process.env.API_URL || 'http://127.0.0.1:3000';
const LOGIN_EMAIL = process.env.ADMIN_EMAIL || 'admin@example.com';
const LOGIN_PASSWORD = process.env.ADMIN_PASSWORD || '123456';

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
};

function log(message, color = colors.reset) {
  console.log(`${color}${message}${colors.reset}`);
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Login and get authentication token
 */
async function login() {
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
    if (error.response) {
      log(`Error: ${error.response.data.message || error.message}`, colors.red);
    } else {
      log(`Error: ${error.message}`, colors.red);
    }
    process.exit(1);
  }
}

/**
 * Search TMDb by title
 */
async function searchTmdb(token, title) {
  try {
    const response = await axios.get(`${API_BASE_URL}/api/v1/movies/external/tmdb/search`, {
      params: { query: title },
      headers: { 'Authorization': `Bearer ${token}` },
    });

    if (response.data.success && response.data.data && response.data.data.length > 0) {
      return response.data.data[0]; // Return first result
    }
    return null;
  } catch (error) {
    console.error(`   TMDb search error: ${error.message}`);
    return null;
  }
}

/**
 * Import movie by TMDb ID
 */
async function importFromTmdb(token, tmdbResult) {
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
      return { success: true, movie: response.data.results[0].movie, source: 'tmdb' };
    }
    return { success: false, message: response.data.message };
  } catch (error) {
    if (error.response?.status === 409 || error.response?.data?.message?.includes('already exists')) {
      return { success: false, message: 'Already exists', alreadyExists: true };
    }
    return { success: false, message: error.message };
  }
}

/**
 * Create manual movie entry
 */
async function createManualEntry(token, crawledMovie) {
  try {
    const payload = {
      contentType: 'MOVIE',
      title: crawledMovie.title,
      posterUrl: crawledMovie.thumbnailUrl,
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
      return { success: true, movie: response.data.data, source: 'manual' };
    }
    return { success: false, message: response.data.message };
  } catch (error) {
    if (error.response?.status === 409 || error.response?.data?.message?.includes('already exists')) {
      return { success: false, message: 'Already exists', alreadyExists: true };
    }
    return { success: false, message: error.response?.data?.message || error.message };
  }
}

/**
 * Check if movie already exists by sourceUrl
 */
async function checkExistsBySourceUrl(token, sourceUrl) {
  try {
    const response = await axios.get(`${API_BASE_URL}/api/v1/movies`, {
      params: { sourceUrl, limit: 1 },
      headers: { 'Authorization': `Bearer ${token}` },
    });

    if (response.data.success && response.data.data?.length > 0) {
      return response.data.data[0];
    }
    return null;
  } catch (error) {
    return null;
  }
}

/**
 * Import a single movie from crawled data
 */
async function importMovie(token, crawledMovie, index, total) {
  log(`\n[${index}/${total}] Processing: ${crawledMovie.title}`, colors.bright);
  log(`   Source: ${crawledMovie.sourceUrl}`, colors.cyan);

  try {
    // Step 1: Check if already imported by sourceUrl
    const existing = await checkExistsBySourceUrl(token, crawledMovie.sourceUrl);
    if (existing) {
      log(`   ⏭️  Already imported (ID: ${existing.id})`, colors.yellow);
      return { success: false, alreadyExists: true };
    }

    // Step 2: Search TMDb by title
    log(`   🔍 Searching TMDb...`, colors.blue);
    const tmdbResult = await searchTmdb(token, crawledMovie.title);

    if (tmdbResult) {
      log(`   ✅ Found on TMDb: ${tmdbResult.title || tmdbResult.name} (${tmdbResult.media_type})`, colors.green);
      log(`   📥 Importing from TMDb...`, colors.blue);
      
      const result = await importFromTmdb(token, tmdbResult);
      
      if (result.success) {
        log(`   ✅ Imported from TMDb (ID: ${result.movie.id})`, colors.green);
        return result;
      } else if (result.alreadyExists) {
        log(`   ⏭️  Already exists in database`, colors.yellow);
        return { success: false, alreadyExists: true };
      } else {
        log(`   ⚠️  TMDb import failed: ${result.message}`, colors.yellow);
        log(`   📝 Creating manual entry...`, colors.blue);
        const manualResult = await createManualEntry(token, crawledMovie);
        
        if (manualResult.success) {
          log(`   ✅ Created manual entry (ID: ${manualResult.movie.id})`, colors.green);
          return manualResult;
        } else if (manualResult.alreadyExists) {
          log(`   ⏭️  Already exists in database`, colors.yellow);
          return { success: false, alreadyExists: true };
        } else {
          log(`   ❌ Manual entry failed: ${manualResult.message}`, colors.red);
          return { success: false, message: manualResult.message };
        }
      }
    } else {
      log(`   ⚠️  Not found on TMDb`, colors.yellow);
      log(`   📝 Creating manual entry...`, colors.blue);
      
      const manualResult = await createManualEntry(token, crawledMovie);
      
      if (manualResult.success) {
        log(`   ✅ Created manual entry (ID: ${manualResult.movie.id})`, colors.green);
        return manualResult;
      } else if (manualResult.alreadyExists) {
        log(`   ⏭️  Already exists in database`, colors.yellow);
        return { success: false, alreadyExists: true };
      } else {
        log(`   ❌ Manual entry failed: ${manualResult.message}`, colors.red);
        return { success: false, message: manualResult.message };
      }
    }
  } catch (error) {
    log(`   ❌ Error: ${error.message}`, colors.red);
    return { success: false, message: error.message };
  }
}

/**
 * Import batch of movies
 */
async function importBatch(token, movies, options = {}) {
  const { skip = 0, limit = Infinity } = options;
  
  const moviesToImport = movies.slice(skip, skip + limit);
  const total = moviesToImport.length;
  
  log(`\n📦 Importing ${total} movies (skip: ${skip}, limit: ${limit})...`, colors.bright);
  log('='.repeat(70), colors.cyan);
  
  const results = {
    tmdb: 0,
    manual: 0,
    skipped: 0,
    failed: 0,
  };

  for (let i = 0; i < moviesToImport.length; i++) {
    const movie = moviesToImport[i];
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
      await sleep(1000); // 1 second delay
    }
  }

  return results;
}

/**
 * Get current movie count
 */
async function getMovieCount(token) {
  try {
    const response = await axios.get(`${API_BASE_URL}/api/v1/movies`, {
      params: { limit: 1 },
      headers: { 'Authorization': `Bearer ${token}` },
    });

    if (response.data.success) {
      return response.data.pagination.total;
    }
    return 0;
  } catch (error) {
    return 0;
  }
}

/**
 * Main execution
 */
async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    log('❌ No input file provided!', colors.red);
    log('\nUsage:', colors.bright);
    log('  node import-from-crawl.js movies-full.json');
    log('  node import-from-crawl.js movies-full.json --limit=100');
    log('  node import-from-crawl.js movies-full.json --skip=50 --limit=50');
    log('\nOptions:', colors.bright);
    log('  --skip=N    Skip first N movies');
    log('  --limit=N   Import maximum N movies');
    process.exit(1);
  }

  // Parse arguments
  const filename = args.find(arg => !arg.startsWith('--'));
  const skipArg = args.find(arg => arg.startsWith('--skip='));
  const limitArg = args.find(arg => arg.startsWith('--limit='));
  
  const skip = skipArg ? parseInt(skipArg.split('=')[1]) : 0;
  const limit = limitArg ? parseInt(limitArg.split('=')[1]) : Infinity;

  // Read input file
  log(`\n📄 Reading movies from ${filename}...`, colors.cyan);
  
  let movies;
  try {
    const fileContent = fs.readFileSync(filename, 'utf-8');
    movies = JSON.parse(fileContent);
    
    if (!Array.isArray(movies)) {
      log('❌ Invalid file format: expected JSON array', colors.red);
      process.exit(1);
    }
    
    log(`✅ Loaded ${movies.length} movies from file`, colors.green);
  } catch (error) {
    log(`❌ Error reading file: ${error.message}`, colors.red);
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
main().catch(error => {
  log(`\n❌ Fatal error: ${error.message}`, colors.red);
  console.error(error);
  process.exit(1);
});

