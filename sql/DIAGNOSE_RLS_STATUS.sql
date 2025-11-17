-- ===============================================
-- DIAGNOSE RLS STATUS
-- Purpose: Check if RLS is actually enabled on tables with policies
-- ===============================================

-- Check tables that have policies but might not have RLS enabled
SELECT 
  'DIAGNOSIS' AS report_type,
  p.schemaname || '.' || p.tablename AS table_name,
  COUNT(DISTINCT p.policyname) AS policy_count,
  CASE 
    WHEN c.relrowsecurity THEN '✅ RLS ENABLED'
    ELSE '❌ RLS NOT ENABLED'
  END AS rls_status,
  CASE 
    WHEN c.relrowsecurity THEN 'OK'
    ELSE 'NEEDS ALTER TABLE ... ENABLE ROW LEVEL SECURITY'
  END AS action_needed
FROM pg_policies p
LEFT JOIN pg_class c ON c.relname = p.tablename
LEFT JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = p.schemaname
WHERE p.schemaname IN ('public', 'service')
GROUP BY p.schemaname, p.tablename, c.relrowsecurity
ORDER BY 
  CASE WHEN c.relrowsecurity THEN 1 ELSE 0 END,
  policy_count DESC;

-- Show all tables and their RLS status
SELECT 
  'ALL_TABLES_RLS_STATUS' AS report_type,
  n.nspname || '.' || c.relname AS table_name,
  CASE 
    WHEN c.relrowsecurity THEN '✅ RLS ENABLED'
    ELSE '❌ RLS DISABLED'
  END AS rls_status,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM pg_policies p 
      WHERE p.schemaname = n.nspname AND p.tablename = c.relname
    ) THEN 'HAS POLICIES'
    ELSE 'NO POLICIES'
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

