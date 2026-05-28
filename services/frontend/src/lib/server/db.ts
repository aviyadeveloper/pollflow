import { Pool } from "pg";
import type { Poll } from "$lib/types";

// Validate required environment variables (only when actually needed)
function getEnvVar(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

// Lazy connection pool - created on first use
let pool: Pool | null = null;

function getPool(): Pool {
  if (!pool) {
    const appEnv = process.env.APP_ENV || "development";
    const useSSL = appEnv === "production";

    pool = new Pool({
      host: getEnvVar("POSTGRES_HOST"),
      port: parseInt(getEnvVar("POSTGRES_PORT")),
      database: getEnvVar("POSTGRES_DB"),
      user: getEnvVar("POSTGRES_USER"),
      password: getEnvVar("POSTGRES_PASSWORD"),
      max: 20,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 2000,
      // Use SSL in production (RDS), disable in development (Docker)
      ssl: useSSL
        ? {
            rejectUnauthorized: false, // RDS uses self-signed cert
          }
        : false,
    });

    pool.on("connect", () => {
      console.log("✓ PostgreSQL connected");
    });

    pool.on("error", (err: Error) => {
      console.error("PostgreSQL pool error:", err);
    });
  }
  return pool;
}

/**
 * Get all polls with vote counts ordered by active status first, then closing time
 * Excludes pending polls (only shows active and closed)
 */
export async function getAllPolls(): Promise<Poll[]> {
  const query = `
    SELECT 
      p.id,
      p.title,
      p.description,
      p.option_a as "optionA",
      p.option_b as "optionB",
      p.poll_category as "pollCategory",
      p.start_time as "startTime",
      p.end_time as "endTime",
      p.status,
      p.created_at as "createdAt",
      COUNT(CASE WHEN v.option = 'a' THEN 1 END) as "voteCountA",
      COUNT(CASE WHEN v.option = 'b' THEN 1 END) as "voteCountB",
      COUNT(v.id) as "totalVotes"
    FROM polls p
    LEFT JOIN votes v ON v.poll_id = p.id
    WHERE p.status IN ('active', 'closed')
    GROUP BY p.id
    ORDER BY 
      CASE WHEN p.status = 'active' THEN 0 ELSE 1 END,
      CASE 
        WHEN p.status = 'active' THEN p.start_time
        ELSE NULL
      END DESC,
      CASE 
        WHEN p.status = 'closed' THEN p.end_time
        ELSE NULL
      END DESC
  `;

  const result = await getPool().query(query);

  return result.rows.map((row) => ({
    ...row,
    voteCountA: parseInt(row.voteCountA) || 0,
    voteCountB: parseInt(row.voteCountB) || 0,
    totalVotes: parseInt(row.totalVotes) || 0,
  }));
}

/**
 * Get a single poll by ID with vote counts
 */
export async function getPollById(pollId: number): Promise<Poll | null> {
  const query = `
    SELECT 
      p.id,
      p.title,
      p.description,
      p.option_a as "optionA",
      p.option_b as "optionB",
      p.poll_category as "pollCategory",
      p.start_time as "startTime",
      p.end_time as "endTime",
      p.status,
      p.created_at as "createdAt",
      COUNT(CASE WHEN v.option = 'a' THEN 1 END) as "voteCountA",
      COUNT(CASE WHEN v.option = 'b' THEN 1 END) as "voteCountB",
      COUNT(v.id) as "totalVotes"
    FROM polls p
    LEFT JOIN votes v ON v.poll_id = p.id
    WHERE p.id = $1
    GROUP BY p.id
  `;

  const result = await getPool().query(query, [pollId]);

  if (result.rows.length === 0) {
    return null;
  }

  const row = result.rows[0];
  return {
    ...row,
    voteCountA: parseInt(row.voteCountA) || 0,
    voteCountB: parseInt(row.voteCountB) || 0,
    totalVotes: parseInt(row.totalVotes) || 0,
  };
}

/**
 * NOTE: Votes are submitted via Redis queue, not directly to PostgreSQL.
 * See redis.ts publishVote() for vote submission.
 * The poll-broker worker consumes the queue and writes to the database.
 */

/**
 * Get results for a poll (works for both active and closed polls)
 */
export async function getPollResults(pollId: number): Promise<{
  voteCountA: number;
  voteCountB: number;
  totalVotes: number;
} | null> {
  const query = `
    SELECT 
      COUNT(CASE WHEN option = 'a' THEN 1 END) as "voteCountA",
      COUNT(CASE WHEN option = 'b' THEN 1 END) as "voteCountB",
      COUNT(*) as "totalVotes"
    FROM votes
    WHERE poll_id = $1
  `;

  const result = await getPool().query(query, [pollId]);

  if (result.rows.length === 0) {
    return null;
  }

  const row = result.rows[0];
  return {
    voteCountA: parseInt(row.voteCountA) || 0,
    voteCountB: parseInt(row.voteCountB) || 0,
    totalVotes: parseInt(row.totalVotes) || 0,
  };
}

/**
 * Close the connection pool (for graceful shutdown)
 */
export async function closePool(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = null;
    console.log("PostgreSQL pool closed");
  }
}

export default pool;
