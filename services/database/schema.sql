-- PollFlow Database Schema
-- PostgreSQL 16+
--
-- This schema defines the core tables for the multi-poll voting system.

-- =============================================================================
-- POLLS TABLE
-- =============================================================================
-- Stores poll metadata including title, options, timing, and lifecycle status

CREATE TABLE polls (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    option_a TEXT NOT NULL,
    option_b TEXT NOT NULL,
    poll_category VARCHAR(50) NOT NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    -- Ensure valid status values
    CONSTRAINT polls_status_check CHECK (status IN ('pending', 'active', 'closed')),
    
    -- Ensure end time is after start time
    CONSTRAINT polls_time_check CHECK (end_time > start_time)
);

-- =============================================================================
-- VOTES TABLE
-- =============================================================================
-- Stores individual votes with IP-based user identification
-- One vote per IP per poll (enforced by unique constraint)

CREATE TABLE votes (
    id SERIAL PRIMARY KEY,
    poll_id INTEGER NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
    user_ip VARCHAR(45) NOT NULL,
    option VARCHAR(10) NOT NULL,
    voted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    -- Ensure valid option values
    CONSTRAINT votes_option_check CHECK (option IN ('a', 'b')),
    
    -- Prevent duplicate votes from same IP on same poll
    CONSTRAINT votes_unique_user_poll UNIQUE (poll_id, user_ip)
);

-- =============================================================================
-- INDEXES
-- =============================================================================
-- Performance optimizations for common query patterns

-- Index for poll lifecycle queries (finding polls to activate/close)
CREATE INDEX idx_polls_status_time ON polls(status, start_time, end_time);

-- Index for filtering polls by category
CREATE INDEX idx_polls_category ON polls(poll_category);

-- Index for aggregating votes per poll (counting results)
CREATE INDEX idx_votes_poll_id ON votes(poll_id);

