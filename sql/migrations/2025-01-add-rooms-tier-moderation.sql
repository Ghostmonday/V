-- ===============================================
-- FILE: 2025-01-add-rooms-tier-moderation.sql
-- PURPOSE: Add room tiers and AI moderation support
-- DEPENDENCIES: 01_vibez_schema.sql
-- ===============================================

-- Create room_tier enum type if it doesn't exist
DO $$ BEGIN
    CREATE TYPE room_tier AS ENUM ('free', 'pro', 'enterprise');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Add room tier and moderation columns to rooms table
ALTER TABLE rooms 
  ADD COLUMN IF NOT EXISTS ai_moderation BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS room_tier room_tier DEFAULT 'free',
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

-- Create moderation_flags table for logging moderation actions
CREATE TABLE IF NOT EXISTS moderation_flags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  message_id UUID REFERENCES messages(id) ON DELETE SET NULL,
  score FLOAT NOT NULL CHECK (score >= 0 AND score <= 1),
  label TEXT NOT NULL CHECK (label IN ('safe', 'toxic')),
  action_taken TEXT CHECK (action_taken IN ('warn', 'flag', 'remove')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for efficient queries
CREATE INDEX IF NOT EXISTS idx_moderation_flags_room_id ON moderation_flags(room_id);
CREATE INDEX IF NOT EXISTS idx_moderation_flags_created_at ON moderation_flags(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rooms_expires_at ON rooms(expires_at) WHERE expires_at IS NOT NULL;

