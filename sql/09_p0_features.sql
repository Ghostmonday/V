-- ===============================================
-- FILE: 09_p0_features.sql
-- PURPOSE: P0 features migration - reactions, threads, edit history, search, bot API
-- DEPENDENCIES: 01_vibez_schema.sql
-- ===============================================

BEGIN;

-- ===============================================
-- MESSAGE REACTIONS (SIN-201)
-- ===============================================

-- Add reactions column to messages table
ALTER TABLE messages ADD COLUMN IF NOT EXISTS reactions JSONB DEFAULT '[]'::jsonb;

-- Create GIN index for efficient reaction queries
CREATE INDEX IF NOT EXISTS idx_messages_reactions ON messages USING GIN (reactions);

-- ===============================================
-- MESSAGE THREADS (SIN-301)
-- ===============================================

-- Create threads table
CREATE TABLE IF NOT EXISTS threads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  title VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  message_count INTEGER DEFAULT 0,
  is_archived BOOLEAN DEFAULT FALSE,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL
);

-- Add thread_id column to messages
ALTER TABLE messages ADD COLUMN IF NOT EXISTS thread_id UUID REFERENCES threads(id) ON DELETE SET NULL;

-- Add reply_to column for direct replies
ALTER TABLE messages ADD COLUMN IF NOT EXISTS reply_to UUID REFERENCES messages(id) ON DELETE SET NULL;

-- Add is_edited flag
ALTER TABLE messages ADD COLUMN IF NOT EXISTS is_edited BOOLEAN DEFAULT FALSE;

-- Create indexes for threads
CREATE INDEX IF NOT EXISTS idx_messages_thread_id ON messages (thread_id) WHERE thread_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_messages_reply_to ON messages (reply_to) WHERE reply_to IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_threads_parent_message ON threads (parent_message_id);
CREATE INDEX IF NOT EXISTS idx_threads_room_id ON threads (room_id) WHERE is_archived = FALSE;
CREATE INDEX IF NOT EXISTS idx_threads_updated_at ON threads (updated_at DESC) WHERE is_archived = FALSE;

-- ===============================================
-- EDIT HISTORY (SIN-401)
-- ===============================================

CREATE TABLE IF NOT EXISTS edit_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  old_content TEXT NOT NULL,
  edited_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  edited_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_edit_history_message_id ON edit_history (message_id);
CREATE INDEX IF NOT EXISTS idx_edit_history_edited_at ON edit_history (edited_at DESC);

-- ===============================================
-- SEARCH INDEX (SIN-402)
-- ===============================================

-- Create materialized view for full-text search
CREATE MATERIALIZED VIEW IF NOT EXISTS message_search_index AS
SELECT
  m.id,
  m.content_preview AS content,
  m.room_id,
  m.sender_id AS user_id,
  m.created_at,
  to_tsvector('english', COALESCE(m.content_preview, '')) AS search_vector
FROM messages m
WHERE m.thread_id IS NULL; -- Only index root messages for now

-- Create indexes on materialized view
CREATE INDEX IF NOT EXISTS idx_message_search_vector ON message_search_index USING GIN (search_vector);
CREATE INDEX IF NOT EXISTS idx_message_search_room ON message_search_index (room_id);
CREATE INDEX IF NOT EXISTS idx_message_search_created_at ON message_search_index (created_at DESC);

-- ===============================================
-- BOT ENDPOINTS (SIN-403)
-- ===============================================

CREATE TABLE IF NOT EXISTS bot_endpoints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bot_id UUID NOT NULL, -- Will reference bots table in future
  endpoint_url VARCHAR(500) NOT NULL,
  webhook_secret VARCHAR(255),
  event_types TEXT[] DEFAULT '{}',
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bot_endpoints_bot_id ON bot_endpoints (bot_id);
CREATE INDEX IF NOT EXISTS idx_bot_endpoints_is_active ON bot_endpoints (is_active) WHERE is_active = TRUE;

-- ===============================================
-- FUNCTIONS AND TRIGGERS
-- ===============================================

-- Function to update thread metadata (message_count and updated_at)
CREATE OR REPLACE FUNCTION update_thread_metadata()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.thread_id IS NOT NULL THEN
    UPDATE threads
    SET
      message_count = message_count + 1,
      updated_at = NOW()
    WHERE id = NEW.thread_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' AND OLD.thread_id IS NOT NULL THEN
    UPDATE threads
    SET
      message_count = GREATEST(message_count - 1, 0),
      updated_at = NOW()
    WHERE id = OLD.thread_id;
    RETURN OLD;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Trigger for thread message count
DROP TRIGGER IF EXISTS trigger_thread_metadata_update ON messages;
CREATE TRIGGER trigger_thread_metadata_update
  AFTER INSERT OR DELETE ON messages
  FOR EACH ROW
  EXECUTE FUNCTION update_thread_metadata();

-- Function to refresh search index (deferred to avoid performance impact)
CREATE OR REPLACE FUNCTION refresh_message_search_index()
RETURNS TRIGGER AS $$
BEGIN
  -- Use CONCURRENT refresh in production (requires unique index)
  -- For now, use regular refresh
  REFRESH MATERIALIZED VIEW message_search_index;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger for search index refresh (deferred)
DROP TRIGGER IF EXISTS trigger_refresh_search_index ON messages;
CREATE CONSTRAINT TRIGGER trigger_refresh_search_index
  AFTER INSERT OR UPDATE OR DELETE ON messages
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW
  EXECUTE FUNCTION refresh_message_search_index();

-- Function to mark message as edited
CREATE OR REPLACE FUNCTION mark_message_edited()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.content_preview IS DISTINCT FROM OLD.content_preview THEN
    NEW.is_edited = TRUE;
    -- Insert into edit history
    INSERT INTO edit_history (message_id, old_content, edited_by)
    VALUES (OLD.id, OLD.content_preview, NEW.sender_id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for edit history
DROP TRIGGER IF EXISTS trigger_mark_message_edited ON messages;
CREATE TRIGGER trigger_mark_message_edited
  BEFORE UPDATE ON messages
  FOR EACH ROW
  WHEN (NEW.content_preview IS DISTINCT FROM OLD.content_preview)
  EXECUTE FUNCTION mark_message_edited();

COMMIT;

