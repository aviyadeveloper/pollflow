export interface PollLifecycleEvent {
  pollId: number;
  event: "poll_activated" | "poll_closed";
  timestamp: number;
}

type LifecycleCallback = (event: PollLifecycleEvent) => void;

// Subscribers for lifecycle events
const lifecycleSubscribers = new Set<LifecycleCallback>();

// Single shared EventSource connection
let eventSource: EventSource | null = null;
let subscriberCount = 0;

/**
 * Subscribe to poll lifecycle events (activation and closure)
 * Returns an unsubscribe function
 */
export function subscribeToPollLifecycle(callback: LifecycleCallback) {
  // Increment subscriber count
  subscriberCount++;

  // Create shared EventSource if it doesn't exist
  if (!eventSource) {
    console.log("Creating shared EventSource for poll lifecycle");
    eventSource = new EventSource("/api/polls/lifecycle");

    eventSource.onmessage = (event) => {
      try {
        const lifecycleEvent = JSON.parse(event.data) as PollLifecycleEvent;

        // Notify all subscribers
        lifecycleSubscribers.forEach((callback) => callback(lifecycleEvent));
      } catch (err) {
        console.error("Error parsing lifecycle event:", err);
      }
    };

    eventSource.onerror = (err) => {
      console.error("Lifecycle EventSource error:", err);
      // Don't close on error - EventSource auto-reconnects
    };
  }

  // Add callback to subscribers
  lifecycleSubscribers.add(callback);

  // Return unsubscribe function
  return () => {
    subscriberCount--;

    // Remove callback from subscribers
    lifecycleSubscribers.delete(callback);

    // Close EventSource when no more subscribers
    if (subscriberCount === 0 && eventSource) {
      console.log("Closing lifecycle EventSource (no more subscribers)");
      eventSource.close();
      eventSource = null;
    }
  };
}
