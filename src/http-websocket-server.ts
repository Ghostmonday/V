/**
 * Main API server
 * - Express HTTP API
 * - WebSocket gateway
 * - Prometheus metrics endpoint
 *
 * Note: TypeScript -> compiled to dist/server/index.js for production.
 */

import 'dotenv/config';
import express, { Request, Response, NextFunction } from 'express';
import cookieParser from 'cookie-parser';
import http from 'http';
import { WebSocketServer } from 'ws';
import * as client from 'prom-client';
import path from 'path';
import { fileURLToPath } from 'url';
import { setupWebSocketGateway } from './ws/websocket-gateway.js';
import fileStorageRoutes from './routes/file-storage-api-routes.js';
import presenceRoutes from './routes/presence-api-routes.js';
import messageRoutes from './routes/message-api-routes.js';
import configRoutes from './routes/config-api-routes.js';
import telemetryRoutes from './routes/telemetry-api-routes.js';
import adminRoutes from './routes/admin-api-routes.js';
import adminModerationRoutes from './routes/admin-moderation-api-routes.js';
import moderationRoutes from './routes/moderation-api-routes.js';
import voiceRoutes from './routes/voice-api-routes.js';
import subscriptionRoutes from './routes/subscription-api-routes.js';
import entitlementsRoutes from './routes/entitlements-api-routes.js';
import healthRoutes from './routes/health-api-routes.js';
import notifyRoutes from './routes/notify-api-routes.js';
import reactionsRoutes from './routes/reactions-api-routes.js';
import searchRoutes from './routes/search-api-routes.js';
import threadsRoutes from './routes/threads-api-routes.js';
import uxTelemetryRoutes from './routes/ux-telemetry-api-routes.js';
import chatRoomConfigRoutes from './routes/chat-room-config-api-routes.js';
import roomRoutes from './routes/room-api-routes.js';
import agoraRoutes from './routes/agora-api-routes.js';
import readReceiptsRoutes from './routes/read-receipts-api-routes.js';
import nicknamesRoutes from './routes/nicknames-api-routes.js';
import pinnedRoutes from './routes/pinned-api-routes.js';
import bandwidthRoutes from './routes/bandwidth-api-routes.js';
import userDataRoutes from './routes/user-data-api-routes.js';
import privacyRoutes from './routes/privacy-api-routes.js';
import inviteRoutes from './routes/invite-api-routes.js';
import gamificationRoutes from './routes/gamification-api-routes.js';
import schedulingRoutes from './routes/scheduling-api-routes.js';
import userSettingsRoutes from './routes/user-settings-api-routes.js';
import authRoutes from './routes/auth-api-routes.js';
import { telemetryMiddleware } from './middleware/monitoring/telemetry-middleware.js';
import { errorMiddleware } from './middleware/error-middleware.js';
import { structuredLogging } from './middleware/monitoring/structured-logging-middleware.js';
import { rateLimit, ipRateLimit } from './middleware/rate-limiting/rate-limiter-middleware.js';
// Removed default rateLimiter import in favor of ipRateLimit
import { sanitizeInput } from './middleware/validation/input-validation-middleware.js';
import { fileUploadSecurity } from './middleware/security/file-upload-security-middleware.js';
import { authMiddleware as supabaseAuthMiddleware } from './middleware/auth/supabase-auth-middleware.js'; // Supabase JWT auth middleware
import helmet from 'helmet';
import csurf from 'csurf';
import { logInfo, logError } from './shared/logger-shared.js';
import { LIMIT_REQUESTS_PER_MIN } from './server-config.js';



const app: any = express();
const server = http.createServer(app as any);
// noServer: true allows us to handle the upgrade manually
const wss = new WebSocketServer({ noServer: true });

// Trust proxy headers (needed for load balancers/reverse proxies)
app.set('trust proxy', 1);

// Handle WebSocket upgrades
server.on('upgrade', (request, socket, head) => {
  // Check if the path is for WebSocket
  if (request.url?.startsWith('/ws') || request.url?.startsWith('/socket.io')) {
    (wss as any).handleUpgrade(request, socket, head, (ws: any) => {
      wss.emit('connection', ws, request);
    });
  } else {
    // Destroy socket if not a valid WebSocket path
    socket.destroy();
  }
});

// collect node metrics for Prometheus
const { register, collectDefaultMetrics } = client as any;
collectDefaultMetrics();

// HTTPS enforcement in production
if (process.env.NODE_ENV === 'production') {
  app.use((req: Request, res: Response, next: NextFunction) => {
    const isHttps = req.secure || req.get('x-forwarded-proto') === 'https';
    
    if (!isHttps) {
      // Preserve query parameters in redirect
      const fullUrl = `https://${req.get('host')}${req.originalUrl}`;
      return res.redirect(308, fullUrl);
    }
    
    next();
  });
}

// CORS middleware - Production-safe configuration
const allowedOrigins = process.env.CORS_ORIGINS?.split(',') || 
  (process.env.NODE_ENV === 'production' 
    ? ['https://vibez.app', 'https://www.vibez.app'] 
    : ['http://localhost:3000', 'http://localhost:5173', 'http://localhost:19006']);

app.use((req: any, res: Response, next: any) => {
  const origin = req.headers.origin;
  
  if (origin && allowedOrigins.includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Access-Control-Allow-Credentials', 'true');
  } else if (!origin) {
    // Allow requests with no origin (e.g., mobile apps, Postman)
    res.setHeader('Access-Control-Allow-Origin', allowedOrigins[0]);
  }
  
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS, PATCH');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With, Accept');
  
  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }
  
  if (next) next();
});

// Security middleware - Helmet with strict CSP
app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'"], // 'unsafe-inline' needed for some UI frameworks
        scriptSrc: ["'self'"], // No inline scripts - XSS protection
        imgSrc: ["'self'", 'data:', 'https:'], // Allow images from HTTPS sources
        connectSrc: ["'self'", 'wss:', 'ws:'], // WebSocket connections
        fontSrc: ["'self'", 'data:'],
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
  }) as any
);

// Phase 6.1: Structured logging middleware (after security, before routes)
app.use(structuredLogging);

// Health endpoint - must be public (before rate limiting and auth)
app.get('/health', (req: Request, res: Response) => res.json({ status: 'ok', ts: new Date().toISOString() }));

import { checkSupabaseHealth, checkRedisHealthStatus } from './config/database-config.js';

app.get('/healthz', async (req: Request, res: Response) => {
  const [postgres, redis] = await Promise.all([
    checkSupabaseHealth(),
    checkRedisHealthStatus()
  ]);

  const status = postgres && redis ? 200 : 503;

  res.status(status).json({
    status: status === 200 ? 'ok' : 'error',
    timestamp: new Date().toISOString(),
    services: {
      postgres: postgres ? 'up' : 'down',
      redis: redis ? 'up' : 'down',
    },
  });
});

// Security.txt endpoint (RFC 9116)
app.get('/.well-known/security.txt', (req: Request, res: Response) => {
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

// Robust rate limiting - 100 requests per minute per IP (fails open if Redis unavailable)
app.use(ipRateLimit(100, 60000));

// Supabase JWT authentication middleware - sets req.user if token present, allows through if not
app.use(supabaseAuthMiddleware);

// Middleware
app.use(cookieParser()); // Parse cookies for HTTP-only token storage
app.use((express as any).json({ limit: '10mb' })); // Limit request size
app.use((express as any).urlencoded({ extended: true, limit: '10mb' }));
app.use(sanitizeInput); // SECURITY: Sanitize all input before processing

// CSRF protection (skip for API endpoints, WebSocket, and health checks)
const csrfProtection = csurf({
  cookie: { httpOnly: true, secure: process.env.NODE_ENV === 'production', sameSite: 'strict' },
  ignoreMethods: ['GET', 'HEAD', 'OPTIONS'],
});
app.use((req: Request, res: Response, next: any) => {
  // Skip CSRF for API endpoints, WebSocket upgrade, and health checks
  if (
    (req as any).path.startsWith('/api/') ||
    (req as any).path.startsWith('/metrics') ||
    (req as any).path === '/health' ||
    req.headers.upgrade === 'websocket'
  ) {
    if (next) return next();
    return;
  }
  csrfProtection(req, res, next as NextFunction);
});

app.use(telemetryMiddleware);

// Routes
app.use('/files', fileStorageRoutes as any);
app.use('/presence', presenceRoutes as any);
app.use('/messaging', messageRoutes as any);
app.use('/config', configRoutes as any);
app.use('/telemetry', telemetryRoutes as any);
app.use('/admin', adminRoutes as any);
app.use('/admin/moderation', adminModerationRoutes as any);
app.use('/api/moderation', moderationRoutes as any); // User-facing moderation endpoints
app.use('/voice', voiceRoutes as any);
app.use('/subscription', subscriptionRoutes as any);
app.use('/entitlements', entitlementsRoutes as any);
import { appStoreWebhook } from './services/webhooks-service.js';
app.post('/appstore-webhook', appStoreWebhook);
// Note: Admin routes are mounted at /admin only (removed duplicate /api mount)
app.use('/api/notify', notifyRoutes as any);
app.use('/api/reactions', reactionsRoutes as any);
app.use('/api/search', searchRoutes as any);
app.use('/api/threads', threadsRoutes as any);
app.use('/api/ux-telemetry', uxTelemetryRoutes as any); // UX Telemetry (separate from system telemetry)
app.use('/api/users', userDataRoutes as any); // GDPR user data endpoints
app.use('/api/privacy', privacyRoutes as any); // Privacy & ZKP endpoints
app.use('/api/read-receipts', readReceiptsRoutes as any); // Read receipts endpoints
app.use('/api/nicknames', nicknamesRoutes as any); // Nicknames endpoints
app.use('/api/pinned', pinnedRoutes as any); // Pinned items endpoints
app.use('/api/bandwidth', bandwidthRoutes as any); // Bandwidth mode endpoints
app.use('/api/invites', inviteRoutes as any);
app.use('/api/gamification', gamificationRoutes as any);
app.use('/api/scheduling', schedulingRoutes as any);
app.use('/api/settings', userSettingsRoutes as any);
app.use('/api/auth', authRoutes as any);
app.use('/chat_rooms', chatRoomConfigRoutes as any); // Room configuration endpoints
app.use('/', roomRoutes as any); // Room creation and join endpoints (POST /chat-rooms, POST /chat-rooms/:id/join)
app.use('/rooms', agoraRoutes as any); // Agora room management (mute, video, members, leave)
app.use(healthRoutes as any); // Mount health routes at root level (additional health endpoints)

// Metrics endpoint
app.get('/metrics', async (req: Request, res: Response) => {
  res.setHeader('Content-Type', register.contentType);
  res.send(await register.metrics()); // No timeout - can hang if metrics collection slow
});

// Websocket gateway
setupWebSocketGateway(wss);

// Partition management cron job (if enabled) - parallel import
const partitionManagementPromise =
  process.env.ENABLE_PARTITION_MANAGEMENT !== 'false'
    ? import('./jobs/partition-management-cron-job.js')
      .then(({ schedulePartitionManagement }) => {
        schedulePartitionManagement();
      })
      .catch((err) => {
        logError('Failed to load partition management', err);
      })
    : Promise.resolve();

// Expire temporary rooms job (if enabled) - parallel import
const expireRoomsPromise =
  process.env.ENABLE_ROOM_EXPIRY !== 'false'
    ? import('./jobs/expire-temporary-rooms-cron-job.js')
      .then(({ default: expireRooms }) => {
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
            expireRooms().catch((err) => {
              logError('Room expiry job failed', err);
            });
            // Schedule next run (24 hours later)
            setInterval(
              () => {
                expireRooms().catch((err) => {
                  logError('Room expiry job failed', err);
                });
              },
              24 * 60 * 60 * 1000
            );
          }, msUntilNext);
        };

        scheduleExpireRooms();
        logInfo('Room expiry job scheduled');
      })
      .catch((err) => {
        logError('Failed to load room expiry job', err);
      })
    : Promise.resolve();

// Phase 8: Data retention cron job (if enabled) - parallel import
const dataRetentionPromise =
  process.env.ENABLE_DATA_RETENTION !== 'false'
    ? import('./jobs/data-retention-cron-job.js')
      .then(() => {
        logInfo('Data retention cron job loaded (auto-scheduled)');
      })
      .catch((err) => {
        logError('Failed to load data retention cron job', err);
      })
    : Promise.resolve();

// Wait for all jobs to load in parallel
await Promise.all([partitionManagementPromise, expireRoomsPromise, dataRetentionPromise]);

// Health endpoint already defined above (before rate limiting)

// Programmatic UI Demo
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
app.get('/ui', (req: Request, res: Response) => {
  (res as any).sendFile(path.join(__dirname, '../../frontend/programmatic-ui-demo.html'));
});

// Debug Stats Endpoint (auth-gated)
app.get('/debug/stats', supabaseAuthMiddleware, async (req: Request, res: Response) => {
  try {
    // Additional debug token check for production (optional extra security layer)
    const debugToken = req.query.token;
    if (
      process.env.NODE_ENV === 'production' &&
      process.env.DEBUG_TOKEN &&
      debugToken !== process.env.DEBUG_TOKEN
    ) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    // Import UX telemetry service dynamically
    const { getRecentSummary, getCategorySummary, getPerformanceMetrics } = await import(
      './services/ux-telemetry-service.js'
    );

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

app.get('/health', (req: Request, res: Response) => res.json({ status: 'ok', uptime: Math.floor(process.uptime() * 1000) }));

// ... (rest of file)

const PORT = process.env.PORT || 3000;
server.listen(PORT as number, '0.0.0.0', () => {
  logInfo(`Server running on port ${PORT}`);
});

// Initialize Sin AI worker (parallel import)
Promise.all([
  import('./workers/sin-ai-worker.js')
    .then(({ startSinWorker }) => {
      startSinWorker();
      logInfo('Sin AI worker started');
    })
    .catch((error) => {
      logInfo('Sin worker not available', error);
    }),
]).catch((error) => {
  logError('Failed to initialize workers', error);
});

// Attach error middleware after routes
app.use(errorMiddleware);

// Graceful shutdown: Close HTTP server, WebSocket server, and Redis client
const shutdown = async (signal: string) => {
  logInfo(`${signal} received, starting graceful shutdown...`);

  // 1. Stop accepting new connections
  server.close(() => {
    logInfo('HTTP server closed');
  });

  // 2. Close WebSocket server
  wss.close(() => {
    logInfo('WebSocket server closed');
  });

  // 3. Close Redis client
  try {
    const { getRedisClient } = await import('./config/database-config.js');
    const redisClient = getRedisClient();
    if (redisClient && typeof redisClient.quit === 'function') {
      await redisClient.quit();
      logInfo('Redis client closed successfully');
    }
  } catch (err) {
    logError('Error closing Redis client', err instanceof Error ? err : new Error(String(err)));
  }

  // 4. Exit
  logInfo('Graceful shutdown complete');
  process.exit(0);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
