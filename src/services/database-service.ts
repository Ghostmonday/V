/**
 * Database Service
 * Provides centralized database access, TTL configuration, and Supabase Realtime integration
 */

import { supabase } from '../config/db.ts';
import { logError, logInfo } from '../shared/logger.js';
import type { RealtimeChannel } from '@supabase/supabase-js';

// TTL configuration types
export interface TTLConfig {
  tableName: string;
  ttlDays: number;
  columnName?: string; // Default: 'created_at'
  enabled: boolean;
}

// Default TTL policies
const DEFAULT_TTL_POLICIES: Record<string, number> = {
  messages: 30, // 30 days default
  temporary_rooms: 7, // 7 days
  read_receipts: 14, // 14 days
  ephemeral_data: 1 / 24, // 1 hour (expressed as days)
};

// Active Supabase Realtime subscriptions
const activeChannels = new Map<string, RealtimeChannel>();

/**
 * Initialize Supabase Realtime client
 * Returns the Supabase client with Realtime enabled
 */
export function getRealtimeClient() {
  return supabase;
}

/**
 * Subscribe to a Supabase Realtime channel
 * @param channelName - Channel name (e.g., 'room:123')
 * @param tableName - Database table to watch (e.g., 'messages')
 * @param callback - Callback function for received events
 * @returns Channel subscription object
 */
export function subscribeToChannel(
  channelName: string,
  tableName: string,
  callback: (payload: any) => void
): RealtimeChannel | null {
  try {
    // Check if already subscribed
    if (activeChannels.has(channelName)) {
      logInfo(`Already subscribed to channel: ${channelName}`);
      return activeChannels.get(channelName)!;
    }

    const channel = supabase
      .channel(channelName)
      .on(
        'postgres_changes',
        {
          event: '*', // Listen to all events (INSERT, UPDATE, DELETE)
          schema: 'public',
          table: tableName,
        },
        (payload) => {
          callback(payload);
        }
      )
      .subscribe((status) => {
        if (status === 'SUBSCRIBED') {
          logInfo(`Subscribed to Realtime channel: ${channelName}`);
        } else if (status === 'CHANNEL_ERROR') {
          logError(
            `Failed to subscribe to channel: ${channelName}`,
            new Error('Channel subscription error')
          );
        }
      });

    activeChannels.set(channelName, channel);
    return channel;
  } catch (error) {
    logError(
      `Error subscribing to channel ${channelName}`,
      error instanceof Error ? error : new Error(String(error))
    );
    return null;
  }
}

/**
 * Unsubscribe from a Realtime channel
 * @param channelName - Channel name to unsubscribe from
 */
export function unsubscribeFromChannel(channelName: string): void {
  const channel = activeChannels.get(channelName);
  if (channel) {
    supabase.removeChannel(channel);
    activeChannels.delete(channelName);
    logInfo(`Unsubscribed from channel: ${channelName}`);
  }
}

/**
 * Configure TTL policy for a table
 * Creates or updates a TTL policy in the database
 * @param config - TTL configuration
 */
export async function configureTTLPolicy(config: TTLConfig): Promise<boolean> {
  try {
    if (!config.enabled) {
      logInfo(`TTL policy disabled for table: ${config.tableName}`);
      return true;
    }

    const columnName = config.columnName || 'created_at';
    const ttlDays = config.ttlDays;

    // Create TTL policy using PostgreSQL function
    // This assumes a function exists in the database to manage TTL policies
    const { error } = await supabase.rpc('set_ttl_policy', {
      table_name: config.tableName,
      column_name: columnName,
      ttl_days: ttlDays,
    });

    if (error) {
      // If RPC function doesn't exist, log warning but don't fail
      logError(`Failed to set TTL policy for ${config.tableName}`, error);
      return false;
    }

    logInfo(`TTL policy configured for ${config.tableName}: ${ttlDays} days`);
    return true;
  } catch (error) {
    logError(
      `Error configuring TTL policy for ${config.tableName}`,
      error instanceof Error ? error : new Error(String(error))
    );
    return false;
  }
}

/**
 * Get default TTL for a table
 * @param tableName - Table name
 * @returns TTL in days, or null if not configured
 */
export function getDefaultTTL(tableName: string): number | null {
  return DEFAULT_TTL_POLICIES[tableName] || null;
}

/**
 * Initialize default TTL policies
 * Configures TTL for all tables with default policies
 */
export async function initializeDefaultTTLPolicies(): Promise<void> {
  logInfo('Initializing default TTL policies...');

  const policies: TTLConfig[] = [
    { tableName: 'messages', ttlDays: DEFAULT_TTL_POLICIES.messages, enabled: true },
    { tableName: 'read_receipts', ttlDays: DEFAULT_TTL_POLICIES.read_receipts, enabled: true },
    // Note: temporary_rooms and ephemeral_data may need custom handling
  ];

  for (const policy of policies) {
    await configureTTLPolicy(policy);
  }

  logInfo('Default TTL policies initialized');
}

/**
 * Subscribe to messages table changes via Supabase Realtime
 * @param roomId - Room ID to filter messages
 * @param callback - Callback for message events
 * @returns Channel subscription
 */
export function subscribeToMessages(
  roomId: string,
  callback: (event: { type: string; payload: any }) => void
): RealtimeChannel | null {
  const channelName = `room:${roomId}`;

  return subscribeToChannel(channelName, 'messages', (payload) => {
    const eventType = payload.eventType || 'UNKNOWN';
    callback({
      type: eventType.toLowerCase(),
      payload: payload.new || payload.old,
    });
  });
}

/**
 * Cleanup: Unsubscribe from all channels
 * Should be called on application shutdown
 */
export function cleanupSubscriptions(): void {
  for (const [channelName] of activeChannels) {
    unsubscribeFromChannel(channelName);
  }
}
