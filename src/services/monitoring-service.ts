/**
 * Monitoring Service
 * Prometheus/Grafana metrics collection
 * Tracks rate limits, sentiment, errors, and performance
 */

import client from 'prom-client';
import { logError } from '../shared/logger.js';

// Rate limit metrics
export const rateLimitCounter = new client.Counter({
  name: 'rate_limit_hits_total',
  help: 'Total number of rate limit hits',
  labelNames: ['endpoint', 'type'], // type: 'user', 'ip', 'ws_message'
});

export const rateLimitGauge = new client.Gauge({
  name: 'rate_limit_active_users',
  help: 'Number of users currently rate limited',
  labelNames: ['type'],
});

// Message metrics (replaces sentiment metrics)
export const messageCounter = new client.Counter({
  name: 'messages_total',
  help: 'Total number of messages processed',
  labelNames: ['type'], // type: 'text', 'image', 'voice'
});

export const sentimentHistogram = new client.Histogram({
  name: 'sentiment_polarity',
  help: 'Sentiment polarity distribution',
  buckets: [-1, -0.6, -0.3, 0, 0.3, 0.6, 1],
});

// Moderation metrics
export const moderationCounter = new client.Counter({
  name: 'moderation_actions_total',
  help: 'Total moderation actions',
  labelNames: ['action'], // action: 'flag', 'warn', 'mute', 'ban'
});

export const toxicityScoreHistogram = new client.Histogram({
  name: 'toxicity_score',
  help: 'Toxicity score distribution',
  buckets: [0, 0.3, 0.5, 0.7, 0.9, 1.0],
});

// Error metrics
export const errorCounter = new client.Counter({
  name: 'errors_total',
  help: 'Total number of errors',
  labelNames: ['type', 'endpoint'], // type: 'auth', 'db', 'ws', 'api'
});

// Performance metrics
export const requestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.1, 0.5, 1, 2, 5, 10],
});

export const websocketConnections = new client.Gauge({
  name: 'websocket_connections_active',
  help: 'Number of active WebSocket connections',
});

export const databaseQueryDuration = new client.Histogram({
  name: 'database_query_duration_seconds',
  help: 'Database query duration in seconds',
  labelNames: ['table', 'operation'],
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 2, 5],
});

/**
 * Record rate limit hit
 */
export function recordRateLimitHit(endpoint: string, type: 'user' | 'ip' | 'ws_message'): void {
  rateLimitCounter.inc({ endpoint, type });
}

/**
 * Record message processing (replaces sentiment-specific tracking)
 */
export function recordMessageProcessed(type: 'text' | 'image' | 'voice'): void {
  messageCounter.inc({ type });
}

/**
 * Record sentiment analysis (for moderation purposes)
 * @deprecated Use recordMessageProcessed for general message tracking
 */
export function recordSentiment(mood: 'happy' | 'sad' | 'neutral', polarity: number): void {
  // Keep for backward compatibility, but prefer recordMessageProcessed
  messageCounter.inc({ type: 'text' });
  sentimentHistogram.observe(polarity);
}

/**
 * Record moderation action
 */
export function recordModerationAction(action: 'flag' | 'warn' | 'mute' | 'ban'): void {
  moderationCounter.inc({ action });
}

/**
 * Record toxicity score
 */
export function recordToxicityScore(score: number): void {
  toxicityScoreHistogram.observe(score);
}

/**
 * Record error
 */
export function recordError(type: string, endpoint: string): void {
  errorCounter.inc({ type, endpoint });
}

/**
 * Record request duration
 */
export function recordRequestDuration(
  method: string,
  route: string,
  status: number,
  duration: number
): void {
  requestDuration.observe({ method, route, status: status.toString() }, duration / 1000);
}

/**
 * Update WebSocket connection count
 */
export function updateWebSocketConnections(count: number): void {
  websocketConnections.set(count);
}

/**
 * Record database query duration
 */
export function recordDatabaseQuery(table: string, operation: string, duration: number): void {
  databaseQueryDuration.observe({ table, operation }, duration / 1000);
}
