-- ===============================================
-- Migration: Personas (Contextual Identities)
-- Purpose: Decouple user identity from room membership for privacy
-- Date: 2025-11-18
-- ===============================================

BEGIN;

-- ===============================================
-- 1. PERSONAS TABLE
-- ===============================================

-- Personas: Per-room or per-community identities for a single user
CREATE TABLE IF NOT EXISTS personas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  
  -- Identity Information
  display_name TEXT NOT NULL,
  avatar_url TEXT,
  bio TEXT,
  
  -- Cryptographic Identity (Signal Protocol)
  -- Each persona has its own identity key pair, unlinkable to the master user ID
  identity_public_key BYTEA NOT NULL, 
  identity_private_key BYTEA NOT NULL, -- Encrypted with user's master key
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  -- Ensure one persona per user per room (for now)
  -- Can be relaxed later for "alt" accounts in same room
  UNIQUE(user_id, room_id)
);

-- Indexes for efficient lookup
CREATE INDEX IF NOT EXISTS idx_personas_user ON personas(user_id);
CREATE INDEX IF NOT EXISTS idx_personas_room ON personas(room_id);
CREATE INDEX IF NOT EXISTS idx_personas_composite ON personas(room_id, user_id);

-- ===============================================
-- 2. UPDATE ROOM MEMBERSHIPS
-- ===============================================

-- Add persona_id to room_memberships
ALTER TABLE room_memberships 
ADD COLUMN IF NOT EXISTS persona_id UUID REFERENCES personas(id) ON DELETE SET NULL;

-- Create index for persona lookups in memberships
CREATE INDEX IF NOT EXISTS idx_memberships_persona ON room_memberships(persona_id);

-- NOTE: We are NOT dropping user_id from room_memberships yet to maintain backward compatibility.
-- The application layer should start preferring persona_id.

-- ===============================================
-- 3. MIGRATION FUNCTION
-- ===============================================

-- Function to auto-generate personas for existing memberships (optional run)
CREATE OR REPLACE FUNCTION generate_default_personas() 
RETURNS void AS $$
DECLARE
  membership RECORD;
  user_record RECORD;
BEGIN
  FOR membership IN SELECT * FROM room_memberships WHERE persona_id IS NULL LOOP
    -- Get user info
    SELECT * INTO user_record FROM users WHERE id = membership.user_id;
    
    -- Create default persona matching user profile
    INSERT INTO personas (user_id, room_id, display_name, identity_public_key, identity_private_key)
    VALUES (
      membership.user_id, 
      membership.room_id, 
      COALESCE(user_record.display_name, user_record.handle, 'Anonymous'),
      '\x00', -- Placeholder: Application must generate real keys on next login
      '\x00'  -- Placeholder: Application must generate real keys on next login
    )
    ON CONFLICT (user_id, room_id) DO NOTHING;
    
    -- Link persona
    UPDATE room_memberships 
    SET persona_id = (SELECT id FROM personas WHERE user_id = membership.user_id AND room_id = membership.room_id)
    WHERE id = membership.id;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMIT;

