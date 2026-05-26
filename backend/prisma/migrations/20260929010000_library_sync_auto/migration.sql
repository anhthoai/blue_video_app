-- Add sync_generation to library_content for stale-entry pruning
ALTER TABLE "library_content"
ADD COLUMN IF NOT EXISTS "sync_generation" VARCHAR(100);

CREATE INDEX IF NOT EXISTS "library_content_sync_generation_idx"
  ON "library_content" ("sync_generation");

-- Create library_sync_states table
CREATE TABLE IF NOT EXISTS "library_sync_states" (
  "id"              TEXT PRIMARY KEY,
  "storage_id"      INTEGER NOT NULL,
  "section"         VARCHAR(100) NOT NULL,
  "folder_slug"     VARCHAR(500) NOT NULL,
  "status"          VARCHAR(20) NOT NULL DEFAULT 'idle',
  "sync_generation" VARCHAR(100),
  "last_sync_at"    TIMESTAMPTZ,
  "started_at"      TIMESTAMPTZ,
  "finished_at"     TIMESTAMPTZ,
  "last_tick_at"    TIMESTAMPTZ,
  "error_message"   TEXT,
  "total_indexed"   INTEGER NOT NULL DEFAULT 0,
  "created_at"      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at"      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS "library_sync_states_section_idx"
  ON "library_sync_states" ("section");

CREATE INDEX IF NOT EXISTS "library_sync_states_status_idx"
  ON "library_sync_states" ("status");
