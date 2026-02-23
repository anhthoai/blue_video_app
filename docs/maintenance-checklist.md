# Maintenance Checklist

Use this list when changing the repo so docs don’t drift.

## When you add/change an API endpoint

- Confirm Swagger still renders: `GET /api-docs`
- Update/verify:
  - [`docs/architecture/api-documentation.md`](./architecture/api-documentation.md)
  - Any feature guide in [`docs/reference-guides.md`](./reference-guides.md)

## When you change DB schema

- Update Prisma schema: [`backend/prisma/schema.prisma`](../backend/prisma/schema.prisma)
- Run/verify migration commands used by the team (document if changed):
  - [`docs/architecture/database-design.md`](./architecture/database-design.md)
  - [`backend/MIGRATION_COMMANDS.md`](../backend/MIGRATION_COMMANDS.md)

## When you add env vars

- Backend: update [`backend/.env.example`](../backend/.env.example)
- Mobile: update [`mobile-app/ENVIRONMENT_SETUP.md`](../mobile-app/ENVIRONMENT_SETUP.md)
- Then update [`docs/configuration.md`](./configuration.md)

## When you add a new feature guide

- Prefer placing it near the code (repo root or component folder).
- Add a link in [`docs/reference-guides.md`](./reference-guides.md).

## When you add new docs under /docs

- Link it from [`docs/README.md`](./README.md)
