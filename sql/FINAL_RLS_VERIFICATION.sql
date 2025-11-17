-- ===============================================
-- FINAL RLS VERIFICATION & SUMMARY
-- Purpose: Comprehensive verification of RLS setup
-- This is PURE SQL - safe to run in SQL editor
-- ===============================================

-- ===============================================
-- 1. POLICY SUMMARY BY TABLE
-- ===============================================
SELECT 
  'POLICY_SUMMARY' AS report_type,
  schemaname || '.' || tablename AS table_name,
  COUNT(*) AS policy_count,
  STRING_AGG(cmd, ', ' ORDER BY cmd) AS policy_types
FROM pg_policies
WHERE schemaname IN ('public', 'service')
GROUP BY schemaname, tablename
ORDER BY policy_count DESC, table_name;

-- ===============================================
-- 2. DETAILED POLICY LISTING
-- ===============================================
SELECT 
  'POLICY_DETAILS' AS report_type,
  schemaname || '.' || tablename AS table_name,
  policyname,
  cmd AS operation,
  roles,
  CASE 
    WHEN qual IS NOT NULL THEN 'Has USING clause'
    ELSE 'No USING clause'
  END AS has_using,
  CASE 
    WHEN with_check IS NOT NULL THEN 'Has WITH CHECK clause'
    ELSE 'No WITH CHECK clause'
  END AS has_with_check
FROM pg_policies
WHERE schemaname IN ('public', 'service')
ORDER BY schemaname, tablename, cmd, policyname;

-- ===============================================
-- 3. RLS STATUS BY TABLE
-- ===============================================
SELECT 
  'RLS_STATUS' AS report_type,
  n.nspname || '.' || c.relname AS table_name,
  CASE 
    WHEN c.relrowsecurity THEN '✅ RLS ENABLED'
    ELSE '❌ RLS DISABLED'
  END AS rls_status,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM pg_policies p
      JOIN pg_class pc ON pc.relname = p.tablename
      JOIN pg_namespace pn ON pn.oid = pc.relnamespace AND pn.nspname = p.schemaname
      WHERE pn.nspname = n.nspname AND pc.relname = c.relname
    ) THEN '✅ HAS POLICIES'
    WHEN c.relrowsecurity THEN '⚠️ RLS ENABLED BUT NO POLICIES'
    ELSE '❌ NO POLICIES'
  END AS policy_status
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('public', 'service')
  AND c.relkind = 'r'
  AND c.relname NOT LIKE 'pg_%'
  AND c.relname NOT LIKE '_%'
ORDER BY 
  CASE WHEN c.relrowsecurity THEN 0 ELSE 1 END,
  c.relname;

-- ===============================================
-- 4. GAP ANALYSIS - CRITICAL TABLES
-- ===============================================
SELECT 
  'GAP_ANALYSIS' AS report_type,
  n.nspname || '.' || c.relname AS table_name,
  CASE 
    WHEN c.relname IN ('audit_log', 'messages', 'rooms', 'users', 'room_memberships', 
                         'legal_holds', 'retention_schedule', 'telemetry', 'logs_raw', 
                         'logs_compressed', 'message_receipts', 'system_config') THEN 'critical'
    WHEN c.relname IN ('assistants', 'bots', 'files', 'threads', 'reactions', 
                         'pinned_items', 'presence_logs', 'healing_logs', 'edit_history',
                         'embeddings', 'subscriptions', 'metrics') THEN 'high'
    ELSE 'medium'
  END AS security_level,
  CASE 
    WHEN NOT c.relrowsecurity THEN '❌ RLS NOT ENABLED'
    WHEN NOT EXISTS (
      SELECT 1 FROM pg_policies p 
      WHERE p.schemaname = n.nspname AND p.tablename = c.relname
    ) THEN '⚠️ RLS ENABLED BUT NO POLICIES'
    WHEN EXISTS (
      SELECT 1 FROM pg_policies p 
      WHERE p.schemaname = n.nspname AND p.tablename = c.relname AND p.cmd = 'SELECT'
    ) AND EXISTS (
      SELECT 1 FROM pg_policies p 
      WHERE p.schemaname = n.nspname AND p.tablename = c.relname AND p.cmd = 'INSERT'
    ) AND EXISTS (
      SELECT 1 FROM pg_policies p 
      WHERE p.schemaname = n.nspname AND p.tablename = c.relname AND p.cmd = 'UPDATE'
    ) AND EXISTS (
      SELECT 1 FROM pg_policies p 
      WHERE p.schemaname = n.nspname AND p.tablename = c.relname AND p.cmd = 'DELETE'
    ) THEN '✅ COMPLIANT'
    WHEN EXISTS (
      SELECT 1 FROM pg_policies p 
      WHERE p.schemaname = n.nspname AND p.tablename = c.relname AND p.cmd = 'SELECT'
    ) AND EXISTS (
      SELECT 1 FROM pg_policies p 
      WHERE p.schemaname = n.nspname AND p.tablename = c.relname AND p.cmd = 'INSERT'
    ) THEN '✅ COMPLIANT (Read/Write)'
    WHEN EXISTS (
      SELECT 1 FROM pg_policies p 
      WHERE p.schemaname = n.nspname AND p.tablename = c.relname AND p.cmd = 'SELECT'
    ) THEN '⚠️ READ ONLY'
    WHEN EXISTS (
      SELECT 1 FROM pg_policies p 
      WHERE p.schemaname = n.nspname AND p.tablename = c.relname AND p.cmd = 'ALL'
    ) THEN '✅ COMPLIANT (Service Role)'
    ELSE '⚠️ PARTIAL COVERAGE'
  END AS status,
  COUNT(DISTINCT p.cmd) AS operation_count
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_policies p ON p.schemaname = n.nspname AND p.tablename = c.relname
WHERE n.nspname IN ('public', 'service')
  AND c.relkind = 'r'
  AND c.relname NOT LIKE 'pg_%'
  AND c.relname NOT LIKE '_%'
GROUP BY n.nspname, c.relname, c.relrowsecurity
ORDER BY 
  CASE 
    WHEN c.relname IN ('audit_log', 'messages', 'rooms', 'users', 'room_memberships', 
                         'legal_holds', 'retention_schedule', 'telemetry', 'logs_raw', 
                         'logs_compressed', 'message_receipts', 'system_config') THEN 1
    WHEN c.relname IN ('assistants', 'bots', 'files', 'threads', 'reactions', 
                         'pinned_items', 'presence_logs', 'healing_logs', 'edit_history',
                         'embeddings', 'subscriptions', 'metrics') THEN 2
    ELSE 3
  END,
  c.relname;

-- ===============================================
-- 5. SUMMARY STATISTICS
-- ===============================================
SELECT 
  'SUMMARY' AS category,
  'Total RLS Policies' AS metric,
  COUNT(*)::TEXT AS value
FROM pg_policies
WHERE schemaname IN ('public', 'service')

UNION ALL

SELECT 
  'SUMMARY' AS category,
  'Tables with RLS Enabled' AS metric,
  COUNT(DISTINCT p.schemaname || '.' || p.tablename)::TEXT AS value
FROM pg_policies p
LEFT JOIN pg_class c ON c.relname = p.tablename
LEFT JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = p.schemaname
WHERE p.schemaname IN ('public', 'service')
  AND c.relkind = 'r'
  AND c.relrowsecurity = true

UNION ALL

SELECT 
  'SUMMARY' AS category,
  'Tables with Policies' AS metric,
  COUNT(DISTINCT schemaname || '.' || tablename)::TEXT AS value
FROM pg_policies
WHERE schemaname IN ('public', 'service')

UNION ALL

SELECT 
  'SUMMARY' AS category,
  'Critical Tables Secured' AS metric,
  COUNT(*)::TEXT AS value
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('public', 'service')
  AND c.relname IN ('audit_log', 'messages', 'rooms', 'users', 'room_memberships', 
                      'legal_holds', 'retention_schedule', 'telemetry', 'logs_raw', 
                      'logs_compressed', 'message_receipts')
  AND c.relkind = 'r'
  AND c.relrowsecurity = true
  AND EXISTS (
    SELECT 1 FROM pg_policies p 
    WHERE p.schemaname = n.nspname AND p.tablename = c.relname
  )

ORDER BY category, metric;

