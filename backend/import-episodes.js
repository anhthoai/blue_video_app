#!/usr/bin/env node

/**
 * Episode Import Script for uloz.to
 * 
 * Usage:
 *   node import-episodes.js <movieId> <folderUrl> [seasonNumber]
 *   node import-episodes.js <movieId> --file <fileUrl> <episodeNumber> [seasonNumber]
 * 
 * Examples:
 *   node import-episodes.js abc-123 https://uloz.to/folder/xyz123 1
 *   node import-episodes.js abc-123 --file https://uloz.to/file/xyz123 1 1
 */

const axios = require('axios');

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

async function getMovie(token, movieId) {
  try {
    const response = await axios.get(
      `${API_BASE_URL}/api/v1/movies/${movieId}`,
      {
        headers: { 'Authorization': `Bearer ${token}` },
      }
    );

    if (response.data.success && response.data.data) {
      return response.data.data;
    }
    return null;
  } catch (error) {
    return null;
  }
}

async function importEpisodes(token, movieId, urlOrSlug, seasonNumber, episodeNumber) {
  try {
    log(`\n📥 Importing from uloz.to...`, colors.yellow);
    log(`   URL/Slug: ${urlOrSlug}`, colors.cyan);
    log(`   Season: ${seasonNumber}`, colors.cyan);
    if (episodeNumber) {
      log(`   Episode: ${episodeNumber}`, colors.cyan);
    }

    const requestBody = {
      url: urlOrSlug,
      seasonNumber: parseInt(seasonNumber),
    };
    
    if (episodeNumber) {
      requestBody.episodeNumber = parseInt(episodeNumber);
    }

    const response = await axios.post(
      `${API_BASE_URL}/api/v1/movies/${movieId}/episodes/import/uloz`,
      requestBody,
      {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      }
    );

    if (response.data.success) {
      const newCount = response.data.data.length;
      const skippedCount = response.data.skipped || 0;
      
      if (skippedCount > 0) {
        log(`✅ Successfully imported ${newCount} new episode(s), skipped ${skippedCount} duplicate(s)`, colors.green);
      } else {
        log(`✅ Successfully imported ${newCount} episode(s)`, colors.green);
      }
      
      if (newCount > 0) {
        response.data.data.forEach((ep, i) => {
          log(`   ${i + 1}. ${ep.episodeLabel}${ep.title ? ' - ' + ep.title : ''}`, colors.cyan);
          log(`      Duration: ${ep.duration ? Math.floor(ep.duration / 60) + 'm' : 'N/A'}`, colors.cyan);
          log(`      File: ${ep.slug}`, colors.cyan);
        });
      }

      return response.data.data;
    }

    return [];
  } catch (error) {
    log(`❌ Import failed: ${error.message}`, colors.red);
    if (error.response?.data) {
      log(`   ${JSON.stringify(error.response.data, null, 2)}`, colors.red);
    }
    return [];
  }
}

async function importSingleEpisode(token, movieId, fileUrl, episodeNumber, seasonNumber) {
  try {
    log(`\n📥 Importing single episode...`, colors.yellow);
    log(`   File: ${fileUrl}`, colors.cyan);
    log(`   Episode: S${seasonNumber.toString().padStart(2, '0')}E${episodeNumber.toString().padStart(2, '0')}`, colors.cyan);

    const response = await axios.post(
      `${API_BASE_URL}/api/v1/movies/${movieId}/episodes/import/uloz`,
      {
        fileUrl,
        episodeNumber: parseInt(episodeNumber),
        seasonNumber: parseInt(seasonNumber),
      },
      {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      }
    );

    if (response.data.success) {
      const ep = response.data.data[0];
      log(`✅ Episode imported successfully`, colors.green);
      log(`   ${ep.episodeLabel}${ep.title ? ' - ' + ep.title : ''}`, colors.cyan);
      return ep;
    }

    return null;
  } catch (error) {
    log(`❌ Import failed: ${error.message}`, colors.red);
    if (error.response?.data) {
      log(`   ${JSON.stringify(error.response.data, null, 2)}`, colors.red);
    }
    return null;
  }
}

async function main() {
  const args = process.argv.slice(2);

  if (args.length < 2) {
    log('❌ Invalid arguments!', colors.red);
    log('\nUsage:', colors.bright);
    log('  node import-episodes.js <movieId> <url-or-slug> [episodeNumber] [seasonNumber]');
    log('\nExamples:');
    log('  # File slug (defaults to episode 1, season 1)');
    log('  node import-episodes.js abc-123 YINK3siyuOvV');
    log('  # File slug with episode number');
    log('  node import-episodes.js abc-123 YINK3siyuOvV 1');
    log('  # File slug with episode and season');
    log('  node import-episodes.js abc-123 YINK3siyuOvV 1 1');
    log('  # Folder URL (auto-detects all episodes, season defaults to 1)');
    log('  node import-episodes.js abc-123 https://uloz.to/folder/xyz123');
    log('\nNote:');
    log('  - episodeNumber: Optional, defaults to 1 (for main file)');
    log('  - seasonNumber: Optional, defaults to 1');
    log('  - Folders will ignore episodeNumber and auto-assign');
    log('\n⚠️  Requires uloz.to VIP account credentials in .env');
    process.exit(1);
  }

  const token = await login();
  log('✅ Logged in successfully', colors.green);

  const movieId = args[0];
  const urlOrSlug = args[1];
  const episodeNumber = args[2] ? parseInt(args[2], 10) : 1;
  const seasonNumber = args[3] ? parseInt(args[3], 10) : 1;

  // Get movie info
  const movie = await getMovie(token, movieId);
  if (!movie) {
    log(`❌ Movie not found: ${movieId}`, colors.red);
    process.exit(1);
  }

  log(`\n🎬 Movie: ${movie.title} (${movie.contentType})`, colors.cyan);

  // Auto-detect and import
  const episodes = await importEpisodes(token, movieId, urlOrSlug, seasonNumber, episodeNumber);
  
  if (episodes && episodes.length > 0) {
    log(`\n📊 Total files imported: ${episodes.length}`, colors.green);
  }

  log('\n🎉 Import complete! Refresh your mobile app to see the files.', colors.green);
}

main().catch(error => {
  log(`\n❌ Fatal error: ${error.message}`, colors.red);
  process.exit(1);
});

