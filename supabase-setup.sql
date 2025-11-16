-- 1 - COMPLETE SETUP SQL (Copy entire block into Supabase SQL Editor)

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE SCHEMA IF NOT EXISTS service;

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  handle TEXT NOT NULL UNIQUE,
  display_name TEXT,
  username TEXT UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_verified BOOLEAN NOT NULL DEFAULT false,
  age_verified BOOLEAN NOT NULL DEFAULT false,
  metadata JSONB DEFAULT '{}'::jsonb,
  policy_flags JSONB DEFAULT '{}'::jsonb,
  last_seen TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  slug TEXT UNIQUE,
  title TEXT,
  creator_id UUID REFERENCES users(id) ON DELETE SET NULL,
  owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_private BOOLEAN NOT NULL DEFAULT false,
  is_public BOOLEAN NOT NULL DEFAULT true,
  ai_moderation BOOLEAN NOT NULL DEFAULT false,
  room_tier TEXT DEFAULT 'free',
  expires_at TIMESTAMPTZ,
  metadata JSONB DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS room_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member',
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(room_id, user_id)
);

CREATE TABLE IF NOT EXISTS room_memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member',
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(room_id, user_id)
);

CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  sender_id UUID REFERENCES users(id) ON DELETE SET NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ,
  thread_id UUID REFERENCES messages(id) ON DELETE SET NULL,
  is_pinned BOOLEAN NOT NULL DEFAULT false,
  metadata JSONB DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS read_receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  read_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(message_id, user_id)
);

CREATE TABLE IF NOT EXISTS message_receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  delivered_at TIMESTAMPTZ,
  read_at TIMESTAMPTZ,
  UNIQUE(message_id, user_id)
);

CREATE TABLE IF NOT EXISTS reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  emoji TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(message_id, user_id, emoji)
);

CREATE TABLE IF NOT EXISTS threads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  root_message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  tier TEXT NOT NULL DEFAULT 'free',
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ,
  metadata JSONB DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
  filename TEXT NOT NULL,
  s3_key TEXT NOT NULL,
  mime_type TEXT,
  size_bytes BIGINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  metadata JSONB DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS telemetry (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
  event_time TIMESTAMPTZ NOT NULL DEFAULT now(),
  payload JSONB DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS ux_telemetry (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  event_category TEXT NOT NULL,
  event_name TEXT NOT NULL,
  event_data JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  performance_data JSONB DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS presence_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
  status TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pinned_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  message_id UUID REFERENCES messages(id) ON DELETE CASCADE,
  pinned_by UUID REFERENCES users(id) ON DELETE SET NULL,
  pinned_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS nicknames (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  nickname TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, room_id)
);

CREATE TABLE IF NOT EXISTS config (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS api_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key_name VARCHAR(100) NOT NULL UNIQUE,
  key_category VARCHAR(50) NOT NULL,
  encrypted_value BYTEA NOT NULL,
  description TEXT,
  environment VARCHAR(20) DEFAULT 'production',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  last_accessed_at TIMESTAMPTZ,
  access_count INTEGER DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_users_handle ON users(handle);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_rooms_name ON rooms(name);
CREATE INDEX IF NOT EXISTS idx_rooms_creator ON rooms(creator_id);
CREATE INDEX IF NOT EXISTS idx_messages_room ON messages(room_id);
CREATE INDEX IF NOT EXISTS idx_messages_user ON messages(user_id);
CREATE INDEX IF NOT EXISTS idx_messages_created ON messages(created_at);
CREATE INDEX IF NOT EXISTS idx_room_members_room ON room_members(room_id);
CREATE INDEX IF NOT EXISTS idx_room_members_user ON room_members(user_id);
CREATE INDEX IF NOT EXISTS idx_reactions_message ON reactions(message_id);
CREATE INDEX IF NOT EXISTS idx_telemetry_event ON telemetry(event_type);
CREATE INDEX IF NOT EXISTS idx_telemetry_time ON telemetry(event_time);
CREATE INDEX IF NOT EXISTS idx_presence_logs_user ON presence_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_presence_logs_room ON presence_logs(room_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_name ON api_keys(key_name);
CREATE INDEX IF NOT EXISTS idx_api_keys_category ON api_keys(key_category);
CREATE INDEX IF NOT EXISTS idx_api_keys_environment ON api_keys(environment);
CREATE INDEX IF NOT EXISTS idx_api_keys_active ON api_keys(is_active) WHERE is_active = true;

CREATE OR REPLACE FUNCTION get_encryption_key()
RETURNS TEXT AS $$
BEGIN
  RETURN current_setting('app.encryption_key', true);
EXCEPTION
  WHEN OTHERS THEN
    RETURN 'vibez-api-keys-master-key-CHANGE-THIS-IN-PRODUCTION';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION store_api_key(
  p_key_name VARCHAR(100),
  p_key_category VARCHAR(50),
  p_value TEXT,
  p_description TEXT DEFAULT NULL,
  p_environment VARCHAR(20) DEFAULT 'production'
)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
  v_encrypted BYTEA;
  v_key_passphrase TEXT;
BEGIN
  v_key_passphrase := get_encryption_key();
  v_encrypted := pgp_sym_encrypt(p_value, v_key_passphrase);
  
  INSERT INTO api_keys (
    key_name, key_category, encrypted_value, description, environment, updated_at
  )
  VALUES (
    p_key_name, p_key_category, v_encrypted, p_description, p_environment, NOW()
  )
  ON CONFLICT (key_name) 
  DO UPDATE SET
    encrypted_value = EXCLUDED.encrypted_value,
    description = COALESCE(EXCLUDED.description, api_keys.description),
    updated_at = NOW()
  RETURNING id INTO v_id;
  
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_api_key(
  p_key_name VARCHAR(100),
  p_environment VARCHAR(20) DEFAULT 'production'
)
RETURNS TEXT AS $$
DECLARE
  v_encrypted BYTEA;
  v_key_passphrase TEXT;
  v_decrypted TEXT;
BEGIN
  SELECT encrypted_value INTO v_encrypted
  FROM api_keys
  WHERE key_name = p_key_name
    AND environment = p_environment
    AND is_active = true
  LIMIT 1;
  
  IF v_encrypted IS NULL THEN
    RAISE EXCEPTION 'API key not found: %', p_key_name;
  END IF;
  
  v_key_passphrase := get_encryption_key();
  v_decrypted := pgp_sym_decrypt(v_encrypted, v_key_passphrase);
  
  UPDATE api_keys
  SET last_accessed_at = NOW(),
      access_count = COALESCE(access_count, 0) + 1
  WHERE key_name = p_key_name
    AND environment = p_environment;
  
  RETURN v_decrypted;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE telemetry ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_keys ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own data" ON users;
CREATE POLICY "Users can read own data" ON users
  FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own data" ON users;
CREATE POLICY "Users can update own data" ON users
  FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Public rooms are readable" ON rooms;
CREATE POLICY "Public rooms are readable" ON rooms
  FOR SELECT TO public USING (is_public = true);

DROP POLICY IF EXISTS "Members can read private rooms" ON rooms;
CREATE POLICY "Members can read private rooms" ON rooms
  FOR SELECT USING (
    is_private = false OR 
    EXISTS (SELECT 1 FROM room_members WHERE room_id = rooms.id AND user_id = auth.uid())
  );

DROP POLICY IF EXISTS "Room members can read messages" ON messages;
CREATE POLICY "Room members can read messages" ON messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM rooms 
      WHERE rooms.id = messages.room_id 
      AND (rooms.is_public = true OR EXISTS (
        SELECT 1 FROM room_members 
        WHERE room_members.room_id = rooms.id 
        AND room_members.user_id = auth.uid()
      ))
    )
  );

DROP POLICY IF EXISTS "Users can create messages" ON messages;
CREATE POLICY "Users can create messages" ON messages
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION current_uid()
RETURNS UUID AS $$
  SELECT (current_setting('request.jwt.claims', true)::json->>'sub')::UUID;
$$ LANGUAGE SQL STABLE;

DROP POLICY IF EXISTS "api_keys_service_role_only" ON api_keys;
CREATE POLICY "api_keys_service_role_only" ON api_keys
  FOR ALL
  TO service_role
  USING (true);

-- 2 - VALIDATION SQL (Run after setup to verify)

SELECT 
  'Extensions' as check_type,
  extname as name,
  CASE 
    WHEN extname IN ('pgcrypto', 'pg_stat_statements', 'uuid-ossp') THEN '✅ REQUIRED'
    ELSE '📦 OPTIONAL'
  END as status
FROM pg_extension
WHERE extname IN ('pgcrypto', 'pg_stat_statements', 'uuid-ossp')
ORDER BY extname;

SELECT 
  'Core Tables' as check_type,
  table_name as name,
  CASE 
    WHEN table_name IN ('users', 'rooms', 'messages', 'room_members', 'api_keys') 
    THEN '✅ CRITICAL'
    ELSE '📋 OPTIONAL'
  END as status
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'users', 'rooms', 'messages', 'room_members', 'room_memberships',
    'read_receipts', 'message_receipts', 'reactions', 'threads',
    'subscriptions', 'files', 'telemetry', 'ux_telemetry', 'presence_logs',
    'pinned_items', 'nicknames', 'config', 'api_keys'
  )
ORDER BY 
  CASE 
    WHEN table_name IN ('users', 'rooms', 'messages', 'room_members', 'api_keys') 
    THEN 1 
    ELSE 2 
  END,
  table_name;

SELECT 
  'RLS Status' as check_type,
  tablename as name,
  CASE 
    WHEN relrowsecurity THEN '✅ ENABLED'
    ELSE '❌ DISABLED'
  END as status
FROM pg_tables t
JOIN pg_class c ON c.relname = t.tablename
WHERE t.schemaname = 'public'
  AND tablename IN ('users', 'rooms', 'messages', 'telemetry', 'room_members', 'subscriptions')
ORDER BY tablename;

SELECT 
  'Functions' as check_type,
  p.proname as name,
  '✅ EXISTS' as status
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('get_encryption_key', 'store_api_key', 'get_api_key', 'current_uid')
ORDER BY p.proname;

DO $$
DECLARE
  test_user_id UUID;
BEGIN
  INSERT INTO users (handle, display_name, age_verified)
  VALUES ('test_' || extract(epoch from now())::text, 'Test User', true)
  RETURNING id INTO test_user_id;
  
  RAISE NOTICE '✅ Test user created: %', test_user_id;
  
  DELETE FROM users WHERE id = test_user_id;
  RAISE NOTICE '✅ Test user cleaned up';
  
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE '❌ Error: %', SQLERRM;
END $$;

SELECT 
  'SUMMARY' as check_type,
  'Total Tables' as name,
  COUNT(*)::TEXT as status
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE';

-- 3 - .env FILE TEMPLATE (Copy these lines into your .env file)

-- NEXT_PUBLIC_SUPABASE_URL=https://your-project-id.supabase.co
-- SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here
-- PORT=3000
-- NODE_ENV=development
-- REDIS_URL=redis://localhost:6379
-- JWT_SECRET=dev_secret_change_in_production

