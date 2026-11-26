<div align="center">
  <img src="apps/mobile/assets/logo.png" width="96" alt="Boored Logo" />
  <h1>Boored</h1>
  <p><strong>Capture whiteboards and turn them into clean, easy-to-read digital notes. (21st Aavishkar Runner Up)</strong></p>
  <p>Automated perspective rectification, pre-erase keyframing, lecturer de-occlusion, OCR extraction, and vector PDF compilation.</p>
</div>

---

## Overview

Documenting university and technical whiteboard lectures with standard phone cameras suffers from four core physical problems:

1. **Erasure Loss**: Instructors erase board sections to make space. Content wiped before someone takes a photo is gone permanently.
2. **Lecturer Occlusion**: Lecturers stand in front of diagrams and formulas, blocking 30% to 50% of the active board.
3. **Desk Perspective & Glare**: Photos taken from classroom desk angles suffer from trapezoidal distortion, lighting glare, and low ink contrast.
4. **Unorganized Photo Reels**: Standard photo galleries leave students with dozens of disconnected, out-of-order images without searchable text.

**Boored** automates the entire process on-device. It rectifies board perspective angles, triggers snapshot saves right before content is erased, removes the lecturer by sampling unobstructed background pixels across frames, extracts text with OCR, and exports both high-resolution visual PDFs and lightweight digital text documents.

---

## Features

- **Interactive 4-Corner Board Rectification**: Live camera overlay with 4 draggable normalized corner pins that snap to whiteboard boundaries. Uses native OpenCV `warpPerspective` homography to flatten angled desk shots into planar views.
- **Pre-Erase Keyframe Trigger**: Real-time OpenCV inter-frame change detection (`detectFrameChange`). When an erase event is detected (sudden luminance jump as dark ink is wiped to white), Boored automatically commits the keyframe right before the erase.
- **Multi-Frame Temporal Lecturer Removal**: On-device neural segmentation (`google_mlkit_selfie_segmentation`) combined with multi-frame temporal reconstruction. Restores actual board handwriting written behind the lecturer by sampling unobstructed board coordinates across the timeline sequence.
- **Granular Processing Options**: On-demand generation options to rebuild Document PDF, generate Clean Copy (de-occluded), extract Digital Notes (OCR), or run the complete pipeline.
- **Page Management & Selective Deletion**: Dedicated Edit Pages screen allowing users to select, delete specific keyframes/pages, or batch remove pages with automatic re-indexing and synchronized PDF regeneration.
- **OpenCV Adaptive Binarization & OCR**: Preprocesses frames with grayscale CLAHE and Gaussian adaptive thresholding to convert marker strokes to solid black text on clean white backgrounds before running ML Kit Latin text recognition.
- **Interactive Timeline Player**: Replay how the board developed over the course of the lecture with scrub controls, variable replay speeds (0.5×, 1.0×, 2.0×), and state markers (`INITIAL`, `ADD`, `ERASE`).
- **Pages View with 1-Tap Copy**: Browse individual de-occluded keyframes and copy formulas, code snippets, or notes directly to the mobile clipboard.
- **Dual PDF Export**: Generates both an A4 landscape visual PDF containing all high-resolution keyframes and a lightweight searchable text document (`digital.pdf`) under 200 KB.
- **Offline-First Storage**: Operates without an internet connection in class. All keyframes, timestamps, and extracted text are stored locally in Drift SQLite.

---

## Visual Workflow

|                                 Home & Folders                                  |                                                Action Options                                                 |                             Live Camera & Rectification                             |
| :-----------------------------------------------------------------------------: | :-----------------------------------------------------------------------------------------------------------: | :---------------------------------------------------------------------------------: |
| <img src="assets/screenshots/home-screen.jpeg" width="240" alt="Home Screen" /> | <img src="assets/screenshots/record-upload-or-create-folder-options.jpeg" width="240" alt="Action Options" /> | <img src="assets/screenshots/camera-screen.jpeg" width="240" alt="Camera Screen" /> |
|               Organize lectures in folders with quick notes feed                |                                  Record live, upload video, or create folder                                  |                 Real-time corner detection & perspective homography                 |

|                            Scrubbable Timeline Player                            |                                 Granular Generation Options                                 |
| :------------------------------------------------------------------------------: | :-----------------------------------------------------------------------------------------: |
| <img src="assets/screenshots/timeline.jpeg" width="240" alt="Timeline Player" /> | <img src="assets/screenshots/generate-options.jpeg" width="240" alt="Regenerate Options" /> |
|              Event playback (INITIAL, ADD, ERASE) & scrub controls               |                    Select Document PDF, Clean Copy, Digital Copy, or All                    |

|                                Document PDF View                                |                                Clean Copy (Professor Removed)                                |
| :-----------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------: |
| <img src="assets/screenshots/pdf-screen.jpeg" width="240" alt="Document PDF" /> | <img src="assets/screenshots/removed-professor-pdf.jpeg" width="240" alt="Clean Copy PDF" /> |
|                  Full-resolution landscape A4 vector document                   |                  Temporal multi-frame recovery restoring actual board notes                  |

---

## Architecture & Tech Stack

```
Boored
├── apps/mobile/          # Android client (Flutter 3.x, Riverpod, Drift SQLite)
│   └── android/          # Native OpenCV 4.5.3 C++/Kotlin bridge & ML Kit
├── apps/api/             # Backend service (Hono + TypeScript on Node.js)
├── packages/db/          # PostgreSQL schema and migrations (Drizzle ORM)
├── packages/contracts/   # Zod validation contracts and OpenAPI definitions
├── infra/                # Docker Compose (PostgreSQL 16, MinIO S3 storage)
└── docs/                 # Architecture decisions & setup guides
```

### Mobile Subsystem (On-Device)

- **Framework**: Flutter 3.x with Riverpod (State Notifier pattern).
- **Target**: Android (minSdk 24, targetSdk 36).
- **Computer Vision**: OpenCV 4.5.3 (`warpPerspective`, CLAHE, unsharp mask, frame differencing) accessed via Android Kotlin `MethodChannel`.
- **Machine Learning**: Google ML Kit (Selfie Segmentation for lecturer removal + Text Recognition for OCR).
- **Persistence**: Drift SQLite database for notes, keyframes, event markers, and extracted text.
- **Document Engine**: Vector PDF generation (`pdf` and `pdfx` packages).

### Backend Subsystem (Cloud Sync)

- **API Runtime**: Hono + TypeScript on Node.js.
- **Authentication**: Google OAuth 2.0 ID token verification (`jose`), issuing JWT access tokens and rotating refresh tokens.
- **Database**: PostgreSQL 16 with Drizzle ORM and full-text search.
- **Object Storage**: S3-compatible storage (MinIO for local development, AWS S3 / Cloudflare R2 for production).

---

## Getting Started

### Prerequisites

- Node.js 20+ and `pnpm`
- Docker and Docker Compose
- Flutter 3.24+ SDK and Android Studio (SDK Platform 35/36)

### 1. Start Local Backend & Infrastructure

```bash
# Clone the repository
git clone https://github.com/r2hu1/Boored.git
cd Boored

# Install workspace dependencies
pnpm install

# Start local PostgreSQL and MinIO S3 containers
pnpm infra:up

# Run database migrations
pnpm db:migrate

# Start the Hono development server
pnpm dev
```

The API runs at `http://localhost:3000` with OpenAPI documentation available at `http://localhost:3000/v1/openapi.json`.

### 2. Run the Android Mobile App

```bash
cd apps/mobile

# Install Flutter dependencies
flutter pub get

# Generate Drift SQLite database code
dart run build_runner build --delete-conflicting-outputs

# Launch the app on an Android emulator or connected device
flutter run
```

---

## Documentation

- [Product & Technical Overview PDF](Boored_Overview.pdf): Complete 5-page illustrated document covering use cases, physical problems, computer vision algorithms, and architecture.
- [Architecture Summary](ARCHITECTURE.md): System layout and technical decisions.
- [Setup Guide](docs/setup-guide.md): Local development environment walkthrough.
- [Google Auth Setup](docs/google-auth-setup.md): OAuth 2.0 configuration, SHA-1 keystore fingerprints, and Google Cloud Console setup.

---

## License

MIT
