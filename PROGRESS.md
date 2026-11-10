# Boored — Progress Tracker

## Decisions Log
- MinIO for local S3 dev (AGPL, infra only)
- Post-processing only for lecturer removal (no realtime preview)
- Riverpod for state management
- ML Kit Selfie Segmentation behind swappable interface
- Platform channels + native OpenCV Android SDK for image processing
- minSdk 24, targetSdk/compileSdk 35
- swagger_parser for Dart client generation
- jose for JWT/Google token verification
- Drift for local SQLite

---

## M0 — Monorepo Scaffold
**Status: ✅ Complete**

### Done
- [x] Root config files (pnpm-workspace.yaml, package.json, .gitignore, .editorconfig, .env.example)
- [x] Docker Compose (Postgres 16, MinIO) — `infra/docker-compose.yml`
- [x] Hono API with health route + OpenAPI spec at /v1/openapi.json — `apps/api/`
- [x] Drizzle schema (6 tables, 4 enums, indexes, FKs, tsvector) + migration generated — `packages/db/`
- [x] Zod contract schemas (auth, note, keyframe, region, file, sync, search) — `packages/contracts/`
- [x] Flutter app launching with placeholder home screen — `apps/mobile/`
- [x] CI workflows (API + Flutter) — `.github/workflows/`
- [x] README with one-command local setup
- [x] docs/ADR-001-architecture.md + docs/setup-guide.md

### Verification Results
- `pnpm install` ✅
- `pnpm typecheck` ✅ (all 3 packages pass)
- `pnpm test` ✅ (health route test passes)
- `pnpm db:generate` ✅ (migration SQL generated)
- `flutter analyze` ✅ (no issues)
- `flutter test` ✅ (home screen test passes)
- `pnpm infra:up` ⚠️ Docker daemon not running on this machine (compose file is valid)

### How to Run
```bash
cp .env.example .env
pnpm install
pnpm infra:up        # needs Docker running
pnpm db:migrate      # needs Postgres running
pnpm dev             # starts API at http://localhost:3000
cd apps/mobile && flutter run  # starts Flutter app
```

---

## Remaining Milestones

### M1 — Google Login End to End
- [ ] Google Cloud Console setup (OAuth client IDs, SHA-1 fingerprints)
- [ ] Flutter: google_sign_in integration
- [ ] API: POST /v1/auth/google (verify ID token, upsert user, issue tokens)
- [ ] API: POST /v1/auth/refresh, POST /v1/auth/logout
- [ ] API: GET /v1/me
- [ ] Auth middleware (JWT verification, user scoping)
- [ ] Flutter: token storage + auto-refresh interceptor
- [ ] Refresh token rotation with family-based reuse detection

### M2 — Home Screen + Local SQLite Notes CRUD
- [ ] Drift database setup with note tables
- [ ] Notes CRUD in Drift (create, read, update, soft delete)
- [ ] Home screen: note cards with title, date, status chip
- [ ] Search by title
- [ ] New note / rename / delete flows

### M3 — Camera Setup + Live Capture
- [ ] Camera preview with board outline overlay
- [ ] Corner selection with drag handles
- [ ] Interval capture to app-private storage
- [ ] Foreground service with persistent notification
- [ ] Wake lock, battery/thermal monitoring
- [ ] Crash recovery from disk
- [ ] Acceptance: 30-minute session without crash

### M4 — Board Corners + Rectification
- [ ] Automatic four-corner detection (OpenCV via platform channels)
- [ ] Perspective transform to flat image
- [ ] Manual correction fallback
- [ ] Periodic re-check during capture

### M5 — Enhancement + Change Detection + Keyframe Policy
- [ ] Lighting normalization, glare/shadow suppression
- [ ] Adaptive thresholding, stroke sharpening
- [ ] Frame registration (alignment to reference)
- [ ] Change detection (ADD/ERASE/NONE classification)
- [ ] Keyframe policy: save before erase, on significant new content
- [ ] Acceptance: no content lost before erase events

### M6 — Lecturer Removal
- [ ] ML Kit Selfie Segmentation integration
- [ ] Multi-frame compositing for occluded regions
- [ ] SegmentationEngine interface
- [ ] Privacy: strip all person-containing frames

### M7 — Final Pass
- [ ] Text recognition (ML Kit) on each keyframe
- [ ] RecognitionEngine interface
- [ ] Timeline JSON generation
- [ ] PDF generation with pdf package
- [ ] Deduplication of near-identical keyframes

### M8 — Note View
- [ ] Timeline player: scrubber, play/pause, speed control
- [ ] Highlighted added/erased content
- [ ] Pages tab: keyframe grid, zoom, copy text, save image
- [ ] PDF tab: in-app preview, download, share
- [ ] Save to Downloads via SAF (no broad storage permission)

### M9 — Sync
- [ ] Outbox queue with retry/backoff
- [ ] PUT /notes/:id (idempotent upsert with version check)
- [ ] PUT /notes/:id/keyframes (batch upsert)
- [ ] Presigned upload/download for files
- [ ] GET /sync/pull?cursor= and POST /sync/push
- [ ] Conflict resolution (version check, last-writer-wins with text protection)
- [ ] Per-note sync status UI (Pending/Syncing/Synced/Failed)
- [ ] Acceptance: offline notes appear after reconnecting

### M10 — Hardening
- [ ] Full-text search (GET /search?q=)
- [ ] Settings screen (capture interval, quality, auto-delete, storage, sync)
- [ ] DELETE /v1/me (account deletion with file cleanup)
- [ ] Auto-delete enforcement (local + server)
- [ ] Additional tests (pipeline stages, sync integration)
- [ ] Battery and processing time benchmark
