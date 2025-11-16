-- ===============================================
-- FILE: 11_indexing_and_rls.sql
-- PURPOSE: Performance indexes, RLS policies, and AI integration points
-- DEPENDENCIES: 01_vibez_schema.sql, 09_p0_features.sql, 10_integrated_features.sql
-- ===============================================

BEGIN;

-- ===============================================
-- 1. TABLE INDEXING REQUIREMENTS
-- ===============================================

-- Telemetry indexes (fixed: column is 'event', not 'event_type')
CREATE INDEX IF NOT EXISTS idx_telemetry_event ON telemetry (event);
CREATE INDEX IF NOT EXISTS idx_telemetry_event_time ON telemetry (event_time DESC);
CREATE INDEX IF NOT EXISTS idx_telemetry_user_id ON telemetry (user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_telemetry_room_id ON telemetry (room_id) WHERE room_id IS NOT NULL;
-- Partial index for specific events
CREATE INDEX IF NOT EXISTS idx_telemetry_msg_sent ON telemetry (event_time DESC, user_id) 
  WHERE event = 'msg_sent';

-- Logs indexes (using logs_raw and audit_log)
CREATE INDEX IF NOT EXISTS idx_logs_raw_created_at ON logs_raw (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_logs_raw_room_created ON logs_raw (room_id, created_at DESC);

-- Audit log indexes
CREATE INDEX IF NOT EXISTS idx_audit_log_action ON audit_log (event_type);
CREATE INDEX IF NOT EXISTS idx_audit_log_entity_id ON audit_log (message_id, room_id, user_id) 
  WHERE message_id IS NOT NULL OR room_id IS NOT NULL OR user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_audit_log_timestamp ON audit_log (event_time DESC);

-- Metrics indexes
CREATE INDEX IF NOT EXISTS idx_metrics_type_target ON metrics (type, metadata);
CREATE INDEX IF NOT EXISTS idx_metrics_type_timestamp ON metrics (type, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_metrics_created_at ON metrics (timestamp DESC);

-- Users indexes
CREATE INDEX IF NOT EXISTS idx_users_handle ON users (handle);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users (created_at DESC);
-- Note: email would be in metadata JSONB, so we'll index that
CREATE INDEX IF NOT EXISTS idx_users_metadata_email ON users USING GIN (metadata) 
  WHERE metadata ? 'email';

-- Presence logs indexes
CREATE INDEX IF NOT EXISTS idx_presence_logs_room_user ON presence_logs (room_id, user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_presence_logs_user_created ON presence_logs (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_presence_logs_room_created ON presence_logs (room_id, created_at DESC);

-- Room memberships indexes
CREATE INDEX IF NOT EXISTS idx_room_memberships_room_user ON room_memberships (room_id, user_id);
CREATE INDEX IF NOT EXISTS idx_room_memberships_user_role ON room_memberships (user_id, role);
CREATE INDEX IF NOT EXISTS idx_room_memberships_role ON room_memberships (role) WHERE role IN ('admin', 'mod');

-- Bots indexes (fixed: column is 'created_by', not 'owner_id')
CREATE INDEX IF NOT EXISTS idx_bots_name ON bots (name);
CREATE INDEX IF NOT EXISTS idx_bots_created_by ON bots (created_by);
CREATE INDEX IF NOT EXISTS idx_bots_is_active ON bots (is_active) WHERE is_active = TRUE;

-- Bot endpoints indexes
CREATE INDEX IF NOT EXISTS idx_bot_endpoints_bot_status ON bot_endpoints (bot_id, is_active);
CREATE INDEX IF NOT EXISTS idx_bot_endpoints_status ON bot_endpoints (is_active) WHERE is_active = TRUE;
-- Note: last_ping would need to be added to the table or tracked in metadata

-- Composite indexes for joins
-- owns (user_id, room_id) - via room_memberships
CREATE INDEX IF NOT EXISTS idx_room_memberships_user_room_composite ON room_memberships (user_id, room_id);

-- creates (user_id, message_id) - via messages.sender_id
CREATE INDEX IF NOT EXISTS idx_messages_sender_created ON messages (sender_id, id, created_at DESC);

-- has (thread_id, message_id) - via messages.thread_id
CREATE INDEX IF NOT EXISTS idx_messages_thread_id_composite ON messages (thread_id, id) WHERE thread_id IS NOT NULL;

-- Embeddings indexes (already has HNSW, but adding content_id reference)
CREATE INDEX IF NOT EXISTS idx_embeddings_message_id_created ON embeddings (message_id, created_at DESC);

-- ===============================================
-- 2. RLS POLICIES & CONTROL POINTS
-- ===============================================

-- Enable RLS on all tables
ALTER TABLE telemetry ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE bots ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE presence_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE assistants ENABLE ROW LEVEL SECURITY;
ALTER TABLE threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_memberships ENABLE ROW LEVEL SECURITY;

-- Helper functions in public schema (Supabase protects auth schema)
-- Get current user ID from JWT
CREATE OR REPLACE FUNCTION public.current_uid() RETURNS UUID AS $$
  SELECT (current_setting('request.jwt.claims', true)::json->>'sub')::UUID;
$$ LANGUAGE SQL STABLE;

-- Get current user role from JWT
CREATE OR REPLACE FUNCTION public.current_role() RETURNS TEXT AS $$
  SELECT COALESCE(
    (current_setting('request.jwt.claims', true)::json->>'role')::TEXT,
    'user'
  );
$$ LANGUAGE SQL STABLE;

-- Helper function to check if user is moderator/admin
CREATE OR REPLACE FUNCTION is_moderator(user_id UUID) RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM room_memberships
    WHERE user_id = $1
    AND role IN ('mod', 'admin', 'owner')
  );
$$ LANGUAGE SQL STABLE;

-- Helper function to get allowed bot IDs for a user
CREATE OR REPLACE FUNCTION allowed_bots(user_id UUID) RETURNS UUID[] AS $$
  SELECT ARRAY_AGG(id) FROM bots
  WHERE created_by = user_id AND is_active = TRUE;
$$ LANGUAGE SQL STABLE;

-- TELEMETRY RLS: Read-only, user can only see their own
CREATE POLICY telemetry_read_own ON telemetry
  FOR SELECT
  USING (user_id = current_uid() OR user_id IS NULL);

-- MESSAGES RLS: Read/write for bots, users can read/write their own
CREATE POLICY messages_read_own ON messages
  FOR SELECT
  USING (
    sender_id = current_uid() 
    OR room_id IN (SELECT room_id FROM room_memberships WHERE user_id = current_uid())
    OR sender_id IN (SELECT UNNEST(allowed_bots(current_uid())))
  );

CREATE POLICY messages_write_own ON messages
  FOR INSERT
  WITH CHECK (
    sender_id = current_uid() 
    OR sender_id IN (SELECT UNNEST(allowed_bots(current_uid())))
  );

CREATE POLICY messages_update_own ON messages
  FOR UPDATE
  USING (sender_id = current_uid())
  WITH CHECK (sender_id = current_uid());

-- BOTS RLS: Admin only (owner can manage their bots)
CREATE POLICY bots_read_own ON bots
  FOR SELECT
  USING (created_by = current_uid() OR current_role() = 'admin');

CREATE POLICY bots_write_own ON bots
  FOR INSERT
  WITH CHECK (created_by = current_uid());

CREATE POLICY bots_update_own ON bots
  FOR UPDATE
  USING (created_by = current_uid() OR current_role() = 'admin')
  WITH CHECK (created_by = current_uid() OR current_role() = 'admin');

CREATE POLICY bots_delete_own ON bots
  FOR DELETE
  USING (created_by = current_uid() OR current_role() = 'admin');

-- AUDIT LOGS RLS: View for moderators
CREATE POLICY audit_logs_read_moderators ON audit_log
  FOR SELECT
  USING (
    is_moderator(current_uid()) 
    OR current_role() = 'admin'
    OR user_id = current_uid() -- Users can see their own audit entries
  );

-- PRESENCE LOGS RLS: Read-only, user can see their own or public rooms
CREATE POLICY presence_logs_read_own ON presence_logs
  FOR SELECT
  USING (
    user_id = current_uid() 
    OR room_id IN (
      SELECT id FROM rooms WHERE is_public = TRUE
    )
  );

-- EMBEDDINGS RLS: Read/write for AI layer (content owner)
CREATE POLICY embeddings_read_own ON embeddings
  FOR SELECT
  USING (
    message_id IN (
      SELECT id FROM messages 
      WHERE sender_id = current_uid()
      OR sender_id IN (SELECT UNNEST(allowed_bots(current_uid())))
    )
  );

CREATE POLICY embeddings_write_own ON embeddings
  FOR INSERT
  WITH CHECK (
    message_id IN (
      SELECT id FROM messages 
      WHERE sender_id = current_uid()
      OR sender_id IN (SELECT UNNEST(allowed_bots(current_uid())))
    )
  );

-- SUBSCRIPTIONS RLS: Write (user-owned)
CREATE POLICY subscriptions_read_own ON subscriptions
  FOR SELECT
  USING (user_id = current_uid());

CREATE POLICY subscriptions_write_own ON subscriptions
  FOR INSERT
  WITH CHECK (user_id = current_uid());

CREATE POLICY subscriptions_update_own ON subscriptions
  FOR UPDATE
  USING (user_id = current_uid())
  WITH CHECK (user_id = current_uid());

CREATE POLICY subscriptions_delete_own ON subscriptions
  FOR DELETE
  USING (user_id = current_uid());

-- ASSISTANTS RLS: Owner only
CREATE POLICY assistants_read_own ON assistants
  FOR SELECT
  USING (owner_id = current_uid());

CREATE POLICY assistants_write_own ON assistants
  FOR INSERT
  WITH CHECK (owner_id = current_uid());

CREATE POLICY assistants_update_own ON assistants
  FOR UPDATE
  USING (owner_id = current_uid())
  WITH CHECK (owner_id = current_uid());

CREATE POLICY assistants_delete_own ON assistants
  FOR DELETE
  USING (owner_id = current_uid());

-- THREADS RLS: Users can read threads in rooms they're members of
CREATE POLICY threads_read_member ON threads
  FOR SELECT
  USING (
    room_id IN (SELECT room_id FROM room_memberships WHERE user_id = current_uid())
    OR created_by = current_uid()
  );

CREATE POLICY threads_write_member ON threads
  FOR INSERT
  WITH CHECK (
    room_id IN (SELECT room_id FROM room_memberships WHERE user_id = current_uid())
    AND created_by = current_uid()
  );

-- ROOM MEMBERSHIPS RLS: Users can see memberships in rooms they're in
CREATE POLICY room_memberships_read_member ON room_memberships
  FOR SELECT
  USING (
    room_id IN (SELECT room_id FROM room_memberships WHERE user_id = current_uid())
    OR user_id = current_uid()
  );

-- ===============================================
-- 3. AI-INTEGRATION HOTSPOTS (DeepSeek API Control Zones)
-- ===============================================

-- View for Bot Monitoring (failure analysis)
CREATE OR REPLACE VIEW ai_bot_monitoring AS
SELECT 
  b.id AS bot_id,
  b.name AS bot_name,
  b.created_by,
  COUNT(be.id) AS endpoint_count,
  COUNT(CASE WHEN be.is_active = FALSE THEN 1 END) AS inactive_endpoints,
  (SELECT COUNT(*) FROM audit_log 
   WHERE payload->>'bot_id' = b.id::text 
   AND event_type = 'bot_error'
   AND event_time > NOW() - INTERVAL '24 hours') AS errors_24h
FROM bots b
LEFT JOIN bot_endpoints be ON be.bot_id = b.id
GROUP BY b.id, b.name, b.created_by;

-- View for Message Quality Control (content analysis)
CREATE OR REPLACE VIEW ai_message_quality AS
SELECT 
  m.id,
  m.room_id,
  m.sender_id,
  m.content_preview,
  m.is_flagged,
  m.flags,
  m.created_at,
  (SELECT COUNT(*) FROM message_receipts WHERE message_id = m.id) AS receipt_count,
  CASE 
    WHEN m.is_flagged = TRUE THEN 'flagged'
    -- @llm_param - Toxicity score threshold for high-risk classification. Messages with toxicity > 0.7 are marked high-risk.
    WHEN m.flags->>'toxicity_score' IS NOT NULL 
      AND (m.flags->>'toxicity_score')::float > 0.7 THEN 'high_risk'
    ELSE 'normal'
  END AS quality_status
FROM messages m
WHERE m.created_at > NOW() - INTERVAL '7 days';

-- View for Presence Trends (behavior patterns)
CREATE OR REPLACE VIEW ai_presence_trends AS
SELECT 
  pl.user_id,
  pl.room_id,
  pl.status,
  DATE_TRUNC('hour', pl.created_at) AS hour_bucket,
  COUNT(*) AS status_count,
  AVG(EXTRACT(EPOCH FROM (NOW() - pl.created_at))) AS avg_age_seconds
FROM presence_logs pl
WHERE pl.created_at > NOW() - INTERVAL '30 days'
GROUP BY pl.user_id, pl.room_id, pl.status, DATE_TRUNC('hour', pl.created_at);

-- View for Audit Trail Analysis (user actions summary)
CREATE OR REPLACE VIEW ai_audit_summary AS
SELECT 
  al.user_id,
  al.event_type,
  COUNT(*) AS event_count,
  MIN(al.event_time) AS first_occurrence,
  MAX(al.event_time) AS last_occurrence,
  jsonb_object_agg(
    al.event_type, 
    jsonb_build_object(
      'count', COUNT(*),
      'recent', COUNT(*) FILTER (WHERE al.event_time > NOW() - INTERVAL '24 hours')
    )
  ) AS event_summary
FROM audit_log al
WHERE al.event_time > NOW() - INTERVAL '30 days'
GROUP BY al.user_id, al.event_type;

-- View for Query Performance (slow query detection)
CREATE OR REPLACE VIEW ai_query_performance AS
SELECT 
  t.event_time,
  t.event,
  t.latency_ms,
  t.room_id,
  t.user_id,
  CASE 
    WHEN t.latency_ms > 1000 THEN 'slow'
    WHEN t.latency_ms > 500 THEN 'moderate'
    ELSE 'fast'
  END AS performance_category
FROM telemetry t
WHERE t.event LIKE '%query%' OR t.event LIKE '%db%'
ORDER BY t.latency_ms DESC;

-- View for Moderation Suggestions (policy analysis)
CREATE OR REPLACE VIEW ai_moderation_suggestions AS
SELECT 
  m.room_id,
  COUNT(*) FILTER (WHERE m.is_flagged = TRUE) AS flagged_count,
  COUNT(*) AS total_messages,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE m.is_flagged = TRUE) / NULLIF(COUNT(*), 0),
    2
  ) AS flag_percentage,
  AVG((m.flags->>'toxicity_score')::float) AS avg_toxicity,
  MAX(m.created_at) AS last_message_time
FROM messages m
WHERE m.created_at > NOW() - INTERVAL '7 days'
GROUP BY m.room_id
HAVING COUNT(*) FILTER (WHERE m.is_flagged = TRUE) > 5;

-- View for Telemetry Insights (aggregated events)
CREATE OR REPLACE VIEW ai_telemetry_insights AS
SELECT 
  t.event,
  DATE_TRUNC('hour', t.event_time) AS hour_bucket,
  COUNT(*) AS event_count,
  AVG(t.latency_ms) AS avg_latency,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY t.latency_ms) AS p95_latency,
  COUNT(DISTINCT t.user_id) AS unique_users,
  COUNT(DISTINCT t.room_id) AS unique_rooms
FROM telemetry t
WHERE t.event_time > NOW() - INTERVAL '24 hours'
GROUP BY t.event, DATE_TRUNC('hour', t.event_time)
ORDER BY event_count DESC;

-- Function for AI to analyze bot failures
CREATE OR REPLACE FUNCTION ai_analyze_bot_failures(bot_id_param UUID, hours_back INT DEFAULT 24)
RETURNS TABLE (
  bot_name TEXT,
  error_count BIGINT,
  last_error TIMESTAMPTZ,
  error_types JSONB,
  recommendation TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    b.name::TEXT,
    COUNT(*)::BIGINT,
    MAX(al.event_time)::TIMESTAMPTZ,
    jsonb_object_agg(al.event_type, COUNT(*))::JSONB,
    CASE 
      WHEN COUNT(*) > 10 THEN 'Consider deactivating bot - high error rate'
      WHEN COUNT(*) > 5 THEN 'Review bot configuration - moderate error rate'
      ELSE 'Bot operating normally'
    END::TEXT AS recommendation
  FROM bots b
  LEFT JOIN audit_log al ON al.payload->>'bot_id' = b.id::text
    AND al.event_type LIKE '%error%'
    AND al.event_time > NOW() - (hours_back || ' hours')::INTERVAL
  WHERE b.id = bot_id_param
  GROUP BY b.id, b.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function for AI to get moderation recommendations
CREATE OR REPLACE FUNCTION ai_moderation_recommendations(room_id_param UUID DEFAULT NULL)
RETURNS TABLE (
  room_id UUID,
  flagged_rate NUMERIC,
  avg_toxicity NUMERIC,
  recommendation TEXT,
  suggested_action TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    m.room_id,
    ROUND(100.0 * COUNT(*) FILTER (WHERE m.is_flagged = TRUE) / NULLIF(COUNT(*), 0), 2) AS flagged_rate,
    AVG((m.flags->>'toxicity_score')::float) AS avg_toxicity,
    CASE 
      -- @llm_param - High toxicity threshold (0.8). Triggers recommendation for stricter moderation.
      WHEN AVG((m.flags->>'toxicity_score')::float) > 0.8 THEN 'High toxicity detected - consider stricter moderation'
      -- @llm_param - Moderate toxicity threshold (0.6). Triggers monitoring recommendation.
      WHEN AVG((m.flags->>'toxicity_score')::float) > 0.6 THEN 'Moderate toxicity - monitor closely'
      ELSE 'Normal activity'
    END::TEXT AS recommendation,
    CASE 
      WHEN COUNT(*) FILTER (WHERE m.is_flagged = TRUE) > 10 THEN 'Enable auto-moderation for this room'
      WHEN COUNT(*) FILTER (WHERE m.is_flagged = TRUE) > 5 THEN 'Increase moderation frequency'
      ELSE 'Current moderation sufficient'
    END::TEXT AS suggested_action
  FROM messages m
  WHERE m.created_at > NOW() - INTERVAL '7 days'
    AND (room_id_param IS NULL OR m.room_id = room_id_param)
  GROUP BY m.room_id
  HAVING COUNT(*) > 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function for AI to detect presence dropouts
CREATE OR REPLACE FUNCTION ai_detect_presence_dropouts(hours_threshold INT DEFAULT 2)
RETURNS TABLE (
  user_id UUID,
  room_id UUID,
  last_seen TIMESTAMPTZ,
  hours_absent NUMERIC,
  status TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pl.user_id,
    pl.room_id,
    MAX(pl.created_at)::TIMESTAMPTZ AS last_seen,
    EXTRACT(EPOCH FROM (NOW() - MAX(pl.created_at))) / 3600.0 AS hours_absent,
    CASE 
      WHEN EXTRACT(EPOCH FROM (NOW() - MAX(pl.created_at))) / 3600.0 > hours_threshold THEN 'potential_dropout'
      ELSE 'active'
    END::TEXT AS status
  FROM presence_logs pl
  WHERE pl.status = 'online'
  GROUP BY pl.user_id, pl.room_id
  HAVING MAX(pl.created_at) < NOW() - (hours_threshold || ' hours')::INTERVAL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant access to AI views (adjust based on your AI service user)
-- CREATE ROLE ai_service WITH LOGIN;
-- GRANT SELECT ON ai_bot_monitoring, ai_message_quality, ai_presence_trends, 
--   ai_audit_summary, ai_query_performance, ai_moderation_suggestions, 
--   ai_telemetry_insights TO ai_service;
-- GRANT EXECUTE ON FUNCTION ai_analyze_bot_failures, ai_moderation_recommendations, 
--   ai_detect_presence_dropouts TO ai_service;

COMMIT;

-- ===============================================
-- NOTES
-- ===============================================
-- 1. All indexes are created with IF NOT EXISTS for idempotency
-- 2. RLS policies use helper functions for JWT claims extraction
-- 3. AI views provide aggregated data for LLM analysis
-- 4. AI functions return structured recommendations
-- 5. Adjust RLS policies based on your authentication setup
-- 6. Create an 'ai_service' role if you want dedicated AI access

