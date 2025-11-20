-- ===============================================
-- VibeZ Complete Database Setup
-- This file consolidates all essential SQL scripts
-- Run this for a complete fresh installation
-- ===============================================

-- Set configuration
SET search_path TO service, public;

-- ===============================================
-- PHASE 1: CORE SCHEMA (from 01_sinapse_schema.sql)
-- ===============================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS vector; -- For AI embeddings

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
  federation_id TEXT UNIQUE
);

-- Rooms: Metadata with partition key and room-level retention overrides
CREATE TABLE IF NOT EXISTS rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  title TEXT,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_public BOOLEAN NOT NULL DEFAULT true,
  partition_month TEXT GENERATED ALWAYS AS (to_char(date_trunc('month', created_at), 'YYYY_MM')) STORED,
  metadata JSONB DEFAULT '{}'::jsonb,
  fed_node_id TEXT,
  retention_hot_days INT,
  retention_cold_days INT
);

-- Room memberships: Roles, strikes, probation, and ban tracking
CREATE TABLE IF NOT EXISTS room_memberships (
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

-- Messages: Minimal canonical records with external payload references
CREATE TABLE IF NOT EXISTS messages (
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
  partition_month TEXT NOT NULL GENERATED ALWAYS AS (to_char(date_trunc('month', created_at), 'YYYY_MM')) STORED,
  fed_origin_hash TEXT
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

-- Raw logs: Transient intake before compression
CREATE TABLE IF NOT EXISTS logs_raw (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  payload BYTEA NOT NULL,
  mime_type TEXT NOT NULL,
  length_bytes INT NOT NULL,
  checksum TEXT NOT NULL,
  processed BOOLEAN NOT NULL DEFAULT FALSE
);

-- Compressed logs: Declarative partitioning by partition_month
CREATE TABLE IF NOT EXISTS logs_compressed (
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
) PARTITION BY RANGE (partition_month);

-- Default partition for overflow
CREATE TABLE IF NOT EXISTS logs_compressed_default PARTITION OF logs_compressed DEFAULT;

-- Service tables
CREATE TABLE IF NOT EXISTS service.encode_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  raw_id UUID NOT NULL REFERENCES logs_raw(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending',
  attempts INT NOT NULL DEFAULT 0,
  max_attempts INT NOT NULL DEFAULT 3,
  last_attempt_at TIMESTAMPTZ,
  error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS service.moderation_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending',
  attempts INT NOT NULL DEFAULT 0,
  max_attempts INT NOT NULL DEFAULT 3,
  last_attempt_at TIMESTAMPTZ,
  error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Retention and legal holds
CREATE TABLE IF NOT EXISTS retention_schedule (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  resource_type TEXT NOT NULL,
  resource_id UUID NOT NULL,
  scheduled_for TIMESTAMPTZ NOT NULL,
  action TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  on_hold BOOLEAN NOT NULL DEFAULT false,
  hold_reason TEXT
);

CREATE TABLE IF NOT EXISTS legal_holds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  resource_type TEXT NOT NULL,
  resource_id UUID NOT NULL,
  hold_until TIMESTAMPTZ NOT NULL,
  reason TEXT NOT NULL,
  actor TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Telemetry and system config
CREATE TABLE IF NOT EXISTS telemetry (
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

CREATE TABLE IF NOT EXISTS system_config (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ===============================================
-- P0 FEATURES (from 09_p0_features.sql)
-- ===============================================

-- Add P0 columns to messages
ALTER TABLE messages 
  ADD COLUMN IF NOT EXISTS reactions JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS thread_id UUID,
  ADD COLUMN IF NOT EXISTS reply_to UUID,
  ADD COLUMN IF NOT EXISTS is_edited BOOLEAN DEFAULT FALSE;

-- Threads table
CREATE TABLE IF NOT EXISTS threads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  title VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  message_count INTEGER DEFAULT 0,
  is_archived BOOLEAN DEFAULT FALSE,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL
);

-- Add foreign key constraint for thread_id
ALTER TABLE messages 
  ADD CONSTRAINT messages_thread_id_fkey 
  FOREIGN KEY (thread_id) REFERENCES threads(id) ON DELETE SET NULL;

-- Add foreign key constraint for reply_to
ALTER TABLE messages 
  ADD CONSTRAINT messages_reply_to_fkey 
  FOREIGN KEY (reply_to) REFERENCES messages(id) ON DELETE SET NULL;

-- Edit history
CREATE TABLE IF NOT EXISTS edit_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  old_content TEXT NOT NULL,
  edited_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  edited_at TIMESTAMPTZ DEFAULT NOW()
);

-- Bot endpoints
CREATE TABLE IF NOT EXISTS bot_endpoints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bot_id UUID NOT NULL,
  endpoint_url VARCHAR(500) NOT NULL,
  webhook_secret VARCHAR(255),
  event_types TEXT[] DEFAULT '{}',
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===============================================
-- INTEGRATED FEATURES (from 10_integrated_features.sql)
-- ===============================================

-- AI Assistants
CREATE TABLE IF NOT EXISTS assistants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  model VARCHAR(100) NOT NULL DEFAULT 'gpt-4',
  temperature DECIMAL(3,2) DEFAULT 0.7 CHECK (temperature >= 0 AND temperature <= 2),
  system_prompt TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Bots
CREATE TABLE IF NOT EXISTS bots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  url VARCHAR(500) NOT NULL,
  token VARCHAR(255) UNIQUE NOT NULL,
  created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  is_active BOOLEAN DEFAULT TRUE,
  permissions JSONB DEFAULT '{}'::jsonb,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Update bot_endpoints foreign key
ALTER TABLE bot_endpoints 
  DROP CONSTRAINT IF EXISTS bot_endpoints_bot_id_fkey,
  ADD CONSTRAINT bot_endpoints_bot_id_fkey 
    FOREIGN KEY (bot_id) REFERENCES bots(id) ON DELETE CASCADE;

-- Subscriptions
CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  push_sub JSONB NOT NULL,
  endpoint VARCHAR(500) NOT NULL,
  p256dh VARCHAR(255),
  auth VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT TRUE
);

-- Embeddings
CREATE TABLE IF NOT EXISTS embeddings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  vector vector(1536) NOT NULL,
  model VARCHAR(100) DEFAULT 'text-embedding-3-small',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Metrics
CREATE TABLE IF NOT EXISTS metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type VARCHAR(100) NOT NULL,
  value DECIMAL(15,2) NOT NULL,
  metadata JSONB DEFAULT '{}'::jsonb,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Presence logs
CREATE TABLE IF NOT EXISTS presence_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
  status VARCHAR(50) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===============================================
-- VIBES FEATURES (from migrations)
-- ===============================================

-- Conversations (VIBES)
CREATE TABLE IF NOT EXISTS conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_message_at TIMESTAMPTZ,
  message_count INTEGER DEFAULT 0,
  is_group BOOLEAN NOT NULL DEFAULT false,
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Conversation participants
CREATE TABLE IF NOT EXISTS conversation_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_read_at TIMESTAMPTZ,
  UNIQUE(conversation_id, user_id)
);

-- Update messages for VIBES
ALTER TABLE messages 
  ADD COLUMN IF NOT EXISTS conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS message_type TEXT DEFAULT 'text' CHECK (message_type IN ('text', 'voice', 'image')),
  ADD COLUMN IF NOT EXISTS voice_url TEXT,
  ADD COLUMN IF NOT EXISTS is_analyzed BOOLEAN DEFAULT false;

-- Sentiment analysis
CREATE TABLE IF NOT EXISTS sentiment_analysis (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  analysis_data JSONB NOT NULL,
  surprise_factor NUMERIC NOT NULL,
  keywords TEXT[],
  breakup_detected BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(conversation_id)
);

-- Cards
CREATE TABLE IF NOT EXISTS cards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sentiment_analysis_id UUID REFERENCES sentiment_analysis(id) ON DELETE SET NULL,
  artwork_url TEXT NOT NULL,
  frame_style TEXT NOT NULL CHECK (frame_style IN ('common', 'uncommon', 'rare', 'epic', 'legendary')),
  title TEXT NOT NULL,
  caption TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  rarity_data JSONB NOT NULL DEFAULT '{}'::jsonb,
  ipfs_cid TEXT,
  arweave_txid TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  generated_at TIMESTAMPTZ,
  is_burned BOOLEAN DEFAULT false,
  burned_at TIMESTAMPTZ
);

-- Card ownerships
CREATE TABLE IF NOT EXISTS card_ownerships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id UUID NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  acquired_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  acquisition_type TEXT NOT NULL CHECK (acquisition_type IN ('claimed', 'defaulted', 'purchased')),
  claim_deadline TIMESTAMPTZ,
  previous_owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
  UNIQUE(card_id, owner_id)
);

-- Card events
CREATE TABLE IF NOT EXISTS card_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id UUID NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL CHECK (event_type IN ('generated', 'offered', 'claimed', 'declined', 'defaulted', 'burned', 'printed')),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Museum entries
CREATE TABLE IF NOT EXISTS museum_entries (
  card_id UUID PRIMARY KEY REFERENCES cards(id) ON DELETE CASCADE,
  visibility TEXT NOT NULL DEFAULT 'public' CHECK (visibility IN ('public', 'redacted', 'burned', 'private')),
  view_count INTEGER DEFAULT 0,
  featured BOOLEAN DEFAULT false,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Boosts
CREATE TABLE IF NOT EXISTS boosts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  boost_type TEXT NOT NULL CHECK (boost_type IN ('rarity_boost')),
  amount_paid NUMERIC NOT NULL,
  payment_provider TEXT,
  payment_id TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Privacy: ZKP Commitments
CREATE TABLE IF NOT EXISTS user_zkp_commitments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  attribute_type TEXT NOT NULL CHECK (attribute_type IN ('age', 'verified', 'subscription_tier', 'location_country', 'custom')),
  commitment TEXT NOT NULL,
  proof_data JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ
);

-- Moderation tables
CREATE TABLE IF NOT EXISTS message_violations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
  count INTEGER DEFAULT 1,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, room_id)
);

CREATE TABLE IF NOT EXISTS user_mutes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
  muted_until TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, room_id)
);

-- API Keys Vault
CREATE TABLE IF NOT EXISTS api_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key_name VARCHAR(100) NOT NULL UNIQUE,
    key_category VARCHAR(50) NOT NULL,
    encrypted_value BYTEA NOT NULL,
    description TEXT,
    environment VARCHAR(20) DEFAULT 'production' CHECK (environment IN ('development', 'staging', 'production')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    last_accessed_at TIMESTAMPTZ,
    access_count INTEGER DEFAULT 0
);

-- ===============================================
-- INDEXES
-- ===============================================

-- Core indexes
CREATE INDEX IF NOT EXISTS idx_messages_room_time ON messages (room_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_hash ON messages (content_hash);
CREATE INDEX IF NOT EXISTS idx_messages_flagged ON messages (is_flagged) WHERE is_flagged = true;
CREATE INDEX IF NOT EXISTS idx_messages_partition ON messages (partition_month);
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_reactions ON messages USING GIN (reactions);
CREATE INDEX IF NOT EXISTS idx_messages_thread_id ON messages (thread_id) WHERE thread_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_messages_reply_to ON messages (reply_to) WHERE reply_to IS NOT NULL;

-- Audit and logs
CREATE INDEX IF NOT EXISTS idx_audit_room_time ON audit_log (room_id, event_time DESC);
CREATE INDEX IF NOT EXISTS idx_audit_node_chain ON audit_log (node_id, id DESC);
CREATE INDEX IF NOT EXISTS idx_audit_event_type ON audit_log (event_type);
CREATE INDEX IF NOT EXISTS idx_logs_raw_room_month ON logs_raw (room_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_logs_compressed_room_month ON logs_compressed (room_id, partition_month, created_at DESC);

-- Feature indexes
CREATE INDEX IF NOT EXISTS idx_threads_parent_message ON threads (parent_message_id);
CREATE INDEX IF NOT EXISTS idx_threads_room_id ON threads (room_id) WHERE is_archived = FALSE;
CREATE INDEX IF NOT EXISTS idx_threads_updated_at ON threads (updated_at DESC) WHERE is_archived = FALSE;
CREATE INDEX IF NOT EXISTS idx_edit_history_message_id ON edit_history (message_id);
CREATE INDEX IF NOT EXISTS idx_edit_history_edited_at ON edit_history (edited_at DESC);
CREATE INDEX IF NOT EXISTS idx_embeddings_vector ON embeddings USING hnsw (vector vector_cosine_ops) WITH (m = 16, ef_construction = 64);

-- User and room indexes
CREATE INDEX IF NOT EXISTS idx_users_handle ON users (handle);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_room_memberships_room_user ON room_memberships (room_id, user_id);
CREATE INDEX IF NOT EXISTS idx_room_memberships_user_role ON room_memberships (user_id, role);

-- API keys and privacy
CREATE INDEX IF NOT EXISTS idx_api_keys_name ON api_keys(key_name);
CREATE INDEX IF NOT EXISTS idx_api_keys_category ON api_keys(key_category);
CREATE INDEX IF NOT EXISTS idx_zkp_commitments_user_id ON user_zkp_commitments(user_id, created_at DESC);

-- ===============================================
-- FUNCTIONS (from 02_compressor_functions.sql)
-- ===============================================

-- SHA256 hex helper
CREATE OR REPLACE FUNCTION sha256_hex(data bytea) RETURNS TEXT AS $$
  SELECT encode(digest($1, 'sha256'), 'hex');
$$ LANGUAGE SQL IMMUTABLE STRICT;

-- Intake log function
CREATE OR REPLACE FUNCTION intake_log(
  room UUID,
  payload BYTEA,
  mime TEXT
) RETURNS UUID AS $$
DECLARE
  rid UUID;
  csum TEXT;
BEGIN
  csum := sha256_hex(payload);
  INSERT INTO logs_raw (room_id, payload, mime_type, length_bytes, checksum)
  VALUES (room, payload, mime, octet_length(payload), csum)
  RETURNING id INTO rid;
  RETURN rid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = service, public;

-- Audit append function
CREATE OR REPLACE FUNCTION audit_append(
  evt_type TEXT,
  room UUID,
  usr UUID,
  msg UUID,
  pload JSONB,
  actor TEXT DEFAULT 'system',
  sig TEXT DEFAULT NULL
) RETURNS BIGINT AS $$
DECLARE
  p_hash TEXT;
  h TEXT;
  prev_chain TEXT;
  canonical TEXT;
  new_id BIGINT;
  lock_key BIGINT;
  node_id_val TEXT;
BEGIN
  node_id_val := current_setting('app.node_id', true);
  IF node_id_val IS NULL OR node_id_val = '' THEN
    node_id_val := 'local';
    PERFORM set_config('app.node_id', node_id_val, false);
  END IF;
  
  lock_key := hashtext(node_id_val);
  
  IF NOT pg_try_advisory_xact_lock(lock_key) THEN
    RAISE EXCEPTION 'Audit chain lock contention for node_id: %', node_id_val;
  END IF;
  
  SELECT chain_hash INTO prev_chain
  FROM audit_log
  WHERE node_id = node_id_val
  ORDER BY id DESC
  LIMIT 1;
  
  IF prev_chain IS NULL THEN
    prev_chain := 'genesis';
  END IF;
  
  canonical := jsonb_build_object(
    'event_time', now(),
    'event_type', evt_type,
    'room_id', room,
    'user_id', usr,
    'message_id', msg,
    'payload', pload,
    'actor', actor,
    'signature', sig,
    'node_id', node_id_val
  )::text;
  
  h := sha256_hex(canonical::bytea);
  p_hash := sha256_hex((prev_chain || h)::bytea);
  
  INSERT INTO audit_log (
    event_type,
    room_id,
    user_id,
    message_id,
    payload,
    actor,
    signature,
    hash,
    prev_hash,
    chain_hash,
    node_id
  )
  VALUES (
    evt_type,
    room,
    usr,
    msg,
    pload,
    actor,
    sig,
    h,
    prev_chain,
    p_hash,
    node_id_val
  )
  RETURNING id INTO new_id;
  
  RETURN new_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = service, public;

-- Update timestamp function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- API Keys encryption helper
CREATE OR REPLACE FUNCTION get_encryption_key()
RETURNS BYTEA AS $$
BEGIN
    RETURN decode(current_setting('app.encryption_key', true), 'hex');
EXCEPTION
    WHEN OTHERS THEN
        RETURN digest('vibez-api-keys-master-key-change-this-in-production', 'sha256');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Search functions
CREATE MATERIALIZED VIEW IF NOT EXISTS message_search_index AS
SELECT
  m.id,
  m.content_preview AS content,
  m.room_id,
  m.sender_id AS user_id,
  m.created_at,
  to_tsvector('english', COALESCE(m.content_preview, '')) AS search_vector
FROM messages m
WHERE m.thread_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_message_search_vector ON message_search_index USING GIN (search_vector);

-- Vector search function
CREATE OR REPLACE FUNCTION match_messages(
  query_embedding vector(1536),
  match_threshold float DEFAULT 0.78,
  match_count int DEFAULT 10,
  filter_room_id UUID DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  room_id UUID,
  sender_id UUID,
  content_preview TEXT,
  created_at TIMESTAMPTZ,
  similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    m.id,
    m.room_id,
    m.sender_id,
    m.content_preview,
    m.created_at,
    1 - (e.vector <=> query_embedding) AS similarity
  FROM messages m
  INNER JOIN embeddings e ON e.message_id = m.id
  WHERE 
    (filter_room_id IS NULL OR m.room_id = filter_room_id)
    AND (1 - (e.vector <=> query_embedding)) > match_threshold
  ORDER BY e.vector <=> query_embedding
  LIMIT match_count;
END;
$$;

-- ===============================================
-- TRIGGERS
-- ===============================================

-- Updated_at triggers
CREATE TRIGGER update_assistants_updated_at
  BEFORE UPDATE ON assistants
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_bots_updated_at
  BEFORE UPDATE ON bots
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_subscriptions_updated_at
  BEFORE UPDATE ON subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_message_violations_updated_at
  BEFORE UPDATE ON message_violations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ===============================================
-- ROW LEVEL SECURITY
-- ===============================================

-- Enable RLS on all tables
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE logs_raw ENABLE ROW LEVEL SECURITY;
ALTER TABLE logs_compressed ENABLE ROW LEVEL SECURITY;
ALTER TABLE service.encode_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE service.moderation_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE retention_schedule ENABLE ROW LEVEL SECURITY;
ALTER TABLE legal_holds ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE telemetry ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_zkp_commitments ENABLE ROW LEVEL SECURITY;
ALTER TABLE bots ENABLE ROW LEVEL SECURITY;
ALTER TABLE assistants ENABLE ROW LEVEL SECURITY;
ALTER TABLE threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE presence_logs ENABLE ROW LEVEL SECURITY;

-- Helper functions for RLS
CREATE OR REPLACE FUNCTION public.current_uid() RETURNS UUID AS $$
  SELECT (current_setting('request.jwt.claims', true)::json->>'sub')::UUID;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION public.current_role() RETURNS TEXT AS $$
  SELECT COALESCE(
    (current_setting('request.jwt.claims', true)::json->>'role')::TEXT,
    'user'
  );
$$ LANGUAGE SQL STABLE;

-- Basic RLS policies (extend as needed)
-- Audit log: Service role only
CREATE POLICY audit_insert_service ON audit_log
  FOR INSERT
  TO service_role
  WITH CHECK (true);

CREATE POLICY audit_select_service ON audit_log
  FOR SELECT
  TO service_role
  USING (true);

CREATE POLICY audit_no_update ON audit_log
  FOR UPDATE
  TO public
  USING (false);

CREATE POLICY audit_no_delete ON audit_log
  FOR DELETE
  TO public
  USING (false);

-- Messages: Authenticated users
CREATE POLICY messages_insert_auth ON messages
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY messages_select_room ON messages
  FOR SELECT
  TO authenticated
  USING (true);

-- System tables: Service role only
CREATE POLICY system_config_service_only ON system_config
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY telemetry_service_only ON telemetry
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- API Keys: Service role only
CREATE POLICY api_keys_service_role_only ON api_keys
    FOR ALL
    USING (auth.role() = 'service_role');

CREATE POLICY api_keys_deny_all ON api_keys
    FOR ALL
    USING (false);

-- ===============================================
-- DEFAULT SYSTEM CONFIGURATION
-- ===============================================

INSERT INTO system_config (key, value) VALUES
  ('retention_policy', jsonb_build_object(
    'hot_retention_days', 30,
    'cold_retention_days', 365
  )),
  ('cold_storage', jsonb_build_object(
    'bucket', 'vibez-cold',
    'provider', 's3'
  )),
  ('moderation_thresholds', jsonb_build_object(
    'default', 0.6,
    'illegal', 0.7,
    'threat', 0.6,
    'pii', 0.65,
    'hate', 0.55,
    'adult', 0.0,
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

-- ===============================================
-- COMPLETION MESSAGE
-- ===============================================
DO $$
BEGIN
  RAISE NOTICE 'VibeZ database setup completed successfully!';
  RAISE NOTICE 'Tables created: %', (SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public');
  RAISE NOTICE 'Indexes created: %', (SELECT count(*) FROM pg_indexes WHERE schemaname = 'public');
  RAISE NOTICE 'RLS enabled on sensitive tables';
  RAISE NOTICE '';
  RAISE NOTICE 'Next steps:';
  RAISE NOTICE '1. Set encryption key: ALTER DATABASE postgres SET app.encryption_key = ''<your-hex-key>'';';
  RAISE NOTICE '2. Store API keys using store_api_key() function';
  RAISE NOTICE '3. Run validation scripts to verify setup';
END $$;
