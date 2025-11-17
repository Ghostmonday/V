/**
 * Redis Cluster and Sentinel Configuration
 * Supports both Redis Cluster mode and Sentinel mode for high availability
 * 
 * Cluster Mode: For horizontal scaling with sharding
 * Sentinel Mode: For high availability with automatic failover (recommended for most use cases)
 */

import Redis, { Cluster, Sentinel } from 'ioredis';
import { logError, logInfo, logWarning } from '../shared/logger.js';

export type RedisMode = 'single' | 'cluster' | 'sentinel';

export interface RedisClusterConfig {
  mode: RedisMode;
  // Single instance
  url?: string;
  // Cluster mode
  nodes?: Array<{ host: string; port: number }>;
  clusterOptions?: {
    enableReadyCheck?: boolean;
    redisOptions?: any;
  };
  // Sentinel mode
  sentinels?: Array<{ host: string; port: number }>;
  sentinelName?: string;
  sentinelOptions?: {
    enableReadyCheck?: boolean;
    redisOptions?: any;
  };
  // Common options
  retryStrategy?: (times: number) => number | null;
  maxRetriesPerRequest?: number;
  enableOfflineQueue?: boolean;
  connectTimeout?: number;
  lazyConnect?: boolean;
}

/**
 * Parse Redis configuration from environment variables
 * Supports multiple configuration formats:
 * 
 * Single: REDIS_URL=redis://localhost:6379
 * Cluster: REDIS_CLUSTER_NODES=host1:port1,host2:port2,host3:port3
 * Sentinel: REDIS_SENTINELS=host1:port1,host2:port2,host3:port3&REDIS_SENTINEL_NAME=mymaster
 */
export function parseRedisConfig(): RedisClusterConfig {
  const mode = (process.env.REDIS_MODE || 'single').toLowerCase() as RedisMode;
  
  // Single instance mode (default)
  if (mode === 'single') {
    return {
      mode: 'single',
      url: process.env.REDIS_URL || 'redis://localhost:6379',
      retryStrategy: (times: number) => Math.min(times * 50, 2000),
      maxRetriesPerRequest: 3,
      enableOfflineQueue: true,
      connectTimeout: 10000,
    };
  }
  
  // Cluster mode
  if (mode === 'cluster') {
    const clusterNodes = process.env.REDIS_CLUSTER_NODES || '';
    if (!clusterNodes) {
      throw new Error('REDIS_CLUSTER_NODES is required when REDIS_MODE=cluster');
    }
    
    const nodes = clusterNodes.split(',').map(node => {
      const [host, port] = node.trim().split(':');
      return {
        host: host || 'localhost',
        port: parseInt(port || '6379', 10),
      };
    });
    
    return {
      mode: 'cluster',
      nodes,
      clusterOptions: {
        enableReadyCheck: true,
        redisOptions: {
          password: process.env.REDIS_PASSWORD,
          retryStrategy: (times: number) => Math.min(times * 50, 2000),
          maxRetriesPerRequest: 3,
          enableOfflineQueue: true,
          connectTimeout: 10000,
        },
      },
    };
  }
  
  // Sentinel mode (recommended for HA)
  if (mode === 'sentinel') {
    const sentinelsStr = process.env.REDIS_SENTINELS || '';
    const sentinelName = process.env.REDIS_SENTINEL_NAME || 'mymaster';
    
    if (!sentinelsStr) {
      throw new Error('REDIS_SENTINELS is required when REDIS_MODE=sentinel');
    }
    
    const sentinels = sentinelsStr.split(',').map(sentinel => {
      const [host, port] = sentinel.trim().split(':');
      return {
        host: host || 'localhost',
        port: parseInt(port || '26379', 10),
      };
    });
    
    return {
      mode: 'sentinel',
      sentinels,
      sentinelName,
      sentinelOptions: {
        enableReadyCheck: true,
        redisOptions: {
          password: process.env.REDIS_PASSWORD,
          retryStrategy: (times: number) => Math.min(times * 50, 2000),
          maxRetriesPerRequest: 3,
          enableOfflineQueue: true,
          connectTimeout: 10000,
        },
      },
    };
  }
  
  throw new Error(`Invalid REDIS_MODE: ${mode}. Must be 'single', 'cluster', or 'sentinel'`);
}

/**
 * Create Redis client based on configuration
 * Supports single instance, cluster, and sentinel modes
 */
export function createRedisClient(config?: RedisClusterConfig): Redis | Cluster {
  const redisConfig = config || parseRedisConfig();
  
  // Single instance mode
  if (redisConfig.mode === 'single') {
    const client = new Redis(redisConfig.url!, {
      retryStrategy: redisConfig.retryStrategy,
      maxRetriesPerRequest: redisConfig.maxRetriesPerRequest,
      enableOfflineQueue: redisConfig.enableOfflineQueue,
      connectTimeout: redisConfig.connectTimeout,
      lazyConnect: redisConfig.lazyConnect,
    });
    
    setupClientEventHandlers(client, 'single');
    return client;
  }
  
  // Cluster mode
  if (redisConfig.mode === 'cluster') {
    if (!redisConfig.nodes || redisConfig.nodes.length === 0) {
      throw new Error('Cluster nodes are required for cluster mode');
    }
    
    const client = new Cluster(redisConfig.nodes, {
      ...redisConfig.clusterOptions,
      redisOptions: {
        ...redisConfig.clusterOptions?.redisOptions,
        retryStrategy: redisConfig.retryStrategy,
        maxRetriesPerRequest: redisConfig.maxRetriesPerRequest,
        enableOfflineQueue: redisConfig.enableOfflineQueue,
        connectTimeout: redisConfig.connectTimeout,
      },
    });
    
    setupClusterEventHandlers(client);
    return client;
  }
  
  // Sentinel mode
  if (redisConfig.mode === 'sentinel') {
    if (!redisConfig.sentinels || redisConfig.sentinels.length === 0) {
      throw new Error('Sentinels are required for sentinel mode');
    }
    
    const client = new Redis({
      sentinels: redisConfig.sentinels,
      name: redisConfig.sentinelName,
      ...redisConfig.sentinelOptions,
      redisOptions: {
        ...redisConfig.sentinelOptions?.redisOptions,
        retryStrategy: redisConfig.retryStrategy,
        maxRetriesPerRequest: redisConfig.maxRetriesPerRequest,
        enableOfflineQueue: redisConfig.enableOfflineQueue,
        connectTimeout: redisConfig.connectTimeout,
      },
    });
    
    setupClientEventHandlers(client, 'sentinel');
    return client;
  }
  
  throw new Error(`Unsupported Redis mode: ${redisConfig.mode}`);
}

/**
 * Setup event handlers for single instance or sentinel Redis client
 */
function setupClientEventHandlers(client: Redis, mode: string): void {
  client.on('connect', () => {
    logInfo(`Redis ${mode} client connected`);
  });
  
  client.on('ready', () => {
    logInfo(`Redis ${mode} client ready`);
  });
  
  client.on('error', (err) => {
    logError(`Redis ${mode} client error`, err);
  });
  
  client.on('close', () => {
    logWarning(`Redis ${mode} client connection closed`);
  });
  
  client.on('reconnecting', (delay: number) => {
    logInfo(`Redis ${mode} client reconnecting in ${delay}ms`);
  });
  
  client.on('end', () => {
    logWarning(`Redis ${mode} client connection ended`);
  });
}

/**
 * Setup event handlers for Redis Cluster client
 */
function setupClusterEventHandlers(client: Cluster): void {
  client.on('connect', () => {
    logInfo('Redis cluster client connected');
  });
  
  client.on('ready', () => {
    logInfo('Redis cluster client ready');
  });
  
  client.on('error', (err) => {
    logError('Redis cluster client error', err);
  });
  
  client.on('close', () => {
    logWarning('Redis cluster client connection closed');
  });
  
  client.on('reconnecting', (delay: number) => {
    logInfo(`Redis cluster client reconnecting in ${delay}ms`);
  });
  
  client.on('end', () => {
    logWarning('Redis cluster client connection ended');
  });
  
  // Cluster-specific events
  client.on('+node', (node: any) => {
    logInfo(`Redis cluster node added: ${node.options.host}:${node.options.port}`);
  });
  
  client.on('-node', (node: any) => {
    logWarning(`Redis cluster node removed: ${node.options.host}:${node.options.port}`);
  });
  
  client.on('node error', (err: Error, node: any) => {
    logError(`Redis cluster node error: ${node.options.host}:${node.options.port}`, err);
  });
  
  client.on('+move', (slot: number, node: any) => {
    logInfo(`Redis cluster slot ${slot} moved to ${node.options.host}:${node.options.port}`);
  });
}

/**
 * Check if Redis client is healthy
 */
export async function checkRedisHealth(client: Redis | Cluster): Promise<boolean> {
  try {
    const result = await Promise.race([
      client.ping(),
      new Promise((_, reject) => 
        setTimeout(() => reject(new Error('Redis health check timeout')), 5000)
      ),
    ]);
    return result === 'PONG';
  } catch (error) {
    logError('Redis health check failed', error instanceof Error ? error : new Error(String(error)));
    return false;
  }
}

/**
 * Gracefully close Redis client
 */
export async function closeRedisClient(client: Redis | Cluster): Promise<void> {
  try {
    await client.quit();
    logInfo('Redis client closed gracefully');
  } catch (error) {
    logError('Error closing Redis client', error instanceof Error ? error : new Error(String(error)));
    // Force disconnect if quit fails
    client.disconnect();
  }
}


