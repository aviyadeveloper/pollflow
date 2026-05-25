# Poll Broker

Background service that manages poll lifecycle and vote processing for PollFlow.

## Purpose

The poll-broker is a bidirectional bridge between Redis and PostgreSQL:

- **Redis → PostgreSQL**: Consumes votes from Redis queue and persists to database
- **PostgreSQL → Redis**: Broadcasts live vote results via Redis pub/sub
- **PostgreSQL**: Manages poll state transitions (pending → active → closed)

## Components

- **Poller** - Poll lifecycle manager (checks every 10s for status changes)
- **Processor** - Vote queue consumer (continuous processing)
- **Broadcaster** - Results publisher (broadcasts every 3s via pub/sub)

## Architecture

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'primaryColor':'#e5e7eb','primaryTextColor':'#111827','primaryBorderColor':'#9ca3af','lineColor':'#111827','secondaryColor':'#d1d5db','tertiaryColor':'#f3f4f6','edgeLabelBackground':'#ffffff','mainBkg':'#f5f5f4','nodeBorder':'#9ca3af','background':'#f5f5f4','clusterBkg':'transparent'},'themeCSS':'.node rect, .node circle, .node ellipse, .node polygon, .node path { filter: none !important; box-shadow: none !important; } .cluster rect { filter: none !important; box-shadow: none !important; } svg { background-color: #f5f5f4 !important; } .cluster-label { background-color: #ffffff !important; padding: 6px 12px !important; border-radius: 4px !important; font-size: 16px !important; font-weight: 700 !important; box-shadow: 0 1px 3px rgba(0,0,0,0.12) !important; border: 1px solid #d1d5db !important; } .edgePath, .edgePath path, .flowchart-link { z-index: 1 !important; }'}}%%

graph TB
    subgraph External["External Systems"]
        PG[(PostgreSQL)]
        RD[(Redis)]
    end

    subgraph PollBroker["poll-broker Service"]
        subgraph Main["main.go"]
            MainEntry[Entry Point<br/>Orchestrates all components]
        end

        subgraph Config["config package"]
            ConfigLoad[Load env vars<br/>No defaults, fail-fast]
        end

        subgraph Clients["Client Packages (Low-Level)"]
            DBClient[db.Client<br/>PostgreSQL operations<br/>- InsertVote<br/>- GetPollResults<br/>- UpdatePollStatus<br/>- GetPolls*]
            RedisClient[redis.Client<br/>Redis operations<br/>- PopVote<br/>- PublishResults<br/>- GetQueueLength]
        end

        subgraph Components["Business Logic Components"]
            Poller[poller<br/>Poll Lifecycle Manager<br/>Every 10s:<br/>- Activate pending polls<br/>- Close expired polls]
            Processor[processor<br/>Vote Consumer<br/>Continuous loop:<br/>- Pop vote from Redis<br/>- Validate vote<br/>- Insert to PostgreSQL]
            Broadcaster[broadcaster<br/>Results Publisher<br/>Every 3s:<br/>- Get active polls<br/>- Query results<br/>- Publish to Redis pub/sub]
        end
    end

    MainEntry -->|initializes| ConfigLoad
    MainEntry -->|creates| DBClient
    MainEntry -->|creates| RedisClient
    MainEntry -->|starts| Poller
    MainEntry -->|starts| Processor
    MainEntry -->|starts| Broadcaster

    Poller -->|uses| DBClient
    Processor -->|uses| DBClient
    Processor -->|uses| RedisClient
    Broadcaster -->|uses| DBClient
    Broadcaster -->|uses| RedisClient

    DBClient -->|connects to| PG
    RedisClient -->|connects to| RD

    Poller -.->|reads/updates| PG
    Processor -.->|pops from| RD
    Processor -.->|writes to| PG
    Broadcaster -.->|reads from| PG
    Broadcaster -.->|publishes to| RD

    style External fill:#e5e7eb,stroke:#4b5563,stroke-width:2px,stroke-dasharray: 5 5
    style PollBroker fill:#d1d5db,stroke:#4b5563,stroke-width:2px,stroke-dasharray: 5 5
    style Main fill:#f3f4f6,stroke:#6b7280,stroke-width:1px,stroke-dasharray: 5 5
    style Config fill:#f3f4f6,stroke:#6b7280,stroke-width:1px,stroke-dasharray: 5 5
    style Clients fill:#f3f4f6,stroke:#6b7280,stroke-width:1px,stroke-dasharray: 5 5
    style Components fill:#f3f4f6,stroke:#6b7280,stroke-width:1px,stroke-dasharray: 5 5

    style PG fill:#8B5CF6,stroke:#6d28d9,stroke-width:2px,color:#fff
    style RD fill:#EF4444,stroke:#dc2626,stroke-width:2px,color:#fff
    style MainEntry fill:#F97316,stroke:#ea580c,stroke-width:2px,color:#fff
    style ConfigLoad fill:#6B7280,stroke:#4b5563,stroke-width:2px,color:#fff
    style DBClient fill:#8B5CF6,stroke:#6d28d9,stroke-width:2px,color:#fff
    style RedisClient fill:#EF4444,stroke:#dc2626,stroke-width:2px,color:#fff
    style Poller fill:#3B82F6,stroke:#2563eb,stroke-width:2px,color:#fff
    style Processor fill:#3B82F6,stroke:#2563eb,stroke-width:2px,color:#fff
    style Broadcaster fill:#3B82F6,stroke:#2563eb,stroke-width:2px,color:#fff
```

**Key Concepts:**
- **Client packages** (db, redis) = Low-level tools for single operations
- **Business components** (poller, processor, broadcaster) = Workers that orchestrate multiple operations
- **main.go** = Entry point that initializes and coordinates all components

## Tech Stack

- Go 1.22+
- PostgreSQL driver: pgx/v5
- Redis client: go-redis/v9

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

## Running Locally

```bash
# Install dependencies
go mod download

# Run service
go run cmd/poll-broker/main.go
```

## Docker

```bash
# Build
docker build -t poll-broker:latest .

# Run
docker run --env-file .development.env poll-broker:latest
```
