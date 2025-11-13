# Ulož.to Library Importer

Command–line utility for mirroring folders from your uloz.to account into the `library_content` table.

## Features

- ✅ Works with private folders inside your uloz.to account using username, password and API key from `.env`
- ✅ Accepts either CLI arguments **or** environment variables for section/folder mappings
- ✅ Recursively walks nested subfolders and imports every file with a lower‑case `contentType` that matches its extension
- ✅ Automatically adds new sections; no schema changes required
- ✅ Re-runs safely: existing folders/files are updated instead of duplicated
- ✅ Outputs progress and detailed diagnostics (file metadata, counts, etc.)

## Requirements

1. Valid uloz.to credentials in `backend/.env`:

```dotenv
ULOZ_USERNAME=you@example.com
ULOZ_PASSWORD=your_password
ULOZ_API_KEY=your_api_key
ULOZ_BASE_URL=https://apis.uloz.to
```

2. Optional section → folder slug mappings (all lower-case section names):

```dotenv
ULOZ_LIBRARY_AUDIO_FOLDER=3C7c2EjZ1zrA
# Format: ULOZ_LIBRARY_{SECTION_NAME}_FOLDER=value
# The importer lowercases {SECTION_NAME}, replaces underscores with hyphens,
# and autogenerates a title-cased display name.
ULOZ_LIBRARY_VIDEOS_FOLDER=abc123xyz            # → section "videos"
ULOZ_LIBRARY_EBOOKS_FOLDER=slugForEpub          # → section "ebooks"
ULOZ_LIBRARY_SHORT_MOVIES_FOLDER=slugForShorts  # → section "short-movies"
ULOZ_LIBRARY_THEMED_MOVIES_FOLDER=slugForThemes # → section "themed-movies"
```

With env mappings, the importer runs without CLI arguments and will process each configured section sequentially.

## Usage

### Basic CLI invocation

```bash
npx ts-node scripts/import-uloz-library.ts \
  --folder 3C7c2EjZ1zrA \
  --section audio \
  --name "Audio"
```

Parameters:

| Flag        | Description                                                                                     |
|-------------|-------------------------------------------------------------------------------------------------|
| `--folder`  | Folder slug or path inside your uloz.to account (required)                                      |
| `--section` | Section identifier stored in the database (defaults to `other` if omitted). Use lowercase text. |
| `--name`    | Display label for the root folder (defaults to the section or slug)                             |

If CLI parameters are supplied they override any environment mappings.

### Environment-driven run

Add one or more `ULOZ_LIBRARY_*_FOLDER` variables (naming convention is up to you—only the value matters). The importer takes the text between `ULOZ_LIBRARY_` and `_FOLDER`, lowercases it, and replaces underscores with hyphens (e.g. `SHORT_MOVIES` → `short-movies`). Run:

```bash
npx ts-node scripts/import-uloz-library.ts
```

Each configured section is imported in order. You can mix CLI and env usage as needed.

## Behaviour

- **Sections & content types** are saved as lower-case strings (`audio`, `ebook`, `folder`, `video`, etc.)—matching the app’s expected format.
- The importer walks the entire folder tree depth-first. Every subfolder emits:
  - `section`–scoped `slugPath` and `filePath`
  - metadata (duration, size, mimeType, preview info if available)
- Files that already exist (matched by slug) are updated; new entries are inserted.
- S3-backed thumbnails and previews are resolved at request time (using `StorageService`).

## Diagnostics & Logging

- Shows login diagnostics and root folder slug once authenticated.
- Under each folder sync:
  - Lists counts for files/folders found via `/v8/.../file-list` and `/v9/.../folder-list`
  - Logs each inserted or updated slug with detailed metadata from `/v7/file/{slug}/private`
- A final summary prints created/updated totals.

## Troubleshooting

| Symptom                                      | Resolution                                                                                             |
|----------------------------------------------|---------------------------------------------------------------------------------------------------------|
| `Invalid authorization token` (401)          | Verify `ULOZ_API_KEY`, ensure the account credentials are correct, and regenerate tokens if necessary. |
| Folder slug not found (404)                  | Confirm the slug exists in your account, or pass a full path (`"Audio/A.M. Arthur"`).                  |
| `PrismaClientValidationError` for enum types | Run `npx prisma generate` after editing the schema; ensure `contentType/section` columns are strings.  |
| Script exits with partial imports            | Rerun the command—the importer upserts by slug, so repeated runs are safe.                             |

## Related Files

- `scripts/import-uloz-library.ts` – Implementation of the importer.
- `src/services/ulozService.ts` – Uloz.to API integration (login, folder traversal, file metadata).
- `src/controllers/libraryController.ts` – REST endpoints that serve imported data to the mobile/web apps.

Happy importing! 🚀

