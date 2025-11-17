-- ===============================================
-- VERIFY RLS POLICIES CREATION
-- Purpose: Check that RLS policies were created successfully
-- Run this after running 05_rls_policies.sql
-- ===============================================

-- Show all RLS policies that were created
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname IN ('public', 'service')
ORDER BY schemaname, tablename, policyname;

-- Count policies per table
SELECT 
  schemaname || '.' || tablename AS table_name,
  COUNT(*) AS policy_count,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ HAS POLICIES'
    ELSE '❌ NO POLICIES'
  END AS status
FROM pg_policies
WHERE schemaname IN ('public', 'service')
GROUP BY schemaname, tablename
ORDER BY policy_count DESC, table_name;

-- Show tables with RLS enabled
SELECT 
  schemaname || '.' || tablename AS table_name,
  CASE 
    WHEN rowsecurity THEN '✅ RLS ENABLED'
    ELSE '❌ RLS DISABLED'
  END AS rls_status
FROM pg_tables
WHERE schemaname IN ('public', 'service')
  AND tablename IN (
    'audit_log', 'messages', 'logs_raw', 'logs_compressed',
    'users', 'rooms', 'room_memberships', 'message_receipts',
    'telemetry', 'system_config', 'retention_schedule', 'legal_holds',
    'healing_logs', 'api_keys', 'encode_queue', 'moderation_queue'
  )
ORDER BY rowsecurity DESC, tablename;

-- Summary
SELECT 
  'SUMMARY' AS category,
  'Total RLS Policies Created' AS metric,
  COUNT(*)::TEXT AS value
FROM pg_policies
WHERE schemaname IN ('public', 'service');

SELECT 
  'SUMMARY' AS category,
  'Tables with RLS Enabled' AS metric,
  COUNT(*)::TEXT AS value
FROM pg_tables
WHERE schemaname IN ('public', 'service')
  AND rowsecurity = true
  AND tablename IN (
    'audit_log', 'messages', 'logs_raw', 'logs_compressed',
    'users', 'rooms', 'room_memberships', 'message_receipts',
    'telemetry', 'system_config', 'retention_schedule', 'legal_holds',
    'healing_logs', 'api_keys', 'encode_queue', 'moderation_queue'
  );

