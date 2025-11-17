-- ===============================================
-- FILE: 2025-01-XX-phase9-sharding.sql
-- PURPOSE: Phase 9.1 - Database Sharding Support
-- DEPENDENCIES: 01_sinapse_schema.sql
-- ===============================================

SET search_path TO service, public;

-- ===============================================
-- SHARD METADATA TABLE
-- ===============================================

-- Store shard configuration and metadata
CREATE TABLE IF NOT EXISTS shard_metadata (
  shard_id TEXT PRIMARY KEY,
  database_url TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  weight INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  metadata JSONB DEFAULT '{}'::jsonb,
  health_status TEXT DEFAULT 'unknown', -- 'healthy', 'degraded', 'unhealthy'
  last_health_check TIMESTAMPTZ
);

-- Index for active shards
CREATE INDEX IF NOT EXISTS idx_shard_metadata_active ON shard_metadata (is_active) WHERE is_active = true;

-- ===============================================
-- SHARD HEALTH METRICS TABLE
-- ===============================================

-- Track shard health metrics over time
CREATE TABLE IF NOT EXISTS shard_health_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shard_id TEXT NOT NULL REFERENCES shard_metadata(shard_id) ON DELETE CASCADE,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
  latency_ms NUMERIC,
  error_count INTEGER DEFAULT 0,
  query_count INTEGER DEFAULT 0,
  error_rate NUMERIC GENERATED ALWAYS AS (
    CASE 
      WHEN query_count > 0 THEN error_count::NUMERIC / query_count::NUMERIC
      ELSE 0
    END
  ) STORED,
  is_healthy BOOLEAN DEFAULT true
);

-- Index for shard health queries
CREATE INDEX IF NOT EXISTS idx_shard_health_shard_time ON shard_health_metrics (shard_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_shard_health_unhealthy ON shard_health_metrics (is_healthy) WHERE is_healthy = false;

-- ===============================================
-- SHARD ROUTING FUNCTION
-- ===============================================

-- Function to get shard ID for a room_id
-- Uses consistent hashing for distribution
CREATE OR REPLACE FUNCTION get_shard_for_room(room_id UUID)
RETURNS TEXT AS $$
DECLARE
  shard_count INTEGER;
  hash_value BIGINT;
  shard_index INTEGER;
BEGIN
  -- Get number of active shards
  SELECT COUNT(*) INTO shard_count
  FROM shard_metadata
  WHERE is_active = true;
  
  -- If no shards configured, return default
  IF shard_count = 0 THEN
    RETURN 'shard_0';
  END IF;
  
  -- Simple hash function (in production, use consistent hashing)
  hash_value := abs(hashtext(room_id::TEXT));
  shard_index := hash_value % shard_count;
  
  -- Get shard_id at index (ordered by shard_id)
  SELECT shard_id INTO shard_index
  FROM (
    SELECT shard_id, ROW_NUMBER() OVER (ORDER BY shard_id) - 1 as idx
    FROM shard_metadata
    WHERE is_active = true
    ORDER BY shard_id
  ) ranked
  WHERE idx = shard_index;
  
  RETURN COALESCE(shard_index, 'shard_0');
END;
$$ LANGUAGE plpgsql STABLE;

-- ===============================================
-- SHARD HEALTH UPDATE FUNCTION
-- ===============================================

-- Function to update shard health status
CREATE OR REPLACE FUNCTION update_shard_health(
  p_shard_id TEXT,
  p_latency_ms NUMERIC,
  p_error_count INTEGER DEFAULT 0,
  p_query_count INTEGER DEFAULT 1
)
RETURNS VOID AS $$
BEGIN
  -- Insert health metrics
  INSERT INTO shard_health_metrics (shard_id, latency_ms, error_count, query_count, is_healthy)
  VALUES (
    p_shard_id,
    p_latency_ms,
    p_error_count,
    p_query_count,
    CASE 
      WHEN p_latency_ms > 1000 OR (p_query_count > 0 AND p_error_count::NUMERIC / p_query_count::NUMERIC > 0.1) 
      THEN false 
      ELSE true 
    END
  );
  
  -- Update shard metadata health status
  UPDATE shard_metadata
  SET 
    health_status = CASE 
      WHEN p_latency_ms > 1000 THEN 'unhealthy'
      WHEN p_latency_ms > 500 OR (p_query_count > 0 AND p_error_count::NUMERIC / p_query_count::NUMERIC > 0.05) THEN 'degraded'
      ELSE 'healthy'
    END,
    last_health_check = now(),
    updated_at = now()
  WHERE shard_id = p_shard_id;
END;
$$ LANGUAGE plpgsql;

-- ===============================================
-- INITIAL SHARD CONFIGURATION
-- ===============================================

-- Insert default shard (current database)
INSERT INTO shard_metadata (shard_id, database_url, is_active, weight, health_status)
VALUES ('shard_0', current_database(), true, 1, 'healthy')
ON CONFLICT (shard_id) DO NOTHING;

-- ===============================================
-- VERIFICATION
-- ===============================================

-- Verify shard metadata table exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'shard_metadata') THEN
    RAISE EXCEPTION 'shard_metadata table not created';
  END IF;
END $$;

-- Verify functions exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_shard_for_room') THEN
    RAISE EXCEPTION 'get_shard_for_room function not created';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_shard_health') THEN
    RAISE EXCEPTION 'update_shard_health function not created';
  END IF;
END $$;

-- Log completion
DO $$
BEGIN
  RAISE NOTICE 'Phase 9.1 sharding migration completed successfully';
END $$;

