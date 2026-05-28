import pino from "pino";

// Get Loki URL from environment (optional)
const lokiURL = process.env.LOKI_URL;
const appEnv = process.env.APP_ENV || "development";

// Configure pino logger with optional Loki transport
const options: pino.LoggerOptions = {
  level: process.env.LOG_LEVEL || "info",
  base: {
    service: "frontend",
    environment: appEnv,
  },
  timestamp: pino.stdTimeFunctions.isoTime,
};

// Only add custom formatters if NOT using Loki (Loki transport expects standard pino format)
if (!lokiURL) {
  options.formatters = {
    level: (label) => {
      return { level: label };
    },
  };
}

// Add Loki transport if URL is configured
if (lokiURL) {
  options.transport = {
    target: "pino-loki",
    options: {
      batching: true,
      interval: 5,
      host: lokiURL,
      labels: { service: "frontend", environment: appEnv },
      silenceErrors: false,
    },
  };
}

// Create pino logger
export const logger = pino(options);

// Helper function for adding context fields
export const withFields = (fields: Record<string, unknown>) => {
  return logger.child(fields);
};
