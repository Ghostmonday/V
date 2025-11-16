/**
 * Message Queue Service
 * Implements Bull queue for reliable message processing with retries and back-pressure
 */

import Queue from 'bull';
import { getRedisClient } from '../config/db.js';
import { logError, logInfo } from '../shared/logger.js';
import * as messageService from './message-service.js';

const redisClient = getRedisClient();

// Create message queue with rate limiting
// Bull uses Redis URL directly or connection object
// VAULT NOT FEASIBLE: Performance blocker - Redis needed synchronously at startup
// TODO: Move to vault when async initialization performance allows
const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';

// Create Bull queue instance for reliable message processing
// Queue name 'message-delivery' is used as Redis key prefix for this queue
export const messageQueue = new Queue('message-delivery', {
  redis: redisUrl, // Redis connection URL (Bull uses Redis for job storage)
  defaultJobOptions: {
    attempts: 3, // Retry failed jobs up to 3 times before giving up
    backoff: {
      type: 'exponential', // Exponential backoff: delay doubles each retry (2s, 4s, 8s)
      delay: 2000, // Initial delay: 2 seconds before first retry
    },
    removeOnComplete: {
      age: 3600, // Auto-delete completed jobs older than 1 hour (in seconds)
      count: 1000, // Keep max 1000 completed jobs (FIFO - oldest deleted first)
    },
    removeOnFail: {
      age: 86400, // Keep failed jobs for 24 hours (for debugging/analysis)
    },
  },
  settings: {
    maxStalledCount: 1, // If job stalls 1 time, mark as failed (prevents infinite retries)
    stalledInterval: 30000, // Check for stalled jobs every 30 seconds
  },
  limiter: {
    max: 1000, // Maximum 1000 jobs processed per duration window
    duration: 1000, // Duration window: 1000ms = 1 second (so 1000 jobs/sec max)
  },
});

// Register job processor for 'send-message' job type
// This function runs whenever a job of type 'send-message' is queued
messageQueue.process('send-message', async (job) => {
  // Extract job data (passed when queueing the message)
  const { roomId, senderId, content } = job.data;
  
  logInfo(`Processing message job ${job.id} for room ${roomId}`);
  
  try {
    // Call the actual message service to persist and broadcast
    // This is where the real work happens (DB insert + Redis pub/sub)
    await messageService.sendMessageToRoom({ // Retry: Bull retries 3x, but DB insert may succeed on retry = duplicate message
      roomId,
      senderId,
      content,
    });
    
    logInfo(`Message job ${job.id} completed successfully`);
    // Return success result (stored in job.result for monitoring)
    return { success: true, messageId: job.id };
  } catch (error: any) {
    logError(`Message job ${job.id} failed`, error);
    // Re-throw error to trigger Bull's retry mechanism
    // Bull will automatically retry based on defaultJobOptions.attempts
    throw error; // Will trigger retry // After 3 retries, message permanently lost
  }
});

// Queue event handlers
messageQueue.on('completed', (job) => {
  logInfo(`Message job ${job.id} completed`);
});

messageQueue.on('failed', (job, err) => {
  logError(`Message job ${job.id} failed after ${job.attemptsMade} attempts`, err); // Message permanently lost - no retry
});

messageQueue.on('stalled', (job) => {
  logError(`Message job ${job.id} stalled`); // Worker crashed mid-processing - job may be duplicated
});

messageQueue.on('error', (error) => {
  logError('Message queue error', error);
});

/**
 * Add message to queue
 */
/**
 * Add message to queue for asynchronous processing
 * 
 * This function implements back-pressure: if queue is too full, reject new messages
 * to prevent memory exhaustion and ensure system stability.
 */
export async function queueMessage(data: {
  roomId: string | number;
  senderId: string;
  content: string;
}): Promise<{ jobId: string; status: string }> {
  try {
      // Check queue depth before adding (back-pressure mechanism)
      // waiting = jobs queued but not yet started
      // active = jobs currently being processed
      const waiting = await messageQueue.getWaitingCount(); // Race: count can change between check and add
      const active = await messageQueue.getActiveCount();
      
      // If total pending jobs exceeds 10,000, reject new messages
      // This prevents queue from growing unbounded and exhausting memory
      // Threshold chosen based on: ~10K jobs * ~1KB/job = ~10MB memory
      if (waiting + active > 10000) {
        throw new Error('Message queue is overloaded. Please try again later.'); // Load spike: legitimate users rejected
      }
    
    // Add job to queue with job type 'send-message'
    // Priority 1 = normal priority (higher numbers = higher priority)
    // delay: 0 = process immediately (no delay)
    const job = await messageQueue.add('send-message', data, {
      priority: 1, // Normal priority (can use 1-10, higher = more important)
      delay: 0, // Process immediately (set delay in ms for scheduled jobs)
    });
    
    // Return job ID so caller can track job status
    return {
      jobId: job.id.toString(), // Convert to string for JSON serialization
      status: 'queued', // Job is queued and waiting to be processed
    };
  } catch (error: any) {
    logError('Failed to queue message', error);
    throw error; // Re-throw to let caller handle (e.g., return 503 to client)
  }
}

/**
 * Get queue statistics
 */
export async function getQueueStats() {
  const [waiting, active, completed, failed, delayed] = await Promise.all([
    messageQueue.getWaitingCount(),
    messageQueue.getActiveCount(),
    messageQueue.getCompletedCount(),
    messageQueue.getFailedCount(),
    messageQueue.getDelayedCount(),
  ]);
  
  return {
    waiting,
    active,
    completed,
    failed,
    delayed,
    total: waiting + active + completed + failed + delayed,
  };
}

/**
 * Clean up old jobs from queue
 * 
 * Removes completed/failed jobs older than retention period to prevent Redis
 * memory growth. Called periodically to maintain queue health.
 */
export async function cleanupQueue() {
  try {
    // Clean completed jobs: remove jobs older than 1 hour, max 1000 at a time
    // 3600000ms = 1 hour in milliseconds
    // 'completed' = only clean successfully completed jobs
    // 1000 = max jobs to clean per call (prevents blocking)
    await messageQueue.clean(3600000, 'completed', 1000);
    
    // Clean failed jobs: remove jobs older than 24 hours, max 100 at a time
    // 86400000ms = 24 hours in milliseconds
    // 'failed' = only clean failed jobs (keep for debugging)
    // 100 = smaller batch for failed jobs (less common)
    await messageQueue.clean(86400000, 'failed', 100);
    
    logInfo('Queue cleanup completed');
  } catch (error: any) {
    // Don't throw - cleanup failures shouldn't crash the app
    logError('Queue cleanup failed', error);
  }
}

// Periodic cleanup: run every hour (3600000ms = 1 hour)
// Prevents Redis from accumulating old job data indefinitely
setInterval(cleanupQueue, 3600000);

