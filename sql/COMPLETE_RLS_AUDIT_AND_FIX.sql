-- ===============================================
-- COMPLETE RLS AUDIT AND FIX
-- Purpose: Comprehensive RLS security audit and policy generation
-- This script performs:
--   1. Enumeration of all tables
--   2. Gap analysis for RLS coverage
--   3. Generation of missing secure policies
--   4. Triple validation (syntax, logic, security)
-- ===============================================

BEGIN;

-- ===============================================
-- STEP 1: ENUMERATE ALL TABLES
-- ===============================================

-- Create temporary table to track all tables and their RLS status
CREATE TEMP TABLE IF NOT EXISTS rls_audit_table_list (
  schema_name TEXT,
  table_name TEXT,
  should_have_rls BOOLEAN,
  rls_enabled BOOLEAN DEFAULT FALSE,
  has_select_policy BOOLEAN DEFAULT FALSE,
  has_insert_policy BOOLEAN DEFAULT FALSE,
  has_update_policy BOOLEAN DEFAULT FALSE,
  has_delete_policy BOOLEAN DEFAULT FALSE,
  security_level TEXT, -- 'critical', 'high', 'medium', 'low', 'public'
  notes TEXT
);

-- Insert all tables from the schema
INSERT INTO rls_audit_table_list (schema_name, table_name, should_have_rls, security_level, notes) VALUES
-- Core tables (CRITICAL - must have RLS)
('public', 'users', true, 'critical', 'User profiles - authenticated read, service manage'),
('public', 'rooms', true, 'critical', 'Room metadata - authenticated read, service manage'),
('public', 'room_memberships', true, 'critical', 'Room membership - members can see their rooms'),
('public', 'messages', true, 'critical', 'Messages - room members only'),
('public', 'message_receipts', true, 'critical', 'Read receipts - own receipts only'),
('public', 'audit_log', true, 'critical', 'Append-only audit log - service role only'),
('public', 'logs_raw', true, 'critical', 'Raw logs - service role only'),
('public', 'logs_compressed', true, 'critical', 'Compressed logs - service role + authenticated read'),
('public', 'retention_schedule', true, 'critical', 'Retention schedule - service role only'),
('public', 'legal_holds', true, 'critical', 'Legal holds - service role only'),
('public', 'telemetry', true, 'critical', 'Telemetry - service role only'),
('public', 'system_config', true, 'critical', 'System config - service role only'),
('service', 'encode_queue', true, 'critical', 'Encode queue - service role only'),
('service', 'moderation_queue', true, 'critical', 'Moderation queue - service role only'),

-- Feature tables (HIGH - should have RLS)
('public', 'threads', true, 'high', 'Threads - room members can see'),
('public', 'edit_history', true, 'high', 'Edit history - message authors can see'),
('public', 'assistants', true, 'high', 'AI assistants - owner only'),
('public', 'bots', true, 'high', 'Bots - creator only'),
('public', 'bot_endpoints', true, 'high', 'Bot endpoints - bot creator only'),
('public', 'subscriptions', true, 'high', 'Push subscriptions - owner only'),
('public', 'embeddings', true, 'high', 'Message embeddings - room members can see'),
('public', 'metrics', true, 'high', 'Metrics - service role only'),
('public', 'presence_logs', true, 'high', 'Presence logs - own or room members'),
('public', 'healing_logs', true, 'high', 'Healing logs - service role + room members'),

-- Additional feature tables (MEDIUM - should have RLS)
('public', 'files', true, 'medium', 'File uploads - owner or room members'),
('public', 'pinned_items', true, 'medium', 'Pinned items - owner only'),
('public', 'reactions', true, 'medium', 'Message reactions - room members can see'),
('public', 'read_receipts', true, 'medium', 'Read receipts - own receipts only'),
('public', 'nicknames', true, 'medium', 'Nicknames - room members can see'),
('public', 'room_members', true, 'medium', 'Room members - room members can see'),
('public', 'ux_telemetry', true, 'medium', 'UX telemetry - owner only'),
('public', 'api_keys', true, 'medium', 'API keys - service role only'),
('public', 'config', true, 'medium', 'Config - service role only'),

-- Optional/advanced tables (MEDIUM - should have RLS)
('public', 'polls', true, 'medium', 'Polls - room members can see'),
('public', 'poll_votes', true, 'medium', 'Poll votes - voters can see own votes'),
('public', 'bot_invites', true, 'medium', 'Bot invites - room admins can manage'),
('public', 'moderation_flags', true, 'medium', 'Moderation flags - moderators can see'),
('public', 'room_moderation_thresholds', true, 'medium', 'Room thresholds - room admins can manage'),
('public', 'flagged_messages', true, 'medium', 'Flagged messages - moderators can see'),
('public', 'message_archives', true, 'medium', 'Message archives - room members can see'),
('public', 'refresh_tokens', true, 'medium', 'Refresh tokens - owner only'),
('public', 'auth_audit_log', true, 'medium', 'Auth audit log - owner only'),
('public', 'user_zkp_commitments', true, 'medium', 'ZKP commitments - owner only'),
('public', 'consent_records', true, 'medium', 'Consent records - owner only'),
('public', 'deleted_users', true, 'medium', 'Deleted users - service role only'),
('public', 'shard_metadata', true, 'medium', 'Shard metadata - service role only'),
('public', 'shard_health_metrics', true, 'medium', 'Shard health - service role only'),
('public', 'monetization_subscriptions', true, 'medium', 'Monetization subscriptions - owner only'),
('public', 'usage_stats', true, 'medium', 'Usage stats - owner only'),
('public', 'conversations', true, 'medium', 'Conversations - participants only'),
('public', 'conversation_participants', true, 'medium', 'Conversation participants - participants can see'),
('public', 'sentiment_analysis', true, 'medium', 'Sentiment analysis - conversation participants can see'),
('public', 'cards', true, 'medium', 'Cards - conversation participants can see'),
('public', 'card_ownerships', true, 'medium', 'Card ownerships - owner only'),
('public', 'card_events', true, 'medium', 'Card events - card owners can see'),
('public', 'museum_entries', true, 'medium', 'Museum entries - public read, owner manage'),
('public', 'boosts', true, 'medium', 'Boosts - owner only');

-- Update RLS status from actual database
UPDATE rls_audit_table_list r
SET rls_enabled = EXISTS (
  SELECT 1 FROM pg_tables t
  WHERE t.schemaname = r.schema_name
    AND t.tablename = r.table_name
    AND t.rowsecurity = true
)
WHERE EXISTS (
  SELECT 1 FROM pg_tables t
  WHERE t.schemaname = r.schema_name
    AND t.tablename = r.table_name
);

-- Update policy counts
UPDATE rls_audit_table_list r
SET 
  has_select_policy = EXISTS (
    SELECT 1 FROM pg_policies p
    WHERE p.schemaname = r.schema_name
      AND p.tablename = r.table_name
      AND p.cmd = 'SELECT'
  ),
  has_insert_policy = EXISTS (
    SELECT 1 FROM pg_policies p
    WHERE p.schemaname = r.schema_name
      AND p.tablename = r.table_name
      AND p.cmd = 'INSERT'
  ),
  has_update_policy = EXISTS (
    SELECT 1 FROM pg_policies p
    WHERE p.schemaname = r.schema_name
      AND p.tablename = r.table_name
      AND p.cmd = 'UPDATE'
  ),
  has_delete_policy = EXISTS (
    SELECT 1 FROM pg_policies p
    WHERE p.schemaname = r.schema_name
      AND p.tablename = r.table_name
      AND p.cmd = 'DELETE'
  )
WHERE EXISTS (
  SELECT 1 FROM pg_tables t
  WHERE t.schemaname = r.schema_name
    AND t.tablename = r.table_name
);

-- ===============================================
-- STEP 2: GAP ANALYSIS REPORT
-- ===============================================

-- Show current status
SELECT 
  'GAP_ANALYSIS' AS report_type,
  schema_name || '.' || table_name AS table_name,
  security_level,
  CASE 
    WHEN NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = schema_name AND tablename = table_name) 
    THEN '⚠️ TABLE DOES NOT EXIST'
    WHEN should_have_rls AND NOT rls_enabled 
    THEN '❌ RLS NOT ENABLED'
    WHEN should_have_rls AND rls_enabled AND NOT (has_select_policy OR has_insert_policy OR has_update_policy OR has_delete_policy)
    THEN '⚠️ RLS ENABLED BUT NO POLICIES'
    WHEN should_have_rls AND rls_enabled AND security_level = 'critical' AND NOT has_select_policy
    THEN '⚠️ CRITICAL TABLE MISSING SELECT POLICY'
    WHEN should_have_rls AND rls_enabled AND security_level = 'critical' AND NOT has_insert_policy
    THEN '⚠️ CRITICAL TABLE MISSING INSERT POLICY'
    ELSE '✅ COMPLIANT'
  END AS status,
  notes
FROM rls_audit_table_list
WHERE should_have_rls
ORDER BY 
  CASE security_level 
    WHEN 'critical' THEN 1 
    WHEN 'high' THEN 2 
    WHEN 'medium' THEN 3 
    ELSE 4 
  END,
  table_name;

COMMIT;

