-- ===============================================
-- VibeZ FRESH START SQL SETUP
-- ===============================================
-- This script sets up the entire VibeZ database schema from scratch.
-- It includes all core tables, features, security policies, and functions.
--
-- PREREQUISITES:
-- 1. Supabase project created.
-- 2. Extensions: pgcrypto, pg_stat_statements, uuid-ossp, vector.
-- 3. Roles: authenticated, service_role (standard Supabase roles).
--
-- INSTRUCTIONS:
-- Run this script in the Supabase SQL Editor.
-- ===============================================

-- 1. CONFIGURATION & EXTENSIONS
SET search_path TO service, public;

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS vector;

-- Create service schema for privileged operations
CREATE SCHEMA IF NOT EXISTS service;

-- ===============================================
-- 2. CORE TABLES
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
  federation_id TEXT UNIQUE,
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'moderator', 'admin', 'owner'))
);

-- Ensure role column exists (if table already existed)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'role') THEN
        ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'moderator', 'admin', 'owner'));
    END IF;
END $$;

-- Rooms: Metadata with partition key and room-level retention overrides
CREATE TABLE IF NOT EXISTS rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  title TEXT,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_public BOOLEAN NOT NULL DEFAULT true,
  partition_month TEXT,
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
  partition_month TEXT NOT NULL,
  fed_origin_hash TEXT,
  -- P0 Features
  reactions JSONB DEFAULT '[]'::jsonb,
  thread_id UUID,
  reply_to UUID,
  is_edited BOOLEAN DEFAULT FALSE,
  -- VIBES Features
  conversation_id UUID, -- FK added later
  message_type TEXT DEFAULT 'text' CHECK (message_type IN ('text', 'voice', 'image')),
  voice_url TEXT,
  is_analyzed BOOLEAN DEFAULT false
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
  id UUID DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL,
  partition_month TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  codec TEXT NOT NULL,
  compressed_payload BYTEA NOT NULL,
  original_length INT NOT NULL,
  checksum TEXT NOT NULL,
  cold_storage_uri TEXT,
  lifecycle_state TEXT NOT NULL DEFAULT 'hot',
  PRIMARY KEY (id, partition_month)
) PARTITION BY RANGE (partition_month);

CREATE TABLE IF NOT EXISTS logs_compressed_default PARTITION OF logs_compressed DEFAULT;

-- ===============================================
-- 3. AUTH & SECURITY TABLES
-- ===============================================

-- Refresh tokens for secure token rotation
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  family_id UUID NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_used_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  user_agent TEXT,
  ip_address TEXT
);

-- Auth audit log
CREATE TABLE IF NOT EXISTS auth_audit_log (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL,
  ip_address TEXT,
  user_agent TEXT,
  success BOOLEAN NOT NULL DEFAULT true,
  failure_reason TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- API Keys Vault
CREATE TABLE IF NOT EXISTS api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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

-- ===============================================
-- 4. FEATURE TABLES
-- ===============================================

-- Threads
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

-- Add foreign key constraint for thread_id and reply_to in messages
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'messages_thread_id_fkey') THEN
        ALTER TABLE messages ADD CONSTRAINT messages_thread_id_fkey FOREIGN KEY (thread_id) REFERENCES threads(id) ON DELETE SET NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'messages_reply_to_fkey') THEN
        ALTER TABLE messages ADD CONSTRAINT messages_reply_to_fkey FOREIGN KEY (reply_to) REFERENCES messages(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Edit history
CREATE TABLE IF NOT EXISTS edit_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  old_content TEXT NOT NULL,
  edited_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  edited_at TIMESTAMPTZ DEFAULT NOW()
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

-- Bot endpoints
CREATE TABLE IF NOT EXISTS bot_endpoints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bot_id UUID NOT NULL REFERENCES bots(id) ON DELETE CASCADE,
  endpoint_url VARCHAR(500) NOT NULL,
  webhook_secret VARCHAR(255),
  event_types TEXT[] DEFAULT '{}',
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

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

-- Add FK to messages for conversation_id
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'messages_conversation_id_fkey') THEN
        ALTER TABLE messages ADD CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE;
    END IF;
END $$;

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

-- ===============================================
-- 5. SERVICE & ARCHIVAL TABLES
-- ===============================================

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

-- System config
CREATE TABLE IF NOT EXISTS system_config (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Telemetry
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

-- Message Archives (Cold Storage)
CREATE TABLE IF NOT EXISTS message_archives (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL UNIQUE REFERENCES messages(id) ON DELETE CASCADE,
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  archived_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  archive_format TEXT NOT NULL DEFAULT 'encrypted_json_v1',
  archive_checksum TEXT NOT NULL,
  archive_data TEXT NOT NULL,
  cold_storage_uri TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
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

-- ===============================================
-- 6. INDEXES
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

-- Refresh Tokens
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON refresh_tokens(user_id) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_token_hash ON refresh_tokens(token_hash);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_family_id ON refresh_tokens(family_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);

-- Auth Audit
CREATE INDEX IF NOT EXISTS idx_auth_audit_user_id ON auth_audit_log(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_auth_audit_event_type ON auth_audit_log(event_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_auth_audit_created_at ON auth_audit_log(created_at DESC);

-- Message Archives
CREATE INDEX IF NOT EXISTS idx_message_archives_message_id ON message_archives(message_id);
CREATE INDEX IF NOT EXISTS idx_message_archives_room_id ON message_archives(room_id);
CREATE INDEX IF NOT EXISTS idx_message_archives_archived_at ON message_archives(archived_at DESC);
CREATE INDEX IF NOT EXISTS idx_message_archives_room_archived ON message_archives(room_id, archived_at DESC);

-- ===============================================
-- 7. FUNCTIONS
-- ===============================================

-- SHA256 hex helper
CREATE OR REPLACE FUNCTION sha256_hex(data bytea) RETURNS TEXT AS $$
BEGIN
  RETURN encode(digest($1, 'sha256'::text), 'hex');
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;

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

-- ===============================================
-- RETENTION & LIFECYCLE FUNCTIONS
-- ===============================================

-- Schedule retention: Enqueue hot→cold and cold→delete transitions
CREATE OR REPLACE FUNCTION schedule_retention() RETURNS JSONB AS $$
DECLARE
  conf JSONB;
  hot_days INT;
  cold_days INT;
  hot_count INT := 0;
  cold_count INT := 0;
  r RECORD;
BEGIN
  -- Get system defaults
  SELECT value INTO conf
  FROM system_config
  WHERE key = 'retention_policy';
  
  hot_days := COALESCE((conf->>'hot_retention_days')::INT, 30);
  cold_days := COALESCE((conf->>'cold_retention_days')::INT, 365);
  
  -- Schedule hot→cold transitions
  FOR r IN
    SELECT lc.id, lc.room_id, lc.created_at,
           COALESCE(r.retention_hot_days, hot_days) AS effective_hot_days
    FROM logs_compressed lc
    LEFT JOIN rooms r ON r.id = lc.room_id
    WHERE lc.lifecycle_state = 'hot'
      AND lc.created_at < now() - make_interval(days => COALESCE(r.retention_hot_days, hot_days))
      AND lc.id NOT IN (
        SELECT resource_id FROM retention_schedule WHERE resource_type = 'logs_compressed' AND resource_id = lc.id
      )
      AND lc.id NOT IN (
        SELECT resource_id FROM legal_holds WHERE resource_type = 'logs_compressed' AND resource_id = lc.id AND hold_until > now()
      )
  LOOP
    INSERT INTO retention_schedule (resource_type, resource_id, scheduled_for, action)
    VALUES ('logs_compressed', r.id, now(), 'move_to_cold')
    ON CONFLICT DO NOTHING;
    hot_count := hot_count + 1;
  END LOOP;
  
  -- Schedule cold→delete transitions
  FOR r IN
    SELECT lc.id, lc.room_id, lc.created_at,
           COALESCE(r.retention_cold_days, cold_days) AS effective_cold_days
    FROM logs_compressed lc
    LEFT JOIN rooms r ON r.id = lc.room_id
    WHERE lc.lifecycle_state = 'cold'
      AND lc.created_at < now() - make_interval(days => COALESCE(r.retention_cold_days, cold_days))
      AND lc.id NOT IN (
        SELECT resource_id FROM retention_schedule WHERE resource_type = 'logs_compressed' AND resource_id = lc.id
      )
      AND lc.id NOT IN (
        SELECT resource_id FROM legal_holds WHERE resource_type = 'logs_compressed' AND resource_id = lc.id AND hold_until > now()
      )
  LOOP
    INSERT INTO retention_schedule (resource_type, resource_id, scheduled_for, action)
    VALUES ('logs_compressed', r.id, now(), 'delete')
    ON CONFLICT DO NOTHING;
    cold_count := cold_count + 1;
  END LOOP;
  
  RETURN jsonb_build_object('hot_scheduled', hot_count, 'cold_scheduled', cold_count, 'timestamp', now());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = service, public;

-- Mark cold storage
CREATE OR REPLACE FUNCTION mark_cold_storage(compressed_id UUID, uri TEXT) RETURNS VOID AS $$
BEGIN
  UPDATE logs_compressed
  SET cold_storage_uri = uri, lifecycle_state = 'cold'
  WHERE id = compressed_id AND lifecycle_state = 'hot';
  
  UPDATE retention_schedule
  SET status = 'done'
  WHERE resource_type = 'logs_compressed' AND resource_id = compressed_id AND action = 'move_to_cold';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = service, public;

-- Apply legal hold
CREATE OR REPLACE FUNCTION apply_legal_hold(resource_type TEXT, resource_id UUID, hold_until TIMESTAMPTZ, reason TEXT, actor TEXT) RETURNS VOID AS $$
BEGIN
  INSERT INTO legal_holds (resource_type, resource_id, hold_until, reason, actor)
  VALUES (resource_type, resource_id, hold_until, reason, actor)
  ON CONFLICT DO NOTHING;
  
  UPDATE retention_schedule
  SET on_hold = TRUE, hold_reason = reason, status = 'on_hold'
  WHERE resource_type = apply_legal_hold.resource_type AND resource_id = apply_legal_hold.resource_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = service, public;

-- Release legal hold
CREATE OR REPLACE FUNCTION release_legal_hold(resource_type TEXT, resource_id UUID) RETURNS VOID AS $$
BEGIN
  DELETE FROM legal_holds
  WHERE resource_type = release_legal_hold.resource_type AND resource_id = release_legal_hold.resource_id;
  
  UPDATE retention_schedule
  SET on_hold = FALSE, hold_reason = NULL, status = 'pending'
  WHERE resource_type = release_legal_hold.resource_type AND resource_id = release_legal_hold.resource_id AND on_hold = TRUE;
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
        RETURN digest('vibez-api-keys-master-key-change-this-in-production'::text, 'sha256'::text);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Cleanup expired refresh tokens
CREATE OR REPLACE FUNCTION cleanup_expired_refresh_tokens()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM refresh_tokens
  WHERE expires_at < NOW() OR revoked_at IS NOT NULL;
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

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
-- 8. TRIGGERS
-- ===============================================

-- Updated_at triggers
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_name = 'update_assistants_updated_at') THEN
        CREATE TRIGGER update_assistants_updated_at BEFORE UPDATE ON assistants FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_name = 'update_bots_updated_at') THEN
        CREATE TRIGGER update_bots_updated_at BEFORE UPDATE ON bots FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_name = 'update_subscriptions_updated_at') THEN
        CREATE TRIGGER update_subscriptions_updated_at BEFORE UPDATE ON subscriptions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_name = 'update_message_violations_updated_at') THEN
        CREATE TRIGGER update_message_violations_updated_at BEFORE UPDATE ON message_violations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Partition month triggers (to avoid GENERATED column immutability issues)
CREATE OR REPLACE FUNCTION set_partition_month()
RETURNS TRIGGER AS $$
BEGIN
  NEW.partition_month := to_char(NEW.created_at, 'YYYY_MM');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS rooms_set_partition_month ON rooms;
CREATE TRIGGER rooms_set_partition_month
  BEFORE INSERT OR UPDATE ON rooms
  FOR EACH ROW
  EXECUTE FUNCTION set_partition_month();

DROP TRIGGER IF EXISTS messages_set_partition_month ON messages;
CREATE TRIGGER messages_set_partition_month
  BEFORE INSERT OR UPDATE ON messages
  FOR EACH ROW
  EXECUTE FUNCTION set_partition_month();

-- ===============================================
-- 9. ROW LEVEL SECURITY (RLS)
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
ALTER TABLE refresh_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth_audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_archives ENABLE ROW LEVEL SECURITY;

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

-- Basic RLS policies (Service Role Access)
-- Service role should have full access to everything
CREATE POLICY service_all_audit_log ON audit_log FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_messages ON messages FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_users ON users FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_rooms ON rooms FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_room_memberships ON room_memberships FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_refresh_tokens ON refresh_tokens FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_auth_audit_log ON auth_audit_log FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_message_archives ON message_archives FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Authenticated User Access (Basic)
CREATE POLICY auth_select_users ON users FOR SELECT TO authenticated USING (true);
CREATE POLICY auth_select_rooms ON rooms FOR SELECT TO authenticated USING (true);
CREATE POLICY auth_select_messages ON messages FOR SELECT TO authenticated USING (true);
CREATE POLICY auth_insert_messages ON messages FOR INSERT TO authenticated WITH CHECK (true);

-- ===============================================
-- SETUP COMPLETE
-- ===============================================

