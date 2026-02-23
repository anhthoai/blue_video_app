# Project Master Checklist (Status + TODO)

This document is the **single source of truth** for:

1. **Implementation roadmap** (what we plan to build next)
2. **Verification checklists** (what we must test to call something “done”)

If you add a new feature doc that contains a checklist, **link it here** (don’t create a second competing checklist).

## How to use this doc

- Treat this file as the canonical “project status” page.
- When a PR lands:
  - Update the relevant checkboxes.
  - Add/adjust links to the canonical deep-dive docs.
- Prefer **checkboxes** for anything that can be verified.

## Start here

- Getting started (backend + mobile): [getting-started.md](./getting-started.md)
- Configuration/secrets: [configuration.md](./configuration.md)
- Existing feature guides index: [reference-guides.md](./reference-guides.md)

---

## Implementation roadmap (product)

Primary roadmap lives in the repo root README; this section mirrors it so the “status + TODO” view stays centralized:

- Roadmap source: [../README.md](../README.md)

### Phase 1: Core Application

- [x] Core Flutter app structure
- [x] Backend API (Node.js + Express + PostgreSQL)
- [x] Authentication system (JWT + Email verification)
- [x] Email service (SMTP with Nodemailer)
- [x] Video streaming with complete player
- [x] Video upload functionality with categories and tags
- [x] Social features (follow, like, comment, share)
- [x] User profiles (current user and other users)
- [x] Search functionality (videos, users, posts)
- [x] Community posts with media and interactions
- [x] Real-time chat with Socket.io
- [x] Multi-language support (EN, ZH, JA)
- [x] Theme system (Light, Dark, System)
- [x] UI overflow fixes and responsive design
- [x] Coin/VIP Posts system with payment integration
- [x] Real payment gateway (USDT TRC20 + Credit Card)
- [x] Coin recharge and transaction history
- [x] IPN (Instant Payment Notification) workflow
- [x] API Documentation (Swagger/OpenAPI)
- [x] Deployment automation (GitHub Actions)

### Phase 2: Enhancements

- [x] Email verification system
- [ ] Social login (Google, Apple)
- [ ] Push notifications (Firebase Cloud Messaging)
- [ ] Video processing pipeline (FFmpeg)
- [ ] Advanced analytics dashboard
- [ ] Content moderation tools
- [ ] Live streaming support
- [ ] Stories feature completion
- [ ] Advanced search filters

### Phase 3: Web & Additional Platforms

- [ ] Web landing page
- [ ] Web app (PWA)
- [ ] Admin dashboard (web)
- [ ] Desktop app (Windows, macOS, Linux)
- [ ] TV app (Android TV, Apple TV)

### Phase 4: Advanced Features

- [ ] AI-powered content recommendations
- [ ] Video transcoding and adaptive bitrate
- [ ] CDN integration
- [ ] Advanced monetization options
- [ ] Creator analytics and insights

---

## Verification checklists (engineering)

This section is intentionally practical: it’s the “what do we test next?” list.

### Library feature (end-to-end)

Canonical overview:
- Library guide: [../LIBRARY_COMPLETE_GUIDE.md](../LIBRARY_COMPLETE_GUIDE.md)
- Quick start runbook: [../QUICK_START.md](../QUICK_START.md)
- Final testing checklist: [../FINAL_TESTING_CHECKLIST.md](../FINAL_TESTING_CHECKLIST.md)
- Fix log / known fixes: [../FIXES_APPLIED.md](../FIXES_APPLIED.md)

#### Backend (Library)

From [../FINAL_TESTING_CHECKLIST.md](../FINAL_TESTING_CHECKLIST.md):
- [x] Movie import from TMDb/IMDb
- [x] Episode import from uloz.to
- [x] LGBTQ+ tagging system
- [x] Dynamic filter options
- [x] Movie CRUD operations
- [x] Authentication
- [x] Stream URL generation

#### Mobile (Library)

From [../FINAL_TESTING_CHECKLIST.md](../FINAL_TESTING_CHECKLIST.md):
- [x] Library navigation (replaced Discover)
- [x] Movies screen with grid
- [x] 3-tier dynamic filters
- [x] Pull-to-refresh
- [x] Movie detail screen
- [x] Episode display for TV series

#### Remaining verification TODO (Library)

From [../FINAL_TESTING_CHECKLIST.md](../FINAL_TESTING_CHECKLIST.md):
- [ ] Validate filter combinations (genre/type/LGBTQ+) on real data
- [ ] Episode import end-to-end (requires uloz.to VIP credentials configured)

### Movie player (in-app episode selection)

Canonical doc:
- [../MOVIE_PLAYER_WITH_EPISODES.md](../MOVIE_PLAYER_WITH_EPISODES.md)

Remaining verification TODO (from the player doc):
- [ ] Test with actual video playback (needs device)
- [ ] Test with multiple episodes
- [ ] Test with different video formats

### Subtitles (backend + mobile)

Canonical doc:
- [../SUBTITLE_COMPLETE_GUIDE.md](../SUBTITLE_COMPLETE_GUIDE.md)

#### Backend testing

- [ ] Import folder with subtitles
- [ ] Console shows subtitle detection
- [ ] Database has subtitle records (Prisma Studio)
- [ ] API includes subtitles in response
- [ ] No duplicate subtitles on re-import
- [ ] New subtitles added to existing episodes
- [ ] All languages detected correctly

#### Mobile testing (detail screen)

- [ ] Open movie with subtitles
- [ ] Pull to refresh
- [ ] Subtitle buttons appear below episodes
- [ ] Flag emojis display correctly
- [ ] Tapping button opens browser
- [ ] uloz.to download page opens

#### Mobile testing (player)

- [ ] CC button visible in controls
- [ ] Bottom sheet opens and includes “Off”
- [ ] Selecting a language loads subtitles (SnackBar + CC turns yellow)
- [ ] Subtitle text displays and stays in sync
- [ ] Switching subtitles works
- [ ] Turning “Off” hides subtitles

### Translations (EN / ZH / JA)

Canonical doc:
- [../TRANSLATION_COMPLETE.md](../TRANSLATION_COMPLETE.md)

Manual testing checklist (from the translation doc):
- [ ] Change language in Settings
- [ ] Verify bottom navigation updates
- [ ] Check Home screen
- [ ] Check Discover screen
- [ ] Check Community screen
- [ ] Check Chat screen
- [ ] Check Profile screen
- [ ] Check Search screen
- [ ] Check Login screen
- [ ] Check Register screen
- [ ] Verify language persists after app restart
- [ ] Test dialogs and error messages

### Payments (real gateway + mock IPN)

Canonical doc:
- [../PAYMENT_TESTING_GUIDE.md](../PAYMENT_TESTING_GUIDE.md)

Verification TODO:
- [ ] Configure gateway env vars in backend/.env (MPS keys + BASE_URL)
- [ ] Create an invoice from the mobile app and confirm orderId returned
- [ ] Real payment test (gateway WebView submit + IPN callback received)
- [ ] Confirm client polling detects COMPLETED
- [ ] Mock IPN test (local dev): trigger mock IPN endpoint and confirm COMPLETED
- [ ] Production safety: confirm mock IPN is not exposed/reachable in prod

### Email verification

Canonical docs:
- [../EMAIL_VERIFICATION_GUIDE.md](../EMAIL_VERIFICATION_GUIDE.md)
- [../TESTING_EMAIL_VERIFICATION.md](../TESTING_EMAIL_VERIFICATION.md)

Verification TODO:
- [ ] Configure SMTP credentials in backend/.env
- [ ] Register a new user and confirm verification email is sent
- [ ] Confirm verification link works and user becomes verified
- [ ] Confirm unverified-user limitations behave as expected (if applicable)

### API docs (Swagger)

Canonical docs:
- [../SWAGGER_DOCUMENTATION.md](../SWAGGER_DOCUMENTATION.md)
- [architecture/api-documentation.md](./architecture/api-documentation.md)

Verification TODO:
- [ ] Backend running locally exposes Swagger UI at /api-docs
- [ ] OpenAPI JSON endpoint is reachable

---

## Docs maintenance checklist (avoid drift)

- Maintenance checklist: [maintenance-checklist.md](./maintenance-checklist.md)
- Consolidation/drift map: [consolidation-map.md](./consolidation-map.md)

Verification TODO:
- [ ] New docs under docs/ are linked from docs/README.md
- [ ] Backend entrypoint references stay consistent (backend/src/server.ts)
- [ ] Duplicate/conflicting docs are converted to archived stubs and linked to canonical docs
