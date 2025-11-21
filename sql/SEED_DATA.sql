-- ===============================================
-- SEED DATA FOR VibeZ
-- ===============================================
-- This script populates the database with initial test data.
-- It is safe to run multiple times (uses ON CONFLICT DO NOTHING).
-- ===============================================

-- 1. USERS
-- ===============================================
INSERT INTO public.users (id, handle, display_name, role, is_verified)
VALUES 
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'admin_user', 'System Admin', 'admin', true),
    ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b22', 'alice', 'Alice Wonderland', 'user', true),
    ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c33', 'bob', 'Bob Builder', 'user', false)
ON CONFLICT (handle) DO NOTHING;

-- 2. ROOMS
-- ===============================================
INSERT INTO public.rooms (id, slug, title, created_by, is_public)
VALUES 
    ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380d44', 'general', 'General Chat', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', true),
    ('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380e55', 'random', 'Random Thoughts', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', true)
ON CONFLICT (slug) DO NOTHING;

-- 3. ROOM MEMBERSHIPS
-- ===============================================
-- Admin in General
INSERT INTO public.room_memberships (room_id, user_id, role)
VALUES ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380d44', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'admin')
ON CONFLICT (room_id, user_id) DO NOTHING;

-- Alice in General
INSERT INTO public.room_memberships (room_id, user_id, role)
VALUES ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380d44', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b22', 'member')
ON CONFLICT (room_id, user_id) DO NOTHING;

-- Bob in General
INSERT INTO public.room_memberships (room_id, user_id, role)
VALUES ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380d44', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c33', 'member')
ON CONFLICT (room_id, user_id) DO NOTHING;

-- Alice in Random
INSERT INTO public.room_memberships (room_id, user_id, role)
VALUES ('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380e55', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b22', 'member')
ON CONFLICT (room_id, user_id) DO NOTHING;

-- 4. MESSAGES
-- ===============================================
INSERT INTO public.messages (id, room_id, sender_id, payload_ref, content_preview, content_hash, audit_hash_chain, partition_month)
VALUES 
    (gen_random_uuid(), 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380d44', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'ref_001', 'Welcome to VibeZ General Chat!', 'hash_001', 'chain_001', to_char(now(), 'YYYY_MM')),
    (gen_random_uuid(), 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380d44', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b22', 'ref_002', 'Hello everyone! Excited to be here.', 'hash_002', 'chain_002', to_char(now(), 'YYYY_MM')),
    (gen_random_uuid(), 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380d44', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c33', 'ref_003', 'Hey Alice! Cool app.', 'hash_003', 'chain_003', to_char(now(), 'YYYY_MM'));

-- 5. BOTS
-- ===============================================
INSERT INTO public.bots (id, name, url, token, created_by)
VALUES 
    (gen_random_uuid(), 'WelcomeBot', 'https://bot.vibez.app/welcome', 'bot_token_123', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11')
ON CONFLICT (token) DO NOTHING;

-- ===============================================
-- SEED COMPLETE
-- ===============================================
