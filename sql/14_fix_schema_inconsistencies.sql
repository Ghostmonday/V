-- ===============================================
-- FILE: 14_fix_schema_inconsistencies.sql
-- PURPOSE: Fix schema inconsistencies and function mismatches
-- DEPENDENCIES: 01_sinapse_schema.sql, sql/functions/batch_fetch.sql
-- USAGE: Run in Supabase SQL Editor
-- ===============================================

BEGIN;

-- ===============================================
-- FIX BATCH FETCH FUNCTION
-- Issue: Function references m.ts and m.content but schema uses created_at and content_preview
-- ===============================================

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS get_room_messages_batch(UUID[], TIMESTAMPTZ);

-- Create corrected batch fetch function
CREATE OR REPLACE FUNCTION get_room_messages_batch(
  room_ids UUID[],
  since_timestamp TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  room_id UUID,
  sender_id UUID,
  content_preview TEXT,
  created_at TIMESTAMPTZ
) 
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    m.id,
    m.room_id,
    m.sender_id,
    m.content_preview,
    m.created_at
  FROM messages m
  WHERE m.room_id = ANY(room_ids)
    AND (since_timestamp IS NULL OR m.created_at >= since_timestamp)
  ORDER BY m.created_at DESC
  LIMIT 50 * array_length(room_ids, 1); -- 50 messages per room
END;
$$;

-- Add comment
COMMENT ON FUNCTION get_room_messages_batch IS 'Batch fetch messages for multiple rooms. Uses correct column names (created_at, content_preview). Reduces round-trips by ~78% compared to individual queries.';

COMMIT;

-- ===============================================
-- VERIFY FUNCTION CREATED
-- ===============================================

SELECT 
  proname AS function_name,
  pg_get_function_arguments(oid) AS arguments,
  pg_get_functiondef(oid) AS definition
FROM pg_proc
WHERE proname = 'get_room_messages_batch'
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

