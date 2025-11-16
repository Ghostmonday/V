-- ===============================================
-- Migration: Room Member Count Trigger
-- Purpose: Automatically update room.active_users when members join/leave
-- Date: 2025-01-XX
-- ===============================================

BEGIN;

-- ===============================================
-- 1. Add active_users column to rooms if it doesn't exist
-- ===============================================
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'rooms' AND column_name = 'active_users'
    ) THEN
        ALTER TABLE rooms ADD COLUMN active_users INT NOT NULL DEFAULT 0;
        RAISE NOTICE 'Added active_users column to rooms table';
    ELSE
        RAISE NOTICE 'Column rooms.active_users already exists';
    END IF;
END $$;

-- ===============================================
-- 2. Create function to update room member count
-- ===============================================
CREATE OR REPLACE FUNCTION update_room_member_count()
RETURNS TRIGGER AS $$
BEGIN
    -- Update active_users count for the affected room
    IF TG_OP = 'INSERT' THEN
        -- Member joined - increment count
        UPDATE rooms 
        SET active_users = (
            SELECT COUNT(*) 
            FROM room_memberships 
            WHERE room_id = NEW.room_id
        )
        WHERE id = NEW.room_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        -- Member left - decrement count
        UPDATE rooms 
        SET active_users = (
            SELECT COUNT(*) 
            FROM room_memberships 
            WHERE room_id = OLD.room_id
        )
        WHERE id = OLD.room_id;
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Member updated (e.g., role change) - recalculate count
        UPDATE rooms 
        SET active_users = (
            SELECT COUNT(*) 
            FROM room_memberships 
            WHERE room_id = NEW.room_id
        )
        WHERE id = NEW.room_id;
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- ===============================================
-- 3. Create trigger on room_memberships
-- ===============================================
DROP TRIGGER IF EXISTS trigger_update_room_member_count ON room_memberships;

CREATE TRIGGER trigger_update_room_member_count
    AFTER INSERT OR UPDATE OR DELETE ON room_memberships
    FOR EACH ROW
    EXECUTE FUNCTION update_room_member_count();

-- ===============================================
-- 4. Initialize active_users for existing rooms
-- ===============================================
UPDATE rooms 
SET active_users = (
    SELECT COUNT(*) 
    FROM room_memberships 
    WHERE room_memberships.room_id = rooms.id
);

COMMIT;

-- ===============================================
-- Verification Query
-- ===============================================
-- Run this to verify trigger is working:
-- SELECT 
--     r.id,
--     r.title,
--     r.active_users,
--     (SELECT COUNT(*) FROM room_memberships WHERE room_id = r.id) as actual_count
-- FROM rooms r
-- LIMIT 10;

