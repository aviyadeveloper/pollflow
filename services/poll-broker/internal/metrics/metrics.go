package metrics
package metrics

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	// Poll metrics
	ActivePolls = promauto.NewGauge(prometheus.GaugeOpts{
		Name: "poll_broker_active_polls_total",
		Help: "Number of currently active polls",
	})

	PollsPolled = promauto.NewCounter(prometheus.CounterOpts{
		Name: "poll_broker_polls_polled_total",
		Help: "Total number of poll status checks performed",
	})

	// Vote processing metrics
	VotesProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "poll_broker_votes_processed_total",
		Help: "Total number of votes processed from queue",
	})

	VoteProcessingErrors = promauto.NewCounter(prometheus.CounterOpts{
		Name: "poll_broker_vote_processing_errors_total",
		Help: "Total number of vote processing errors",
	})

	VoteProcessingDuration = promauto.NewHistogram(prometheus.HistogramOpts{
		Name:    "poll_broker_vote_processing_duration_seconds",
		Help:    "Duration of vote processing operations",
		Buckets: prometheus.DefBuckets,
	})

	// Results broadcasting metrics
	ResultsBroadcasts = promauto.NewCounter(prometheus.CounterOpts{
		Name: "poll_broker_results_broadcasts_total",
		Help: "Total number of results broadcast operations",
	})

	ResultsBroadcastErrors = promauto.NewCounter(prometheus.CounterOpts{
		Name: "poll_broker_results_broadcast_errors_total",
		Help: "Total number of results broadcast errors",
	})

	// Database metrics
	DatabaseQueryDuration = promauto.NewHistogram(prometheus.HistogramOpts{
		Name:    "poll_broker_database_query_duration_seconds",
		Help:    "Duration of database query operations",
		Buckets: prometheus.DefBuckets,
	})

	DatabaseErrors = promauto.NewCounter(prometheus.CounterOpts{
		Name: "poll_broker_database_errors_total",
		Help: "Total number of database errors",
	})

	// Redis metrics
	RedisOperationDuration = promauto.NewHistogram(prometheus.HistogramOpts{
		Name:    "poll_broker_redis_operation_duration_seconds",
		Help:    "Duration of Redis operations",
		Buckets: prometheus.DefBuckets,
	})

	RedisErrors = promauto.NewCounter(prometheus.CounterOpts{
		Name: "poll_broker_redis_errors_total",
		Help: "Total number of Redis errors",
	})
)
