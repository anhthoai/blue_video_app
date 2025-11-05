#!/usr/bin/env node

/**
 * Movie Import Script
 * 
 * Usage:
 *   node import-movies.js tt14452776
 *   node import-movies.js tt14452776 tt13406036 tt5164432
 *   node import-movies.js --batch movies.txt
 */

const axios = require('axios');
const fs = require('fs');

const API_BASE_URL = process.env.API_URL || 'http://localhost:3000';
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
};

function log(message, color = colors.reset) {
  console.log(`${color}${message}${colors.reset}`);
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
 * Import a single movie by IMDb ID
 */
async function importMovie(token, imdbId) {
  try {
    log(`\n📥 Importing ${imdbId}...`, colors.yellow);

    const response = await axios.post(
      `${API_BASE_URL}/api/v1/movies/import/imdb`,
      { imdbId },
      {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      }
    );

    if (response.data.success) {
      const result = response.data.results[0];
      if (result.success) {
        const movie = result.movie;
        log(`✅ Successfully imported: ${movie.title}`, colors.green);
        log(`   Type: ${movie.contentType}`, colors.cyan);
        log(`   Genres: ${movie.genres?.join(', ') || 'N/A'}`, colors.cyan);
        log(`   Year: ${movie.releaseDate ? new Date(movie.releaseDate).getFullYear() : 'N/A'}`, colors.cyan);
        log(`   Rating: ${movie.voteAverage || 'N/A'}/10`, colors.cyan);
        log(`   Movie ID: ${movie.id}`, colors.cyan);
        return { success: true, movie };
      } else {
        log(`⚠️  Import failed: ${result.message}`, colors.yellow);
        return { success: false, message: result.message };
      }
    } else {
      log(`❌ Import failed: ${response.data.message}`, colors.red);
      return { success: false, message: response.data.message };
    }
  } catch (error) {
    if (error.response?.status === 409 || error.response?.data?.message?.includes('already exists')) {
      log(`⚠️  Movie already exists (${imdbId})`, colors.yellow);
      return { success: false, message: 'Already exists' };
    }
    log(`❌ Error importing ${imdbId}: ${error.message}`, colors.red);
    if (error.response?.data) {
      log(`   Details: ${JSON.stringify(error.response.data)}`, colors.red);
    }
    return { success: false, message: error.message };
  }
}

/**
 * Import multiple movies
 */
async function importBatch(token, imdbIds) {
  log(`\n📦 Batch importing ${imdbIds.length} movies...`, colors.bright);
  
  const results = {
    success: 0,
    failed: 0,
    skipped: 0,
  };

  for (let i = 0; i < imdbIds.length; i++) {
    const imdbId = imdbIds[i].trim();
    if (!imdbId) continue;

    log(`\n[${i + 1}/${imdbIds.length}] ${imdbId}`, colors.bright);
    
    const result = await importMovie(token, imdbId);
    
    if (result.success) {
      results.success++;
    } else if (result.message?.includes('already exists')) {
      results.skipped++;
    } else {
      results.failed++;
    }

    // Small delay between imports to avoid rate limiting
    if (i < imdbIds.length - 1) {
      await new Promise(resolve => setTimeout(resolve, 500));
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
      headers: token ? { 'Authorization': `Bearer ${token}` } : {},
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
    log('❌ No IMDb IDs provided!', colors.red);
    log('\nUsage:', colors.bright);
    log('  node import-movies.js tt14452776');
    log('  node import-movies.js tt14452776 tt13406036 tt5164432');
    log('  node import-movies.js --batch movies.txt');
    log('\nExample movies.txt file:');
    log('  tt14452776  # Heartstopper');
    log('  tt13406036  # Young Royals');
    log('  tt5164432   # Love, Simon');
    process.exit(1);
  }

  // Login
  const token = await login();

  // Check current movie count
  const initialCount = await getMovieCount(token);
  log(`\n📊 Current library: ${initialCount} movie(s)`, colors.cyan);

  let imdbIds = [];

  // Check if batch import from file
  if (args[0] === '--batch' && args[1]) {
    const filename = args[1];
    log(`\n📄 Reading IMDb IDs from ${filename}...`, colors.cyan);
    
    try {
      const fileContent = fs.readFileSync(filename, 'utf-8');
      imdbIds = fileContent
        .split('\n')
        .map(line => line.split('#')[0].trim()) // Remove comments
        .filter(line => line && line.startsWith('tt'));
      
      log(`✅ Found ${imdbIds.length} IMDb IDs`, colors.green);
    } catch (error) {
      log(`❌ Error reading file: ${error.message}`, colors.red);
      process.exit(1);
    }
  } else {
    // Single or multiple IDs from command line
    imdbIds = args;
  }

  log(`\n🎬 Importing ${imdbIds.length} movie(s)...`, colors.bright);
  log('='.repeat(50), colors.cyan);

  // Import movies
  let results;
  if (imdbIds.length === 1) {
    const result = await importMovie(token, imdbIds[0]);
    results = {
      success: result.success ? 1 : 0,
      failed: result.success ? 0 : 1,
      skipped: 0,
    };
  } else {
    results = await importBatch(token, imdbIds);
  }

  // Summary
  log('\n' + '='.repeat(50), colors.cyan);
  log('📊 Import Summary:', colors.bright);
  log(`   ✅ Successfully imported: ${results.success}`, colors.green);
  if (results.skipped > 0) {
    log(`   ⏭️  Skipped (already exists): ${results.skipped}`, colors.yellow);
  }
  if (results.failed > 0) {
    log(`   ❌ Failed: ${results.failed}`, colors.red);
  }

  // Check final count
  const finalCount = await getMovieCount(token);
  const newMovies = finalCount - initialCount;
  log(`\n📚 Total movies in library: ${finalCount} (+${newMovies} new)`, colors.cyan);

  log('\n🎉 Import complete! Refresh your mobile app to see the movies.', colors.green);
}

// Run main function
main().catch(error => {
  log(`\n❌ Fatal error: ${error.message}`, colors.red);
  process.exit(1);
});

