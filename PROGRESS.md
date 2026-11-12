# Boored — Progress Tracker

## Decisions Log
- MinIO for local S3 dev (AGPL, infra only)
- Post-processing only for lecturer removal (no realtime preview)
- Riverpod for state management (modern Notifier/NotifierProvider pattern)
- ML Kit Selfie Segmentation behind swappable interface
- Platform channels + native OpenCV Android SDK for image processing
- minSdk 24, targetSdk/compileSdk 35
- swagger_parser for Dart client generation
- jose for JWT/Google token verification
- Drift for local SQLite
- Google Sign-In v7.2+ API (GoogleSignIn.instance, initialize(), authenticate())

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

---

## M1 — Google Login End to End
**Status: ✅ Complete**

### Done
- [x] Google Cloud Console setup guide with actual keystore debug SHA-1 — `docs/google-auth-setup.md`
- [x] Hono API auth routes in `apps/api/src/routes/auth.ts`:
  - `POST /v1/auth/google`: Verifies Google ID token, upserts user by `google_sub`, issues access token + hashed rotating refresh token
  - `POST /v1/auth/refresh`: Rotates refresh token, detects reuse of revoked tokens, revokes whole token family on breach
  - `POST /v1/auth/logout`: Revokes refresh token
- [x] Hono API user profile route in `apps/api/src/routes/me.ts`:
  - `GET /v1/me`: Authenticated endpoint scoped strictly by verified JWT access token subject (`c.get("user").sub`)
- [x] Auth middleware `requireAuth` in `apps/api/src/middleware/auth.ts`
- [x] Vitest route integration tests in `apps/api/src/__tests__/auth.test.ts` (all 4 tests pass against local DB)
- [x] Flutter Client Auth Integration:
  - `TokenStorage` with `flutter_secure_storage` (`apps/mobile/lib/core/storage/token_storage.dart`)
  - `AuthInterceptor` with Dio queued interceptor for automatic 401 token refresh & retry (`apps/mobile/lib/core/network/auth_interceptor.dart`)
  - `ApiClient` with baseUrl and timeout configuration (`apps/mobile/lib/core/network/api_client.dart`)
  - `AuthRepository` with `google_sign_in` 7.2.0 singleton API (`apps/mobile/lib/features/auth/data/auth_repository.dart`)
  - `AuthNotifier` Riverpod state management (`apps/mobile/lib/features/auth/presentation/auth_controller.dart`)
  - `LoginScreen` UI with loading and error states (`apps/mobile/lib/features/auth/presentation/login_screen.dart`)
  - `routerProvider` route guards redirecting unauthenticated users to `/login`
  - Widget tests for `HomeScreen` and `LoginScreen` (`apps/mobile/test/`)

### Verification Results
- `pnpm typecheck` ✅ (0 errors across contracts, db, api)
- `pnpm test` ✅ (5/5 tests passing: health + auth/me integration tests)
- `flutter analyze` ✅ (0 errors, 0 warnings)
- `flutter test` ✅ (all widget tests passing)

---

## Remaining Milestones

### M2 — Home Screen + Local SQLite Notes CRUD
**Status: ✅ Complete**

#### Done
- [x] Drift database setup (`lib/core/database/app_database.dart`) with Notes table mirroring backend schema
- [x] Code generation via build_runner (app_database.g.dart, notes_dao.g.dart)
- [x] NotesDao with full CRUD: watch, search, create, update, soft delete, restore, permanent delete
- [x] Database Riverpod provider with singleton lifecycle
- [x] NotesRepository wrapping DAO with clean API
- [x] NotesNotifier with reactive stream subscription, search, create, delete, restore
- [x] Home screen: note cards list, search bar, user avatar menu, empty/loading/error states
- [x] NoteCard widget with status chip and swipe-to-delete with undo
- [x] CreateNoteDialog with validation
- [x] NoteDetailScreen placeholder with rename and delete actions
- [x] Router updated with `/notes/:id` route
- [x] Relative time formatting utility
- [x] syncStatus column on Notes table for future M9 sync tracking

#### Verification Results
- `flutter analyze` ✅ (0 issues)
- `flutter test` ✅ (2/2 tests pass)
- `pnpm typecheck` ✅ (backend unaffected)
- `dart run build_runner build` ✅ (45 outputs)

#### Dependencies Added
- drift ^2.35.4, drift_flutter ^0.3.0, sqlite3_flutter_libs ^0.6.0, uuid ^4.5.1
- Dev: drift_dev ^2.35.1, build_runner ^2.4.0

### M3 — Camera Setup + Live Capture
**Status: ✅ Complete**

#### Done
- [x] Camera preview with board outline overlay (`lib/features/capture/presentation/widgets/board_overlay.dart`)
- [x] Interactive corner drag handles (normalized coordinates, real-time bounding polygon)
- [x] Periodic interval capture (3s/5s/10s/15s/30s selectable) writing sequentially to app-private storage (`captures/<noteId>/frame_00000.jpg`)
- [x] Wakelock integration preventing device sleep during active capture sessions
- [x] Session management & state machine via Riverpod (`CaptureNotifier`: idle, initializing, previewing, recording, stopping, error)
- [x] Disk crash recovery utility (`CaptureService.recoverFrames`)
- [x] Navigation wiring: creating a new note seamlessly directs to `/capture/:id` with custom title

#### Verification Results
- `flutter analyze` ✅ (0 issues found)
- `flutter test` ✅ (All tests passed)

### M4 — Board Corners + Rectification
**Status: ✅ Complete**

#### Done
- [x] Native OpenCV Android integration via Gradle (`com.quickbirdstudios:opencv:4.5.3.0`)
- [x] Kotlin MethodChannel bridge (`com.boored.boored/opencv`) for computer vision operations
- [x] Automatic 4-corner board detection via Canny edge detection, contour approximation, and quadrilateral classification
- [x] Normalized corner ordering algorithm (top-left, top-right, bottom-right, bottom-left)
- [x] Perspective warp transform (`Imgproc.warpPerspective`) unwarping camera angles into flat, rectified whiteboard frames
- [x] Dart `OpenCVService` wrapper interface connecting UI with native OpenCV routines
- [x] Live capture UI with automatic corner detection button + manual drag handles fallback
- [x] Real-time rectification pipeline: each periodic raw frame captured is automatically warped to `_rectified.jpg` using selected/detected corner polygon

#### Verification Results
- `flutter analyze` ✅ (0 issues found)
- `flutter test` ✅ (All tests passed)

### M5 — Enhancement + Change Detection + Keyframe Policy
**Status: ✅ Complete**

#### Done
- [x] Lighting normalization & glare/shadow suppression via CLAHE on L-channel in LAB color space
- [x] Stroke sharpening & contrast enhancement using unsharp masking filter
- [x] Inter-frame change detection algorithm in native OpenCV (comparing successive rectified frames via absolute difference thresholding)
- [x] Event type classification: `ADD` (new dark/colored marker strokes) vs `ERASE` (brightness jump towards white background) vs `NONE`
- [x] Keyframes Drift SQLite table & migration (tracking `id`, `noteId`, `index`, `timestampMs`, `eventType`, `imagePath`, `extractedText`, `syncStatus`)
- [x] `KeyframePolicyManager`:
  - Rule 1: Always persist initial frame as baseline (`INITIAL`)
  - Rule 2: Save keyframe immediately when whiteboard erase is detected to prevent loss of erased lecture notes (`ERASE`)
  - Rule 3: Save keyframe when significant new written content is added (`diffRatio >= 4%`)
- [x] Dynamic UI keyframe counter on capture control bar displaying saved keyframe count alongside raw frame count

#### Verification Results
- `flutter analyze` ✅ (0 issues found)
- `flutter test` ✅ (All tests passed)

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
