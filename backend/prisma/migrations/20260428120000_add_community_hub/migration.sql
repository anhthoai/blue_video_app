DO $$ BEGIN
    CREATE TYPE "community_request_status" AS ENUM ('OPEN', 'ENDED');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE "community_request_submission_type" AS ENUM ('FILE_UPLOAD', 'LINKED_VIDEO');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE "community_posts"
    ADD COLUMN IF NOT EXISTS "forum_id" TEXT;

CREATE TABLE IF NOT EXISTS "community_forums" (
    "id" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "subtitle" TEXT NOT NULL,
    "description" TEXT,
    "accent_start" TEXT NOT NULL DEFAULT '#4F7DFF',
    "accent_end" TEXT NOT NULL DEFAULT '#5FD4FF',
    "keywords" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    "post_count" INTEGER NOT NULL DEFAULT 0,
    "is_hot" BOOLEAN NOT NULL DEFAULT false,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_by_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "community_forums_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "community_forum_follows" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "forum_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "community_forum_follows_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "community_requests" (
    "id" TEXT NOT NULL,
    "author_id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "board_label" TEXT NOT NULL DEFAULT 'Latest',
    "keywords" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    "preview_hints" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    "base_coins" INTEGER NOT NULL DEFAULT 0,
    "bonus_coins" INTEGER NOT NULL DEFAULT 0,
    "want_count" INTEGER NOT NULL DEFAULT 0,
    "reply_count" INTEGER NOT NULL DEFAULT 0,
    "supporter_count" INTEGER NOT NULL DEFAULT 0,
    "is_featured" BOOLEAN NOT NULL DEFAULT false,
    "status" "community_request_status" NOT NULL DEFAULT 'OPEN',
    "approved_submission_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "community_requests_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "community_request_wants" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "request_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "community_request_wants_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "community_request_supports" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "request_id" TEXT NOT NULL,
    "coins" INTEGER NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "community_request_supports_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "community_request_submissions" (
    "id" TEXT NOT NULL,
    "request_id" TEXT NOT NULL,
    "contributor_id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "type" "community_request_submission_type" NOT NULL,
    "linked_video_url" TEXT,
    "search_keyword" TEXT,
    "file_name" TEXT,
    "file_directory" TEXT,
    "s3_storage_id" INTEGER NOT NULL DEFAULT 1,
    "mime_type" TEXT,
    "likes" INTEGER NOT NULL DEFAULT 0,
    "comments" INTEGER NOT NULL DEFAULT 0,
    "play_count" INTEGER NOT NULL DEFAULT 0,
    "is_approved" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "community_request_submissions_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "community_forums_slug_key" ON "community_forums"("slug");
CREATE INDEX IF NOT EXISTS "community_posts_forum_id_idx" ON "community_posts"("forum_id");
CREATE INDEX IF NOT EXISTS "community_forums_is_hot_sort_order_idx" ON "community_forums"("is_hot", "sort_order");
CREATE INDEX IF NOT EXISTS "community_forums_created_by_id_idx" ON "community_forums"("created_by_id");
CREATE UNIQUE INDEX IF NOT EXISTS "community_forum_follows_user_id_forum_id_key" ON "community_forum_follows"("user_id", "forum_id");
CREATE INDEX IF NOT EXISTS "community_forum_follows_forum_id_idx" ON "community_forum_follows"("forum_id");
CREATE INDEX IF NOT EXISTS "community_requests_author_id_idx" ON "community_requests"("author_id");
CREATE INDEX IF NOT EXISTS "community_requests_status_idx" ON "community_requests"("status");
CREATE INDEX IF NOT EXISTS "community_requests_is_featured_created_at_idx" ON "community_requests"("is_featured", "created_at");
CREATE UNIQUE INDEX IF NOT EXISTS "community_request_wants_user_id_request_id_key" ON "community_request_wants"("user_id", "request_id");
CREATE INDEX IF NOT EXISTS "community_request_wants_request_id_idx" ON "community_request_wants"("request_id");
CREATE INDEX IF NOT EXISTS "community_request_supports_user_id_idx" ON "community_request_supports"("user_id");
CREATE INDEX IF NOT EXISTS "community_request_supports_request_id_idx" ON "community_request_supports"("request_id");
CREATE INDEX IF NOT EXISTS "community_request_submissions_request_id_idx" ON "community_request_submissions"("request_id");
CREATE INDEX IF NOT EXISTS "community_request_submissions_contributor_id_idx" ON "community_request_submissions"("contributor_id");
CREATE INDEX IF NOT EXISTS "community_request_submissions_is_approved_idx" ON "community_request_submissions"("is_approved");

DO $$ BEGIN
    ALTER TABLE "community_posts"
        ADD CONSTRAINT "community_posts_forum_id_fkey"
        FOREIGN KEY ("forum_id") REFERENCES "community_forums"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE "community_forums"
        ADD CONSTRAINT "community_forums_created_by_id_fkey"
        FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE "community_forum_follows"
        ADD CONSTRAINT "community_forum_follows_user_id_fkey"
        FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE "community_forum_follows"
        ADD CONSTRAINT "community_forum_follows_forum_id_fkey"
        FOREIGN KEY ("forum_id") REFERENCES "community_forums"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE "community_requests"
        ADD CONSTRAINT "community_requests_author_id_fkey"
        FOREIGN KEY ("author_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE "community_request_wants"
        ADD CONSTRAINT "community_request_wants_user_id_fkey"
        FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE "community_request_wants"
        ADD CONSTRAINT "community_request_wants_request_id_fkey"
        FOREIGN KEY ("request_id") REFERENCES "community_requests"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE "community_request_supports"
        ADD CONSTRAINT "community_request_supports_user_id_fkey"
        FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE "community_request_supports"
        ADD CONSTRAINT "community_request_supports_request_id_fkey"
        FOREIGN KEY ("request_id") REFERENCES "community_requests"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE "community_request_submissions"
        ADD CONSTRAINT "community_request_submissions_request_id_fkey"
        FOREIGN KEY ("request_id") REFERENCES "community_requests"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE "community_request_submissions"
        ADD CONSTRAINT "community_request_submissions_contributor_id_fkey"
        FOREIGN KEY ("contributor_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;
