-- ===============================================
-- MISSING INDEXES REPORT - PART 1: REQUIRED INDEXES
-- Generated from codebase analysis
-- Date: 2025-01-XX
-- ===============================================
-- 
-- This report identifies missing indexes based on actual queries
-- found in the codebase (routes, services, WebSocket flows).
-- 
-- PRIORITY LEGEND:
-- HIGH PRIORITY = Required for correctness or critical performance
-- NORMAL = Improves performance for common queries
-- LOW PRIORITY = Nice-to-have optimization          4v
--
-- ===============================================
-- QUICK REFERENCE: CRITICAL MISSING INDEXES
-- ===============================================
--
-- HIGH PRIORITY (Apply these first):                                                                      vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
-- 1. idx_rooms_is_public_active_users - Room listing performance
-- 2. idx_message_receipts_message_id - FK index for JOINs
-- 3. idx_message_receipts_user_id - FK index for batch queries
-- 4. idx_pinned_items_user_id - FK index for user lookups
-- 5. idx_pinned_items_user_room - Composite lookup optimization
--
-- NORMAL PRIORITY (Apply after HIGH priority):
-- See detailed list below
--
-- ===============================================

BEGIN;

-- ===============================================
-- HIGH PRIORITY INDEXES
-- ===============================================

-- 1. MESSAGES TABLE
-- ===============================================

-- Query: getRoomMessages() - filters by room_id, orders by created_at DESC
-- Found in: src/services/message-service.ts:176-180
-- Status: EXISTS (idx_messages_room_time) - VERIFIED

-- Query: getThread() - filters by thread_id, orders by created_at ASC
-- Found in: src/services/messages-controller.ts:291
-- Status: EXISTS (idx_messages_thread_id_composite) - VERIFIED

-- Query: VIBES - filters by conversation_id
-- Found in: src/services/message-service.ts:92, src/jobs/vibes-card-generation-job.ts:40,57
-- Status: EXISTS (idx_messages_conversation_id from migration 2025-11-15-vibes-core-schema.sql:47) - VERIFIED

-- Query: getRoomMessages() - uses 'ts' column for filtering/ordering
-- Found in: src/services/message-service.ts:178
-- Priority: HIGH PRIORITY (if ts != created_at)
-- Note: Verify if 'ts' column exists or if it's an alias for created_at
-- If ts column exists separately:
-- CREATE INDEX IF NOT EXISTS idx_messages_ts 
-- ON messages(ts DESC);

-- Query: getRoomThreads() - filters by is_archived = false
-- Found in: src/services/messages-controller.ts:350
-- Note: is_archived is on threads table, not messages table
-- Status: Covered by idx_threads_room_id partial index (WHERE is_archived = FALSE) - VERIFIED

-- Query: searchMessages() - filters by room_id on message_search_index view
-- Found in: src/services/messages-controller.ts:586
-- Status: Depends on underlying view/indexes - VERIFY VIEW DEFINITION

-- Query: getActivityFeed() - filters by sender_id, orders by created_at DESC
-- Found in: src/services/presence-service.ts:90
-- Status: EXISTS (idx_messages_sender_created) - VERIFIED

-- ===============================================
-- 2. ROOMS TABLE
-- ===============================================

-- Query: createRoom() - checks if name exists
-- Found in: src/services/room-service.ts:29
-- Status: EXISTS (idx_rooms_name) - VERIFIED

-- Query: joinRoom() - filters by id
-- Found in: src/services/room-service.ts:72
-- Status: PRIMARY KEY - VERIFIED

-- Query: listRooms() - filters by is_public = true, orders by active_users DESC
-- Found in: src/services/presence-service.ts:82
-- Priority: HIGH PRIORITY
-- Reason: Common query pattern, missing composite index for ORDER BY active_users
-- Note: idx_rooms_public_created exists but doesn't cover active_users ordering
CREATE INDEX IF NOT EXISTS idx_rooms_is_public_active_users 
ON rooms(is_public, active_users DESC NULLS LAST) 
WHERE is_public = TRUE;

-- Query: listRooms() - filters by is_private
-- Found in: src/services/room-service.ts:150
-- Priority: NORMAL
-- Reason: Used in room listing queries
CREATE INDEX IF NOT EXISTS idx_rooms_is_private 
ON rooms(is_private) 
WHERE is_private = TRUE;

-- Query: Various - filters by slug
-- Found in: Multiple locations (slug is UNIQUE but may need index for lookups)
-- Priority: NORMAL
-- Reason: Slug lookups are common (if slug column exists)
-- Note: UNIQUE constraint creates index automatically, but verify it exists
-- If slug queries are slow, consider:
-- CREATE INDEX IF NOT EXISTS idx_rooms_slug 
-- ON rooms(slug) 
-- WHERE slug IS NOT NULL;

-- Query: RLS policy - checks is_public
-- Found in: RLS policies
-- Status: Covered by idx_rooms_is_public_active_users above

-- ===============================================
-- 3. MESSAGE_RECEIPTS TABLE
-- ===============================================

-- Query: getReadReceipts() - filters by message_id
-- Found in: src/services/read-receipts-service.ts:123
-- Priority: HIGH PRIORITY
-- Reason: FK column missing index (causes slow JOINs)
CREATE INDEX IF NOT EXISTS idx_message_receipts_message_id 
ON message_receipts(message_id);

-- Query: getRoomReadStatus() - filters by user_id, uses IN(message_id)
-- Found in: src/services/read-receipts-service.ts:160
-- Priority: HIGH PRIORITY
-- Reason: FK column missing index, used in batch queries
CREATE INDEX IF NOT EXISTS idx_message_receipts_user_id 
ON message_receipts(user_id);

-- Query: markDelivered/markRead - upsert on (message_id, user_id)
-- Found in: src/services/read-receipts-service.ts:17,46
-- Status: UNIQUE constraint creates index - VERIFIED

-- Composite index for common query pattern (message_id + user_id lookups)
-- Priority: NORMAL (optimization)
-- Reason: Most queries filter by both columns
CREATE INDEX IF NOT EXISTS idx_message_receipts_message_user 
ON message_receipts(message_id, user_id);

-- ===============================================
-- 4. ROOM_MEMBERSHIPS TABLE
-- ===============================================

-- Query: getNickname() - filters by user_id + room_id
-- Found in: src/services/nickname-service.ts:76
-- Status: EXISTS (idx_room_memberships_room_user) - VERIFIED

-- Query: getRoomNicknames() - filters by room_id, checks nickname IS NOT NULL
-- Found in: src/services/nickname-service.ts:95
-- Priority: NORMAL
-- Reason: Partial index for nickname queries
CREATE INDEX IF NOT EXISTS idx_room_memberships_room_nickname 
ON room_memberships(room_id, nickname) 
WHERE nickname IS NOT NULL;

-- Query: RLS policies - filters by user_id for membership checks
-- Found in: sql/11_indexing_and_rls.sql:132
-- Status: EXISTS (idx_room_memberships_user_role) - VERIFIED

-- ===============================================
-- 5. THREADS TABLE
-- ===============================================

-- Query: getThread() - filters by id
-- Found in: src/services/messages-controller.ts:282
-- Status: PRIMARY KEY - VERIFIED

-- Query: getRoomThreads() - filters by room_id + is_archived, orders by updated_at DESC
-- Found in: src/services/messages-controller.ts:349-351
-- Status: EXISTS (idx_threads_room_id and idx_threads_updated_at from 09_p0_features.sql:49-50) - VERIFIED
-- Note: Composite index may improve performance further, but separate indexes exist

-- Query: getThread() - joins with messages via parent_message_id
-- Found in: src/services/messages-controller.ts:281
-- Status: EXISTS (idx_threads_parent_message from 09_p0_features.sql:48) - VERIFIED

-- Query: getThread() - filters by created_by (if column exists)
-- Found in: src/services/messages-controller.ts:200
-- Priority: NORMAL (if column exists)
-- Note: Verify if created_by column exists in threads table
-- If exists:
-- CREATE INDEX IF NOT EXISTS idx_threads_created_by 
-- ON threads(created_by);

-- ===============================================
-- 6. PINNED_ITEMS TABLE
-- ===============================================

-- Query: getPinnedRooms() - filters by user_id, orders by pinned_at DESC
-- Found in: src/services/pinned-items-service.ts:74
-- Priority: HIGH PRIORITY
-- Reason: Missing index on FK column
CREATE INDEX IF NOT EXISTS idx_pinned_items_user_id 
ON pinned_items(user_id);

-- Query: isRoomPinned() - filters by user_id + room_id
-- Found in: src/services/pinned-items-service.ts:96
-- Priority: HIGH PRIORITY
-- Reason: Common lookup pattern, missing composite index
CREATE INDEX IF NOT EXISTS idx_pinned_items_user_room 
ON pinned_items(user_id, room_id);

-- Query: pinRoom/unpinRoom - filters by room_id
-- Found in: src/services/pinned-items-service.ts:42
-- Priority: NORMAL
-- Reason: FK column should be indexed
CREATE INDEX IF NOT EXISTS idx_pinned_items_room_id 
ON pinned_items(room_id);

-- ===============================================
-- 7. PRESENCE_LOGS TABLE
-- ===============================================

-- Query: updateRoomPresence() - inserts with user_id, room_id, status
-- Found in: src/services/presence-service.ts:26
-- Status: EXISTS (idx_presence_logs_room_user, idx_presence_logs_user_created) - VERIFIED

-- Query: RLS policy - filters by status for presence queries
-- Found in: AI functions (ai_detect_presence_dropouts)
-- Priority: NORMAL
-- Reason: Used in presence analytics queries
CREATE INDEX IF NOT EXISTS idx_presence_logs_status_created 
ON presence_logs(status, created_at DESC);

-- ===============================================
-- 8. TELEMETRY TABLE
-- ===============================================

-- Query: Various - filters by event_type
-- Found in: Multiple locations
-- Status: EXISTS (idx_telemetry_event) - VERIFIED

-- Query: Various - orders by event_time DESC
-- Found in: Multiple locations
-- Status: EXISTS (idx_telemetry_event_time) - VERIFIED

-- Query: RLS policy - filters by user_id
-- Found in: RLS policies
-- Status: EXISTS (idx_telemetry_user_id) - VERIFIED

-- ===============================================
-- 9. UX_TELEMETRY TABLE
-- ===============================================

-- Query: Various - filters by user_id, orders by created_at
-- Found in: src/services/ux-telemetry-service.ts
-- Priority: NORMAL
-- Reason: Missing composite index for user-specific queries
CREATE INDEX IF NOT EXISTS idx_ux_telemetry_user_created 
ON ux_telemetry(user_id, created_at DESC) 
WHERE user_id IS NOT NULL;

-- Query: Various - filters by event_category
-- Found in: src/services/ux-telemetry-service.ts:199
-- Status: EXISTS (idx_ux_telemetry_category) - VERIFIED

-- ===============================================
-- 10. REACTIONS TABLE (if separate table exists)
-- ===============================================

-- Query: Reactions stored in messages.reactions JSONB (not separate table)
-- Found in: src/services/messages-controller.ts:40
-- Status: N/A - reactions stored as JSONB in messages table
-- Note: If reactions table exists separately, add:
-- CREATE INDEX IF NOT EXISTS idx_reactions_message_id 
-- ON reactions(message_id);
-- CREATE INDEX IF NOT EXISTS idx_reactions_user_id 
-- ON reactions(user_id);
-- CREATE INDEX IF NOT EXISTS idx_reactions_message_user_emoji 
-- ON reactions(message_id, user_id, emoji);

-- ===============================================
-- 11. FILES TABLE
-- ===============================================

-- Query: Various - filters by user_id
-- Found in: Multiple locations
-- Priority: NORMAL
-- Reason: FK column should be indexed
CREATE INDEX IF NOT EXISTS idx_files_user_id 
ON files(user_id) 
WHERE user_id IS NOT NULL;

-- Query: Various - filters by room_id
-- Found in: Multiple locations
-- Priority: NORMAL
-- Reason: FK column should be indexed
CREATE INDEX IF NOT EXISTS idx_files_room_id 
ON files(room_id) 
WHERE room_id IS NOT NULL;

-- ===============================================
-- 12. SUBSCRIPTIONS TABLE
-- ===============================================

-- Query: getUserSubscription() - filters by user_id
-- Found in: Multiple locations
-- Status: EXISTS (idx_subscriptions_user_id from 10_integrated_features.sql:76) - VERIFIED

-- Query: Various - filters by status
-- Found in: src/services/notifications-service.ts:103
-- Priority: NORMAL
-- Reason: Used in subscription status queries
CREATE INDEX IF NOT EXISTS idx_subscriptions_status 
ON subscriptions(status) 
WHERE status = 'active';

-- ===============================================
-- 13. ROOM_MEMBERS TABLE (if separate from room_memberships)
-- ===============================================

-- Query: joinRoom() - checks membership
-- Found in: src/services/room-service.ts:84
-- Status: EXISTS (idx_room_members_room, idx_room_members_user) - VERIFIED

-- ===============================================
-- 14. FOREIGN KEY INDEXES (Missing FK indexes)
-- ===============================================

-- These FK columns are referenced but may not have indexes:

-- messages.sender_id - FK to users(id)
-- Status: EXISTS (idx_messages_sender_created) - VERIFIED

-- messages.room_id - FK to rooms(id)
-- Status: EXISTS (idx_messages_room_time) - VERIFIED

-- rooms.created_by - FK to users(id)
-- Priority: NORMAL
-- Reason: FK column should be indexed
CREATE INDEX IF NOT EXISTS idx_rooms_created_by 
ON rooms(created_by) 
WHERE created_by IS NOT NULL;

-- rooms.creator_id - FK to users(id) (if different from created_by)
-- Status: EXISTS (idx_rooms_creator) - VERIFIED

-- threads.room_id - FK to rooms(id)
-- Status: EXISTS (idx_threads_room_id from 09_p0_features.sql:49) - VERIFIED

-- threads.created_by - FK to users(id) (if column exists)
-- Priority: NORMAL (if column exists)
-- Note: Verify if created_by column exists in threads table

-- pinned_items.pinned_by - FK to users(id)
-- Priority: NORMAL
-- Reason: FK column should be indexed
CREATE INDEX IF NOT EXISTS idx_pinned_items_pinned_by 
ON pinned_items(pinned_by) 
WHERE pinned_by IS NOT NULL;

-- ===============================================
-- SUMMARY OF MISSING INDEXES
-- ===============================================

-- HIGH PRIORITY (Required for correctness or critical performance):
-- 1. idx_rooms_is_public_active_users (ORDER BY active_users optimization)
-- 2. idx_message_receipts_message_id (FK index - MISSING)
-- 3. idx_message_receipts_user_id (FK index - MISSING)
-- 4. idx_pinned_items_user_id (FK index - MISSING)
-- 5. idx_pinned_items_user_room (composite lookup - MISSING)

-- NORMAL PRIORITY (Improves performance):
-- 1. idx_rooms_is_private
-- 2. idx_message_receipts_message_user
-- 3. idx_room_memberships_room_nickname
-- 4. idx_pinned_items_room_id
-- 5. idx_presence_logs_status_created
-- 6. idx_ux_telemetry_user_created
-- 7. idx_files_user_id
-- 8. idx_files_room_id
-- 9. idx_subscriptions_status
-- 10. idx_rooms_created_by
-- 11. idx_pinned_items_pinned_by

COMMIT;

-- ===============================================
-- VERIFICATION QUERIES
-- ===============================================

-- Run these queries to verify indexes were created:

-- SELECT 
--   schemaname,
--   tablename,
--   indexname,
--   indexdef
-- FROM pg_indexes
-- WHERE schemaname = 'public'
--   AND tablename IN (
--     'messages', 'rooms', 'message_receipts', 'threads', 
--     'pinned_items', 'subscriptions', 'room_memberships'
--   )
-- ORDER BY tablename, indexname;

-- ===============================================
-- NOTES
-- ===============================================
-- 1. All indexes use IF NOT EXISTS for idempotency
-- 2. Partial indexes (WHERE clauses) reduce index size and improve performance
-- 3. Composite indexes are ordered by selectivity (most selective first)
-- 4. DESC indexes are used for ORDER BY DESC queries
-- 5. NULLS LAST is used for DESC indexes to handle NULL values correctly
-- 6. Verify column existence before creating indexes (some columns may not exist in all schemas)
-- 7. Monitor index usage with: SELECT * FROM pg_stat_user_indexes;
-- 8. Consider dropping unused indexes if they're not improving query performance

