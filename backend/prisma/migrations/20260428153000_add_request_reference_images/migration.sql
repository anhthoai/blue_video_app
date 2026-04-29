ALTER TABLE "community_requests"
ADD COLUMN "reference_images" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
ADD COLUMN "file_directory" TEXT,
ADD COLUMN "s3_storage_id" INTEGER NOT NULL DEFAULT 1;
