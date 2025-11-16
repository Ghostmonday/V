/**
 * UX Telemetry Service
 * 
 * Service layer for storing and querying UX telemetry events.
 * Completely separate from system/infra telemetry.
 * 
 * @module ux-telemetry-service
 */

import { supabase } from '../config/db.js';
import { logError, logInfo } from '../shared/logger.js';
import type { UXTelemetryEvent, UXEventCategory } from '../types/ux-telemetry.js';
import { redactUXTelemetryEvent, redactUXTelemetryBatch } from './ux-telemetry-redaction.js';

/**
 * Insert a single UX telemetry event
 * Samples 10% of events to reduce DB writes while maintaining signal quality
 */
export async function insertUXTelemetryEvent(
  event: UXTelemetryEvent
): Promise<{ success: boolean; error?: string }> {
  try {
    // Sample 10% of events (90% reduction in DB writes)
    if (Math.random() >= 0.1) {
      return { success: true }; // Sampled out - return success without DB write
    }
    
    // Redact PII (server-side safety net)
    const { event: redactedEvent, stats } = redactUXTelemetryEvent(event);
    
    // Insert into database
    const { error } = await supabase.from('ux_telemetry').insert({
      trace_id: redactedEvent.traceId,
      session_id: redactedEvent.sessionId,
      event_type: redactedEvent.eventType,
      category: redactedEvent.category,
      component_id: redactedEvent.componentId || null,
      state_before: redactedEvent.stateBefore || null,
      state_after: redactedEvent.stateAfter || null,
      metadata: redactedEvent.metadata,
      device_context: redactedEvent.deviceContext || null,
      sampling_flag: redactedEvent.samplingFlag,
      user_id: redactedEvent.userId || null,
      room_id: redactedEvent.roomId || null,
      event_time: redactedEvent.timestamp,
    });
    
    if (error) {
      logError('[UX Telemetry] Failed to insert event', error);
      return { success: false, error: error.message };
    }
    
    if (stats.wasModified) {
      logInfo(`[UX Telemetry] Event inserted with PII redaction: ${redactedEvent.eventType}`);
    }
    
    return { success: true };
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    logError('[UX Telemetry] Error inserting event', error instanceof Error ? error : new Error(String(error)));
    return { success: false, error: errorMessage };
  }
}

/**
 * Insert a batch of UX telemetry events
 * Samples 10% of events to reduce DB writes while maintaining signal quality
 */
export async function insertUXTelemetryBatch(
  events: UXTelemetryEvent[]
): Promise<{
  success: boolean;
  inserted: number;
  failed: number;
  errors: string[];
}> {
  try {
    // Sample 10% of events (90% reduction in DB writes)
    const sampledEvents = events.filter(() => Math.random() < 0.1);
    
    if (sampledEvents.length === 0) {
      return {
        success: true,
        inserted: 0,
        failed: 0,
        errors: [],
      };
    }
    
    // Redact PII from batch
    const { events: redactedEvents, stats } = redactUXTelemetryBatch(sampledEvents);
    
    if (stats.wasModified) {
      logInfo(
        `[UX Telemetry] Batch redaction: ${stats.fieldsRedacted} fields, ` +
        `${stats.totalPiiInstances} PII instances removed`
      );
    }
    
    // Transform events for database
    const dbEvents = redactedEvents.map(event => ({
      trace_id: event.traceId,
      session_id: event.sessionId,
      event_type: event.eventType,
      category: event.category,
      component_id: event.componentId || null,
      state_before: event.stateBefore || null,
      state_after: event.stateAfter || null,
      metadata: event.metadata,
      device_context: event.deviceContext || null,
      sampling_flag: event.samplingFlag,
      user_id: event.userId || null,
      room_id: event.roomId || null,
      event_time: event.timestamp,
    }));
    
    // Batch insert
    const { data, error } = await supabase
      .from('ux_telemetry')
      .insert(dbEvents)
      .select('id');
    
    if (error) {
      logError('[UX Telemetry] Failed to insert batch', error);
      return {
        success: false,
        inserted: 0,
        failed: events.length,
        errors: [error.message],
      };
    }
    
    const inserted = data?.length || 0;
    const failed = sampledEvents.length - inserted;
    
    logInfo(`[UX Telemetry] Batch inserted: ${inserted} events (sampled from ${events.length}), ${failed} failed`);
    
    return {
      success: failed === 0,
      inserted,
      failed,
      errors: failed > 0 ? ['Some events failed to insert'] : [],
    };
  } catch (error: unknown) {
    const errorObj = error instanceof Error ? error : new Error(String(error));
    logError('[UX Telemetry] Error inserting batch', errorObj);
    return {
      success: false,
      inserted: 0,
      failed: sampledEvents.length,
      errors: [errorObj.message || 'Unknown error'],
    };
  }
}

/**
 * Get events by session ID (for user journey analysis)
 */
export async function getEventsBySession(
  sessionId: string,
  limit: number = 100
): Promise<UXTelemetryEvent[] | null> {
  try {
    const { data, error } = await supabase
      .from('ux_telemetry')
      .select('*')
      .eq('session_id', sessionId)
      .order('event_time', { ascending: true })
      .limit(limit);
    
    if (error) {
      logError('[UX Telemetry] Error fetching events by session', error);
      return null;
    }
    
    // Transform database records to UXTelemetryEvent format
    return (data || []).map(transformDbToEvent);
  } catch (error) {
    logError('[UX Telemetry] Error in getEventsBySession', error);
    return null;
  }
}

/**
 * Get events by category (for LLM observer pattern detection)
 */
export async function getEventsByCategory(
  category: UXEventCategory,
  hours: number = 24,
  limit: number = 1000
): Promise<UXTelemetryEvent[] | null> {
  try {
    const since = new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();
    
    const { data, error } = await supabase
      .from('ux_telemetry')
      .select('*')
      .eq('category', category)
      .gte('event_time', since)
      .order('event_time', { ascending: false })
      .limit(limit);
    
    if (error) {
      logError('[UX Telemetry] Error fetching events by category', error);
      return null;
    }
    
    return (data || []).map(transformDbToEvent);
  } catch (error) {
    logError('[UX Telemetry] Error in getEventsByCategory', error);
    return null;
  }
}

/**
 * Get events by trace ID (for correlating with backend traces)
 */
export async function getEventsByTrace(
  traceId: string,
  limit: number = 100
): Promise<UXTelemetryEvent[] | null> {
  try {
    const { data, error } = await supabase
      .from('ux_telemetry')
      .select('*')
      .eq('trace_id', traceId)
      .order('event_time', { ascending: true })
      .limit(limit);
    
    if (error) {
      logError('[UX Telemetry] Error fetching events by trace', error);
      return null;
    }
    
    return (data || []).map(transformDbToEvent);
  } catch (error) {
    logError('[UX Telemetry] Error in getEventsByTrace', error);
    return null;
  }
}

/**
 * Get events by user ID
 */
export async function getEventsByUser(
  userId: string,
  hours: number = 24,
  limit: number = 1000
): Promise<UXTelemetryEvent[] | null> {
  try {
    const since = new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();
    
    const { data, error } = await supabase
      .from('ux_telemetry')
      .select('*')
      .eq('user_id', userId)
      .gte('event_time', since)
      .order('event_time', { ascending: false })
      .limit(limit);
    
    if (error) {
      logError('[UX Telemetry] Error fetching events by user', error);
      return null;
    }
    
    return (data || []).map(transformDbToEvent);
  } catch (error) {
    logError('[UX Telemetry] Error in getEventsByUser', error);
    return null;
  }
}

/**
 * Get recent events summary
 */
export async function getRecentSummary(hours: number = 24): Promise<any[] | null> {
  try {
    const since = new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();
    
    const { data, error } = await supabase.rpc('get_ux_recent_summary', {
      p_hours: hours,
    });
    
    if (error) {
      // Fallback to manual query if RPC doesn't exist
      const { data: viewData, error: viewError } = await supabase
        .from('ux_telemetry_recent_summary')
        .select('*');
      
      if (viewError) {
        logError('[UX Telemetry] Error fetching recent summary', viewError);
        return null;
      }
      
      return viewData;
    }
    
    return data;
  } catch (error) {
    logError('[UX Telemetry] Error in getRecentSummary', error);
    return null;
  }
}

/**
 * Get category summary (for LLM observer)
 */
export async function getCategorySummary(): Promise<any[] | null> {
  try {
    const { data, error } = await supabase
      .from('ux_telemetry_category_summary')
      .select('*');
    
    if (error) {
      logError('[UX Telemetry] Error fetching category summary', error);
      return null;
    }
    
    return data;
  } catch (error) {
    logError('[UX Telemetry] Error in getCategorySummary', error);
    return null;
  }
}

/**
 * Get AI feedback events (suggestions, auto-fixes, help requests)
 */
export async function getAIFeedbackEvents(
  hours: number = 24,
  limit: number = 1000
): Promise<UXTelemetryEvent[] | null> {
  try {
    const since = new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();
    
    const { data, error } = await supabase
      .from('ux_telemetry')
      .select('*')
      .eq('category', 'ai_feedback')
      .gte('event_time', since)
      .order('event_time', { ascending: false })
      .limit(limit);
    
    if (error) {
      logError('[UX Telemetry] Error fetching AI feedback events', error);
      return null;
    }
    
    return (data || []).map(transformDbToEvent);
  } catch (error) {
    logError('[UX Telemetry] Error in getAIFeedbackEvents', error);
    return null;
  }
}

/**
 * Get emotional/cognitive state events (sentiment, emotion curves)
 */
export async function getEmotionalEvents(
  sessionId?: string,
  hours: number = 24,
  limit: number = 1000
): Promise<UXTelemetryEvent[] | null> {
  try {
    const since = new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();
    
    let query = supabase
      .from('ux_telemetry')
      .select('*')
      .eq('category', 'cognitive_state')
      .gte('event_time', since);
    
    if (sessionId) {
      query = query.eq('session_id', sessionId);
    }
    
    const { data, error } = await query
      .order('event_time', { ascending: true })
      .limit(limit);
    
    if (error) {
      logError('[UX Telemetry] Error fetching emotional events', error);
      return null;
    }
    
    return (data || []).map(transformDbToEvent);
  } catch (error) {
    logError('[UX Telemetry] Error in getEmotionalEvents', error);
    return null;
  }
}

/**
 * Get journey analytics events (funnels, dropoffs, sequences)
 */
export async function getJourneyEvents(
  sessionId?: string,
  hours: number = 24,
  limit: number = 1000
): Promise<UXTelemetryEvent[] | null> {
  try {
    const since = new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();
    
    let query = supabase
      .from('ux_telemetry')
      .select('*')
      .eq('category', 'journey_analytics')
      .gte('event_time', since);
    
    if (sessionId) {
      query = query.eq('session_id', sessionId);
    }
    
    const { data, error } = await query
      .order('event_time', { ascending: true })
      .limit(limit);
    
    if (error) {
      logError('[UX Telemetry] Error fetching journey events', error);
      return null;
    }
    
    return (data || []).map(transformDbToEvent);
  } catch (error) {
    logError('[UX Telemetry] Error in getJourneyEvents', error);
    return null;
  }
}

/**
 * Get performance events (load times, latency, stutters)
 */
export async function getPerformanceEvents(
  hours: number = 24,
  limit: number = 1000
): Promise<UXTelemetryEvent[] | null> {
  try {
    const since = new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();
    
    const { data, error } = await supabase
      .from('ux_telemetry')
      .select('*')
      .eq('category', 'performance')
      .gte('event_time', since)
      .order('event_time', { ascending: false })
      .limit(limit);
    
    if (error) {
      logError('[UX Telemetry] Error fetching performance events', error);
      return null;
    }
    
    return (data || []).map(transformDbToEvent);
  } catch (error) {
    logError('[UX Telemetry] Error in getPerformanceEvents', error);
    return null;
  }
}

/**
 * Get behavior modeling events (bursts, stalls, retries)
 */
export async function getBehaviorEvents(
  hours: number = 24,
  limit: number = 1000
): Promise<UXTelemetryEvent[] | null> {
  try {
    const since = new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();
    
    const { data, error } = await supabase
      .from('ux_telemetry')
      .select('*')
      .eq('category', 'behavior_modeling')
      .gte('event_time', since)
      .order('event_time', { ascending: false })
      .limit(limit);
    
    if (error) {
      logError('[UX Telemetry] Error fetching behavior events', error);
      return null;
    }
    
    return (data || []).map(transformDbToEvent);
  } catch (error) {
    logError('[UX Telemetry] Error in getBehaviorEvents', error);
    return null;
  }
}

/**
 * Aggregate AI suggestion metrics
 */
export async function getAISuggestionMetrics(hours: number = 168): Promise<{
  totalSuggestions: number;
  accepted: number;
  rejected: number;
  acceptanceRate: number;
} | null> {
  try {
    const events = await getAIFeedbackEvents(hours);
    if (!events) return null;
    
    const accepted = events.filter(e => e.eventType === 'ai_suggestion_accepted').length;
    const rejected = events.filter(e => e.eventType === 'ai_suggestion_rejected').length;
    const totalSuggestions = accepted + rejected;
    
    return {
      totalSuggestions,
      accepted,
      rejected,
      acceptanceRate: totalSuggestions > 0 ? accepted / totalSuggestions : 0,
    };
  } catch (error) {
    logError('[UX Telemetry] Error in getAISuggestionMetrics', error);
    return null;
  }
}

/**
 * Aggregate sentiment metrics
 */
export async function getSentimentMetrics(hours: number = 168): Promise<{
  avgSentiment: number;
  volatility: number;
  positiveTrend: boolean;
} | null> {
  try {
    const events = await getEmotionalEvents(undefined, hours);
    if (!events) return null;
    
    const sentimentEvents = events.filter(
      e => e.eventType === 'message_sentiment_before' || e.eventType === 'message_sentiment_after'
    );
    
    const scores = sentimentEvents
      .map(e => (e.metadata as any).sentimentScore)
      .filter(s => typeof s === 'number');
    
    if (scores.length === 0) return null;
    
    const avgSentiment = scores.reduce((a, b) => a + b, 0) / scores.length;
    const variance = scores.reduce((sum, score) => sum + Math.pow(score - avgSentiment, 2), 0) / scores.length;
    const volatility = Math.sqrt(variance);
    
    // Check if trend is positive (last 25% vs first 25%)
    const quarterSize = Math.floor(scores.length / 4);
    const firstQuarter = scores.slice(0, quarterSize);
    const lastQuarter = scores.slice(-quarterSize);
    const positiveTrend = 
      lastQuarter.reduce((a, b) => a + b, 0) / lastQuarter.length > 
      firstQuarter.reduce((a, b) => a + b, 0) / firstQuarter.length;
    
    return {
      avgSentiment,
      volatility,
      positiveTrend,
    };
  } catch (error) {
    logError('[UX Telemetry] Error in getSentimentMetrics', error);
    return null;
  }
}

/**
 * Aggregate funnel completion metrics
 */
export async function getFunnelMetrics(hours: number = 168): Promise<{
  totalCheckpoints: number;
  totalDropoffs: number;
  completionRate: number;
} | null> {
  try {
    const events = await getJourneyEvents(undefined, hours);
    if (!events) return null;
    
    const checkpoints = events.filter(e => e.eventType === 'funnel_checkpoint_hit').length;
    const dropoffs = events.filter(e => e.eventType === 'dropoff_point_detected').length;
    const total = checkpoints + dropoffs;
    
    return {
      totalCheckpoints: checkpoints,
      totalDropoffs: dropoffs,
      completionRate: total > 0 ? checkpoints / total : 0,
    };
  } catch (error) {
    logError('[UX Telemetry] Error in getFunnelMetrics', error);
    return null;
  }
}

/**
 * Aggregate performance metrics
 */
export async function getPerformanceMetrics(hours: number = 24): Promise<{
  avgLoadTime: number;
  avgInteractionLatency: number;
  stutterRate: number;
  longStateCount: number;
} | null> {
  try {
    const events = await getPerformanceEvents(hours);
    if (!events) return null;
    
    const loadTimeEvents = events.filter(e => e.eventType === 'load_time_perceived_vs_actual');
    const latencyEvents = events.filter(e => e.eventType === 'interaction_latency_ms');
    const stutterEvents = events.filter(e => e.eventType === 'stuttered_input');
    const longStateEvents = events.filter(e => e.eventType === 'long_state_without_progress');
    
    const avgLoadTime = loadTimeEvents.length > 0
      ? loadTimeEvents.reduce((sum, e) => sum + ((e.metadata as any).actualMs || 0), 0) / loadTimeEvents.length
      : 0;
    
    const avgInteractionLatency = latencyEvents.length > 0
      ? latencyEvents.reduce((sum, e) => sum + ((e.metadata as any).duration || 0), 0) / latencyEvents.length
      : 0;
    
    return {
      avgLoadTime,
      avgInteractionLatency,
      stutterRate: stutterEvents.length / events.length,
      longStateCount: longStateEvents.length,
    };
  } catch (error) {
    logError('[UX Telemetry] Error in getPerformanceMetrics', error);
    return null;
  }
}

/**
 * Delete user's UX telemetry (GDPR compliance)
 */
export async function deleteUserTelemetry(userId: string): Promise<number> {
  try {
    const { data, error } = await supabase.rpc('delete_user_ux_telemetry', {
      p_user_id: userId,
    });
    
    if (error) {
      logError('[UX Telemetry] Error deleting user telemetry', error);
      return 0;
    }
    
    const deletedCount = data || 0;
    logInfo(`[UX Telemetry] Deleted ${deletedCount} events for user ${userId}`);
    
    return deletedCount;
  } catch (error) {
    logError('[UX Telemetry] Error in deleteUserTelemetry', error);
    return 0;
  }
}

/**
 * Export user's UX telemetry (GDPR compliance)
 */
export async function exportUserTelemetry(
  userId: string
): Promise<UXTelemetryEvent[] | null> {
  try {
    const { data, error } = await supabase
      .from('ux_telemetry')
      .select('*')
      .eq('user_id', userId)
      .order('event_time', { ascending: true });
    
    if (error) {
      logError('[UX Telemetry] Error exporting user telemetry', error);
      return null;
    }
    
    return (data || []).map(transformDbToEvent);
  } catch (error) {
    logError('[UX Telemetry] Error in exportUserTelemetry', error);
    return null;
  }
}

/**
 * Transform database record to UXTelemetryEvent
 */
function transformDbToEvent(dbRecord: any): UXTelemetryEvent {
  return {
    traceId: dbRecord.trace_id,
    sessionId: dbRecord.session_id,
    eventType: dbRecord.event_type,
    category: dbRecord.category,
    timestamp: dbRecord.event_time,
    componentId: dbRecord.component_id,
    stateBefore: dbRecord.state_before,
    stateAfter: dbRecord.state_after,
    metadata: dbRecord.metadata || {},
    deviceContext: dbRecord.device_context,
    samplingFlag: dbRecord.sampling_flag,
    userId: dbRecord.user_id,
    roomId: dbRecord.room_id,
  };
}

