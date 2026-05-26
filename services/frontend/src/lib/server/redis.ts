import Redis from "ioredis";
import type { VoteRequest } from "$lib/types";

// Validate required environment variables
function getEnvVar(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

// Get optional environment variable
function getOptionalEnvVar(name: string): string | undefined {
  return process.env[name] || undefined;
}

// Redis client for queue operations
const redis = new Redis({
  host: getEnvVar("REDIS_HOST"),
  port: parseInt(getEnvVar("REDIS_PORT")),
  password: getOptionalEnvVar("REDIS_PASSWORD"),
  maxRetriesPerRequest: 3,
  retryStrategy(times) {
    const delay = Math.min(times * 50, 2000);
    return delay;
  },
});

redis.on("connect", () => {
  console.log("✓ Redis connected (queue)");
});

redis.on("error", (err: Error) => {
  console.error("Redis error (queue):", err);
});

/**
 * Push a vote to the Redis queue for processing by poll-broker
 */
export async function publishVote(vote: VoteRequest): Promise<void> {
  const queueName = "votes:queue";
  const payload = JSON.stringify({
    poll_id: vote.pollId,
    option: vote.option,
    user_ip: vote.userIp,
    timestamp: Date.now(),
  });

  await redis.rpush(queueName, payload);
}

export default redis;
