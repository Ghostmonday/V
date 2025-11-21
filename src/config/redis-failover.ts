/**
 * Redis Failover Handler
 * Manages failover scenarios and reconnection logic for Redis Cluster and Sentinel
 */

import Redis, { Cluster } from 'ioredis';
import { logError, logInfo, logWarning } from '../shared/logger-shared.js';
import { checkRedisHealth, createRedisClient, parseRedisConfig } from './redis-cluster.js';

export interface FailoverHandler {
  onFailover: (newMaster: string) => void;
  onReconnect: () => void;
  onError: (error: Error) => void;
}

/**
 * Setup failover handlers for Redis client
 * Monitors connection health and handles failover scenarios
 */
export function setupFailoverHandlers(
  client: Redis.Redis | Cluster,
  handlers?: Partial<FailoverHandler>
): void {
  let reconnectAttempts = 0;
  const maxReconnectAttempts = 10;
  let isReconnecting = false;
  
  // Track last successful operation
  let lastHealthCheck = Date.now();
  const healthCheckInterval = 30000; // 30 seconds
  
  // Periodic health check
  const healthCheck = setInterval(async () => {
    try {
      const healthy = await checkRedisHealth(client);
      if (healthy) {
        lastHealthCheck = Date.now();
        reconnectAttempts = 0; // Reset on successful health check
        if (isReconnecting) {
          isReconnecting = false;
          handlers?.onReconnect?.();
          logInfo('Redis reconnected successfully');
        }
      } else {
        logWarning('Redis health check failed');
      }
    } catch (error) {
      logError('Redis health check error', error instanceof Error ? error : new Error(String(error)));
    }
  }, healthCheckInterval);
  
  // Error handler
  client.on('error', (err: Error) => {
    logError('Redis client error', err);
    handlers?.onError?.(err);
    
    // Check if this is a connection error
    if (err.message.includes('ECONNREFUSED') || err.message.includes('ETIMEDOUT')) {
      if (!isReconnecting && reconnectAttempts < maxReconnectAttempts) {
        isReconnecting = true;
        reconnectAttempts++;
        logWarning(`Redis connection lost, attempting reconnection (${reconnectAttempts}/${maxReconnectAttempts})`);
      }
    }
  });
  
  // Reconnecting handler
  client.on('reconnecting', (delay: number) => {
    logInfo(`Redis reconnecting in ${delay}ms (attempt ${reconnectAttempts})`);
  });
  
  // Cluster-specific failover handlers
  if (client instanceof Cluster) {
    // Node added to cluster
    client.on('+node', (node: any) => {
      logInfo(`Redis cluster node added: ${node.options.host}:${node.options.port}`);
    });
    
    // Node removed from cluster
    client.on('-node', (node: any) => {
      logWarning(`Redis cluster node removed: ${node.options.host}:${node.options.port}`);
    });
    
    // Slot moved (failover scenario)
    client.on('+move', (slot: number, node: any) => {
      const newMaster = `${node.options.host}:${node.options.port}`;
      logInfo(`Redis cluster slot ${slot} moved to ${newMaster} (failover detected)`);
      handlers?.onFailover?.(newMaster);
    });
  }
  
  // Sentinel-specific failover handlers
  if (client instanceof Redis && (client as any).connector?.name === 'sentinel') {
    // Monitor for failover events
    client.on('sentinelReconnect', () => {
      logInfo('Redis Sentinel reconnected');
    });
    
    // Note: Sentinel failover is handled automatically by ioredis
    // The client will automatically switch to the new master
    client.on('ready', () => {
      const currentMaster = (client as any).connector?.sentinel?.getCurrentMaster();
      if (currentMaster) {
        logInfo(`Redis connected to master: ${currentMaster.host}:${currentMaster.port}`);
      }
    });
  }
  
  // Cleanup on disconnect
  client.on('end', () => {
    clearInterval(healthCheck);
  });
}

/**
 * Create a resilient Redis client with failover support
 * Automatically handles reconnection and failover scenarios
 */
export function createResilientRedisClient(): Redis.Redis | Cluster {
  const config = parseRedisConfig();
  const client = createRedisClient(config);
  
  setupFailoverHandlers(client, {
    onFailover: (newMaster: string) => {
      logInfo(`Redis failover completed, new master: ${newMaster}`);
    },
    onReconnect: () => {
      logInfo('Redis reconnected after failover');
    },
    onError: (error: Error) => {
      logError('Redis failover error', error);
    },
  });
  
  return client;
}

/**
 * Wait for Redis to be ready (with timeout)
 */
export async function waitForRedisReady(
  client: Redis.Redis | Cluster,
  timeout: number = 10000
): Promise<boolean> {
  return new Promise((resolve) => {
    const startTime = Date.now();
    
    const checkReady = () => {
      if (client.status === 'ready') {
        resolve(true);
        return;
      }
      
      if (Date.now() - startTime > timeout) {
        logWarning('Redis ready check timeout');
        resolve(false);
        return;
      }
      
      setTimeout(checkReady, 100);
    };
    
    // If already ready, resolve immediately
    if (client.status === 'ready') {
      resolve(true);
      return;
    }
    
    // Wait for ready event
    client.once('ready', () => {
      resolve(true);
    });
    
    // Start checking
    checkReady();
  });
}


