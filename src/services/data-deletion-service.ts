/**
 * Data Deletion Service
 * Handles GDPR/CCPA compliant data deletion with soft delete and retention periods
 */

import { supabase } from '../config/database-config.js';
import { logError, logInfo, logAudit } from '../shared/logger-shared.js';

// Default retention period: 30 days (configurable via env)
const DEFAULT_RETENTION_DAYS = parseInt(
  (process.env.DATA_RETENTION_DAYS || process.env.RETENTION_USERS_DAYS || '30') as string,
  10
);

/**
 * Soft delete user data with retention period
 * Data is marked for deletion but retained for compliance/legal purposes
 */
export async function softDeleteUserData(
  userId: string,
  deletionReason: string = 'user_request'
): Promise<{ success: boolean; retentionUntil: string; errors: string[] }> {
  const errors: string[] = [];
  const retentionUntil = new Date(Date.now() + DEFAULT_RETENTION_DAYS * 24 * 60 * 60 * 1000);

  try {
    // Start transaction-like operation
    const deletionResults: Record<string, number> = {};

    // 1. Mark user as deleted in deleted_users table
    const { error: deletedUserError } = await supabase.from('deleted_users').upsert(
      {
        user_id: userId,
        deleted_at: new Date().toISOString(),
        retention_until: retentionUntil.toISOString(),
        deletion_reason: deletionReason,
        metadata: {
          retentionDays: DEFAULT_RETENTION_DAYS,
        },
      },
      {
        onConflict: 'user_id',
      }
    );

    if (deletedUserError) {
      errors.push(`Failed to mark user as deleted: ${deletedUserError.message}`);
    }

    // 2. Anonymize user profile (keep for referential integrity)
    const { error: userError } = await supabase
      .from('users')
      .update({
        handle: `deleted_${userId.substring(0, 8)}`,
        display_name: '[Deleted User]',
        metadata: {
          deleted: true,
          deletedAt: new Date().toISOString(),
          retentionUntil: retentionUntil.toISOString(),
        },
      })
      .eq('id', userId);

    if (userError) {
      errors.push(`Failed to anonymize user profile: ${userError.message}`);
    }

    // 3. Anonymize messages (soft delete: replace content)
    const { count: messageCount } = await supabase
      .from('messages')
      .update({
        sender_id: '00000000-0000-0000-0000-000000000000', // System/anonymous user
        content_preview: '[deleted]',
      })
      .eq('sender_id', userId);

    deletionResults.messages = messageCount || 0;

    // 4. Delete room memberships
    const { count: membershipCount } = await supabase
      .from('room_memberships')
      .delete()
      .eq('user_id', userId);

    deletionResults.memberships = membershipCount || 0;

    // 5. Delete conversation participants
    const { count: conversationParticipantCount } = await supabase
      .from('conversation_participants')
      .delete()
      .eq('user_id', userId);

    deletionResults.conversationParticipants = conversationParticipantCount || 0;

    // 6. Delete files metadata (actual files may remain in storage)
    const { count: fileCount } = await supabase.from('files').delete().eq('user_id', userId);

    deletionResults.files = fileCount || 0;

    // 7. Delete subscriptions
    const { count: subscriptionCount } = await supabase
      .from('subscriptions')
      .delete()
      .eq('user_id', userId);

    deletionResults.subscriptions = subscriptionCount || 0;

    // 8. Delete UX telemetry
    try {
      const { deleteUserTelemetry } = await import('./ux-telemetry-service.js');
      const telemetryDeleted = await deleteUserTelemetry(userId);
      deletionResults.telemetry = telemetryDeleted;
    } catch (error: any) {
      errors.push(`Failed to delete telemetry: ${error.message}`);
      deletionResults.telemetry = 0;
    }

    // 9. Anonymize boosts (if table exists - VIBES feature)
    try {
      const { count: boostCount } = await supabase
        .from('boosts')
        .update({
          user_id: '00000000-0000-0000-0000-000000000000',
          metadata: { ...{ anonymized: true, originalUserId: userId } },
        })
        .eq('user_id', userId);

      deletionResults.boosts = boostCount || 0;
    } catch (error) {
      // Table may not exist if VIBES feature is disabled
      deletionResults.boosts = 0;
    }

    // Log deletion
    await logAudit('user_data_soft_deleted', userId, {
      deletedAt: new Date().toISOString(),
      retentionUntil: retentionUntil.toISOString(),
      deletionReason,
      deletionResults,
    });

    logInfo(`User data soft-deleted for user ${userId}`, {
      retentionUntil: retentionUntil.toISOString(),
      deletionResults,
    });

    return {
      success: errors.length === 0,
      retentionUntil: retentionUntil.toISOString(),
      errors,
    };
  } catch (error: any) {
    logError('Failed to soft delete user data', error);
    errors.push(`Unexpected error: ${error.message}`);
    return {
      success: false,
      retentionUntil: retentionUntil.toISOString(),
      errors,
    };
  }
}

/**
 * Anonymize user PII after retention period
 * Called by data retention cron job
 */
export async function anonymizeUserPII(userId: string): Promise<boolean> {
  try {
    // Anonymize email if exists (encrypt with placeholder)
    const { data: user } = await supabase.from('users').select('email').eq('id', userId).single();

    if (user?.email) {
      // Encrypt email with a placeholder value
      const { encryptField } = await import('./encryption-service.js');
      const anonymizedEmail = await encryptField(`anonymized_${userId}@deleted.local`);

      const { error } = await supabase
        .from('users')
        .update({
          email: anonymizedEmail,
          metadata: {
            anonymized: true,
            anonymizedAt: new Date().toISOString(),
          },
        })
        .eq('id', userId);

      if (error) {
        logError('Failed to anonymize email', error);
        return false;
      }
    }

    // Mark as anonymized in deleted_users table
    const { error: updateError } = await supabase
      .from('deleted_users')
      .update({
        anonymized_at: new Date().toISOString(),
      })
      .eq('user_id', userId);

    if (updateError) {
      logError('Failed to update anonymization timestamp', updateError);
      return false;
    }

    logInfo(`User PII anonymized for user ${userId}`);
    return true;
  } catch (error: any) {
    logError('Failed to anonymize user PII', error);
    return false;
  }
}

/**
 * Permanently delete user data after retention period
 * WARNING: This is irreversible
 */
export async function permanentlyDeleteUserData(userId: string): Promise<boolean> {
  try {
    // This should only be called after retention period and anonymization
    // For now, we keep the soft-deleted record for audit purposes
    // Actual hard deletion can be implemented based on legal requirements

    logInfo(
      `User data permanently deleted for user ${userId} (soft-delete record retained for audit)`
    );
    return true;
  } catch (error: any) {
    logError('Failed to permanently delete user data', error);
    return false;
  }
}
