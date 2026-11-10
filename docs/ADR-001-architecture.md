# ADR-001: Architecture and Technology Choices

**Status**: Accepted
**Date**: 2026-11-10

## Context

Boored is a classroom whiteboard digitization app. Users capture a whiteboard during a lecture, and the app produces cleaned keyframe images, extracted text, a timeline player, and a PDF. The app must work offline-first with background sync.

We need to choose:
- Backend framework and runtime
- Database and ORM
- Mobile framework and state management
- Image processing approach
- Local database for offline support
- API client generation strategy

## Decisions

### Backend: Hono on Node.js with TypeScript

Hono is lightweight, fast, and has first-class OpenAPI support via `@hono/zod-openapi`. Node.js is the most mature runtime for Hono.

### Database: PostgreSQL with Drizzle ORM

PostgreSQL for full-text search (`tsvector`), JSONB support, and maturity. Drizzle for type-safe queries with minimal abstraction overhead.

### Mobile: Flutter (Android first) with Riverpod

Flutter for cross-platform potential. Riverpod over Bloc for less boilerplate, compile-time safety on provider dependencies, and better support for accessing state outside the widget tree (background services, repositories).

### Local DB: Drift (SQLite)

Type-safe queries, reactive streams, compile-time verification, in-memory databases for testing. Superior to raw sqflite for our schema complexity.

### Image Processing: Platform Channels + OpenCV Android SDK

Native Kotlin calling OpenCV Android SDK 4.x via platform channels. More proven than `opencv_dart` (community package, younger). Native threading via Kotlin coroutines keeps heavy work off the Dart VM entirely.

### Text Recognition: ML Kit on-device

Behind a `RecognitionEngine` interface for future engine swaps. On-device processing respects privacy.

### Lecturer Removal: Post-processing only

ML Kit Selfie Segmentation applied during the final pass, not during live capture. Saves battery and produces higher quality results through multi-frame compositing.

### API Client Generation: swagger_parser

Pure Dart tool generating Retrofit + Freezed clients from OpenAPI 3.1 spec. Replaces the Java-based openapi-generator which has known Dart codegen bugs in 2026.

### Auth: jose for JWT

Lighter than google-auth-library. Handles both Google token verification (JWKS) and our own JWT issuance.

### minSdk: 24 (Android 7.0)

Covers 93–94% of active devices. Required by modern package toolchains (`share_plus` 13.x, etc.).

### Object Storage: MinIO (dev) / S3 or R2 (prod)

Files never pass through the API. Presigned URLs for upload/download. MinIO is AGPL but used only as dev infrastructure.

## Consequences

- Platform channels require maintaining a Kotlin bridge layer for OpenCV operations.
- `swagger_parser` may occasionally need manual fixes for edge-case OpenAPI constructs.
- Riverpod code-gen adds a `build_runner` step to the Flutter dev workflow.
- Post-processing-only lecturer removal means the live capture shows raw (unrectified) frames — the user sees the final cleaned result only after processing.
