import pino from "pino";
import { Writable } from "stream";

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

// Create custom Loki stream writer (bypassing pino-loki)
class LokiStream extends Writable {
  private lokiUrl: string;
  private labels: Record<string, string>;

  constructor(lokiUrl: string, labels: Record<string, string>) {
    super();
    this.lokiUrl = lokiUrl;
    this.labels = labels;
  }

  _write(chunk: Buffer, encoding: string, callback: () => void) {
    const log = chunk.toString();

    // Send to Loki asynchronously
    this.sendToLoki(log).catch((err) => {
      console.error("Loki push error:", err.message);
    });

    // Don't wait for Loki - call callback immediately
    callback();
  }

  private async sendToLoki(logLine: string) {
    const timestamp = Date.now() + "000000"; // Loki needs nanoseconds

    // Parse pino log to extract level and convert to label
    let levelLabel = "info";
    try {
      const parsed = JSON.parse(logLine);
      if (typeof parsed.level === "number") {
        // Pino numeric levels: 10=trace, 20=debug, 30=info, 40=warn, 50=error, 60=fatal
        const levelMap: Record<number, string> = {
          10: "trace",
          20: "debug",
          30: "info",
          40: "warn",
          50: "error",
          60: "fatal",
        };
        levelLabel = levelMap[parsed.level] || "info";
      }
    } catch {
      // If parsing fails, keep default "info"
    }

    const payload = {
      streams: [
        {
          stream: { ...this.labels, level: levelLabel },
          values: [[timestamp, logLine]],
        },
      ],
    };

    const response = await fetch(`${this.lokiUrl}/loki/api/v1/push`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      throw new Error(`Loki responded with ${response.status}`);
    }
  }
}

// Create pino logger
let logger: pino.Logger;

if (lokiURL) {
  // Use custom Loki stream writer
  const lokiStream = new LokiStream(lokiURL, {
    service: "frontend",
    environment: appEnv,
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
