# Boored — Features & Files

## Mobile App (`apps/mobile/`)

### Google Authentication (using `google_sign_in` + backend JWT)

- `lib/features/auth/data/auth_repository.dart` — Google Sign-In flow, ID token exchange with backend, token storage
- `lib/features/auth/data/auth_user.dart` — User model (id, email, name, avatar)
- `lib/features/auth/presentation/auth_controller.dart` — Riverpod auth state management, sign-in/sign-out/session restore
- `lib/features/auth/presentation/login_screen.dart` — Login UI with Google Sign-In button
- `lib/core/storage/token_storage.dart` — Secure access/refresh token persistence (`flutter_secure_storage`)
- `lib/core/network/auth_interceptor.dart` — Dio interceptor for Bearer token injection + 401 auto-refresh
- `lib/core/constants/api_constants.dart` — API base URL and Google OAuth client ID config (supports `.env` and `--dart-define`)
- `lib/main.dart` — GoogleSignIn initialization at app startup

### Camera Capture & Periodic Frame Recording (using `camera`)

- `lib/features/capture/data/capture_service.dart` — Camera init, periodic frame capture at configurable intervals, crash recovery
- `lib/features/capture/presentation/capture_screen.dart` — Camera preview UI, permission handling, recording controls, auto-detect board button
- `lib/features/capture/presentation/capture_controller.dart` — Capture state machine (idle → previewing → recording → paused), wakelock, frame processing pipeline

### Whiteboard Detection & Perspective Correction (using OpenCV native via MethodChannel)

- `lib/features/capture/data/opencv_service.dart` — Dart MethodChannel bridge for all OpenCV operations
- `lib/features/capture/presentation/widgets/board_overlay.dart` — Draggable 4-corner overlay widget for manual board region adjustment
- `android/app/src/main/kotlin/com/boored/boored/MainActivity.kt`
  - `detectCornersNative()` — Multi-strategy corner detection (Canny + adaptive threshold + HSV whiteboard mask)
  - `warpPerspectiveNative()` — Perspective warp to flatten board to rectangle

### Whiteboard Image Enhancement (using OpenCV native)

- `lib/features/capture/data/opencv_service.dart` — `enhanceWhiteboard()` Dart call
- `android/app/src/main/kotlin/com/boored/boored/MainActivity.kt`
  - `enhanceWhiteboardNative()` — Bilateral denoising → LAB CLAHE contrast normalization → unsharp mask stroke sharpening

### Frame Change Detection & Keyframe Policy (using OpenCV native)

- `lib/features/capture/data/opencv_service.dart` — `detectFrameChange()` Dart call
- `lib/features/capture/data/keyframe_policy.dart` — Keyframe save policy: first frame always saved, ERASE events, ADD events with ≥4% diff
- `android/app/src/main/kotlin/com/boored/boored/MainActivity.kt`
  - `detectChangeNative()` — Grayscale diff + threshold → pixel ratio → brightness shift to classify ADD vs ERASE vs NONE

### Professor/Lecturer Removal (using ML Kit Selfie Segmentation + OpenCV native)

- `lib/features/capture/data/lecturer_removal_processor.dart` — Sequence-level removal: finds clean reference frames, composites over person regions
- `lib/features/capture/data/mlkit_segmentation_engine.dart` — ML Kit selfie segmentation (stream mode, raw-size mask)
- `lib/features/capture/domain/segmentation_engine.dart` — Segmentation engine interface + `SegmentationMaskResult` with `hasPerson` detection
- `android/app/src/main/kotlin/com/boored/boored/MainActivity.kt`
  - `compositeNative()` — Binary mask from confidences → morphological dilation → Gaussian blur → alpha blending current frame with clean background

### Text Recognition / OCR (using ML Kit Text Recognition)

- `lib/features/capture/data/mlkit_recognition_engine.dart` — ML Kit Latin text recognizer, iterates blocks → lines for full text extraction
- `lib/features/capture/domain/recognition_engine.dart` — Recognition engine interface

### OCR Preprocessing (using OpenCV native)

- `lib/features/capture/data/opencv_service.dart` — `preprocessForOcr()` Dart call
- `android/app/src/main/kotlin/com/boored/boored/MainActivity.kt`
  - `preprocessForOcrNative()` — Grayscale → CLAHE → adaptive threshold → median blur for binarized OCR input

### Session Finalization & PDF Generation (using `pdf` package)

- `lib/features/capture/data/session_finalizer.dart`
  - `finalizeNote()` — Full pipeline: lecturer removal → OCR extraction → timeline JSON → image PDF → digital text PDF → status update
  - `generateDigitalPdf()` — Clean typeset PDF from extracted OCR text with headers/footers/section labels

### Note Detail Viewer (Timeline, Pages Grid, PDF, Digital Copy)

- `lib/features/notes/presentation/note_detail_screen.dart` — Tabbed viewer: timeline player with transport controls, masonry pages grid, embedded PDF viewer (`pdfx`), digital copy tab, menu actions (OCR extract, remove professor, rename, open externally, save to Downloads, delete)

### Notes CRUD & Search (using Drift/SQLite)

- `lib/features/notes/data/notes_repository.dart` — Repository layer over DAO (watch, search, create, update, delete, restore)
- `lib/features/notes/presentation/notes_controller.dart` — Riverpod state: reactive note list, client-side title search, create/delete/restore/rename
- `lib/features/notes/presentation/widgets/note_card.dart` — Note list item with status chip, relative time, swipe-to-delete
- `lib/features/notes/presentation/widgets/create_note_dialog.dart` — New note title dialog

### Home Screen

- `lib/features/home/presentation/home_screen.dart` — Note list, search bar, sync badge, user avatar menu, FAB to create + capture

### Local Database (using Drift + SQLite)

- `lib/core/database/app_database.dart` — Schema: `Notes` and `Keyframes` tables with sync status tracking
- `lib/core/database/database_provider.dart` — Riverpod database singleton provider
- `lib/core/database/daos/notes_dao.dart` — Notes DAO: CRUD, soft delete, restore, versioning, watch streams
- `lib/core/database/daos/keyframes_dao.dart` — Keyframes DAO: insert (deduplicated), update image/text, watch by note

### Cloud Sync (using Dio + backend REST API)

- `lib/features/sync/sync_controller.dart` — Push pending notes/keyframes → pull remote changes → version-based conflict resolution
- `lib/core/network/api_client.dart` — Dio HTTP client with base URL, timeouts, auth interceptor

### Settings & Account Deletion

- `lib/features/settings/settings_screen.dart` — User profile display, manual sync trigger, permanent account + data deletion

### Navigation (using `go_router`)

- `lib/app/router.dart` — Auth-gated routing: `/login`, `/`, `/notes/:id`, `/capture/:id`, `/settings`

### Utilities

- `lib/core/utils/relative_time.dart` — Human-readable relative timestamps ("3 mins ago", "yesterday")

### External PDF Viewer (using Android Intent via MethodChannel)

- `android/app/src/main/kotlin/com/boored/boored/MainActivity.kt`
  - `handleOpenPdf()` — FileProvider URI + ACTION_VIEW intent chooser

---

## Backend API (`apps/api/`)

- `src/index.ts` — Server entrypoint
- `src/app.ts` — Express/Hono app setup
- `src/env.ts` — Environment config
- `src/db.ts` — Database connection
- `src/routes/auth.ts` — Google ID token verification, JWT issue, refresh, logout
- `src/routes/sync.ts` — Push/pull sync endpoints
- `src/routes/me.ts` — Current user profile, account deletion
- `src/routes/search.ts` — Server-side note search
- `src/routes/health.ts` — Health check
- `src/middleware/auth.ts` — JWT Bearer token verification middleware
- `src/middleware/error-handler.ts` — Global error handler
- `src/services/jwt.ts` — JWT sign/verify helpers

---

## Shared Packages

### Contracts (`packages/contracts/`)

- `src/schemas/auth.ts` — Auth request/response schemas
- `src/schemas/note.ts` — Note schemas
- `src/schemas/keyframe.ts` — Keyframe schemas
- `src/schemas/sync.ts` — Sync push/pull schemas
- `src/schemas/user.ts` — User schemas
- `src/schemas/file.ts` — File schemas
- `src/schemas/region.ts` — Region schemas
- `src/schemas/search.ts` — Search schemas
- `src/schemas/common.ts` — Shared/common schemas
- `openapi.json` — Generated OpenAPI spec

### Database (`packages/db/`)

- `src/client.ts` — Drizzle ORM client
- `src/migrate.ts` — Migration runner
- `src/schema/users.ts` — Users table
- `src/schema/notes.ts` — Notes table
- `src/schema/keyframes.ts` — Keyframes table
- `src/schema/files.ts` — Files table
- `src/schema/regions.ts` — Regions table
- `src/schema/refresh_tokens.ts` — Refresh tokens table
- `drizzle.config.ts` — Drizzle Kit config
