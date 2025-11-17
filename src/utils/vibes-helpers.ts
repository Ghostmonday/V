/**
 * VIBES Helper Utilities
 * Common functions for VIBES operations
 */

import { RarityTier } from '../types/vibes.types.js';

/**
 * Format rarity tier for display
 */
export function formatRarityTier(tier: RarityTier): string {
  const formats: Record<RarityTier, string> = {
    common: 'Common',
    uncommon: 'Uncommon',
    rare: 'Rare',
    epic: 'Epic',
    legendary: 'Legendary',
  };
  return formats[tier] || tier;
}

/**
 * Get rarity color (for UI)
 */
export function getRarityColor(tier: RarityTier): string {
  const colors: Record<RarityTier, string> = {
    common: '#9CA3AF',      // Gray
    uncommon: '#10B981',    // Green
    rare: '#3B82F6',        // Blue
    epic: '#8B5CF6',        // Purple
    legendary: '#F59E0B',   // Gold
  };
  return colors[tier] || colors.common;
}

