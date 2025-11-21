-- ===============================================
-- ENABLE MISSING RLS ON FEATURE TABLES
-- ===============================================
-- These tables were defined in FRESH_START.sql but missed the RLS enablement step.
-- Running this ensures they are protected by Row Level Security.

SET search_path = service, public;

ALTER TABLE edit_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE bot_endpoints ENABLE ROW LEVEL SECURITY;
ALTER TABLE metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE sentiment_analysis ENABLE ROW LEVEL SECURITY;
ALTER TABLE cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE card_ownerships ENABLE ROW LEVEL SECURITY;
ALTER TABLE card_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE museum_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE boosts ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_violations ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_mutes ENABLE ROW LEVEL SECURITY;

-- Confirmation
DO $$
BEGIN
  RAISE NOTICE 'RLS enabled for all feature tables.';
END $$;
