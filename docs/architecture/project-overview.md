# Project Overview

Blue Video App is a full-stack video streaming + social platform.

## Components

- **Mobile app (Flutter)**: UI, client-side state, API calls, playback.
  - Source: [`mobile-app/`](../../mobile-app/)
- **Backend API (Node.js + TypeScript)**: REST API + Socket.io, file uploads, payments, email verification.
  - Source: [`backend/`](../../backend/)
- **Database (PostgreSQL via Prisma)**: main persistence layer.
  - Schema: [`backend/prisma/schema.prisma`](../../backend/prisma/schema.prisma)
- **Storage (S3-compatible / Cloudflare R2)**: videos/images with CDN URL rewriting.

## Documentation pointers

- Quick start (backend + mobile): [`docs/getting-started.md`](../getting-started.md)
- Repo map: [`docs/repo-structure.md`](../repo-structure.md)
- Existing feature guides: [`docs/reference-guides.md`](../reference-guides.md)
