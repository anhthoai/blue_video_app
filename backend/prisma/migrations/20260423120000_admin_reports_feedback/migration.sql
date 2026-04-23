ALTER TABLE "community_post_reports"
ADD COLUMN "status" "report_status" NOT NULL DEFAULT 'PENDING',
ADD COLUMN "admin_reply" TEXT,
ADD COLUMN "reviewed_at" TIMESTAMP(3),
ADD COLUMN "reviewed_by" TEXT,
ADD COLUMN "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE "user_reports"
ADD COLUMN "admin_reply" TEXT,
ADD COLUMN "reviewed_at" TIMESTAMP(3),
ADD COLUMN "reviewed_by" TEXT;

CREATE TABLE "video_reports" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "video_id" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "description" TEXT,
    "status" "report_status" NOT NULL DEFAULT 'PENDING',
    "admin_reply" TEXT,
    "reviewed_at" TIMESTAMP(3),
    "reviewed_by" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "video_reports_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "feedback_entries" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "subject" TEXT,
    "message" TEXT NOT NULL,
    "status" "report_status" NOT NULL DEFAULT 'PENDING',
    "admin_reply" TEXT,
    "replied_at" TIMESTAMP(3),
    "replied_by" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "feedback_entries_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "video_reports_user_id_video_id_key" ON "video_reports"("user_id", "video_id");
CREATE INDEX "community_post_reports_status_idx" ON "community_post_reports"("status");
CREATE INDEX "user_reports_status_idx" ON "user_reports"("status");
CREATE INDEX "video_reports_status_idx" ON "video_reports"("status");
CREATE INDEX "feedback_entries_status_idx" ON "feedback_entries"("status");

ALTER TABLE "video_reports"
ADD CONSTRAINT "video_reports_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "video_reports"
ADD CONSTRAINT "video_reports_video_id_fkey"
FOREIGN KEY ("video_id") REFERENCES "videos"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "feedback_entries"
ADD CONSTRAINT "feedback_entries_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;