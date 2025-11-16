import express from 'express';
import { authMiddleware as authenticate } from '../middleware/auth.js';
import { enqueueNotification } from '../services/notifications-service.js';

const router = express.Router();

router.post('/', authenticate, async (req, res) => {
  const { user_id, payload } = req.body;
  try {
    await enqueueNotification(user_id, payload);
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Notify failed' });
  }
});

export default router;

