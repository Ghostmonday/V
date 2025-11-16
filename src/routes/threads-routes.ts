import express from 'express';
import { supabase } from '../config/db.js';
import { authMiddleware as authenticate } from '../middleware/auth.js';
import { broadcastToRoom } from '../ws/utils.js';

const router = express.Router();

router.post('/', authenticate, async (req, res) => {
  const { parent_message_id, title, initial_message } = req.body;
  try {
    const { data: thread } = await supabase.from('threads').insert({
      parent_message_id,
      title,
      created_by: req.user.id,
    }).select().single();
    if (initial_message) {
      await supabase.from('messages').insert({
        content: initial_message,
        thread_id: thread.id,
        sender_id: req.user.id,
      });
    }
    broadcastToRoom(thread.room_id, { type: 'thread_created', data: thread });
    res.json(thread);
  } catch (error) {
    res.status(500).json({ error: 'Failed to create thread' });
  }
});

router.get('/:id', authenticate, async (req, res) => {
  const { id } = req.params;
  try {
    const { data } = await supabase.from('threads').select('*').eq('id', id).single();
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: 'Failed to get thread' });
  }
});

export default router;

