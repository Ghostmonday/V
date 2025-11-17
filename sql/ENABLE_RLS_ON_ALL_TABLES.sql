-- ===============================================
-- ENABLE RLS ON ALL TABLES WITH POLICIES
-- Purpose: Enable RLS on tables that have policies but RLS is not enabled
-- WARNING: This will enable RLS on tables. Make sure policies exist first!
-- ===============================================

BEGIN;

-- Enable RLS on all tables that have policies but RLS is not enabled
DO $$
DECLARE
  tbl RECORD;
BEGIN
  FOR tbl IN 
    SELECT DISTINCT p.schemaname, p.tablename
    FROM pg_policies p
    LEFT JOIN pg_class c ON c.relname = p.tablename
    LEFT JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = p.schemaname
    WHERE p.schemaname IN ('public', 'service')
      AND (c.relrowsecurity IS NULL OR c.relrowsecurity = false)
  LOOP
    BEGIN
      EXECUTE format('ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY', tbl.schemaname, tbl.tablename);
      RAISE NOTICE 'Enabled RLS on %.%', tbl.schemaname, tbl.tablename;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Failed to enable RLS on %.%: %', tbl.schemaname, tbl.tablename, SQLERRM;
    END;
  END LOOP;
END $$;

-- Verify RLS is now enabled
SELECT 
  'VERIFICATION' AS report_type,
  p.schemaname || '.' || p.tablename AS table_name,
  COUNT(DISTINCT p.policyname) AS policy_count,
  CASE 
    WHEN c.relrowsecurity THEN '✅ RLS ENABLED'
    ELSE '❌ RLS STILL DISABLED'
  END AS rls_status
FROM pg_policies p
LEFT JOIN pg_class c ON c.relname = p.tablename
LEFT JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = p.schemaname
WHERE p.schemaname IN ('public', 'service')
GROUP BY p.schemaname, p.tablename, c.relrowsecurity
ORDER BY 
  CASE WHEN c.relrowsecurity THEN 0 ELSE 1 END,
  p.tablename;

COMMIT;

