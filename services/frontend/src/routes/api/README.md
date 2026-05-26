# API Routes

SvelteKit API endpoints following REST conventions.

## Planned Endpoints

### GET /api/polls/active
- Returns list of active polls
- Response: `{ polls: Poll[] }`

### GET /api/polls/[id]
- Returns single poll details
- Response: `{ poll: Poll }`

### POST /api/vote
- Submit vote for a poll
- Body: `{ pollId: string, optionId: string, voterId: string }`
- Response: `{ success: boolean }`

### GET /api/results/[id]/stream
- Server-Sent Events (SSE) stream for real-time results
- Content-Type: `text/event-stream`
- Events: `{ pollId, results: { [optionId]: count } }`

## File Naming Convention

- `+server.ts` - API route handler
- Example: `polls/active/+server.ts` → `/api/polls/active`
