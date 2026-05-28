/**
 * Clears all library data so a fresh sync can be triggered.
 *
 * Usage (from backend/ directory):
 *   npx ts-node scripts/clear-library.ts
 *
 * What it does:
 *   1. Deletes all rows in library_content (self-referential FK with CASCADE,
 *      so children are automatically removed when parents are deleted — but we
 *      TRUNCATE with CASCADE to be instant regardless of row count).
 *   2. Deletes all rows in library_sync_states so the next sync re-crawls
 *      every section from scratch.
 */

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('Clearing library data...');

  // Use raw TRUNCATE CASCADE — fastest, avoids row-by-row FK checks.
  await prisma.$executeRawUnsafe('TRUNCATE TABLE library_content CASCADE');
  console.log('✓ library_content cleared');

  await prisma.$executeRawUnsafe('TRUNCATE TABLE library_sync_states CASCADE');
  console.log('✓ library_sync_states cleared');

  console.log('\nDone. Run the sync to re-import all library data.');
}

main()
  .catch((err) => {
    console.error('Error:', err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
