package broadcaster

import (
	"context"
	"fmt"
	"log"
	"time"

	"pollflow/poll-broker/internal/db"
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

	log.Printf("Results broadcaster started (interval: %v)", b.interval)

	// Run immediately on start
	b.broadcastResults(ctx)

	for {
		select {
		case <-ticker.C:
			b.broadcastResults(ctx)
		case <-b.stopCh:
			log.Println("Results broadcaster stopped")
			return
		case <-ctx.Done():
			log.Println("Results broadcaster context cancelled")
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
		log.Printf("Error getting active polls: %v", err)
		return
	}

	if len(polls) == 0 {
		return
	}

	log.Printf("Broadcasting results for %d active poll(s)", len(polls))

	for _, poll := range polls {
		if err := b.broadcastPollResults(ctx, poll.ID); err != nil {
			log.Printf("Failed to broadcast results for poll %d: %v", poll.ID, err)
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

	log.Printf("Broadcast results for poll %d: A=%d, B=%d, Total=%d",
		pollID, results.OptionACount, results.OptionBCount, results.TotalVotes)

	return nil
}
