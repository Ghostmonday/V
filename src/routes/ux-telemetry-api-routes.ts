/**
 * UX Telemetry Routes
 *
 * API endpoints for UX telemetry ingestion and querying.
 * Completely separate from system/infra telemetry routes.
 *
 * @module ux-telemetry-routes
 */

import express from 'express';
import { z } from 'zod/v3';
import {
  insertUXTelemetryBatch,
  getEventsBySession,
  getEventsByCategory,
  getRecentSummary,
  getCategorySummary,
  deleteUserTelemetry,
  exportUserTelemetry,
} from '../services/ux-telemetry-service.js';
import { logError, logInfo } from '../shared/logger-shared.js';
import { authMiddleware } from '../middleware/auth/supabase-auth.js';
import { AuthenticatedRequest } from '../types/auth.types.js';
import type { UXTelemetryBatch } from '../types/ux-telemetry.js';
import { UXEventCategory, UXEventType } from '../types/ux-telemetry.js';

const router = express.Router();

/**
 * Zod schemas for validation
 */

// Device context schema
const deviceContextSchema = z
  .object({
    userAgent: z.string().optional(),
    screenWidth: z.number().optional(),
    screenHeight: z.number().optional(),
    viewportWidth: z.number().optional(),
    viewportHeight: z.number().optional(),
    pixelRatio: z.number().optional(),
    platform: z.string().optional(),
    language: z.string().optional(),
    connectionType: z.string().optional(),
    timezone: z.string().optional(),
  })
  .optional();

// UX telemetry event schema
const uxTelemetryEventSchema = z.object({
  traceId: z.string().uuid(),
  sessionId: z.string().uuid(),
  eventType: z.nativeEnum(UXEventType),
  category: z.nativeEnum(UXEventCategory),
  timestamp: z.string().datetime(),
  componentId: z.string().optional(),
  stateBefore: z.string().optional(),
  stateAfter: z.string().optional(),
  metadata: z.record(z.unknown()),
  deviceContext: deviceContextSchema,
  samplingFlag: z.boolean(),
  userId: z.string().uuid().optional(),
  roomId: z.string().uuid().optional(),
});

// Batch schema
const uxTelemetryBatchSchema = z.object({
  events: z.array(uxTelemetryEventSchema),
  batchId: z.string().uuid(),
  timestamp: z.string().datetime(),
});

/**
 * POST /api/ux-telemetry
 *
 * Ingest a batch of UX telemetry events.
 * Validates schema, applies server-side PII redaction, and stores in database.
 */
router.post('/', async (req, res) => {
  try {
    // Validate request body
    const validation = uxTelemetryBatchSchema.safeParse(req.body);

    if (!validation.success) {
      logError('[UX Telemetry] Invalid batch format', validation.error);
      return res.status(400).json({
        success: false,
        error: 'Invalid batch format',
        details: validation.error.format(),
      });
    }

    const batch: UXTelemetryBatch = validation.data;

    // Validate batch size
    if (batch.events.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Batch is empty',
      });
    }

    if (batch.events.length > 100) {
      return res.status(400).json({
        success: false,
        error: 'Batch too large (max 100 events)',
      });
    }

    logInfo(`[UX Telemetry] Received batch: ${batch.batchId} (${batch.events.length} events)`);

    // Insert batch (includes PII redaction)
    const result = await insertUXTelemetryBatch(batch.events);

    return res.status(result.success ? 200 : 207).json({
      success: result.success,
      inserted: result.inserted,
      failed: result.failed,
      errors: result.errors,
      batchId: batch.batchId,
    });
  } catch (error: any) {
    logError('[UX Telemetry] Error processing batch', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
      message: error.message,
    });
  }
});

/**
 * GET /api/ux-telemetry/session/:sessionId
 *
 * Get events for a specific session (user journey analysis).
 */
router.get('/session/:sessionId', async (req, res) => {
  try {
    const { sessionId } = req.params;
    const limit = parseInt(req.query.limit as string) || 100;

    if (!sessionId || sessionId.length < 10) {
      return res.status(400).json({
        success: false,
        error: 'Invalid session ID',
      });
    }

    const events = await getEventsBySession(sessionId, limit);

    if (!events) {
      return res.status(500).json({
        success: false,
        error: 'Failed to fetch events',
      });
    }

    return res.json({
      success: true,
      sessionId,
      events,
      count: events.length,
    });
  } catch (error: any) {
    logError('[UX Telemetry] Error fetching session events', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * GET /api/ux-telemetry/category/:category
 *
 * Get events by category (for LLM observer pattern detection).
 */
router.get('/category/:category', async (req, res) => {
  try {
    const { category } = req.params;
    const hours = parseInt(req.query.hours as string) || 24;
    const limit = parseInt(req.query.limit as string) || 1000;

    // Validate category
    if (!Object.values(UXEventCategory).includes(category as UXEventCategory)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid category',
        validCategories: Object.values(UXEventCategory),
      });
    }

    const events = await getEventsByCategory(category as UXEventCategory, hours, limit);

    if (!events) {
      return res.status(500).json({
        success: false,
        error: 'Failed to fetch events',
      });
    }

    return res.json({
      success: true,
      category,
      hours,
      events,
      count: events.length,
    });
  } catch (error: any) {
    logError('[UX Telemetry] Error fetching category events', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * GET /api/ux-telemetry/summary/recent
 *
 * Get recent events summary (for dashboards).
 */
router.get('/summary/recent', async (req, res) => {
  try {
    const hours = parseInt(req.query.hours as string) || 24;

    const summary = await getRecentSummary(hours);

    if (!summary) {
      return res.status(500).json({
        success: false,
        error: 'Failed to fetch summary',
      });
    }

    return res.json({
      success: true,
      hours,
      summary,
    });
  } catch (error: any) {
    logError('[UX Telemetry] Error fetching recent summary', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * GET /api/ux-telemetry/summary/categories
 *
 * Get category summary (for LLM observer).
 */
router.get('/summary/categories', async (req, res) => {
  try {
    const summary = await getCategorySummary();

    if (!summary) {
      return res.status(500).json({
        success: false,
        error: 'Failed to fetch summary',
      });
    }

    return res.json({
      success: true,
      summary,
    });
  } catch (error: any) {
    logError('[UX Telemetry] Error fetching category summary', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * GET /api/ux-telemetry/export/:userId
 *
 * Export user's UX telemetry (GDPR compliance).
 */
router.get('/export/:userId', authMiddleware, async (req: AuthenticatedRequest, res) => {
  try {
    const { userId } = req.params;
    const authenticatedUserId = req.user?.userId;

    // Ensure user can only export their own data
    if (authenticatedUserId !== userId) {
      return res.status(403).json({
        success: false,
        error: 'Forbidden: You can only export your own telemetry data',
      });
    }

    const events = await exportUserTelemetry(userId);

    if (!events) {
      return res.status(500).json({
        success: false,
        error: 'Failed to export telemetry',
      });
    }

    return res.json({
      success: true,
      userId,
      events,
      count: events.length,
      exportedAt: new Date().toISOString(),
    });
  } catch (error: any) {
    logError('[UX Telemetry] Error exporting user telemetry', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * DELETE /api/ux-telemetry/user/:userId
 *
 * Delete user's UX telemetry (GDPR compliance).
 */
router.delete('/user/:userId', authMiddleware, async (req: AuthenticatedRequest, res) => {
  try {
    const { userId } = req.params;
    const authenticatedUserId = req.user?.userId;

    // Ensure user can only delete their own data
    if (authenticatedUserId !== userId) {
      return res.status(403).json({
        success: false,
        error: 'Forbidden: You can only delete your own telemetry data',
      });
    }

    const deletedCount = await deleteUserTelemetry(userId);

    return res.json({
      success: true,
      userId,
      deletedCount,
      deletedAt: new Date().toISOString(),
    });
  } catch (error: any) {
    logError('[UX Telemetry] Error deleting user telemetry', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

export default router;
