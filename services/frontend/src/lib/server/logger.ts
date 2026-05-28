import pino from "pino";

// Create pino logger with JSON formatter
export const logger = pino({
  level: process.env.LOG_LEVEL || "info",
  base: {
    service: "frontend",
  },
  timestamp: pino.stdTimeFunctions.isoTime,
  formatters: {
    level: (label) => {
      return { level: label };
    },
  },
});

// Helper function for adding context fields
export const withFields = (fields: Record<string, unknown>) => {
  return logger.child(fields);
};
