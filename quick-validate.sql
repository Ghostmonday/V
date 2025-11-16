-- ===============================================
-- QUICK VALIDATION - Run this first for a fast check
-- ===============================================

-- Quick check: Do we have all critical tables?
SELECT 
  CASE 
    WHEN COUNT(*) >= 18 THEN '✅ All tables created (' || COUNT(*) || ')'
    ELSE '❌ Missing tables (found ' || COUNT(*) || ', expected 18)'
  END as status
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'users', 'rooms', 'messages', 'room_members', 'room_memberships',
    'read_receipts', 'message_receipts', 'reactions', 'threads',
    'subscriptions', 'files', 'telemetry', 'ux_telemetry', 'presence_logs',
    'pinned_items', 'nicknames', 'config', 'api_keys'
  );

-- Quick check: Are extensions installed?
SELECT 
  CASE 
    WHEN COUNT(*) >= 3 THEN '✅ All extensions installed (' || COUNT(*) || ')'
    ELSE '❌ Missing extensions (found ' || COUNT(*) || ', expected 3)'
  END as status
FROM pg_extension
WHERE extname IN ('pgcrypto', 'pg_stat_statements', 'uuid-ossp');

-- Quick check: Are functions created?
SELECT 
  CASE 
    WHEN COUNT(*) >= 4 THEN '✅ All functions created (' || COUNT(*) || ')'
    ELSE '❌ Missing functions (found ' || COUNT(*) || ', expected 4)'
  END as status
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('get_encryption_key', 'store_api_key', 'get_api_key', 'current_uid');

-- Quick check: Is RLS enabled on critical tables?
SELECT 
  CASE 
    WHEN COUNT(*) >= 6 THEN '✅ RLS enabled on critical tables (' || COUNT(*) || ')'
    ELSE '⚠️  Some tables missing RLS (found ' || COUNT(*) || ', expected 6)'
  END as status
FROM pg_tables t
JOIN pg_class c ON c.relname = t.tablename
WHERE t.schemaname = 'public'
  AND t.tablename IN ('users', 'rooms', 'messages', 'telemetry', 'room_members', 'subscriptions', 'api_keys')
  AND c.relrowsecurity = true;

-- Quick test: Can we insert a test user?
DO $$
DECLARE
  test_id UUID;
BEGIN
  INSERT INTO users (handle, display_name, age_verified)
  VALUES ('quick_test_' || extract(epoch from now())::text, 'Quick Test', true)
  RETURNING id INTO test_id;
  
  DELETE FROM users WHERE id = test_id;
  RAISE NOTICE '✅ Data operations working - can insert/delete';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE '❌ Data operations failed: %', SQLERRM;
END $$;

