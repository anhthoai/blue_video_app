# Repo Structure

## Top-level folders

- `mobile-app/` — Flutter app (UI + client-side services)
- `backend/` — Node.js + TypeScript API server (Express) and Prisma schema
- `landing-page/` — Placeholder docs for a future marketing site
- `docs/` — Documentation hub (this folder)
- `references/` — DB dumps and reference scripts/data

## Key files by area

### Backend

- Entrypoint/server wiring: [`backend/src/server.ts`](../backend/src/server.ts)
- Prisma schema (tables/enums): [`backend/prisma/schema.prisma`](../backend/prisma/schema.prisma)
- Backend scripts:
  - Import movies: [`backend/import-movies.js`](../backend/import-movies.js)
  - Import episodes: [`backend/import-episodes.js`](../backend/import-episodes.js)
  - Tag LGBTQ content: [`backend/tag-lgbtq.js`](../backend/tag-lgbtq.js)
- Environment template: [`backend/.env.example`](../backend/.env.example)

### Mobile app

- Entrypoint: [`mobile-app/lib/main.dart`](../mobile-app/lib/main.dart)
- API base URL usage: [`mobile-app/lib/core/services/api_service.dart`](../mobile-app/lib/core/services/api_service.dart)
- Env setup guide: [`mobile-app/ENVIRONMENT_SETUP.md`](../mobile-app/ENVIRONMENT_SETUP.md)

## “Guides” that are not under /docs

A lot of feature-specific documents live at repo root (e.g. library, subtitles, email verification, payments). See:
- [`docs/reference-guides.md`](reference-guides.md)
