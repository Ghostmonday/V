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

/**
 * Calculate time remaining until claim deadline
 */
export function getTimeRemaining(deadline: Date | null): number | null {
  if (!deadline) return null;
  const now = new Date();
  const remaining = deadline.getTime() - now.getTime();
  return Math.max(0, remaining);
}

/**
 * Format time remaining as human-readable string
 */
export function formatTimeRemaining(ms: number | null): string {
  if (ms === null) return 'No deadline';
  if (ms <= 0) return 'Expired';
  
  const minutes = Math.floor(ms / 60000);
  const seconds = Math.floor((ms % 60000) / 1000);
  
  if (minutes > 0) {
    return `${minutes}m ${seconds}s`;
  }
  return `${seconds}s`;
}

/**
 * Validate card metadata structure
 */
export function validateCardMetadata(metadata: any): boolean {
  if (!metadata || typeof metadata !== 'object') return false;
  
  // Check required fields
  const required = ['timestamp', 'participants', 'sentiment_tags'];
  return required.every(field => field in metadata);
}
