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
