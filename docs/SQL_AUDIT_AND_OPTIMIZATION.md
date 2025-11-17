-- ===============================================
-- COMPREHENSIVE SCHEMA SETUP
-- Ensures all tables and columns exist before creating indexes
-- ===============================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "vector"; -- For embeddings table

-- Create service schema for privileged operations
CREATE SCHEMA IF NOT EXISTS service;

-- Ensure all required tables exist
DO $$
BEGIN
  -- Create users table if missing
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users') THEN
    CREATE TABLE users (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      handle TEXT NOT NULL UNIQUE,
      display_name TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      is_verified BOOLEAN NOT NULL DEFAULT false,
      metadata JSONB DEFAULT '{}'::jsonb,
      policy_flags JSONB DEFAULT '{}'::jsonb,
      last_seen TIMESTAMPTZ,
      federation_id TEXT UNIQUE
    );
  END IF;

  -- Create rooms table if missing
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'rooms') THEN
    CREATE TABLE rooms (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      slug TEXT NOT NULL UNIQUE,
      title TEXT,
      created_by UUID REFERENCES users(id) ON DELETE SET NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      is_public BOOLEAN NOT NULL DEFAULT true,
      partition_month TEXT GENERATED ALWAYS AS (to_char(date_trunc('month', created_at AT TIME ZONE 'UTC'), 'YYYY_MM')) STORED,
      metadata JSONB DEFAULT '{}'::jsonb,
      fed_node_id TEXT,
      retention_hot_days INT,
      retention_cold_days INT
    );
  END IF;

  -- Create messages table if missing
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'messages') THEN
    CREATE TABLE messages (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
      sender_id UUID REFERENCES users(id) ON DELETE SET NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      payload_ref TEXT NOT NULL,
      content_preview TEXT,
      content_hash TEXT NOT NULL,
      audit_hash_chain TEXT NOT NULL,
      flags JSONB DEFAULT '{}'::jsonb,
      is_flagged BOOLEAN NOT NULL DEFAULT FALSE,
      is_exported BOOLEAN NOT NULL DEFAULT FALSE,
      partition_month TEXT NOT NULL GENERATED ALWAYS AS (to_char(date_trunc('month', created_at AT TIME ZONE 'UTC'), 'YYYY_MM')) STORED,
      fed_origin_hash TEXT,
      thread_id UUID
    );
  END IF;

  -- Create message_receipts table if missing
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'message_receipts') THEN
    CREATE TABLE message_receipts (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      delivered_at TIMESTAMPTZ,
      read_at TIMESTAMPTZ,
      UNIQUE(message_id, user_id)
    );
  END IF;

  -- Create retention_schedule table if missing
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'retention_schedule') THEN
    CREATE TABLE retention_schedule (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      resource_type TEXT NOT NULL,
      resource_id UUID NOT NULL,
      scheduled_for TIMESTAMPTZ NOT NULL,
      action TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      on_hold BOOLEAN NOT NULL DEFAULT false,
      hold_reason TEXT
    );
  END IF;

  -- Create legal_holds table if missing
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'legal_holds') THEN
    CREATE TABLE legal_holds (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      resource_type TEXT NOT NULL,
      resource_id UUID NOT NULL,
      hold_until TIMESTAMPTZ NOT NULL,
      reason TEXT NOT NULL,
      actor TEXT NOT NULL,
      created_at TIMESTAMPTZ DEFAULT now()
    );
  END IF;

  -- Create threads table if missing
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'threads') THEN
    CREATE TABLE threads (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      is_archived BOOLEAN NOT NULL DEFAULT false
    );
  END IF;

  -- Create metrics table if missing
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'metrics') THEN
    CREATE TABLE metrics (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      type TEXT NOT NULL,
      timestamp TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  END IF;

  -- Create presence_logs table if missing
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'presence_logs') THEN
    CREATE TABLE presence_logs (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID REFERENCES users(id) ON DELETE CASCADE,
      room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  END IF;

  -- Create audit_log table if missing
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'audit_log') THEN
    CREATE TABLE audit_log (
      id BIGSERIAL PRIMARY KEY,
      event_time TIMESTAMPTZ NOT NULL DEFAULT now(),
      event_type TEXT NOT NULL,
      room_id UUID,
      user_id UUID,
      message_id UUID,
      payload JSONB,
      actor TEXT,
      signature TEXT,
      hash TEXT NOT NULL,
      prev_hash TEXT,
      chain_hash TEXT NOT NULL,
      node_id TEXT NOT NULL DEFAULT 'local'
    );
  END IF;

  -- Create room_memberships table if missing
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'room_memberships') THEN
    CREATE TABLE room_memberships (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      role TEXT NOT NULL DEFAULT 'member',
      joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      strike_count INT NOT NULL DEFAULT 0,
      probation_until TIMESTAMPTZ,
      last_warning_at TIMESTAMPTZ,
      ban_reason JSONB DEFAULT '{}'::jsonb,
      UNIQUE(room_id, user_id)
    );
  END IF;

  -- Create logs_raw table if missing
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'logs_raw') THEN
    CREATE TABLE logs_raw (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      payload BYTEA NOT NULL,
      mime_type TEXT NOT NULL,
      length_bytes INT NOT NULL,
      checksum TEXT NOT NULL,
      processed BOOLEAN NOT NULL DEFAULT FALSE
    );
  END IF;

  -- Create logs_compressed table if missing
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'logs_compressed') THEN
    CREATE TABLE logs_compressed (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      room_id UUID NOT NULL,
      partition_month TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      codec TEXT NOT NULL,
      compressed_payload BYTEA NOT NULL,
      original_length INT NOT NULL,
      checksum TEXT NOT NULL,
      cold_storage_uri TEXT,
      lifecycle_state TEXT NOT NULL DEFAULT 'hot'
    );
  END IF;

  -- Create telemetry table if missing
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'telemetry') THEN
    CREATE TABLE telemetry (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      event_time TIMESTAMPTZ NOT NULL DEFAULT now(),
      event TEXT NOT NULL,
      room_id UUID,
      user_id UUID,
      risk NUMERIC,
      action TEXT,
      features JSONB,
      latency_ms INT,
      precision_recall JSONB DEFAULT '{}'::jsonb
    );
  END IF;

  -- Create edit_history table if missing
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'edit_history') THEN
    CREATE TABLE edit_history (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      message_id UUID REFERENCES messages(id) ON DELETE CASCADE,
      edited_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      content_preview TEXT
    );
  END IF;

  -- Create assistants table if missing
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'assistants') THEN
    CREATE TABLE assistants (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      owner_id UUID REFERENCES users(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  END IF;

  -- Create bots table if missing
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bots') THEN
    CREATE TABLE bots (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      created_by UUID REFERENCES users(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  END IF;

  -- Create bot_endpoints table if missing
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bot_endpoints') THEN
    CREATE TABLE bot_endpoints (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      bot_id UUID REFERENCES bots(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  END IF;

  -- Create subscriptions table if missing
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'subscriptions') THEN
    CREATE TABLE subscriptions (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID REFERENCES users(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  END IF;

  -- Create embeddings table if missing
  -- Note: Requires vector extension (enabled above)
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'embeddings') THEN
    CREATE TABLE embeddings (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      message_id UUID REFERENCES messages(id) ON DELETE CASCADE,
      vector vector(1536), -- Requires pgvector extension
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  END IF;

  -- Create healing_logs table if missing
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'healing_logs') THEN
    CREATE TABLE healing_logs (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
      room_id UUID,
      type TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  END IF;
END $$;

-- Ensure all required columns exist
DO $$
BEGIN
  -- rooms.created_by
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'rooms' AND column_name = 'created_by'
  ) THEN
    ALTER TABLE rooms ADD COLUMN created_by UUID REFERENCES users(id) ON DELETE SET NULL;
  END IF;

  -- rooms.is_public
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'rooms' AND column_name = 'is_public'
  ) THEN
    ALTER TABLE rooms ADD COLUMN is_public BOOLEAN NOT NULL DEFAULT true;
  END IF;

  -- rooms.created_at
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'rooms' AND column_name = 'created_at'
  ) THEN
    ALTER TABLE rooms ADD COLUMN created_at TIMESTAMPTZ NOT NULL DEFAULT now();
  END IF;

  -- messages.content_preview
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'messages' AND column_name = 'content_preview'
  ) THEN
    ALTER TABLE messages ADD COLUMN content_preview TEXT;
  END IF;

  -- messages.thread_id
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'messages' AND column_name = 'thread_id'
  ) THEN
    ALTER TABLE messages ADD COLUMN thread_id UUID;
  END IF;

  -- message_receipts.read_at
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'message_receipts' AND column_name = 'read_at'
  ) THEN
    ALTER TABLE message_receipts ADD COLUMN read_at TIMESTAMPTZ;
  END IF;

  -- retention_schedule.status
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'retention_schedule' AND column_name = 'status'
  ) THEN
    ALTER TABLE retention_schedule ADD COLUMN status TEXT NOT NULL DEFAULT 'pending';
  END IF;

  -- retention_schedule.scheduled_for
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'retention_schedule' AND column_name = 'scheduled_for'
  ) THEN
    ALTER TABLE retention_schedule ADD COLUMN scheduled_for TIMESTAMPTZ NOT NULL DEFAULT now();
  END IF;

  -- retention_schedule.on_hold
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'retention_schedule' AND column_name = 'on_hold'
  ) THEN
    ALTER TABLE retention_schedule ADD COLUMN on_hold BOOLEAN NOT NULL DEFAULT false;
  END IF;

  -- threads.updated_at
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'threads' AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE threads ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
  END IF;

  -- threads.is_archived
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'threads' AND column_name = 'is_archived'
  ) THEN
    ALTER TABLE threads ADD COLUMN is_archived BOOLEAN NOT NULL DEFAULT false;
  END IF;

  -- presence_logs.created_at
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'presence_logs' AND column_name = 'created_at'
  ) THEN
    ALTER TABLE presence_logs ADD COLUMN created_at TIMESTAMPTZ NOT NULL DEFAULT now();
  END IF;
END $$;

-- ===============================================
-- MISSING INDEXES
-- ===============================================

-- Missing: Composite index for receipt lookups
CREATE INDEX IF NOT EXISTS idx_message_receipts_message_user 
ON message_receipts (message_id, user_id);

-- Missing: Index for user's unread messages
CREATE INDEX IF NOT EXISTS idx_message_receipts_user_unread 
ON message_receipts (user_id, read_at) 
WHERE read_at IS NULL;


-- Missing: Index on slug (already unique, but explicit index helps)
-- Note: UNIQUE constraint creates index, but explicit index helps with JOINs
CREATE INDEX IF NOT EXISTS idx_rooms_slug_lookup 
ON rooms (slug);

-- Missing: Index for user's rooms
CREATE INDEX IF NOT EXISTS idx_rooms_created_by 
ON rooms (created_by) 
WHERE created_by IS NOT NULL;


-- Missing: Index for pending retention jobs
CREATE INDEX IF NOT EXISTS idx_retention_schedule_pending 
ON retention_schedule (status, scheduled_for) 
WHERE status = 'pending';

-- Missing: Index for resource lookups
CREATE INDEX IF NOT EXISTS idx_retention_schedule_resource 
ON retention_schedule (resource_type, resource_id);


-- Missing: Index for active legal holds
-- Note: Cannot use NOW() in index predicate (not IMMUTABLE), so index all holds
-- Query can still filter by hold_until > NOW() and index will help
CREATE INDEX IF NOT EXISTS idx_legal_holds_active 
ON legal_holds (resource_type, resource_id, hold_until);


-- Already covered by idx_message_receipts_user_unread above


-- Missing: Index for public room discovery
CREATE INDEX IF NOT EXISTS idx_rooms_public_recent 
ON rooms (is_public, created_at DESC) 
WHERE is_public = true;


-- Missing: GIN index on content_preview for faster text search
-- Note: Materialized view has index, but direct table index helps
CREATE INDEX IF NOT EXISTS idx_messages_content_preview_gin 
ON messages USING gin (to_tsvector('english', content_preview)) 
WHERE content_preview IS NOT NULL;

-- ===============================================
-- FILE: 13_add_missing_indexes.sql
-- PURPOSE: Add missing critical indexes for optimal performance
-- DEPENDENCIES: 01_sinapse_schema.sql
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
-- Note: Cannot use NOW() in index predicate (not IMMUTABLE), so index all holds
-- Query can still filter by hold_until > NOW() and index will help
CREATE INDEX IF NOT EXISTS idx_legal_holds_active 
ON legal_holds (resource_type, resource_id, hold_until);

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

-- Composite index for time-series queries
CREATE INDEX IF NOT EXISTS idx_metrics_type_timestamp_composite 
ON metrics (type, timestamp DESC);

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
    'idx_metrics_type_timestamp_composite',
    'idx_presence_logs_user_recent',
    'idx_presence_logs_room_recent'
  )
ORDER BY tablename, indexname;


-- ===============================================
-- FILE: 14_fix_schema_inconsistencies.sql
-- PURPOSE: Fix schema inconsistencies and function mismatches
-- DEPENDENCIES: 01_sinapse_schema.sql, sql/functions/batch_fetch.sql
-- ===============================================

BEGIN;

-- ===============================================
-- FIX BATCH FETCH FUNCTION
-- ===============================================

-- Update batch_fetch function to use correct column names
CREATE OR REPLACE FUNCTION get_room_messages_batch(
  room_ids UUID[],
  since_timestamp TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  room_id UUID,
  sender_id UUID,
  content_preview TEXT,
  created_at TIMESTAMPTZ
) 
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    m.id,
    m.room_id,
    m.sender_id,
    m.content_preview,
    m.created_at
  FROM messages m
  WHERE m.room_id = ANY(room_ids)
    AND (since_timestamp IS NULL OR m.created_at >= since_timestamp)
  ORDER BY m.created_at DESC
  LIMIT 50 * array_length(room_ids, 1); -- 50 messages per room
END;
$$;

COMMIT;


-- ===============================================
-- FILE: 15_analyze_tables.sql
-- PURPOSE: Update table statistics for optimal query planning
-- USAGE: Run periodically (weekly/monthly) to keep stats fresh
-- ===============================================

-- Analyze all tables to update statistics for query planner
ANALYZE users;
ANALYZE rooms;
ANALYZE room_memberships;
ANALYZE messages;
ANALYZE message_receipts;
ANALYZE audit_log;
ANALYZE logs_raw;
ANALYZE logs_compressed;
ANALYZE retention_schedule;
ANALYZE legal_holds;
ANALYZE telemetry;
ANALYZE threads;
ANALYZE edit_history;
ANALYZE assistants;
ANALYZE bots;
ANALYZE bot_endpoints;
ANALYZE subscriptions;
ANALYZE embeddings;
ANALYZE metrics;
ANALYZE presence_logs;
ANALYZE healing_logs;
-- Additional tables found in database
ANALYZE api_keys;
ANALYZE config;
ANALYZE files;
ANALYZE nicknames;
ANALYZE pinned_items;
ANALYZE reactions;
ANALYZE read_receipts;
ANALYZE room_members;
ANALYZE ux_telemetry;

-- Show table statistics
SELECT 
  schemaname,
  relname AS tablename,
  n_live_tup AS row_count,
  n_dead_tup AS dead_rows,
  last_vacuum,
  last_autovacuum,
  last_analyze,
  last_autoanalyze
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_live_tup DESC;


-- ===============================================
-- FILE: 16_performance_tests.sql
-- PURPOSE: Test query performance and index usage
-- ===============================================

-- ===============================================
-- TEST 1: Room Messages Query (Most Common)
-- Expected: Uses idx_messages_room_time
-- ===============================================

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
  id,
  room_id,
  sender_id,
  content_preview,
  created_at
FROM messages
WHERE room_id = '00000000-0000-0000-0000-000000000001'::UUID
ORDER BY created_at DESC
LIMIT 50;

-- ===============================================
-- TEST 2: Unread Messages Count
-- Expected: Uses idx_message_receipts_user_unread
-- ===============================================

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT COUNT(*)
FROM message_receipts
WHERE user_id = '00000000-0000-0000-0000-000000000001'::UUID
  AND read_at IS NULL;

-- ===============================================
-- TEST 3: User's Rooms
-- Expected: Uses idx_rooms_created_by
-- ===============================================

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
  id,
  slug,
  title,
  created_at
FROM rooms
WHERE created_by = '00000000-0000-0000-0000-000000000001'::UUID
ORDER BY created_at DESC;

-- ===============================================
-- TEST 4: Room Membership Check
-- Expected: Uses idx_room_memberships_room_user
-- ===============================================

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
  id,
  role,
  joined_at
FROM room_memberships
WHERE room_id = '00000000-0000-0000-0000-000000000001'::UUID
  AND user_id = '00000000-0000-0000-0000-000000000002'::UUID;

-- ===============================================
-- TEST 5: Pending Retention Jobs
-- Expected: Uses idx_retention_schedule_pending
-- ===============================================

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
  id,
  resource_type,
  resource_id,
  scheduled_for,
  action
FROM retention_schedule
WHERE status = 'pending'
  AND scheduled_for <= NOW()
ORDER BY scheduled_for ASC
LIMIT 100;

-- ===============================================
-- TEST 6: Active Legal Holds
-- Expected: Uses idx_legal_holds_active
-- ===============================================

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
  id,
  resource_type,
  resource_id,
  hold_until
FROM legal_holds
WHERE resource_type = 'logs_compressed'
  AND resource_id = '00000000-0000-0000-0000-000000000001'::UUID
  AND hold_until > NOW();

-- ===============================================
-- TEST 7: Public Rooms Discovery
-- Expected: Uses idx_rooms_public_recent
-- ===============================================

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
  id,
  slug,
  title,
  created_at
FROM rooms
WHERE is_public = true
ORDER BY created_at DESC
LIMIT 20;

-- ===============================================
-- TEST 8: Full-Text Search
-- Expected: Uses idx_messages_content_preview_gin
-- ===============================================

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
  id,
  room_id,
  content_preview,
  created_at
FROM messages
WHERE to_tsvector('english', content_preview) @@ plainto_tsquery('english', 'test query')
ORDER BY created_at DESC
LIMIT 20;

-- ===============================================
-- TEST 9: Vector Similarity Search
-- Expected: Uses idx_embeddings_vector (HNSW)
-- NOTE: Uses a generated test vector (all zeros). Works even if embeddings table is empty.
-- ===============================================

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
  e.message_id,
  m.content_preview,
  1 - (e.vector <=> (SELECT array_agg(0.0::float4)::vector(1536) FROM generate_series(1, 1536))) AS similarity
FROM embeddings e
JOIN messages m ON m.id = e.message_id
WHERE 1 - (e.vector <=> (SELECT array_agg(0.0::float4)::vector(1536) FROM generate_series(1, 1536))) > 0.78
ORDER BY e.vector <=> (SELECT array_agg(0.0::float4)::vector(1536) FROM generate_series(1, 1536))
LIMIT 10;

-- ===============================================
-- TEST 10: Thread Messages
-- Expected: Uses idx_messages_thread_id_composite
-- ===============================================

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
  id,
  thread_id,
  sender_id,
  content_preview,
  created_at
FROM messages
WHERE thread_id = '00000000-0000-0000-0000-000000000001'::UUID
ORDER BY created_at ASC;

-- ===============================================
-- INDEX USAGE STATISTICS
-- ===============================================

SELECT 
  schemaname,
  relname AS tablename,
  indexrelname AS indexname,
  idx_scan AS index_scans,
  idx_tup_read AS tuples_read,
  idx_tup_fetch AS tuples_fetched
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
  AND indexrelname LIKE 'idx_%'
ORDER BY idx_scan DESC;

-- ===============================================
-- TABLE SIZE STATISTICS
-- ===============================================

SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
  pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS index_size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
