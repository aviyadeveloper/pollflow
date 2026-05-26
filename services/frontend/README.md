# PollFlow Frontend

SvelteKit full-stack application for multi-poll voting system.

## Tech Stack

- **SvelteKit 2.5** - Full-stack framework with SSR and API routes
- **TypeScript 5.5** - Type safety
- **PostgreSQL** - Database client (pg 8.12)
- **Redis** - Queue and pub/sub client (ioredis 5.4)

## Environment Variables

```bash
DB_HOST=localhost
DB_PORT=5432
DB_NAME=pollflow_development
DB_USER=pollflow_developer
DB_PASSWORD=developer_password

REDIS_HOST=localhost
REDIS_PORT=6379
```

## Development

### Local Development (recommended)

Use Docker Compose from the project root for a complete development environment:

```bash
# From project root
make docker-up              # Start all services
make docker-logs-frontend   # View frontend logs
make docker-restart-frontend # Restart after code changes

# Access application
open http://localhost:3000
```

### Standalone Development

Run the frontend service independently (requires PostgreSQL and Redis):

```bash
# Install dependencies
pnpm install

# Copy environment variables
cp .env.example .env
# Edit .env with your database/Redis credentials

# Run dev server
pnpm dev

# Build for production
pnpm build

# Preview production build
pnpm preview
```

### Docker Build

Build and run the frontend Docker image:

```bash
# Build image
docker build -t pollflow-frontend .

# Run container
docker run -p 3000:3000 \
  -e POSTGRES_HOST=host.docker.internal \
  -e POSTGRES_PORT=5432 \
  -e POSTGRES_DB=pollflow_development \
  -e POSTGRES_USER=pollflow_developer \
  -e POSTGRES_PASSWORD=developer_password \
  -e REDIS_HOST=host.docker.internal \
  -e REDIS_PORT=6379 \
  -e REDIS_PASSWORD= \
  pollflow-frontend
```

## Project Structure

```
src/
├── lib/
│   ├── server/          # Backend code (DB, Redis clients)
│   └── components/      # Svelte UI components
└── routes/
    ├── +page.svelte             # Active polls homepage
    ├── poll/[id]/+page.svelte   # Vote & results page
    └── api/                     # Backend API endpoints
```

## Package Security

All packages are:
- Maintained by official organizations
- Pinned to exact versions (enforced by `pnpm-workspace.yaml`)
- 7-day release buffer enforced via `minimumReleaseAge: 10080` (minutes)
- `minimumReleaseAgeStrict: true` - Installation fails if no version meets age requirement
- `blockExoticSubdeps: true` - Only direct dependencies can use git/tarball sources
- `autoInstallPeers: false` - Manual peer dependency control
- `strictDepBuilds: true` - Fail on unreviewed build scripts
- pnpm's content-addressable store prevents package tampering

See `/pnpm-workspace.yaml` for full security configuration.
