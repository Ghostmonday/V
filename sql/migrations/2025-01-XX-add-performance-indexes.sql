-- ===============================================
-- Migration: Add Performance Indexes
-- Purpose: Add indexes on frequently queried columns for better query performance
-- Date: 2025-01-XX
-- ===============================================

BEGIN;

-- ===============================================
-- 1. UX Telemetry Indexes
-- ===============================================
-- Index on event_category for filtering by category
CREATE INDEX IF NOT EXISTS idx_ux_telemetry_category 
ON ux_telemetry(event_category);

-- Index on created_at for time-based queries (most recent first)
CREATE INDEX IF NOT EXISTS idx_ux_telemetry_created_at 
ON ux_telemetry(created_at DESC);

-- Composite index for user-specific category queries
CREATE INDEX IF NOT EXISTS idx_ux_telemetry_user_category 
ON ux_telemetry(user_id, event_category, created_at DESC) 
WHERE user_id IS NOT NULL;

-- Index on event_name for filtering by specific events
CREATE INDEX IF NOT EXISTS idx_ux_telemetry_event_name 
ON ux_telemetry(event_name);

-- ===============================================
-- 2. Messages Indexes (additional to existing)
-- ===============================================
-- Index on sender_id for user message queries
CREATE INDEX IF NOT EXISTS idx_messages_sender_id 
ON messages(sender_id) 
WHERE sender_id IS NOT NULL;

-- Composite index for room message queries with sender
CREATE INDEX IF NOT EXISTS idx_messages_room_sender_time 
ON messages(room_id, sender_id, created_at DESC);

-- ===============================================
-- 3. Presence Logs Indexes
-- ===============================================
-- Composite index for user presence queries
CREATE INDEX IF NOT EXISTS idx_presence_logs_user_created 
ON presence_logs(user_id, created_at DESC);

-- Composite index for room presence queries
CREATE INDEX IF NOT EXISTS idx_presence_logs_room_created 
ON presence_logs(room_id, created_at DESC) 
WHERE room_id IS NOT NULL;

-- Index on status for filtering by presence status
CREATE INDEX IF NOT EXISTS idx_presence_logs_status 
ON presence_logs(status);

-- ===============================================
-- 4. Rooms Indexes (additional to existing)
-- ===============================================
-- Index on created_at for time-based room queries
CREATE INDEX IF NOT EXISTS idx_rooms_created_at 
ON rooms(created_at DESC);

-- Composite index for public room queries
CREATE INDEX IF NOT EXISTS idx_rooms_public_created 
ON rooms(is_public, created_at DESC) 
WHERE is_public = true;

-- Index on created_by for user-created room queries
CREATE INDEX IF NOT EXISTS idx_rooms_created_by 
ON rooms(created_by) 
WHERE created_by IS NOT NULL;

COMMIT;

-- ===============================================
-- Verification Query
-- ===============================================
-- Run this to verify indexes were created:
-- SELECT 
--     schemaname,
--     tablename,
--     indexname
-- FROM pg_indexes
-- WHERE tablename IN ('ux_telemetry', 'messages', 'presence_logs', 'rooms')
--     AND indexname LIKE 'idx_%'
-- ORDER BY tablename, indexname;

