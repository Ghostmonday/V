-- ===============================================
-- FILE: 10_integrated_features.sql
-- PURPOSE: Missing tables for integrated features (assistants, bots, subscriptions, embeddings, metrics)
-- DEPENDENCIES: 01_vibez_schema.sql, 09_p0_features.sql
-- ===============================================

BEGIN;

-- ===============================================
-- AI ASSISTANTS (SIN-501)
-- ===============================================

CREATE TABLE IF NOT EXISTS assistants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  -- @llm_param - LLM model selection per assistant. User-configurable. Options: 'gpt-4', 'claude', 'deepseek'
  model VARCHAR(100) NOT NULL DEFAULT 'gpt-4', -- 'gpt-4', 'claude', 'deepseek'
  -- @llm_param - Temperature per assistant. Controls creativity/randomness. Range: 0-2. User-configurable.
  temperature DECIMAL(3,2) DEFAULT 0.7 CHECK (temperature >= 0 AND temperature <= 2),
  system_prompt TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_assistants_owner_id ON assistants (owner_id);
CREATE INDEX IF NOT EXISTS idx_assistants_is_active ON assistants (is_active) WHERE is_active = TRUE;

-- ===============================================
-- BOTS TABLE (SIN-502)
-- ===============================================

CREATE TABLE IF NOT EXISTS bots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  url VARCHAR(500) NOT NULL, -- Webhook URL for bot
  token VARCHAR(255) UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(32), 'hex'), -- Bot authentication token
  created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  is_active BOOLEAN DEFAULT TRUE,
  permissions JSONB DEFAULT '{}'::jsonb, -- Bot permissions per room
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bots_created_by ON bots (created_by);
CREATE INDEX IF NOT EXISTS idx_bots_token ON bots (token);
CREATE INDEX IF NOT EXISTS idx_bots_is_active ON bots (is_active) WHERE is_active = TRUE;

-- Update bot_endpoints to reference bots table
ALTER TABLE bot_endpoints 
  DROP CONSTRAINT IF EXISTS bot_endpoints_bot_id_fkey,
  ADD CONSTRAINT bot_endpoints_bot_id_fkey 
    FOREIGN KEY (bot_id) REFERENCES bots(id) ON DELETE CASCADE;

-- ===============================================
-- PUSH NOTIFICATION SUBSCRIPTIONS (SIN-503)
-- ===============================================

CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  push_sub JSONB NOT NULL, -- Web Push subscription object
  endpoint VARCHAR(500) NOT NULL,
  p256dh VARCHAR(255),
  auth VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT TRUE
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions (user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_is_active ON subscriptions (is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_subscriptions_endpoint ON subscriptions (endpoint);

-- ===============================================
-- VECTOR EMBEDDINGS FOR SEARCH (SIN-504)
-- ===============================================

-- Enable pgvector extension for vector similarity search
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS embeddings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  vector vector(1536) NOT NULL, -- OpenAI text-embedding-3-small dimension
  -- @llm_param - Embedding model per embedding. Controls which model generates vectors for semantic search.
  model VARCHAR(100) DEFAULT 'text-embedding-3-small',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_embeddings_message_id ON embeddings (message_id);
-- Create HNSW index for fast vector similarity search
CREATE INDEX IF NOT EXISTS idx_embeddings_vector ON embeddings 
  USING hnsw (vector vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);

-- ===============================================
-- METRICS TABLE (SIN-505)
-- ===============================================

CREATE TABLE IF NOT EXISTS metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type VARCHAR(100) NOT NULL, -- 'message_sent', 'user_active', 'room_created', etc.
  value DECIMAL(15,2) NOT NULL,
  metadata JSONB DEFAULT '{}'::jsonb,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_metrics_type ON metrics (type);
CREATE INDEX IF NOT EXISTS idx_metrics_timestamp ON metrics (timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_metrics_type_timestamp ON metrics (type, timestamp DESC);

-- ===============================================
-- PRESENCE LOGS (SIN-506)
-- ===============================================

CREATE TABLE IF NOT EXISTS presence_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
  status VARCHAR(50) NOT NULL, -- 'online', 'offline', 'away', 'busy'
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_presence_logs_user_id ON presence_logs (user_id);
CREATE INDEX IF NOT EXISTS idx_presence_logs_room_id ON presence_logs (room_id);
CREATE INDEX IF NOT EXISTS idx_presence_logs_created_at ON presence_logs (created_at DESC);

-- ===============================================
-- VECTOR SEARCH FUNCTION (SIN-507)
-- ===============================================

-- Function for semantic similarity search using pgvector
CREATE OR REPLACE FUNCTION match_messages(
  query_embedding vector(1536),
  -- @llm_param - Similarity threshold for semantic search. Controls how similar messages must be to match. Higher = stricter.
  match_threshold float DEFAULT 0.78,
  -- @llm_param - Maximum number of matching messages to return. Controls search result count.
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
-- TRIGGERS AND FUNCTIONS
-- ===============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
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

COMMIT;

