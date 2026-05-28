package poller

import (
	"context"
	"fmt"
	"log"
	"time"

	"pollflow/poll-broker/internal/db"
	"pollflow/poll-broker/internal/redis"
)

// Poller manages poll lifecycle state transitions
type Poller struct {
	db       *db.Client
	redis    *redis.Client
	interval time.Duration
	stopCh   chan struct{}
}

// New creates a new poll lifecycle manager
func New(dbClient *db.Client, redisClient *redis.Client, interval time.Duration) *Poller {
	return &Poller{
		db:       dbClient,
		redis:    redisClient,
		interval: interval,
		stopCh:   make(chan struct{}),
	}
}

// Start begins the poll lifecycle management loop
func (p *Poller) Start(ctx context.Context) {
	ticker := time.NewTicker(p.interval)
	defer ticker.Stop()

	log.Printf("Poll lifecycle manager started (interval: %v)", p.interval)

	// Run immediately on start
	p.checkPollLifecycle(ctx)

	for {
		select {
		case <-ticker.C:
			p.checkPollLifecycle(ctx)
		case <-p.stopCh:
			log.Println("Poll lifecycle manager stopped")
			return
		case <-ctx.Done():
			log.Println("Poll lifecycle manager context cancelled")
			return
		}
	}
}

// Stop signals the poller to stop
func (p *Poller) Stop() {
	close(p.stopCh)
}

// checkPollLifecycle checks for polls that need status updates
func (p *Poller) checkPollLifecycle(ctx context.Context) {
	// Activate pending polls
	if err := p.activatePolls(ctx); err != nil {
		log.Printf("Error activating polls: %v", err)
	}

	// Close active polls
	if err := p.closePolls(ctx); err != nil {
		log.Printf("Error closing polls: %v", err)
	}
}

// activatePolls finds and activates pending polls that have reached their start time
func (p *Poller) activatePolls(ctx context.Context) error {
	polls, err := p.db.GetPollsToActivate(ctx)
	if err != nil {
		return fmt.Errorf("failed to get polls to activate: %w", err)
	}

	if len(polls) == 0 {
		return nil
	}

	log.Printf("Activating %d poll(s)", len(polls))

	for _, poll := range polls {
		if err := p.db.UpdatePollStatus(ctx, poll.ID, "active"); err != nil {
			log.Printf("Failed to activate poll %d: %v", poll.ID, err)
			continue
		}
		log.Printf(" - - Activated poll %d: %s", poll.ID, poll.Title)

		// Publish lifecycle event
		if err := p.redis.PublishLifecycleEvent(ctx, poll.ID, redis.EventPollActivated); err != nil {
			log.Printf("Failed to publish activation event for poll %d: %v", poll.ID, err)
			// Don't fail the activation if pub/sub fails
		}
	}

	return nil
}

// closePolls finds and closes active polls that have reached their end time
func (p *Poller) closePolls(ctx context.Context) error {
	polls, err := p.db.GetPollsToClose(ctx)
	if err != nil {
		return fmt.Errorf("failed to get polls to close: %w", err)
	}

	if len(polls) == 0 {
		return nil
	}

	log.Printf("Closing %d poll(s)", len(polls))

	for _, poll := range polls {
		if err := p.db.UpdatePollStatus(ctx, poll.ID, "closed"); err != nil {
			log.Printf("Failed to close poll %d: %v", poll.ID, err)
			continue
		}
		log.Printf(" - - Closed poll %d: %s", poll.ID, poll.Title)

		// Publish lifecycle event
		if err := p.redis.PublishLifecycleEvent(ctx, poll.ID, redis.EventPollClosed); err != nil {
			log.Printf("Failed to publish closure event for poll %d: %v", poll.ID, err)
			// Don't fail the closure if pub/sub fails
		}
	}

	return nil
}
