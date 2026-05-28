import pino from "pino";
import pinoLoki from "pino-loki";

// Get Loki URL from environment (optional)
const lokiURL = process.env.LOKI_URL;
const appEnv = process.env.APP_ENV || "development";

// Configure pino logger
const options: pino.LoggerOptions = {
  level: process.env.LOG_LEVEL || "info",
  base: {
    service: "frontend",
    environment: appEnv,
  },
  timestamp: pino.stdTimeFunctions.isoTime,
};

// Only add custom formatters if NOT using Loki (pino-loki needs standard pino format)
if (!lokiURL) {
  options.formatters = {
    level: (label) => {
      return { level: label };
    },
  };
}

// Create pino logger
let logger: pino.Logger;

if (lokiURL) {
  // Use pino-loki directly (not as transport) for better error visibility
  const lokiStream = pinoLoki({
    host: lokiURL,
    labels: { service: "frontend", environment: appEnv },
    // Disable batching for immediate log delivery (can enable later for performance)
    batching: false,
    replaceTimestamp: false,
    convertArrays: false,
  });

  // Log any Loki errors to console
  lokiStream.on("error", (err) => {
    console.error("Loki stream error:", err);
  });

  logger = pino(options, lokiStream);
} else {
  logger = pino(options);
}

export { logger };

// Helper function for adding context fields
export const withFields = (fields: Record<string, unknown>) => {
  return logger.child(fields);
};
