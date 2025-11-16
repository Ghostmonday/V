-- ============================================================================
-- Realtime Triggers for Message Events
-- Creates PostgreSQL triggers that publish events to Redis via pg_notify
-- and enable Supabase Realtime subscriptions
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_notify;

-- ============================================================================
-- Function: Notify message created event
-- ============================================================================

CREATE OR REPLACE FUNCTION notify_message_created()
RETURNS TRIGGER AS $$
BEGIN
  -- Publish to PostgreSQL NOTIFY channel (Supabase Realtime listens to this)
  PERFORM pg_notify('message_created', json_build_object(
    'id', NEW.id,
    'room_id', NEW.room_id,
    'sender_id', NEW.sender_id,
    'created_at', NEW.created_at,
    'is_encrypted', COALESCE(NEW.is_encrypted, false)
  )::text);
  
  -- Also publish to Redis channel via pg_notify (if Redis listener is configured)
  -- Format: room:{room_id} for Redis pub/sub
  PERFORM pg_notify('redis:room:' || NEW.room_id::text, json_build_object(
    'type', 'message_created',
    'room_id', NEW.room_id,
    'message_id', NEW.id,
    'sender_id', NEW.sender_id,
    'timestamp', EXTRACT(EPOCH FROM NEW.created_at) * 1000
  )::text);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Function: Notify message updated event
-- ============================================================================

CREATE OR REPLACE FUNCTION notify_message_updated()
RETURNS TRIGGER AS $$
BEGIN
  -- Only notify if content or important fields changed
  IF (OLD.content IS DISTINCT FROM NEW.content) OR 
     (OLD.is_encrypted IS DISTINCT FROM NEW.is_encrypted) THEN
    
    PERFORM pg_notify('message_updated', json_build_object(
      'id', NEW.id,
      'room_id', NEW.room_id,
      'updated_at', NEW.updated_at,
      'is_encrypted', COALESCE(NEW.is_encrypted, false)
    )::text);
    
    PERFORM pg_notify('redis:room:' || NEW.room_id::text, json_build_object(
      'type', 'message_updated',
      'room_id', NEW.room_id,
      'message_id', NEW.id,
      'timestamp', EXTRACT(EPOCH FROM COALESCE(NEW.updated_at, NEW.created_at)) * 1000
    )::text);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Function: Notify message deleted event
-- ============================================================================

CREATE OR REPLACE FUNCTION notify_message_deleted()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM pg_notify('message_deleted', json_build_object(
    'id', OLD.id,
    'room_id', OLD.room_id,
    'deleted_at', NOW()
  )::text);
  
  PERFORM pg_notify('redis:room:' || OLD.room_id::text, json_build_object(
    'type', 'message_deleted',
    'room_id', OLD.room_id,
    'message_id', OLD.id,
    'timestamp', EXTRACT(EPOCH FROM NOW()) * 1000
  )::text);
  
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Create Triggers
-- ============================================================================

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS trigger_message_created ON messages;
DROP TRIGGER IF EXISTS trigger_message_updated ON messages;
DROP TRIGGER IF EXISTS trigger_message_deleted ON messages;

-- Create triggers
CREATE TRIGGER trigger_message_created
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_message_created();

CREATE TRIGGER trigger_message_updated
  AFTER UPDATE ON messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_message_updated();

CREATE TRIGGER trigger_message_deleted
  AFTER DELETE ON messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_message_deleted();

-- ============================================================================
-- Enable Realtime for messages table (Supabase-specific)
-- ============================================================================

-- Note: In Supabase, you typically enable Realtime via the dashboard,
-- but we can also do it programmatically if needed:
-- ALTER PUBLICATION supabase_realtime ADD TABLE messages;

-- ============================================================================
-- Indexes for better trigger performance
-- ============================================================================

-- Ensure room_id is indexed for efficient room-based queries
CREATE INDEX IF NOT EXISTS idx_messages_room_id_created_at 
  ON messages(room_id, created_at DESC);

-- Index for encrypted messages (if filtering needed)
CREATE INDEX IF NOT EXISTS idx_messages_is_encrypted 
  ON messages(is_encrypted) 
  WHERE is_encrypted = true;

-- ============================================================================
-- Comments
-- ============================================================================

COMMENT ON FUNCTION notify_message_created() IS 
  'Publishes message_created events to PostgreSQL NOTIFY and Redis channels';

COMMENT ON FUNCTION notify_message_updated() IS 
  'Publishes message_updated events when message content changes';

COMMENT ON FUNCTION notify_message_deleted() IS 
  'Publishes message_deleted events when messages are removed';

