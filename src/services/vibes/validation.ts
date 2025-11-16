/**
 * VIBES Data Validation
 * Input validation for VIBES operations
 */

import { RarityTier } from '../types/vibes.types.js';

/**
 * Validate conversation ID format
 */
export function isValidConversationId(id: string): boolean {
  // UUID format validation
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  return uuidRegex.test(id);
}

/**
 * Validate card ID format
 */
export function isValidCardId(id: string): boolean {
  return isValidConversationId(id); // Same format
}

/**
 * Validate rarity tier
 */
export function isValidRarityTier(tier: string): tier is RarityTier {
  return ['common', 'uncommon', 'rare', 'epic', 'legendary'].includes(tier);
}

/**
 * Validate participant IDs array
 */
export function validateParticipantIds(ids: string[]): { valid: boolean; error?: string } {
  if (!Array.isArray(ids)) {
    return { valid: false, error: 'participant_ids must be an array' };
  }

  if (ids.length === 0) {
    return { valid: false, error: 'At least one participant required' };
  }

  if (ids.length > 100) {
    return { valid: false, error: 'Maximum 100 participants' };
  }

  for (const id of ids) {
    if (!isValidConversationId(id)) {
      return { valid: false, error: `Invalid participant ID: ${id}` };
    }
  }

  return { valid: true };
}

/**
 * Validate claim deadline
 */
export function validateClaimDeadline(deadline: Date): { valid: boolean; error?: string } {
  const now = new Date();
  const minDeadline = new Date(now.getTime() + 60000); // At least 1 minute
  const maxDeadline = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000); // Max 7 days

  if (deadline < minDeadline) {
    return { valid: false, error: 'Deadline must be at least 1 minute in the future' };
  }

  if (deadline > maxDeadline) {
    return { valid: false, error: 'Deadline cannot be more than 7 days in the future' };
  }

  return { valid: true };
}

/**
 * Sanitize card title
 */
export function sanitizeCardTitle(title: string): string {
  return title
    .trim()
    .slice(0, 100) // Max 100 chars
    .replace(/[<>]/g, ''); // Remove HTML brackets
}

/**
 * Sanitize card caption
 */
export function sanitizeCardCaption(caption: string): string {
  return caption
    .trim()
    .slice(0, 500) // Max 500 chars
    .replace(/[<>]/g, ''); // Remove HTML brackets
}
