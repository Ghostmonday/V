-- ===============================================
-- VERIFY RLS STATUS - Complete Security Check
-- Purpose: Verify all tables have RLS enabled and proper policies
-- Run this AFTER running COMPLETE_SECURITY_FIX.sql
-- ===============================================

SET search_path TO service, public;

-- ===============================================
-- 1. CHECK RLS ENABLED STATUS
-- ===============================================

SELECT 
  'RLS STATUS CHECK' AS check_type,
  schemaname,
  tablename,
  CASE 
    WHEN relrowsecurity THEN '✅ RLS ENABLED'
    ELSE '🔴 RLS DISABLED - CRITICAL!'
  END AS rls_status,
  (SELECT COUNT(*) FROM pg_policies WHERE schemaname = t.schemaname AND tablename = t.tablename) AS policy_count
FROM pg_tables t
LEFT JOIN pg_class c ON c.relname = t.tablename
LEFT JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = t.schemaname
WHERE t.schemaname IN ('public', 'service')
  AND t.tablename NOT LIKE 'pg_%'
  AND t.tablename NOT LIKE '_prisma%'
ORDER BY 
  CASE WHEN relrowsecurity THEN 0 ELSE 1 END,
  t.tablename;

-- ===============================================
-- 2. CHECK TABLES WITHOUT POLICIES
-- ===============================================

SELECT 
  'TABLES WITHOUT POLICIES' AS check_type,
  schemaname,
  tablename,
  CASE 
    WHEN relrowsecurity THEN '⚠️ RLS ENABLED BUT NO POLICIES'
    ELSE '🔴 RLS DISABLED'
  END AS issue
FROM pg_tables t
LEFT JOIN pg_class c ON c.relname = t.tablename
LEFT JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = t.schemaname
WHERE t.schemaname IN ('public', 'service')
  AND t.tablename NOT LIKE 'pg_%'
  AND t.tablename NOT LIKE '_prisma%'
  AND NOT EXISTS (
    SELECT 1 FROM pg_policies p 
    WHERE p.schemaname = t.schemaname 
    AND p.tablename = t.tablename
  )
ORDER BY t.tablename;

-- ===============================================
-- 3. LIST ALL POLICIES BY TABLE
-- ===============================================

SELECT 
  'POLICY LIST' AS check_type,
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd AS operation,
  qual AS using_expression,
  with_check AS with_check_expression
FROM pg_policies
WHERE schemaname IN ('public', 'service')
ORDER BY schemaname, tablename, cmd, policyname;

-- ===============================================
-- 4. CHECK FOR LEAKY POLICIES (SELECT with USING (true))
-- ===============================================

SELECT 
  'LEAKY POLICIES' AS check_type,
  schemaname,
  tablename,
  policyname,
  cmd AS operation,
  '⚠️ Policy allows all rows' AS issue
FROM pg_policies
WHERE schemaname IN ('public', 'service')
  AND cmd = 'SELECT'
  AND (qual = '(true)' OR qual IS NULL)
  AND tablename NOT IN ('users', 'rooms') -- These may have intentional public access
ORDER BY tablename, policyname;

-- ===============================================
-- 5. CHECK FOR TABLES WITH NO DELETE POLICIES
-- ===============================================

SELECT 
  'MISSING DELETE POLICIES' AS check_type,
  schemaname,
  tablename,
  '⚠️ No DELETE policy - users cannot delete' AS issue
FROM pg_tables t
LEFT JOIN pg_class c ON c.relname = t.tablename
LEFT JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = t.schemaname
WHERE t.schemaname IN ('public', 'service')
  AND t.tablename NOT LIKE 'pg_%'
  AND t.tablename NOT LIKE '_prisma%'
  AND relrowsecurity = true
  AND NOT EXISTS (
    SELECT 1 FROM pg_policies p 
    WHERE p.schemaname = t.schemaname 
    AND p.tablename = t.tablename
    AND p.cmd = 'DELETE'
  )
  AND t.tablename NOT IN ('audit_log', 'auth_audit_log', 'message_archives', 'card_events', 'sentiment_analysis') -- Immutable tables
ORDER BY t.tablename;

-- ===============================================
-- 6. CHECK SECURITY DEFINER FUNCTIONS
-- ===============================================

SELECT 
  'SECURITY DEFINER FUNCTIONS' AS check_type,
  n.nspname AS schema,
  p.proname AS function_name,
  pg_get_function_arguments(p.oid) AS arguments,
  CASE 
    WHEN p.prosecdef THEN '⚠️ SECURITY DEFINER'
    ELSE '✅ SECURITY INVOKER'
  END AS security_type
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public', 'service')
  AND p.prosecdef = true
ORDER BY n.nspname, p.proname;

-- ===============================================
-- 7. SUMMARY REPORT
-- ===============================================

SELECT 
  'SUMMARY' AS report_type,
  COUNT(DISTINCT t.tablename) FILTER (WHERE relrowsecurity) AS tables_with_rls,
  COUNT(DISTINCT t.tablename) FILTER (WHERE NOT relrowsecurity) AS tables_without_rls,
  COUNT(DISTINCT p.policyname) AS total_policies,
  COUNT(DISTINCT t.tablename) FILTER (
    WHERE relrowsecurity 
    AND NOT EXISTS (
      SELECT 1 FROM pg_policies p2 
      WHERE p2.schemaname = t.schemaname 
      AND p2.tablename = t.tablename
    )
  ) AS tables_with_rls_but_no_policies
FROM pg_tables t
LEFT JOIN pg_class c ON c.relname = t.tablename
LEFT JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = t.schemaname
LEFT JOIN pg_policies p ON p.schemaname = t.schemaname AND p.tablename = t.tablename
WHERE t.schemaname IN ('public', 'service')
  AND t.tablename NOT LIKE 'pg_%'
  AND t.tablename NOT LIKE '_prisma%';

-- ===============================================
-- EXPECTED RESULTS AFTER FIX:
-- - All tables should have RLS ENABLED
-- - All tables should have at least 1 policy
-- - No leaky SELECT policies (except intentional public access)
-- - Critical tables should have DELETE policies
-- ===============================================

