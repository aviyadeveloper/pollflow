# Server-Side Code

This directory contains server-only code that runs exclusively on the backend.

## Files

- `db.ts` - PostgreSQL connection pool and query utilities
- `redis.ts` - Redis client for pub/sub and queue operations

## Important

Code in `lib/server/` is automatically excluded from client bundles by SvelteKit.
Never import server-side code (DB connections, secrets) into client components.
