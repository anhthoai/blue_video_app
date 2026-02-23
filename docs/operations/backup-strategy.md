# Backup Strategy

## Database

- PostgreSQL is the primary source of truth.
- Keep periodic `pg_dump` backups.

Reference artifacts already in the repo (useful for restores/dev):

- [`references/blue_video_db.sql`](../../references/blue_video_db.sql)
- [`references/blue_video_db.dump`](../../references/blue_video_db.dump)

## Media storage

Videos/images live in S3-compatible storage (e.g. Cloudflare R2). Ensure your bucket policies + lifecycle rules match your retention needs.

## Secrets

- Do not store `.env` in the repo.
- Store deployment credentials in GitHub Secrets.

Deployment guide: [`backend/DEPLOYMENT.md`](../../backend/DEPLOYMENT.md)
