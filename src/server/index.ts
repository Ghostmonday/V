/**
 * Main API server
 * - Express HTTP API
 * - WebSocket gateway
 * - Prometheus metrics endpoint
 *
 * Note: TypeScript -> compiled to dist/server/index.js for production.
 */

import express from 'express';
import cookieParser from 'cookie-parser';
import dotenv from 'dotenv';
import http from 'http';
import { WebSocketServer } from 'ws';
import client from 'prom-client';
import path from 'path';
import { fileURLToPath } from 'url';
import { setupWebSocketGateway } from '../ws/gateway.js';
import userAuthenticationRoutes from '../routes/user-authentication-routes.js';
import refreshTokenRoutes from '../routes/refresh-token-routes.js';
import fileStorageRoutes from '../routes/file-storage-routes.js';
import presenceRoutes from '../routes/presence-routes.js';
import messageRoutes from '../routes/message-routes.js';
import configRoutes from '../routes/config-routes.js';
import telemetryRoutes from '../routes/telemetry-routes.js';
import adminRoutes from '../routes/admin-routes.js';
import adminModerationRoutes from '../routes/admin-moderation-routes.js';
import moderationRoutes from '../routes/moderation-routes.js';
import voiceRoutes from '../routes/voice-routes.js';
import subscriptionRoutes from '../routes/subscription-routes.js';
import entitlementsRoutes from '../routes/entitlements-routes.js';
import healthRoutes from '../routes/health-routes.js';
import notifyRoutes from '../routes/notify-routes.js';
import reactionsRoutes from '../routes/reactions-routes.js';
import searchRoutes from '../routes/search-routes.js';
import threadsRoutes from '../routes/threads-routes.js';
import uxTelemetryRoutes from '../routes/ux-telemetry-routes.js';
import chatRoomConfigRoutes from '../routes/chat-room-config-routes.js';
import roomRoutes from '../routes/room-routes.js';
import agoraRoutes from '../routes/agora-routes.js';
import readReceiptsRoutes from '../routes/read-receipts-routes.js';
import nicknamesRoutes from '../routes/nicknames-routes.js';
import pinnedRoutes from '../routes/pinned-routes.js';
import bandwidthRoutes from '../routes/bandwidth-routes.js';
import vibesConversationRoutes from '../routes/vibes/conversation-routes.js';
import vibesCardRoutes from '../routes/vibes/card-routes.js';
import vibesMuseumRoutes from '../routes/vibes/museum-routes.js';
import userDataRoutes from '../routes/user-data-routes.js';
import privacyRoutes from '../routes/privacy-routes.js';
import { telemetryMiddleware } from './middleware/telemetry.js';
import { errorMiddleware } from './middleware/error.js';
import { structuredLogging } from '../middleware/structured-logging.js';
import { rateLimit, ipRateLimit } from '../middleware/rate-limiter.js';
import rateLimiter from '../middleware/rate-limiter.js'; // Simple default rate limiter
import { sanitizeInput } from '../middleware/input-validation.js';
import { fileUploadSecurity } from '../middleware/file-upload-security.js';
import authMiddleware from '../middleware/auth.js'; // Optional auth middleware
import helmet from 'helmet';
import csurf from 'csurf';
import { logInfo } from '../shared/logger.js';
import { LIMIT_REQUESTS_PER_MIN } from './utils/config.js';
import { vibesConfig } from '../config/vibes.config.js';

dotenv.config();

const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ server });

// collect node metrics for Prometheus
client.collectDefaultMetrics();

// HTTPS enforcement in production
if (process.env.NODE_ENV === 'production') {
  app.use((req, res, next) => {
    // Check if request is HTTP (not HTTPS)
    if (req.header('x-forwarded-proto') !== 'https' && req.protocol !== 'https') {
      // Redirect to HTTPS
      return res.redirect(308, `https://${req.get('host')}${req.url}`);
    }
    next();
  });
}

// CORS configuration - locked to vibez.app and localhost:3000
// SECURITY: Never use wildcard (*) with credentials: true
const allowedOrigins = [
  'https://vibez.app',
  'http://localhost:3000',
];

app.use((req, res, next) => {
  const origin = req.headers.origin;
  // SECURITY: Only set CORS headers if origin is in allowed list
  // Never use '*' with credentials: true (prevents credential leakage)
  if (origin && allowedOrigins.includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Access-Control-Allow-Headers', 'authorization, content-type');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.setHeader('Access-Control-Allow-Credentials', 'true');
  } else if (origin) {
    // Log unauthorized origin attempts for security monitoring
    logInfo(`Blocked CORS request from unauthorized origin: ${origin}`);
  }
  
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  
  next();
});

// Security middleware - Helmet with strict CSP
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"], // 'unsafe-inline' needed for some UI frameworks
      scriptSrc: ["'self'"], // No inline scripts - XSS protection
      imgSrc: ["'self'", "data:", "https:"], // Allow images from HTTPS sources
      connectSrc: ["'self'", "wss:", "ws:"], // WebSocket connections
      fontSrc: ["'self'", "data:"],
      objectSrc: ["'none'"], // Block plugins
      mediaSrc: ["'self'"],
      frameSrc: ["'none'"], // Block iframes
      baseUri: ["'self'"],
      formAction: ["'self'"],
      upgradeInsecureRequests: [], // Upgrade HTTP to HTTPS
    },
  },
  crossOriginEmbedderPolicy: false, // Allow WebSocket connections
  hsts: {
    maxAge: 31536000, // 1 year
    includeSubDomains: true,
    preload: true,
  },
  noSniff: true, // Prevent MIME type sniffing
  xssFilter: true, // Enable XSS filter
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
}));

// Phase 6.1: Structured logging middleware (after security, before routes)
app.use(structuredLogging);

// Health endpoint - must be public (before rate limiting and auth)
app.get('/health', (req, res) => res.json({ status: 'ok', ts: new Date().toISOString() }));

// Security.txt endpoint (RFC 9116)
app.get('/.well-known/security.txt', (req, res) => {
  res.setHeader('Content-Type', 'text/plain');
  res.send(`Contact: security@vibez.app
Expires: 2026-12-31T23:59:59.000Z
Preferred-Languages: en
Canonical: https://vibez.app/.well-known/security.txt
Policy: https://vibez.app/security-policy

# Security Policy

We take security seriously. If you discover a security vulnerability, please follow these guidelines:

## Reporting a Vulnerability

1. **Do NOT** open a public issue
2. Email security@vibez.app with:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

## Response Timeline

- Initial response within 48 hours
- Status update within 7 days
- Resolution timeline depends on severity

## Scope

- VibeZ API (api.vibez.app)
- VibeZ Web App (vibez.app)
- VibeZ iOS App
- Infrastructure and deployment systems

## Out of Scope

- Social engineering attacks
- Physical security issues
- Denial of service attacks
- Spam or abuse reports (use support@vibez.app)

## Recognition

We recognize security researchers who responsibly disclose vulnerabilities. With your permission, we'll credit you in our security advisories.

## Legal

We will not pursue legal action against security researchers who:
- Act in good faith
- Do not access or modify data beyond what's necessary
- Do not disrupt our services
- Follow responsible disclosure practices

Thank you for helping keep VibeZ secure!
`);
});

// Simple rate limiting - 60 requests per minute per IP (fails open if Redis unavailable)
app.use(rateLimiter);

// Optional authentication middleware - sets req.user if token present, allows through if not
app.use(authMiddleware);

// Middleware
app.use(cookieParser()); // Parse cookies for HTTP-only token storage
app.use(express.json({ limit: '10mb' })); // Limit request size
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(sanitizeInput); // SECURITY: Sanitize all input before processing

// CSRF protection (skip for API endpoints, WebSocket, and health checks)
const csrfProtection = csurf({ 
  cookie: { httpOnly: true, secure: process.env.NODE_ENV === 'production', sameSite: 'strict' },
  ignoreMethods: ['GET', 'HEAD', 'OPTIONS'],
});
app.use((req, res, next) => {
  // Skip CSRF for API endpoints, WebSocket upgrade, and health checks
  if (req.path.startsWith('/api/') || 
      req.path.startsWith('/auth/') ||
      req.path.startsWith('/metrics') ||
      req.path === '/health' ||
      req.headers.upgrade === 'websocket') {
    return next();
  }
  csrfProtection(req, res, next);
});

app.use(telemetryMiddleware);

// Routes
app.use('/auth', userAuthenticationRoutes);
app.use('/auth', refreshTokenRoutes); // Refresh token endpoints
app.use('/files', fileStorageRoutes);
app.use('/presence', presenceRoutes);
app.use('/messaging', messageRoutes);
app.use('/config', configRoutes);
app.use('/telemetry', telemetryRoutes);
app.use('/admin', adminRoutes);
app.use('/admin/moderation', adminModerationRoutes);
app.use('/api/moderation', moderationRoutes); // User-facing moderation endpoints
app.use('/voice', voiceRoutes);
app.use('/subscription', subscriptionRoutes);
app.use('/entitlements', entitlementsRoutes);
import { appStoreWebhook } from '../services/webhooks.js';
app.post('/appstore-webhook', appStoreWebhook);
// Note: Admin routes are mounted at /admin only (removed duplicate /api mount)
app.use('/api/notify', notifyRoutes);
app.use('/api/reactions', reactionsRoutes);
app.use('/api/search', searchRoutes);
app.use('/api/threads', threadsRoutes);
app.use('/api/ux-telemetry', uxTelemetryRoutes); // UX Telemetry (separate from system telemetry)
app.use('/api/users', userDataRoutes); // GDPR user data endpoints
app.use('/api/privacy', privacyRoutes); // Privacy & ZKP endpoints
app.use('/api/read-receipts', readReceiptsRoutes); // Read receipts endpoints
app.use('/api/nicknames', nicknamesRoutes); // Nicknames endpoints
app.use('/api/pinned', pinnedRoutes); // Pinned items endpoints
app.use('/api/bandwidth', bandwidthRoutes); // Bandwidth mode endpoints
app.use('/chat_rooms', chatRoomConfigRoutes); // Room configuration endpoints
app.use('/', roomRoutes); // Room creation and join endpoints (POST /chat-rooms, POST /chat-rooms/:id/join)
app.use('/rooms', agoraRoutes); // Agora room management (mute, video, members, leave)
app.use('/vibes/conversations', vibesConversationRoutes); // VIBES conversation endpoints
app.use('/vibes/cards', vibesCardRoutes); // VIBES card endpoints
app.use('/vibes/museum', vibesMuseumRoutes); // VIBES museum endpoints
import vibesAdminRoutes from '../routes/vibes/admin-routes.js';
app.use('/vibes/admin', vibesAdminRoutes); // VIBES admin endpoints
app.use(healthRoutes); // Mount health routes at root level (additional health endpoints)

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.setHeader('Content-Type', client.register.contentType);
  res.send(await client.register.metrics()); // No timeout - can hang if metrics collection slow
});

// Websocket gateway
setupWebSocketGateway(wss);

// Partition management cron job (if enabled) - parallel import
const partitionManagementPromise = process.env.ENABLE_PARTITION_MANAGEMENT !== 'false'
  ? import('../jobs/partition-management-cron.js').then(({ schedulePartitionManagement }) => {
      schedulePartitionManagement();
    }).catch(err => {
      logError('Failed to load partition management', err);
    })
  : Promise.resolve();

// Expire temporary rooms job (if enabled) - parallel import
const expireRoomsPromise = process.env.ENABLE_ROOM_EXPIRY !== 'false'
  ? import('../jobs/expire-temporary-rooms.js').then(({ default: expireRooms }) => {
      // Schedule to run daily at 2 AM UTC
      const scheduleExpireRooms = () => {
        const now = new Date();
        const nextRun = new Date(now);
        nextRun.setUTCHours(2, 0, 0, 0);
        if (nextRun <= now) {
          nextRun.setUTCDate(nextRun.getUTCDate() + 1);
        }
        const msUntilNext = nextRun.getTime() - now.getTime();
        
        setTimeout(() => {
          expireRooms().catch(err => {
            logError('Room expiry job failed', err);
          });
          // Schedule next run (24 hours later)
          setInterval(() => {
            expireRooms().catch(err => {
              logError('Room expiry job failed', err);
            });
          }, 24 * 60 * 60 * 1000);
        }, msUntilNext);
      };
      
      scheduleExpireRooms();
      logInfo('Room expiry job scheduled');
    }).catch(err => {
      logError('Failed to load room expiry job', err);
    })
  : Promise.resolve();

// VIBES Card Generation Job (if enabled) - parallel import
const cardGenerationPromise = vibesConfig.cardGenerationEnabled
  ? import('../jobs/vibes-card-generation-job.js').then(({ processCardGeneration, processExpiredClaims }) => {
      // Run card generation every 5 minutes
      setInterval(() => {
        processCardGeneration().catch(err => {
          logError('Card generation job failed', err);
        });
      }, 5 * 60 * 1000);
      
      // Process expired claims every minute
      setInterval(() => {
        processExpiredClaims().catch(err => {
          logError('Expired claims job failed', err);
        });
      }, 60 * 1000);
      
      logInfo('VIBES card generation job scheduled');
    }).catch(err => {
      logError('Failed to load card generation job', err);
    })
  : Promise.resolve();

// Phase 8: Data retention cron job (if enabled) - parallel import
const dataRetentionPromise = process.env.ENABLE_DATA_RETENTION !== 'false'
  ? import('../jobs/data-retention-cron.js').then(() => {
      logInfo('Data retention cron job loaded (auto-scheduled)');
    }).catch(err => {
      logError('Failed to load data retention cron job', err);
    })
  : Promise.resolve();

// Wait for all jobs to load in parallel
await Promise.all([partitionManagementPromise, expireRoomsPromise, cardGenerationPromise, dataRetentionPromise]);

// Health endpoint already defined above (before rate limiting)

// Programmatic UI Demo
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
app.get('/ui', (req, res) => {
  res.sendFile(path.join(__dirname, '../../frontend/programmatic-ui-demo.html'));
});

// Debug Stats Endpoint (auth-gated)
app.get('/debug/stats', authMiddleware, async (req, res) => {
  try {
    // Additional debug token check for production (optional extra security layer)
    const debugToken = req.query.token;
    if (process.env.NODE_ENV === 'production' && process.env.DEBUG_TOKEN && debugToken !== process.env.DEBUG_TOKEN) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    
    // Import UX telemetry service dynamically
    const { 
      getRecentSummary, 
      getCategorySummary,
      getPerformanceMetrics,
    } = await import('../services/ux-telemetry-service.js');
    
    // Get aggregated metrics
    const recentSummary = await getRecentSummary(24);
    const categorySummary = await getCategorySummary();
    
    // Get performance metrics
    const performanceMetrics = await getPerformanceMetrics(24);
    
    return res.json({
      timestamp: new Date().toISOString(),
      recent_summary: recentSummary,
      category_summary: categorySummary,
      
      // Performance Linking
      performance_linking: {
        avg_load_time_ms: performanceMetrics?.avgLoadTime || 0,
        avg_interaction_latency_ms: performanceMetrics?.avgInteractionLatency || 0,
        stutter_rate: performanceMetrics?.stutterRate || 0,
        long_state_count: performanceMetrics?.longStateCount || 0,
      },
      
      note: 'UX Telemetry stats - separate from system telemetry. Includes performance linking metrics.',
    });
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return res.status(500).json({ 
      error: 'Failed to fetch stats',
      message: errorMessage,
    });
  }
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  logInfo(`Server running on port ${PORT}`);
});

// Initialize Sin AI worker (parallel import)
Promise.all([
  import('../workers/sin-worker.js').then(({ startSinWorker }) => {
    startSinWorker();
    logInfo('Sin AI worker started');
  }).catch((error) => {
    logInfo('Sin worker not available', error);
  })
]).catch((error) => {
  logError('Failed to initialize workers', error);
});


// Attach error middleware after routes
app.use(errorMiddleware);

