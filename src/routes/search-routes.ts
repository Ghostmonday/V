import express from 'express';
import { authMiddleware as authenticate } from '../middleware/auth.js';
import { fullTextSearch, searchRoomMessages, searchRooms } from '../services/search-service.js';
import { logAudit } from '../shared/logger.js';
import { AuthenticatedRequest } from '../types/auth.types.js';

const router = express.Router();

/**
 * GET /search?query=foo&type=messages&room_id=xxx
 * Full-text search across messages, rooms, and users
 */
router.get('/', authenticate, async (req: AuthenticatedRequest, res) => {
  try {
    const { query, type, room_id, user_id, limit, offset } = req.query;

    if (!query || typeof query !== 'string') {
      return res.status(400).json({ error: 'query parameter is required' });
    }

    const results = await fullTextSearch({
      query: query as string,
      type: (type as any) || 'all',
      roomId: room_id as string | undefined,
      userId: user_id as string | undefined,
      limit: limit ? parseInt(limit as string) : 50,
      offset: offset ? parseInt(offset as string) : 0
    });

    await logAudit('search', req.user?.userId || 'unknown', { 
      query, 
      type, 
      result_count: results.length 
    });

    res.json({ results, count: results.length });
  } catch (error: any) {
    res.status(500).json({ error: 'Search failed', message: error.message });
  }
});

/**
 * GET /search/messages?room_id=xxx&query=foo
 * Search messages in a specific room
 */
router.get('/messages', authenticate, async (req: AuthenticatedRequest, res) => {
  try {
    const { room_id, query, limit } = req.query;

    if (!query || typeof query !== 'string') {
      return res.status(400).json({ error: 'query parameter is required' });
    }

    if (!room_id || typeof room_id !== 'string') {
      return res.status(400).json({ error: 'room_id parameter is required' });
    }

    const results = await searchRoomMessages(
      room_id as string,
      query as string,
      limit ? parseInt(limit as string) : 50
    );

    res.json({ results, count: results.length });
  } catch (error: any) {
    res.status(500).json({ error: 'Message search failed', message: error.message });
  }
});

/**
 * GET /search/rooms?query=foo
 * Search public rooms
 */
router.get('/rooms', authenticate, async (req: AuthenticatedRequest, res) => {
  try {
    const { query, limit } = req.query;

    if (!query || typeof query !== 'string') {
      return res.status(400).json({ error: 'query parameter is required' });
    }

    const results = await searchRooms(
      query as string,
      limit ? parseInt(limit as string) : 20
    );

    res.json({ results, count: results.length });
  } catch (error: any) {
    res.status(500).json({ error: 'Room search failed', message: error.message });
  }
});

export default router;

