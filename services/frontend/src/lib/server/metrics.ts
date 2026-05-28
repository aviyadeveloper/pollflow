import { register, Counter, Histogram, Gauge } from "prom-client";

// HTTP request metrics
export const httpRequestsTotal = new Counter({
  name: "frontend_http_requests_total",
  help: "Total number of HTTP requests",
  labelNames: ["method", "route", "status"],
});

export const httpRequestDuration = new Histogram({
  name: "frontend_http_request_duration_seconds",
  help: "HTTP request duration in seconds",
  labelNames: ["method", "route", "status"],
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 2, 5],
});

// Database metrics
export const dbQueryDuration = new Histogram({
  name: "frontend_db_query_duration_seconds",
  help: "Database query duration in seconds",
  labelNames: ["operation"],
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 2, 5],
});

export const dbErrors = new Counter({
  name: "frontend_db_errors_total",
  help: "Total number of database errors",
  labelNames: ["operation"],
});

// Redis metrics
export const redisOperationDuration = new Histogram({
  name: "frontend_redis_operation_duration_seconds",
  help: "Redis operation duration in seconds",
  labelNames: ["operation"],
  buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1],
});

export const redisErrors = new Counter({
  name: "frontend_redis_errors_total",
  help: "Total number of Redis errors",
  labelNames: ["operation"],
});

// Vote metrics
export const votesSubmitted = new Counter({
  name: "frontend_votes_submitted_total",
  help: "Total number of votes submitted",
  labelNames: ["poll_id"],
});

// Active polls
export const activePolls = new Gauge({
  name: "frontend_active_polls",
  help: "Number of currently active polls",
});

// Export the Prometheus registry
export { register };
