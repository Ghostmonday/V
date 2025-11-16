import express from 'express';
import { supabase } from '../config/db.js';
import { authMiddleware as authenticate } from '../middleware/auth.js';
import { broadcastToRoom } from '../ws/utils.js';

const router = express.Router();

router.post('/', authenticate, async (req, res) => {
  const { message_id, emoji, action = 'add' } = req.body;
  
  // Input validation
  if (!message_id || !emoji) {
    return res.status(400).json({ error: 'message_id and emoji are required' });
  }
  
  if (!['add', 'remove'].includes(action)) {
    return res.status(400).json({ error: 'action must be "add" or "remove"' });
  }
  
  // Validate emoji (basic check)
  if (typeof emoji !== 'string' || emoji.length > 10) {
    return res.status(400).json({ error: 'Invalid emoji format' });
  }

  try {
    const { data: msg, error: fetchError } = await supabase
      .from('messages')
      .select('reactions, room_id')
      .eq('id', message_id)
      .single();
    
    if (fetchError || !msg) {
      return res.status(404).json({ error: 'Message not found' });
    }
    
    let reactions = Array.isArray(msg.reactions) ? [...msg.reactions] : [];
    const idx = reactions.findIndex((r: any) => r.emoji === emoji);
    
    if (action === 'add') {
      if (idx === -1) {
        reactions.push({ emoji, user_ids: [req.user.id], count: 1 });
      } else {
        // Check if user already reacted
        if (!reactions[idx].user_ids.includes(req.user.id)) {
          reactions[idx].user_ids.push(req.user.id);
          reactions[idx].count++;
        }
      }
    } else if (idx !== -1) {
      reactions[idx].user_ids = reactions[idx].user_ids.filter((id: string) => id !== req.user.id);
      reactions[idx].count--;
      if (reactions[idx].count === 0) {
        reactions.splice(idx, 1);
      }
    }
    
    const { error: updateError } = await supabase
      .from('messages')
      .update({ reactions })
      .eq('id', message_id);
    
    if (updateError) {
      throw updateError;
    }
    
    broadcastToRoom(msg.room_id, { type: 'reaction_update', data: { message_id, reactions } });
    res.json({ success: true, reactions });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to update reaction', details: error.message });
  }
});

export default router;

