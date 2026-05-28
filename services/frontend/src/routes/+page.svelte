<script lang="ts">
  import { onMount, onDestroy } from "svelte";
  import type { PageData } from "./$types";
  import type { Poll } from "$lib/types";
  import PollCard from "$lib/components/PollCard.svelte";
  import { subscribeToPollLifecycle } from "$lib/stores/pollLifecycle";

  let { data }: { data: PageData } = $props();

  // Make polls reactive so we can add/update them from lifecycle events
  let pollsRaw = $state<Poll[]>(data.polls || []);

  // Sorted polls: active first (newest first), then closed (most recently closed)
  const polls = $derived(() => {
    return [...pollsRaw].sort((a, b) => {
      // Active polls first
      if (a.status === "active" && b.status !== "active") return -1;
      if (a.status !== "active" && b.status === "active") return 1;

      const aStartTime = new Date(a.startTime).getTime();
      const bStartTime = new Date(b.startTime).getTime();
      const aEndTime = new Date(a.endTime).getTime();
      const bEndTime = new Date(b.endTime).getTime();

      // Within active: sort by start_time DESC (newest first, appears at top)
      if (a.status === "active" && b.status === "active") {
        return bStartTime - aStartTime;
      }

      // Within closed: sort by end_time DESC (most recently closed first)
      if (a.status === "closed" && b.status === "closed") {
        return bEndTime - aEndTime;
      }

      return 0;
    });
  });

  let nextPollSeconds = $state(0);
  let interval: ReturnType<typeof setInterval> | null = null;
  let unsubscribeLifecycle: (() => void) | null = null;

  // Filter state
  let selectedStatus = $state<"all" | "active" | "ended">("all");
  let selectedCategory = $state<string>("all");

  // Get unique categories from polls
  const categories = $derived(() => {
    if (!pollsRaw || pollsRaw.length === 0) return [];
    const cats = new Set(pollsRaw.map((p: Poll) => p.pollCategory));
    return Array.from(cats).sort();
  });

  // Filtered polls based on selected filters
  const filteredPolls = $derived(() => {
    return polls().filter((poll: Poll) => {
      // Status filter
      if (selectedStatus === "active" && poll.status !== "active") return false;
      if (selectedStatus === "ended" && poll.status === "active") return false;

      // Category filter
      if (selectedCategory !== "all" && poll.pollCategory !== selectedCategory)
        return false;

      return true;
    });
  });

  const nextPollProgress = $derived(() => {
    const total = 5 * 60; // 5 minutes in seconds
    return ((total - nextPollSeconds) / total) * 100;
  });

  const nextPollDisplay = $derived(() => {
    if (nextPollSeconds <= 0) return "Refresh";
    const minutes = Math.floor(nextPollSeconds / 60);
    const seconds = nextPollSeconds % 60;
    return `${minutes}:${seconds.toString().padStart(2, "0")}`;
  });

  onMount(() => {
    updateNextPollCountdown();
    interval = setInterval(updateNextPollCountdown, 1000);

    // Subscribe to poll lifecycle events
    unsubscribeLifecycle = subscribeToPollLifecycle(async (event) => {
      if (event.event === "poll_activated") {
        console.log(`Poll ${event.pollId} activated, fetching data...`);

        // Fetch the full poll data
        try {
          const response = await fetch(`/api/polls/${event.pollId}`);
          if (response.ok) {
            const data = await response.json();
            const newPoll = data.poll as Poll;

            // Add to polls array (will be auto-sorted by derived state)
            pollsRaw = [newPoll, ...pollsRaw];
            console.log(`Poll ${event.pollId} added to UI`);
          } else {
            console.error(
              `Failed to fetch poll ${event.pollId}:`,
              response.statusText,
            );
          }
        } catch (error) {
          console.error(`Error fetching poll ${event.pollId}:`, error);
        }
      } else if (event.event === "poll_closed") {
        console.log(`Poll ${event.pollId} closed, updating status...`);

        // Find and update the poll status
        const pollIndex = pollsRaw.findIndex((p) => p.id === event.pollId);
        if (pollIndex !== -1) {
          // Update the poll status to closed (will be auto-sorted by derived state)
          pollsRaw[pollIndex] = { ...pollsRaw[pollIndex], status: "closed" };
          console.log(`Poll ${event.pollId} marked as closed`);
        }
      }
    });
  });

  onDestroy(() => {
    if (interval) clearInterval(interval);
    if (unsubscribeLifecycle) unsubscribeLifecycle();
  });

  function updateNextPollCountdown() {
    if (pollsRaw.length === 0) {
      nextPollSeconds = 0;
      return;
    }

    // Find the poll with the most recent start time (newest poll)
    const mostRecentPoll = pollsRaw.reduce((latest: Poll, poll: Poll) => {
      const pollStart = new Date(poll.startTime).getTime();
      const latestStart = new Date(latest.startTime).getTime();
      return pollStart > latestStart ? poll : latest;
    }, pollsRaw[0]);

    const latestStart = new Date(mostRecentPoll.startTime).getTime();

    // Next poll is 5 minutes after the most recent poll's start time
    const nextPollTime = latestStart + 5 * 60 * 1000;
    const now = Date.now();
    const diff = nextPollTime - now;

    nextPollSeconds = Math.max(0, Math.floor(diff / 1000));
  }
</script>

<div class="container">
  <div class="filters">
    <div class="filter-row">
      <div class="branding">
        <h1>PollFlow</h1>
        <p class="subtitle">Real-time Voting</p>
      </div>

      <div class="filter-group timer-group">
        <div class="timer-circle">
          <svg width="50" height="50" viewBox="0 0 50 50">
            <circle
              cx="25"
              cy="25"
              r="22"
              fill="none"
              stroke="rgba(59, 130, 246, 0.2)"
              stroke-width="2.5"
            />
            <circle
              cx="25"
              cy="25"
              r="22"
              fill="none"
              stroke="url(#gradient)"
              stroke-width="2.5"
              stroke-dasharray="138.23"
              stroke-dashoffset={138.23 * (1 - nextPollProgress() / 100)}
              stroke-linecap="round"
              transform="rotate(-90 25 25)"
              class="timer-progress"
            />
            <defs>
              <linearGradient id="gradient" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" style="stop-color:#3b82f6;stop-opacity:1" />
                <stop offset="100%" style="stop-color:#8b5cf6;stop-opacity:1" />
              </linearGradient>
            </defs>
          </svg>
          <div class="timer-content">
            <div class="timer-label">Next</div>
            <div class="timer-value">{nextPollDisplay()}</div>
          </div>
        </div>
      </div>

      <div class="filter-group">
        <span class="filter-label">Status:</span>
        <button
          class="filter-btn"
          class:active={selectedStatus === "all"}
          onclick={() => (selectedStatus = "all")}
        >
          All
        </button>
        <button
          class="filter-btn"
          class:active={selectedStatus === "active"}
          onclick={() => (selectedStatus = "active")}
        >
          Active
        </button>
        <button
          class="filter-btn"
          class:active={selectedStatus === "ended"}
          onclick={() => (selectedStatus = "ended")}
        >
          Ended
        </button>
      </div>
    </div>

    <div class="filter-row">
      <div class="filter-group">
        <span class="filter-label">Category:</span>
        <button
          class="filter-btn"
          class:active={selectedCategory === "all"}
          onclick={() => (selectedCategory = "all")}
        >
          All
        </button>
        {#each categories() as category}
          <button
            class="filter-btn"
            class:active={selectedCategory === category}
            onclick={() => (selectedCategory = category as string)}
          >
            {category}
          </button>
        {/each}
      </div>
    </div>
  </div>

  <main>
    {#if filteredPolls().length === 0}
      <div class="empty-state">
        <p>No polls match your filters.</p>
      </div>
    {:else}
      <div class="polls-grid">
        {#each filteredPolls() as poll (poll.id)}
          <PollCard {poll} />
        {/each}
      </div>
    {/if}
  </main>
</div>

<style>
  :global(body) {
    background: #0f172a;
    color: #f8fafc;
    margin: 0;
    min-height: 100vh;
  }

  .container {
    max-width: 1400px;
    margin: 0 auto;
    padding: 3rem 2rem;
  }

  .branding {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    padding-right: 1.5rem;
    border-right: 1px solid #475569;
  }

  h1 {
    font-size: 1.5rem;
    margin: 0;
    background: linear-gradient(135deg, #3b82f6 0%, #8b5cf6 100%);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    font-weight: 800;
    letter-spacing: -0.02em;
    line-height: 1;
  }

  .subtitle {
    font-size: 0.75rem;
    color: #94a3b8;
    margin: 0;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .timer-group {
    padding-right: 1.5rem;
    border-right: 1px solid #475569;
  }

  .timer-circle {
    position: relative;
    width: 50px;
    height: 50px;
  }

  .timer-progress {
    transition: stroke-dashoffset 1s linear;
  }

  .timer-content {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    text-align: center;
  }

  .timer-label {
    font-size: 0.5rem;
    color: #94a3b8;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    font-weight: 600;
    margin-bottom: 0;
    line-height: 1;
  }

  .timer-value {
    color: #60a5fa;
    font-size: 0.625rem;
    font-weight: 700;
    font-variant-numeric: tabular-nums;
    line-height: 1;
  }

  .empty-state {
    text-align: center;
    padding: 6rem 2rem;
    color: #64748b;
    font-size: 1.125rem;
  }

  .filters {
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
    margin-bottom: 3rem;
    padding: 1.25rem 1.5rem;
    background: rgba(30, 41, 59, 0.5);
    border: 1px solid #334155;
    border-radius: 1rem;
  }

  .filter-row {
    display: flex;
    align-items: center;
    gap: 2rem;
    flex-wrap: wrap;
  }

  .filter-group {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    flex-wrap: wrap;
  }

  .filter-label {
    color: #94a3b8;
    font-size: 0.875rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .filter-btn {
    padding: 0.5rem 1rem;
    border: 1px solid #475569;
    background: transparent;
    color: #cbd5e1;
    border-radius: 0.5rem;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .filter-btn:hover {
    background: rgba(59, 130, 246, 0.1);
    border-color: #3b82f6;
    color: #60a5fa;
  }

  .filter-btn.active {
    background: linear-gradient(135deg, #3b82f6 0%, #8b5cf6 100%);
    border-color: transparent;
    color: #ffffff;
    box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
  }

  .polls-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 1.5rem;
  }

  @media (max-width: 768px) {
    .container {
      padding: 2rem 1rem;
    }

    h1 {
      font-size: 1.25rem;
    }

    .subtitle {
      font-size: 0.625rem;
    }

    .filter-row {
      flex-direction: column;
      align-items: stretch;
      gap: 1rem;
    }

    .branding {
      border-right: none;
      padding-right: 0;
      padding-bottom: 1rem;
      border-bottom: 1px solid #475569;
    }

    .filter-group {
      width: 100%;
      justify-content: flex-start;
    }

    .timer-group {
      border-right: none;
      padding-right: 0;
      padding-bottom: 1rem;
      border-bottom: 1px solid #475569;
    }

    .polls-grid {
      grid-template-columns: 1fr;
      gap: 1.25rem;
    }
  }

  @media (min-width: 1600px) {
    .polls-grid {
      grid-template-columns: repeat(5, 1fr);
    }
  }
</style>
