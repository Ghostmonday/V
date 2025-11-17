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

