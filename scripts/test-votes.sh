#!/bin/bash

# Test script to simulate multiple users voting on polls
# This bypasses IP restrictions by injecting votes directly into Redis queue
# 
# Usage:
#   ./scripts/test-votes.sh <pollId> <numVotes> [option]
#   
# Examples:
#   ./scripts/test-votes.sh 1 10        # 10 random votes on poll 1
#   ./scripts/test-votes.sh 2 5 a       # 5 votes for option A on poll 2
#   ./scripts/test-votes.sh 3 3 b       # 3 votes for option B on poll 3

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

echo ""
echo "🗳️  Simulating $NUM_VOTES vote(s) on Poll $POLL_ID..."
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
  
  # Create vote JSON
  TIMESTAMP=$(date +%s)
  VOTE_JSON="{\"poll_id\":$POLL_ID,\"option\":\"$OPTION\",\"user_ip\":\"$FAKE_IP\",\"timestamp\":$TIMESTAMP}"
  
  # Push to Redis queue via docker
  docker exec pollflow-redis redis-cli RPUSH votes:queue "$VOTE_JSON" > /dev/null
  
  echo "✓ Vote submitted: IP $FAKE_IP -> Poll $POLL_ID Option ${OPTION^^}"
  
  # Small delay between votes
  sleep 0.1
done

echo ""
echo "✅ Successfully submitted $NUM_VOTES vote(s) to Redis queue"
echo "💡 The poll-broker will process them and broadcast results via SSE"
echo ""
