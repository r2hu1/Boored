# Boored — Features & Files

## Mobile App (`apps/mobile/`)

### Google Authentication & Session Persistence (using `google_sign_in` + backend JWT)

- `apps/mobile/lib/features/auth/data/auth_repository.dart` — Google Sign-In flow, ID token exchange with backend, token & user data storage, fast-path local session restoration
- `apps/mobile/lib/features/auth/data/auth_user.dart` — User model (`id`, `email`, `name`, `avatarUrl`)
- `apps/mobile/lib/features/auth/presentation/auth_controller.dart` — Riverpod auth state management, sign-in/sign-out/session restore
- `apps/mobile/lib/features/auth/presentation/login_screen.dart` — Login UI with Google Sign-In button
- `apps/mobile/lib/core/storage/token_storage.dart` — Secure access/refresh token and cached user profile persistence (`flutter_secure_storage`)
- `apps/mobile/lib/core/network/auth_interceptor.dart` — Dio interceptor for Bearer token injection + 401 auto-refresh with retry
- `apps/mobile/lib/core/constants/api_constants.dart` — API base URL and Google OAuth client ID config (supports `.env` and `--dart-define`)
- `apps/mobile/lib/main.dart` — GoogleSignIn initialization and `.env` loading at app startup

### Camera Capture & Periodic Frame Recording (using `camera`)

- `apps/mobile/lib/features/capture/data/capture_service.dart` — Camera init, periodic frame capture at configurable intervals, crash recovery
- `apps/mobile/lib/features/capture/presentation/capture_screen.dart` — Camera preview UI, permission handling, recording controls, auto-detect board button, remove professor toggle
- `apps/mobile/lib/features/capture/presentation/capture_controller.dart` — Capture state machine (idle → previewing → recording → paused), wakelock, frame processing pipeline

### Video Import from Gallery

- `apps/mobile/lib/features/capture/data/video_import_service.dart` — Service for extracting frames from imported video files at configurable intervals
- `apps/mobile/lib/features/capture/presentation/video_import_screen.dart` — Video import UI with interval selection, frame extraction progress indicator, and batch processing
- `apps/mobile/android/app/src/main/kotlin/com/boored/boored/MainActivity.kt`
  - `extractVideoFramesNative()` — Native `MediaMetadataRetriever` frame extraction from video files

### Whiteboard Detection & Perspective Correction (using OpenCV native via MethodChannel)

- `apps/mobile/lib/features/capture/data/opencv_service.dart` — Dart MethodChannel bridge for all OpenCV operations
- `apps/mobile/lib/features/capture/presentation/widgets/board_overlay.dart` — Draggable 4-corner overlay widget for manual board region adjustment
- `apps/mobile/android/app/src/main/kotlin/com/boored/boored/MainActivity.kt`
  - `detectCornersNative()` — Multi-strategy corner detection (Canny + adaptive threshold + HSV whiteboard mask)
  - `warpPerspectiveNative()` — Perspective warp to flatten board to rectangle

### Whiteboard Image Enhancement (using OpenCV native)

- `apps/mobile/lib/features/capture/data/opencv_service.dart` — `enhanceWhiteboard()` Dart call
- `apps/mobile/android/app/src/main/kotlin/com/boored/boored/MainActivity.kt`
  - `enhanceWhiteboardNative()` — Bilateral denoising → LAB CLAHE contrast normalization → unsharp mask stroke sharpening

### Frame Change Detection & Keyframe Policy (using OpenCV native)

- `apps/mobile/lib/features/capture/data/opencv_service.dart` — `detectFrameChange()` Dart call
- `apps/mobile/lib/features/capture/data/keyframe_policy.dart` — Keyframe save policy: first frame always saved, ERASE events, ADD events with ≥4% diff
- `apps/mobile/android/app/src/main/kotlin/com/boored/boored/MainActivity.kt`
  - `detectChangeNative()` — Grayscale diff + threshold → pixel ratio → brightness shift to classify ADD vs ERASE vs NONE

### Professor/Lecturer Removal (using ML Kit Selfie Segmentation + OpenCV native)

- `apps/mobile/lib/features/capture/data/lecturer_removal_processor.dart` — Sequence-level removal: finds clean reference frames, composites over person regions
- `apps/mobile/lib/features/capture/data/mlkit_segmentation_engine.dart` — ML Kit selfie segmentation engine
- `apps/mobile/lib/features/capture/domain/segmentation_engine.dart` — Segmentation engine interface + `SegmentationMaskResult` with `hasPerson` detection
- `apps/mobile/android/app/src/main/kotlin/com/boored/boored/MainActivity.kt`
  - `compositeNative()` — Binary mask from confidences → morphological dilation → Gaussian blur → alpha blending current frame with clean background

### Text Recognition / OCR (using ML Kit Text Recognition)

- `apps/mobile/lib/features/capture/data/mlkit_recognition_engine.dart` — ML Kit Latin text recognizer, iterates blocks → lines for full text extraction
- `apps/mobile/lib/features/capture/domain/recognition_engine.dart` — Recognition engine interface

### OCR Preprocessing (using OpenCV native)

- `apps/mobile/lib/features/capture/data/opencv_service.dart` — `preprocessForOcr()` Dart call
- `apps/mobile/android/app/src/main/kotlin/com/boored/boored/MainActivity.kt`
  - `preprocessForOcrNative()` — Grayscale → CLAHE → adaptive threshold → median blur for binarized OCR input

### Session Finalization & PDF Generation (using `pdf` package)

- `apps/mobile/lib/features/capture/data/session_finalizer.dart`
  - `finalizeNote()` — Generates `document.pdf` from keyframes without generating digital PDF; marks note status as ready
  - `generateDigitalPdf()` — Clean typeset text-only PDF from extracted OCR text without embedded whiteboard images
  - `removeProfessorAndGeneratePdf()` — Dedicated processor running segmentation and compositing, saving cleaned keyframes, and outputting `clean.pdf`

### Note Detail Viewer (Timeline, Pages Grid, PDF, Digital Copy, Clean Copy)

- `apps/mobile/lib/features/notes/presentation/note_detail_screen.dart` — Dynamic tabbed viewer:
  - **Timeline Tab**: Interactive viewer with transport controls (play, pause, step forward/backward, slider) and deduplication
  - **Pages Tab**: 2-column masonry grid of all captured pages with copy-text shortcuts
  - **PDF Tab**: Embedded Document PDF viewer (`pdfx`) for `document.pdf`
  - **Digital Tab**: Embedded viewer for `digital.pdf` (dynamically shown if digital copy exists)
  - **Clean Tab**: Embedded viewer for `clean.pdf` (dynamically shown if professor removal was performed)
  - **Actions & Menu**: Process / Generate PDF toolbar action, video capture resume, popup menu (Generate Digital Copy, Remove professor, Rename, Open externally, Save to Downloads, Delete)

### Folders Organization & Management

- `apps/mobile/lib/core/database/daos/folders_dao.dart` — Folders DAO: CRUD operations, reactive folder note counts, folder watch streams
- `apps/mobile/lib/features/folders/data/folders_repository.dart` — Folders repository layer over Drift DAO
- `apps/mobile/lib/features/folders/presentation/folders_controller.dart` — Riverpod state management for folders list and note counts
- `apps/mobile/lib/features/folders/presentation/folder_detail_screen.dart` — Folder detail view listing notes within that folder, search, folder rename/delete
- `apps/mobile/lib/features/folders/presentation/widgets/folder_card.dart` — 3D folder card UI with back flap tab (`_FolderBackPainter`), peeking paper sheet, gradient pocket, note count, and popup menu
- `apps/mobile/lib/features/folders/presentation/widgets/folder_sheet.dart` — Create folder and rename folder modal bottom sheets

### Notes CRUD & Search (using Drift/SQLite)

- `apps/mobile/lib/features/notes/data/notes_repository.dart` — Repository layer over DAO (watch, search, create, update, delete, restore)
- `apps/mobile/lib/features/notes/presentation/notes_controller.dart` — Riverpod state: reactive note list, client-side title search, create/delete/restore/rename
- `apps/mobile/lib/features/notes/presentation/widgets/note_card.dart` — Note list item with pill layout, circular sparkle icon, preview subtitle, and swipe-to-delete
- `apps/mobile/lib/features/notes/presentation/widgets/create_note_dialog.dart` — Rename and delete note bottom sheets

### Home Screen

- `apps/mobile/lib/features/home/presentation/home_screen.dart` — App home interface:
  - Dynamic time-based greeting ("Good morning,", "Good afternoon,", "Good evening,") with user name
  - Official Material 3 `SearchBar` for filtering notes
  - Horizontal folders section with `FolderCard` items
  - `_CreateFolderCard` displayed when folder list is empty, matching the folder card visual structure
  - All Notes list with note cards
  - Expandable speed-dial Floating Action Button (`Record Live`, `Upload Video`, `New Folder`)
  - Cloud sync indicator badge and user profile avatar menu

### Local Database (using Drift + SQLite)

- `apps/mobile/lib/core/database/app_database.dart` — Schema: `Notes`, `Keyframes`, and `Folders` tables with sync status tracking
- `apps/mobile/lib/core/database/database_provider.dart` — Riverpod database singleton provider
- `apps/mobile/lib/core/database/daos/notes_dao.dart` — Notes DAO: CRUD, soft delete, restore, versioning, watch streams
- `apps/mobile/lib/core/database/daos/keyframes_dao.dart` — Keyframes DAO: insert (deduplicated), update image/text, watch by note
- `apps/mobile/lib/core/database/daos/folders_dao.dart` — Folders DAO: CRUD, note count, watch streams

### Cloud Sync (using Dio + backend REST API)

- `apps/mobile/lib/features/sync/sync_controller.dart` — Push pending notes/keyframes → pull remote changes → version-based conflict resolution
- `apps/mobile/lib/core/network/api_client.dart` — Dio HTTP client with base URL, timeouts, auth interceptor

### Settings & Account Deletion

- `apps/mobile/lib/features/settings/settings_screen.dart` — User profile display, manual sync trigger, permanent account + data deletion

### Navigation (using `go_router`)

- `apps/mobile/lib/app/router.dart` — Auth-gated routing with guard during initial session check:
  - `/` — Home Screen
  - `/login` — Login Screen
  - `/notes/:id` — Note Detail Screen
  - `/capture/:id` — Live Camera Capture Screen
  - `/import/:id` — Video Import Screen
  - `/folders/:id` — Folder Detail Screen
  - `/settings` — Settings Screen

### Utilities

- `apps/mobile/lib/core/utils/relative_time.dart` — Human-readable relative timestamps ("3 mins ago", "yesterday")

### External PDF Viewer (using Android Intent via MethodChannel)

- `apps/mobile/android/app/src/main/kotlin/com/boored/boored/MainActivity.kt`
  - `handleOpenPdf()` — FileProvider URI + ACTION_VIEW intent chooser

---

## Backend API (`apps/api/`)

- `apps/api/src/index.ts` — Server entrypoint
- `apps/api/src/app.ts` — Express/Hono app setup
- `apps/api/src/env.ts` — Environment config
- `apps/api/src/db.ts` — Database connection
- `apps/api/src/routes/auth.ts` — Google ID token verification, JWT issue, refresh, logout
- `apps/api/src/routes/sync.ts` — Push/pull sync endpoints
- `apps/api/src/routes/me.ts` — Current user profile, account deletion
- `apps/api/src/routes/search.ts` — Server-side note search
- `apps/api/src/routes/health.ts` — Health check
- `apps/api/src/middleware/auth.ts` — JWT Bearer token verification middleware
- `apps/api/src/middleware/error-handler.ts` — Global error handler
- `apps/api/src/services/jwt.ts` — JWT sign/verify helpers

---

## Shared Packages

### Contracts (`packages/contracts/`)

- `packages/contracts/src/schemas/auth.ts` — Auth request/response schemas
- `packages/contracts/src/schemas/note.ts` — Note schemas
- `packages/contracts/src/schemas/keyframe.ts` — Keyframe schemas
- `packages/contracts/src/schemas/sync.ts` — Sync push/pull schemas
- `packages/contracts/src/schemas/user.ts` — User schemas
- `packages/contracts/src/schemas/file.ts` — File schemas
- `packages/contracts/src/schemas/region.ts` — Region schemas
- `packages/contracts/src/schemas/search.ts` — Search schemas
- `packages/contracts/src/schemas/common.ts` — Shared/common schemas
- `packages/contracts/openapi.json` — Generated OpenAPI spec

### Database (`packages/db/`)

- `packages/db/src/client.ts` — Drizzle ORM client
- `packages/db/src/migrate.ts` — Migration runner
- `packages/db/src/schema/users.ts` — Users table
- `packages/db/src/schema/notes.ts` — Notes table
- `packages/db/src/schema/keyframes.ts` — Keyframes table
- `packages/db/src/schema/files.ts` — Files table
- `packages/db/src/schema/regions.ts` — Regions table
- `packages/db/src/schema/refresh_tokens.ts` — Refresh tokens table
- `packages/db/drizzle.config.ts` — Drizzle Kit config
