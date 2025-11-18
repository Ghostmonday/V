/**
 * Type declarations for db.js module
 * Database configuration - Supabase REST API only
 */
import type { SupabaseClient } from '@supabase/supabase-js';
import type Redis from 'ioredis';

export const supabase: SupabaseClient;
export function getRedisClient(): Redis;
