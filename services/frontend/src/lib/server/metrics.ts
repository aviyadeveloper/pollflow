import { Registry, collectDefaultMetrics } from "prom-client";

// Single registry shared across all requests
export const registry = new Registry();

// Collect default Node.js metrics (event loop, memory, CPU, GC, etc.)
collectDefaultMetrics({ register: registry });
