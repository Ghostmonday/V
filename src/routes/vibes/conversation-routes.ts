/**
 * VIBES Conversation Routes
 * API endpoints for conversation management
 */

import express from 'express';
import { authMiddleware } from '../../middleware/auth.js';
import {
  createConversation,
  getConversation,
  getUserConversations,
  addParticipant,
  qualifiesForCardGeneration,
} from '../../services/vibes/conversation-service.js';
import { logError } from '../../shared/logger.js';

const router = express.Router();

// Create conversation
router.post('/', authMiddleware, async (req, res, next) => {
  try {
    const userId = (req as any).user?.id;
    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { participant_ids, is_group } = req.body;
    
    if (!participant_ids || !Array.isArray(participant_ids) || participant_ids.length === 0) {
      return res.status(400).json({ error: 'participant_ids required' });
    }

    const conversation = await createConversation(
      userId,
      participant_ids,
      is_group || false
    );

    res.json({ conversation });
  } catch (error) {
    logError('Failed to create conversation', error);
    next(error);
  }
});

// Get conversation by ID
router.get('/:id', authMiddleware, async (req, res, next) => {
  try {
    const conversation = await getConversation(req.params.id);
    
    if (!conversation) {
      return res.status(404).json({ error: 'Conversation not found' });
    }

    res.json({ conversation });
  } catch (error) {
    logError('Failed to get conversation', error);
    next(error);
  }
});

// Get user's conversations
router.get('/', authMiddleware, async (req, res, next) => {
  try {
    const userId = (req as any).user?.id;
    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const conversations = await getUserConversations(userId);
    res.json({ conversations });
  } catch (error) {
    logError('Failed to get user conversations', error);
    next(error);
  }
});

// Add participant
router.post('/:id/participants', authMiddleware, async (req, res, next) => {
  try {
    const { user_id } = req.body;
    
    if (!user_id) {
      return res.status(400).json({ error: 'user_id required' });
    }

    await addParticipant(req.params.id, user_id);
    res.json({ success: true });
  } catch (error) {
    logError('Failed to add participant', error);
    next(error);
  }
});

// Check if qualifies for card generation
router.get('/:id/qualifies-for-card', authMiddleware, async (req, res, next) => {
  try {
    const qualifies = await qualifiesForCardGeneration(req.params.id);
    res.json({ qualifies });
  } catch (error) {
    logError('Failed to check qualification', error);
    next(error);
  }
});

export default router;
