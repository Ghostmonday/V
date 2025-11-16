/**
 * Telemetry glue
 * Exports telemetry functions used across codebase
 * Maintains backward compatibility with existing telemetryHook usage
 */

import client from 'prom-client';
import { logTelemetryEvent } from '../services/telemetry-service.js';

// HTTP request counter for legacy compatibility
const httpRequestCounter = new client.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'path'],
});

/**
 * Legacy telemetryHook - maintains backward compatibility
 * Also logs to database via new telemetry service
 */
export function telemetryHook(event: string, metadata?: any) {
  // Legacy: Increment HTTP request counter for request_* events
  if (event.startsWith('request_')) {
    const parts = event.split('_');
    const method = parts[1] || 'UNKNOWN';
    const path = parts.slice(2).join('_') || '/';
    httpRequestCounter.inc({ method, path });
  }
  
  // New: Also log to database (async, non-blocking)
  logTelemetryEvent(event, { metadata }).catch(() => {
    // Silently fail - don't break existing code
  });
}

// Export all telemetry functions
export {
  logTelemetryEvent,
  recordTelemetryEvent,
  // Messaging events
  logMessageEdited,
  logMessageDeleted,
  logMessageFlagged,
  logMessagePinned,
  logMessageReacted,
  // Presence events
  logUserJoinedRoom,
  logUserLeftRoom,
  logUserIdle,
  logUserBack,
  logVoiceSessionStart,
  logVoiceSessionEnd,
  // Bot events
  logBotInvoked,
  logBotResponse,
  logBotFailure,
  logBotTimeout,
  logBotFlagged,
  // Moderation events
  logModActionTaken,
  logModAppealSubmitted,
  logModEscalated,
  logPolicyChange,
  // Thread events
  logThreadCreated,
  logThreadClosed,
  logReactionSummaryUpdated,
  // Connectivity events
  logClientConnected,
  logClientDisconnected,
  logReconnectAttempt,
  logMobileForeground,
  logMobileBackground,
  // AI events
  logAISuggestionApplied,
  logAISuggestionRejected,
  logAIPolicyOverride,
  logAIFlag,
  // Batch logging
  logTelemetryBatch,
} from '../services/telemetry-service.js';

