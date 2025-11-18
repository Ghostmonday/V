/**
 * Node.js Clustering Support
 * Enables multi-process WebSocket handling for better scalability
 *
 * Usage: Set ENABLE_CLUSTERING=true to enable clustering mode
 * The cluster module will spawn worker processes, each handling WebSocket connections
 */

import cluster from 'cluster';
import os from 'os';
import { logInfo, logError } from '../shared/logger.js';

const ENABLE_CLUSTERING = process.env.ENABLE_CLUSTERING === 'true';
const WORKER_COUNT = parseInt(process.env.CLUSTER_WORKER_COUNT || String(os.cpus().length), 10);

/**
 * Setup cluster master process
 * Spawns worker processes and handles worker lifecycle
 */
export function setupCluster(callback: () => void): void {
  if (!ENABLE_CLUSTERING) {
    // Clustering disabled - run callback directly
    callback();
    return;
  }

  if (cluster.isPrimary) {
    // Master process - spawn workers
    logInfo(`Starting cluster with ${WORKER_COUNT} workers`);

    // Spawn workers
    for (let i = 0; i < WORKER_COUNT; i++) {
      const worker = cluster.fork();
      logInfo(`Worker ${worker.process.pid} spawned`);
    }

    // Handle worker exit - restart if crashed
    cluster.on('exit', (worker, code, signal) => {
      logError(`Worker ${worker.process.pid} died`, new Error(`Code: ${code}, Signal: ${signal}`));
      logInfo('Spawning new worker to replace dead worker');
      const newWorker = cluster.fork();
      logInfo(`Worker ${newWorker.process.pid} spawned`);
    });

    // Handle worker online
    cluster.on('online', (worker) => {
      logInfo(`Worker ${worker.process.pid} is online`);
    });

    // Handle worker disconnect
    cluster.on('disconnect', (worker) => {
      logInfo(`Worker ${worker.process.pid} disconnected`);
    });
  } else {
    // Worker process - run the server
    logInfo(`Worker ${process.pid} starting server`);
    callback();
  }
}

/**
 * Check if current process is a worker
 */
export function isWorker(): boolean {
  return ENABLE_CLUSTERING && cluster.isWorker;
}

/**
 * Get worker ID (for logging/debugging)
 */
export function getWorkerId(): string {
  if (cluster.isPrimary) {
    return 'master';
  }
  return `worker-${process.pid}`;
}
