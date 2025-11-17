-- ===============================================
-- Phase 5: Per-Room Moderation Thresholds
-- Purpose: Allow room-specific moderation threshold overrides
-- ===============================================

BEGIN;

-- Create room_moderation_thresholds table for per-room custom thresholds
CREATE TABLE IF NOT EXISTS room_moderation_thresholds (
  room_id UUID PRIMARY KEY REFERENCES rooms(id) ON DELETE CASCADE,
  warn_threshold NUMERIC NOT NULL DEFAULT 0.6 CHECK (warn_threshold >= 0 AND warn_threshold <= 1),
  block_threshold NUMERIC NOT NULL DEFAULT 0.8 CHECK (block_threshold >= 0 AND block_threshold <= 1),
  enabled BOOLEAN NOT NULL DEFAULT true,
  updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT valid_thresholds CHECK (block_threshold >= warn_threshold)
);

-- Index for efficient lookups
CREATE INDEX IF NOT EXISTS idx_room_thresholds_enabled ON room_moderation_thresholds(room_id) WHERE enabled = true;

-- RLS policies
ALTER TABLE room_moderation_thresholds ENABLE ROW LEVEL SECURITY;

-- Only room owners and admins can view/update thresholds
CREATE POLICY room_thresholds_select ON room_moderation_thresholds
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM rooms 
      WHERE rooms.id = room_moderation_thresholds.room_id 
      AND (rooms.created_by = auth.uid() OR EXISTS (
        SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role IN ('admin', 'moderator')
      ))
    )
  );

CREATE POLICY room_thresholds_update ON room_moderation_thresholds
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM rooms 
      WHERE rooms.id = room_moderation_thresholds.room_id 
      AND (rooms.created_by = auth.uid() OR EXISTS (
        SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role IN ('admin', 'moderator')
      ))
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM rooms 
      WHERE rooms.id = room_moderation_thresholds.room_id 
      AND (rooms.created_by = auth.uid() OR EXISTS (
        SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role IN ('admin', 'moderator')
      ))
    )
  );

CREATE POLICY room_thresholds_insert ON room_moderation_thresholds
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM rooms 
      WHERE rooms.id = room_moderation_thresholds.room_id 
      AND (rooms.created_by = auth.uid() OR EXISTS (
        SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role IN ('admin', 'moderator')
      ))
    )
  );

COMMIT;

-- ===============================================
-- Validation
-- ===============================================
-- SELECT table_name FROM information_schema.tables WHERE table_name = 'room_moderation_thresholds';
-- SELECT * FROM room_moderation_thresholds LIMIT 1;

