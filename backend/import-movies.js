#!/usr/bin/env node

/**
 * Movie Import Script
 * 
 * Usage:
 *   node import-movies.js tt14452776
 *   node import-movies.js 278137
 *   node import-movies.js tt14452776 278137 tt5164432
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

function normalizeIdentifier(input) {
  const trimmed = `${input}`.trim();

  if (!trimmed) return null;

  const urlMatch = trimmed.match(/themoviedb\.org\/(movie|tv)\/(\d+)/i);
  if (urlMatch) {
    return `${urlMatch[1].toLowerCase()}:${urlMatch[2]}`;
  }

  const prefixMatch = trimmed.match(/^(movie|tv)[/:](\d+)$/i);
  if (prefixMatch) {
    return `${prefixMatch[1].toLowerCase()}:${prefixMatch[2]}`;
  }

  if (/^tt\d+$/i.test(trimmed) || /^\d+$/.test(trimmed)) {
    return trimmed;
  }

  return null;
}

function displayIdentifierInfo(identifier) {
  if (identifier.startsWith('tv:')) {
    return { label: 'TMDb TV', formatted: identifier, payload: identifier };
  }
  if (identifier.startsWith('movie:')) {
    return { label: 'TMDb Movie', formatted: identifier, payload: identifier };
  }
  if (/^tt\d+$/i.test(identifier)) {
    return { label: 'IMDb', formatted: identifier, payload: identifier };
  }
  if (/^\d+$/.test(identifier)) {
    return { label: 'TMDb', formatted: identifier, payload: identifier };
  }

  return { label: 'Unknown', formatted: identifier, payload: identifier };
}

async function importMovie(token, identifierInput) {
  const normalized = normalizeIdentifier(identifierInput);

  if (!normalized) {
    log(`⚠️  Skipping invalid identifier: ${identifierInput}`, colors.yellow);
    return { success: false, message: 'Invalid identifier' };
  }

  const { label } = displayIdentifierInfo(normalized);
  try {
    log(`\n📥 Importing ${normalized} (${label})...`, colors.yellow);

    const response = await axios.post(
      `${API_BASE_URL}/api/v1/movies/import/imdb`,
      { identifiers: [normalized] },
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
      if (Array.isArray(response.data.results) && response.data.results.length > 0) {
        response.data.results.forEach((item, idx) => {
          log(`   [${idx + 1}] ${item.identifier || item.imdbId || item.tmdbId || 'Unknown'} -> ${item.message}`, colors.red);
        });
      }
      return { success: false, message: response.data.message };
    }
  } catch (error) {
    if (error.response?.status === 409 || error.response?.data?.message?.includes('already exists')) {
      log(`⚠️  Movie already exists (${normalized})`, colors.yellow);
      return { success: false, message: 'Already exists' };
    }
    log(`❌ Error importing ${normalized}: ${error.message}`, colors.red);
    if (error.response?.data) {
      log(`   Details: ${JSON.stringify(error.response.data)}`, colors.red);
    }
    return { success: false, message: error.message };
  }
}

/**
 * Import multiple movies
 */
async function importBatch(token, rawIds) {
  log(`\n📦 Batch importing ${rawIds.length} movies...`, colors.bright);
  
  const results = {
    success: 0,
    failed: 0,
    skipped: 0,
  };

  for (let i = 0; i < rawIds.length; i++) {
    const identifier = rawIds[i].trim();
    if (!identifier) continue;

    log(`\n[${i + 1}/${rawIds.length}] ${identifier}`, colors.bright);
    
    const result = await importMovie(token, identifier);
    
    if (result.success) {
      results.success++;
    } else if (result.message?.includes('already exists')) {
      results.skipped++;
    } else {
      results.failed++;
    }

    // Small delay between imports to avoid rate limiting
    if (i < rawIds.length - 1) {
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

  let movieIdentifiers = [];

  // Check if batch import from file
  if (args[0] === '--batch' && args[1]) {
    const filename = args[1];
    log(`\n📄 Reading identifiers from ${filename}...`, colors.cyan);
    
    try {
      const fileContent = fs.readFileSync(filename, 'utf-8');
      movieIdentifiers = fileContent
        .split('\n')
        .map(line => line.split('#')[0].trim())
        .map(line => normalizeIdentifier(line))
        .filter(Boolean);

      log(`✅ Found ${movieIdentifiers.length} valid identifier(s)`, colors.green);
    } catch (error) {
      log(`❌ Error reading file: ${error.message}`, colors.red);
      process.exit(1);
    }
  } else {
    // Single or multiple IDs from command line
    movieIdentifiers = args
      .map(value => normalizeIdentifier(value))
      .filter(Boolean);
  }

  log(`\n🎬 Importing ${movieIdentifiers.length} movie(s)...`, colors.bright);
  log('='.repeat(50), colors.cyan);

  // Import movies
  let results;
  if (movieIdentifiers.length === 1) {
    const result = await importMovie(token, movieIdentifiers[0]);
    results = {
      success: result.success ? 1 : 0,
      failed: result.success ? 0 : 1,
      skipped: 0,
    };
  } else {
    results = await importBatch(token, movieIdentifiers);
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
    log('   Review logs above for detailed reasons.', colors.red);
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

