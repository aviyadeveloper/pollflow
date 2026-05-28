import type { RequestHandler } from "./$types";
import { createRedisSubscriber } from "$lib/server/redis";

export const GET: RequestHandler = async () => {
  // Create a ReadableStream for Server-Sent Events
  const stream = new ReadableStream({
    async start(controller) {
      const encoder = new TextEncoder();

      // Create a dedicated Redis subscriber for this connection
      const subscriber = createRedisSubscriber();

      // Send initial connection comment
      controller.enqueue(encoder.encode(`: connected to poll lifecycle\n\n`));

      const channel = "poll:lifecycle";

      console.log("SSE: Subscribing to poll lifecycle channel");

      // Subscribe to the lifecycle channel
      await subscriber.subscribe(channel);

      // Handle incoming messages
      subscriber.on("message", (ch: string, message: string) => {
        if (ch === channel) {
          try {
            const raw = JSON.parse(message);
            // Transform snake_case to camelCase
            const event = {
              pollId: raw.poll_id,
              event: raw.event, // "poll_activated" or "poll_closed"
              timestamp: raw.timestamp,
            };

            const data = `data: ${JSON.stringify(event)}\n\n`;
            controller.enqueue(encoder.encode(data));
          } catch (error: any) {
            // If controller is closed, clean up the subscriber
            if (
              error?.code === "ERR_INVALID_STATE" ||
              error?.message?.includes("Controller is already closed")
            ) {
              console.log(
                "Controller closed for lifecycle stream, cleaning up subscriber",
              );
              if ((controller as any)._cleanup) {
                (controller as any)._cleanup();
              }
            } else {
              console.error("Error parsing/sending lifecycle event:", error);
            }
          }
        }
      });

      // Handle errors
      subscriber.on("error", (error: Error) => {
        console.error("Redis subscriber error for lifecycle stream:", error);
      });

      // Keep connection alive with periodic heartbeat
      const heartbeat = setInterval(() => {
        try {
          controller.enqueue(encoder.encode(": heartbeat\n\n"));
        } catch (error: any) {
          // Controller closed, clean up and stop heartbeat
          console.log(
            "Heartbeat detected closed controller for lifecycle stream, cleaning up",
          );
          clearInterval(heartbeat);
          if ((controller as any)._cleanup) {
            (controller as any)._cleanup();
          }
        }
      }, 30000); // Every 30 seconds

      // Store cleanup function
      (controller as any)._cleanup = async () => {
        clearInterval(heartbeat);
        // Silence all event handlers to prevent errors during cleanup
        subscriber.removeAllListeners();
        // Simply disconnect - don't try to unsubscribe or quit
        // The connection will clean up on its own
        try {
          subscriber.disconnect(false);
        } catch (e) {
          // Ignore
        }
      };
    },

    cancel(controller) {
      console.log("Client disconnected from lifecycle stream");
      if ((controller as any)._cleanup) {
        (controller as any)._cleanup().catch((err: any) => {
          console.log(
            "Error during lifecycle SSE cancel:",
            err.code || err.message,
          );
        });
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
