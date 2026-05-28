import type { RequestHandler } from "./$types";
import { createRedisSubscriber } from "$lib/server/redis";
import { logger } from "$lib/server/logger";

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

      logger.info(
        { event: "sse_lifecycle_subscribed" },
        "Subscribing to poll lifecycle channel",
      );

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
              logger.debug(
                { event: "sse_lifecycle_controller_closed" },
                "Controller closed, cleaning up subscriber",
              );
              if ((controller as any)._cleanup) {
                (controller as any)._cleanup();
              }
            } else {
              logger.error(
                { event: "sse_lifecycle_error", error },
                "Error parsing/sending lifecycle event",
              );
            }
          }
        }
      });

      // Handle errors
      subscriber.on("error", (error: Error) => {
        logger.error(
          { event: "sse_lifecycle_subscriber_error", error: error.message },
          "Redis subscriber error",
        );
      });

      // Keep connection alive with periodic heartbeat
      const heartbeat = setInterval(() => {
        try {
          controller.enqueue(encoder.encode(": heartbeat\n\n"));
        } catch (error: any) {
          // Controller closed, clean up and stop heartbeat
          logger.debug(
            { event: "sse_lifecycle_heartbeat_closed" },
            "Heartbeat detected closed controller",
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
      logger.info(
        { event: "sse_lifecycle_disconnected" },
        "Client disconnected from lifecycle stream",
      );
      if ((controller as any)._cleanup) {
        (controller as any)._cleanup().catch((err: any) => {
          logger.debug(
            {
              event: "sse_lifecycle_cancel_error",
              error: err.code || err.message,
            },
            "Error during SSE cancel",
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
