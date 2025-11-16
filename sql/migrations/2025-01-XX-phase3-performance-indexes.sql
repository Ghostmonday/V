-- ===============================================
-- Migration: Phase 3 - Performance Indexes
-- Purpose: Apply missing indexes from MISSING_INDEXES_REPORT.sql
-- Date: 2025-01-XX
-- Phase: 3.1 Performance Indexes
-- ===============================================

BEGIN;

-- ===============================================
-- HIGH PRIORITY INDEXES (Apply First)
-- ===============================================

-- 0 (REQUIRED FIRST: Add active_users column if it doesn't exist)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'rooms' AND column_name = 'active_users'
    ) THEN
        ALTER TABLE rooms ADD COLUMN active_users INT NOT NULL DEFAULT 0;
    END IF;
END $$;

-- 1. Room listing performance - ORDER BY active_users
CREATE INDEX IF NOT EXISTS idx_rooms_is_public_active_users 
ON rooms(is_public, active_users DESC NULLS LAST) 
WHERE is_public = TRUE;

-- 2. Message receipts FK index for JOINs
CREATE INDEX IF NOT EXISTS idx_message_receipts_message_id 
ON message_receipts(message_id);

-- 3. Message receipts FK index for batch queries
CREATE INDEX IF NOT EXISTS idx_message_receipts_user_id 
ON message_receipts(user_id);

-- 3a (REQUIRED FIRST: Add user_id column to pinned_items if it doesn't exist)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pinned_items' AND column_name = 'user_id'
    ) THEN
        -- Check if pinned_by exists (old schema)
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'pinned_items' AND column_name = 'pinned_by'
        ) THEN
            -- Migrate: rename pinned_by to user_id
            ALTER TABLE pinned_items RENAME COLUMN pinned_by TO user_id;
            ALTER TABLE pinned_items ALTER COLUMN user_id SET NOT NULL;
        ELSE
            -- Add new user_id column
            ALTER TABLE pinned_items ADD COLUMN user_id UUID REFERENCES users(id) ON DELETE CASCADE;
            ALTER TABLE pinned_items ALTER COLUMN user_id SET NOT NULL;
        END IF;
    END IF;
END $$;

-- 4. Pinned items FK index
CREATE INDEX IF NOT EXISTS idx_pinned_items_user_id 
ON pinned_items(user_id);

-- 5. Pinned items composite lookup optimization
CREATE INDEX IF NOT EXISTS idx_pinned_items_user_room 
ON pinned_items(user_id, room_id);

-- ===============================================
-- NORMAL PRIORITY INDEXES (Apply After High Priority)
-- ===============================================

-- 6. Room private queries
CREATE INDEX IF NOT EXISTS idx_rooms_is_private 
ON rooms(is_private) 
WHERE is_private = TRUE;

-- 7. Message receipts composite optimization
CREATE INDEX IF NOT EXISTS idx_message_receipts_message_user 
ON message_receipts(message_id, user_id);

-- 7a (REQUIRED FIRST: Add nickname column to room_memberships if it doesn't exist)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'room_memberships' AND column_name = 'nickname'
    ) THEN
        ALTER TABLE room_memberships ADD COLUMN nickname TEXT;
    END IF;
END $$;

-- 8. Room memberships nickname queries
CREATE INDEX IF NOT EXISTS idx_room_memberships_room_nickname 
ON room_memberships(room_id, nickname) 
WHERE nickname IS NOT NULL;

-- 9. Pinned items room queries
CREATE INDEX IF NOT EXISTS idx_pinned_items_room_id 
ON pinned_items(room_id);

-- 10. Presence logs status queries
CREATE INDEX IF NOT EXISTS idx_presence_logs_status_created 
ON presence_logs(status, created_at DESC);

-- 11. UX telemetry user queries
CREATE INDEX IF NOT EXISTS idx_ux_telemetry_user_created 
ON ux_telemetry(user_id, created_at DESC) 
WHERE user_id IS NOT NULL;

-- 12. Files user queries
CREATE INDEX IF NOT EXISTS idx_files_user_id 
ON files(user_id) 
WHERE user_id IS NOT NULL;

-- 13. Files room queries
CREATE INDEX IF NOT EXISTS idx_files_room_id 
ON files(room_id) 
WHERE room_id IS NOT NULL;

-- 14. Subscriptions status queries
CREATE INDEX IF NOT EXISTS idx_subscriptions_status 
ON subscriptions(status) 
WHERE status = 'active';

-- 14a (REQUIRED FIRST: Check if created_by or creator_id exists, add if needed)
DO $$ 
BEGIN
    -- Check if created_by exists, if not check for creator_id
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'rooms' AND column_name = 'created_by'
    ) THEN
        -- Check if creator_id exists (alternative column name)
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'rooms' AND column_name = 'creator_id'
        ) THEN
            -- creator_id exists, create index on that instead
            CREATE INDEX IF NOT EXISTS idx_rooms_creator_id 
            ON rooms(creator_id) 
            WHERE creator_id IS NOT NULL;
        ELSE
            -- Neither exists, add created_by column
            ALTER TABLE rooms ADD COLUMN created_by UUID REFERENCES users(id) ON DELETE SET NULL;
            CREATE INDEX IF NOT EXISTS idx_rooms_created_by 
            ON rooms(created_by) 
            WHERE created_by IS NOT NULL;
        END IF;
    ELSE
        -- created_by exists, create index
        CREATE INDEX IF NOT EXISTS idx_rooms_created_by 
        ON rooms(created_by) 
        WHERE created_by IS NOT NULL;
    END IF;
END $$;

COMMIT;

-- ===============================================
-- VERIFICATION QUERY
-- ===============================================
-- Run this to verify indexes were created:
-- SELECT 
--   schemaname,
--   tablename,
--   indexname,
--   indexdef
-- FROM pg_indexes
-- WHERE schemaname = 'public'
--   AND indexname LIKE 'idx_%'
--   AND tablename IN (
--     'rooms', 'message_receipts', 'pinned_items', 
--     'room_memberships', 'presence_logs', 'ux_telemetry',
--     'files', 'subscriptions'
--   )
-- ORDER BY tablename, indexname;

