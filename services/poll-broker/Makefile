.PHONY: test test-verbose test-coverage build run

# Run all tests
test:
	@echo "Running tests..."
	go test ./... -v

# Run tests with verbose output
test-verbose:
	@echo "Running tests (verbose)..."
	go test ./... -v -count=1

# Run tests with coverage
test-coverage:
	@echo "Running tests with coverage..."
	go test ./... -v -cover -coverprofile=coverage.out
	@echo ""
	@echo "Coverage summary:"
	@go tool cover -func=coverage.out | tail -1

# Build the application
build:
	@echo "Building poll-broker..."
	go build -o bin/poll-broker ./cmd/poll-broker

# Run the application (local development)
run:
	@echo "Running poll-broker..."
	go run ./cmd/poll-broker
