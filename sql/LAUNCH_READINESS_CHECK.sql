-- ===============================================
-- DATABASE LAUNCH READINESS AUDIT
-- Purpose: Verify all critical components are in place for production launch
-- Run this before deploying to production
-- ===============================================

BEGIN;

-- ===============================================
-- 1. REQUIRED EXTENSIONS
-- ===============================================
SELECT 
  'EXTENSIONS' AS category,
  extname AS name,
  CASE 
    WHEN extname IS NOT NULL THEN '✅ INSTALLED'
    ELSE '❌ MISSING'
  END AS status
FROM pg_extension
WHERE extname IN ('pgcrypto', 'pg_stat_statements', 'vector', 'uuid-ossp')
ORDER BY extname;

-- Check for missing extensions
SELECT 
  'EXTENSIONS' AS category,
  req.extname AS required_extension,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM pg_extension 
      WHERE extname = req.extname
    ) THEN '✅ INSTALLED'
    ELSE '❌ MISSING'
  END AS status
FROM (VALUES 
  ('pgcrypto'),
  ('pg_stat_statements'),
  ('vector'),
  ('uuid-ossp')
) AS req(extname);

-- ===============================================
-- 2. REQUIRED TABLES (Core Schema)
-- ===============================================
SELECT 
  'CORE_TABLES' AS category,
  table_name,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name = t.table_name
    ) THEN '✅ EXISTS'
    ELSE '❌ MISSING'
  END AS status
FROM (
  VALUES 
    ('users'),
    ('rooms'),
    ('room_memberships'),
    ('messages'),
    ('message_receipts'),
    ('audit_log'),
    ('logs_raw'),
    ('logs_compressed'),
    ('retention_schedule'),
    ('legal_holds'),
    ('telemetry'),
    ('system_config'),
    ('service.encode_queue'),
    ('service.moderation_queue')
) AS t(table_name);

-- ===============================================
-- 3. REQUIRED TABLES (Feature Tables)
-- ===============================================
SELECT 
  'FEATURE_TABLES' AS category,
  table_name,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name = t.table_name
    ) THEN '✅ EXISTS'
    ELSE '❌ MISSING'
  END AS status
FROM (
  VALUES 
    ('threads'),
    ('edit_history'),
    ('assistants'),
    ('bots'),
    ('bot_endpoints'),
    ('subscriptions'),
    ('embeddings'),
    ('metrics'),
    ('presence_logs'),
    ('healing_logs'),
    ('api_keys'),
    ('config'),
    ('files'),
    ('nicknames'),
    ('pinned_items'),
    ('reactions'),
    ('read_receipts'),
    ('room_members'),
    ('ux_telemetry')
) AS t(table_name);

-- ===============================================
-- 4. CRITICAL INDEXES
-- ===============================================
SELECT 
  'CRITICAL_INDEXES' AS category,
  index_name,
  table_name,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM pg_indexes 
      WHERE schemaname = 'public' 
      AND indexname = idx.index_name
    ) THEN '✅ EXISTS'
    ELSE '❌ MISSING'
  END AS status
FROM (
  VALUES 
    ('idx_messages_room_time', 'messages'),
    ('idx_messages_hash', 'messages'),
    ('idx_audit_room_time', 'audit_log'),
    ('idx_logs_raw_room_month', 'logs_raw'),
    ('idx_logs_compressed_room_month', 'logs_compressed'),
    ('idx_telemetry_event_time', 'telemetry'),
    ('idx_rooms_slug_lookup', 'rooms'),
    ('idx_rooms_created_by', 'rooms'),
    ('idx_message_receipts_message_user', 'message_receipts'),
    ('idx_message_receipts_user_unread', 'message_receipts')
) AS idx(index_name, table_name);

-- ===============================================
-- 5. FOREIGN KEY CONSTRAINTS
-- ===============================================
SELECT 
  'FOREIGN_KEYS' AS category,
  tc.constraint_name,
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  CASE 
    WHEN tc.constraint_name IS NOT NULL THEN '✅ EXISTS'
    ELSE '❌ MISSING'
  END AS status
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
  AND (
    (tc.table_name = 'messages' AND ccu.table_name = 'rooms') OR
    (tc.table_name = 'messages' AND ccu.table_name = 'users') OR
    (tc.table_name = 'message_receipts' AND ccu.table_name = 'messages') OR
    (tc.table_name = 'room_memberships' AND ccu.table_name = 'rooms') OR
    (tc.table_name = 'room_memberships' AND ccu.table_name = 'users')
  )
ORDER BY tc.table_name, tc.constraint_name;

-- ===============================================
-- 6. ROW LEVEL SECURITY (RLS) STATUS
-- ===============================================
SELECT 
  'RLS_STATUS' AS category,
  t.schemaname || '.' || t.tablename AS table_name,
  CASE 
    WHEN t.rowsecurity THEN '✅ ENABLED'
    ELSE '⚠️ DISABLED'
  END AS rls_status,
  CASE 
    WHEN t.tablename IN ('audit_log', 'messages', 'logs_raw', 'logs_compressed', 
                       'users', 'rooms', 'room_memberships', 'message_receipts',
                       'telemetry', 'system_config', 'retention_schedule', 'legal_holds',
                       'healing_logs', 'api_keys')
    THEN 'CRITICAL'
    ELSE 'OPTIONAL'
  END AS priority
FROM pg_tables t
WHERE t.schemaname IN ('public', 'service')
  AND t.tablename IN ('audit_log', 'messages', 'logs_raw', 'logs_compressed', 
                    'users', 'rooms', 'room_memberships', 'message_receipts',
                    'telemetry', 'system_config', 'retention_schedule', 'legal_holds',
                    'healing_logs', 'api_keys', 'encode_queue', 'moderation_queue')
ORDER BY priority DESC, t.tablename;

-- ===============================================
-- 7. RLS POLICIES COUNT
-- ===============================================
SELECT 
  'RLS_POLICIES' AS category,
  t.schemaname || '.' || t.tablename AS table_name,
  COUNT(pol.policyname) AS policy_count,
  CASE 
    WHEN COUNT(pol.policyname) > 0 THEN '✅ HAS POLICIES'
    WHEN t.rowsecurity THEN '⚠️ RLS ENABLED BUT NO POLICIES'
    ELSE '❌ NO RLS'
  END AS status
FROM pg_tables t
LEFT JOIN pg_policies pol ON pol.schemaname = t.schemaname AND pol.tablename = t.tablename
WHERE t.schemaname IN ('public', 'service')
  AND t.tablename IN ('audit_log', 'messages', 'logs_raw', 'logs_compressed', 
                      'users', 'rooms', 'room_memberships', 'message_receipts',
                      'telemetry', 'system_config', 'retention_schedule', 'legal_holds',
                      'healing_logs', 'api_keys', 'encode_queue', 'moderation_queue')
GROUP BY t.schemaname, t.tablename, t.rowsecurity
ORDER BY policy_count, t.tablename;

-- ===============================================
-- 8. REQUIRED COLUMNS IN CRITICAL TABLES
-- ===============================================
SELECT 
  'REQUIRED_COLUMNS' AS category,
  table_name,
  column_name,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = col.table_name
      AND column_name = col.column_name
    ) THEN '✅ EXISTS'
    ELSE '❌ MISSING'
  END AS status
FROM (
  VALUES 
    ('users', 'id'),
    ('users', 'handle'),
    ('users', 'created_at'),
    ('rooms', 'id'),
    ('rooms', 'slug'),
    ('rooms', 'created_at'),
    ('rooms', 'created_by'),
    ('messages', 'id'),
    ('messages', 'room_id'),
    ('messages', 'sender_id'),
    ('messages', 'created_at'),
    ('messages', 'content_hash'),
    ('messages', 'audit_hash_chain'),
    ('message_receipts', 'message_id'),
    ('message_receipts', 'user_id'),
    ('room_memberships', 'room_id'),
    ('room_memberships', 'user_id'),
    ('room_memberships', 'role')
) AS col(table_name, column_name)
ORDER BY table_name, column_name;

-- ===============================================
-- 9. SYSTEM CONFIG DEFAULTS
-- ===============================================
-- Use DO block with dynamic SQL to safely check system_config table
-- This avoids errors if the table doesn't exist
DO $$
DECLARE
  table_exists BOOLEAN;
  key_exists BOOLEAN;
  config_key TEXT;
  result_text TEXT;
BEGIN
  -- Check if system_config table exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'system_config'
  ) INTO table_exists;
  
  IF NOT table_exists THEN
    -- Table doesn't exist, output all keys as missing table
    RAISE NOTICE 'SYSTEM_CONFIG|retention_policy|⚠️ TABLE DOES NOT EXIST';
    RAISE NOTICE 'SYSTEM_CONFIG|cold_storage|⚠️ TABLE DOES NOT EXIST';
    RAISE NOTICE 'SYSTEM_CONFIG|moderation_thresholds|⚠️ TABLE DOES NOT EXIST';
    RAISE NOTICE 'SYSTEM_CONFIG|codec|⚠️ TABLE DOES NOT EXIST';
  ELSE
    -- Table exists, check each key using dynamic SQL
    FOR config_key IN SELECT unnest(ARRAY['retention_policy', 'cold_storage', 'moderation_thresholds', 'codec'])
    LOOP
      EXECUTE format('SELECT EXISTS(SELECT 1 FROM system_config WHERE key = $1)') 
        INTO key_exists USING config_key;
      
      IF key_exists THEN
        RAISE NOTICE 'SYSTEM_CONFIG|%|✅ EXISTS', config_key;
      ELSE
        RAISE NOTICE 'SYSTEM_CONFIG|%|❌ MISSING', config_key;
      END IF;
    END LOOP;
  END IF;
END $$;

-- ===============================================
-- 10. SERVICE SCHEMA EXISTS
-- ===============================================
SELECT 
  'SCHEMA' AS category,
  schema_name,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.schemata 
      WHERE schema_name = 'service'
    ) THEN '✅ EXISTS'
    ELSE '❌ MISSING'
  END AS status
FROM (
  VALUES ('service')
) AS s(schema_name);

-- ===============================================
-- 11. SUMMARY REPORT
-- ===============================================
SELECT 
  'SUMMARY' AS category,
  'Total Tables' AS metric,
  COUNT(*)::TEXT AS value
FROM information_schema.tables
WHERE table_schema = 'public';

SELECT 
  'SUMMARY' AS category,
  'Total Indexes' AS metric,
  COUNT(*)::TEXT AS value
FROM pg_indexes
WHERE schemaname = 'public';

SELECT 
  'SUMMARY' AS category,
  'Tables with RLS Enabled' AS metric,
  COUNT(*)::TEXT AS value
FROM pg_tables
WHERE schemaname = 'public'
  AND rowsecurity = true;

SELECT 
  'SUMMARY' AS category,
  'Total RLS Policies' AS metric,
  COUNT(*)::TEXT AS value
FROM pg_policies
WHERE schemaname = 'public';

COMMIT;

