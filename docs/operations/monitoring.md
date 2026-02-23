# Monitoring

## Backend

Suggested basics:

- Monitor PM2 process status (see [`backend/DEPLOYMENT.md`](../../backend/DEPLOYMENT.md))
- Track server logs (PM2 + Nginx if used)
- Use `GET /api-docs` and a simple health request to confirm the server is up

## Error reports

If you add structured logging/monitoring (Sentry, Datadog, New Relic), document the env vars in:

- [`docs/configuration.md`](../configuration.md)
