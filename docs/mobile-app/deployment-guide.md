# Mobile App - Deployment Guide

This repo currently documents backend deployment in detail; mobile release steps depend on your store accounts and signing setup.

## Build commands

From `mobile-app/`:

```bash
flutter build apk --release
flutter build appbundle --release
flutter build ios --release
```

## Environment

- Ensure `mobile-app/.env` points to the production API domain.
- See [`mobile-app/ENVIRONMENT_SETUP.md`](../../mobile-app/ENVIRONMENT_SETUP.md)

## Related

- Backend deployment: [`backend/DEPLOYMENT.md`](../../backend/DEPLOYMENT.md)
