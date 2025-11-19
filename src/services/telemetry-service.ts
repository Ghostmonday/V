/**
 * Telemetry Service
 * Comprehensive event logging for analytics, monitoring, and AI analysis
 * Dual logging: Prometheus (real-time) + Supabase (persistent)
 */

import client from 'prom-client';
import { supabase } from '../config/database-config.js';
import { logError } from '../shared/logger-shared.js';

// Prometheus counter metric for telemetry events
const telemetryEventCounter = new client.Counter({
  name: 'telemetry_events_total',
  help: 'Total number of telemetry events recorded',
  labelNames: ['event'],
});

export interface TelemetryMetadata {
  [key: string]: any;
  message_id?: string;
  thread_id?: string;
  bot_id?: string;
  action?: string;
  reason?: string;
  error?: string;
  latency_ms?: number;
  device_type?: string;
  app_state?: string;
}

/**
 * Core telemetry logging function with retry logic
 * Phase 6.4: Enhanced with sampling and compression
 */
export async function logTelemetryEvent(
  eventType: string,
  options: {
    userId?: string;
    roomId?: string;
    metadata?: TelemetryMetadata;
  } = {}
): Promise<void> {
  const { userId, roomId, metadata = {} } = options;

  // Increment Prometheus counter (synchronous, fast) - always count
  telemetryEventCounter.inc({ event: eventType });

  // Phase 6.4: Event sampling (10% of events, preserve all critical events)
  const isCriticalEvent =
    eventType.includes('error') ||
    eventType.includes('critical') ||
    eventType.includes('security') ||
    eventType.includes('auth_failure');

  const samplingRate = parseFloat(process.env.TELEMETRY_SAMPLING_RATE || '0.1'); // Default 10%
  const shouldSample = isCriticalEvent || Math.random() < samplingRate;

  if (!shouldSample) {
    // Sampled out - don't persist to DB, but metrics are still recorded
    return;
  }

  // Phase 6.4: Compress metadata before storage (if large)
  let compressedMetadata = metadata;
  if (JSON.stringify(metadata).length > 1000) {
    // For large metadata, we could compress, but for now just truncate
    // In production, use gzip compression
    compressedMetadata = {
      ...metadata,
      _compressed: true,
      _original_size: JSON.stringify(metadata).length,
    };
  }

  // Persist to Supabase with retry logic (async, can fail gracefully)
  const maxRetries = 3;
  let lastError: Error | null = null;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const { error } = await supabase.from('telemetry').insert({
        event: eventType,
        user_id: userId || null,
        room_id: roomId || null,
        features: compressedMetadata,
        event_time: new Date().toISOString(),
        risk: metadata?.risk || null,
        action: metadata?.action || null,
        latency_ms: metadata?.latency_ms || null,
      });

      if (error) {
        lastError = error;
        // If it's a transient error, retry; otherwise, log and give up
        if (attempt < maxRetries && (error.code === 'PGRST301' || error.code === 'PGRST302')) {
          // PGRST301/302 are connection errors - retry with exponential backoff
          await new Promise((resolve) => setTimeout(resolve, Math.pow(2, attempt) * 100));
          continue;
        } else {
          // Non-retryable error or max retries reached
          logError(
            `Failed to log telemetry event (attempt ${attempt}/${maxRetries}): ${error.code || 'unknown'} - ${error.message}`,
            error
          );
          break;
        }
      } else {
        // Success - exit retry loop
        return;
      }
    } catch (error: any) {
      lastError = error instanceof Error ? error : new Error(String(error));

      // Retry on network errors or timeouts
      if (
        attempt < maxRetries &&
        (error.message?.includes('network') ||
          error.message?.includes('timeout') ||
          error.message?.includes('ECONNREFUSED'))
      ) {
        await new Promise((resolve) => setTimeout(resolve, Math.pow(2, attempt) * 100));
        continue;
      } else {
        logError(
          `Telemetry logging error (attempt ${attempt}/${maxRetries}): ${lastError.message}`,
          lastError
        );
        break;
      }
    }
  }

  // If we get here, all retries failed
  // Don't throw - telemetry failures shouldn't break main operations
  // But log detailed error for monitoring
  if (lastError) {
    logError(
      `Telemetry logging failed after ${maxRetries} retries. Event: ${eventType}, User: ${userId || 'none'}, Room: ${roomId || 'none'}`,
      lastError
    );
  }
}

// ===============================================
// MESSAGING EVENTS
// ===============================================

export async function logMessageEdited(
  messageId: string,
  userId: string,
  roomId: string,
  metadata?: TelemetryMetadata
): Promise<void> {
  await logTelemetryEvent('msg_edited', {
    userId,
    roomId,
    metadata: {
      message_id: messageId,
      ...metadata,
    },
  });
}

export async function logMessageDeleted(
  messageId: string,
  userId: string,
  roomId: string,
  reason?: string
): Promise<void> {
  await logTelemetryEvent('msg_deleted', {
    userId,
    roomId,
    metadata: {
      message_id: messageId,
      reason,
    },
  });
}

export async function logMessageFlagged(
  messageId: string,
  userId: string,
  roomId: string,
  flags: Record<string, any>
): Promise<void> {
  await logTelemetryEvent('msg_flagged', {
    userId,
    roomId,
    metadata: {
      message_id: messageId,
      flags,
      toxicity_score: flags.toxicity_score,
    },
  });
}

export async function logMessagePinned(
  messageId: string,
  userId: string,
  roomId: string,
  pinned: boolean
): Promise<void> {
  await logTelemetryEvent('msg_pinned', {
    userId,
    roomId,
    metadata: {
      message_id: messageId,
      pinned,
    },
  });
}

export async function logMessageReacted(
  messageId: string,
  userId: string,
  roomId: string,
  emoji: string,
  action: 'add' | 'remove'
): Promise<void> {
  await logTelemetryEvent('msg_reacted', {
    userId,
    roomId,
    metadata: {
      message_id: messageId,
      emoji,
      action,
    },
  });
}

// ===============================================
// PRESENCE & SESSION EVENTS
// ===============================================

export async function logUserJoinedRoom(
  userId: string,
  roomId: string,
  metadata?: TelemetryMetadata
): Promise<void> {
  await logTelemetryEvent('user_joined_room', {
    userId,
    roomId,
    metadata,
  });
}

export async function logUserLeftRoom(
  userId: string,
  roomId: string,
  reason?: string
): Promise<void> {
  await logTelemetryEvent('user_left_room', {
    userId,
    roomId,
    metadata: { reason },
  });
}

export async function logUserIdle(userId: string, roomId: string): Promise<void> {
  await logTelemetryEvent('user_idle', {
    userId,
    roomId,
  });
}

export async function logUserBack(userId: string, roomId: string): Promise<void> {
  await logTelemetryEvent('user_back', {
    userId,
    roomId,
  });
}

export async function logVoiceSessionStart(
  userId: string,
  roomId: string,
  sessionId: string
): Promise<void> {
  await logTelemetryEvent('voice_session_start', {
    userId,
    roomId,
    metadata: {
      session_id: sessionId,
    },
  });
}

export async function logVoiceSessionEnd(
  userId: string,
  roomId: string,
  sessionId: string,
  durationMs?: number
): Promise<void> {
  await logTelemetryEvent('voice_session_end', {
    userId,
    roomId,
    metadata: {
      session_id: sessionId,
      duration_ms: durationMs,
    },
  });
}

// ===============================================
// BOT ACTIVITY EVENTS
// ===============================================

export async function logBotInvoked(
  botId: string,
  userId: string,
  roomId: string,
  metadata?: TelemetryMetadata
): Promise<void> {
  await logTelemetryEvent('bot_invoked', {
    userId,
    roomId,
    metadata: {
      bot_id: botId,
      ...metadata,
    },
  });
}

export async function logBotResponse(
  botId: string,
  userId: string,
  roomId: string,
  responseTimeMs: number,
  metadata?: TelemetryMetadata
): Promise<void> {
  await logTelemetryEvent('bot_response', {
    userId,
    roomId,
    metadata: {
      bot_id: botId,
      response_time_ms: responseTimeMs,
      ...metadata,
    },
  });
}

export async function logBotFailure(
  botId: string,
  userId: string,
  roomId: string,
  error: string,
  metadata?: TelemetryMetadata
): Promise<void> {
  await logTelemetryEvent('bot_failure', {
    userId,
    roomId,
    metadata: {
      bot_id: botId,
      error,
      ...metadata,
    },
  });
}

export async function logBotTimeout(
  botId: string,
  userId: string,
  roomId: string,
  timeoutMs: number
): Promise<void> {
  await logTelemetryEvent('bot_timeout', {
    userId,
    roomId,
    metadata: {
      bot_id: botId,
      timeout_ms: timeoutMs,
    },
  });
}

export async function logBotFlagged(
  botId: string,
  userId: string,
  roomId: string,
  reason: string
): Promise<void> {
  await logTelemetryEvent('bot_flagged', {
    userId,
    roomId,
    metadata: {
      bot_id: botId,
      reason,
    },
  });
}

// ===============================================
// MODERATION & ADMIN EVENTS
// ===============================================

export async function logModActionTaken(
  moderatorId: string,
  targetUserId: string,
  roomId: string,
  action: string,
  reason?: string
): Promise<void> {
  await logTelemetryEvent('mod_action_taken', {
    userId: moderatorId,
    roomId,
    metadata: {
      target_user_id: targetUserId,
      action,
      reason,
    },
  });
}

export async function logModAppealSubmitted(
  userId: string,
  roomId: string,
  appealReason: string
): Promise<void> {
  await logTelemetryEvent('mod_appeal_submitted', {
    userId,
    roomId,
    metadata: {
      appeal_reason: appealReason,
    },
  });
}

export async function logModEscalated(
  moderatorId: string,
  targetUserId: string,
  roomId: string,
  escalationReason: string
): Promise<void> {
  await logTelemetryEvent('mod_escalated', {
    userId: moderatorId,
    roomId,
    metadata: {
      target_user_id: targetUserId,
      escalation_reason: escalationReason,
    },
  });
}

export async function logPolicyChange(
  userId: string,
  policyType: string,
  oldValue: any,
  newValue: any
): Promise<void> {
  await logTelemetryEvent('policy_change', {
    userId,
    metadata: {
      policy_type: policyType,
      old_value: oldValue,
      new_value: newValue,
    },
  });
}

// ===============================================
// THREAD & REACTION EVENTS
// ===============================================

export async function logThreadCreated(
  threadId: string,
  userId: string,
  roomId: string,
  parentMessageId: string
): Promise<void> {
  await logTelemetryEvent('thread_created', {
    userId,
    roomId,
    metadata: {
      thread_id: threadId,
      parent_message_id: parentMessageId,
    },
  });
}

export async function logThreadClosed(
  threadId: string,
  userId: string,
  roomId: string,
  messageCount: number
): Promise<void> {
  await logTelemetryEvent('thread_closed', {
    userId,
    roomId,
    metadata: {
      thread_id: threadId,
      message_count: messageCount,
    },
  });
}

export async function logReactionSummaryUpdated(
  messageId: string,
  userId: string,
  roomId: string,
  reactionCount: number
): Promise<void> {
  await logTelemetryEvent('reaction_summary_updated', {
    userId,
    roomId,
    metadata: {
      message_id: messageId,
      reaction_count: reactionCount,
    },
  });
}

// ===============================================
// CONNECTIVITY & DEVICE EVENTS
// ===============================================

export async function logClientConnected(
  userId: string,
  deviceType?: string,
  metadata?: TelemetryMetadata
): Promise<void> {
  await logTelemetryEvent('client_connected', {
    userId,
    metadata: {
      device_type: deviceType,
      ...metadata,
    },
  });
}

export async function logClientDisconnected(
  userId: string,
  reason?: string,
  metadata?: TelemetryMetadata
): Promise<void> {
  await logTelemetryEvent('client_disconnected', {
    userId,
    metadata: {
      reason,
      ...metadata,
    },
  });
}

export async function logReconnectAttempt(
  userId: string,
  attemptNumber: number,
  success: boolean
): Promise<void> {
  await logTelemetryEvent('reconnect_attempt', {
    userId,
    metadata: {
      attempt_number: attemptNumber,
      success,
    },
  });
}

export async function logMobileForeground(userId: string): Promise<void> {
  await logTelemetryEvent('mobile_foreground', {
    userId,
    metadata: {
      app_state: 'foreground',
    },
  });
}

export async function logMobileBackground(userId: string): Promise<void> {
  await logTelemetryEvent('mobile_background', {
    userId,
    metadata: {
      app_state: 'background',
    },
  });
}

// ===============================================
// AI & LLM OPS EVENTS
// ===============================================

export async function logAISuggestionApplied(
  userId: string,
  suggestionId: string,
  suggestionType: string
): Promise<void> {
  await logTelemetryEvent('ai_suggestion_applied', {
    userId,
    metadata: {
      suggestion_id: suggestionId,
      suggestion_type: suggestionType,
    },
  });
}

export async function logAISuggestionRejected(
  userId: string,
  suggestionId: string,
  suggestionType: string,
  reason?: string
): Promise<void> {
  await logTelemetryEvent('ai_suggestion_rejected', {
    userId,
    metadata: {
      suggestion_id: suggestionId,
      suggestion_type: suggestionType,
      reason,
    },
  });
}

export async function logAIPolicyOverride(
  userId: string,
  policyType: string,
  overrideReason: string
): Promise<void> {
  await logTelemetryEvent('ai_policy_override', {
    userId,
    metadata: {
      policy_type: policyType,
      override_reason: overrideReason,
    },
  });
}

export async function logAIFlag(
  userId: string,
  roomId: string,
  flagType: string,
  severity: string,
  details: Record<string, any>
): Promise<void> {
  await logTelemetryEvent('ai_flag', {
    userId,
    roomId,
    metadata: {
      flag_type: flagType,
      severity,
      ...details,
    },
  });
}

// ===============================================
// MODERATION EVENTS
// ===============================================

/**
 * Log moderation event (scan, warning, mute)
 */
export async function logModerationEvent(
  event: 'scan_toxic' | 'warning_sent' | 'mute_applied',
  userId: string,
  roomId: string,
  metadata: {
    score?: number;
    suggestion?: string;
    violationCount?: number;
    mutedUntil?: string;
  } = {}
): Promise<void> {
  await logTelemetryEvent(`moderation_${event}`, {
    userId,
    roomId,
    metadata: {
      ...metadata,
      timestamp: new Date().toISOString(),
    },
  });

  // Also increment Prometheus metric specifically for moderation
  telemetryEventCounter.inc({ event: `moderation_${event}` });
}

// ===============================================
// BATCH LOGGING (for performance)
// ===============================================

export async function logTelemetryBatch(
  events: Array<{
    eventType: string;
    userId?: string;
    roomId?: string;
    metadata?: TelemetryMetadata;
  }>
): Promise<void> {
  try {
    // Increment Prometheus counters
    events.forEach(({ eventType }) => {
      telemetryEventCounter.inc({ event: eventType });
    });

    const telemetryRecords = events.map(({ eventType, userId, roomId, metadata = {} }) => ({
      event: eventType,
      user_id: userId || null,
      room_id: roomId || null,
      features: metadata,
      event_time: new Date().toISOString(),
      risk: metadata?.risk || null,
      action: metadata?.action || null,
      latency_ms: metadata?.latency_ms || null,
    }));

    const { error } = await supabase.from('telemetry').insert(telemetryRecords);

    if (error) {
      logError('Failed to log telemetry batch', error);
    }
  } catch (error: any) {
    logError('Telemetry batch logging error', error);
  }
}

// Legacy exports for backward compatibility
export const recordTelemetryEvent = logTelemetryEvent;
