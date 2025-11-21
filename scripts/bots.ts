#!/usr/bin/env tsx

/**
 * Bot Simulation Script
 * Simulates seeded users (Alice, Bob, Admin) performing random actions
 * to verify RLS policies and system behavior.
 */

import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import jwt from 'jsonwebtoken';
import { config } from 'dotenv';
import { join } from 'path';
import { fileURLToPath } from 'url';

// Load environment variables
const __dirname = fileURLToPath(new URL('.', import.meta.url));
config({ path: join(__dirname, '../.env') });

const SUPABASE_URL = process.env.SUPABASE_URL || 'http://localhost:54321';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;
const SUPABASE_JWT_SECRET = process.env.SUPABASE_JWT_SECRET;

if (!SUPABASE_ANON_KEY || !SUPABASE_JWT_SECRET) {
    console.error('❌ Missing SUPABASE_ANON_KEY or SUPABASE_JWT_SECRET');
    process.exit(1);
}

// Seeded Users (from SEED_DATA.sql)
const SEEDED_USERS = [
    { id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', handle: 'admin_user', role: 'admin' },
    { id: 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b22', handle: 'alice', role: 'user' },
    { id: 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c33', handle: 'bob', role: 'user' }
] as const;

const ROOMS = [
    'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380d44', // General
    'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380e55'  // Random
] as const;

type ActionType = 'send_message' | 'create_thread' | 'react_message' | 'view_room';
type User = typeof SEEDED_USERS[number];

// Database insert types
interface MessageInsert {
    room_id: string;
    payload_ref: string;
    content_preview: string;
    content_hash: string;
    audit_hash_chain: string;
    partition_month: string;
}

interface ThreadInsert {
    parent_message_id: string;
    room_id: string;
    title: string;
}

interface Reaction {
    user_id: string;
    emoji: string;
    created_at: string;
}

/**
 * Generate a valid Supabase JWT for a specific user ID
 */
function generateUserToken(userId: string): string {
    const payload = {
        sub: userId,
        aud: 'authenticated',
        role: 'authenticated',
        exp: Math.floor(Date.now() / 1000) + (60 * 60)
    };
    return jwt.sign(payload, SUPABASE_JWT_SECRET!);
}

/**
 * Create an authenticated Supabase client for a user
 */
function getClientForUser(userId: string): SupabaseClient {
    const token = generateUserToken(userId);
    return createClient(SUPABASE_URL, SUPABASE_ANON_KEY!, {
        global: {
            headers: {
                Authorization: `Bearer ${token}`
            }
        }
    });
}

async function sendMessage(user: User, client: SupabaseClient): Promise<void> {
    const roomId = ROOMS[Math.floor(Math.random() * ROOMS.length)];
    const content = `Simulated message from ${user.handle} at ${new Date().toISOString()}`;

    const messageData: MessageInsert = {
        room_id: roomId,
        payload_ref: `sim_${Date.now()}`,
        content_preview: content,
        content_hash: `hash_${Date.now()}`,
        audit_hash_chain: `chain_${Date.now()}`,
        partition_month: new Date().toISOString().slice(0, 7).replace('-', '_')
    };

    const { error } = await client
        .from('messages')
        .insert(messageData)
        .select()
        .single();

    if (error) {
        console.error(`❌ [${user.handle}] Failed to send message:`, error.message);
    } else {
        console.log(`💬 [${user.handle}] Sent message in room ${roomId.slice(0, 8)}...`);
    }
}

async function createThread(user: User, client: SupabaseClient): Promise<void> {
    const { data: messages } = await client
        .from('messages')
        .select('id, room_id')
        .limit(5)
        .order('created_at', { ascending: false });

    if (!messages?.length) return;

    const parent = messages[Math.floor(Math.random() * messages.length)];
    const threadData: ThreadInsert = {
        parent_message_id: parent.id,
        room_id: parent.room_id,
        title: `Thread about ${parent.id.slice(0, 8)}`
    };

    const { error } = await client
        .from('threads')
        .insert(threadData);

    if (error) {
        console.error(`❌ [${user.handle}] Failed to create thread:`, error.message);
    } else {
        console.log(`🧵 [${user.handle}] Created thread on message ${parent.id.slice(0, 8)}...`);
    }
}

async function reactToMessage(user: User, client: SupabaseClient): Promise<void> {
    const { data: messages } = await client
        .from('messages')
        .select('id, reactions')
        .limit(5)
        .order('created_at', { ascending: false });

    if (!messages?.length) return;

    const msg = messages[Math.floor(Math.random() * messages.length)];
    const reactions = Array.isArray(msg.reactions) ? msg.reactions : [];
    const newReaction: Reaction = {
        user_id: user.id,
        emoji: '👍',
        created_at: new Date().toISOString()
    };

    const { error } = await client
        .from('messages')
        .update({ reactions: [...reactions, newReaction] })
        .eq('id', msg.id);

    if (error) {
        console.error(`❌ [${user.handle}] Failed to react:`, error.message);
    } else {
        console.log(`👍 [${user.handle}] Reacted to message ${msg.id.slice(0, 8)}...`);
    }
}

async function viewRoom(user: User, client: SupabaseClient): Promise<void> {
    const roomId = ROOMS[Math.floor(Math.random() * ROOMS.length)];
    const { data, error } = await client
        .from('rooms')
        .select('*')
        .eq('id', roomId)
        .single();

    if (error) {
        console.error(`❌ [${user.handle}] Failed to view room:`, error.message);
    } else {
        console.log(`👀 [${user.handle}] Viewed room ${data.title}`);
    }
}

async function runSimulation(): Promise<void> {
    console.log('🤖 Starting Bot Simulation with Seeded Users...');
    console.log('Users:', SEEDED_USERS.map(u => u.handle).join(', '));
    console.log('Press Ctrl+C to stop.\n');

    while (true) {
        const user = SEEDED_USERS[Math.floor(Math.random() * SEEDED_USERS.length)];
        const client = getClientForUser(user.id);

        const actions: ActionType[] = ['send_message', 'create_thread', 'react_message', 'view_room'];
        const action = actions[Math.floor(Math.random() * actions.length)];

        try {
            switch (action) {
                case 'send_message':
                    await sendMessage(user, client);
                    break;
                case 'create_thread':
                    await createThread(user, client);
                    break;
                case 'react_message':
                    await reactToMessage(user, client);
                    break;
                case 'view_room':
                    await viewRoom(user, client);
                    break;
            }
        } catch (err) {
            console.error(`⚠️ Unexpected error for ${user.handle}:`, err instanceof Error ? err.message : String(err));
        }

        const delay = Math.floor(Math.random() * 2000) + 1000;
        await new Promise(resolve => setTimeout(resolve, delay));
    }
}

runSimulation().catch(console.error);
