/**
 * Admin Routes
 * Administrative endpoints including health check and demo seeding
 */

import { Router, type Request, type Response } from 'express';
import { supabase } from '../config/db.ts';
import * as optimizerService from '../services/optimizer-service.js';
import { telemetryHook } from '../telemetry/index.js';
import { authMiddleware } from '../middleware/auth.js';
import { logError } from '../shared/logger.js';

const router = Router();

/**
 * GET /admin/health
 * Health check endpoint with Supabase connectivity test
 */
router.get('/health', async (_req: Request, res: Response) => {
  try {
    const { data, error } = await supabase
      .from('users')
      .select('id')
      .limit(1);

    if (error) throw error;

    res.json({
      status: 'healthy',
      database: 'Supabase REST',
      timestamp: new Date().toISOString(),
      sample_user_count: data.length,
    });
  } catch (err: unknown) {
    logError('Health check failed', err instanceof Error ? err : new Error(String(err)));
    res.status(503).json({
      status: 'unhealthy',
      error: err instanceof Error ? err.message : String(err),
    });
  }
});

/**
 * POST /admin/demo-seed
 * Seeds demo data: user → room → message
 */
router.post('/demo-seed', async (_req: Request, res: Response) => {
  try {
    // 1. Insert demo user
    const { data: user, error: userErr } = await supabase
      .from('users')
      .insert([{ username: 'DemoUser' }])
      .select()
      .single();
    if (userErr) throw userErr;

    // 2. Insert demo room
    const { data: room, error: roomErr } = await supabase
      .from('rooms')
      .insert([{ name: 'Demo Room', owner_id: user.id }])
      .select()
      .single();
    if (roomErr) throw roomErr;

    // 3. Insert demo message
    const { error: msgErr } = await supabase
      .from('messages')
      .insert([
        {
          room_id: room.id,
          user_id: user.id,
          content: 'Hello from VibeZ backend!',
        },
      ]);
    if (msgErr) throw msgErr;

    res.json({
      status: 'ok',
      user_id: user.id,
      room_id: room.id,
      message: 'Demo data seeded successfully',
    });
  } catch (err: unknown) {
    logError('Demo-seed error', err instanceof Error ? err : new Error(String(err)));
    res.status(500).json({ 
      status: 'error', 
      message: err instanceof Error ? err.message : String(err) 
    });
  }
});

/**
 * Rate limiter function for room actions
 * Allows up to 5 actions per room_id per minute
 * 
 * Uses Redis INCR pattern:
 * - First call: INCR creates key with value 1, then EXPIRE sets 60s TTL
 * - Subsequent calls: INCR increments counter, EXPIRE is no-op (key already has TTL)
 * - After 60s: Key expires, counter resets to 0
 */
async function rateLimitRoomActions(roomId: string): Promise<boolean> {
  // Dynamic import to avoid circular dependency
  const { getRedisClient } = await import('../config/db.js');
  const redisClient = getRedisClient();
  
  // Redis key format: "healing_action:{roomId}"
  // Each room gets its own counter
  const key = `healing_action:${roomId}`;
  
    // Increment counter atomically (INCR is atomic in Redis)
    // Returns new count value
    const count = await redisClient.incr(key); // Race: INCR and EXPIRE not atomic together
    
    // Set expiration only on first increment (count === 1)
    // This creates a 60-second sliding window
    // If key already exists, EXPIRE is no-op (doesn't reset TTL)
    if (count === 1) {
      await redisClient.expire(key, 60); // Gotcha: if Redis down between INCR and EXPIRE, key never expires
    }
  
  // Return true if under limit (5 actions), false if exceeded
  return count <= 5; // Allow up to 5 actions per minute per room
}

/**
 * POST /admin/apply-recommendation
 * Store optimization recommendation (requires authentication)
 * Enhanced with input validation, rate limiting, and security
 */
router.post('/apply-recommendation', authMiddleware, async (req: Request, res: Response, next) => {
  try {
    // Dynamic import to reduce initial bundle size (Zod is only used here)
    const { z } = await import('zod');
    
    // Define Zod schema for input validation with strict typing
    // .strict() prevents extra fields (security: reject unexpected data)
    const RecommendationSchema = z.object({
      room_id: z.string().uuid('Invalid room_id format').optional(), // Must be valid UUID if provided
      recommendation: z.union([
        z.record(z.string(), z.unknown()), // Object: { key: value } format
        z.string().min(1, 'Recommendation cannot be empty') // Or string (min 1 char)
      ]), // Union allows either object or string
    }).strict(); // Reject unknown fields (prevents injection of extra data)

    // Validate request body against schema
    // safeParse returns { success: boolean, data?: T, error?: ZodError }
    const validation = RecommendationSchema.safeParse(req.body);
    if (!validation.success) {
      // Validation failed - return 400 with error details
      return res.status(400).json({ error: validation.error.message });
    }

    // Extract validated data (TypeScript knows types are correct)
    const { room_id, recommendation } = validation.data;

    // Rate limit if room_id is provided (per-room rate limiting)
    // Prevents abuse: max 5 recommendations per room per minute
    if (room_id) {
      const allowed = await rateLimitRoomActions(room_id);
      if (!allowed) {
        // Rate limit exceeded - return 429 Too Many Requests
        return res.status(429).json({ error: 'Rate limit exceeded for this room' });
      }
    }

    telemetryHook('admin_apply_start');
    await optimizerService.storeOptimizationRecommendation(recommendation);
    telemetryHook('admin_apply_end');
    res.status(200).json({ success: true });
  } catch (error) {
    next(error);
  }
});

export default router;
