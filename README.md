# Boored

Classroom whiteboard digitization app. Capture a whiteboard during a lecture, get cleaned keyframe images, extracted text, a timeline player, and a PDF.

## Architecture

- **Mobile**: Flutter (Android) with Riverpod, Drift, OpenCV via platform channels
- **API**: Hono + TypeScript on Node.js
- **Database**: PostgreSQL with Drizzle ORM
- **Storage**: S3-compatible (MinIO local, S3/R2 production)

## Quick Start

```bash
cp .env.example .env
pnpm install
pnpm infra:up
pnpm db:migrate
pnpm dev
```

See [docs/setup-guide.md](docs/setup-guide.md) for full setup instructions.

## Project Structure

```
apps/mobile/       Flutter app (Android)
apps/api/          Hono API (TypeScript)
packages/db/       Drizzle schema and migrations
packages/contracts/ Zod schemas and OpenAPI definitions
infra/             Docker Compose (Postgres, MinIO)
docs/              Architecture decisions, setup guide
```

## Documentation

- [Architecture Summary](ARCHITECTURE.md)
- [Setup Guide](docs/setup-guide.md)
- [ADR-001: Architecture Choices](docs/ADR-001-architecture.md)
- [Progress Tracker](PROGRESS.md)
