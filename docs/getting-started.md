# Getting Started

This folder is the **documentation hub** for Blue Video App. Most “deep dives” already live in the repo root, `backend/`, and `mobile-app/`.

## What to run first (local dev)

### 1) Backend API (Node.js + PostgreSQL)

1. Open a terminal in `backend/`
2. Create env file from the template:
   - Copy [`backend/.env.example`](../backend/.env.example) to `backend/.env` and fill the required values.
3. Install + start:

```bash
cd backend
npm install
npx prisma generate
npx prisma db push
npm run dev
```

API docs: `http://localhost:3000/api-docs`

More details:
- Backend README: [`backend/README.md`](../backend/README.md)
- Deployment guide: [`backend/DEPLOYMENT.md`](../backend/DEPLOYMENT.md)

### 2) Mobile app (Flutter)

1. Configure API URLs (device vs emulator):
   - See [`mobile-app/ENVIRONMENT_SETUP.md`](../mobile-app/ENVIRONMENT_SETUP.md)
2. Install + run:

```bash
cd mobile-app
flutter pub get
flutter run
```

More details:
- Mobile README: [`mobile-app/README.md`](../mobile-app/README.md)
- Testing guide: [`mobile-app/TESTING_GUIDE.md`](../mobile-app/TESTING_GUIDE.md)

### 3) Quick smoke test (Library feature)

If you want an end-to-end sanity check (backend + mobile), start here:
- [`QUICK_START.md`](../QUICK_START.md)

## Where the code starts

- Backend entrypoint: [`backend/src/server.ts`](../backend/src/server.ts)
- Database schema: [`backend/prisma/schema.prisma`](../backend/prisma/schema.prisma)
- Mobile entrypoint: [`mobile-app/lib/main.dart`](../mobile-app/lib/main.dart)

## If something breaks

Start with:
- [`FINAL_TESTING_CHECKLIST.md`](../FINAL_TESTING_CHECKLIST.md)
- [`FIXES_APPLIED.md`](../FIXES_APPLIED.md)
