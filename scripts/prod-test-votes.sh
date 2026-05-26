#!/bin/bash

# Production vote testing script - submits test votes to EKS Redis
# Bypasses IP restrictions by injecting votes directly into Redis queue
# 
# Usage:
#   ./scripts/prod-test-votes.sh <pollId> <numVotes> [option]
#   
# Examples:
#   ./scripts/prod-test-votes.sh 1 10        # 10 random votes on poll 1
#   ./scripts/prod-test-votes.sh 2 5 a       # 5 votes for option A on poll 2
#   ./scripts/prod-test-votes.sh 3 3 b       # 3 votes for option B on poll 3
#
# Requirements:
#   - kubectl configured with access to the EKS cluster
#   - Redis pods running in the cluster

set -e

# Parse arguments
POLL_ID=$1
NUM_VOTES=$2
FIXED_OPTION=$3

# Validate arguments
if [ -z "$POLL_ID" ] || [ -z "$NUM_VOTES" ]; then
  echo "Usage: $0 <pollId> <numVotes> [option]"
  echo "Example: $0 1 10"
  echo "Example: $0 2 5 a"
  exit 1
fi

if ! [[ "$POLL_ID" =~ ^[0-9]+$ ]] || ! [[ "$NUM_VOTES" =~ ^[0-9]+$ ]]; then
  echo "Error: pollId and numVotes must be numbers"
  exit 1
fi

if [ -n "$FIXED_OPTION" ] && [ "$FIXED_OPTION" != "a" ] && [ "$FIXED_OPTION" != "b" ]; then
  echo "Error: option must be 'a' or 'b'"
  exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
  echo "Error: kubectl is not installed or not in PATH"
  exit 1
fi

# Find the Redis primary pod
REDIS_POD=$(kubectl get pods -l app=redis,component=primary -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$REDIS_POD" ]; then
  echo "Error: Could not find Redis primary pod in the cluster"
  echo "Make sure Redis is deployed and running"
  exit 1
fi

# Fetch poll title from database
echo "Fetching poll details..."
PGHOST=$(kubectl get configmap rds-config -o jsonpath='{.data.POSTGRES_HOST}')
PGPORT=$(kubectl get configmap rds-config -o jsonpath='{.data.POSTGRES_PORT}')
PGDATABASE=$(kubectl get configmap rds-config -o jsonpath='{.data.POSTGRES_DB}')
PGUSER=$(kubectl get secret rds-credentials -o jsonpath='{.data.username}' | base64 -d)
PGPASSWORD=$(kubectl get secret rds-credentials -o jsonpath='{.data.password}' | base64 -d)

POLL_TITLE=$(kubectl run poll-query-$RANDOM \
  --image=postgres:16-alpine \
  --restart=Never \
  --rm -i \
  --quiet \
  --env="PGHOST=$PGHOST" \
  --env="PGPORT=$PGPORT" \
  --env="PGDATABASE=$PGDATABASE" \
  --env="PGUSER=$PGUSER" \
  --env="PGPASSWORD=$PGPASSWORD" \
  --env="PGSSLMODE=require" \
  --command -- psql -t -c "SELECT title FROM polls WHERE id = $POLL_ID;" 2>/dev/null | xargs)

if [ -z "$POLL_TITLE" ]; then
  echo "⚠️  Warning: Could not find poll with ID $POLL_ID"
  echo ""
fi

echo ""
echo "🗳️  Simulating $NUM_VOTES vote(s) on Poll $POLL_ID"
if [ -n "$POLL_TITLE" ]; then
  echo "📋 Poll: \"$POLL_TITLE\""
fi
echo "🔧 Target: Production Redis ($REDIS_POD)"
echo ""

# Submit votes
for i in $(seq 1 $NUM_VOTES); do
  # Generate a fake IP address
  FAKE_IP="192.168.$((RANDOM % 256)).$((RANDOM % 256))"
  
  # Choose option: fixed or random
  if [ -n "$FIXED_OPTION" ]; then
    OPTION=$FIXED_OPTION
  else
    OPTION=$([ $((RANDOM % 2)) -eq 0 ] && echo "a" || echo "b")
  fi
  
  # Create vote JSON (matching the format expected by poll-broker)
  TIMESTAMP=$(date +%s)
  VOTE_JSON="{\"poll_id\":$POLL_ID,\"option\":\"$OPTION\",\"user_ip\":\"$FAKE_IP\",\"timestamp\":$TIMESTAMP}"
  
  # Push to Redis queue via kubectl exec
  kubectl exec -i "$REDIS_POD" -- redis-cli RPUSH votes:queue "$VOTE_JSON" > /dev/null
  
  echo "✓ Vote submitted: IP $FAKE_IP -> Poll $POLL_ID Option ${OPTION^^}"
  
  # Small delay between votes to simulate realistic behavior
  sleep 0.1
done

echo ""
echo "✅ Successfully submitted $NUM_VOTES vote(s) to production Redis queue"
echo "💡 The poll-broker will process them and broadcast results via SSE"
echo ""
echo "📊 To view queue status:"
echo "   kubectl exec $REDIS_POD -- redis-cli LLEN votes:queue"
echo ""
