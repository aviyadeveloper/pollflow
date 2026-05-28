package poller

import (
	"context"
	"fmt"
	"time"

	"pollflow/poll-broker/internal/db"
	"pollflow/poll-broker/internal/logger"
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

	logger.WithEvent("poller_started").WithField("interval", p.interval.String()).Info("Poll lifecycle manager started")

	// Run immediately on start
	p.checkPollLifecycle(ctx)

	for {
		select {
		case <-ticker.C:
			p.checkPollLifecycle(ctx)
		case <-p.stopCh:
			logger.WithEvent("poller_stopped").Info("Poll lifecycle manager stopped")
			return
		case <-ctx.Done():
			logger.WithEvent("poller_cancelled").Info("Poll lifecycle manager context cancelled")
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
		logger.WithEvent("poll_activation_error").WithError(err).Error("Error activating polls")
	}

	// Close active polls
	if err := p.closePolls(ctx); err != nil {
		logger.WithEvent("poll_closure_error").WithError(err).Error("Error closing polls")
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

	logger.WithFields(logger.LogFields{
		"event": "activating_polls",
		"count": len(polls),
	}).Info("Activating polls")

	for _, poll := range polls {
		if err := p.db.UpdatePollStatus(ctx, poll.ID, "active"); err != nil {
			logger.WithFields(logger.LogFields{
				"poll_id": poll.ID,
				"event":   "poll_activation_failed",
				"error":   err,
			}).Error("Failed to activate poll")
			continue
		}
		logger.WithFields(logger.LogFields{
			"poll_id": poll.ID,
			"event":   "poll_activated",
			"title":   poll.Title,
		}).Info("Poll activated")

		// Publish lifecycle event
		if err := p.redis.PublishLifecycleEvent(ctx, poll.ID, redis.EventPollActivated); err != nil {
			logger.WithFields(logger.LogFields{
				"poll_id": poll.ID,
				"event":   "lifecycle_publish_failed",
				"error":   err,
			}).Warn("Failed to publish activation event")
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

	logger.WithFields(logger.LogFields{
		"event": "closing_polls",
		"count": len(polls),
	}).Info("Closing polls")

	for _, poll := range polls {
		if err := p.db.UpdatePollStatus(ctx, poll.ID, "closed"); err != nil {
			logger.WithFields(logger.LogFields{
				"poll_id": poll.ID,
				"event":   "poll_closure_failed",
				"error":   err,
			}).Error("Failed to close poll")
			continue
		}
		logger.WithFields(logger.LogFields{
			"poll_id": poll.ID,
			"event":   "poll_closed",
			"title":   poll.Title,
		}).Info("Poll closed")

		// Publish lifecycle event
		if err := p.redis.PublishLifecycleEvent(ctx, poll.ID, redis.EventPollClosed); err != nil {
			logger.WithFields(logger.LogFields{
				"poll_id": poll.ID,
				"event":   "lifecycle_publish_failed",
				"error":   err,
			}).Warn("Failed to publish closure event")
			// Don't fail the closure if pub/sub fails
		}
	}

	return nil
}
