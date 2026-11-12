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
**Status: ✅ Complete**

#### Done
- [x] Swappable `SegmentationEngine` domain interface with confidence thresholding (`hasPerson` flag)
- [x] On-device `MLKitSegmentationEngine` implementation using `google_mlkit_selfie_segmentation`
- [x] Native OpenCV multi-frame compositing bridge (`compositeNative` via `Imgproc.resize` + mask overlay)
- [x] Dart `LecturerRemovalProcessor`: evaluates sequence of keyframes, isolates unoccluded background segments, and composites clear board content over lecturer-blocked regions
- [x] Privacy compliance: automatically deletes intermediate person-containing frames after compositing

#### Verification Results
- `flutter analyze` ✅ (0 issues found)
- `flutter test` ✅ (All tests passed)

### M7 — Final Pass
**Status: ✅ Complete**

#### Done
- [x] Swappable `RecognitionEngine` interface for text recognition
- [x] On-device `MLKitRecognitionEngine` implementation with `google_mlkit_text_recognition`
- [x] `SessionFinalizer` coordinator pipeline:
  - Lecturer de-occlusion sequence processing
  - Keyframe-level text extraction saved to Drift database (`extractedText` column)
  - `timeline.json` persistence formatted for timeline scrubbing and indexing
  - High-res vector-formatted PDF generation using `pdf` package (`document.pdf` in landscape A4)
  - Note status state transition: `recording` → `processing` → `ready`

#### Verification Results
- `flutter analyze` ✅ (0 issues found)
- `flutter test` ✅ (All tests passed)

### M8 — Note View
**Status: ✅ Complete**

#### Done
- [x] Multi-tab interactive Note View (`Timeline`, `Pages`, `PDF`)
- [x] Timeline Player:
  - Interactive scrubbing slider across keyframes
  - Play / Pause state machine with variable speed selector (0.5x, 1.0x, 2.0x)
  - Event type badge display (`ADD`, `ERASE`, `INITIAL`)
- [x] Pages Grid tab:
  - Grid presentation of extracted keyframes
  - One-tap OCR text copy to clipboard
  - Tap card to jump directly to that point in timeline player
- [x] PDF Viewer tab:
  - High-res vector rendering via `pdfx` (`PdfViewPinch` with pinch-to-zoom support)
  - Native Android share sheet integration via `SharePlus`
  - Action trigger to execute final processing pass (`SessionFinalizer`) directly from UI

#### Verification Results
- `flutter analyze` ✅ (0 issues found)
- `flutter test` ✅ (All tests passed)

### M9 — Sync
**Status: ✅ Complete**

#### Done
- [x] Backend sync routes:
  - `POST /v1/sync/push`: Idempotent upserting for local notes and keyframes with optimistic version concurrency checks
  - `GET /v1/sync/pull`: Incremental change fetching with cursor tracking (`updated_at` timestamps)
- [x] Vitest integration suite for sync endpoints (`apps/api/src/__tests__/sync.test.ts` - 3/3 passing)
- [x] Mobile `SyncNotifier`:
  - Outbox push for un-synced notes & keyframes
  - Pull updates with conflict protection (remote vs local versioning check)
  - Automatic `pending` count calculation
- [x] Home screen sync indicator with reactive pending badge and one-tap manual sync

#### Verification Results
- `pnpm typecheck` ✅ (0 errors)
- `pnpm test` ✅ (8/8 tests passing across auth, health, sync)
- `flutter analyze` ✅ (0 issues found)
- `flutter test` ✅ (All tests passed)

### M10 — Hardening & Final Polish
**Status: ✅ Complete**

#### Done
- [x] Full-text search endpoint (`GET /v1/search?q=`) using Postgres tsvector & GIN index matching against note titles, summaries, and keyframe OCR texts
- [x] Account deletion endpoint (`DELETE /v1/me`) with cascade purge across notes, keyframes, regions, refresh tokens, and files
- [x] Mobile Settings screen (`lib/features/settings/settings_screen.dart`):
  - User profile display (avatar, name, email)
  - Cloud synchronization status indicator & on-demand sync trigger
  - Cache size inspection & local cache clearing
  - Account deletion confirmation dialog with session teardown & routing back to login
  - App version and build details
- [x] App router registration (`/settings`) and navigation link in HomeScreen user avatar menu
- [x] End-to-end build and test validation:
  - TypeScript contracts, db, and API typecheck (`tsc --noEmit`)
  - Vitest suite passing 8/8 tests (health, auth, me, sync)
  - Flutter analysis (0 warnings / 0 errors)
  - Flutter unit and widget test suite passing
  - Flutter Android debug APK build compilation (`assembleDebug`) passing cleanly
