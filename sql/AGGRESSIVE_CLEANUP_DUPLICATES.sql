-- ===============================================
-- AGGRESSIVE CLEANUP - DROP ALL POLICIES ON SPECIFIC TABLES
-- Purpose: Remove ALL policies from tables with duplicates, then re-run RLS_COMPLETE_POLICIES.sql
-- WARNING: This will remove ALL policies from these tables. Run RLS_COMPLETE_POLICIES.sql immediately after.
-- ===============================================

BEGIN;

-- ===============================================
-- MESSAGES - Drop ALL policies
-- ===============================================
DO $$
DECLARE
  pol RECORD;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'messages') THEN
    FOR pol IN 
      SELECT policyname FROM pg_policies 
      WHERE schemaname = 'public' AND tablename = 'messages'
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON messages', pol.policyname);
    END LOOP;
  END IF;
END $$;

-- ===============================================
-- ROOMS - Drop ALL policies
-- ===============================================
DO $$
DECLARE
  pol RECORD;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'rooms') THEN
    FOR pol IN 
      SELECT policyname FROM pg_policies 
      WHERE schemaname = 'public' AND tablename = 'rooms'
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON rooms', pol.policyname);
    END LOOP;
  END IF;
END $$;

-- ===============================================
-- USERS - Drop ALL policies
-- ===============================================
DO $$
DECLARE
  pol RECORD;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'users') THEN
    FOR pol IN 
      SELECT policyname FROM pg_policies 
      WHERE schemaname = 'public' AND tablename = 'users'
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON users', pol.policyname);
    END LOOP;
  END IF;
END $$;

-- ===============================================
-- PRESENCE_LOGS - Drop ALL policies
-- ===============================================
DO $$
DECLARE
  pol RECORD;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'presence_logs') THEN
    FOR pol IN 
      SELECT policyname FROM pg_policies 
      WHERE schemaname = 'public' AND tablename = 'presence_logs'
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON presence_logs', pol.policyname);
    END LOOP;
  END IF;
END $$;

-- ===============================================
-- HEALING_LOGS - Drop ALL policies
-- ===============================================
DO $$
DECLARE
  pol RECORD;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'healing_logs') THEN
    FOR pol IN 
      SELECT policyname FROM pg_policies 
      WHERE schemaname = 'public' AND tablename = 'healing_logs'
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON healing_logs', pol.policyname);
    END LOOP;
  END IF;
END $$;

COMMIT;

-- ===============================================
-- VERIFICATION: Show remaining policies
-- ===============================================
SELECT 
  'AFTER_AGGRESSIVE_CLEANUP' AS report_type,
  schemaname || '.' || tablename AS table_name,
  COUNT(*) AS policy_count,
  STRING_AGG(cmd, ', ' ORDER BY cmd) AS policy_types
FROM pg_policies
WHERE schemaname IN ('public', 'service')
  AND tablename IN ('messages', 'rooms', 'users', 'presence_logs', 'healing_logs')
GROUP BY schemaname, tablename
ORDER BY table_name;

