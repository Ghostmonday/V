/**
 * Sentiment Analysis Service Tests
 * Tests sentiment calculation and error handling
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { createMockRedis } from '../../tests/__helpers__/test-setup.js';

// Import the functions after mocking to avoid circular dependency
let analyzeSentiment: any, analyzeSentimentBatch: any;

// Mock Redis
vi.mock('../../config/database-config.js', () => ({
  getRedisClient: vi.fn(() => createMockRedis()),
}));

// Mock sentiment package
const mockSentiment = {
  analyze: vi.fn((text: string) => {
    // Simple mock: count positive/negative words
    const positiveWords = ['love', 'happy', 'great', 'amazing', 'wonderful'];
    const negativeWords = ['hate', 'sad', 'bad', 'terrible', 'awful'];

    const lowerText = text.toLowerCase();
    const positiveCount = positiveWords.filter((w) => lowerText.includes(w)).length;
    const negativeCount = negativeWords.filter((w) => lowerText.includes(w)).length;

    // Return higher scores to exceed the 0.6 threshold after normalization
    // The service divides by max(abs(score), 10), so we need score > 6 for polarity > 0.6
    const score = (positiveCount - negativeCount) * 4; // Multiply by 4 to get stronger signal
    return {
      score,
      words: text.split(/\s+/),
    };
  }),
};

vi.mock('sentiment', () => ({
  default: vi.fn(() => mockSentiment),
  Sentiment: vi.fn(() => mockSentiment),
}));

describe('Sentiment Analysis Service', () => {
  beforeAll(async () => {
    // Load the functions after mocking to avoid circular dependency
    const sentimentModule = await import('../sentiment-analysis-service.js');
    analyzeSentiment = sentimentModule.analyzeSentiment;
    analyzeSentimentBatch = sentimentModule.analyzeSentimentBatch;
  });

  beforeEach(() => {
    vi.clearAllMocks();
    // Reset the mock analyze function to the default implementation
    mockSentiment.analyze = vi.fn((text: string) => {
      const positiveWords = ['love', 'happy', 'great', 'amazing', 'wonderful'];
      const negativeWords = ['hate', 'sad', 'bad', 'terrible', 'awful'];

      const lowerText = text.toLowerCase();
      const positiveCount = positiveWords.filter((w) => lowerText.includes(w)).length;
      const negativeCount = negativeWords.filter((w) => lowerText.includes(w)).length;

      const score = (positiveCount - negativeCount) * 4;
      return {
        score,
        words: text.split(/\s+/),
      };
    });
  });

  describe('analyzeSentiment', () => {
    it('should return positive sentiment for positive text', async () => {
      const result = await analyzeSentiment('I love this! It is amazing and wonderful!');

      expect(result.polarity).toBeGreaterThan(0);
      expect(result.mood).toBe('happy');
      expect(result.confidence).toBeGreaterThan(0);
      expect(result.cached).toBe(false);
    });

    it('should return negative sentiment for negative text', async () => {
      const result = await analyzeSentiment('I hate this. It is terrible and awful.');

      expect(result.polarity).toBeLessThan(0);
      expect(result.mood).toBe('sad');
      expect(result.confidence).toBeGreaterThan(0);
    });

    it('should return neutral sentiment for neutral text', async () => {
      const result = await analyzeSentiment('This is a normal message with no strong emotions.');

      expect(result.mood).toBe('neutral');
      expect(Math.abs(result.polarity)).toBeLessThan(0.6);
    });

    it('should return neutral for empty text', async () => {
      const result = await analyzeSentiment('');

      expect(result.polarity).toBe(0);
      expect(result.mood).toBe('neutral');
      expect(result.confidence).toBe(0);
    });

    it('should cache results', async () => {
      const text = 'I love this amazing product!';

      // First call
      const result1 = await analyzeSentiment(text);
      expect(result1.cached).toBe(false);

      // Second call should be cached
      const result2 = await analyzeSentiment(text);
      expect(result2.cached).toBe(true);
      expect(result2.polarity).toBe(result1.polarity);
      expect(result2.mood).toBe(result1.mood);
    });

    it('should handle errors gracefully', async () => {
      // Mock sentiment to throw error
      mockSentiment.analyze = vi.fn(() => {
        throw new Error('Sentiment analysis failed');
      });

      const result = await analyzeSentiment('Test message');

      // Should return neutral with low confidence on error
      expect(result.polarity).toBe(0);
      expect(result.mood).toBe('neutral');
      expect(result.confidence).toBe(0);
    });

    it('should map polarity to mood correctly', async () => {
      // Test happy threshold (>0.6)
      mockSentiment.analyze = vi.fn(() => ({
        score: 10, // High positive score
        words: ['love', 'amazing', 'wonderful', 'great', 'happy'],
      }));

      const happyResult = await analyzeSentiment(
        'I love this amazing wonderful great happy thing!'
      );
      expect(happyResult.mood).toBe('happy');

      // Test sad threshold (<-0.6)
      mockSentiment.analyze = vi.fn(() => ({
        score: -10, // High negative score
        words: ['hate', 'terrible', 'awful', 'bad', 'sad'],
      }));

      const sadResult = await analyzeSentiment('I hate this terrible awful bad sad thing!');
      expect(sadResult.mood).toBe('sad');

      // Test neutral (between -0.6 and 0.6)
      mockSentiment.analyze = vi.fn(() => ({
        score: 2, // Low score
        words: ['okay', 'fine'],
      }));

      const neutralResult = await analyzeSentiment('This is okay and fine.');
      expect(neutralResult.mood).toBe('neutral');
    });
  });

  describe('analyzeSentimentBatch', () => {
    it('should analyze multiple texts', async () => {
      // Use multi-word text to get strong enough sentiment scores
      // Need 2+ positive/negative words to exceed 0.6 threshold after normalization
      const texts = [
        'I love this! It is amazing and wonderful!',
        'I hate this. It is terrible and awful.',
        'This is neutral.'
      ];

      const results = await analyzeSentimentBatch(texts);

      expect(results).toHaveLength(3);
      expect(results[0].mood).toBe('happy');
      expect(results[1].mood).toBe('sad');
      expect(results[2].mood).toBe('neutral');
    });

    it('should handle empty array', async () => {
      const results = await analyzeSentimentBatch([]);

      expect(results).toHaveLength(0);
    });
  });
});
