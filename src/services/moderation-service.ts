/**
 * Moderation Service
 * AI-powered content moderation using DeepSeek API
 * Enterprise-only feature for room-level moderation
 * Opt-in only: Warnings first, mutes after repeat violations (no auto-bans)
 */

import axios from 'axios';
import { logError, logWarning, logInfo } from '../shared/logger-shared.js';
import { supabase } from '../config/database-config.js';
import { logModerationEvent } from './telemetry-service.js';
import { sanitizePrompt, logPromptAudit } from '../utils/prompt-sanitizer-utils.js';
import { getDeepSeekKey } from './api-keys-service.js';
import { analyzeWithPerspective, getModerationThresholds } from './perspective-api-service.js';

/**
 * Scan message for toxicity using Perspective API (primary) and DeepSeek (fallback)
 * Returns score, isToxic flag, and suggestion text
 * Uses configurable thresholds from system config
 */
export async function scanForToxicity(
  content: string,
  roomId: string,
  messageId?: string,
  userId?: string
): Promise<{ score: number; isToxic: boolean; suggestion: string }> {
  try {
    // Get configurable thresholds (with room-specific override if available)
    const thresholds = await getModerationThresholds(roomId);
    const warnThreshold = thresholds.warn; // Default: 0.6
    const blockThreshold = thresholds.block; // Default: 0.8

    // Try Perspective API first (more reliable for toxicity detection)
    const perspectiveResult = await analyzeWithPerspective(content);

    if (perspectiveResult) {
      // Use Perspective API result
      const score = perspectiveResult.toxicity;
      const isBlocked = score >= blockThreshold;

      // Generate suggestion based on severity
      let suggestion = 'Please keep conversations respectful';
      if (isBlocked) {
        suggestion = 'This message violates our community guidelines. Please revise.';
      } else if (score >= warnThreshold) {
        suggestion = 'This message may be inappropriate. Please be respectful.';
      }

      // Auto-flag messages above warn threshold
      if (score >= warnThreshold && messageId && userId) {
        const { flagMessage } = await import('./message-flagging-service.js');
        await flagMessage(
          messageId,
          roomId,
          userId,
          'toxicity',
          score,
          null, // null = system flag
          {
            source: 'perspective_api',
            perspectiveScores: {
              toxicity: perspectiveResult.toxicity,
              severeToxicity: perspectiveResult.severeToxicity,
              identityAttack: perspectiveResult.identityAttack,
              insult: perspectiveResult.insult,
              profanity: perspectiveResult.profanity,
              threat: perspectiveResult.threat,
            },
          }
        );
      }

      return {
        score,
        isToxic: isBlocked, // Block only at blockThreshold (0.8)
        suggestion,
      };
    }

    // Fallback to DeepSeek if Perspective API unavailable
    const deepseekKey = await getDeepSeekKey();
    if (!deepseekKey) {
      logWarning('No moderation API keys found - moderation disabled');
      return { score: 0, isToxic: false, suggestion: '' };
    }

    // Sanitize prompt before sending to LLM
    const sanitizedContent = sanitizePrompt(content);

    // Log prompt audit
    await logPromptAudit(roomId, sanitizedContent, 'moderation_scan', { roomId });

    const prompt = `Analyze this message for toxicity, hate speech, or spam: ${sanitizedContent}
Respond with JSON only: {"score": 0-1, "isToxic": true/false, "suggestion": "brief warning text"}`;

    // Use Supabase Edge Function proxy instead of direct API call
    const { getSupabaseKeys } = await import('./api-keys-service.js');
    const supabaseKeys = await getSupabaseKeys();
    const supabaseUrl = supabaseKeys.url;
    const supabaseAnonKey = supabaseKeys.anonKey;

    // Get JWT token for Supabase auth (from room context or system token)
    // For now, use anon key - in production, use service role or user JWT
    const response = await axios.post(
      `${supabaseUrl}/functions/v1/llm-proxy`,
      {
        prompt,
        model: 'deepseek-chat',
        intent: 'moderation_scan',
      },
      {
        headers: {
          Authorization: `Bearer ${supabaseAnonKey}`,
          'Content-Type': 'application/json',
        },
      }
    );

    // Edge Function returns DeepSeek response directly
    const raw =
      response.data?.choices?.[0]?.message?.content?.trim() ||
      '{"score":0,"isToxic":false,"suggestion":""}';

    // Parse JSON response
    let result;
    try {
      result = JSON.parse(raw);
    } catch {
      // Fallback: try to extract JSON from markdown or text
      const jsonMatch = raw.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        result = JSON.parse(jsonMatch[0]);
      } else {
        throw new Error('Invalid JSON response');
      }
    }

    const score = Math.max(0, Math.min(1, parseFloat(result.score) || 0));

    // Use configurable thresholds for DeepSeek results too
    const isToxic = score >= blockThreshold; // Block at higher threshold

    // Auto-flag messages above warn threshold
    if (score >= warnThreshold && messageId && userId) {
      const { flagMessage } = await import('./message-flagging-service.js');
      await flagMessage(
        messageId,
        roomId,
        userId,
        'toxicity',
        score,
        null, // null = system flag
        { source: 'deepseek_moderation' }
      );
    }

    const suggestion = result.suggestion || 'Please keep conversations respectful';

    return { score, isToxic, suggestion };
  } catch (error: any) {
    logError('Moderation scan failed', error);
    // Fail-safe: return safe if API fails
    return { score: 0, isToxic: false, suggestion: '' };
  }
}

/**
 * Handle moderation violation: warnings first, then mutes after repeat violations
 * No auto-bans - keeps it light
 */
export async function handleViolation(
  userId: string,
  roomId: string,
  suggestion: string,
  violationCount: number
): Promise<void> {
  try {
    // Get current violation count for this user in this room
    const { data: violations } = await supabase
      .from('message_violations')
      .select('count')
      .eq('user_id', userId)
      .eq('room_id', roomId)
      .single();

    const count = violations?.count || 0;

    if (count === 0) {
      // First violation: Send warning DM
      // Find or create DM room with system user
      const { data: dmRoom } = await supabase
        .from('rooms')
        .select('id')
        .eq('created_by', userId)
        .eq('is_public', false)
        .limit(1)
        .single();

      const targetRoomId = dmRoom?.id || roomId; // Fallback to original room if no DM

      await supabase.from('messages').insert({
        room_id: targetRoomId,
        sender_id: 'system', // System user ID - adjust if you have a specific system user UUID
        content: `Hey, chill - ${suggestion}. Next one's a timeout.`,
      });

      // Log violation
      await supabase.from('message_violations').upsert(
        {
          user_id: userId,
          room_id: roomId,
          count: 1,
        },
        {
          onConflict: 'user_id,room_id',
        }
      );

      // Log telemetry event
      await logModerationEvent('warning_sent', userId, roomId, {
        suggestion,
        violationCount: 1,
      });

      logInfo(`Warning sent to user ${userId} in room ${roomId}`);
    } else if (count >= 2) {
      // 2+ violations: Auto-mute for 1 hour
      const mutedUntil = new Date(Date.now() + 3600000).toISOString(); // 1 hour

      await supabase.from('user_mutes').upsert(
        {
          user_id: userId,
          room_id: roomId,
          muted_until: mutedUntil,
        },
        {
          onConflict: 'user_id,room_id',
        }
      );

      // Increment violation count
      await supabase
        .from('message_violations')
        .update({ count: count + 1 })
        .eq('user_id', userId)
        .eq('room_id', roomId);

      // Log telemetry event
      await logModerationEvent('mute_applied', userId, roomId, {
        violationCount: count + 1,
        mutedUntil,
      });

      logInfo(`User ${userId} muted in room ${roomId} until ${mutedUntil}`);
    } else {
      // Second violation: Increment count
      await supabase
        .from('message_violations')
        .update({ count: count + 1 })
        .eq('user_id', userId)
        .eq('room_id', roomId);
    }
  } catch (err: any) {
    logError('Error handling violation', err);
  }
}

/**
 * Check if user is muted in a room
 */
export async function isUserMuted(userId: string, roomId: string): Promise<boolean> {
  try {
    const { data } = await supabase
      .from('user_mutes')
      .select('muted_until')
      .eq('user_id', userId)
      .eq('room_id', roomId)
      .single();

    if (!data || !data.muted_until) return false;

    const mutedUntil = new Date(data.muted_until);
    const now = new Date();

    if (now > mutedUntil) {
      // Mute expired, clean it up
      await supabase.from('user_mutes').delete().eq('user_id', userId).eq('room_id', roomId);
      return false;
    }

    return true;
  } catch {
    return false;
  }
}

/**
 * Get room configuration including moderation settings
 */
export async function getRoomById(roomId: string): Promise<{
  id: string;
  ai_moderation: boolean;
  room_tier: string;
  expires_at?: string | null;
} | null> {
  try {
    const { data, error } = await supabase
      .from('rooms')
      .select('id, ai_moderation, room_tier, expires_at')
      .eq('id', roomId)
      .single();

    if (error || !data) {
      logError('Failed to fetch room', error);
      return null;
    }

    return {
      id: data.id,
      ai_moderation: data.ai_moderation || false,
      room_tier: data.room_tier || 'free',
      expires_at: data.expires_at,
    };
  } catch (err: any) {
    logError('Error fetching room', err);
    return null;
  }
}

/**
 * Analyze message content for toxicity (legacy compatibility)
 * @deprecated Use scanForToxicity instead
 */
export async function analyzeMessage(
  content: string
): Promise<{ score: number; label: 'safe' | 'toxic' }> {
  const result = await scanForToxicity(content, '');
  return {
    score: result.score,
    label: result.isToxic ? 'toxic' : 'safe',
  };
}

/**
 * Log moderation flag to database (legacy compatibility)
 */
export async function logFlag(
  roomId: string,
  userId: string,
  messageId: string | null,
  score: number,
  action: string
): Promise<void> {
  try {
    const { error } = await supabase.from('moderation_flags').insert({
      room_id: roomId,
      user_id: userId,
      message_id: messageId,
      score,
      label: score > 0.7 ? 'toxic' : 'safe',
      action_taken: action,
    });

    if (error) {
      logError('Failed to log moderation flag', error);
    } else {
      logInfo(
        `Moderation flag logged: room=${roomId}, action=${action}, score=${score.toFixed(2)}`
      );
    }
  } catch (err: any) {
    logError('Error logging moderation flag', err);
  }
}
