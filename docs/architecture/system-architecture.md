# System Architecture

## High-level flow

1. **Mobile app** calls the backend REST API at `API_BASE_URL`.
2. **Backend** authenticates requests (JWT) and reads/writes to **PostgreSQL**.
3. For media:
   - Backend stores uploaded files in **S3-compatible storage** (e.g. Cloudflare R2)
   - Backend returns public URLs (often rewritten using `CDN_URL`)
4. For real-time features:
   - Mobile connects to **Socket.io** at `API_SOCKET_URL`

## Backend composition

- Entrypoint and route registration: [`backend/src/server.ts`](../../backend/src/server.ts)
- Prisma client (DB access): [`backend/prisma/schema.prisma`](../../backend/prisma/schema.prisma)
- Swagger UI: `GET /api-docs`

## Environment boundaries

- Backend env: `backend/.env` (start from [`backend/.env.example`](../../backend/.env.example))
- Mobile env: `mobile-app/.env` (see [`mobile-app/ENVIRONMENT_SETUP.md`](../../mobile-app/ENVIRONMENT_SETUP.md))

## Notes

Some features have dedicated guides (library import, subtitles, email verification, payments). See [`docs/reference-guides.md`](../reference-guides.md).
