/**
 * Perspective API Service
 * Google Perspective API integration for toxicity detection
 * 
 * Install: npm install @tensorflow-models/toxicity (or use REST API)
 * API Key: Get from Google Cloud Console
 */

import axios from 'axios';
import { logError, logWarning } from '../shared/logger.js';
import { getApiKey } from './api-keys-service.js';
import { supabase } from '../config/db.js';

const PERSPECTIVE_API_URL = 'https://commentanalyzer.googleapis.com/v1alpha1/comments:analyze';

export interface PerspectiveResult {
  toxicity: number; // 0-1
  severeToxicity: number;
  identityAttack: number;
  insult: number;
  profanity: number;
  threat: number;
  isToxic: boolean;
}

/**
 * Analyze text using Perspective API
 */
export async function analyzeWithPerspective(text: string): Promise<PerspectiveResult | null> {
  try {
    const apiKey = await getApiKey('perspective_api_key', 'production');
    
    if (!apiKey) {
      logWarning('Perspective API key not found - skipping analysis');
      return null;
    }

    const response = await axios.post(
      `${PERSPECTIVE_API_URL}?key=${apiKey}`,
      {
        comment: { text },
        requestedAttributes: {
          TOXICITY: {},
          SEVERE_TOXICITY: {},
          IDENTITY_ATTACK: {},
          INSULT: {},
          PROFANITY: {},
          THREAT: {},
        },
        languages: ['en'],
      },
      {
        headers: {
          'Content-Type': 'application/json',
        },
        timeout: 5000, // 5 second timeout
      }
    );

    const attributes = response.data?.attributeScores || {};
    
    const toxicity = attributes.TOXICITY?.summaryScore?.value || 0;
    const severeToxicity = attributes.SEVERE_TOXICITY?.summaryScore?.value || 0;
    const identityAttack = attributes.IDENTITY_ATTACK?.summaryScore?.value || 0;
    const insult = attributes.INSULT?.summaryScore?.value || 0;
    const profanity = attributes.PROFANITY?.summaryScore?.value || 0;
    const threat = attributes.THREAT?.summaryScore?.value || 0;

    // Consider toxic if any attribute exceeds threshold
    const isToxic = toxicity > 0.7 || severeToxicity > 0.7 || identityAttack > 0.7 || threat > 0.7;

    return {
      toxicity,
      severeToxicity,
      identityAttack,
      insult,
      profanity,
      threat,
      isToxic,
    };
  } catch (error: any) {
    logError('Perspective API analysis failed', error);
    return null;
  }
}

/**
 * Get configurable threshold from system config
 */
export async function getModerationThresholds(): Promise<{
  warn: number;
  block: number;
}> {
  try {
    const { data } = await supabase
      .from('system_config')
      .select('value')
      .eq('key', 'moderation_thresholds')
      .single();

    if (data?.value) {
      return {
        warn: data.value.warn || 0.6,
        block: data.value.block || 0.8,
      };
    }

    // Default thresholds
    return {
      warn: 0.6,
      block: 0.8,
    };
  } catch (error: any) {
    logError('Failed to get moderation thresholds', error);
    return {
      warn: 0.6,
      block: 0.8,
    };
  }
}

