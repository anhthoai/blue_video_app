-- Add persistent storage/account IDs for multi-provider routing

ALTER TABLE "users"
  ADD COLUMN IF NOT EXISTS "s3_storage_id" INTEGER NOT NULL DEFAULT 1;

ALTER TABLE "videos"
  ADD COLUMN IF NOT EXISTS "s3_storage_id" INTEGER NOT NULL DEFAULT 1;

ALTER TABLE "community_posts"
  ADD COLUMN IF NOT EXISTS "s3_storage_id" INTEGER NOT NULL DEFAULT 1;

ALTER TABLE "chat_messages"
  ADD COLUMN IF NOT EXISTS "s3_storage_id" INTEGER NOT NULL DEFAULT 1;

ALTER TABLE "categories"
  ADD COLUMN IF NOT EXISTS "s3_storage_id" INTEGER NOT NULL DEFAULT 1;

ALTER TABLE "movie_episodes"
  ADD COLUMN IF NOT EXISTS "uloz_storage_id" INTEGER NOT NULL DEFAULT 1;

ALTER TABLE "subtitles"
  ADD COLUMN IF NOT EXISTS "uloz_storage_id" INTEGER NOT NULL DEFAULT 1;

ALTER TABLE "library_content"
  ADD COLUMN IF NOT EXISTS "uloz_storage_id" INTEGER NOT NULL DEFAULT 1;
