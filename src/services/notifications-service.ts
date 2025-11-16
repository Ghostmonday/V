import { getRedisClient } from '../config/db.js';
import { supabase } from '../config/db.js';
import webPush from 'web-push';
import { logError, logInfo } from '../shared/logger.js';

const redis = getRedisClient();
webPush.setVapidDetails(
  process.env.VAPID_SUBJECT || '',
  process.env.VAPID_PUBLIC_KEY || '',
  process.env.VAPID_PRIVATE_KEY || ''
);

// Use Redis Streams for better performance (or fallback to list)
const NOTIFICATION_STREAM = 'notifications:stream';
const NOTIFICATION_GROUP = 'notification-workers';

// Initialize consumer group if using streams
async function initNotificationStream() {
  try {
    await redis.xgroup('CREATE', NOTIFICATION_STREAM, NOTIFICATION_GROUP, '0', 'MKSTREAM').catch(() => {
      // Group already exists, ignore
    });
  } catch (error) {
    // Stream doesn't exist yet, will be created on first write
  }
}

export async function enqueueNotification(userId: string, payload: any): Promise<void> {
  try {
    const notificationData = {
      userId,
      payload: JSON.stringify(payload),
      timestamp: Date.now(),
    };
    
    // Use Redis Streams for better performance
    await redis.xadd(
      NOTIFICATION_STREAM,
      '*',
      'userId', userId,
      'payload', JSON.stringify(payload),
      'timestamp', Date.now().toString()
    );
  } catch (error: any) {
    // Fallback to list if streams not available
    logError('Failed to enqueue notification via stream, using list fallback', error);
    await redis.rpush(`notifications:${userId}`, JSON.stringify(payload));
  }
}

// Worker: process notification queue using Redis Streams
async function processNotificationQueue() {
  try {
    // Read from stream using consumer group
    const messages = await redis.xreadgroup(
      'GROUP', NOTIFICATION_GROUP, 'worker-1',
      'COUNT', 10,
      'BLOCK', 1000,
      'STREAMS', NOTIFICATION_STREAM, '>'
    );

    if (!messages || messages.length === 0) {
      return;
    }

    for (const [stream, streamMessages] of messages) {
      for (const [messageId, fields] of streamMessages) {
        try {
          const fieldMap: Record<string, string> = {};
          for (let i = 0; i < fields.length; i += 2) {
            fieldMap[fields[i]] = fields[i + 1];
          }

          const userId = fieldMap.userId;
          const payload = JSON.parse(fieldMap.payload);

          // Get user's push subscriptions
          const { data: subs, error } = await supabase
            .from('subscriptions')
            .select('push_sub, endpoint')
            .eq('user_id', userId)
            .eq('is_active', true);

          if (error) {
            logError('Failed to fetch subscriptions', error);
            continue;
          }

          // Send notification to all active subscriptions
          const sendPromises = (subs || []).map(async (sub: any) => {
            try {
              const pushSub = typeof sub.push_sub === 'string' 
                ? JSON.parse(sub.push_sub) 
                : sub.push_sub;
              
              await webPush.sendNotification(pushSub, JSON.stringify(payload));
              logInfo(`Notification sent to user ${userId}`);
            } catch (err: any) {
              logError(`Failed to send notification to ${sub.endpoint}`, err);
              // Mark subscription as inactive if it's invalid
              if (err.statusCode === 410 || err.statusCode === 404) {
                await supabase
                  .from('subscriptions')
                  .update({ is_active: false })
                  .eq('endpoint', sub.endpoint);
              }
            }
          });

          await Promise.allSettled(sendPromises);

          // Acknowledge message processing
          await redis.xack(NOTIFICATION_STREAM, NOTIFICATION_GROUP, messageId);
        } catch (error: any) {
          logError('Error processing notification', error);
          // Acknowledge anyway to prevent reprocessing
          await redis.xack(NOTIFICATION_STREAM, NOTIFICATION_GROUP, messageId).catch(() => {});
        }
      }
    }
  } catch (error: any) {
    // Fallback to list-based processing if streams fail
    if (error.message?.includes('NOGROUP') || error.message?.includes('stream')) {
      await processNotificationListFallback();
    } else {
      logError('Notification worker error', error);
    }
  }
}

// Fallback: process using Redis lists (less efficient but works)
async function processNotificationListFallback() {
  try {
    // Use SCAN instead of KEYS to avoid blocking
    const cursor = '0';
    const [nextCursor, keys] = await redis.scan(cursor, 'MATCH', 'notifications:*', 'COUNT', 10);
    
    for (const key of keys) {
      if (key.startsWith('notifications:stream')) continue; // Skip stream keys
      
      const userId = key.split(':')[1];
      const payload = await redis.lpop(key);
      
      if (payload) {
        const { data: subs } = await supabase
          .from('subscriptions')
          .select('push_sub, endpoint')
          .eq('user_id', userId)
          .eq('is_active', true);

        for (const sub of subs || []) {
          try {
            const pushSub = typeof sub.push_sub === 'string' 
              ? JSON.parse(sub.push_sub) 
              : sub.push_sub;
            await webPush.sendNotification(pushSub, payload);
          } catch (err: any) {
            logError(`Failed to send notification`, err);
          }
        }
      }
    }
  } catch (error: any) {
    logError('Notification list fallback error', error);
  }
}

// Initialize stream on module load
initNotificationStream().catch(err => {
  logError('Failed to initialize notification stream', err);
});

// Process queue every 2 seconds (less frequent than before)
setInterval(() => {
  processNotificationQueue().catch(err => {
    logError('Notification queue processing error', err);
  });
}, 2000);

