# Voting Application Services

The following Readme is divided into two main secions: An old version which describes the app as it was built in the previous project, and a a new version which describes what the app should do after an overhaul.

The main transition is from a single static poll, to a mutiple poll system, where users are presented with around 16-24 polls daily. Each poll will have a start and end time, and users can only vote during the active period.

Live poll results are displayed when users vote. Past polls are "archived in the database" and users can view them in a separate section.

The worker service will be responsible for closing polls when their end time is reached, and moving them to the archive section.

There is no longer any need for two seperate frontends - the voting and results frontends will be merged into a single application that handles both voting and displaying results. This will simplify the architecture and improve the user experience.

## Old Version

### Overview

Three-tier voting application demonstrating microservices architecture with Redis queue and PostgreSQL persistence.

### Services

#### vote/ - Voting Frontend
**Tech**: Python 3.11 + Flask + Gunicorn  
**Port**: 80  
**Connects to**: Redis  
**Purpose**: Submit votes via web UI, pushes to Redis queue

**Environment Variables**:
- `REDIS_HOST` - Redis hostname (default: redis)
- `REDIS_PORT` - Redis port (default: 6379)
- `OPTION_A`, `OPTION_B` - Voting options (default: Cats/Dogs)

#### result/ - Results Frontend
**Tech**: Node.js 18 + Express + Socket.IO  
**Port**: 80  
**Connects to**: PostgreSQL  
**Purpose**: Display real-time voting results from database

**Environment Variables**:
- `PG_HOST`, `PG_PORT`, `PG_USER`, `PG_PASSWORD`, `PG_DATABASE`

#### worker/ - Background Processor
**Tech**: .NET 8.0 (C#)  
**Port**: None (background service)  
**Connects to**: Redis + PostgreSQL  
**Purpose**: Polls Redis queue every 100ms, persists votes to PostgreSQL

**Environment Variables**:
- `REDIS_HOST` - Redis hostname (default: redis)
- `DB_HOST`, `DB_USERNAME`, `DB_PASSWORD`, `DB_NAME`

### Architecture Flow

```
User → vote (Flask) → Redis → worker (.NET) → PostgreSQL → result (Node.js) → User
```

1. User submits vote via voting frontend
2. Vote pushed to Redis list ("votes")
3. Worker polls Redis and transfers to PostgreSQL
4. Results frontend displays current standings via Socket.IO

### Local Build

```bash
# Vote service
cd vote && docker build -t voting-app:latest .

# Result service
cd result && docker build -t result-app:latest .

# Worker service
cd worker && docker build -t worker:latest .
```

### Notes

- All Dockerfiles use multi-stage builds for optimization
- Services have automatic reconnection logic for resilience
- Health check support via curl (installed in containers)
- Production configs: Gunicorn (4 workers), proper logging enabled


## New Version

### Overview

Multi-poll voting system where users are presented with 16-24 daily polls. Each poll has time constraints (start/end times), and users can only vote during active periods. Live results are displayed via real-time updates. Past polls are archived and viewable separately.

### Architecture

**Stack**:
- **Frontend**: SvelteKit (TypeScript) - Full-stack framework with built-in SSR and API routes
- **Worker**: Go - Background processing, poll lifecycle management
- **Cache/Queue**: Redis - Vote queue and pub/sub for real-time updates
- **Database**: PostgreSQL - Persistent storage
- **User Identity**: IP-based (one vote per poll per IP)

**Data Flow**:
```
User → SvelteKit (Frontend + API) → Redis Queue → Go Worker → PostgreSQL
                                      ↓
                                   Pub/Sub ← Go Worker (Broadcaster)
                                      ↓
                              SvelteKit SSE → User (Live Results)
```

### Services Structure

```
services/
├── database/              # Database schema & migrations
│   ├── schema.sql        # Core tables (polls, votes, results_cache)
│   ├── seed.sql          # Mock poll data for development
│   └── README.md
├── frontend/             # SvelteKit application (TypeScript)
│   ├── src/
│   │   ├── lib/
│   │   │   ├── server/        # Backend code (DB, Redis clients)
│   │   │   ├── components/    # Svelte UI components
│   │   │   └── stores/        # Client state management
│   │   └── routes/
│   │       ├── +page.svelte           # Active polls list
│   │       ├── poll/[id]/+page.svelte # Vote & live results
│   │       ├── archive/+page.svelte   # Past polls
│   │       └── api/                   # Backend API endpoints
│   ├── Dockerfile
│   └── package.json
├── worker/               # Go background service
│   ├── cmd/worker/main.go
│   ├── internal/
│   │   ├── poller/      # Poll lifecycle (activate/close)
│   │   ├── processor/   # Vote queue processing
│   │   └── broadcaster/ # Results pub/sub (3s intervals)
│   ├── go.mod
│   └── Dockerfile
└── README.md
```

### Implementation Roadmap

#### Phase 1: Database Schema ✅

**File**: `services/database/schema.sql`

**Tables**:
- `polls` - Poll metadata (title, options, start/end times, status)
- `votes` - Individual votes with IP constraint (one vote per poll per IP)
- `poll_results_cache` - Aggregated vote counts for performance

**Indexes**: Optimized for status+time queries and vote lookups

**Seed Data**: `services/database/seed.sql` with 20 mock polls

#### Phase 2: Go Worker Service ✅

**Core Components**:

1. **Poll Lifecycle Manager** - Every 10 seconds:
   - Activates polls when `start_time` reached
   - Closes polls when `end_time` reached
   - Updates poll status (pending → active → closed)

2. **Vote Processor** - Continuous:
   - Pops votes from Redis queue (`votes:queue`)
   - Validates and writes to PostgreSQL
   - Handles duplicate votes (IP constraint)
   - Updates results cache

3. **Results Broadcaster** - Every 3 seconds:
   - Publishes current results to Redis pub/sub
   - Channel: `poll:results:{poll_id}`
   - Only for active polls

**Dependencies** (~5 total):
- `github.com/jackc/pgx/v5` - PostgreSQL driver
- `github.com/redis/go-redis/v9` - Redis client
- Standard library for everything else

**Image Size**: ~20MB (multi-stage Alpine build)

#### Phase 3: SvelteKit Frontend

**Pages**:
- `/` - Grid of active polls with countdown timers
- `/poll/[id]` - Vote submission + live results (SSE updates)
- `/archive` - Paginated list of closed polls with final results

**Backend API Routes** (same codebase):
- `GET /api/polls/active` - Active polls list
- `GET /api/polls/[id]` - Poll details + user vote status (by IP)
- `POST /api/vote` - Push vote to Redis queue
- `GET /api/results/[id]/stream` - SSE endpoint for live updates
- `GET /api/polls/archive` - Closed polls

**Real-time Strategy**:
- Server-Sent Events (SSE) for result updates
- Backend subscribes to Redis pub/sub
- Forwards updates to browser clients every 3 seconds

**Dependencies** (~12 total):
- `@sveltejs/kit`, `@sveltejs/adapter-node`
- `pg` - PostgreSQL client
- `ioredis` - Redis client
- `svelte`, `vite`, `typescript`

**Bundle Size**: ~25-30KB JavaScript
**Image Size**: ~80MB (Node 20 Alpine)

#### Phase 4: Docker & Local Development

**`docker-compose.yml`** (root directory):
```yaml
services:
  postgres:
    image: postgres:16-alpine
    volumes:
      - ./services/database:/docker-entrypoint-initdb.d  # Auto-run schema/seed
  
  redis:
    image: redis:7-alpine
  
  worker:
    build: ./services/worker
    depends_on: [postgres, redis]
  
  frontend:
    build: ./services/frontend
    ports: ["3000:3000"]
    depends_on: [postgres, redis]
```

**Development Commands**:
```bash
make dev-up        # Start all services
make dev-logs      # View logs
make dev-rebuild   # Rebuild and restart
```

#### Phase 5: Kubernetes Updates

Update existing `k8s/` manifests:
- Replace `vote/` and `result/` with unified `frontend/`
- Replace existing `worker/` with new Go version
- Keep Redis StatefulSet (existing)
- Update ingress to route only to frontend service

### Key Features

**Vote Flow**:
1. User clicks vote → Frontend API extracts IP
2. Vote pushed to Redis queue → Returns 202 immediately
3. Worker pops from queue → Writes to PostgreSQL
4. Worker broadcasts results every 3 seconds
5. Frontend SSE receives update → UI re-renders

**Poll Lifecycle**:
- Polls seeded with start/end times
- Worker automatically activates/closes based on timestamps
- Future: AI-powered poll generation using news APIs

**Results Display**:
- Live updates during active polls (3-second intervals)
- Animated percentage bars
- Final results for archived polls
- IP-based vote tracking (no user accounts needed)

### DevOps Showcase Points

This architecture demonstrates:
- ✅ Microservices (2 independent services)
- ✅ Message Queue (Redis for async vote processing)
- ✅ Database (PostgreSQL with proper indexing)
- ✅ Caching (Redis + results cache table)
- ✅ Real-time (SSE + pub/sub pattern)
- ✅ Containerization (Multi-stage Dockerfiles)
- ✅ Orchestration (Kubernetes/EKS ready)
- ✅ Scalability (Stateless services, horizontal scaling)


### Local Development

```bash
# Start local environment
docker-compose up -d

# Access application
open http://localhost:3000

# View logs
docker-compose logs -f worker
docker-compose logs -f frontend

# Rebuild after changes
docker-compose up -d --build
```

### Deployment Notes

**Local**: Self-contained with Docker Compose (includes PostgreSQL)  
**AWS**: Uses existing EKS + RDS infrastructure (schema applied separately)  
**Migrations**: Future enhancement using golang-migrate or similar

---

## Backlog

Future enhancements and optimizations to consider after MVP is complete:

### Performance & Optimization

- **Results Caching Layer**
  - Implement materialized view or cache table for vote aggregation
  - Reduces real-time query load on votes table
  - Update via trigger or worker process
  - Consider PostgreSQL materialized views with `REFRESH MATERIALIZED VIEW CONCURRENTLY`

- **Redis Optimization**
  - Connection pooling for high-traffic scenarios
  - Redis Cluster for horizontal scaling
  - Separate Redis instances for queue vs. pub/sub

### Features

- **User Authentication System**
  - Replace IP-based voting with proper user accounts
  - OAuth integration (Google, GitHub)
  - User profile with voting history
  - Follow favorite poll categories

- **Multi-Choice Polls**
  - Support for 3+ options per poll
  - Ranked choice voting
  - Multiple selection polls

- **Poll Media Support**
  - Image attachments for poll context
  - Video embeds
  - GIF support for options

- **Poll Reactions & Comments**
  - Emoji reactions to polls
  - Comment threads on polls
  - Comment voting/sorting

- **AI-Powered Poll Generation**
  - Integration with news APIs (NewsAPI, Google News)
  - OpenAI/Anthropic for poll generation from articles
  - Daily automated poll seeding worker
  - Category classification

- **Analytics Dashboard**
  - Admin interface for poll creation
  - Real-time analytics (votes over time, demographic insights)
  - Popular categories tracking
  - User engagement metrics

- **Advanced Filtering**
  - Filter polls by category on homepage
  - Search polls by keyword
  - Sort by popularity, recency, ending soon

- **Notifications**
  - Email notifications when followed polls close
  - Browser push notifications for new polls
  - Daily digest emails

### Infrastructure & DevOps

- **Database Migrations**
  - Implement versioned migrations with golang-migrate
  - CI/CD integration for automatic schema updates
  - Rollback strategy

- **Observability**
  - Prometheus metrics export
  - Grafana dashboards
  - Structured logging with ELK stack
  - Distributed tracing (Jaeger/Tempo)

- **CI/CD Pipeline**
  - GitHub Actions for automated testing
  - Automated Docker builds on push
  - Automated deployment to staging/production
  - Database migration automation

- **Testing**
  - Unit tests for Go worker
  - Integration tests for API endpoints
  - E2E tests with Playwright
  - Load testing with k6

- **Security Enhancements**
  - Rate limiting per IP
  - CAPTCHA for vote submission
  - Input sanitization and validation
  - SQL injection prevention audits
  - CORS policy refinement

- **Scaling Strategy**
  - Horizontal pod autoscaling (HPA) for frontend
  - Worker replicas with leader election
  - Read replicas for PostgreSQL
  - CDN integration for static assets

### Technical Debt

- **Error Handling**
  - Comprehensive error messages
  - Retry logic with exponential backoff
  - Dead letter queue for failed votes

- **Configuration Management**
  - Centralized config with environment-specific overrides
  - Secrets management (AWS Secrets Manager, Vault)
  - Feature flags system

- **Code Quality**
  - Linting and formatting enforcement
  - Code coverage targets (80%+)
  - Documentation generation
  - API documentation (OpenAPI/Swagger)