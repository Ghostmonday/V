-- Feature Enhancements Migration
-- Adds: Full-text search, read receipts, nicknames, file uploads, formatting, polls, pinned items, bandwidth mode

-- 1. Full-text search index on messages
CREATE INDEX IF NOT EXISTS messages_content_fts_idx 
ON messages USING GIN(to_tsvector('english', COALESCE(content_preview, '')));

-- Also index on rooms title/slug for room search
CREATE INDEX IF NOT EXISTS rooms_title_fts_idx 
ON rooms USING GIN(to_tsvector('english', COALESCE(title, '') || ' ' || COALESCE(slug, '')));

-- Index on users for user search (if username/display_name exists)
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'username') THEN
    CREATE INDEX IF NOT EXISTS users_username_fts_idx 
    ON users USING GIN(to_tsvector('english', COALESCE(username, '')));
  END IF;
END $$;

-- 2. Read receipts - message_receipts table already exists, but ensure seen_at is available
-- Add seen_at if it doesn't exist (some schemas use read_at)
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'message_receipts' AND column_name = 'seen_at') THEN
    ALTER TABLE message_receipts ADD COLUMN seen_at TIMESTAMPTZ;
  END IF;
END $$;

-- 3. Custom nicknames in room_memberships
ALTER TABLE room_memberships 
ADD COLUMN IF NOT EXISTS nickname TEXT;

-- Index for nickname lookups
CREATE INDEX IF NOT EXISTS room_memberships_nickname_idx 
ON room_memberships(nickname) WHERE nickname IS NOT NULL;

-- 4. Enhanced files table for larger uploads
DO $$ 
BEGIN
  -- Add columns if files table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'files') THEN
    ALTER TABLE files ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE SET NULL;
    ALTER TABLE files ADD COLUMN IF NOT EXISTS room_id UUID REFERENCES rooms(id) ON DELETE SET NULL;
    ALTER TABLE files ADD COLUMN IF NOT EXISTS file_name TEXT;
    ALTER TABLE files ADD COLUMN IF NOT EXISTS file_size BIGINT;
    ALTER TABLE files ADD COLUMN IF NOT EXISTS mime_type TEXT;
    ALTER TABLE files ADD COLUMN IF NOT EXISTS uploaded_at TIMESTAMPTZ DEFAULT now();
    ALTER TABLE files ADD COLUMN IF NOT EXISTS s3_key TEXT;
    ALTER TABLE files ADD COLUMN IF NOT EXISTS chunked_upload_id TEXT;
    ALTER TABLE files ADD COLUMN IF NOT EXISTS upload_status TEXT DEFAULT 'pending';
  ELSE
    -- Create files table if it doesn't exist
    CREATE TABLE files (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      url TEXT NOT NULL,
      user_id UUID REFERENCES users(id) ON DELETE SET NULL,
      room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
      file_name TEXT,
      file_size BIGINT,
      mime_type TEXT,
      uploaded_at TIMESTAMPTZ DEFAULT now(),
      s3_key TEXT,
      chunked_upload_id TEXT,
      upload_status TEXT DEFAULT 'pending'
    );
  END IF;
END $$;

-- 5. Formatted content in messages
ALTER TABLE messages 
ADD COLUMN IF NOT EXISTS formatted_content TEXT;

-- Index for formatted content search
CREATE INDEX IF NOT EXISTS messages_formatted_fts_idx 
ON messages USING GIN(to_tsvector('english', COALESCE(formatted_content, '')));

-- 6. User preferences for bandwidth mode
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users') THEN
    -- Add bandwidth_mode preference
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'users' AND column_name = 'preferences') THEN
      ALTER TABLE users ADD COLUMN preferences JSONB DEFAULT '{}'::jsonb;
    END IF;
  END IF;
END $$;

-- 7. Pinned items table
CREATE TABLE IF NOT EXISTS pinned_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  pinned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, room_id)
);

CREATE INDEX IF NOT EXISTS pinned_items_user_idx ON pinned_items(user_id);
CREATE INDEX IF NOT EXISTS pinned_items_room_idx ON pinned_items(room_id);

-- 8. Polls table
CREATE TABLE IF NOT EXISTS polls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  question TEXT NOT NULL,
  options JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array of option objects: {id, text, votes}
  is_anonymous BOOLEAN NOT NULL DEFAULT false,
  is_multiple_choice BOOLEAN NOT NULL DEFAULT false,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  status TEXT NOT NULL DEFAULT 'active' -- active, closed, expired
);

CREATE INDEX IF NOT EXISTS polls_room_idx ON polls(room_id);
CREATE INDEX IF NOT EXISTS polls_status_idx ON polls(status);

-- Poll votes table
CREATE TABLE IF NOT EXISTS poll_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id UUID NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL, -- NULL if anonymous
  option_id TEXT NOT NULL, -- References option.id in polls.options JSONB
  voted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(poll_id, user_id, option_id) -- One vote per user per option (unless multiple choice)
);

CREATE INDEX IF NOT EXISTS poll_votes_poll_idx ON poll_votes(poll_id);
CREATE INDEX IF NOT EXISTS poll_votes_user_idx ON poll_votes(user_id);

-- 9. Bot invites table
CREATE TABLE IF NOT EXISTS bot_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  token TEXT NOT NULL UNIQUE, -- JWT-like invite token
  bot_name TEXT NOT NULL,
  bot_config JSONB DEFAULT '{}'::jsonb, -- Bot behavior/config
  template_id TEXT, -- Reference to bot template
  expires_at TIMESTAMPTZ,
  used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  status TEXT NOT NULL DEFAULT 'pending' -- pending, used, expired
);

CREATE INDEX IF NOT EXISTS bot_invites_token_idx ON bot_invites(token);
CREATE INDEX IF NOT EXISTS bot_invites_room_idx ON bot_invites(room_id);

-- 10. Device tokens for push notifications
CREATE TABLE IF NOT EXISTS device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_token TEXT NOT NULL,
  platform TEXT NOT NULL, -- 'ios', 'android'
  device_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_used_at TIMESTAMPTZ,
  UNIQUE(user_id, device_token)
);

CREATE INDEX IF NOT EXISTS device_tokens_user_idx ON device_tokens(user_id);
CREATE INDEX IF NOT EXISTS device_tokens_platform_idx ON device_tokens(platform);

-- RLS Policies for new tables
ALTER TABLE pinned_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE poll_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE bot_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

-- Pinned items: Users can see their own pins
CREATE POLICY "Users can view their own pinned items"
ON pinned_items FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own pinned items"
ON pinned_items FOR ALL
USING (auth.uid() = user_id);

-- Polls: Room members can view polls in their rooms
CREATE POLICY "Room members can view polls"
ON polls FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM room_memberships 
    WHERE room_id = polls.room_id 
    AND user_id = auth.uid()
  )
);

-- Poll votes: Users can vote (anonymous if poll allows)
CREATE POLICY "Users can vote in polls"
ON poll_votes FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM polls p
    JOIN room_memberships rm ON rm.room_id = p.room_id
    WHERE p.id = poll_votes.poll_id
    AND (rm.user_id = auth.uid() OR p.is_anonymous)
  )
);

-- Bot invites: Room admins can create invites
CREATE POLICY "Room admins can create bot invites"
ON bot_invites FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM room_memberships
    WHERE room_id = bot_invites.room_id
    AND user_id = auth.uid()
    AND role IN ('owner', 'admin')
  )
);

-- Device tokens: Users manage their own tokens
CREATE POLICY "Users manage their own device tokens"
ON device_tokens FOR ALL
USING (auth.uid() = user_id);

-- Full-text search function
CREATE OR REPLACE FUNCTION search_messages_fulltext(
  search_query TEXT,
  filter_room_id UUID DEFAULT NULL,
  filter_user_id UUID DEFAULT NULL,
  result_limit INT DEFAULT 50
)
RETURNS TABLE (
  id UUID,
  room_id UUID,
  sender_id UUID,
  content_preview TEXT,
  created_at TIMESTAMPTZ,
  rank REAL
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    m.id,
    m.room_id,
    m.sender_id,
    m.content_preview,
    m.created_at,
    ts_rank(to_tsvector('english', COALESCE(m.content_preview, '')), plainto_tsquery('english', search_query)) AS rank
  FROM messages m
  WHERE 
    to_tsvector('english', COALESCE(m.content_preview, '')) @@ plainto_tsquery('english', search_query)
    AND (filter_room_id IS NULL OR m.room_id = filter_room_id)
    AND (filter_user_id IS NULL OR m.sender_id = filter_user_id)
  ORDER BY rank DESC, m.created_at DESC
  LIMIT result_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Search rooms function
CREATE OR REPLACE FUNCTION search_rooms_fulltext(
  search_query TEXT,
  result_limit INT DEFAULT 20
)
RETURNS TABLE (
  id UUID,
  slug TEXT,
  title TEXT,
  created_at TIMESTAMPTZ,
  rank REAL
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    r.id,
    r.slug,
    r.title,
    r.created_at,
    ts_rank(to_tsvector('english', COALESCE(r.title, '') || ' ' || COALESCE(r.slug, '')), plainto_tsquery('english', search_query)) AS rank
  FROM rooms r
  WHERE 
    to_tsvector('english', COALESCE(r.title, '') || ' ' || COALESCE(r.slug, '')) @@ plainto_tsquery('english', search_query)
    AND r.is_public = true
  ORDER BY rank DESC, r.created_at DESC
  LIMIT result_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

