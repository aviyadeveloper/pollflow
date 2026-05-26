import type { RequestHandler } from "./$types";
import { createRedisSubscriber } from "$lib/server/redis";

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
      const subscriber = createRedisSubscriber();

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
          } catch (error: any) {
            // If controller is closed, clean up the subscriber
            if (error?.code === 'ERR_INVALID_STATE' || error?.message?.includes('Controller is already closed')) {
              console.log(`Controller closed for poll ${pollId}, cleaning up subscriber`);
              if ((controller as any)._cleanup) {
                (controller as any)._cleanup();
              }
            } else {
              console.error("Error parsing/sending results:", error);
            }
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
        } catch (error: any) {
          // Controller closed, clean up and stop heartbeat
          console.log(`Heartbeat detected closed controller for poll ${pollId}, cleaning up`);
          clearInterval(heartbeat);
          if ((controller as any)._cleanup) {
            (controller as any)._cleanup();
          }
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
