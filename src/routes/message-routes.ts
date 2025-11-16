/**
 * Message Routes
 * Handles message sending and retrieval endpoints
 */

import { Router } from 'express';
import * as messageService from '../services/message-service.js';
import { telemetryHook } from '../telemetry/index.js';
import { rateLimit } from '../middleware/rate-limiter.js';

const router = Router();

// Apply rate limiting to message routes
router.use(rateLimit({ max: 100, windowMs: 60000 })); // 100 requests per minute

/**
 * POST /messaging/send
 * Send a message to a room (queued for reliability)
 */
router.post('/send', async (req, res, next) => {
  try {
    telemetryHook('messaging_send_start');
    
    // Queue message instead of processing directly
    const { queueMessage } = await import('../services/message-queue.js');
    const result = await queueMessage(req.body); // Async handoff: message queued but not guaranteed to process
    
    telemetryHook('messaging_send_end');
    res.status(202).json({
      status: 'accepted',
      jobId: result.jobId,
      message: 'Message queued for processing',
    });
  } catch (error) {
    next(error); // Error branch: queue full or Redis down, but client gets generic error
  }
});

/**
 * GET /messaging/:roomId?since=ISO8601_TIMESTAMP
 * Retrieve recent messages from a room
 * @param since - Optional ISO8601 timestamp to fetch messages after this time (lazy loading)
 */
router.get('/:roomId', async (req, res, next) => {
  try {
    telemetryHook('messaging_get_start');
    const since = req.query.since as string | undefined;
    const messages = await messageService.getRoomMessages(req.params.roomId, since); // No timeout - can hang if DB slow
    telemetryHook('messaging_get_end');
    res.json(messages);
  } catch (error) {
    next(error); // Error branch: DB timeout not caught, hangs indefinitely
  }
});

/**
 * SIN-202: Reaction endpoints
 */
router.post('/:message_id/react', async (req, res, next) => {
  try {
    const { messagesController } = await import('../services/messages-controller.js');
    await messagesController.addReaction(req, res);
  } catch (error) {
    next(error);
  }
});

router.delete('/:message_id/react/:emoji', async (req, res, next) => {
  try {
    // Reuse addReaction with remove action
    const { messagesController } = await import('../services/messages-controller.js');
    req.body.action = 'remove';
    await messagesController.addReaction(req, res);
  } catch (error) {
    next(error);
  }
});

/**
 * SIN-302: Thread endpoints
 */
router.post('/threads', async (req, res, next) => {
  try {
    const { messagesController } = await import('../services/messages-controller.js');
    await messagesController.createThread(req, res);
  } catch (error) {
    next(error);
  }
});

router.get('/threads/:thread_id', async (req, res, next) => {
  try {
    const { messagesController } = await import('../services/messages-controller.js');
    await messagesController.getThread(req, res);
  } catch (error) {
    next(error);
  }
});

router.get('/rooms/:room_id/threads', async (req, res, next) => {
  try {
    const { messagesController } = await import('../services/messages-controller.js');
    await messagesController.getRoomThreads(req, res);
  } catch (error) {
    next(error);
  }
});

/**
 * SIN-401: Message edit/delete
 */
router.patch('/:message_id', async (req, res, next) => {
  try {
    const { messagesController } = await import('../services/messages-controller.js');
    await messagesController.editMessage(req, res);
  } catch (error) {
    next(error);
  }
});

router.delete('/:message_id', async (req, res, next) => {
  try {
    const { messagesController } = await import('../services/messages-controller.js');
    await messagesController.deleteMessage(req, res);
  } catch (error) {
    next(error);
  }
});

/**
 * SIN-402: Search messages
 */
router.get('/search', async (req, res, next) => {
  try {
    const { messagesController } = await import('../services/messages-controller.js');
    await messagesController.searchMessages(req, res);
  } catch (error) {
    next(error);
  }
});

export default router;

