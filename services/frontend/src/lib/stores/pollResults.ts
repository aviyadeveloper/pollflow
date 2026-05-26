import { writable } from 'svelte/stores';
import type { PollResults } from '$lib/types';

// Store for poll results, keyed by poll ID
const pollResultsStore = writable<Map<number, PollResults>>(new Map());

// Single shared EventSource connection
let eventSource: EventSource | null = null;
let subscriberCount = 0;

/**
 * Subscribe to real-time poll results for a specific poll
 * Returns an unsubscribe function
 */
export function subscribeToPollResults(pollId: number, callback: (results: PollResults) => void) {
  // Increment subscriber count
  subscriberCount++;

  // Create shared EventSource if it doesn't exist
  if (!eventSource) {
    console.log('Creating shared EventSource for all polls');
    eventSource = new EventSource('/api/polls/results');

    eventSource.onmessage = (event) => {
      try {
        const results = JSON.parse(event.data) as PollResults;
        
        // Update the store
        pollResultsStore.update(map => {
          map.set(results.pollId, results);
          return map;
        });
      } catch (err) {
        console.error('Error parsing poll results:', err);
      }
    };

    eventSource.onerror = (err) => {
      console.error('EventSource error:', err);
      // Don't close on error - EventSource auto-reconnects
    };
  }

  // Subscribe to store updates for this specific poll
  const unsubscribeStore = pollResultsStore.subscribe((map) => {
    const results = map.get(pollId);
    if (results) {
      callback(results);
    }
  });

  // Return unsubscribe function
  return () => {
    subscriberCount--;
    unsubscribeStore();

    // Close EventSource when no more subscribers
    if (subscriberCount === 0 && eventSource) {
      console.log('Closing shared EventSource (no more subscribers)');
      eventSource.close();
      eventSource = null;
    }
  };
}

/**
 * Get the current results for a poll (if available)
 */
export function getPollResults(pollId: number): PollResults | undefined {
  let results: PollResults | undefined;
  pollResultsStore.subscribe(map => {
    results = map.get(pollId);
  })();
  return results;
}
