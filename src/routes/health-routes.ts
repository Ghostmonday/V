import express from 'express';
import { getRedisClient } from '../config/redis-pubsub.js';
import { supabase } from '../config/db.ts';
import { getCacheMetrics } from '../services/cache-service.js';

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

/**
 * Phase 3.4: Cache metrics endpoint
 * GET /health/cache-metrics
 */
router.get('/cache-metrics', async (req, res) => {
  try {
    const metrics = getCacheMetrics();
    res.json({
      success: true,
      metrics: {
        ...metrics,
        // Calculate hit rate percentage
        hitRatePercent: Math.round(metrics.hitRate * 100 * 100) / 100,
      },
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to get cache metrics' });
  }
});

export default router;

