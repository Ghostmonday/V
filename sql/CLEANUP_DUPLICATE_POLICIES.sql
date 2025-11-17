-- ===============================================
-- CLEANUP DUPLICATE RLS POLICIES
-- Purpose: Remove duplicate/conflicting policies from old scripts
-- Run this BEFORE running RLS_COMPLETE_POLICIES.sql if you have duplicates
-- ===============================================

BEGIN;

-- ===============================================
-- MESSAGES TABLE - Clean up duplicates
-- ===============================================
DO $$
BEGIN
  -- Drop old policies that might conflict
  DROP POLICY IF EXISTS messages_insert_auth ON messages;
  DROP POLICY IF EXISTS messages_select_room ON messages;
  DROP POLICY IF EXISTS messages_update_restrict ON messages;
  DROP POLICY IF EXISTS messages_delete_own ON messages;
  DROP POLICY IF EXISTS messages_read_own ON messages;
  DROP POLICY IF EXISTS messages_write_own ON messages;
  DROP POLICY IF EXISTS messages_update_own ON messages;
END $$;

-- ===============================================
-- ROOMS TABLE - Clean up duplicates
-- ===============================================
DO $$
BEGIN
  DROP POLICY IF EXISTS rooms_select_auth ON rooms;
  DROP POLICY IF EXISTS rooms_all_service ON rooms;
END $$;

-- ===============================================
-- USERS TABLE - Clean up duplicates
-- ===============================================
DO $$
BEGIN
  DROP POLICY IF EXISTS users_select_auth ON users;
  DROP POLICY IF EXISTS users_all_service ON users;
END $$;

-- ===============================================
-- PRESENCE_LOGS TABLE - Clean up duplicates
-- ===============================================
DO $$
BEGIN
  DROP POLICY IF EXISTS presence_logs_read_own ON presence_logs;
END $$;

-- ===============================================
-- MESSAGE_RECEIPTS TABLE - Clean up duplicates
-- ===============================================
DO $$
BEGIN
  DROP POLICY IF EXISTS message_receipts_select ON message_receipts;
  DROP POLICY IF EXISTS message_receipts_own ON message_receipts;
END $$;

-- ===============================================
-- HEALING_LOGS TABLE - Clean up duplicates
-- ===============================================
DO $$
BEGIN
  DROP POLICY IF EXISTS healing_logs_service ON healing_logs;
  DROP POLICY IF EXISTS healing_logs_select_room ON healing_logs;
  DROP POLICY IF EXISTS healing_logs_deny_others ON healing_logs;
END $$;

-- ===============================================
-- ROOM_MEMBERSHIPS TABLE - Clean up duplicates
-- ===============================================
DO $$
BEGIN
  DROP POLICY IF EXISTS room_memberships_select_auth ON room_memberships;
  DROP POLICY IF EXISTS room_memberships_all_service ON room_memberships;
  DROP POLICY IF EXISTS room_memberships_update_own ON room_memberships;
  DROP POLICY IF EXISTS room_memberships_read_member ON room_memberships;
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

