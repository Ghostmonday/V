/**
 * Sentiment Analysis Service
 * Real NLP-based sentiment analysis with caching and error fallback
 *
 * Uses 'sentiment' npm package for Node.js sentiment analysis
 * Maps polarity: >0.6 = happy, <-0.6 = sad, else neutral
 */

import { getRedisClient } from '../config/db.ts';
import { logError, logInfo } from '../shared/logger.js';

// Try to import sentiment package (install: npm install sentiment)
let Sentiment: any = null;
try {
  const sentimentModule = await import('sentiment');
  Sentiment = sentimentModule.default || sentimentModule.Sentiment;
} catch (error) {
  logError('Sentiment package not installed. Run: npm install sentiment', error);
}

const redis = getRedisClient();
const CACHE_TTL_SECONDS = 3600; // 1 hour cache

export interface SentimentResult {
  polarity: number; // -1 to 1
  mood: 'happy' | 'sad' | 'neutral';
  confidence: number; // 0 to 1
  cached: boolean;
}

/**
 * Analyze sentiment of text
 * Returns polarity (-1 to 1) and mood (happy/sad/neutral)
 */
export async function analyzeSentiment(text: string): Promise<SentimentResult> {
  if (!text || typeof text !== 'string' || text.trim().length === 0) {
    return {
      polarity: 0,
      mood: 'neutral',
      confidence: 0,
      cached: false,
    };
  }

  // Check cache first
  const cacheKey = `sentiment:${hashText(text)}`;
  try {
    if (redis) {
      const cached = await redis.get(cacheKey);
      if (cached) {
        const result = JSON.parse(cached);
        return { ...result, cached: true };
      }
    }
  } catch (error: any) {
    logError('Sentiment cache read failed', error);
  }

  // Analyze sentiment
  let polarity = 0;
  let confidence = 0.5;
  let mood: 'happy' | 'sad' | 'neutral' = 'neutral';

  try {
    if (Sentiment) {
      // Use real sentiment analysis
      const sentiment = new Sentiment();
      const result = sentiment.analyze(text);

      // Sentiment package returns score: positive = positive, negative = negative
      // Normalize to -1 to 1 range
      const score = result.score || 0;
      const maxScore = Math.max(Math.abs(score), 10); // Normalize by max expected score
      polarity = Math.max(-1, Math.min(1, score / maxScore));

      // Calculate confidence based on word count
      const wordCount = result.words?.length || 0;
      confidence = Math.min(1, wordCount / 10); // More words = higher confidence
    } else {
      // Fallback: simple keyword matching (existing implementation)
      polarity = calculateBasicSentiment(text);
      confidence = 0.3; // Lower confidence for fallback
    }

    // Map polarity to mood: >0.6 = happy, <-0.6 = sad, else neutral
    if (polarity > 0.6) {
      mood = 'happy';
    } else if (polarity < -0.6) {
      mood = 'sad';
    } else {
      mood = 'neutral';
    }

    const result: SentimentResult = {
      polarity,
      mood,
      confidence,
      cached: false,
    };

    // Cache result
    try {
      if (redis) {
        await redis.setex(cacheKey, CACHE_TTL_SECONDS, JSON.stringify(result));
      }
    } catch (error: any) {
      logError('Sentiment cache write failed', error);
    }

    return result;
  } catch (error: any) {
    // Error fallback: return neutral with low confidence
    logError('Sentiment analysis failed, using fallback', error);
    return {
      polarity: 0,
      mood: 'neutral',
      confidence: 0,
      cached: false,
    };
  }
}

/**
 * Hash text for cache key (simple hash)
 */
function hashText(text: string): string {
  // Simple hash for cache key (not cryptographic)
  let hash = 0;
  for (let i = 0; i < text.length; i++) {
    const char = text.charCodeAt(i);
    hash = (hash << 5) - hash + char;
    hash = hash & hash; // Convert to 32-bit integer
  }
  return Math.abs(hash).toString(36);
}

/**
 * Fallback sentiment calculation (simple keyword matching)
 */
function calculateBasicSentiment(text: string): number {
  const positiveWords = [
    'love',
    'happy',
    'great',
    'amazing',
    'wonderful',
    'excellent',
    'fantastic',
    'good',
    'nice',
    'awesome',
  ];
  const negativeWords = [
    'hate',
    'sad',
    'bad',
    'terrible',
    'awful',
    'horrible',
    'worst',
    'disappointed',
    'angry',
    'frustrated',
  ];

  const lowerText = text.toLowerCase();
  const positiveCount = positiveWords.filter((w) => lowerText.includes(w)).length;
  const negativeCount = negativeWords.filter((w) => lowerText.includes(w)).length;

  if (positiveCount + negativeCount === 0) return 0;
  return (positiveCount - negativeCount) / (positiveCount + negativeCount + 1);
}

/**
 * Batch analyze multiple texts
 */
export async function analyzeSentimentBatch(texts: string[]): Promise<SentimentResult[]> {
  return Promise.all(texts.map((text) => analyzeSentiment(text)));
}
