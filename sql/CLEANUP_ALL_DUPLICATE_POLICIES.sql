-- ===============================================
-- CLEANUP ALL DUPLICATE RLS POLICIES
-- Purpose: Remove ALL duplicate/conflicting policies from old scripts
-- Run this BEFORE running RLS_COMPLETE_POLICIES.sql to ensure clean state
-- ===============================================

BEGIN;

-- ===============================================
-- MESSAGES TABLE - Remove ALL possible duplicates
-- ===============================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'messages') THEN
    -- Drop ALL known policy names from various scripts
    DROP POLICY IF EXISTS messages_insert_auth ON messages;
    DROP POLICY IF EXISTS messages_select_room ON messages;
    DROP POLICY IF EXISTS messages_update_own ON messages;
    DROP POLICY IF EXISTS messages_update_restrict ON messages;
    DROP POLICY IF EXISTS messages_delete_own ON messages;
    DROP POLICY IF EXISTS messages_read_own ON messages;
    DROP POLICY IF EXISTS messages_write_own ON messages;
    DROP POLICY IF EXISTS messages_all_service ON messages;
  END IF;
END $$;

-- ===============================================
-- ROOMS TABLE - Remove ALL possible duplicates
-- ===============================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'rooms') THEN
    DROP POLICY IF EXISTS rooms_select_auth ON rooms;
    DROP POLICY IF EXISTS rooms_insert_auth ON rooms;
    DROP POLICY IF EXISTS rooms_update_creator ON rooms;
    DROP POLICY IF EXISTS rooms_all_service ON rooms;
  END IF;
END $$;

-- ===============================================
-- USERS TABLE - Remove ALL possible duplicates
-- ===============================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'users') THEN
    DROP POLICY IF EXISTS users_select_auth ON users;
    DROP POLICY IF EXISTS users_insert_own ON users;
    DROP POLICY IF EXISTS users_update_own ON users;
    DROP POLICY IF EXISTS users_all_service ON users;
  END IF;
END $$;

-- ===============================================
-- PRESENCE_LOGS TABLE - Remove ALL possible duplicates
-- ===============================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'presence_logs') THEN
    DROP POLICY IF EXISTS presence_logs_select_own ON presence_logs;
    DROP POLICY IF EXISTS presence_logs_select_room ON presence_logs;
    DROP POLICY IF EXISTS presence_logs_read_own ON presence_logs;
    DROP POLICY IF EXISTS presence_logs_insert_own ON presence_logs;
    DROP POLICY IF EXISTS presence_logs_all_service ON presence_logs;
  END IF;
END $$;

-- ===============================================
-- MESSAGE_RECEIPTS TABLE - Remove ALL possible duplicates
-- ===============================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'message_receipts') THEN
    DROP POLICY IF EXISTS message_receipts_select ON message_receipts;
    DROP POLICY IF EXISTS message_receipts_insert ON message_receipts;
    DROP POLICY IF EXISTS message_receipts_update_own ON message_receipts;
    DROP POLICY IF EXISTS message_receipts_delete_own ON message_receipts;
    DROP POLICY IF EXISTS message_receipts_own ON message_receipts;
    DROP POLICY IF EXISTS message_receipts_all_service ON message_receipts;
  END IF;
END $$;

-- ===============================================
-- HEALING_LOGS TABLE - Remove ALL possible duplicates
-- ===============================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'healing_logs') THEN
    DROP POLICY IF EXISTS healing_logs_service ON healing_logs;
    DROP POLICY IF EXISTS healing_logs_select_room ON healing_logs;
    DROP POLICY IF EXISTS healing_logs_deny_others ON healing_logs;
  END IF;
END $$;

-- ===============================================
-- ROOM_MEMBERSHIPS TABLE - Remove ALL possible duplicates
-- ===============================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'room_memberships') THEN
    DROP POLICY IF EXISTS room_memberships_select_auth ON room_memberships;
    DROP POLICY IF EXISTS room_memberships_insert_auth ON room_memberships;
    DROP POLICY IF EXISTS room_memberships_update_own ON room_memberships;
    DROP POLICY IF EXISTS room_memberships_delete_own ON room_memberships;
    DROP POLICY IF EXISTS room_memberships_read_member ON room_memberships;
    DROP POLICY IF EXISTS room_memberships_all_service ON room_memberships;
  END IF;
END $$;

-- ===============================================
-- Show remaining policies after cleanup
-- ===============================================
SELECT 
  'AFTER_CLEANUP' AS report_type,
  schemaname || '.' || tablename AS table_name,
  COUNT(*) AS policy_count,
  STRING_AGG(cmd, ', ' ORDER BY cmd) AS policy_types
FROM pg_policies
WHERE schemaname IN ('public', 'service')
GROUP BY schemaname, tablename
ORDER BY policy_count DESC, table_name;

COMMIT;

