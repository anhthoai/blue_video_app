ALTER TABLE "community_request_submissions"
ADD COLUMN IF NOT EXISTS "linked_media_metadata" JSONB;