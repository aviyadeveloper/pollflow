import type { RequestHandler } from "./$types";
import { createRedisSubscriber } from "$lib/server/redis";
import { getAllPolls } from "$lib/server/db";

export const GET: RequestHandler = async () => {
  // Create a ReadableStream for Server-Sent Events
  const stream = new ReadableStream({
    async start(controller) {
      const encoder = new TextEncoder();

      // Create a dedicated Redis subscriber for this connection
      const subscriber = createRedisSubscriber();

      // Send initial connection comment
      controller.enqueue(encoder.encode(`: connected to all polls\n\n`));

      // Get all active polls to know which channels to subscribe to
      const polls = await getAllPolls();
      const activePolls = polls.filter(p => p.status === 'active');
      const channels = activePolls.map(p => `poll:results:${p.id}`);

      console.log(`SSE: Subscribing to ${channels.length} active poll channels:`, channels);

      // Subscribe to all active poll channels
      if (channels.length > 0) {
        await subscriber.subscribe(...channels);
      }

      // Handle incoming messages
      subscriber.on("message", (ch: string, message: string) => {
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
            console.log('Controller closed for all-polls stream, cleaning up subscriber');
            if ((controller as any)._cleanup) {
              (controller as any)._cleanup();
            }
          } else {
            console.error("Error parsing/sending results:", error);
          }
        }
      });

      // Handle errors
      subscriber.on("error", (error: Error) => {
        console.error("Redis subscriber error for all-polls stream:", error);
      });

      // Keep connection alive with periodic heartbeat
      const heartbeat = setInterval(() => {
        try {
          controller.enqueue(encoder.encode(": heartbeat\n\n"));
        } catch (error: any) {
          // Controller closed, clean up and stop heartbeat
          console.log('Heartbeat detected closed controller for all-polls stream, cleaning up');
          clearInterval(heartbeat);
          if ((controller as any)._cleanup) {
            (controller as any)._cleanup();
          }
        }
      }, 30000); // Every 30 seconds

      // Store cleanup function
      (controller as any)._cleanup = () => {
        clearInterval(heartbeat);
        subscriber.unsubscribe();
        subscriber.quit();
      };
    },

    cancel(controller) {
      console.log('Client disconnected from all-polls stream');
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
