package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"pollflow/poll-broker/internal/broadcaster"
	"pollflow/poll-broker/internal/config"
	"pollflow/poll-broker/internal/db"
	"pollflow/poll-broker/internal/poller"
	"pollflow/poll-broker/internal/processor"
	"pollflow/poll-broker/internal/redis"
)

func main() {
	log.Println("Starting poll-broker service...")

	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Create main context
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Initialize database client
	dbClient, err := db.NewClient(ctx, cfg.DatabaseURL())
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer dbClient.Close()
	log.Println("Connected to PostgreSQL")

	// Initialize Redis client
	redisClient, err := redis.NewClient(ctx, cfg.RedisAddr())
	if err != nil {
		log.Fatalf("Failed to connect to Redis: %v", err)
	}
	defer redisClient.Close()
	log.Println("Connected to Redis")

	// Create components
	pollPoller := poller.New(dbClient, 10*time.Second)
	voteProcessor := processor.New(dbClient, redisClient)
	resultsBroadcaster := broadcaster.New(dbClient, redisClient, 3*time.Second)

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

	log.Println("All components started successfully")

	// Wait for interrupt signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	// Block until signal received
	sig := <-sigChan
	log.Printf("Received signal: %v. Initiating graceful shutdown...", sig)

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
		log.Println("All components stopped gracefully")
	case <-time.After(10 * time.Second):
		log.Println("Shutdown timeout exceeded, forcing exit")
	}

	log.Println("poll-broker service stopped")
}
