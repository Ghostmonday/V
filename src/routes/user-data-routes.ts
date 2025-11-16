/**
 * User Data Routes
 * GDPR/CCPA compliance endpoints for user data export and deletion
 */

import { Router, Request, Response } from 'express';
import { authMiddleware } from '../middleware/auth.js';
import { AuthenticatedRequest } from '../types/auth.types.js';
import { supabase } from '../config/db.ts';
import { logError, logInfo, logAudit } from '../shared/logger.js';
import { rateLimit } from '../middleware/rate-limiter.js';
import { decryptField } from '../services/encryption-service.js';

const router = Router();

// Rate limiting: 10 requests per hour for data export/deletion
router.use(rateLimit({ max: 10, windowMs: 60 * 60 * 1000 }));

/**
 * GET /api/users/:id/data
 * Export all user data (GDPR right to access)
 */
router.get('/:id/data', authMiddleware, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { id } = req.params;
    const authenticatedUserId = req.user?.userId;

    // Ensure user can only export their own data
    if (authenticatedUserId !== id) {
      return res.status(403).json({
        success: false,
        error: 'Forbidden: You can only export your own data',
      });
    }

    // Collect all user data
    const userData: Record<string, any> = {
      userId: id,
      exportedAt: new Date().toISOString(),
      profile: null,
      messages: [],
      rooms: [],
      memberships: [],
      files: [],
      subscriptions: [],
      telemetry: null,
      auditLogs: [],
    };

    // Get user profile
    const { data: user, error: userError } = await supabase
      .from('users')
      .select('*')
      .eq('id', id)
      .single();

    if (userError) {
      logError('Failed to fetch user profile', userError);
    } else if (user) {
      // Decrypt sensitive fields
      const decryptedUser = { ...user };
      if (user.email) {
        try {
          decryptedUser.email = await decryptField(user.email);
        } catch {
          decryptedUser.email = '[encrypted]';
        }
      }
      userData.profile = decryptedUser;
    }

    // Get user messages
    const { data: messages } = await supabase
      .from('messages')
      .select('id, room_id, content, created_at, updated_at')
      .eq('sender_id', id)
      .order('created_at', { ascending: false })
      .limit(1000); // Limit to recent 1000 messages

    if (messages) {
      userData.messages = messages;
    }

    // Get rooms created by user
    const { data: rooms } = await supabase
      .from('rooms')
      .select('id, name, is_public, created_at, updated_at')
      .eq('created_by', id)
      .order('created_at', { ascending: false });

    if (rooms) {
      userData.rooms = rooms;
    }

    // Get room memberships
    const { data: memberships } = await supabase
      .from('room_memberships')
      .select('room_id, role, nickname, joined_at')
      .eq('user_id', id)
      .order('joined_at', { ascending: false });

    if (memberships) {
      userData.memberships = memberships;
    }

    // Get files uploaded by user
    const { data: files } = await supabase
      .from('files')
      .select('id, filename, mime_type, size, created_at')
      .eq('user_id', id)
      .order('created_at', { ascending: false });

    if (files) {
      userData.files = files;
    }

    // Get subscriptions
    const { data: subscriptions } = await supabase
      .from('subscriptions')
      .select('tier, status, created_at, expires_at')
      .eq('user_id', id)
      .order('created_at', { ascending: false });

    if (subscriptions) {
      userData.subscriptions = subscriptions;
    }

    // Get UX telemetry (already has export function)
    try {
      const { exportUserTelemetry } = await import('../services/ux-telemetry-service.js');
      const telemetry = await exportUserTelemetry(id);
      if (telemetry) {
        userData.telemetry = telemetry;
      }
    } catch (error: any) {
      logError('Failed to export telemetry', error);
    }

    // Get audit logs (user's own actions)
    const { data: auditLogs } = await supabase
      .from('audit_log')
      .select('event_type, metadata, created_at')
      .eq('user_id', id)
      .order('created_at', { ascending: false })
      .limit(500);

    if (auditLogs) {
      userData.auditLogs = auditLogs;
    }

    // Log export event
    await logAudit('user_data_exported', id, {
      exportedAt: userData.exportedAt,
      messageCount: userData.messages.length,
      roomCount: userData.rooms.length,
    });

    res.json({
      success: true,
      data: userData,
    });
  } catch (error: any) {
    logError('Failed to export user data', error);
    res.status(500).json({
      success: false,
      error: 'Failed to export user data',
    });
  }
});

/**
 * DELETE /api/users/:id/data
 * Delete all user data (GDPR right to erasure)
 */
router.delete('/:id/data', authMiddleware, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { id } = req.params;
    const authenticatedUserId = req.user?.userId;

    // Ensure user can only delete their own data
    if (authenticatedUserId !== id) {
      return res.status(403).json({
        success: false,
        error: 'Forbidden: You can only delete your own data',
      });
    }

    // Log deletion request
    await logAudit('user_data_deletion_requested', id, {
      requestedAt: new Date().toISOString(),
    });

    // Delete user data in order (respecting foreign key constraints)
    const deletionResults: Record<string, number> = {};

    // Delete messages (soft delete: anonymize instead of hard delete for data integrity)
    const { count: messageCount } = await supabase
      .from('messages')
      .update({ 
        sender_id: '00000000-0000-0000-0000-000000000000', // System/anonymous user
        content: '[deleted]',
      })
      .eq('sender_id', id);

    deletionResults.messages = messageCount || 0;

    // Delete room memberships
    const { count: membershipCount } = await supabase
      .from('room_memberships')
      .delete()
      .eq('user_id', id);

    deletionResults.memberships = membershipCount || 0;

    // Delete files (metadata only - actual files may remain in storage)
    const { count: fileCount } = await supabase
      .from('files')
      .delete()
      .eq('user_id', id);

    deletionResults.files = fileCount || 0;

    // Delete subscriptions
    const { count: subscriptionCount } = await supabase
      .from('subscriptions')
      .delete()
      .eq('user_id', id);

    deletionResults.subscriptions = subscriptionCount || 0;

    // Delete UX telemetry
    try {
      const { deleteUserTelemetry } = await import('../services/ux-telemetry-service.js');
      const telemetryDeleted = await deleteUserTelemetry(id);
      deletionResults.telemetry = telemetryDeleted;
    } catch (error: any) {
      logError('Failed to delete telemetry', error);
      deletionResults.telemetry = 0;
    }

    // Anonymize user profile (don't delete for referential integrity)
    const { error: userError } = await supabase
      .from('users')
      .update({
        email: `deleted_${id}@deleted.local`,
        metadata: { deleted: true, deletedAt: new Date().toISOString() },
      })
      .eq('id', id);

    if (userError) {
      logError('Failed to anonymize user', userError);
    }

    // Log deletion completion
    await logAudit('user_data_deleted', id, {
      deletedAt: new Date().toISOString(),
      deletionResults,
    });

    logInfo(`User data deleted for user ${id}`, { deletionResults });

    res.json({
      success: true,
      userId: id,
      deletedAt: new Date().toISOString(),
      deletionResults,
      note: 'User profile anonymized. Some data may be retained for legal/compliance purposes.',
    });
  } catch (error: any) {
    logError('Failed to delete user data', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete user data',
    });
  }
});

/**
 * POST /api/users/:id/consent
 * Update user consent preferences (GDPR consent management)
 */
router.post('/:id/consent', authMiddleware, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { id } = req.params;
    const authenticatedUserId = req.user?.userId;
    const { marketing, analytics, required } = req.body;

    // Ensure user can only update their own consent
    if (authenticatedUserId !== id) {
      return res.status(403).json({
        success: false,
        error: 'Forbidden: You can only update your own consent',
      });
    }

    // Update consent preferences
    const { error } = await supabase
      .from('users')
      .update({
        metadata: {
          consent: {
            marketing: marketing ?? false,
            analytics: analytics ?? false,
            required: required ?? true, // Required consent cannot be false
            updatedAt: new Date().toISOString(),
          },
        },
      })
      .eq('id', id);

    if (error) {
      throw error;
    }

    // Log consent update
    await logAudit('user_consent_updated', id, {
      marketing,
      analytics,
      required,
      updatedAt: new Date().toISOString(),
    });

    res.json({
      success: true,
      userId: id,
      consent: {
        marketing,
        analytics,
        required,
      },
    });
  } catch (error: any) {
    logError('Failed to update consent', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update consent preferences',
    });
  }
});

export default router;

