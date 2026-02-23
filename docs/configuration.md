# Configuration & Secrets

This project uses environment variables in **two places**:

- Backend: `backend/.env` (created from [`backend/.env.example`](../backend/.env.example))
- Mobile app: `mobile-app/.env` (see [`mobile-app/ENVIRONMENT_SETUP.md`](../mobile-app/ENVIRONMENT_SETUP.md))

## Backend (`backend/.env`)

Start by copying the template:

- [`backend/.env.example`](../backend/.env.example)

Minimum you usually need for local development:

- `DATABASE_URL` (PostgreSQL connection string)
- `JWT_SECRET`, `JWT_REFRESH_SECRET`

Features that require additional config:

- Storage uploads: `S3_*` + `CDN_URL`
- Email verification: `SMTP_*` + `FRONTEND_URL`
- CORS for mobile device testing: `CORS_ORIGIN`, `SOCKET_CORS_ORIGIN`

## Mobile app (`mobile-app/.env`)

The app reads API endpoints from `.env` (bundled via `flutter_dotenv`).

Common values:

- `API_BASE_URL` — REST base URL, typically `http://<your-ip>:3000/api/v1`
- `API_SOCKET_URL` — Socket.io base URL, typically `http://<your-ip>:3000`

See:
- [`mobile-app/ENVIRONMENT_SETUP.md`](../mobile-app/ENVIRONMENT_SETUP.md)

## Don’t commit secrets

- Keep `.env` files out of git (already covered by `.gitignore` in most setups).
- Use repo secrets (GitHub Actions) for deployment.

Deployment reference:
- [`backend/DEPLOYMENT.md`](../backend/DEPLOYMENT.md)
