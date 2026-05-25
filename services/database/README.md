# PollFlow Database

Database schema and seed data for the PollFlow multi-poll voting application.

## Overview

This directory contains the PostgreSQL database schema and seed data for PollFlow. The application uses a simple, efficient schema with two main tables:

- **polls** - Poll metadata (title, options, category, timing, status)
- **votes** - Individual votes with IP-based user tracking

## Schema

### Tables

**`polls`**
- `id` - Primary key (serial)
- `title` - Poll question
- `description` - Additional context (nullable)
- `option_a`, `option_b` - Voting options
- `poll_category` - Category (politics, tech, sports, science, entertainment, etc.)
- `start_time`, `end_time` - Poll active window
- `status` - Lifecycle state: `pending`, `active`, `closed`
- `created_at` - Creation timestamp

**`votes`**
- `id` - Primary key (serial)
- `poll_id` - Foreign key to polls (CASCADE on delete)
- `user_ip` - Voter IP address (IPv4/IPv6 compatible)
- `option` - Vote choice (`a` or `b`)
- `voted_at` - Vote timestamp
- **Constraint**: UNIQUE(poll_id, user_ip) - One vote per IP per poll

### Indexes

- `idx_polls_status_time` - Optimizes poll lifecycle queries
- `idx_polls_category` - Fast category filtering
- `idx_votes_poll_id` - Efficient vote aggregation

## Usage

### Local Development (Docker Compose)

The schema and seed data are automatically applied when PostgreSQL starts:

```bash
# Start local environment
docker-compose up -d postgres

# Verify schema
docker-compose exec postgres psql -U pollflow -d pollflow -c "\dt"

# Check seed data
docker-compose exec postgres psql -U pollflow -d pollflow -c "SELECT COUNT(*) FROM polls;"
```

**How it works**: Docker Compose mounts `./services/database/` to `/docker-entrypoint-initdb.d/` in the postgres container. PostgreSQL automatically executes `.sql` files in alphabetical order on first initialization.

### Manual Application (RDS or Other PostgreSQL)

```bash
# Apply schema
psql -h your-host -U your-user -d your-database -f schema.sql

# Apply seed data (optional - for testing only)
psql -h your-host -U your-user -d your-database -f seed.sql
```

### Terraform Integration

For AWS RDS deployments using the Terraform configuration in `infra/`, you can:

1. **Apply manually after Terraform creates RDS**:
   ```bash
   terraform -chdir=infra/tf-main apply
   # Get RDS endpoint from outputs
   psql -h $(terraform -chdir=infra/tf-main output -raw rds_endpoint) -U pollflow -d pollflow -f services/database/schema.sql
   ```

2. **Use Terraform null_resource** (future enhancement):
   ```hcl
   resource "null_resource" "db_schema" {
     provisioner "local-exec" {
       command = "psql -h ${aws_db_instance.main.endpoint} -f ../../services/database/schema.sql"
     }
   }
   ```

3. **Use migration tools** (recommended for production):
   - golang-migrate
   - Flyway
   - Liquibase

## Resetting/Reseeding Data

```bash
# Local: Reset entire database
docker-compose down -v  # Removes volumes
docker-compose up -d postgres  # Recreates with fresh data

# Manual: Drop and recreate
psql -h your-host -U your-user -d your-database << EOF
DROP TABLE IF EXISTS votes CASCADE;
DROP TABLE IF EXISTS polls CASCADE;
\i schema.sql
\i seed.sql
EOF
```

## Seed Data

The `seed.sql` file contains 20 mock polls for development and testing:

- **5 pending polls** - Starting in the future (2-10 hours)
- **10 active polls** - Currently open for voting (ending 5-16 hours from now)
- **5 closed polls** - Already ended (12-72 hours ago)

Polls cover news-related categories: politics, tech, sports, science, entertainment. Approximately 150 votes are distributed across active and closed polls to simulate realistic usage.

## Future: Migrations

As the schema evolves, we'll add versioned migration files:

```
database/
├── schema.sql           # Initial schema (deprecated after migrations)
├── seed.sql
├── migrations/
│   ├── 001_initial.sql
│   ├── 002_add_poll_images.sql
│   └── 003_add_user_accounts.sql
└── README.md
```

Recommended migration tools:
- **golang-migrate** - Lightweight, works well with Go worker
- **Flyway** - Java-based, popular choice
- **node-pg-migrate** - JavaScript, integrates with SvelteKit frontend

## Notes

- Schema is designed for PostgreSQL 12+, tested with PostgreSQL 16
- All timestamps use PostgreSQL `TIMESTAMP` (no timezone) - adjust as needed
- IP addresses stored as VARCHAR(45) to support both IPv4 and IPv6
- No authentication system yet - IP-based voting is intentionally simple for MVP

