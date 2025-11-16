/**
 * Consolidated Configuration
 * Single source of truth for all environment variables and config
 */

import { z } from 'zod';

const configSchema = z.object({
  // Supabase
  supabase: z.object({
    url: z.string().url(),
    key: z.string().min(1),
  }),
  
  // LiveKit
  livekit: z.object({
    host: z.string().url(),
    apiKey: z.string().min(1),
    secret: z.string().min(1),
  }),
  
  // DeepSeek / AI
  deepseek: z.object({
    apiKey: z.string().min(1).optional(),
  }),
  
  // OpenAI
  openai: z.object({
    apiKey: z.string().min(1).optional(),
  }),
  
  // Redis
  redis: z.object({
    url: z.string().url().default('redis://localhost:6379'),
  }),
  
  // Server
  server: z.object({
    port: z.number().int().positive().default(3000),
    nodeEnv: z.enum(['development', 'production', 'test']).default('development'),
  }),
  
  // Rate Limiting
  rateLimits: z.object({
    ipRequestsPerMinute: z.number().int().positive().default(1000),
    userRequestsPerMinute: z.number().int().positive().default(100),
    windowMs: z.number().int().positive().default(60000),
  }),
  
  // Request Limits
  requestLimits: z.object({
    maxBodySize: z.string().default('10mb'),
    maxUrlSize: z.number().int().positive().default(2048),
  }),
  
  // CORS
  cors: z.object({
    allowedOrigins: z.array(z.string()).default(['https://vibez.app', 'http://localhost:3000']),
  }),
});

type Config = z.infer<typeof configSchema>;

function loadConfig(): Config {
  const rawConfig = {
    supabase: {
      url: process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL || '',
      key: process.env.SUPABASE_SERVICE_ROLE_KEY || '',
    },
    livekit: {
      host: process.env.LIVEKIT_URL || '',
      apiKey: process.env.LIVEKIT_API_KEY || '',
      secret: process.env.LIVEKIT_API_SECRET || '',
    },
    deepseek: {
      apiKey: process.env.DEEPSEEK_API_KEY,
    },
    openai: {
      apiKey: process.env.OPENAI_API_KEY,
    },
    redis: {
      url: process.env.REDIS_URL || 'redis://localhost:6379',
    },
    server: {
      port: parseInt(process.env.PORT || '3000', 10),
      nodeEnv: (process.env.NODE_ENV || 'development') as 'development' | 'production' | 'test',
    },
    rateLimits: {
      ipRequestsPerMinute: parseInt(process.env.IP_RATE_LIMIT_PER_MIN || '1000', 10),
      userRequestsPerMinute: parseInt(process.env.USER_RATE_LIMIT_PER_MIN || '100', 10),
      windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '60000', 10),
    },
    requestLimits: {
      maxBodySize: process.env.MAX_BODY_SIZE || '10mb',
      maxUrlSize: parseInt(process.env.MAX_URL_SIZE || '2048', 10),
    },
    cors: {
      allowedOrigins: process.env.CORS_ORIGINS
        ? process.env.CORS_ORIGINS.split(',')
        : ['https://vibez.app', 'http://localhost:3000'],
    },
  };

  return configSchema.parse(rawConfig);
}

export const config = loadConfig() as const;

// Export convenience getters
export const getSupabaseConfig = () => config.supabase;
export const getLiveKitConfig = () => config.livekit;
export const getRedisConfig = () => config.redis;
export const getServerConfig = () => config.server;
export const getRateLimitConfig = () => config.rateLimits;
export const getCorsConfig = () => config.cors;

