# Documentation Consolidation Map

This repo has a lot of valuable, feature-specific docs—many created during active implementation. Over time, the main maintenance risk is **doc drift** (multiple files describing the same thing with conflicting “current status” and stale file paths).

This document proposes a consolidation approach **without moving or deleting files** yet.

## Principles

- Prefer **one canonical doc per topic**.
- Other docs become either:
  - **Reference** (deep dive, still accurate)
  - **Changelog/status** (historical snapshot)
  - **Archive** (kept for history, not maintained)
- Keep “how to run” and “where is the code” in the docs hub:
  - [`docs/getting-started.md`](getting-started.md)
  - [`docs/repo-structure.md`](repo-structure.md)
  - [`docs/configuration.md`](configuration.md)

## Known drift issues to fix (high value)

### 1) `server-local.ts` references

`backend/src/server-local.ts` does **not** exist in this repo; the entrypoint is:

- [`backend/src/server.ts`](../backend/src/server.ts)

Many markdown files still mention `server-local.ts` (Swagger, email verification/testing, library backend docs, deployment diagrams, etc.).

Suggested cleanup:
- Global find/replace in markdown: `server-local.ts` → `server.ts`
- Where the text refers to compiled output (e.g. `dist/server-local.js`), align it with the actual build output used by your deployment.

### 2) “Complete” vs “In Progress” contradictions

Some areas have multiple docs that disagree on status (common with progress/status logs). Pick one canonical “current state” doc and treat the rest as historical.

## Canonical docs by topic

### Project entry points

- Canonical hub: [`docs/README.md`](README.md)
- Canonical run instructions: [`docs/getting-started.md`](getting-started.md)
- Canonical repo map: [`docs/repo-structure.md`](repo-structure.md)

### Backend (API + deployment)

- Canonical backend setup/usage: [`backend/README.md`](../backend/README.md)
- Canonical deployment: [`backend/DEPLOYMENT.md`](../backend/DEPLOYMENT.md)
- Supporting (workflow/checklists):
  - [`\.github/DEPLOYMENT_CHECKLIST.md`](../.github/DEPLOYMENT_CHECKLIST.md)
  - [`\.github/DEPLOYMENT_WORKFLOW.md`](../.github/DEPLOYMENT_WORKFLOW.md)
  - [`\.github/POST_DEPLOYMENT.md`](../.github/POST_DEPLOYMENT.md)

Suggested consolidation action:
- Keep `.github/*` docs as *supporting*, but ensure they don’t contain stale build file names (example: `server-local.js`).

### API docs

- Canonical “how to view API docs”: [`docs/architecture/api-documentation.md`](architecture/api-documentation.md)
- Supporting details:
  - [`SWAGGER_DOCUMENTATION.md`](../SWAGGER_DOCUMENTATION.md)
  - [`backend/API_DOCUMENTATION.md`](../backend/API_DOCUMENTATION.md)

### Mobile app

- Canonical mobile overview: [`mobile-app/README.md`](../mobile-app/README.md)
- Canonical environment setup: [`mobile-app/ENVIRONMENT_SETUP.md`](../mobile-app/ENVIRONMENT_SETUP.md)
- Testing:
  - Canonical detailed testing steps: [`mobile-app/TESTING_GUIDE.md`](../mobile-app/TESTING_GUIDE.md)
  - Short status note (optional): [`mobile-app/README_TESTING.md`](../mobile-app/README_TESTING.md) (archived stub)

Potential drift to watch:
- The mobile testing docs are heavily oriented around **mock data / no real API**. If the app is now partially connected to the backend (e.g. Library), either:
  - Keep these docs but label them clearly as “Mock mode”, or
  - Update them to describe both modes (mock vs real API).

### Library feature

These docs overlap a lot. Suggested “one canonical entry point”:

- Canonical overview & quick reference: [`LIBRARY_COMPLETE_GUIDE.md`](../LIBRARY_COMPLETE_GUIDE.md)

Supporting docs (keep, but treat as deep dives / historical snapshots):
- Spec / scope: [`LIBRARY_FEATURE.md`](../LIBRARY_FEATURE.md)
- Setup steps (may overlap with backend README): [`LIBRARY_SETUP_INSTRUCTIONS.md`](../LIBRARY_SETUP_INSTRUCTIONS.md)
- Backend implementation details: [`LIBRARY_BACKEND_COMPLETE.md`](../LIBRARY_BACKEND_COMPLETE.md) (archived stub)
- Testing checklist style docs:
  - [`LIBRARY_TESTING_GUIDE.md`](../LIBRARY_TESTING_GUIDE.md)
  - [`FINAL_TESTING_CHECKLIST.md`](../FINAL_TESTING_CHECKLIST.md)
  - [`QUICK_START.md`](../QUICK_START.md)
- Phase/summary snapshots:
  - [`LIBRARY_PHASE2_COMPLETE.md`](../LIBRARY_PHASE2_COMPLETE.md) (archived stub)
  - [`COMPLETE_SETUP_SUMMARY.md`](../COMPLETE_SETUP_SUMMARY.md) (archived stub)

Suggested consolidation action:
- Add a short “Status & entry links” section at the top of `LIBRARY_COMPLETE_GUIDE.md` that links to the other docs, and treat the others as supporting.

### Movie playback & player

Pick one canonical “current behavior” doc (recommended):

- Canonical: [`MOVIE_PLAYER_WITH_EPISODES.md`](../MOVIE_PLAYER_WITH_EPISODES.md)

Supporting:
- External-player integration notes: [`MOVIE_PLAYBACK_COMPLETE.md`](../MOVIE_PLAYBACK_COMPLETE.md) (archived stub; previous content in git history)
- Detail screen specifics: [`MOVIE_DETAIL_SCREEN_GUIDE.md`](../MOVIE_DETAIL_SCREEN_GUIDE.md)

Potential drift to watch:
- `MOVIE_PLAYBACK_COMPLETE.md` describes launching an **external player**.
- `MOVIE_PLAYER_WITH_EPISODES.md` describes an **in-app player**.

These can both be true historically; choose one as “current” and mark the other as “previous approach”.

### Subtitles

- Canonical: [`SUBTITLE_COMPLETE_GUIDE.md`](../SUBTITLE_COMPLETE_GUIDE.md)
- Supporting backend notes:
  - [`backend/SUBTITLE_SUPPORT.md`](../backend/SUBTITLE_SUPPORT.md)
  - [`backend/SUBTITLE_IMPORT_FIXES.md`](../backend/SUBTITLE_IMPORT_FIXES.md)

Likely outdated:
- [`SUBTITLE_FEATURE_SUMMARY.md`](../SUBTITLE_FEATURE_SUMMARY.md) is now an archived stub to avoid contradictions. Previous content is available via git history.

### Email verification

- Canonical: [`EMAIL_VERIFICATION_GUIDE.md`](../EMAIL_VERIFICATION_GUIDE.md)
- Supporting:
  - [`TESTING_EMAIL_VERIFICATION.md`](../TESTING_EMAIL_VERIFICATION.md)
  - [`EMAIL_AUTHENTICATION_FIX.md`](../EMAIL_AUTHENTICATION_FIX.md)

Suggested consolidation action:
- Ensure these docs reference the correct backend entrypoint (`backend/src/server.ts`).

### Payments

- Canonical testing doc: [`PAYMENT_TESTING_GUIDE.md`](../PAYMENT_TESTING_GUIDE.md)
- Supporting backend overview/examples: [`backend/README.md`](../backend/README.md)

### Translation

These three documents overlap and may contradict each other:

- [`TRANSLATION_STATUS.md`](../TRANSLATION_STATUS.md)
- [`TRANSLATION_PROGRESS.md`](../TRANSLATION_PROGRESS.md)
- [`TRANSLATION_COMPLETE.md`](../TRANSLATION_COMPLETE.md)

Recommendation:
- Use [`TRANSLATION_COMPLETE.md`](../TRANSLATION_COMPLETE.md) as canonical (current state).
- The other two are archived stubs to reduce duplication; previous content is available via git history.

## Suggested next step (optional)

If you want, I can do a targeted cleanup pass to reduce drift without restructuring files:

1. Fix remaining `server-local.ts` references in the most-used docs
2. Add “Canonical / Historical” labels at the top of the most duplicated guides
3. Update translation/subtitle docs to remove contradictions
