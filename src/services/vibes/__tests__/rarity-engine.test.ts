/**
 * VIBES Rarity Engine Tests
 */

import { describe, it, expect } from 'vitest';
import { calculateRarity, RarityTier } from '../rarity-engine.js';
import type { SentimentAnalysis } from '../sentiment-service.js';
import type { ConversationParticipant } from '../conversation-service.js';

describe('Rarity Engine', () => {
  it('should calculate rarity', () => {
    const sentiment: SentimentAnalysis = {
      id: 'test',
      conversation_id: 'test',
      sentiment_score: 0.5,
      emotional_intensity: 0.7,
      surprise_factor: 0.3,
      keywords: ['test'],
      breakup_detected: false,
      safety_flags: [],
      analysis_data: {},
      created_at: new Date(),
    };

    const participants: ConversationParticipant[] = [
      { id: '1', conversation_id: 'test', user_id: 'user1', joined_at: new Date(), last_read_at: null },
      { id: '2', conversation_id: 'test', user_id: 'user2', joined_at: new Date(), last_read_at: null },
    ];

    const rarity = calculateRarity(sentiment, participants, [{ type: 'text' }], undefined);
    
    expect(rarity).toBeDefined();
    expect(rarity.final_tier).toBeDefined();
    expect(['common', 'uncommon', 'rare', 'epic', 'legendary']).toContain(rarity.final_tier);
  });

  it('should handle high sentiment scores', () => {
    const sentiment: SentimentAnalysis = {
      id: 'test',
      conversation_id: 'test',
      sentiment_score: 0.9, // Very positive
      emotional_intensity: 0.9,
      surprise_factor: 0.8,
      keywords: ['amazing', 'love'],
      breakup_detected: false,
      safety_flags: [],
      analysis_data: {},
      created_at: new Date(),
    };

    const participants: ConversationParticipant[] = [
      { id: '1', conversation_id: 'test', user_id: 'user1', joined_at: new Date(), last_read_at: null },
    ];

    const rarity = calculateRarity(sentiment, participants, [{ type: 'text' }], undefined);
    
    expect(rarity.final_score).toBeGreaterThan(0.5);
  });
});
