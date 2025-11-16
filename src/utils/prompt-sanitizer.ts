/**
 * Prompt Sanitizer
 * Strips HTML, escapes backticks, caps at 4k tokens
 * Hashes and logs to audit_logs table
 */

import { supabase } from '../config/db.js';
import { logError, logInfo } from '../shared/logger.js';

const MAX_TOKENS = 4000;
const CHARS_PER_TOKEN = 4; // Rough estimate
const MAX_CHARS = MAX_TOKENS * CHARS_PER_TOKEN; // ~16k chars

/**
 * Sanitize prompt: strip HTML, escape backticks, cap at 4k tokens
 */
export function sanitizePrompt(prompt: string): string {
  if (!prompt || typeof prompt !== 'string') {
    return '';
  }

  // Remove HTML tags
  let sanitized = prompt.replace(/<[^>]*>/g, '');

  // Escape backticks (prevent code injection)
  sanitized = sanitized.replace(/`/g, '\\`');

  // Remove script tags and event handlers
  sanitized = sanitized.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
  sanitized = sanitized.replace(/on\w+\s*=\s*["'][^"']*["']/gi, '');

  // Cap at 4k tokens (roughly 16k chars)
  if (sanitized.length > MAX_CHARS) {
    sanitized = sanitized.substring(0, MAX_CHARS);
    logWarning('Prompt truncated to 4k tokens');
  }

  return sanitized.trim();
}

/**
 * Hash prompt for audit logging (SHA-256)
 */
export async function hashPrompt(prompt: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(prompt);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

/**
 * Log prompt to audit_logs table
 */
export async function logPromptAudit(
  userId: string,
  prompt: string,
  intent: string = 'unknown',
  metadata: Record<string, any> = {}
): Promise<void> {
  try {
    const sanitized = sanitizePrompt(prompt);
    const promptHash = await hashPrompt(sanitized);

    await supabase.from('audit_logs').insert({
      user_id: userId,
      action: 'llm_prompt',
      timestamp: new Date().toISOString(),
      metadata: {
        prompt_hash: promptHash,
        prompt_length: sanitized.length,
        intent,
        ...metadata,
      },
    });

    logInfo(`Prompt audit logged: user=${userId}, hash=${promptHash.substring(0, 8)}...`);
  } catch (error: any) {
    logError('Failed to log prompt audit', error);
    // Don't throw - audit logging shouldn't break main flow
  }
}

