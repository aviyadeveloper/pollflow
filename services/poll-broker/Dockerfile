# Build stage
FROM golang:1.26-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git

# Set working directory
WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -o poll-broker \
    ./cmd/poll-broker

# Production stage
FROM alpine:3.19

# Install ca-certificates for HTTPS connections
RUN apk --no-cache add ca-certificates tzdata

# Create non-root user
RUN addgroup -g 1000 pollbroker && \
    adduser -D -u 1000 -G pollbroker pollbroker

# Set working directory
WORKDIR /app

# Copy binary from builder
COPY --from=builder /build/poll-broker .

# Change ownership
RUN chown -R pollbroker:pollbroker /app

# Switch to non-root user
USER pollbroker

# Expose any ports if needed (none for this service)

# Run the binary
CMD ["/app/poll-broker"]
