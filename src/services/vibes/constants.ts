/**
 * VIBES Constants
 * Configuration constants for VIBES system
 */

export const VIBES_CONSTANTS = {
  // Card Generation Thresholds
  MIN_MESSAGES_FOR_CARD: 5,
  MIN_PARTICIPANTS_FOR_CARD: 2,
  MAX_PARTICIPANTS_FOR_CARD: 100,

  // Claim Deadlines
  DEFAULT_CLAIM_DEADLINE_MINUTES: 15,
  MIN_CLAIM_DEADLINE_MINUTES: 1,
  MAX_CLAIM_DEADLINE_DAYS: 7,

  // Rarity Thresholds (0-1 score)
  RARITY_THRESHOLDS: {
    LEGENDARY: 0.95,
    EPIC: 0.85,
    RARE: 0.70,
    UNCOMMON: 0.50,
    COMMON: 0.0,
  },

  // Multiplier Caps
  MAX_IDENTITY_MULTIPLIER: 2.0, // 200% boost max
  MAX_DYNAMICS_MULTIPLIER: 1.5, // 150% boost max
  MAX_VOICE_MULTIPLIER: 0.3,    // 30% boost max
  MAX_GROUP_SIZE_MULTIPLIER: 0.5, // 50% boost max
  MAX_SURPRISE_MULTIPLIER: 1.0,   // 100% boost max

  // Card Limits
  MAX_CARD_TITLE_LENGTH: 100,
  MAX_CARD_CAPTION_LENGTH: 500,
  MAX_KEYWORDS: 10,

  // Museum
  DEFAULT_MUSEUM_LIMIT: 20,
  MAX_MUSEUM_LIMIT: 100,
  MAX_MUSEUM_OFFSET: 10000,

  // Safety
  SAFETY_FLAGS: {
    SELF_HARM: 'self_harm',
    VIOLENCE: 'violence',
    HARASSMENT: 'harassment',
    SPAM: 'spam',
  },

  // Event Types
  CARD_EVENT_TYPES: [
    'generated',
    'offered',
    'claimed',
    'declined',
    'defaulted',
    'burned',
    'printed',
  ] as const,
} as const;
