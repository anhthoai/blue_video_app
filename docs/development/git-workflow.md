# Git Workflow

## Branching

- `main` is the primary branch.
- Use feature branches for changes (e.g. `feature/library-filters`, `fix/email-verification`).

## PR checklist (practical)

- Backend changes: run `npm test` (if applicable) + `npm run lint`.
- Mobile changes: run `flutter analyze` + relevant tests.
- Docs changes: ensure links in [`docs/README.md`](../README.md) still resolve.
