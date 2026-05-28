<script lang="ts">
  import { onMount, onDestroy } from "svelte";
  import type { Poll, PollResults } from "$lib/types";
  import { subscribeToPollResults } from "$lib/stores/pollResults";

  interface Props {
    poll: Poll;
  }

  let { poll }: Props = $props();

  // State management
  let userVote = $state<"a" | "b" | null>(null);
  let isSubmitting = $state(false);
  let justVoted = $state(false);
  let error = $state<string | null>(null);
  let results = $state<PollResults | null>(null);
  let unsubscribe: (() => void) | null = null;
  let timeRemaining = $state(0);
  let interval: ReturnType<typeof setInterval> | null = null;

  // Derived state
  const isPollActive = $derived(
    poll.status === "active" &&
      new Date(poll.startTime) <= new Date() &&
      new Date(poll.endTime) >= new Date(),
  );

  const timeProgress = $derived(() => {
    if (!isPollActive) return 0;
    const now = Date.now();
    const start = new Date(poll.startTime).getTime();
    const end = new Date(poll.endTime).getTime();
    const elapsed = now - start;
    const total = end - start;
    return Math.max(0, Math.min(100, (elapsed / total) * 100));
  });

  onMount(() => {
    // Check if user has already voted and which option
    const storedVote = localStorage.getItem(`poll_${poll.id}_vote`);
    if (storedVote === "a" || storedVote === "b") {
      userVote = storedVote;
    }

    // Subscribe to real-time results for active polls via shared connection
    if (isPollActive) {
      unsubscribe = subscribeToPollResults(poll.id, (updatedResults) => {
        results = updatedResults;
      });
      updateTimeRemaining();
      interval = setInterval(updateTimeRemaining, 1000);
    }
  });

  onDestroy(() => {
    if (unsubscribe) {
      unsubscribe();
      unsubscribe = null;
    }
    if (interval) clearInterval(interval);
  });

  function updateTimeRemaining() {
    const now = Date.now();
    const end = new Date(poll.endTime).getTime();
    timeRemaining = Math.max(0, Math.floor((end - now) / 1000));
  }

  function formatTimeRemaining(): string {
    const hours = Math.floor(timeRemaining / 3600);
    const minutes = Math.floor((timeRemaining % 3600) / 60);
    const seconds = timeRemaining % 60;

    if (hours > 0) {
      return `${hours}h ${minutes}m`;
    } else if (minutes > 0) {
      return `${minutes}m ${seconds}s`;
    } else {
      return `${seconds}s`;
    }
  }

  async function handleVote(option: "a" | "b") {
    if (userVote || !isPollActive || isSubmitting) return;

    isSubmitting = true;
    justVoted = true;
    error = null;

    try {
      const response = await fetch(`/api/polls/${poll.id}/vote`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ option }),
      });

      const result = await response.json();

      if (!response.ok) {
        throw new Error(result.error || "Failed to submit vote");
      }

      userVote = option;
      localStorage.setItem(`poll_${poll.id}_vote`, option);

      // Reset animation after 600ms
      setTimeout(() => {
        justVoted = false;
      }, 600);
    } catch (err) {
      error = err instanceof Error ? err.message : "Failed to submit vote";
      justVoted = false;
    } finally {
      isSubmitting = false;
    }
  }

  function getVotePercentage(option: "a" | "b"): number {
    const total = results ? results.totalVotes : poll.totalVotes;
    if (total === 0) return 0;
    const count = results
      ? option === "a"
        ? results.voteCountA
        : results.voteCountB
      : option === "a"
        ? poll.voteCountA
        : poll.voteCountB;
    return (count / total) * 100;
  }

  function getVoteCount(option: "a" | "b"): number {
    if (results) {
      return option === "a" ? results.voteCountA : results.voteCountB;
    }
    return option === "a" ? poll.voteCountA : poll.voteCountB;
  }
</script>

<div
  class="poll-card"
  class:active={isPollActive}
  class:closed={!isPollActive}
  class:just-voted={justVoted}
>
  {#if isPollActive}
    <div class="time-bar-container">
      <div class="time-bar" style="width: {timeProgress()}%"></div>
    </div>
  {/if}

  <div class="card-content">
    <div class="card-header">
      <h3 class="poll-title">{poll.title}</h3>
    </div>

    {#if poll.description}
      <p class="description">{poll.description}</p>
    {/if}

    {#if isPollActive && !userVote}
      <div class="vote-buttons">
        <button
          class="vote-btn yes"
          onclick={() => handleVote("a")}
          disabled={isSubmitting}
        >
          <span class="vote-icon">✓</span>
          <span class="vote-text">{poll.optionA}</span>
        </button>

        <button
          class="vote-btn no"
          onclick={() => handleVote("b")}
          disabled={isSubmitting}
        >
          <span class="vote-icon">✕</span>
          <span class="vote-text">{poll.optionB}</span>
        </button>
      </div>

      {#if error}
        <div class="error">{error}</div>
      {/if}
    {:else}
      <div class="results">
        <div class="result-item" class:user-voted={userVote === "a"}>
          <div class="result-header">
            <span class="option-label yes-label">
              {#if userVote === "a"}
                <span class="vote-indicator">●</span>
              {/if}
              {poll.optionA}
            </span>
            <span class="vote-count">{getVoteCount("a")}</span>
          </div>
          <div class="progress-bar">
            <div
              class="progress yes-progress"
              style="width: {getVotePercentage('a')}%"
            ></div>
          </div>
        </div>

        <div class="result-item" class:user-voted={userVote === "b"}>
          <div class="result-header">
            <span class="option-label no-label">
              {#if userVote === "b"}
                <span class="vote-indicator">●</span>
              {/if}
              {poll.optionB}
            </span>
            <span class="vote-count">{getVoteCount("b")}</span>
          </div>
          <div class="progress-bar">
            <div
              class="progress no-progress"
              style="width: {getVotePercentage('b')}%"
            ></div>
          </div>
        </div>
      </div>
    {/if}
  </div>

  <div class="card-footer">
    <span class="tag category">{poll.pollCategory}</span>
    {#if isPollActive}
      <span class="time-badge">{formatTimeRemaining()}</span>
    {:else}
      <span class="closed-badge">CLOSED</span>
    {/if}
  </div>
</div>

<style>
  .poll-card {
    border: 1px solid #334155;
    border-radius: 1rem;
    overflow: hidden;
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    box-shadow:
      0 4px 6px -1px rgba(0, 0, 0, 0.3),
      0 2px 4px -1px rgba(0, 0, 0, 0.2);
    height: 100%;
    display: flex;
    flex-direction: column;
    position: relative;
    background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%);
  }

  .poll-card.active {
    box-shadow:
      0 4px 6px -1px rgba(0, 0, 0, 0.3),
      0 2px 4px -1px rgba(0, 0, 0, 0.2),
      0 0 20px rgba(59, 130, 246, 0.3),
      0 0 40px rgba(59, 130, 246, 0.1);
    border-color: rgba(59, 130, 246, 0.3);
  }

  .poll-card.closed {
    opacity: 0.85;
    border-color: #334155;
  }

  .poll-card.closed:hover {
    opacity: 1;
  }

  .poll-card.just-voted {
    animation: vote-pulse 0.6s cubic-bezier(0.4, 0, 0.2, 1);
  }

  @keyframes vote-pulse {
    0%,
    100% {
      transform: scale(1);
    }
    50% {
      transform: scale(1.05);
      box-shadow:
        0 25px 30px -5px rgba(59, 130, 246, 0.5),
        0 15px 15px -5px rgba(59, 130, 246, 0.4);
    }
  }

  .poll-card:hover {
    border-color: #475569;
    box-shadow:
      0 20px 25px -5px rgba(0, 0, 0, 0.4),
      0 10px 10px -5px rgba(0, 0, 0, 0.3);
  }

  .poll-card.active:hover {
    box-shadow:
      0 20px 25px -5px rgba(0, 0, 0, 0.4),
      0 10px 10px -5px rgba(0, 0, 0, 0.3),
      0 0 30px rgba(59, 130, 246, 0.4),
      0 0 60px rgba(59, 130, 246, 0.15);
    transform: translateY(-2px);
  }

  .time-bar-container {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 3px;
    background: rgba(51, 65, 85, 0.5);
    overflow: hidden;
  }

  .time-bar {
    height: 100%;
    background: linear-gradient(90deg, #3b82f6, #8b5cf6);
    transition: width 1s linear;
    box-shadow: 0 0 10px rgba(59, 130, 246, 0.6);
  }

  .card-content {
    padding: 1.5rem;
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
  }

  .card-header {
    display: flex;
    align-items: flex-start;
  }

  .poll-title {
    font-size: 1.125rem;
    font-weight: 700;
    margin: 0;
    color: #f8fafc;
    line-height: 1.4;
    letter-spacing: -0.01em;
    flex: 1;
  }

  .description {
    color: #94a3b8;
    margin: 0;
    line-height: 1.5;
    font-size: 0.875rem;
  }

  .vote-buttons {
    display: flex;
    gap: 0.75rem;
    margin-top: auto;
  }

  .vote-btn {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.5rem;
    padding: 1rem 0.75rem;
    border: 2px solid;
    border-radius: 0.75rem;
    font-weight: 600;
    font-size: 0.9375rem;
    cursor: pointer;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    position: relative;
    overflow: hidden;
  }

  .vote-btn::before {
    content: "";
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    opacity: 0;
    transition: opacity 0.2s;
  }

  .vote-btn:hover::before {
    opacity: 0.1;
    background: white;
  }

  .vote-btn:active {
    transform: scale(0.95);
  }

  .vote-btn.yes {
    background: rgba(16, 185, 129, 0.15);
    border-color: #10b981;
    color: #10b981;
  }

  .vote-btn.yes:hover {
    background: rgba(16, 185, 129, 0.25);
    border-color: #34d399;
    box-shadow: 0 0 20px rgba(16, 185, 129, 0.3);
  }

  .vote-btn.no {
    background: rgba(239, 68, 68, 0.15);
    border-color: #ef4444;
    color: #ef4444;
  }

  .vote-btn.no:hover {
    background: rgba(239, 68, 68, 0.25);
    border-color: #f87171;
    box-shadow: 0 0 20px rgba(239, 68, 68, 0.3);
  }

  .vote-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
    transform: none;
  }

  .vote-icon {
    font-size: 1.5rem;
    font-weight: bold;
  }

  .vote-text {
    font-size: 0.875rem;
  }

  .results {
    display: flex;
    flex-direction: column;
    gap: 1rem;
    margin-top: auto;
  }

  .result-item {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .result-item.user-voted {
    position: relative;
  }

  .result-item.user-voted::before {
    content: "";
    position: absolute;
    left: -1rem;
    top: 0;
    bottom: 0;
    width: 3px;
    background: linear-gradient(180deg, #3b82f6, #8b5cf6);
    border-radius: 9999px;
    box-shadow: 0 0 8px rgba(59, 130, 246, 0.6);
  }

  .result-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 0.875rem;
  }

  .option-label {
    font-weight: 600;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .vote-indicator {
    color: #3b82f6;
    font-size: 0.5rem;
    animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
  }

  @keyframes pulse {
    0%,
    100% {
      opacity: 1;
    }
    50% {
      opacity: 0.5;
    }
  }

  .yes-label {
    color: #10b981;
  }

  .no-label {
    color: #ef4444;
  }

  .vote-count {
    color: #94a3b8;
    font-weight: 500;
    font-variant-numeric: tabular-nums;
  }

  .progress-bar {
    height: 0.5rem;
    background: #1e293b;
    border-radius: 9999px;
    overflow: hidden;
    border: 1px solid #334155;
  }

  .progress {
    height: 100%;
    transition: width 0.4s cubic-bezier(0.4, 0, 0.2, 1);
    border-radius: 9999px;
  }

  .yes-progress {
    background: linear-gradient(90deg, #10b981, #34d399);
    box-shadow: 0 0 10px rgba(16, 185, 129, 0.5);
  }

  .no-progress {
    background: linear-gradient(90deg, #ef4444, #f87171);
    box-shadow: 0 0 10px rgba(239, 68, 68, 0.5);
  }

  .error {
    background: rgba(239, 68, 68, 0.15);
    border: 1px solid #ef4444;
    border-radius: 0.5rem;
    padding: 0.75rem;
    color: #fca5a5;
    font-size: 0.875rem;
  }

  .card-footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem 1.5rem;
    background: rgba(15, 23, 42, 0.5);
    border-top: 1px solid #334155;
    gap: 0.75rem;
  }

  .tag {
    padding: 0.25rem 0.625rem;
    border-radius: 0.375rem;
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .tag.category {
    background: rgba(148, 163, 184, 0.1);
    color: #cbd5e1;
    border: 1px solid #475569;
  }

  .time-badge {
    background: rgba(59, 130, 246, 0.2);
    color: #60a5fa;
    border: 1px solid #3b82f6;
    padding: 0.25rem 0.625rem;
    border-radius: 0.375rem;
    font-size: 0.75rem;
    font-weight: 600;
    font-variant-numeric: tabular-nums;
    white-space: nowrap;
  }

  .closed-badge {
    background: rgba(100, 116, 139, 0.2);
    color: #94a3b8;
    border: 1px solid #475569;
    padding: 0.25rem 0.625rem;
    border-radius: 0.375rem;
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    white-space: nowrap;
  }
</style>
