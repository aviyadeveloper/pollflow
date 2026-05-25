package processor

import (
	"context"
	"fmt"
	"log"
	"strings"
	"time"

	"pollflow/poll-broker/internal/db"
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
	log.Println("Vote processor started")

	for {
		select {
		case <-p.stopCh:
			log.Println("Vote processor stopped")
			return
		case <-ctx.Done():
			log.Println("Vote processor context cancelled")
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
		log.Printf("Error popping vote from queue: %v", err)
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
		log.Printf("Invalid vote data: %v - Vote: %+v", err, vote)
		return // Drop invalid vote
	}

	// Insert vote into PostgreSQL
	if err := p.db.InsertVote(ctx, vote.PollID, vote.UserIP, vote.Option); err != nil {
		// Check if it's a duplicate vote error (UNIQUE constraint)
		if strings.Contains(err.Error(), "duplicate") || strings.Contains(err.Error(), "unique") {
			log.Printf("Duplicate vote ignored: poll_id=%d, user_ip=%s", vote.PollID, vote.UserIP)
		} else {
			log.Printf("Failed to insert vote: %v - Vote: %+v", err, vote)
		}
		return
	}

	log.Printf("Vote recorded: poll_id=%d, user_ip=%s, option=%s", vote.PollID, vote.UserIP, vote.Option)
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
