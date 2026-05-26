import type { PollResults } from "$lib/types";

// Simple store for poll results without Svelte stores
const resultsMap = new Map<number, PollResults>();
const pollSubscribers = new Map<number, Set<(results: PollResults) => void>>();

// Single shared EventSource connection
let eventSource: EventSource | null = null;
let subscriberCount = 0;

/**
 * Subscribe to real-time poll results for a specific poll
 * Returns an unsubscribe function
 */
export function subscribeToPollResults(
  pollId: number,
  callback: (results: PollResults) => void,
) {
  // Increment subscriber count
  subscriberCount++;

  // Create shared EventSource if it doesn't exist
  if (!eventSource) {
    console.log("Creating shared EventSource for all polls");
    eventSource = new EventSource("/api/polls/results");

    eventSource.onmessage = (event) => {
      try {
        const results = JSON.parse(event.data) as PollResults;

        // Update the results map
        resultsMap.set(results.pollId, results);

        // Notify subscribers for this specific poll
        const subscribers = pollSubscribers.get(results.pollId);
        if (subscribers) {
          subscribers.forEach((callback) => callback(results));
        }
      } catch (err) {
        console.error("Error parsing poll results:", err);
      }
    };

    eventSource.onerror = (err) => {
      console.error("EventSource error:", err);
      // Don't close on error - EventSource auto-reconnects
    };
  }

  // Get or create subscriber set for this poll
  let subscribers = pollSubscribers.get(pollId);
  if (!subscribers) {
    subscribers = new Set();
    pollSubscribers.set(pollId, subscribers);
  }

  // Add callback to subscribers
  subscribers.add(callback);

  // Call callback immediately if we already have results
  const existingResults = resultsMap.get(pollId);
  if (existingResults) {
    callback(existingResults);
  }

  // Return unsubscribe function
  return () => {
    subscriberCount--;

    // Remove callback from subscribers
    const subscribers = pollSubscribers.get(pollId);
    if (subscribers) {
      subscribers.delete(callback);
      if (subscribers.size === 0) {
        pollSubscribers.delete(pollId);
      }
    }

    // Close EventSource when no more subscribers
    if (subscriberCount === 0 && eventSource) {
      console.log("Closing shared EventSource (no more subscribers)");
      eventSource.close();
      eventSource = null;
    }
  };
}

/**
 * Get the current results for a poll (if available)
 */
export function getPollResults(pollId: number): PollResults | undefined {
  return resultsMap.get(pollId);
}
