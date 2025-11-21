-- ===============================================
-- ADD MISSING RLS POLICIES FOR FEATURES
-- ===============================================
-- This script adds granular RLS policies to feature tables that were 
-- enabled for RLS but had no policies defined (deny-all state).
--
-- DEPENDENCIES:
-- Assumes public.current_uid() function exists (from RESET_AND_INIT.sql).
-- ===============================================

-- 1. THREADS
-- Users can view threads in rooms they are members of
CREATE POLICY auth_select_threads ON public.threads FOR SELECT TO authenticated USING (
    EXISTS (
        SELECT 1 FROM public.room_memberships rm
        WHERE rm.room_id = threads.room_id AND rm.user_id = public.current_uid()
    )
);

-- Users can create threads in rooms they are members of
CREATE POLICY auth_insert_threads ON public.threads FOR INSERT TO authenticated WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.room_memberships rm
        WHERE rm.room_id = threads.room_id AND rm.user_id = public.current_uid()
    )
);

-- 2. EDIT HISTORY
-- Users can view edit history in rooms they are members of
CREATE POLICY auth_select_edit_history ON public.edit_history FOR SELECT TO authenticated USING (
    EXISTS (
        SELECT 1 FROM public.messages m
        JOIN public.room_memberships rm ON rm.room_id = m.room_id
        WHERE m.id = edit_history.message_id AND rm.user_id = public.current_uid()
    )
);

-- 3. BOTS
-- Users can CRUD their own bots
CREATE POLICY auth_all_own_bots ON public.bots FOR ALL TO authenticated USING (
    created_by = public.current_uid()
) WITH CHECK (
    created_by = public.current_uid()
);

-- Active bots are visible to everyone (for discovery)
CREATE POLICY auth_select_active_bots ON public.bots FOR SELECT TO authenticated USING (
    is_active = true
);

-- 4. BOT ENDPOINTS
-- Bot owners can manage endpoints
CREATE POLICY auth_all_own_bot_endpoints ON public.bot_endpoints FOR ALL TO authenticated USING (
    EXISTS (
        SELECT 1 FROM public.bots b
        WHERE b.id = bot_endpoints.bot_id AND b.created_by = public.current_uid()
    )
) WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.bots b
        WHERE b.id = bot_endpoints.bot_id AND b.created_by = public.current_uid()
    )
);

-- 5. ASSISTANTS
-- Users can CRUD their own assistants
CREATE POLICY auth_all_own_assistants ON public.assistants FOR ALL TO authenticated USING (
    owner_id = public.current_uid()
) WITH CHECK (
    owner_id = public.current_uid()
);

-- 6. SUBSCRIPTIONS
-- Users can CRUD their own subscriptions
CREATE POLICY auth_all_own_subscriptions ON public.subscriptions FOR ALL TO authenticated USING (
    user_id = public.current_uid()
) WITH CHECK (
    user_id = public.current_uid()
);

-- 7. CONVERSATIONS (VIBES)
-- Participants can view conversations
CREATE POLICY auth_select_conversations ON public.conversations FOR SELECT TO authenticated USING (
    EXISTS (
        SELECT 1 FROM public.conversation_participants cp
        WHERE cp.conversation_id = conversations.id AND cp.user_id = public.current_uid()
    )
);

-- Users can create conversations
CREATE POLICY auth_insert_conversations ON public.conversations FOR INSERT TO authenticated WITH CHECK (
    created_by = public.current_uid()
);

-- 8. CONVERSATION PARTICIPANTS
-- Users can view participants of conversations they are in
CREATE POLICY auth_select_participants ON public.conversation_participants FOR SELECT TO authenticated USING (
    EXISTS (
        SELECT 1 FROM public.conversation_participants cp
        WHERE cp.conversation_id = conversation_participants.conversation_id AND cp.user_id = public.current_uid()
    )
);

-- 9. CARDS
-- Everyone can view cards (Public Gallery)
CREATE POLICY auth_select_cards ON public.cards FOR SELECT TO authenticated USING (true);

-- 10. CARD OWNERSHIPS
-- Users can view their own card ownerships
CREATE POLICY auth_select_own_cards ON public.card_ownerships FOR SELECT TO authenticated USING (
    owner_id = public.current_uid()
);

-- 11. PRESENCE LOGS
-- Users can view presence in rooms they are in
CREATE POLICY auth_select_presence ON public.presence_logs FOR SELECT TO authenticated USING (
    EXISTS (
        SELECT 1 FROM public.room_memberships rm
        WHERE rm.room_id = presence_logs.room_id AND rm.user_id = public.current_uid()
    )
);

-- Users can update their own presence
CREATE POLICY auth_insert_own_presence ON public.presence_logs FOR INSERT TO authenticated WITH CHECK (
    user_id = public.current_uid()
);

-- 12. EMBEDDINGS
-- Users can view embeddings for messages they can see
CREATE POLICY auth_select_embeddings ON public.embeddings FOR SELECT TO authenticated USING (
    EXISTS (
        SELECT 1 FROM public.messages m
        JOIN public.room_memberships rm ON rm.room_id = m.room_id
        WHERE m.id = embeddings.message_id AND rm.user_id = public.current_uid()
    )
);

-- ===============================================
-- POLICIES APPLIED
-- ===============================================
