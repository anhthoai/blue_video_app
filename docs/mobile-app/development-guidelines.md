# Mobile App - Development Guidelines

## Project layout

- Screens: `mobile-app/lib/screens/`
- Core services/utilities: `mobile-app/lib/core/`
- Models: `mobile-app/lib/models/`
- Shared widgets: `mobile-app/lib/widgets/`

## Environment configuration

- [`mobile-app/ENVIRONMENT_SETUP.md`](../../mobile-app/ENVIRONMENT_SETUP.md)

## Formatting & linting

Common commands:

```bash
dart format .
flutter analyze
```

## State management & navigation

- State: Riverpod (see dependencies in [`mobile-app/pubspec.yaml`](../../mobile-app/pubspec.yaml))
- Navigation: GoRouter

## Testing

- See [`docs/mobile-app/testing-guide.md`](testing-guide.md)
