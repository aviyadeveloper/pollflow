import type { RequestHandler } from "./$types";
import Redis from "ioredis";

function getEnvVar(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function getOptionalEnvVar(name: string): string | undefined {
  return process.env[name] || undefined;
}

export const GET: RequestHandler = async ({ params }) => {
  const pollId = parseInt(params.id);

  if (isNaN(pollId)) {
    return new Response(JSON.stringify({ error: "Invalid poll ID" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const channel = `poll:results:${pollId}`;

  // Create a ReadableStream for Server-Sent Events
  const stream = new ReadableStream({
    async start(controller) {
      const encoder = new TextEncoder();

      // Create a dedicated Redis subscriber for this connection
      const subscriber = new Redis({
        host: getEnvVar("REDIS_HOST"),
        port: parseInt(getEnvVar("REDIS_PORT")),
        password: getOptionalEnvVar("REDIS_PASSWORD"),
      });

      // Send initial connection comment
      controller.enqueue(encoder.encode(`: connected to poll ${pollId}\n\n`));

      // Subscribe to the channel
      await subscriber.subscribe(channel);

      // Handle incoming messages
      subscriber.on("message", (ch: string, message: string) => {
        if (ch === channel) {
          try {
            const raw = JSON.parse(message);
            // Transform snake_case to camelCase
            const results = {
              pollId: raw.poll_id,
              voteCountA: raw.option_a_count,
              voteCountB: raw.option_b_count,
              totalVotes: raw.total_votes,
              lastUpdated: new Date().toISOString(),
            };

            const data = `data: ${JSON.stringify(results)}\n\n`;
            controller.enqueue(encoder.encode(data));
          } catch (error) {
            console.error("Error parsing/sending results:", error);
          }
        }
      });

      // Handle errors
      subscriber.on("error", (error: Error) => {
        console.error(`Redis subscriber error for poll ${pollId}:`, error);
      });

      // Keep connection alive with periodic heartbeat
      const heartbeat = setInterval(() => {
        try {
          controller.enqueue(encoder.encode(": heartbeat\n\n"));
        } catch (error) {
          // Controller closed, stop heartbeat
          clearInterval(heartbeat);
        }
      }, 30000); // Every 30 seconds

      // Store cleanup function
      (controller as any)._cleanup = () => {
        clearInterval(heartbeat);
        subscriber.unsubscribe(channel);
        subscriber.quit();
      };
    },

    cancel(controller) {
      console.log(`Client disconnected from poll ${pollId} stream`);
      if ((controller as any)._cleanup) {
        (controller as any)._cleanup();
      }
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
    },
  });
};
