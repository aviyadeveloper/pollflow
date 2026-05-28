package processor

import (
	"context"
	"fmt"
	"strings"
	"time"

	"pollflow/poll-broker/internal/db"
	"pollflow/poll-broker/internal/logger"
	"pollflow/poll-broker/internal/redis"
)

// Processor consumes votes from Redis queue and persists to PostgreSQL
type Processor struct {
	db     *db.Client
	redis  *redis.Client
	stopCh chan struct{}
}

// New creates a new vote processor
func New(dbClient *db.Client, redisClient *redis.Client) *Processor {
	return &Processor{
		db:     dbClient,
		redis:  redisClient,
		stopCh: make(chan struct{}),
	}
}

// Start begins consuming votes from the Redis queue
func (p *Processor) Start(ctx context.Context) {
	logger.WithEvent("processor_started").Info("Vote processor started")

	for {
		select {
		case <-p.stopCh:
			logger.WithEvent("processor_stopped").Info("Vote processor stopped")
			return
		case <-ctx.Done():
			logger.WithEvent("processor_cancelled").Info("Vote processor context cancelled")
			return
		default:
			p.processNextVote(ctx)
		}
	}
}

// Stop signals the processor to stop
func (p *Processor) Stop() {
	close(p.stopCh)
}

// processNextVote pops one vote from Redis and persists it to PostgreSQL
func (p *Processor) processNextVote(ctx context.Context) {
	vote, err := p.redis.PopVote(ctx)
	if err != nil {
		logger.WithEvent("vote_pop_error").WithError(err).Error("Error popping vote from queue")
		time.Sleep(1 * time.Second) // Back off on error
		return
	}

	// Queue is empty
	if vote == nil {
		time.Sleep(100 * time.Millisecond) // Brief pause when queue empty
		return
	}

	// Validate vote data
	if err := p.validateVote(vote); err != nil {
		logger.WithFields(logger.LogFields{
			"event":   "vote_validation_failed",
			"error":   err,
			"poll_id": vote.PollID,
			"user_ip": vote.UserIP,
			"option":  vote.Option,
		}).Warn("Invalid vote data")
		return // Drop invalid vote
	}

	// Insert vote into PostgreSQL
	if err := p.db.InsertVote(ctx, vote.PollID, vote.UserIP, vote.Option); err != nil {
		// Check if it's a duplicate vote error (UNIQUE constraint)
		if strings.Contains(err.Error(), "duplicate") || strings.Contains(err.Error(), "unique") {
			logger.WithFields(logger.LogFields{
				"poll_id": vote.PollID,
				"event":   "duplicate_vote",
				"user_ip": vote.UserIP,
			}).Info("Duplicate vote ignored")
		} else {
			logger.WithFields(logger.LogFields{
				"poll_id": vote.PollID,
				"event":   "vote_insert_failed",
				"error":   err,
				"user_ip": vote.UserIP,
				"option":  vote.Option,
			}).Error("Failed to insert vote")
		}
		return
	}

	logger.WithFields(logger.LogFields{
		"poll_id": vote.PollID,
		"event":   "vote_recorded",
		"user_ip": vote.UserIP,
		"option":  vote.Option,
	}).Info("Vote recorded")
}

// validateVote checks if vote data is valid
func (p *Processor) validateVote(vote *redis.VotePayload) error {
	if vote.PollID <= 0 {
		return fmt.Errorf("invalid poll_id: %d", vote.PollID)
	}

	if vote.UserIP == "" {
		return fmt.Errorf("user_ip is empty")
	}

	if vote.Option != "a" && vote.Option != "b" {
		return fmt.Errorf("invalid option: %s (must be 'a' or 'b')", vote.Option)
	}

	return nil
}
