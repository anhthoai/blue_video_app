import 'dotenv/config';

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

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

function log(message: string, color: string = colors.reset): void {
  console.log(`${color}${message}${colors.reset}`);
}

/**
 * Get statistics about movies in database
 */
async function getMovieStats(): Promise<{
  totalMovies: number;
  totalEpisodes: number;
  totalSubtitles: number;
}> {
  const totalMovies = await prisma.movie.count();
  const totalEpisodes = await prisma.movieEpisode.count();
  const totalSubtitles = await prisma.subtitle.count();

  return {
    totalMovies,
    totalEpisodes,
    totalSubtitles,
  };
}

/**
 * Delete all movies (cascades to episodes and subtitles)
 */
async function deleteAllMovies(): Promise<void> {
  log('\n🗑️  Deleting all movies...', colors.red);
  
  // Delete all movies (cascades to episodes and subtitles)
  const result = await prisma.movie.deleteMany({});
  
  log(`✅ Deleted ${result.count} movie(s)`, colors.green);
  log('   (Episodes and subtitles were automatically deleted due to cascade)', colors.cyan);
}

/**
 * Main execution
 */
async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const hasConfirmFlag = args.includes('--confirm');

  if (!hasConfirmFlag) {
    log('❌ This script will delete ALL movies from the database!', colors.red);
    log('\n⚠️  WARNING: This action cannot be undone!', colors.yellow);
    log('   This will delete:', colors.bright);
    log('   - All movies', colors.red);
    log('   - All episodes (cascade)', colors.red);
    log('   - All subtitles (cascade)', colors.red);
    
    log('\n📊 Current database statistics:', colors.cyan);
    const stats = await getMovieStats();
    log(`   Movies: ${stats.totalMovies}`, colors.cyan);
    log(`   Episodes: ${stats.totalEpisodes}`, colors.cyan);
    log(`   Subtitles: ${stats.totalSubtitles}`, colors.cyan);
    
    log('\n💡 To proceed, run with --confirm flag:', colors.bright);
    log('   npx ts-node scripts/delete-all-movies.ts --confirm', colors.cyan);
    process.exit(1);
  }

  log('\n📊 Current database statistics:', colors.cyan);
  const beforeStats = await getMovieStats();
  log(`   Movies: ${beforeStats.totalMovies}`, colors.cyan);
  log(`   Episodes: ${beforeStats.totalEpisodes}`, colors.cyan);
  log(`   Subtitles: ${beforeStats.totalSubtitles}`, colors.cyan);

  if (beforeStats.totalMovies === 0) {
    log('\n✅ Database is already empty. Nothing to delete.', colors.green);
    await prisma.$disconnect();
    return;
  }

  log('\n⚠️  Proceeding with deletion...', colors.yellow);
  
  try {
    await deleteAllMovies();
    
    log('\n📊 Final database statistics:', colors.cyan);
    const afterStats = await getMovieStats();
    log(`   Movies: ${afterStats.totalMovies}`, colors.cyan);
    log(`   Episodes: ${afterStats.totalEpisodes}`, colors.cyan);
    log(`   Subtitles: ${afterStats.totalSubtitles}`, colors.cyan);
    
    log('\n✅ All movie data has been deleted successfully!', colors.green);
  } catch (error) {
    const err = error as Error;
    log(`\n❌ Error deleting movies: ${err.message}`, colors.red);
    console.error(error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

// Run main function
main()
  .catch(error => {
    const err = error as Error;
    log(`\n❌ Fatal error: ${err.message}`, colors.red);
    console.error(error);
    process.exit(1);
  });

