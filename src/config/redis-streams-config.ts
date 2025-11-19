/**
 * Redis Streams Integration
 * Phase 9.2: Enhanced pub/sub with Redis Streams for message routing and archival
 *
 * Redis Streams provides:
 * - Persistent message queues
 * - Consumer groups for load balancing
 * - Message acknowledgment and retry
 * - Better support for archival workflows
 *
 * Architecture:
 * - Streams: Separate streams per room for message routing
 * - Consumer Groups: Process messages in parallel across instances
 * - Archival: Stream messages to archival service via dedicated consumer group
 */

import { getRedisClient } from './db.ts';
import { logInfo, logError, logWarning } from '../shared/logger-shared.js';

const redis = getRedisClient();

// Stream names
const MESSAGE_STREAM_PREFIX = 'messages:';
const ARCHIVAL_STREAM = 'messages:archival';
const MODERATION_STREAM = 'messages:moderation';

// Consumer group names
const CONSUMER_GROUP_BROADCAST = 'broadcast';
const CONSUMER_GROUP_ARCHIVAL = 'archival';
const CONSUMER_GROUP_MODERATION = 'moderation';

/**
 * Get stream name for a room
 */
function getRoomStream(roomId: string): string {
  return `${MESSAGE_STREAM_PREFIX}${roomId}`;
}

/**
 * Initialize consumer groups for a stream
 * Creates consumer groups if they don't exist
 *
 * @param streamName - Stream name
 */
export async function initializeConsumerGroups(streamName: string): Promise<void> {
  try {
    // Create broadcast consumer group (reads from beginning if new)
    try {
      await redis.xgroup('CREATE', streamName, CONSUMER_GROUP_BROADCAST, '0', 'MKSTREAM');
      logInfo('Created broadcast consumer group', { stream: streamName });
    } catch (error: any) {
      // Group already exists, ignore error
      if (!error.message?.includes('BUSYGROUP')) {
        throw error;
      }
    }

    // Create archival consumer group
    try {
      await redis.xgroup('CREATE', streamName, CONSUMER_GROUP_ARCHIVAL, '0', 'MKSTREAM');
      logInfo('Created archival consumer group', { stream: streamName });
    } catch (error: any) {
      if (!error.message?.includes('BUSYGROUP')) {
        throw error;
      }
    }

    // Create moderation consumer group
    try {
      await redis.xgroup('CREATE', streamName, CONSUMER_GROUP_MODERATION, '0', 'MKSTREAM');
      logInfo('Created moderation consumer group', { stream: streamName });
    } catch (error: any) {
      if (!error.message?.includes('BUSYGROUP')) {
        throw error;
      }
    }
  } catch (error) {
    logError(
      'Failed to initialize consumer groups',
      error instanceof Error ? error : new Error(String(error))
    );
  }
}

/**
 * Publish message to Redis Stream
 * Adds message to room-specific stream for routing
 *
 * @param roomId - Room ID
 * @param messageData - Message data
 * @returns Stream entry ID
 */
export async function publishToStream(
  roomId: string,
  messageData: Record<string, any>
): Promise<string> {
  try {
    const streamName = getRoomStream(roomId);

    // Initialize consumer groups if needed
    await initializeConsumerGroups(streamName);

    // Add message to stream
    // Format: { field: value, ... } where values are strings
    const fields: string[] = [];
    for (const [key, value] of Object.entries(messageData)) {
      fields.push(key, JSON.stringify(value));
    }

    const entryId = await redis.xadd(streamName, '*', ...fields);

    logInfo('Published message to stream', { stream: streamName, entryId });

    return entryId as string;
  } catch (error) {
    logError(
      'Failed to publish to stream',
      error instanceof Error ? error : new Error(String(error))
    );
    throw error;
  }
}

/**
 * Read messages from stream using consumer group
 * Processes messages and acknowledges them
 *
 * @param streamName - Stream name
 * @param consumerGroup - Consumer group name
 * @param consumerName - Consumer name (unique per instance)
 * @param count - Number of messages to read (default: 10)
 * @returns Array of messages
 */
export async function readFromStream(
  streamName: string,
  consumerGroup: string,
  consumerName: string,
  count: number = 10
): Promise<Array<{ id: string; data: Record<string, any> }>> {
  try {
    // Read pending messages first (unacknowledged)
    const pending = (await redis.xreadgroup(
      'GROUP',
      consumerGroup,
      consumerName,
      'COUNT',
      count.toString(),
      'STREAMS',
      streamName,
      '0'
    )) as any;

    // If no pending messages, read new messages
    if (!pending || pending.length === 0 || pending[0][1].length === 0) {
      const newMessages = (await redis.xreadgroup(
        'GROUP',
        consumerGroup,
        consumerName,
        'COUNT',
        count.toString(),
        'BLOCK',
        '1000', // Block for 1 second
        'STREAMS',
        streamName,
        '>'
      )) as any;

      if (!newMessages || newMessages.length === 0) {
        return [];
      }

      return parseStreamMessages(newMessages[0][1]);
    }

    return parseStreamMessages(pending[0][1]);
  } catch (error) {
    logError(
      'Failed to read from stream',
      error instanceof Error ? error : new Error(String(error))
    );
    return [];
  }
}

/**
 * Parse stream messages from Redis format
 */
function parseStreamMessages(messages: any[]): Array<{ id: string; data: Record<string, any> }> {
  return messages.map((msg: any) => {
    const id = msg[0] as string;
    const fields = msg[1] as string[];
    const data: Record<string, any> = {};

    // Parse field-value pairs
    for (let i = 0; i < fields.length; i += 2) {
      const key = fields[i];
      const value = fields[i + 1];
      try {
        data[key] = JSON.parse(value);
      } catch {
        data[key] = value; // Fallback to raw string
      }
    }

    return { id, data };
  });
}

/**
 * Acknowledge message processing
 * Marks message as processed in consumer group
 *
 * @param streamName - Stream name
 * @param consumerGroup - Consumer group name
 * @param messageIds - Array of message IDs to acknowledge
 */
export async function acknowledgeMessages(
  streamName: string,
  consumerGroup: string,
  messageIds: string[]
): Promise<void> {
  try {
    if (messageIds.length === 0) {
      return;
    }

    await redis.xack(streamName, consumerGroup, ...messageIds);
    logInfo('Acknowledged messages', { stream: streamName, count: messageIds.length });
  } catch (error) {
    logError(
      'Failed to acknowledge messages',
      error instanceof Error ? error : new Error(String(error))
    );
  }
}

/**
 * Route message to archival stream
 * Copies message to archival stream for processing
 *
 * @param roomId - Room ID
 * @param messageId - Message ID
 * @param messageData - Message data
 */
export async function routeToArchival(
  roomId: string,
  messageId: string,
  messageData: Record<string, any>
): Promise<void> {
  try {
    const archivalData = {
      room_id: roomId,
      message_id: messageId,
      ...messageData,
      archived_at: new Date().toISOString(),
    };

    await publishToStream(ARCHIVAL_STREAM, archivalData);
    logInfo('Routed message to archival', { messageId, roomId });
  } catch (error) {
    logError(
      'Failed to route to archival',
      error instanceof Error ? error : new Error(String(error))
    );
  }
}

/**
 * Route message to moderation stream
 * Copies message to moderation stream for processing
 *
 * @param roomId - Room ID
 * @param messageId - Message ID
 * @param messageData - Message data
 */
export async function routeToModeration(
  roomId: string,
  messageId: string,
  messageData: Record<string, any>
): Promise<void> {
  try {
    const moderationData = {
      room_id: roomId,
      message_id: messageId,
      ...messageData,
      queued_at: new Date().toISOString(),
    };

    await publishToStream(MODERATION_STREAM, moderationData);
    logInfo('Routed message to moderation', { messageId, roomId });
  } catch (error) {
    logError(
      'Failed to route to moderation',
      error instanceof Error ? error : new Error(String(error))
    );
  }
}

/**
 * Get stream length (number of messages)
 */
export async function getStreamLength(streamName: string): Promise<number> {
  try {
    const length = await redis.xlen(streamName);
    return length as number;
  } catch (error) {
    logError(
      'Failed to get stream length',
      error instanceof Error ? error : new Error(String(error))
    );
    return 0;
  }
}

/**
 * Trim stream to keep only recent messages
 * Removes old messages beyond retention period
 *
 * @param streamName - Stream name
 * @param maxLength - Maximum number of messages to keep
 */
export async function trimStream(streamName: string, maxLength: number): Promise<number> {
  try {
    const trimmed = await redis.xtrim(streamName, 'MAXLEN', '~', maxLength.toString());
    return trimmed as number;
  } catch (error) {
    logError('Failed to trim stream', error instanceof Error ? error : new Error(String(error)));
    return 0;
  }
}

/**
 * Get consumer group info
 * Returns information about consumers and pending messages
 */
export async function getConsumerGroupInfo(
  streamName: string,
  consumerGroup: string
): Promise<any> {
  try {
    const info = await redis.xinfo('GROUPS', streamName);
    // Find our consumer group
    const groups = info as any[];
    return groups.find((g: any) => g[1] === consumerGroup) || null;
  } catch (error) {
    logError(
      'Failed to get consumer group info',
      error instanceof Error ? error : new Error(String(error))
    );
    return null;
  }
}
