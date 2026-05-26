package redis

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

// Client wraps a Redis client for queue and pub/sub operations
type Client struct {
	client *redis.Client
}

// VotePayload represents a vote in the Redis queue
type VotePayload struct {
	PollID    int    `json:"poll_id"`
	UserIP    string `json:"user_ip"`
	Option    string `json:"option"`
	Timestamp int64  `json:"timestamp"`
}

// PollResultsPayload represents poll results for pub/sub
type PollResultsPayload struct {
	PollID       int `json:"poll_id"`
	OptionACount int `json:"option_a_count"`
	OptionBCount int `json:"option_b_count"`
	TotalVotes   int `json:"total_votes"`
}

const (
	VotesQueueKey  = "votes:queue"
	ResultsChannel = "poll:results:%d" // Format with poll ID
)

// NewClient creates a new Redis client
func NewClient(ctx context.Context, addr string) (*Client, error) {
	rdb := redis.NewClient(&redis.Options{
		Addr:         addr,
		Password:     "", // No password for local development
		DB:           0,  // Default DB
		DialTimeout:  5 * time.Second,
		ReadTimeout:  3 * time.Second,
		WriteTimeout: 3 * time.Second,
		PoolSize:     10,
		MinIdleConns: 2,
	})

	// Test connection
	if err := rdb.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("failed to ping Redis: %w", err)
	}

	return &Client{client: rdb}, nil
}

// Close closes the Redis connection
func (c *Client) Close() error {
	return c.client.Close()
}

// PopVote pops a vote from the Redis queue (LPOP)
// Returns nil if queue is empty
func (c *Client) PopVote(ctx context.Context) (*VotePayload, error) {
	result, err := c.client.LPop(ctx, VotesQueueKey).Result()
	if err != nil {
		if err == redis.Nil {
			// Queue is empty
			return nil, nil
		}
		return nil, fmt.Errorf("failed to pop vote from queue: %w", err)
	}

	var vote VotePayload
	if err := json.Unmarshal([]byte(result), &vote); err != nil {
		return nil, fmt.Errorf("failed to unmarshal vote: %w", err)
	}

	return &vote, nil
}

// PublishResults publishes poll results to a Redis pub/sub channel
func (c *Client) PublishResults(ctx context.Context, results PollResultsPayload) error {
	data, err := json.Marshal(results)
	if err != nil {
		return fmt.Errorf("failed to marshal results: %w", err)
	}

	channel := fmt.Sprintf(ResultsChannel, results.PollID)
	if err := c.client.Publish(ctx, channel, data).Err(); err != nil {
		return fmt.Errorf("failed to publish results: %w", err)
	}

	return nil
}

// GetQueueLength returns the number of votes waiting in the queue
func (c *Client) GetQueueLength(ctx context.Context) (int64, error) {
	length, err := c.client.LLen(ctx, VotesQueueKey).Result()
	if err != nil {
		return 0, fmt.Errorf("failed to get queue length: %w", err)
	}
	return length, nil
}
