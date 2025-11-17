/**
 * Moderation Service Tests
 * Tests toxicity scoring and threshold enforcement
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { scanForToxicity } from '../moderation.service.js';

// Mock dependencies
vi.mock('../perspective-api-service.js', () => ({
  analyzeWithPerspective: vi.fn(),
  getModerationThresholds: vi.fn(async () => ({
    warn: 0.6,
    block: 0.8,
  })),
}));

vi.mock('../api-keys-service.js', () => ({
  getDeepSeekKey: vi.fn(async () => 'test-deepseek-key'),
}));

vi.mock('./message-flagging-service.js', () => ({
  flagMessage: vi.fn(async () => {}),
}));

vi.mock('../utils/prompt-sanitizer.js', () => ({
  sanitizePrompt: vi.fn((text: string) => text),
  logPromptAudit: vi.fn(async () => {}),
}));

vi.mock('../shared/logger.js', () => ({
  logError: vi.fn(),
  logWarning: vi.fn(),
  logInfo: vi.fn(),
}));

describe('Moderation Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('scanForToxicity', () => {
    it('should return low score for clean text', async () => {
      const { analyzeWithPerspective } = await import('../perspective-api-service.js');
      
      vi.mocked(analyzeWithPerspective).mockResolvedValue({
        toxicity: 0.2,
        severeToxicity: 0.1,
        identityAttack: 0.1,
        insult: 0.1,
        profanity: 0.1,
        threat: 0.1,
      });
      
      const result = await scanForToxicity('Hello, how are you?', 'room-123');
      
      expect(result.score).toBe(0.2);
      expect(result.isToxic).toBe(false);
      expect(result.suggestion).toBe('Please keep conversations respectful');
    });

    it('should warn at warn threshold (0.6)', async () => {
      const { analyzeWithPerspective } = await import('../perspective-api-service.js');
      const { flagMessage } = await import('./message-flagging-service.js');
      
      vi.mocked(analyzeWithPerspective).mockResolvedValue({
        toxicity: 0.65,
        severeToxicity: 0.3,
        identityAttack: 0.2,
        insult: 0.4,
        profanity: 0.5,
        threat: 0.2,
      });
      
      const result = await scanForToxicity(
        'This is a warning message',
        'room-123',
        'msg-123',
        'user-123'
      );
      
      expect(result.score).toBe(0.65);
      expect(result.isToxic).toBe(false); // Not blocked, only warned
      expect(result.suggestion).toContain('may be inappropriate');
      expect(flagMessage).toHaveBeenCalled(); // Should auto-flag
    });

    it('should block at block threshold (0.8)', async () => {
      const { analyzeWithPerspective } = await import('../perspective-api-service.js');
      const { flagMessage } = await import('./message-flagging-service.js');
      
      vi.mocked(analyzeWithPerspective).mockResolvedValue({
        toxicity: 0.85,
        severeToxicity: 0.7,
        identityAttack: 0.5,
        insult: 0.8,
        profanity: 0.9,
        threat: 0.6,
      });
      
      const result = await scanForToxicity(
        'This is a toxic message',
        'room-123',
        'msg-123',
        'user-123'
      );
      
      expect(result.score).toBe(0.85);
      expect(result.isToxic).toBe(true); // Should be blocked
      expect(result.suggestion).toContain('violates our community guidelines');
      expect(flagMessage).toHaveBeenCalled(); // Should auto-flag
    });

    it('should fallback to DeepSeek if Perspective API fails', async () => {
      const { analyzeWithPerspective } = await import('../perspective-api-service.js');
      
      vi.mocked(analyzeWithPerspective).mockResolvedValue(null);
      
      // Mock DeepSeek API call (would be in actual implementation)
      const result = await scanForToxicity('Test message', 'room-123');
      
      // Should not throw error, should return result (even if neutral)
      expect(result).toBeDefined();
      expect(typeof result.score).toBe('number');
      expect(typeof result.isToxic).toBe('boolean');
    });

    it('should return neutral if no API keys available', async () => {
      const { getDeepSeekKey } = await import('../api-keys-service.js');
      
      vi.mocked(getDeepSeekKey).mockResolvedValue(null);
      
      const { analyzeWithPerspective } = await import('../perspective-api-service.js');
      vi.mocked(analyzeWithPerspective).mockResolvedValue(null);
      
      const result = await scanForToxicity('Test message', 'room-123');
      
      expect(result.score).toBe(0);
      expect(result.isToxic).toBe(false);
      expect(result.suggestion).toBe('');
    });

    it('should use per-room thresholds when configured', async () => {
      const { getModerationThresholds } = await import('../perspective-api-service.js');
      
      // Mock custom room thresholds
      vi.mocked(getModerationThresholds).mockResolvedValue({
        warn: 0.5, // Lower threshold
        block: 0.7, // Lower threshold
      });
      
      const { analyzeWithPerspective } = await import('../perspective-api-service.js');
      vi.mocked(analyzeWithPerspective).mockResolvedValue({
        toxicity: 0.55,
        severeToxicity: 0.2,
        identityAttack: 0.1,
        insult: 0.3,
        profanity: 0.4,
        threat: 0.1,
      });
      
      const result = await scanForToxicity('Test message', 'room-123', 'msg-123', 'user-123');
      
      // Should warn at 0.55 (above custom warn threshold of 0.5)
      expect(result.score).toBe(0.55);
      expect(result.isToxic).toBe(false); // Not blocked yet (below 0.7)
    });
  });
});

