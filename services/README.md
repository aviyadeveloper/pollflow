# Voting Application Services

## Overview

Three-tier voting application demonstrating microservices architecture with Redis queue and PostgreSQL persistence.

## Services

### vote/ - Voting Frontend
**Tech**: Python 3.11 + Flask + Gunicorn  
**Port**: 80  
**Connects to**: Redis  
**Purpose**: Submit votes via web UI, pushes to Redis queue

**Environment Variables**:
- `REDIS_HOST` - Redis hostname (default: redis)
- `REDIS_PORT` - Redis port (default: 6379)
- `OPTION_A`, `OPTION_B` - Voting options (default: Cats/Dogs)

### result/ - Results Frontend
**Tech**: Node.js 18 + Express + Socket.IO  
**Port**: 80  
**Connects to**: PostgreSQL  
**Purpose**: Display real-time voting results from database

**Environment Variables**:
- `PG_HOST`, `PG_PORT`, `PG_USER`, `PG_PASSWORD`, `PG_DATABASE`

### worker/ - Background Processor
**Tech**: .NET 8.0 (C#)  
**Port**: None (background service)  
**Connects to**: Redis + PostgreSQL  
**Purpose**: Polls Redis queue every 100ms, persists votes to PostgreSQL

**Environment Variables**:
- `REDIS_HOST` - Redis hostname (default: redis)
- `DB_HOST`, `DB_USERNAME`, `DB_PASSWORD`, `DB_NAME`

## Architecture Flow

```
User → vote (Flask) → Redis → worker (.NET) → PostgreSQL → result (Node.js) → User
```

1. User submits vote via voting frontend
2. Vote pushed to Redis list ("votes")
3. Worker polls Redis and transfers to PostgreSQL
4. Results frontend displays current standings via Socket.IO

## Local Build

```bash
# Vote service
cd vote && docker build -t voting-app:latest .

# Result service
cd result && docker build -t result-app:latest .

# Worker service
cd worker && docker build -t worker:latest .
```

## Notes

- All Dockerfiles use multi-stage builds for optimization
- Services have automatic reconnection logic for resilience
- Health check support via curl (installed in containers)
- Production configs: Gunicorn (4 workers), proper logging enabled
