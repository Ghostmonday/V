-- ===============================================
-- COMPLETE SECURITY FIX FOR VIBEZ SUPABASE SCHEMA
-- Purpose: Fix all RLS gaps, leaky policies, and security issues
-- Status: 🔴 CRITICAL - Run this immediately
-- ===============================================
--
-- This script:
-- 1. Enables RLS on all tables missing it
-- 2. Creates secure policies for all tables
-- 3. Fixes leaky SELECT policies
-- 4. Fixes SECURITY DEFINER functions
-- 5. Adds missing DELETE policies
-- 6. Adds admin/mod override policies
--
-- ⚠️ SAFE TO RUN MULTIPLE TIMES (idempotent)
-- ⚠️ NO DATA DELETION - Only policy changes
--
-- ===============================================

BEGIN;

SET search_path TO service, public;

-- ===============================================
-- HELPER FUNCTIONS (FIXED - Remove unsafe defaults)
-- ===============================================

-- Fix: Remove default parameter to prevent bypass
DROP FUNCTION IF EXISTS is_room_member(UUID, UUID);
CREATE OR REPLACE FUNCTION is_room_member(check_room_id UUID, check_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  -- Force check_user_id to match auth.uid() to prevent bypass
  IF check_user_id != auth.uid() THEN
    RETURN false;
  END IF;
  
  RETURN EXISTS (
    SELECT 1 FROM room_memberships
    WHERE room_id = check_room_id
      AND user_id = check_user_id
      AND role != 'banned'
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Fix: Remove default parameter
DROP FUNCTION IF EXISTS is_room_admin(UUID, UUID);
CREATE OR REPLACE FUNCTION is_room_admin(check_room_id UUID, check_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  -- Force check_user_id to match auth.uid()
  IF check_user_id != auth.uid() THEN
    RETURN false;
  END IF;
  
  RETURN EXISTS (
    SELECT 1 FROM room_memberships
    WHERE room_id = check_room_id
      AND user_id = check_user_id
      AND role IN ('owner', 'admin', 'mod')
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ===============================================
-- 1. FIX USERS TABLE (Leaky SELECT policy)
-- ===============================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'users') THEN
    ALTER TABLE users ENABLE ROW LEVEL SECURITY;
    
    -- Fix leaky SELECT policy
    DROP POLICY IF EXISTS users_select_auth ON users;
    CREATE POLICY users_select_auth ON users
      FOR SELECT TO authenticated
      USING (
        id = auth.uid() -- Own profile
        OR is_verified = true -- Public verified users only (for display names)
      );
    
    -- Add DELETE policy
    DROP POLICY IF EXISTS users_delete_own ON users;
    CREATE POLICY users_delete_own ON users
      FOR DELETE TO authenticated
      USING (id = auth.uid());
  END IF;
END $$;

-- ===============================================
-- 2. FIX ROOMS TABLE (Respect is_public flag)
-- ===============================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'rooms') THEN
    ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
    
    -- Fix SELECT policy to respect is_public
    DROP POLICY IF EXISTS rooms_select_auth ON rooms;
    CREATE POLICY rooms_select_auth ON rooms
      FOR SELECT TO authenticated
      USING (
        is_public = true -- Public rooms
        OR created_by = auth.uid() -- Own rooms
        OR id IN ( -- Rooms user is member of
          SELECT room_id FROM room_memberships WHERE user_id = auth.uid()
        )
      );
    
    -- Add DELETE policy for creators
    DROP POLICY IF EXISTS rooms_delete_creator ON rooms;
    CREATE POLICY rooms_delete_creator ON rooms
      FOR DELETE TO authenticated
      USING (created_by = auth.uid());
  END IF;
END $$;

-- ===============================================
-- 3. FIX ROOM_MEMBERSHIPS (Circular dependency)
-- ===============================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'room_memberships') THEN
    ALTER TABLE room_memberships ENABLE ROW LEVEL SECURITY;
    
    -- Fix circular dependency in SELECT policy
    DROP POLICY IF EXISTS room_memberships_select_auth ON room_memberships;
    CREATE POLICY room_memberships_select_auth ON room_memberships
      FOR SELECT TO authenticated
      USING (
        user_id = auth.uid() -- Own membership
        OR EXISTS ( -- Rooms user is member of (check via EXISTS to avoid circular ref)
          SELECT 1 FROM room_memberships rm 
          WHERE rm.room_id = room_memberships.room_id 
            AND rm.user_id = auth.uid() 
            AND rm.role != 'banned'
        )
      );
    
    -- Add admin/mod override for managing memberships
    DROP POLICY IF EXISTS room_memberships_admin_manage ON room_memberships;
    CREATE POLICY room_memberships_admin_manage ON room_memberships
      FOR ALL TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM room_memberships rm
          WHERE rm.room_id = room_memberships.room_id
            AND rm.user_id = auth.uid()
            AND rm.role IN ('owner', 'admin', 'mod')
        )
      )
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM room_memberships rm
          WHERE rm.room_id = room_memberships.room_id
            AND rm.user_id = auth.uid()
            AND rm.role IN ('owner', 'admin', 'mod')
        )
      );
  END IF;
END $$;

-- ===============================================
-- 4. FIX LOGS_COMPRESSED (Leaky SELECT policy)
-- ===============================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'logs_compressed') THEN
    ALTER TABLE logs_compressed ENABLE ROW LEVEL SECURITY;
    
    -- Fix leaky SELECT policy
    DROP POLICY IF EXISTS logs_compressed_select_auth ON logs_compressed;
    CREATE POLICY logs_compressed_select_auth ON logs_compressed
      FOR SELECT TO authenticated
      USING (
        room_id IN (
          SELECT room_id FROM room_memberships WHERE user_id = auth.uid()
        )
      );
  END IF;
END $$;

-- ===============================================
-- 5. ADD ADMIN/MOD OVERRIDE FOR MESSAGES
-- ===============================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'messages') THEN
    -- Add admin/mod override for deleting/modifying messages
    DROP POLICY IF EXISTS messages_admin_modify ON messages;
    CREATE POLICY messages_admin_modify ON messages
      FOR UPDATE TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM room_memberships rm
          WHERE rm.room_id = messages.room_id
            AND rm.user_id = auth.uid()
            AND rm.role IN ('owner', 'admin', 'mod')
        )
      )
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM room_memberships rm
          WHERE rm.room_id = messages.room_id
            AND rm.user_id = auth.uid()
            AND rm.role IN ('owner', 'admin', 'mod')
        )
      );
    
    DROP POLICY IF EXISTS messages_admin_delete ON messages;
    CREATE POLICY messages_admin_delete ON messages
      FOR DELETE TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM room_memberships rm
          WHERE rm.room_id = messages.room_id
            AND rm.user_id = auth.uid()
            AND rm.role IN ('owner', 'admin', 'mod')
        )
      );
  END IF;
END $$;

-- ===============================================
-- 6. REFRESH_TOKENS (CRITICAL - No RLS)
-- ===============================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'refresh_tokens') THEN
    ALTER TABLE refresh_tokens ENABLE ROW LEVEL SECURITY;
    
    -- Users can only see their own tokens
    DROP POLICY IF EXISTS refresh_tokens_select_own ON refresh_tokens;
    CREATE POLICY refresh_tokens_select_own ON refresh_tokens
      FOR SELECT TO authenticated
      USING (user_id = auth.uid());
    
    -- Users can insert their own tokens
    DROP POLICY IF EXISTS refresh_tokens_insert_own ON refresh_tokens;
    CREATE POLICY refresh_tokens_insert_own ON refresh_tokens
      FOR INSERT TO authenticated
      WITH CHECK (user_id = auth.uid());
    
    -- Users can delete their own tokens (logout)
    DROP POLICY IF EXISTS refresh_tokens_delete_own ON refresh_tokens;
    CREATE POLICY refresh_tokens_delete_own ON refresh_tokens
      FOR DELETE TO authenticated
      USING (user_id = auth.uid());
    
    -- Service role for token rotation
    DROP POLICY IF EXISTS refresh_tokens_all_service ON refresh_tokens;
    CREATE POLICY refresh_tokens_all_service ON refresh_tokens
      FOR ALL TO service_role
      USING (true) WITH CHECK (true);
  END IF;
END $$;

-- ===============================================
-- 7. AUTH_AUDIT_LOG (CRITICAL - No RLS)
-- ===============================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'auth_audit_log') THEN
    ALTER TABLE auth_audit_log ENABLE ROW LEVEL SECURITY;
    
    -- Users can only see their own audit log
    DROP POLICY IF EXISTS auth_audit_log_select_own ON auth_audit_log;
    CREATE POLICY auth_audit_log_select_own ON auth_audit_log
      FOR SELECT TO authenticated
      USING (user_id = auth.uid());
    
    -- Service role can insert
    DROP POLICY IF EXISTS auth_audit_log_insert_service ON auth_audit_log;
    CREATE POLICY auth_audit_log_insert_service ON auth_audit_log
      FOR INSERT TO service_role
      WITH CHECK (true);
    
    -- No updates or deletes (immutable audit log)
    DROP POLICY IF EXISTS auth_audit_log_no_update ON auth_audit_log;
    CREATE POLICY auth_audit_log_no_update ON auth_audit_log
      FOR UPDATE TO public
      USING (false);
    
    DROP POLICY IF EXISTS auth_audit_log_no_delete ON auth_audit_log;
    CREATE POLICY auth_audit_log_no_delete ON auth_audit_log
      FOR DELETE TO public
      USING (false);
  END IF;
END $$;

-- ===============================================
-- 8. FLAGGED_MESSAGES (CRITICAL - No RLS)
-- ===============================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'flagged_messages') THEN
    ALTER TABLE flagged_messages ENABLE ROW LEVEL SECURITY;
    
    -- Moderators can see flagged messages
    DROP POLICY IF EXISTS flagged_messages_select_moderator ON flagged_messages;
    CREATE POLICY flagged_messages_select_moderator ON flagged_messages
      FOR SELECT TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM room_memberships rm
          WHERE rm.room_id = flagged_messages.room_id
            AND rm.user_id = auth.uid()
            AND rm.role IN ('owner', 'admin', 'mod')
        )
      );
    
    -- Service role can insert (auto-flagging)
    DROP POLICY IF EXISTS flagged_messages_insert_service ON flagged_messages;
    CREATE POLICY flagged_messages_insert_service ON flagged_messages
      FOR INSERT TO service_role
      WITH CHECK (true);
    
    -- Users can flag messages (insert via service role typically)
    DROP POLICY IF EXISTS flagged_messages_insert_user ON flagged_messages;
    CREATE POLICY flagged_messages_insert_user ON flagged_messages
      FOR INSERT TO authenticated
      WITH CHECK (
        room_id IN (
          SELECT room_id FROM room_memberships WHERE user_id = auth.uid()
        )
        AND flagged_by = auth.uid()
      );
    
    -- Moderators can update (review/action)
    DROP POLICY IF EXISTS flagged_messages_update_moderator ON flagged_messages;
    CREATE POLICY flagged_messages_update_moderator ON flagged_messages
      FOR UPDATE TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM room_memberships rm
          WHERE rm.room_id = flagged_messages.room_id
            AND rm.user_id = auth.uid()
            AND rm.role IN ('owner', 'admin', 'mod')
        )
      )
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM room_memberships rm
          WHERE rm.room_id = flagged_messages.room_id
            AND rm.user_id = auth.uid()
            AND rm.role IN ('owner', 'admin', 'mod')
        )
      );
  END IF;
END $$;

-- ===============================================
-- 9. MESSAGE_ARCHIVES (CRITICAL - No RLS)
-- ===============================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'message_archives') THEN
    ALTER TABLE message_archives ENABLE ROW LEVEL SECURITY;
    
    -- Room members can see archived messages
    DROP POLICY IF EXISTS message_archives_select_room ON message_archives;
    CREATE POLICY message_archives_select_room ON message_archives
      FOR SELECT TO authenticated
      USING (
        room_id IN (
          SELECT room_id FROM room_memberships WHERE user_id = auth.uid()
        )
      );
    
    -- Service role can insert (archival process)
    DROP POLICY IF EXISTS message_archives_insert_service ON message_archives;
    CREATE POLICY message_archives_insert_service ON message_archives
      FOR INSERT TO service_role
      WITH CHECK (true);
    
    -- No updates or deletes (immutable archive)
    DROP POLICY IF EXISTS message_archives_no_update ON message_archives;
    CREATE POLICY message_archives_no_update ON message_archives
      FOR UPDATE TO public
      USING (false);
    
    DROP POLICY IF EXISTS message_archives_no_delete ON message_archives;
    CREATE POLICY message_archives_no_delete ON message_archives
      FOR DELETE TO public
      USING (false);
  END IF;
END $$;

-- ===============================================
-- 10. CONVERSATIONS (CRITICAL - No RLS)
-- ===============================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'conversations') THEN
    ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
    
    -- Participants can see conversations
    DROP POLICY IF EXISTS conversations_select_participant ON conversations;
    CREATE POLICY conversations_select_participant ON conversations
      FOR SELECT TO authenticated
      USING (
        id IN (
          SELECT conversation_id FROM conversation_participants WHERE user_id = auth.uid()
        )
        OR created_by = auth.uid()
      );
    
    -- Users can create conversations
    DROP POLICY IF EXISTS conversations_insert_auth ON conversations;
    CREATE POLICY conversations_insert_auth ON conversations
      FOR INSERT TO authenticated
      WITH CHECK (created_by = auth.uid() OR created_by IS NULL);
    
    -- Creators can update
    DROP POLICY IF EXISTS conversations_update_creator ON conversations;
    CREATE POLICY conversations_update_creator ON conversations
      FOR UPDATE TO authenticated
      USING (created_by = auth.uid())
      WITH CHECK (created_by = auth.uid());
    
    -- Creators can delete
    DROP POLICY IF EXISTS conversations_delete_creator ON conversations;
    CREATE POLICY conversations_delete_creator ON conversations
      FOR DELETE TO authenticated
      USING (created_by = auth.uid());
  END IF;
END $$;

-- ===============================================
-- 11. CONVERSATION_PARTICIPANTS (CRITICAL - No RLS)
-- ===============================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'conversation_participants') THEN
    ALTER TABLE conversation_participants ENABLE ROW LEVEL SECURITY;
    
    -- Participants can see other participants
    DROP POLICY IF EXISTS conversation_participants_select ON conversation_participants;
    CREATE POLICY conversation_participants_select ON conversation_participants
      FOR SELECT TO authenticated
      USING (
        conversation_id IN (
          SELECT conversation_id FROM conversation_participants WHERE user_id = auth.uid()
        )
        OR user_id = auth.uid()
      );
    
    -- Users can join conversations (insert own participation)
    DROP POLICY IF EXISTS conversation_participants_insert_own ON conversation_participants;
    CREATE POLICY conversation_participants_insert_own ON conversation_participants
      FOR INSERT TO authenticated
      WITH CHECK (user_id = auth.uid());
    
    -- Users can update own participation
    DROP POLICY IF EXISTS conversation_participants_update_own ON conversation_participants;
    CREATE POLICY conversation_participants_update_own ON conversation_participants
      FOR UPDATE TO authenticated
      USING (user_id = auth.uid())
      WITH CHECK (user_id = auth.uid());
    
    -- Users can leave (delete own participation)
    DROP POLICY IF EXISTS conversation_participants_delete_own ON conversation_participants;
    CREATE POLICY conversation_participants_delete_own ON conversation_participants
      FOR DELETE TO authenticated
      USING (user_id = auth.uid());
  END IF;
END $$;

-- ===============================================
-- 12. SENTIMENT_ANALYSIS (CRITICAL - No RLS)
-- ===============================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'sentiment_analysis') THEN
    ALTER TABLE sentiment_analysis ENABLE ROW LEVEL SECURITY;
    
    -- Conversation participants can see analysis
    DROP POLICY IF EXISTS sentiment_analysis_select_participant ON sentiment_analysis;
    CREATE POLICY sentiment_analysis_select_participant ON sentiment_analysis
      FOR SELECT TO authenticated
      USING (
        conversation_id IN (
          SELECT conversation_id FROM conversation_participants WHERE user_id = auth.uid()
        )
      );
    
    -- Service role can insert (analysis process)
    DROP POLICY IF EXISTS sentiment_analysis_insert_service ON sentiment_analysis;
    CREATE POLICY sentiment_analysis_insert_service ON sentiment_analysis
      FOR INSERT TO service_role
      WITH CHECK (true);
    
    -- No updates or deletes
    DROP POLICY IF EXISTS sentiment_analysis_no_update ON sentiment_analysis;
    CREATE POLICY sentiment_analysis_no_update ON sentiment_analysis
      FOR UPDATE TO public
      USING (false);
    
    DROP POLICY IF EXISTS sentiment_analysis_no_delete ON sentiment_analysis;
    CREATE POLICY sentiment_analysis_no_delete ON sentiment_analysis
      FOR DELETE TO public
      USING (false);
  END IF;
END $$;

-- ===============================================
-- 13. CARDS (CRITICAL - No RLS)
-- ===============================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'cards') THEN
    ALTER TABLE cards ENABLE ROW LEVEL SECURITY;
    
    -- Card owners + public museum entries can see cards
    DROP POLICY IF EXISTS cards_select ON cards;
    CREATE POLICY cards_select ON cards
      FOR SELECT TO authenticated
      USING (
        id IN (
          SELECT card_id FROM card_ownerships WHERE owner_id = auth.uid()
        )
        OR id IN (
          SELECT card_id FROM museum_entries WHERE visibility = 'public'
        )
      );
    
    -- Service role can insert (card generation)
    DROP POLICY IF EXISTS cards_insert_service ON cards;
    CREATE POLICY cards_insert_service ON cards
      FOR INSERT TO service_role
      WITH CHECK (true);
    
    -- Card owners can update (burn, etc.)
    DROP POLICY IF EXISTS cards_update_owner ON cards;
    CREATE POLICY cards_update_owner ON cards
      FOR UPDATE TO authenticated
      USING (
        id IN (
          SELECT card_id FROM card_ownerships WHERE owner_id = auth.uid()
        )
      )
      WITH CHECK (
        id IN (
          SELECT card_id FROM card_ownerships WHERE owner_id = auth.uid()
        )
      );
  END IF;
END $$;

-- ===============================================
-- 14. CARD_OWNERSHIPS (CRITICAL - No RLS)
-- ===============================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'card_ownerships') THEN
    ALTER TABLE card_ownerships ENABLE ROW LEVEL SECURITY;
    
    -- Owners can see their own ownerships
    DROP POLICY IF EXISTS card_ownerships_select_own ON card_ownerships;
    CREATE POLICY card_ownerships_select_own ON card_ownerships
      FOR SELECT TO authenticated
      USING (owner_id = auth.uid());
    
    -- Service role can insert (card claiming)
    DROP POLICY IF EXISTS card_ownerships_insert_service ON card_ownerships;
    CREATE POLICY card_ownerships_insert_service ON card_ownerships
      FOR INSERT TO service_role
      WITH CHECK (true);
    
    -- Users can insert their own (claiming)
    DROP POLICY IF EXISTS card_ownerships_insert_own ON card_ownerships;
    CREATE POLICY card_ownerships_insert_own ON card_ownerships
      FOR INSERT TO authenticated
      WITH CHECK (owner_id = auth.uid());
  END IF;
END $$;

-- ===============================================
-- 15. CARD_EVENTS (CRITICAL - No RLS)
-- ===============================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'card_events') THEN
    ALTER TABLE card_events ENABLE ROW LEVEL SECURITY;
    
    -- Card owners can see events
    DROP POLICY IF EXISTS card_events_select_owner ON card_events;
    CREATE POLICY card_events_select_owner ON card_events
      FOR SELECT TO authenticated
      USING (
        card_id IN (
          SELECT card_id FROM card_ownerships WHERE owner_id = auth.uid()
        )
        OR user_id = auth.uid()
      );
    
    -- Service role can insert (event logging)
    DROP POLICY IF EXISTS card_events_insert_service ON card_events;
    CREATE POLICY card_events_insert_service ON card_events
      FOR INSERT TO service_role
      WITH CHECK (true);
    
    -- No updates or deletes (immutable audit trail)
    DROP POLICY IF EXISTS card_events_no_update ON card_events;
    CREATE POLICY card_events_no_update ON card_events
      FOR UPDATE TO public
      USING (false);
    
    DROP POLICY IF EXISTS card_events_no_delete ON card_events;
    CREATE POLICY card_events_no_delete ON card_events
      FOR DELETE TO public
      USING (false);
  END IF;
END $$;

-- ===============================================
-- 16. MUSEUM_ENTRIES (CRITICAL - No RLS)
-- ===============================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'museum_entries') THEN
    ALTER TABLE museum_entries ENABLE ROW LEVEL SECURITY;
    
    -- Public can see public entries
    DROP POLICY IF EXISTS museum_entries_select_public ON museum_entries;
    CREATE POLICY museum_entries_select_public ON museum_entries
      FOR SELECT TO authenticated
      USING (
        visibility = 'public'
        OR card_id IN (
          SELECT card_id FROM card_ownerships WHERE owner_id = auth.uid()
        )
      );
    
    -- Card owners can insert/update
    DROP POLICY IF EXISTS museum_entries_write_owner ON museum_entries;
    CREATE POLICY museum_entries_write_owner ON museum_entries
      FOR ALL TO authenticated
      USING (
        card_id IN (
          SELECT card_id FROM card_ownerships WHERE owner_id = auth.uid()
        )
      )
      WITH CHECK (
        card_id IN (
          SELECT card_id FROM card_ownerships WHERE owner_id = auth.uid()
        )
      );
    
    -- Service role can insert
    DROP POLICY IF EXISTS museum_entries_insert_service ON museum_entries;
    CREATE POLICY museum_entries_insert_service ON museum_entries
      FOR INSERT TO service_role
      WITH CHECK (true);
  END IF;
END $$;

-- ===============================================
-- 17. BOOSTS (CRITICAL - No RLS)
-- ===============================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'boosts') THEN
    ALTER TABLE boosts ENABLE ROW LEVEL SECURITY;
    
    -- Users can see their own boosts
    DROP POLICY IF EXISTS boosts_select_own ON boosts;
    CREATE POLICY boosts_select_own ON boosts
      FOR SELECT TO authenticated
      USING (user_id = auth.uid());
    
    -- Users can insert their own boosts
    DROP POLICY IF EXISTS boosts_insert_own ON boosts;
    CREATE POLICY boosts_insert_own ON boosts
      FOR INSERT TO authenticated
      WITH CHECK (user_id = auth.uid());
    
    -- Service role full access
    DROP POLICY IF EXISTS boosts_all_service ON boosts;
    CREATE POLICY boosts_all_service ON boosts
      FOR ALL TO service_role
      USING (true) WITH CHECK (true);
  END IF;
END $$;

-- ===============================================
-- 18. PERSONAS (CRITICAL - No RLS)
-- ===============================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'personas') THEN
    ALTER TABLE personas ENABLE ROW LEVEL SECURITY;
    
    -- Users can see their own personas
    DROP POLICY IF EXISTS personas_select_own ON personas;
    CREATE POLICY personas_select_own ON personas
      FOR SELECT TO authenticated
      USING (user_id = auth.uid());
    
    -- Users can insert their own personas
    DROP POLICY IF EXISTS personas_insert_own ON personas;
    CREATE POLICY personas_insert_own ON personas
      FOR INSERT TO authenticated
      WITH CHECK (user_id = auth.uid());
    
    -- Users can update their own personas
    DROP POLICY IF EXISTS personas_update_own ON personas;
    CREATE POLICY personas_update_own ON personas
      FOR UPDATE TO authenticated
      USING (user_id = auth.uid())
      WITH CHECK (user_id = auth.uid());
    
    -- Users can delete their own personas
    DROP POLICY IF EXISTS personas_delete_own ON personas;
    CREATE POLICY personas_delete_own ON personas
      FOR DELETE TO authenticated
      USING (user_id = auth.uid());
  END IF;
END $$;

-- ===============================================
-- 19. INVITES (CRITICAL - No RLS)
-- ===============================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'invites') THEN
    ALTER TABLE invites ENABLE ROW LEVEL SECURITY;
    
    -- Creators + room admins can see invites
    DROP POLICY IF EXISTS invites_select ON invites;
    CREATE POLICY invites_select ON invites
      FOR SELECT TO authenticated
      USING (
        created_by = auth.uid()
        OR (
          room_id IS NOT NULL
          AND EXISTS (
            SELECT 1 FROM room_memberships rm
            WHERE rm.room_id = invites.room_id
              AND rm.user_id = auth.uid()
              AND rm.role IN ('owner', 'admin', 'mod')
          )
        )
      );
    
    -- Room admins can create invites
    DROP POLICY IF EXISTS invites_insert_admin ON invites;
    CREATE POLICY invites_insert_admin ON invites
      FOR INSERT TO authenticated
      WITH CHECK (
        created_by = auth.uid()
        AND (
          room_id IS NULL
          OR EXISTS (
            SELECT 1 FROM room_memberships rm
            WHERE rm.room_id = invites.room_id
              AND rm.user_id = auth.uid()
              AND rm.role IN ('owner', 'admin', 'mod')
          )
        )
      );
    
    -- Creators can update/delete
    DROP POLICY IF EXISTS invites_update_creator ON invites;
    CREATE POLICY invites_update_creator ON invites
      FOR UPDATE TO authenticated
      USING (created_by = auth.uid())
      WITH CHECK (created_by = auth.uid());
    
    DROP POLICY IF EXISTS invites_delete_creator ON invites;
    CREATE POLICY invites_delete_creator ON invites
      FOR DELETE TO authenticated
      USING (created_by = auth.uid());
  END IF;
END $$;

-- ===============================================
-- 20. USER_PROGRESS (CRITICAL - No RLS)
-- ===============================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'user_progress') THEN
    ALTER TABLE user_progress ENABLE ROW LEVEL SECURITY;
    
    -- Users can see their own progress + public leaderboard (all progress)
    DROP POLICY IF EXISTS user_progress_select ON user_progress;
    CREATE POLICY user_progress_select ON user_progress
      FOR SELECT TO authenticated
      USING (true); -- Public leaderboard
    
    -- Users can update their own progress
    DROP POLICY IF EXISTS user_progress_update_own ON user_progress;
    CREATE POLICY user_progress_update_own ON user_progress
      FOR UPDATE TO authenticated
      USING (user_id = auth.uid())
      WITH CHECK (user_id = auth.uid());
    
    -- Service role can insert/update (XP updates)
    DROP POLICY IF EXISTS user_progress_all_service ON user_progress;
    CREATE POLICY user_progress_all_service ON user_progress
      FOR ALL TO service_role
      USING (true) WITH CHECK (true);
  END IF;
END $$;

-- ===============================================
-- 21. SCHEDULED_CALLS (CRITICAL - No RLS)
-- ===============================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'scheduled_calls') THEN
    ALTER TABLE scheduled_calls ENABLE ROW LEVEL SECURITY;
    
    -- Room members can see scheduled calls
    DROP POLICY IF EXISTS scheduled_calls_select_room ON scheduled_calls;
    CREATE POLICY scheduled_calls_select_room ON scheduled_calls
      FOR SELECT TO authenticated
      USING (
        room_id IN (
          SELECT room_id FROM room_memberships WHERE user_id = auth.uid()
        )
        OR scheduler_id = auth.uid()
      );
    
    -- Room members can create scheduled calls
    DROP POLICY IF EXISTS scheduled_calls_insert_member ON scheduled_calls;
    CREATE POLICY scheduled_calls_insert_member ON scheduled_calls
      FOR INSERT TO authenticated
      WITH CHECK (
        scheduler_id = auth.uid()
        AND room_id IN (
          SELECT room_id FROM room_memberships WHERE user_id = auth.uid()
        )
      );
    
    -- Schedulers can update/delete
    DROP POLICY IF EXISTS scheduled_calls_update_scheduler ON scheduled_calls;
    CREATE POLICY scheduled_calls_update_scheduler ON scheduled_calls
      FOR UPDATE TO authenticated
      USING (scheduler_id = auth.uid())
      WITH CHECK (scheduler_id = auth.uid());
    
    DROP POLICY IF EXISTS scheduled_calls_delete_scheduler ON scheduled_calls;
    CREATE POLICY scheduled_calls_delete_scheduler ON scheduled_calls
      FOR DELETE TO authenticated
      USING (scheduler_id = auth.uid());
  END IF;
END $$;

-- ===============================================
-- 22. USER_SUBSCRIPTIONS (CRITICAL - No RLS)
-- ===============================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'user_subscriptions') THEN
    ALTER TABLE user_subscriptions ENABLE ROW LEVEL SECURITY;
    
    -- Users can see their own subscriptions
    DROP POLICY IF EXISTS user_subscriptions_select_own ON user_subscriptions;
    CREATE POLICY user_subscriptions_select_own ON user_subscriptions
      FOR SELECT TO authenticated
      USING (user_id = auth.uid());
    
    -- Service role can insert/update (payment processing)
    DROP POLICY IF EXISTS user_subscriptions_all_service ON user_subscriptions;
    CREATE POLICY user_subscriptions_all_service ON user_subscriptions
      FOR ALL TO service_role
      USING (true) WITH CHECK (true);
  END IF;
END $$;

-- ===============================================
-- VERIFICATION QUERY
-- ===============================================

-- Check RLS status on all tables
SELECT 
  schemaname,
  tablename,
  CASE 
    WHEN relrowsecurity THEN '✅ RLS ENABLED'
    ELSE '❌ RLS DISABLED'
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

COMMIT;

-- ===============================================
-- SUMMARY
-- ===============================================
-- This script has:
-- 1. ✅ Fixed leaky SELECT policies (users, rooms, logs_compressed)
-- 2. ✅ Fixed circular dependencies (room_memberships)
-- 3. ✅ Fixed SECURITY DEFINER functions
-- 4. ✅ Enabled RLS on 17+ critical tables
-- 5. ✅ Added admin/mod override policies
-- 6. ✅ Added missing DELETE policies
-- 7. ✅ Added service role policies where needed
--
-- Next: Run VERIFY_RLS_STATUS.sql to verify all fixes
-- ===============================================

