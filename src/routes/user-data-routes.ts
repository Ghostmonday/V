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
      conversations: [],
      conversationParticipants: [],
      boosts: [],
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

    // Get conversations created by user
    const { data: conversations } = await supabase
      .from('conversations')
      .select('id, created_at, updated_at, last_message_at, message_count, is_group, metadata')
      .eq('created_by', id)
      .order('created_at', { ascending: false });

    if (conversations) {
      userData.conversations = conversations;
    }

    // Get conversation participants
    const { data: conversationParticipants } = await supabase
      .from('conversation_participants')
      .select('conversation_id, joined_at, last_read_at')
      .eq('user_id', id)
      .order('joined_at', { ascending: false });

    if (conversationParticipants) {
      userData.conversationParticipants = conversationParticipants;
    }


    // Get boosts/transactions
    const { data: boosts } = await supabase
      .from('boosts')
      .select('id, conversation_id, boost_type, amount_paid, payment_provider, payment_id, metadata, created_at')
      .eq('user_id', id)
      .order('created_at', { ascending: false });

    if (boosts) {
      userData.boosts = boosts;
    }

    // Log export event
    await logAudit('user_data_exported', id, {
      exportedAt: userData.exportedAt,
      messageCount: userData.messages.length,
      roomCount: userData.rooms.length,
      conversationCount: userData.conversations.length,
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
 * Uses soft delete with retention period for compliance
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

    // Use soft delete service with retention period
    const { softDeleteUserData } = await import('../services/data-deletion-service.js');
    const result = await softDeleteUserData(id, 'user_request');

    if (!result.success) {
      logError('Soft delete had errors', new Error(result.errors.join('; ')));
    }

    res.json({
      success: result.success,
      userId: id,
      deletedAt: new Date().toISOString(),
      retentionUntil: result.retentionUntil,
      errors: result.errors,
      note: 'Your data has been soft-deleted and will be permanently removed after the retention period. Some anonymized data may be retained for legal/compliance purposes.',
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
 * Stores consent records with audit trail
 */
router.post('/:id/consent', authMiddleware, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { id } = req.params;
    const authenticatedUserId = req.user?.userId;
    const { marketing, analytics, required, cookies, third_party, consent_version } = req.body;
    const ipAddress = req.ip || req.socket.remoteAddress || 'unknown';
    const userAgent = req.get('user-agent') || 'unknown';

    // Ensure user can only update their own consent
    if (authenticatedUserId !== id) {
      return res.status(403).json({
        success: false,
        error: 'Forbidden: You can only update your own consent',
      });
    }

    const consentVersion = consent_version || '1.0';
    const consentRecords: Array<{ consent_type: string; granted: boolean }> = [];

    // Create consent records for each consent type
    if (marketing !== undefined) {
      consentRecords.push({ consent_type: 'marketing', granted: marketing });
    }
    if (analytics !== undefined) {
      consentRecords.push({ consent_type: 'analytics', granted: analytics });
    }
    if (required !== undefined) {
      consentRecords.push({ consent_type: 'required', granted: required });
    }
    if (cookies !== undefined) {
      consentRecords.push({ consent_type: 'cookies', granted: cookies });
    }
    if (third_party !== undefined) {
      consentRecords.push({ consent_type: 'third_party', granted: third_party });
    }

    // Insert consent records
    const recordsToInsert = consentRecords.map(record => ({
      user_id: id,
      consent_type: record.consent_type,
      granted: record.granted,
      consent_version: consentVersion,
      ip_address: ipAddress,
      user_agent: userAgent,
      metadata: {
        updatedAt: new Date().toISOString(),
      },
    }));

    const { error: consentError } = await supabase
      .from('consent_records')
      .insert(recordsToInsert);

    if (consentError) {
      throw consentError;
    }

    // Also update user metadata for backward compatibility
    const { error: userError } = await supabase
      .from('users')
      .update({
        metadata: {
          consent: {
            marketing: marketing ?? false,
            analytics: analytics ?? false,
            required: required ?? true, // Required consent cannot be false
            cookies: cookies ?? false,
            third_party: third_party ?? false,
            updatedAt: new Date().toISOString(),
            consentVersion,
          },
        },
      })
      .eq('id', id);

    if (userError) {
      logError('Failed to update user metadata', userError);
    }

    // Log consent update
    await logAudit('user_consent_updated', id, {
      marketing,
      analytics,
      required,
      cookies,
      third_party,
      consentVersion,
      updatedAt: new Date().toISOString(),
    });

    res.json({
      success: true,
      userId: id,
      consent: {
        marketing,
        analytics,
        required,
        cookies,
        third_party,
      },
      consentVersion,
    });
  } catch (error: any) {
    logError('Failed to update consent', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update consent preferences',
    });
  }
});

/**
 * GET /api/users/:id/consent
 * Get user consent history (GDPR consent management)
 */
router.get('/:id/consent', authMiddleware, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { id } = req.params;
    const authenticatedUserId = req.user?.userId;

    // Ensure user can only view their own consent
    if (authenticatedUserId !== id) {
      return res.status(403).json({
        success: false,
        error: 'Forbidden: You can only view your own consent records',
      });
    }

    // Get consent records
    const { data: consentRecords, error } = await supabase
      .from('consent_records')
      .select('*')
      .eq('user_id', id)
      .order('created_at', { ascending: false });

    if (error) {
      throw error;
    }

    // Get current consent from user metadata
    const { data: user } = await supabase
      .from('users')
      .select('metadata')
      .eq('id', id)
      .single();

    res.json({
      success: true,
      userId: id,
      currentConsent: user?.metadata?.consent || null,
      consentHistory: consentRecords || [],
    });
  } catch (error: any) {
    logError('Failed to get consent records', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get consent records',
    });
  }
});

/**
 * DELETE /api/users/:id/consent/:type
 * Withdraw consent (GDPR consent management)
 */
router.delete('/:id/consent/:type', authMiddleware, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { id, type } = req.params;
    const authenticatedUserId = req.user?.userId;

    // Ensure user can only withdraw their own consent
    if (authenticatedUserId !== id) {
      return res.status(403).json({
        success: false,
        error: 'Forbidden: You can only withdraw your own consent',
      });
    }

    // Required consent cannot be withdrawn
    if (type === 'required') {
      return res.status(400).json({
        success: false,
        error: 'Required consent cannot be withdrawn',
      });
    }

    // Mark consent as withdrawn
    const { error } = await supabase
      .from('consent_records')
      .update({
        withdrawn_at: new Date().toISOString(),
        granted: false,
      })
      .eq('user_id', id)
      .eq('consent_type', type)
      .is('withdrawn_at', null); // Only update if not already withdrawn

    if (error) {
      throw error;
    }

    // Update user metadata
    const { data: user } = await supabase
      .from('users')
      .select('metadata')
      .eq('id', id)
      .single();

    if (user?.metadata?.consent) {
      const updatedConsent = {
        ...user.metadata.consent,
        [type]: false,
        withdrawnAt: new Date().toISOString(),
      };

      await supabase
        .from('users')
        .update({
          metadata: {
            ...user.metadata,
            consent: updatedConsent,
          },
        })
        .eq('id', id);
    }

    // Log consent withdrawal
    await logAudit('user_consent_withdrawn', id, {
      consentType: type,
      withdrawnAt: new Date().toISOString(),
    });

    res.json({
      success: true,
      userId: id,
      consentType: type,
      withdrawnAt: new Date().toISOString(),
    });
  } catch (error: any) {
    logError('Failed to withdraw consent', error);
    res.status(500).json({
      success: false,
      error: 'Failed to withdraw consent',
    });
  }
});

export default router;

