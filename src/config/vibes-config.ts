/**
 * VIBES Configuration
 * Central config module for VIBES application
 */

import dotenv from 'dotenv';

dotenv.config();

export interface VIBESConfig {
  // Server
  port: number;
  nodeEnv: string;

  // Database
  databaseUrl: string;
  supabaseUrl: string;
  supabaseKey: string;

  // Redis
  redisUrl?: string;

  // AI Services
  sentimentApiUrl?: string;

  // Storage
  s3Bucket?: string;
  awsAccessKeyId?: string;
  awsSecretAccessKey?: string;

  // VIBES Specific

  // Features
  features: {
    voiceMessages: boolean;
    printToBurn: boolean;
  };
}

function getEnv(key: string, defaultValue?: string): string {
  const value = process.env[key];
  if (!value && !defaultValue) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value || defaultValue || '';
}

function getBooleanEnv(key: string, defaultValue: boolean = false): boolean {
  const value = process.env[key];
  if (!value) return defaultValue;
  return value.toLowerCase() === 'true';
}

function getNumberEnv(key: string, defaultValue: number): number {
  const value = process.env[key];
  if (!value) return defaultValue;
  const parsed = parseInt(value, 10);
  if (isNaN(parsed)) return defaultValue;
  return parsed;
}

export const vibesConfig: VIBESConfig = {
  // Server
  port: getNumberEnv('PORT', 3000),
  nodeEnv: getEnv('NODE_ENV', 'development'),

  // Database
  databaseUrl: getEnv('DATABASE_URL'),
  supabaseUrl: getEnv('NEXT_PUBLIC_SUPABASE_URL') || getEnv('SUPABASE_URL'),
  supabaseKey: getEnv('SUPABASE_SERVICE_ROLE_KEY') || getEnv('SUPABASE_KEY'),

  // Redis (optional)
  redisUrl: process.env.REDIS_URL,

  // AI Services
  sentimentApiUrl: process.env.SENTIMENT_API_URL,

  // Storage
  s3Bucket: process.env.AWS_BUCKET,
  awsAccessKeyId: process.env.AWS_ACCESS_KEY_ID,
  awsSecretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,

  // VIBES Specific

  // Features
  features: {
    voiceMessages: getBooleanEnv('FEATURE_VOICE_MESSAGES', false),
    printToBurn: getBooleanEnv('FEATURE_PRINT_TO_BURN', false),
  },
};

// Validation
if (!vibesConfig.databaseUrl && !vibesConfig.supabaseUrl) {
  throw new Error('Either DATABASE_URL or SUPABASE_URL must be set');
}

export default vibesConfig;
