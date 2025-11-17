/**
 * VIBES Rarity Engine
 * Calculates rarity tiers based on sentiment and conversation dynamics
 */

import { SentimentAnalysis } from './sentiment-service.js';
import { ConversationParticipant } from './conversation-service.js';
import { VIBES_CONSTANTS } from './constants.js';

export type RarityTier = 'common' | 'uncommon' | 'rare' | 'epic' | 'legendary';

export interface RarityCalculation {
  base_rarity: RarityTier;
  multipliers: {
    identity: number;      // Celebrity/unusual pairing
    dynamics: number;      // Emotional intensity
    voice: number;         // Voice message bonus
    group_size: number;    // Group conversation bonus
    surprise: number;      // Surprise factor
  };
  final_score: number;
  final_tier: RarityTier;
}

/**
 * Calculate rarity for a conversation
 */
export function calculateRarity(
  sentiment: SentimentAnalysis,
  participants: ConversationParticipant[],
  messageTypes: Array<{ type: string }>,
  participantMetadata?: Array<{ user_id: string; is_celebrity?: boolean }>
): RarityCalculation {
  // Base rarity from sentiment score
  const baseScore = (sentiment.sentiment_score + 1) / 2; // Normalize -1 to 1 -> 0 to 1
  const baseRarity = scoreToRarity(baseScore);

  // Calculate multipliers
  const identityMultiplier = calculateIdentityMultiplier(participants, participantMetadata);
  const dynamicsMultiplier = sentiment.emotional_intensity;
  const voiceMultiplier = calculateVoiceMultiplier(messageTypes);
  const groupSizeMultiplier = calculateGroupSizeMultiplier(participants.length);
  const surpriseMultiplier = sentiment.surprise_factor;

  // Final score calculation
  const multipliers = {
    identity: identityMultiplier,
    dynamics: dynamicsMultiplier,
    voice: voiceMultiplier,
    group_size: groupSizeMultiplier,
    surprise: surpriseMultiplier,
  };

  const finalScore = baseScore * 
    (1 + identityMultiplier) *
    (1 + dynamicsMultiplier) *
    (1 + voiceMultiplier) *
    (1 + groupSizeMultiplier) *
    (1 + surpriseMultiplier);

  const finalTier = scoreToRarity(Math.min(finalScore, 1));

  return {
    base_rarity: baseRarity,
    multipliers,
    final_score: finalScore,
    final_tier: finalTier,
  };
}

/**
 * Convert score (0-1) to rarity tier
 */
function scoreToRarity(score: number): RarityTier {
  const { RARITY_THRESHOLDS } = VIBES_CONSTANTS;
  if (score >= RARITY_THRESHOLDS.LEGENDARY) return 'legendary';
  if (score >= RARITY_THRESHOLDS.EPIC) return 'epic';
  if (score >= RARITY_THRESHOLDS.RARE) return 'rare';
  if (score >= RARITY_THRESHOLDS.UNCOMMON) return 'uncommon';
  return 'common';
}

/**
 * Calculate identity multiplier (celebrity/unusual pairings)
 */
function calculateIdentityMultiplier(
  participants: ConversationParticipant[],
  metadata?: Array<{ user_id: string; is_celebrity?: boolean }>
): number {
  if (!metadata || participants.length < 2) return 0;

  const celebrityCount = participants.filter(p => 
    metadata.find(m => m.user_id === p.user_id && m.is_celebrity)
  ).length;

  // Celebrity multiplier
  if (celebrityCount > 0) {
    return Math.min(0.5 * celebrityCount, VIBES_CONSTANTS.MAX_IDENTITY_MULTIPLIER);
  }

  // Unusual pairing (different user types, etc.)
  // Placeholder: could check user metadata for unusual combinations
  return 0;
}

/**
 * Calculate voice message multiplier
 */
function calculateVoiceMultiplier(messageTypes: Array<{ type: string }>): number {
  const voiceCount = messageTypes.filter(m => m.type === 'voice').length;
  const totalCount = messageTypes.length;
  
  if (totalCount === 0) return 0;
  
  const voiceRatio = voiceCount / totalCount;
  return Math.min(voiceRatio * 0.3, VIBES_CONSTANTS.MAX_VOICE_MULTIPLIER);
}

/**
 * Calculate group size multiplier
 */
function calculateGroupSizeMultiplier(participantCount: number): number {
  if (participantCount <= 2) return 0;
  
  // Larger groups = rarer (diminishing returns)
  if (participantCount >= 10) return Math.min(0.5, VIBES_CONSTANTS.MAX_GROUP_SIZE_MULTIPLIER);
  if (participantCount >= 5) return 0.3;  // 30% boost for 5-9
  return 0.1; // 10% boost for 3-4
}
