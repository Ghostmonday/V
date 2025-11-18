-- ===============================================
-- Migration: Optimization Indexes and Ephemeral Messages
-- Purpose: Add message expiration support and verify/apply missing performance indexes
-- Date: 2025-11-18
-- ===============================================

BEGIN;

-- ===============================================
-- 1. EPHEMERAL MESSAGES (Phase 2.1)
-- ===============================================

-- Add expires_at column to messages table for TTL-based auto-deletion
ALTER TABLE messages 
ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

-- Create index on expires_at for efficient cleanup queries
CREATE INDEX IF NOT EXISTS idx_messages_expires_at 
ON messages(expires_at) 
WHERE expires_at IS NOT NULL;

-- ===============================================
-- 2. PERFORMANCE INDEXES (Phase 3.1)
-- ===============================================

-- Verify and create messages(room_id, created_at DESC) index if missing
-- This is critical for message retrieval queries
CREATE INDEX IF NOT EXISTS idx_messages_room_created_at_desc 
ON messages(room_id, created_at DESC);

-- Index for room listing queries (rooms by owner, ordered by creation time)
CREATE INDEX IF NOT EXISTS idx_rooms_owner_created_at_desc 
ON rooms(created_by, created_at DESC) 
WHERE created_by IS NOT NULL;

-- Index for user lookup by email (if email is stored in metadata JSONB)
-- Note: This assumes email might be in metadata JSONB field
CREATE INDEX IF NOT EXISTS idx_users_metadata_email_gin 
ON users USING GIN(metadata) 
WHERE metadata ? 'email';

-- Composite index for user lookup (id, email in metadata)
-- This supports the user lookup optimization mentioned in the plan
CREATE INDEX IF NOT EXISTS idx_users_id_metadata_email 
ON users(id) 
WHERE metadata ? 'email';

-- ===============================================
-- 3. ADDITIONAL OPTIMIZATION INDEXES
-- ===============================================

-- Index for messages by sender (useful for user message history)
CREATE INDEX IF NOT EXISTS idx_messages_sender_created_at_desc 
ON messages(sender_id, created_at DESC) 
WHERE sender_id IS NOT NULL;

-- Index for expired messages cleanup (composite with created_at for efficient queries)
CREATE INDEX IF NOT EXISTS idx_messages_expires_created 
ON messages(expires_at, created_at) 
WHERE expires_at IS NOT NULL;

COMMIT;

-- ===============================================
-- NOTES:
-- ===============================================
-- 1. The expires_at column allows messages to have a TTL (time-to-live)
--    Set expires_at = NOW() + INTERVAL 'X seconds' when creating ephemeral messages
-- 
-- 2. Cleanup job should run periodically to soft-delete expired messages:
--    UPDATE messages SET is_deleted = true WHERE expires_at < NOW() AND expires_at IS NOT NULL;
--    (Assuming is_deleted column exists, or use actual DELETE if hard deletion is desired)
--
-- 3. Indexes are created with IF NOT EXISTS to be idempotent
--    This allows the migration to be run multiple times safely

