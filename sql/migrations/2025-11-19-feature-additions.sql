-- Enable pg_trgm for fuzzy search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Feature 11: Quiet Hours
ALTER TABLE users ADD COLUMN IF NOT EXISTS quiet_hours_enabled BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS quiet_hours_start TIME;
ALTER TABLE users ADD COLUMN IF NOT EXISTS quiet_hours_end TIME;

-- Feature 8: Pinned Messages
ALTER TABLE messages ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT FALSE;

-- Feature 9: Threaded Replies
ALTER TABLE messages ADD COLUMN IF NOT EXISTS thread_id UUID REFERENCES messages(id);

-- Feature 20: Invite Links
CREATE TABLE IF NOT EXISTS invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    max_uses INTEGER,
    uses INTEGER DEFAULT 0,
    room_id UUID REFERENCES rooms(id)
);

-- Feature 22: Gamification (User Progress)
CREATE TABLE IF NOT EXISTS user_progress (
    user_id UUID PRIMARY KEY REFERENCES users(id),
    xp INTEGER DEFAULT 0,
    level INTEGER DEFAULT 1,
    badges TEXT[],
    current_streak INTEGER DEFAULT 0,
    last_activity_date DATE,
    credits INTEGER DEFAULT 0 -- Feature 21: Referral Bonuses
);

-- Feature 28: Call Scheduling
CREATE TABLE IF NOT EXISTS scheduled_calls (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID REFERENCES rooms(id),
    scheduler_id UUID REFERENCES users(id),
    scheduled_time TIMESTAMPTZ NOT NULL,
    title TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Feature 29: Subscription Tiers
CREATE TABLE IF NOT EXISTS user_subscriptions (
    user_id UUID PRIMARY KEY REFERENCES users(id),
    tier TEXT NOT NULL DEFAULT 'free',
    status TEXT NOT NULL DEFAULT 'active',
    current_period_end TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Feature 5: Searchable Chats Index
CREATE INDEX IF NOT EXISTS idx_messages_content_trgm ON messages USING gin (content_preview gin_trgm_ops);
-- Note: content_preview is used for search as per schema comment, or we might need to index a full content column if it exists.
-- The schema says `content_preview TEXT`, but `payload_ref` points to the full content.
-- If we want to search full content, we might need to fetch it or index `content_preview` if it's sufficient.
-- Assuming `content_preview` is what we search on for now.

-- Feature 12: Profile Mood Indicators
ALTER TABLE users ADD COLUMN IF NOT EXISTS mood_indicator TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS mood_updated_at TIMESTAMPTZ;

-- Feature 23: Leaderboards (Materialized View or just Index)
-- We can use existing indexes for counting messages.
