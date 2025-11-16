-- ===============================================
-- FILE: 01_vibez_schema.sql
-- PURPOSE: Core tables, extensions, and indexes for VibeZ Communication Ledger
-- DEPENDENCIES: None (run first)
-- ===============================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Create service schema for privileged operations
CREATE SCHEMA IF NOT EXISTS service;

-- ===============================================
-- CORE TABLES
-- ===============================================

-- Users: Profiles with trust metadata and federation support
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  handle TEXT NOT NULL UNIQUE,
  display_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_verified BOOLEAN NOT NULL DEFAULT false,
  metadata JSONB DEFAULT '{}'::jsonb,
  policy_flags JSONB DEFAULT '{}'::jsonb,
  last_seen TIMESTAMPTZ,
  federation_id TEXT UNIQUE -- For cross-node user mapping
);

-- Rooms: Metadata with partition key and room-level retention overrides
CREATE TABLE IF NOT EXISTS rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  title TEXT,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_public BOOLEAN NOT NULL DEFAULT true,
  partition_month TEXT GENERATED ALWAYS AS (to_char(date_trunc('month', created_at AT TIME ZONE 'UTC'), 'YYYY_MM')) STORED,
  metadata JSONB DEFAULT '{}'::jsonb,
  fed_node_id TEXT, -- Origin node for federated rooms
  retention_hot_days INT, -- Room-level override (NULL = use system default)
  retention_cold_days INT -- Room-level override (NULL = use system default)
);

-- Room memberships: Roles, strikes, probation, and ban tracking
CREATE TABLE IF NOT EXISTS room_memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member', -- owner, admin, mod, member, banned
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  strike_count INT NOT NULL DEFAULT 0,
  probation_until TIMESTAMPTZ,
  last_warning_at TIMESTAMPTZ,
  ban_reason JSONB DEFAULT '{}'::jsonb, -- Audit details for bans
  UNIQUE(room_id, user_id)
);

-- Messages: Minimal canonical records with external payload references
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  payload_ref TEXT NOT NULL, -- 'raw:{id}', 'cmp:{id}', or 'cold:{uri}'
  content_preview TEXT, -- <=512 chars for search/UX
  content_hash TEXT NOT NULL, -- SHA256 of normalized payload
  audit_hash_chain TEXT NOT NULL, -- Tamper-evident chain
  flags JSONB DEFAULT '{}'::jsonb, -- {labels: [], scores: [], features: {}}
  is_flagged BOOLEAN NOT NULL DEFAULT FALSE,
  is_exported BOOLEAN NOT NULL DEFAULT FALSE,
  partition_month TEXT NOT NULL GENERATED ALWAYS AS (to_char(date_trunc('month', created_at AT TIME ZONE 'UTC'), 'YYYY_MM')) STORED,
  fed_origin_hash TEXT -- For federated message verification
);

-- Message receipts: Delivery and read states
CREATE TABLE IF NOT EXISTS message_receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  delivered_at TIMESTAMPTZ,
  read_at TIMESTAMPTZ,
  UNIQUE(message_id, user_id)
);

-- Audit log: Append-only, immutable events with chained hashes
CREATE TABLE IF NOT EXISTS audit_log (
  id BIGSERIAL PRIMARY KEY,
  event_time TIMESTAMPTZ NOT NULL DEFAULT now(),
  event_type TEXT NOT NULL, -- 'moderation_flag', 'ingest', 'export', 'fed_verify', 'cold_storage_transition'
  room_id UUID,
  user_id UUID,
  message_id UUID,
  payload JSONB,
  actor TEXT, -- 'grok-moderator', 'system', 'legal', 'fed_node'
  signature TEXT, -- Ed25519 signature for federation
  hash TEXT NOT NULL, -- SHA256 of canonical event
  prev_hash TEXT, -- Previous audit chain hash
  chain_hash TEXT NOT NULL, -- Chained SHA256
  node_id TEXT NOT NULL DEFAULT current_setting('app.node_id', true, true) -- Node-specific for federation
);

-- Raw logs: Transient intake before compression
CREATE TABLE IF NOT EXISTS logs_raw (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  payload BYTEA NOT NULL,
  mime_type TEXT NOT NULL,
  length_bytes INT NOT NULL,
  checksum TEXT NOT NULL, -- SHA256
  processed BOOLEAN NOT NULL DEFAULT FALSE
);

-- Compressed logs: Declarative partitioning by partition_month
-- Non-FK room_id for partition flexibility (validated via soft-reference jobs)
CREATE TABLE IF NOT EXISTS logs_compressed (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL, -- Non-FK; validated via soft-reference jobs
  partition_month TEXT NOT NULL, -- 'YYYY_MM' format
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  codec TEXT NOT NULL, -- 'lz4' or 'gzip'
  compressed_payload BYTEA NOT NULL,
  original_length INT NOT NULL,
  checksum TEXT NOT NULL, -- SHA256 of compressed payload
  cold_storage_uri TEXT, -- S3 URI when moved to cold storage
  lifecycle_state TEXT NOT NULL DEFAULT 'hot' -- 'hot', 'cold', 'deleted'
) PARTITION BY RANGE (partition_month);

-- Default partition for overflow
CREATE TABLE IF NOT EXISTS logs_compressed_default PARTITION OF logs_compressed DEFAULT;

-- Encode queue: Tracks compression jobs with status and retry logic
CREATE TABLE IF NOT EXISTS service.encode_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  raw_id UUID NOT NULL REFERENCES logs_raw(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'processing', 'done', 'failed'
  attempts INT NOT NULL DEFAULT 0,
  max_attempts INT NOT NULL DEFAULT 3,
  last_attempt_at TIMESTAMPTZ,
  error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Moderation queue: Decouples moderation from ingestion for SLO compliance
CREATE TABLE IF NOT EXISTS service.moderation_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'processing', 'done', 'failed'
  attempts INT NOT NULL DEFAULT 0,
  max_attempts INT NOT NULL DEFAULT 3,
  last_attempt_at TIMESTAMPTZ,
  error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Retention schedule: Queued actions for retention lifecycle
CREATE TABLE IF NOT EXISTS retention_schedule (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  resource_type TEXT NOT NULL, -- 'logs_compressed', 'audit_log', 'messages'
  resource_id UUID NOT NULL,
  scheduled_for TIMESTAMPTZ NOT NULL,
  action TEXT NOT NULL, -- 'move_to_cold', 'delete'
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'done', 'failed', 'on_hold'
  on_hold BOOLEAN NOT NULL DEFAULT false,
  hold_reason TEXT -- For legal holds
);

-- Legal holds: Prevents disposal of resources under legal hold
CREATE TABLE IF NOT EXISTS legal_holds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  resource_type TEXT NOT NULL,
  resource_id UUID NOT NULL,
  hold_until TIMESTAMPTZ NOT NULL,
  reason TEXT NOT NULL,
  actor TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Telemetry: Metrics for optimization and SLO monitoring
CREATE TABLE IF NOT EXISTS telemetry (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_time TIMESTAMPTZ NOT NULL DEFAULT now(),
  event TEXT NOT NULL, -- 'moderation_flag', 'compression', 'backlog_size', 'fallback_codec', etc.
  room_id UUID,
  user_id UUID,
  risk NUMERIC,
  action TEXT,
  features JSONB,
  latency_ms INT,
  precision_recall JSONB DEFAULT '{}'::jsonb -- For optimizer tuning
);

-- System config: Tunables with JSONB for complex configurations
CREATE TABLE IF NOT EXISTS system_config (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ===============================================
-- INDEXES
-- ===============================================

-- Messages indexes
CREATE INDEX IF NOT EXISTS idx_messages_room_time ON messages (room_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_hash ON messages (content_hash);
CREATE INDEX IF NOT EXISTS idx_messages_flagged ON messages (is_flagged) WHERE is_flagged = true;
CREATE INDEX IF NOT EXISTS idx_messages_partition ON messages (partition_month);

-- Audit log indexes
CREATE INDEX IF NOT EXISTS idx_audit_room_time ON audit_log (room_id, event_time DESC);
CREATE INDEX IF NOT EXISTS idx_audit_node_chain ON audit_log (node_id, id DESC); -- For per-node chain verification
CREATE INDEX IF NOT EXISTS idx_audit_event_type ON audit_log (event_type);

-- Raw logs indexes
CREATE INDEX IF NOT EXISTS idx_logs_raw_room_month ON logs_raw (room_id, created_at DESC);

-- Compressed logs indexes
CREATE INDEX IF NOT EXISTS idx_logs_compressed_room_month ON logs_compressed (room_id, partition_month, created_at DESC);

-- Telemetry indexes
CREATE INDEX IF NOT EXISTS idx_telemetry_event_time ON telemetry (event_time DESC);

-- Queue indexes for efficient claiming
CREATE INDEX IF NOT EXISTS encode_queue_status_idx ON service.encode_queue (status) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS moderation_queue_status_idx ON service.moderation_queue (status) WHERE status = 'pending';

-- Room retention override index
CREATE INDEX IF NOT EXISTS rooms_retention_idx ON rooms (retention_hot_days, retention_cold_days) WHERE retention_hot_days IS NOT NULL OR retention_cold_days IS NOT NULL;

-- ===============================================
-- DEFAULT SYSTEM CONFIG
-- ===============================================

-- Insert default system configuration
INSERT INTO system_config (key, value) VALUES
  ('retention_policy', jsonb_build_object(
    'hot_retention_days', 30,
    'cold_retention_days', 365
  )),
  ('cold_storage', jsonb_build_object(
    'bucket', 'vibez-cold',
    'provider', 's3'
  )),
  -- @llm_param - Moderation thresholds stored in system_config. Controls AI moderation sensitivity per category. LLM can adjust these.
  ('moderation_thresholds', jsonb_build_object(
    -- @llm_param - Default moderation threshold. Messages exceeding this score are flagged.
    'default', 0.6,
    -- @llm_param - Illegal content threshold. Higher threshold = stricter detection.
    'illegal', 0.7,
    -- @llm_param - Threat detection threshold. Controls sensitivity to threats.
    'threat', 0.6,
    -- @llm_param - PII (Personally Identifiable Information) detection threshold.
    'pii', 0.65,
    -- @llm_param - Hate speech detection threshold. Lower = more sensitive.
    'hate', 0.55,
    -- @llm_param - Adult content threshold. 0.0 = disabled.
    'adult', 0.0,
    -- @llm_param - Probation multiplier. Users on probation have thresholds multiplied by this value (lower = stricter).
    'probation_multiplier', 0.5
  )),
  ('codec', jsonb_build_object(
    'preferences', jsonb_build_object(
      'text/plain', 'lz4',
      'text/*', 'lz4',
      'application/json', 'lz4',
      'application/*', 'gzip',
      'image/*', 'gzip',
      'video/*', 'gzip',
      'audio/*', 'gzip',
      'default', 'gzip'
    )
  ))
ON CONFLICT (key) DO NOTHING;

-- Set default node_id if not already set
DO $$
BEGIN
  IF current_setting('app.node_id', true) IS NULL THEN
    PERFORM set_config('app.node_id', 'local', false);
  END IF;
END $$;

