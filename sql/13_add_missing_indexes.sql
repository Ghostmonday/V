-- ===============================================
-- FILE: 13_add_missing_indexes.sql
-- PURPOSE: Add missing critical indexes for optimal performance
-- DEPENDENCIES: 01_sinapse_schema.sql
-- USAGE: Run in Supabase SQL Editor
-- ===============================================

BEGIN;

-- ===============================================
-- MESSAGE RECEIPTS INDEXES
-- ===============================================

-- Composite index for receipt lookups (message_id + user_id)
CREATE INDEX IF NOT EXISTS idx_message_receipts_message_user 
ON message_receipts (message_id, user_id);

-- Index for user's unread messages (optimizes unread count queries)
CREATE INDEX IF NOT EXISTS idx_message_receipts_user_unread 
ON message_receipts (user_id, read_at) 
WHERE read_at IS NULL;

-- Index for read receipts by message (optimizes read status queries)
CREATE INDEX IF NOT EXISTS idx_message_receipts_message_read 
ON message_receipts (message_id, read_at) 
WHERE read_at IS NOT NULL;

-- ===============================================
-- ROOMS INDEXES
-- ===============================================

-- Explicit index on slug (helps with JOINs and lookups)
-- Note: UNIQUE constraint already creates index, but explicit helps query planner
CREATE INDEX IF NOT EXISTS idx_rooms_slug_lookup 
ON rooms (slug);

-- Index for user's created rooms
CREATE INDEX IF NOT EXISTS idx_rooms_created_by 
ON rooms (created_by) 
WHERE created_by IS NOT NULL;

-- Index for public room discovery
CREATE INDEX IF NOT EXISTS idx_rooms_public_recent 
ON rooms (is_public, created_at DESC) 
WHERE is_public = true;

-- ===============================================
-- RETENTION SCHEDULE INDEXES
-- ===============================================

-- Index for pending retention jobs (optimizes job queue queries)
CREATE INDEX IF NOT EXISTS idx_retention_schedule_pending 
ON retention_schedule (status, scheduled_for) 
WHERE status = 'pending';

-- Index for resource lookups (optimizes legal hold checks)
CREATE INDEX IF NOT EXISTS idx_retention_schedule_resource 
ON retention_schedule (resource_type, resource_id);

-- Index for on_hold status (optimizes hold release queries)
CREATE INDEX IF NOT EXISTS idx_retention_schedule_on_hold 
ON retention_schedule (on_hold, scheduled_for) 
WHERE on_hold = true;

-- ===============================================
-- LEGAL HOLDS INDEXES
-- ===============================================

-- Index for active legal holds (optimizes retention checks)
CREATE INDEX IF NOT EXISTS idx_legal_holds_active 
ON legal_holds (resource_type, resource_id, hold_until) 
WHERE hold_until > NOW();

-- Index for resource lookups
CREATE INDEX IF NOT EXISTS idx_legal_holds_resource 
ON legal_holds (resource_type, resource_id);

-- ===============================================
-- MESSAGES CONTENT SEARCH INDEXES
-- ===============================================

-- GIN index on content_preview for faster full-text search
-- Note: Materialized view has index, but direct table index helps with updates
CREATE INDEX IF NOT EXISTS idx_messages_content_preview_gin 
ON messages USING gin (to_tsvector('english', content_preview)) 
WHERE content_preview IS NOT NULL;

-- ===============================================
-- THREADS INDEXES
-- ===============================================

-- Index for room threads (optimizes room thread listing)
CREATE INDEX IF NOT EXISTS idx_threads_room_updated 
ON threads (room_id, updated_at DESC) 
WHERE is_archived = false;

-- ===============================================
-- METRICS INDEXES
-- ===============================================

-- Composite index for time-series queries (if not already exists)
-- Note: Check if idx_metrics_type_timestamp already exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE indexname = 'idx_metrics_type_timestamp'
  ) THEN
    CREATE INDEX idx_metrics_type_timestamp 
    ON metrics (type, timestamp DESC);
  END IF;
END $$;

-- ===============================================
-- PRESENCE LOGS INDEXES
-- ===============================================

-- Index for recent presence by user (optimizes presence queries)
CREATE INDEX IF NOT EXISTS idx_presence_logs_user_recent 
ON presence_logs (user_id, created_at DESC);

-- Index for room presence (optimizes room member presence)
CREATE INDEX IF NOT EXISTS idx_presence_logs_room_recent 
ON presence_logs (room_id, created_at DESC) 
WHERE room_id IS NOT NULL;

COMMIT;

-- ===============================================
-- VERIFY INDEXES CREATED
-- ===============================================

SELECT 
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE indexname LIKE 'idx_%'
  AND indexname IN (
    'idx_message_receipts_message_user',
    'idx_message_receipts_user_unread',
    'idx_message_receipts_message_read',
    'idx_rooms_slug_lookup',
    'idx_rooms_created_by',
    'idx_rooms_public_recent',
    'idx_retention_schedule_pending',
    'idx_retention_schedule_resource',
    'idx_retention_schedule_on_hold',
    'idx_legal_holds_active',
    'idx_legal_holds_resource',
    'idx_messages_content_preview_gin',
    'idx_threads_room_updated',
    'idx_metrics_type_timestamp',
    'idx_presence_logs_user_recent',
    'idx_presence_logs_room_recent'
  )
ORDER BY tablename, indexname;

