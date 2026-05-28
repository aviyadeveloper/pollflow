package broadcaster

import (
	"context"
	"fmt"
	"time"

	"pollflow/poll-broker/internal/db"
	"pollflow/poll-broker/internal/logger"
	"pollflow/poll-broker/internal/redis"
)

// Broadcaster publishes poll results to Redis pub/sub
type Broadcaster struct {
	db       *db.Client
	redis    *redis.Client
	interval time.Duration
	stopCh   chan struct{}
}

// New creates a new results broadcaster
func New(dbClient *db.Client, redisClient *redis.Client, interval time.Duration) *Broadcaster {
	return &Broadcaster{
		db:       dbClient,
		redis:    redisClient,
		interval: interval,
		stopCh:   make(chan struct{}),
	}
}

// Start begins broadcasting poll results
func (b *Broadcaster) Start(ctx context.Context) {
	ticker := time.NewTicker(b.interval)
	defer ticker.Stop()

	logger.Log.WithFields(logger.LogFields{
		"event":    "broadcaster_started",
		"interval": b.interval.String(),
	}).Info("Results broadcaster started")

	// Run immediately on start
	b.broadcastResults(ctx)

	for {
		select {
		case <-ticker.C:
			b.broadcastResults(ctx)
		case <-b.stopCh:
			logger.Log.WithField("event", "broadcaster_stopped").Info("Results broadcaster stopped")
			return
		case <-ctx.Done():
			logger.Log.WithField("event", "broadcaster_cancelled").Info("Results broadcaster context cancelled")
			return
		}
	}
}

// Stop signals the broadcaster to stop
func (b *Broadcaster) Stop() {
	close(b.stopCh)
}

// broadcastResults publishes current results for all active polls
func (b *Broadcaster) broadcastResults(ctx context.Context) {
	// Get all active polls
	polls, err := b.db.GetActivePolls(ctx)
	if err != nil {
		logger.Log.WithFields(logger.LogFields{
			"event": "get_active_polls_failed",
			"error": err.Error(),
		}).Error("Error getting active polls")
		return
	}

	if len(polls) == 0 {
		return
	}

	logger.Log.WithFields(logger.LogFields{
		"event":        "broadcast_results_start",
		"active_polls": len(polls),
	}).Info("Broadcasting results for active polls")

	for _, poll := range polls {
		if err := b.broadcastPollResults(ctx, poll.ID); err != nil {
			logger.Log.WithFields(logger.LogFields{
				"event":   "broadcast_poll_failed",
				"poll_id": poll.ID,
				"error":   err.Error(),
			}).Error("Failed to broadcast results for poll")
			continue
		}
	}
}

// broadcastPollResults publishes results for a single poll
func (b *Broadcaster) broadcastPollResults(ctx context.Context, pollID int) error {
	// Get current results from database
	results, err := b.db.GetPollResults(ctx, pollID)
	if err != nil {
		return fmt.Errorf("failed to get poll results: %w", err)
	}

	// Prepare payload for Redis pub/sub
	payload := redis.PollResultsPayload{
		PollID:       pollID,
		OptionACount: results.OptionACount,
		OptionBCount: results.OptionBCount,
		TotalVotes:   results.TotalVotes,
	}

	// Publish to Redis
	if err := b.redis.PublishResults(ctx, payload); err != nil {
		return fmt.Errorf("failed to publish results: %w", err)
	}

	logger.Log.WithFields(logger.LogFields{
		"event":          "broadcast_poll_success",
		"poll_id":        pollID,
		"option_a_count": results.OptionACount,
		"option_b_count": results.OptionBCount,
		"total_votes":    results.TotalVotes,
	}).Info("Broadcast results for poll")

	return nil
}
