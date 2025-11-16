-- ===============================================
-- Migration: Message Flagging System
-- Purpose: Store flagged messages for admin review
-- Date: 2025-01-XX
-- ===============================================

BEGIN;

-- Flagged messages table
CREATE TABLE IF NOT EXISTS flagged_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason TEXT NOT NULL, -- 'toxicity', 'spam', 'harassment', 'inappropriate', 'other'
  score NUMERIC NOT NULL DEFAULT 0, -- 0-1 toxicity score
  flagged_by UUID REFERENCES users(id) ON DELETE SET NULL, -- NULL if auto-flagged by system
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'reviewed', 'dismissed', 'action_taken'
  reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  action_taken TEXT, -- 'warned', 'muted', 'banned', 'message_deleted'
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_flagged_messages_status ON flagged_messages(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_flagged_messages_message_id ON flagged_messages(message_id);
CREATE INDEX IF NOT EXISTS idx_flagged_messages_user_id ON flagged_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_flagged_messages_room_id ON flagged_messages(room_id);
CREATE INDEX IF NOT EXISTS idx_flagged_messages_flagged_by ON flagged_messages(flagged_by) WHERE flagged_by IS NOT NULL;

COMMIT;

