#!/usr/bin/env node

/**
 * LGBTQ+ Tagging Script
 * 
 * Since TMDb doesn't provide LGBTQ+ classifications, this script allows you to
 * manually tag movies with LGBTQ+ types.
 * 
 * Usage:
 *   node tag-lgbtq.js <movieId> <type1> [type2] [type3]
 *   node tag-lgbtq.js --batch tag-list.txt
 * 
 * Examples:
 *   node tag-lgbtq.js abc-123-def gay
 *   node tag-lgbtq.js abc-123-def gay romance
 *   node tag-lgbtq.js --search "Heartstopper" gay
 */

const axios = require('axios');
const fs = require('fs');

const API_BASE_URL = process.env.API_URL || 'http://localhost:3000';
const LOGIN_EMAIL = process.env.ADMIN_EMAIL || 'admin@example.com';
const LOGIN_PASSWORD = process.env.ADMIN_PASSWORD || '123456';

const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  cyan: '\x1b[36m',
  bright: '\x1b[1m',
};

function log(message, color = colors.reset) {
  console.log(`${color}${message}${colors.reset}`);
}

async function login() {
  try {
    const response = await axios.post(`${API_BASE_URL}/api/v1/auth/login`, {
      email: LOGIN_EMAIL,
      password: LOGIN_PASSWORD,
    });

    const token = response.data.data?.accessToken || response.data.accessToken;
    if (token) {
      return token;
    }
    throw new Error('No token received');
  } catch (error) {
    log('❌ Login failed!', colors.red);
    log(`Error: ${error.message}`, colors.red);
    process.exit(1);
  }
}

async function searchMovie(token, title) {
  try {
    const response = await axios.get(`${API_BASE_URL}/api/v1/movies`, {
      params: { search: title, limit: 10 },
      headers: token ? { 'Authorization': `Bearer ${token}` } : {},
    });

    if (response.data.success && response.data.data.length > 0) {
      return response.data.data;
    }
    return [];
  } catch (error) {
    log(`❌ Search failed: ${error.message}`, colors.red);
    return [];
  }
}

async function tagMovie(token, movieId, lgbtqTypes) {
  try {
    log(`\n🏷️  Tagging movie ${movieId}...`, colors.yellow);

    const response = await axios.patch(
      `${API_BASE_URL}/api/v1/movies/${movieId}`,
      { lgbtqTypes },
      {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      }
    );

    if (response.data.success) {
      const movie = response.data.data;
      log(`✅ Tagged: ${movie.title}`, colors.green);
      log(`   LGBTQ+ Types: ${lgbtqTypes.join(', ')}`, colors.cyan);
      return true;
    }
    return false;
  } catch (error) {
    log(`❌ Tagging failed: ${error.message}`, colors.red);
    if (error.response?.data) {
      log(`   ${JSON.stringify(error.response.data)}`, colors.red);
    }
    return false;
  }
}

async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    log('❌ No arguments provided!', colors.red);
    log('\nUsage:', colors.bright);
    log('  node tag-lgbtq.js <movieId> <type1> [type2] ...');
    log('  node tag-lgbtq.js --search "Movie Title" <type1> [type2] ...');
    log('  node tag-lgbtq.js --batch tag-list.txt');
    log('\nValid LGBTQ+ types:', colors.cyan);
    log('  gay, lesbian, bisexual, transgender, queer');
    log('\nExamples:');
    log('  node tag-lgbtq.js abc-123-uuid gay');
    log('  node tag-lgbtq.js --search "Heartstopper" gay');
    log('  node tag-lgbtq.js --search "Portrait of a Lady" lesbian');
    process.exit(1);
  }

  const token = await login();
  log('✅ Logged in successfully', colors.green);

  // Handle --search flag
  if (args[0] === '--search') {
    const title = args[1];
    const types = args.slice(2);

    if (!title || types.length === 0) {
      log('❌ Usage: node tag-lgbtq.js --search "Title" <type1> [type2]', colors.red);
      process.exit(1);
    }

    log(`\n🔍 Searching for "${title}"...`, colors.cyan);
    const movies = await searchMovie(token, title);

    if (movies.length === 0) {
      log('❌ No movies found', colors.red);
      process.exit(1);
    }

    if (movies.length > 1) {
      log(`\n📋 Found ${movies.length} movies:`, colors.yellow);
      movies.forEach((m, i) => {
        log(`   ${i + 1}. ${m.title} (${m.releaseDate ? new Date(m.releaseDate).getFullYear() : 'N/A'}) - ${m.contentType}`, colors.cyan);
        log(`      ID: ${m.id}`, colors.cyan);
      });
      log('\nPlease use specific movie ID instead of search.', colors.yellow);
      process.exit(0);
    }

    const movie = movies[0];
    log(`✅ Found: ${movie.title} (${movie.id})`, colors.green);
    await tagMovie(token, movie.id, types);
    
  } else if (args[0] === '--batch') {
    // Batch tagging from file
    log('❌ Batch tagging not yet implemented', colors.red);
    log('Use: node tag-lgbtq.js <movieId> <type>', colors.yellow);
    process.exit(1);
    
  } else {
    // Single movie tagging
    const movieId = args[0];
    const types = args.slice(1);

    if (types.length === 0) {
      log('❌ No LGBTQ+ types provided!', colors.red);
      log('Valid types: gay, lesbian, bisexual, transgender, queer', colors.yellow);
      process.exit(1);
    }

    await tagMovie(token, movieId, types);
  }

  log('\n🎉 Tagging complete! Refresh your mobile app to see updates.', colors.green);
}

main().catch(error => {
  log(`\n❌ Fatal error: ${error.message}`, colors.red);
  process.exit(1);
});

