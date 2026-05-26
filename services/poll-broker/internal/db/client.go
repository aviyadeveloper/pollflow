package db

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Client wraps a PostgreSQL connection pool
type Client struct {
	pool *pgxpool.Pool
}

// Poll represents a poll record from the database
type Poll struct {
	ID          int
	Title       string
	Description *string
	OptionA     string
	OptionB     string
	Category    string
	StartTime   time.Time
	EndTime     time.Time
	Status      string
	CreatedAt   time.Time
}

// Vote represents a vote record from the database
type Vote struct {
	ID      int
	PollID  int
	UserIP  string
	Option  string
	VotedAt time.Time
}

// PollResults holds aggregated vote counts for a poll
type PollResults struct {
	PollID       int
	OptionACount int
	OptionBCount int
	TotalVotes   int
}

// NewClient creates a new database client with connection pooling
func NewClient(ctx context.Context, databaseURL string) (*Client, error) {
	config, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("failed to parse database URL: %w", err)
	}

	// Connection pool settings
	config.MaxConns = 10
	config.MinConns = 2
	config.MaxConnLifetime = time.Hour
	config.MaxConnIdleTime = 30 * time.Minute

	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		return nil, fmt.Errorf("failed to create connection pool: %w", err)
	}

	// Test connection
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	return &Client{pool: pool}, nil
}

// Close closes the database connection pool
func (c *Client) Close() {
	c.pool.Close()
}

// UpdatePollStatus updates the status of a poll
func (c *Client) UpdatePollStatus(ctx context.Context, pollID int, newStatus string) error {
	query := `UPDATE polls SET status = $1 WHERE id = $2`
	_, err := c.pool.Exec(ctx, query, newStatus, pollID)
	if err != nil {
		return fmt.Errorf("failed to update poll status: %w", err)
	}
	return nil
}

// GetPollsToActivate returns pending polls that should be activated
func (c *Client) GetPollsToActivate(ctx context.Context) ([]Poll, error) {
	query := `
		SELECT id, title, description, option_a, option_b, poll_category, 
		       start_time, end_time, status, created_at
		FROM polls
		WHERE status = 'pending' AND start_time <= NOW()
	`
	return c.queryPolls(ctx, query)
}

// GetPollsToClose returns active polls that should be closed
func (c *Client) GetPollsToClose(ctx context.Context) ([]Poll, error) {
	query := `
		SELECT id, title, description, option_a, option_b, poll_category,
		       start_time, end_time, status, created_at
		FROM polls
		WHERE status = 'active' AND end_time <= NOW()
	`
	return c.queryPolls(ctx, query)
}

// GetActivePolls returns all currently active polls
func (c *Client) GetActivePolls(ctx context.Context) ([]Poll, error) {
	query := `
		SELECT id, title, description, option_a, option_b, poll_category,
		       start_time, end_time, status, created_at
		FROM polls
		WHERE status = 'active'
	`
	return c.queryPolls(ctx, query)
}

// InsertVote inserts a vote into the database
// Returns error if vote already exists (duplicate constraint)
func (c *Client) InsertVote(ctx context.Context, pollID int, userIP, option string) error {
	query := `
		INSERT INTO votes (poll_id, user_ip, option)
		VALUES ($1, $2, $3)
	`
	_, err := c.pool.Exec(ctx, query, pollID, userIP, option)
	if err != nil {
		return fmt.Errorf("failed to insert vote: %w", err)
	}
	return nil
}

// GetPollResults returns aggregated vote counts for a poll
func (c *Client) GetPollResults(ctx context.Context, pollID int) (*PollResults, error) {
	query := `
		SELECT
			poll_id,
			COUNT(CASE WHEN option = 'a' THEN 1 END) as option_a_count,
			COUNT(CASE WHEN option = 'b' THEN 1 END) as option_b_count,
			COUNT(*) as total_votes
		FROM votes
		WHERE poll_id = $1
		GROUP BY poll_id
	`

	results := &PollResults{PollID: pollID}
	err := c.pool.QueryRow(ctx, query, pollID).Scan(
		&results.PollID,
		&results.OptionACount,
		&results.OptionBCount,
		&results.TotalVotes,
	)

	if err != nil {
		// If no votes exist yet, return zeros
		if err.Error() == "no rows in result set" {
			return results, nil
		}
		return nil, fmt.Errorf("failed to get poll results: %w", err)
	}

	return results, nil
}

// queryPolls is a helper function to execute poll queries
func (c *Client) queryPolls(ctx context.Context, query string, args ...interface{}) ([]Poll, error) {
	rows, err := c.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query polls: %w", err)
	}
	defer rows.Close()

	var polls []Poll
	for rows.Next() {
		var p Poll
		err := rows.Scan(
			&p.ID,
			&p.Title,
			&p.Description,
			&p.OptionA,
			&p.OptionB,
			&p.Category,
			&p.StartTime,
			&p.EndTime,
			&p.Status,
			&p.CreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan poll row: %w", err)
		}
		polls = append(polls, p)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating poll rows: %w", err)
	}

	return polls, nil
}
