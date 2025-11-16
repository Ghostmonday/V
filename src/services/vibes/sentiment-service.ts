/**
 * VIBES Sentiment Analysis Service
 * Analyzes conversations for emotional dynamics and sentiment
 */

import { supabase } from '../../config/db.ts';
import { logError } from '../../shared/logger.js';
import { vibesConfig } from '../../config/vibes.config.js';

export interface SentimentAnalysis {
  id: string;
  conversation_id: string;
  sentiment_score: number; // -1 to 1
  emotional_intensity: number; // 0 to 1
  surprise_factor: number; // 0 to 1
  keywords: string[];
  breakup_detected: boolean;
  safety_flags: string[];
  analysis_data: Record<string, any>;
  created_at: Date;
}

/**
 * Analyze conversation sentiment
 * TODO: Integrate with OpenAI or sentiment API
 */
export async function analyzeConversation(
  conversationId: string,
  messages: Array<{ content: string; sender_id: string; created_at: Date }>
): Promise<SentimentAnalysis> {
  try {
    // Aggregate message content
    const allText = messages.map(m => m.content).join(' ');
    
    // Basic sentiment calculation (placeholder - replace with real AI)
    const sentimentScore = calculateBasicSentiment(allText);
    const emotionalIntensity = calculateEmotionalIntensity(messages);
    const surpriseFactor = calculateSurpriseFactor(messages);
    const keywords = extractKeywords(allText);
    const breakupDetected = detectBreakup(allText);
    const safetyFlags = detectSafetyIssues(allText);

    const analysisData = {
      message_count: messages.length,
      avg_message_length: allText.length / messages.length,
      participant_count: new Set(messages.map(m => m.sender_id)).size,
      timestamp: new Date().toISOString(),
    };

    // Store analysis
    const { data, error } = await supabase
      .from('sentiment_analysis')
      .insert({
        conversation_id: conversationId,
        sentiment_score: sentimentScore,
        emotional_intensity: emotionalIntensity,
        surprise_factor: surpriseFactor,
        keywords: keywords,
        breakup_detected: breakupDetected,
        safety_flags: safetyFlags,
        analysis_data: analysisData,
      })
      .select()
      .single();

    if (error) throw error;

    return data as SentimentAnalysis;
  } catch (error) {
    logError('Failed to analyze conversation sentiment', error);
    throw error;
  }
}

/**
 * Get sentiment analysis for conversation
 */
export async function getSentimentAnalysis(
  conversationId: string
): Promise<SentimentAnalysis | null> {
  try {
    const { data, error } = await supabase
      .from('sentiment_analysis')
      .select('*')
      .eq('conversation_id', conversationId)
      .single();

    if (error) throw error;
    return data as SentimentAnalysis | null;
  } catch (error) {
    logError('Failed to get sentiment analysis', error);
    return null;
  }
}

// ==========================================
// Placeholder Functions (Replace with Real AI)
// ==========================================

function calculateBasicSentiment(text: string): number {
  // Placeholder: simple keyword matching
  const positiveWords = ['love', 'happy', 'great', 'amazing', 'wonderful'];
  const negativeWords = ['hate', 'sad', 'bad', 'terrible', 'awful'];
  
  const lowerText = text.toLowerCase();
  const positiveCount = positiveWords.filter(w => lowerText.includes(w)).length;
  const negativeCount = negativeWords.filter(w => lowerText.includes(w)).length;
  
  if (positiveCount + negativeCount === 0) return 0;
  return (positiveCount - negativeCount) / (positiveCount + negativeCount);
}

function calculateEmotionalIntensity(messages: any[]): number {
  // Placeholder: based on message frequency and length
  const avgLength = messages.reduce((sum, m) => sum + m.content.length, 0) / messages.length;
  return Math.min(avgLength / 100, 1); // Normalize to 0-1
}

function calculateSurpriseFactor(messages: any[]): number {
  // Placeholder: based on message timing variance
  if (messages.length < 2) return 0;
  
  const intervals = [];
  for (let i = 1; i < messages.length; i++) {
    const interval = messages[i].created_at - messages[i-1].created_at;
    intervals.push(interval);
  }
  
  const avgInterval = intervals.reduce((a, b) => a + b, 0) / intervals.length;
  const variance = intervals.reduce((sum, i) => sum + Math.pow(i - avgInterval, 2), 0) / intervals.length;
  
  return Math.min(variance / 1000, 1); // Normalize
}

function extractKeywords(text: string): string[] {
  // Placeholder: simple word frequency
  const words = text.toLowerCase().split(/\W+/);
  const freq: Record<string, number> = {};
  
  words.forEach(word => {
    if (word.length > 4) { // Ignore short words
      freq[word] = (freq[word] || 0) + 1;
    }
  });
  
  return Object.entries(freq)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .map(([word]) => word);
}

function detectBreakup(text: string): boolean {
  const breakupKeywords = ['breakup', 'break up', 'over', 'done', 'finished', 'end'];
  const lowerText = text.toLowerCase();
  return breakupKeywords.some(keyword => lowerText.includes(keyword));
}

function detectSafetyIssues(text: string): string[] {
  const flags: string[] = [];
  const lowerText = text.toLowerCase();
  
  // Self-harm detection
  if (lowerText.includes('suicide') || lowerText.includes('kill myself')) {
    flags.push('self_harm');
  }
  
  // Violence detection
  if (lowerText.includes('hurt you') || lowerText.includes('violence')) {
    flags.push('violence');
  }
  
  return flags;
}
