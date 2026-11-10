# Local Development Setup

## Prerequisites

- Node.js >= 20
- pnpm >= 10
- Flutter >= 3.40 (stable channel)
- Docker and Docker Compose
- Android Studio with Android SDK (API 35)

## Quick Start

```bash
# 1. Clone and install
git clone <repo-url>
cd Boored
cp .env.example .env
pnpm install

# 2. Start infrastructure
pnpm infra:up
# Wait for Postgres and MinIO to be healthy

# 3. Run database migrations
pnpm db:migrate

# 4. Start the API
pnpm dev
# API runs at http://localhost:3000
# Docs at http://localhost:3000/v1/docs

# 5. Run Flutter app (in a separate terminal)
cd apps/mobile
flutter pub get
flutter run
```

## Infrastructure

- **PostgreSQL**: `localhost:5432` (user: `boored`, pass: `boored_dev`, db: `boored`)
- **MinIO Console**: http://localhost:9001 (user: `minioadmin`, pass: `minioadmin`)
- **MinIO S3 API**: http://localhost:9000

## Common Commands

| Command | Description |
|---------|-------------|
| `pnpm dev` | Start API in dev mode with hot reload |
| `pnpm test` | Run API tests |
| `pnpm typecheck` | TypeScript type checking |
| `pnpm db:generate` | Generate Drizzle migrations |
| `pnpm db:migrate` | Apply migrations |
| `pnpm db:studio` | Open Drizzle Studio |
| `pnpm infra:up` | Start Docker services |
| `pnpm infra:down` | Stop Docker services |
| `pnpm spec:export` | Export OpenAPI spec JSON |
