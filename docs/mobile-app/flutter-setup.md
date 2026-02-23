# Flutter Setup Guide

## Prerequisites

- Flutter (stable) matching the constraints in [`mobile-app/pubspec.yaml`](../../mobile-app/pubspec.yaml)
- Android Studio / Xcode as needed

## Install + run

From `mobile-app/`:

```bash
flutter pub get
flutter run
```

## Configure API endpoints

The app reads API URLs from `mobile-app/.env`.

- See: [`mobile-app/ENVIRONMENT_SETUP.md`](../../mobile-app/ENVIRONMENT_SETUP.md)

## Troubleshooting

- If running on a physical device, prefer using your PC LAN IP instead of `localhost`.
- For Android emulator, use `10.0.2.2`.

More details: [`docs/configuration.md`](../configuration.md)
