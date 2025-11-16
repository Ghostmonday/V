import express from 'express';
import { getRedisClient } from '../config/redis-pubsub.js';
import { supabase } from '../config/db.js';

const router = express.Router();

router.get('/healthz', async (req, res) => {
  try {
    await getRedisClient().ping();
    await supabase.from('users').select('count(*)');
    // LiveKit health check can be added here
    res.json({ status: 'healthy' });
  } catch (error) {
    res.status(503).json({ status: 'unhealthy' });
  }
});

export default router;

