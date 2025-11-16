/**
 * Server configuration
 * Centralized config values - hardcoded defaults with vault migration path
 */
import dotenv from 'dotenv';
dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || '3000', 10),
  dbUrl: process.env.DB_URL,
  redisUrl: process.env.REDIS_URL,
  
  // Rate limiting configuration
  rateLimits: {
    // IP-based DDoS protection (per minute)
    ipRequestsPerMinute: parseInt(process.env.IP_RATE_LIMIT_PER_MIN || '1000', 10),
    
    // User-based rate limiting (per minute)
    userRequestsPerMinute: parseInt(process.env.USER_RATE_LIMIT_PER_MIN || '100', 10),
    
    // Window size in milliseconds
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '60000', 10),
  },
  
  // Request size limits
  requestLimits: {
    maxBodySize: process.env.MAX_BODY_SIZE || '10mb',
    maxUrlSize: parseInt(process.env.MAX_URL_SIZE || '2048', 10),
  },
  
  // CORS configuration
  cors: {
    allowedOrigins: [
      'https://vibez.app',
      'http://localhost:3000',
    ],
  },
};

// Export rate limit constants for easy access
export const LIMIT_REQUESTS_PER_MIN = config.rateLimits.ipRequestsPerMinute;
export const LIMIT_USER_REQUESTS_PER_MIN = config.rateLimits.userRequestsPerMinute;

