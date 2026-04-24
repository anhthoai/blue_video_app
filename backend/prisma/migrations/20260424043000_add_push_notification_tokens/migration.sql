CREATE TABLE "push_notification_tokens" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "platform" VARCHAR(50) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "last_used_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "push_notification_tokens_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "push_notification_tokens_token_key" ON "push_notification_tokens"("token");
CREATE INDEX "push_notification_tokens_user_id_idx" ON "push_notification_tokens"("user_id");
CREATE INDEX "push_notification_tokens_updated_at_idx" ON "push_notification_tokens"("updated_at");

ALTER TABLE "push_notification_tokens"
ADD CONSTRAINT "push_notification_tokens_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;