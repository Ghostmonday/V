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
