-- ===============================================
-- FILE: 2025-01-add-moderation-tables.sql
-- PURPOSE: Add message violations and user mutes tables
-- DEPENDENCIES: 2025-01-add-rooms-tier-moderation.sql
-- ===============================================

-- Message violations tracking (for warning/mute logic)
CREATE TABLE IF NOT EXISTS message_violations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
  count INTEGER DEFAULT 1,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, room_id)
);

-- User mutes (temporary mutes, not bans)
CREATE TABLE IF NOT EXISTS user_mutes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
  muted_until TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, room_id)
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_message_violations_user_room ON message_violations(user_id, room_id);
CREATE INDEX IF NOT EXISTS idx_user_mutes_user_room ON user_mutes(user_id, room_id);
CREATE INDEX IF NOT EXISTS idx_user_mutes_muted_until ON user_mutes(muted_until) WHERE muted_until > NOW();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at
CREATE TRIGGER update_message_violations_updated_at
  BEFORE UPDATE ON message_violations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

