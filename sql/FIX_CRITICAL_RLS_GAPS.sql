-- ===============================================
-- FIX CRITICAL RLS GAPS
-- Purpose: Fix critical tables that have RLS enabled but no policies
-- Run this to ensure all critical tables have proper policies
-- ===============================================

BEGIN;

-- ===============================================
-- LEGAL_HOLDS - Fix missing policies
-- ===============================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'legal_holds') THEN
    ALTER TABLE legal_holds ENABLE ROW LEVEL SECURITY;
    
    -- Drop any existing policies
    DROP POLICY IF EXISTS legal_holds_service_only ON legal_holds;
    DROP POLICY IF EXISTS legal_holds_deny_others ON legal_holds;
    
    -- Service role only
    CREATE POLICY legal_holds_service_only ON legal_holds
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
    
    -- Deny all others
    CREATE POLICY legal_holds_deny_others ON legal_holds
      FOR ALL
      TO public
      USING (false);
  END IF;
END $$;

-- ===============================================
-- LOGS_RAW - Fix missing policies
-- ===============================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'logs_raw') THEN
    ALTER TABLE logs_raw ENABLE ROW LEVEL SECURITY;
    
    -- Drop any existing policies
    DROP POLICY IF EXISTS logs_raw_service_only ON logs_raw;
    DROP POLICY IF EXISTS logs_raw_deny_others ON logs_raw;
    
    -- Service role only
    CREATE POLICY logs_raw_service_only ON logs_raw
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
    
    -- Deny all others
    CREATE POLICY logs_raw_deny_others ON logs_raw
      FOR ALL
      TO public
      USING (false);
  END IF;
END $$;

-- ===============================================
-- LOGS_COMPRESSED - Add missing INSERT policy
-- ===============================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'logs_compressed') THEN
    ALTER TABLE logs_compressed ENABLE ROW LEVEL SECURITY;
    
    -- Drop any existing policies
    DROP POLICY IF EXISTS logs_compressed_service_lifecycle ON logs_compressed;
    DROP POLICY IF EXISTS logs_compressed_select_auth ON logs_compressed;
    DROP POLICY IF EXISTS logs_compressed_insert_auth ON logs_compressed;
    
    -- Service role for lifecycle operations (includes INSERT)
    CREATE POLICY logs_compressed_service_lifecycle ON logs_compressed
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
    
    -- Authenticated users can select for fetch operations
    CREATE POLICY logs_compressed_select_auth ON logs_compressed
      FOR SELECT
      TO authenticated
      USING (
        room_id IN (
          SELECT room_id FROM room_memberships WHERE user_id = auth.uid()
        )
      );
    
    -- Authenticated users can insert (for application use)
    CREATE POLICY logs_compressed_insert_auth ON logs_compressed
      FOR INSERT
      TO authenticated
      WITH CHECK (
        room_id IN (
          SELECT room_id FROM room_memberships WHERE user_id = auth.uid()
        )
      );
  END IF;
END $$;

-- ===============================================
-- MESSAGE_RECEIPTS - Add explicit INSERT policy
-- ===============================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'message_receipts') THEN
    ALTER TABLE message_receipts ENABLE ROW LEVEL SECURITY;
    
    -- Drop any existing policies
    DROP POLICY IF EXISTS message_receipts_select ON message_receipts;
    DROP POLICY IF EXISTS message_receipts_insert ON message_receipts;
    DROP POLICY IF EXISTS message_receipts_update_own ON message_receipts;
    DROP POLICY IF EXISTS message_receipts_delete_own ON message_receipts;
    DROP POLICY IF EXISTS message_receipts_own ON message_receipts;
    DROP POLICY IF EXISTS message_receipts_all_service ON message_receipts;
    
    -- Users can see receipts for messages they can see
    CREATE POLICY message_receipts_select ON message_receipts
      FOR SELECT
      TO authenticated
      USING (
        message_id IN (
          SELECT id FROM messages
          WHERE room_id IN (
            SELECT room_id FROM room_memberships
            WHERE user_id = auth.uid()
          )
        )
      );
    
    -- Users can insert their own receipts
    CREATE POLICY message_receipts_insert ON message_receipts
      FOR INSERT
      TO authenticated
      WITH CHECK (user_id = auth.uid());
    
    -- Users can update their own receipts
    CREATE POLICY message_receipts_update_own ON message_receipts
      FOR UPDATE
      TO authenticated
      USING (user_id = auth.uid())
      WITH CHECK (user_id = auth.uid());
    
    -- Users can delete their own receipts
    CREATE POLICY message_receipts_delete_own ON message_receipts
      FOR DELETE
      TO authenticated
      USING (user_id = auth.uid());
    
    -- Service role has full access
    CREATE POLICY message_receipts_all_service ON message_receipts
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
  END IF;
END $$;

-- ===============================================
-- RETENTION_SCHEDULE - Fix missing policies
-- ===============================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'retention_schedule') THEN
    ALTER TABLE retention_schedule ENABLE ROW LEVEL SECURITY;
    
    -- Drop any existing policies
    DROP POLICY IF EXISTS retention_schedule_service_only ON retention_schedule;
    DROP POLICY IF EXISTS retention_schedule_deny_others ON retention_schedule;
    
    -- Service role only
    CREATE POLICY retention_schedule_service_only ON retention_schedule
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
    
    -- Deny all others
    CREATE POLICY retention_schedule_deny_others ON retention_schedule
      FOR ALL
      TO public
      USING (false);
  END IF;
END $$;

-- ===============================================
-- TELEMETRY - Fix missing policies
-- ===============================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'telemetry') THEN
    ALTER TABLE telemetry ENABLE ROW LEVEL SECURITY;
    
    -- Drop any existing policies
    DROP POLICY IF EXISTS telemetry_service_only ON telemetry;
    DROP POLICY IF EXISTS telemetry_deny_others ON telemetry;
    DROP POLICY IF EXISTS telemetry_read_own ON telemetry;
    
    -- Service role only
    CREATE POLICY telemetry_service_only ON telemetry
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
    
    -- Deny all others
    CREATE POLICY telemetry_deny_others ON telemetry
      FOR ALL
      TO public
      USING (false);
  END IF;
END $$;

-- ===============================================
-- METRICS - Fix missing policies
-- ===============================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'metrics') THEN
    ALTER TABLE metrics ENABLE ROW LEVEL SECURITY;
    
    -- Drop any existing policies
    DROP POLICY IF EXISTS metrics_service_only ON metrics;
    DROP POLICY IF EXISTS metrics_deny_others ON metrics;
    
    -- Service role only
    CREATE POLICY metrics_service_only ON metrics
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
    
    -- Deny all others
    CREATE POLICY metrics_deny_others ON metrics
      FOR ALL
      TO public
      USING (false);
  END IF;
END $$;

-- ===============================================
-- API_KEYS - Fix missing policies
-- ===============================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'api_keys') THEN
    ALTER TABLE api_keys ENABLE ROW LEVEL SECURITY;
    
    -- Drop any existing policies
    DROP POLICY IF EXISTS api_keys_service_role_only ON api_keys;
    DROP POLICY IF EXISTS api_keys_deny_all ON api_keys;
    
    -- Service role only
    CREATE POLICY api_keys_service_role_only ON api_keys
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
    
    -- Deny all others
    CREATE POLICY api_keys_deny_all ON api_keys
      FOR ALL
      TO public
      USING (false);
  END IF;
END $$;

-- ===============================================
-- CONFIG - Fix missing policies
-- ===============================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'config') THEN
    ALTER TABLE config ENABLE ROW LEVEL SECURITY;
    
    -- Drop any existing policies
    DROP POLICY IF EXISTS config_service_only ON config;
    DROP POLICY IF EXISTS config_deny_others ON config;
    
    -- Service role only
    CREATE POLICY config_service_only ON config
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
    
    -- Deny all others
    CREATE POLICY config_deny_others ON config
      FOR ALL
      TO public
      USING (false);
  END IF;
END $$;

-- ===============================================
-- NICKNAMES - Enable RLS and add policies
-- ===============================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'nicknames') THEN
    ALTER TABLE nicknames ENABLE ROW LEVEL SECURITY;
    
    -- Drop any existing policies
    DROP POLICY IF EXISTS nicknames_select_room ON nicknames;
    DROP POLICY IF EXISTS nicknames_update_own ON nicknames;
    DROP POLICY IF EXISTS nicknames_all_service ON nicknames;
    
    -- Room members can see nicknames in their rooms
    CREATE POLICY nicknames_select_room ON nicknames
      FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = 'nicknames' AND column_name = 'room_id'
        )
        AND (
          SELECT room_id FROM nicknames WHERE nicknames.id = nicknames.id
        ) IN (
          SELECT room_id FROM room_memberships WHERE user_id = auth.uid()
        )
      );
    
    -- Users can update their own nicknames
    CREATE POLICY nicknames_update_own ON nicknames
      FOR UPDATE
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = 'nicknames' AND column_name = 'user_id'
        )
        AND (
          SELECT user_id FROM nicknames WHERE nicknames.id = nicknames.id
        ) = auth.uid()
      )
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = 'nicknames' AND column_name = 'user_id'
        )
        AND (
          SELECT user_id FROM nicknames WHERE nicknames.id = nicknames.id
        ) = auth.uid()
      );
    
    -- Service role has full access
    CREATE POLICY nicknames_all_service ON nicknames
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
  END IF;
END $$;

-- ===============================================
-- READ_RECEIPTS - Enable RLS and add policies
-- ===============================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'read_receipts') THEN
    ALTER TABLE read_receipts ENABLE ROW LEVEL SECURITY;
    
    -- Drop any existing policies
    DROP POLICY IF EXISTS read_receipts_select ON read_receipts;
    DROP POLICY IF EXISTS read_receipts_insert ON read_receipts;
    DROP POLICY IF EXISTS read_receipts_update_own ON read_receipts;
    DROP POLICY IF EXISTS read_receipts_delete_own ON read_receipts;
    DROP POLICY IF EXISTS read_receipts_own ON read_receipts;
    DROP POLICY IF EXISTS read_receipts_all_service ON read_receipts;
    
    -- Users can see receipts for messages they can see
    CREATE POLICY read_receipts_select ON read_receipts
      FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = 'read_receipts' AND column_name = 'message_id'
        )
        AND (
          SELECT message_id FROM read_receipts WHERE read_receipts.id = read_receipts.id
        ) IN (
          SELECT id FROM messages
          WHERE room_id IN (
            SELECT room_id FROM room_memberships WHERE user_id = auth.uid()
          )
        )
      );
    
    -- Users can insert their own receipts
    CREATE POLICY read_receipts_insert ON read_receipts
      FOR INSERT
      TO authenticated
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = 'read_receipts' AND column_name = 'user_id'
        )
        AND (
          SELECT user_id FROM read_receipts WHERE read_receipts.id = read_receipts.id
        ) = auth.uid()
      );
    
    -- Users can update their own receipts
    CREATE POLICY read_receipts_update_own ON read_receipts
      FOR UPDATE
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = 'read_receipts' AND column_name = 'user_id'
        )
        AND (
          SELECT user_id FROM read_receipts WHERE read_receipts.id = read_receipts.id
        ) = auth.uid()
      )
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = 'read_receipts' AND column_name = 'user_id'
        )
        AND (
          SELECT user_id FROM read_receipts WHERE read_receipts.id = read_receipts.id
        ) = auth.uid()
      );
    
    -- Users can delete their own receipts
    CREATE POLICY read_receipts_delete_own ON read_receipts
      FOR DELETE
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = 'read_receipts' AND column_name = 'user_id'
        )
        AND (
          SELECT user_id FROM read_receipts WHERE read_receipts.id = read_receipts.id
        ) = auth.uid()
      );
    
    -- Service role has full access
    CREATE POLICY read_receipts_all_service ON read_receipts
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
  END IF;
END $$;

-- ===============================================
-- ROOM_MEMBERS - Add policies
-- ===============================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'room_members') THEN
    ALTER TABLE room_members ENABLE ROW LEVEL SECURITY;
    
    -- Drop any existing policies
    DROP POLICY IF EXISTS room_members_select_room ON room_members;
    DROP POLICY IF EXISTS room_members_insert_own ON room_members;
    DROP POLICY IF EXISTS room_members_delete_own ON room_members;
    DROP POLICY IF EXISTS room_members_all_service ON room_members;
    
    -- Room members can see members in their rooms
    CREATE POLICY room_members_select_room ON room_members
      FOR SELECT
      TO authenticated
      USING (
        room_id IN (
          SELECT room_id FROM room_memberships WHERE user_id = auth.uid()
        )
      );
    
    -- Users can join rooms (insert their own membership)
    CREATE POLICY room_members_insert_own ON room_members
      FOR INSERT
      TO authenticated
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = 'room_members' AND column_name = 'user_id'
        )
        AND (
          SELECT user_id FROM room_members WHERE room_members.id = room_members.id
        ) = auth.uid()
      );
    
    -- Users can leave rooms (delete their own membership)
    CREATE POLICY room_members_delete_own ON room_members
      FOR DELETE
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = 'room_members' AND column_name = 'user_id'
        )
        AND (
          SELECT user_id FROM room_members WHERE room_members.id = room_members.id
        ) = auth.uid()
      );
    
    -- Service role has full access
    CREATE POLICY room_members_all_service ON room_members
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
  END IF;
END $$;

-- ===============================================
-- UX_TELEMETRY - Enable RLS and add policies
-- ===============================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'ux_telemetry') THEN
    ALTER TABLE ux_telemetry ENABLE ROW LEVEL SECURITY;
    
    -- Drop any existing policies
    DROP POLICY IF EXISTS ux_telemetry_select_own ON ux_telemetry;
    DROP POLICY IF EXISTS ux_telemetry_insert_own ON ux_telemetry;
    DROP POLICY IF EXISTS ux_telemetry_all_service ON ux_telemetry;
    
    -- Users can see their own UX telemetry
    CREATE POLICY ux_telemetry_select_own ON ux_telemetry
      FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = 'ux_telemetry' AND column_name = 'user_id'
        )
        AND (
          SELECT user_id FROM ux_telemetry WHERE ux_telemetry.id = ux_telemetry.id
        ) = auth.uid()
      );
    
    -- Users can insert their own UX telemetry
    CREATE POLICY ux_telemetry_insert_own ON ux_telemetry
      FOR INSERT
      TO authenticated
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = 'ux_telemetry' AND column_name = 'user_id'
        )
        AND (
          SELECT user_id FROM ux_telemetry WHERE ux_telemetry.id = ux_telemetry.id
        ) = auth.uid()
      );
    
    -- Service role has full access
    CREATE POLICY ux_telemetry_all_service ON ux_telemetry
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
  END IF;
END $$;

COMMIT;

-- ===============================================
-- VERIFICATION: Show fixed tables
-- ===============================================
SELECT 
  'FIXED_TABLES' AS report_type,
  schemaname || '.' || tablename AS table_name,
  COUNT(*) AS policy_count,
  STRING_AGG(cmd, ', ' ORDER BY cmd) AS policy_types
FROM pg_policies
WHERE schemaname IN ('public', 'service')
  AND tablename IN (
    'legal_holds', 'logs_raw', 'logs_compressed', 'message_receipts',
    'retention_schedule', 'telemetry', 'metrics', 'api_keys', 'config',
    'nicknames', 'read_receipts', 'room_members', 'ux_telemetry'
  )
GROUP BY schemaname, tablename
ORDER BY table_name;

