-- Create rooms table - Real implementation
-- Run this in Supabase SQL Editor

CREATE TABLE IF NOT EXISTS rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  creator_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  is_private BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create room_members table for join tracking
CREATE TABLE IF NOT EXISTS room_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(room_id, user_id)
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_room_members_room_user ON room_members(room_id, user_id);
CREATE INDEX IF NOT EXISTS idx_rooms_creator ON rooms(creator_id);
CREATE INDEX IF NOT EXISTS idx_rooms_private ON rooms(is_private);

-- Seed rooms with default rooms
-- Note: Replace 'YOUR_ADMIN_USER_ID' with actual Supabase admin user ID
INSERT INTO rooms (name, creator_id, is_private) VALUES
  ('General Lounge', (SELECT id FROM auth.users LIMIT 1), false),
  ('Voice Jam', (SELECT id FROM auth.users LIMIT 1), false),
  ('Dev Den', (SELECT id FROM auth.users LIMIT 1), false)
ON CONFLICT DO NOTHING;

