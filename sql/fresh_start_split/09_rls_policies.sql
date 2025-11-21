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

-- Additional Feature Tables (Ensure RLS is enabled)
ALTER TABLE edit_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE bot_endpoints ENABLE ROW LEVEL SECURITY;
ALTER TABLE metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE sentiment_analysis ENABLE ROW LEVEL SECURITY;
ALTER TABLE cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE card_ownerships ENABLE ROW LEVEL SECURITY;
ALTER TABLE card_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE museum_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE boosts ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_violations ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_mutes ENABLE ROW LEVEL SECURITY;

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
