package main

import (
	"context"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"pollflow/poll-broker/internal/broadcaster"
	"pollflow/poll-broker/internal/config"
	"pollflow/poll-broker/internal/db"
	"pollflow/poll-broker/internal/logger"
	"pollflow/poll-broker/internal/poller"
	"pollflow/poll-broker/internal/processor"
	"pollflow/poll-broker/internal/redis"

	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func main() {
	// Initialize structured logging
	logger.Initialize()
	logger.Log.Info("Starting poll-broker service")

	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		logger.Log.WithError(err).Fatal("Failed to load configuration")
	}

	// Create main context
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Initialize database client
	dbClient, err := db.NewClient(ctx, cfg.DatabaseURL())
	if err != nil {
		logger.Log.WithError(err).Fatal("Failed to connect to database")
	}
	defer dbClient.Close()
	logger.Log.Info("Connected to PostgreSQL")

	// Initialize Redis client
	redisClient, err := redis.NewClient(ctx, cfg.RedisAddr())
	if err != nil {
		logger.Log.WithError(err).Fatal("Failed to connect to Redis")
	}
	defer redisClient.Close()
	logger.Log.Info("Connected to Redis")

	// Start Prometheus metrics server
	metricsServer := &http.Server{
		Addr:    ":9090",
		Handler: promhttp.Handler(),
	}
	go func() {
		logger.Log.Info("Metrics server listening on :9090")
		if err := metricsServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Log.WithError(err).Error("Metrics server error")
		}
	}()

	// Create components
	pollPoller := poller.New(dbClient, redisClient, 10*time.Second)
	voteProcessor := processor.New(dbClient, redisClient)
	resultsBroadcaster := broadcaster.New(dbClient, redisClient, 1*time.Second)

	// Start components in goroutines
	var wg sync.WaitGroup

	wg.Add(1)
	go func() {
		defer wg.Done()
		pollPoller.Start(ctx)
	}()

	wg.Add(1)
	go func() {
		defer wg.Done()
		voteProcessor.Start(ctx)
	}()

	wg.Add(1)
	go func() {
		defer wg.Done()
		resultsBroadcaster.Start(ctx)
	}()

	logger.Log.Info("All components started successfully")

	// Wait for interrupt signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	// Block until signal received
	sig := <-sigChan
	logger.Log.WithField("signal", sig.String()).Info("Received signal, initiating graceful shutdown")

	// Cancel context to stop all components
	cancel()

	// Stop components explicitly
	pollPoller.Stop()
	voteProcessor.Stop()
	resultsBroadcaster.Stop()

	// Wait for all goroutines to finish with timeout
	done := make(chan struct{})
	go func() {
		wg.Wait()
		close(done)
	}()

	select {
	case <-done:
		logger.Log.Info("All components stopped gracefully")
	case <-time.After(10 * time.Second):
		logger.Log.Warn("Shutdown timeout exceeded, forcing exit")
	}

	// Shutdown metrics server
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer shutdownCancel()
	if err := metricsServer.Shutdown(shutdownCtx); err != nil {
		logger.Log.WithError(err).Warn("Metrics server shutdown error")
	}

	logger.Log.Info("poll-broker service stopped")
}
