-- ===============================================
-- FILE: 08_enhanced_rls_policies.sql
-- PURPOSE: Enhanced RLS policies with proper room membership checks
-- DEPENDENCIES: 01_vibez_schema.sql, 05_rls_policies.sql
-- ===============================================

SET search_path TO service, public;

-- ===============================================
-- ENHANCED MESSAGES POLICY
-- Fix: Check room_memberships instead of allowing all authenticated users
-- ===============================================

-- Drop existing policy and recreate with proper checks
DROP POLICY IF EXISTS messages_select_room ON messages;

CREATE POLICY messages_select_room ON messages
  FOR SELECT
  TO authenticated
  USING (
    -- Users can only see messages in rooms they're members of
    room_id IN (
      SELECT room_id 
      FROM room_memberships 
      WHERE user_id = auth.uid() 
        AND role != 'banned'
    )
  );

-- Enhanced insert policy: Only allow if user is member of room
DROP POLICY IF EXISTS messages_insert_auth ON messages;

CREATE POLICY messages_insert_auth ON messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    -- User must be a member of the room and not banned
    room_id IN (
      SELECT room_id 
      FROM room_memberships 
      WHERE user_id = auth.uid() 
        AND role != 'banned'
    )
    AND sender_id = auth.uid() -- Can only send as themselves
  );

-- Add delete policy: Only allow deletion of own messages within time limit
CREATE POLICY messages_delete_own ON messages
  FOR DELETE
  TO authenticated
  USING (
    sender_id = auth.uid()
    AND created_at > now() - INTERVAL '24 hours' -- 24 hour deletion window
  );

-- ===============================================
-- ENHANCED ROOM MEMBERSHIPS POLICY
-- ===============================================

-- Users can only see memberships for rooms they're in
DROP POLICY IF EXISTS room_memberships_select_auth ON room_memberships;

CREATE POLICY room_memberships_select_auth ON room_memberships
  FOR SELECT
  TO authenticated
  USING (
    -- Can see memberships if they're a member of the room
    room_id IN (
      SELECT room_id 
      FROM room_memberships 
      WHERE user_id = auth.uid()
    )
    OR user_id = auth.uid() -- Or if it's their own membership
  );

-- Users can only update their own membership status (e.g., leave)
CREATE POLICY room_memberships_update_own ON room_memberships
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (
    user_id = auth.uid()
    AND role != 'owner' -- Can't change owner role
  );

-- ===============================================
-- MESSAGE RECEIPTS POLICY
-- ===============================================

ALTER TABLE message_receipts ENABLE ROW LEVEL SECURITY;

-- Users can only see receipts for messages they can see
CREATE POLICY message_receipts_select ON message_receipts
  FOR SELECT
  TO authenticated
  USING (
    message_id IN (
      SELECT id FROM messages
      WHERE room_id IN (
        SELECT room_id 
        FROM room_memberships 
        WHERE user_id = auth.uid()
      )
    )
  );

-- Users can only create/update their own receipts
CREATE POLICY message_receipts_own ON message_receipts
  FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ===============================================
-- HEALING_LOGS POLICY
-- ===============================================

ALTER TABLE healing_logs ENABLE ROW LEVEL SECURITY;

-- Service role can manage all healing logs
CREATE POLICY healing_logs_service ON healing_logs
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Users can only see healing logs for rooms they're in (if room_id is set)
CREATE POLICY healing_logs_select_room ON healing_logs
  FOR SELECT
  TO authenticated
  USING (
    room_id IS NULL -- System-wide logs
    OR room_id IN (
      SELECT room_id 
      FROM room_memberships 
      WHERE user_id = auth.uid()
    )
  );

-- Deny all other access
CREATE POLICY healing_logs_deny_others ON healing_logs
  FOR ALL
  TO public
  USING (false);

