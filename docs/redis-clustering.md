# Redis Clustering and Replication Setup

This document describes how to configure Redis clustering and replication for high availability in VibeZ.

## Overview

VibeZ supports three Redis deployment modes:

1. **Single Instance** (default): Simple single Redis server
2. **Redis Cluster**: Horizontal scaling with automatic sharding
3. **Redis Sentinel** (recommended): High availability with automatic failover

## Configuration

### Environment Variables

#### Single Instance Mode (Default)

```bash
REDIS_MODE=single
REDIS_URL=redis://localhost:6379
REDIS_PASSWORD=optional_password
```

#### Cluster Mode

```bash
REDIS_MODE=cluster
REDIS_CLUSTER_NODES=node1:7000,node2:7001,node3:7002
REDIS_PASSWORD=optional_password
```

#### Sentinel Mode (Recommended for HA)

```bash
REDIS_MODE=sentinel
REDIS_SENTINELS=sentinel1:26379,sentinel2:26380,sentinel3:26381
REDIS_SENTINEL_NAME=mymaster
REDIS_PASSWORD=optional_password
```

## Redis Sentinel Setup (Recommended)

Redis Sentinel provides automatic failover and is recommended for production deployments.

### Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Sentinel 1 │     │  Sentinel 2 │     │  Sentinel 3 │
│   :26379    │     │   :26380    │     │   :26381    │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │
              ┌────────────┴────────────┐
              │                         │
       ┌──────▼──────┐          ┌──────▼──────┐
       │   Master    │          │   Replica   │
       │  :6379      │◄─────────│  :6380      │
       └─────────────┘          └─────────────┘
```

### Setup Instructions

1. **Start Redis Master**:

```bash
redis-server --port 6379 --requirepass yourpassword
```

2. **Start Redis Replica**:

```bash
redis-server --port 6380 --requirepass yourpassword --replicaof localhost 6379
```

3. **Start Sentinel Instances**:

```bash
# Sentinel 1
redis-sentinel sentinel1.conf --port 26379

# Sentinel 2
redis-sentinel sentinel2.conf --port 26380

# Sentinel 3
redis-sentinel sentinel3.conf --port 26381
```

4. **Sentinel Configuration** (`sentinel1.conf`):

```
port 26379
sentinel monitor mymaster localhost 6379 2
sentinel auth-pass mymaster yourpassword
sentinel down-after-milliseconds mymaster 5000
sentinel parallel-syncs mymaster 1
sentinel failover-timeout mymaster 10000
```

5. **Configure VibeZ**:

```bash
REDIS_MODE=sentinel
REDIS_SENTINELS=localhost:26379,localhost:26380,localhost:26381
REDIS_SENTINEL_NAME=mymaster
REDIS_PASSWORD=yourpassword
```

## Redis Cluster Setup

Redis Cluster provides horizontal scaling with automatic sharding.

### Architecture

```
┌──────────┐  ┌──────────┐  ┌──────────┐
│ Node 1   │  │ Node 2   │  │ Node 3   │
│ :7000    │  │ :7001    │  │ :7002    │
│ (Master) │  │ (Master) │  │ (Master) │
└────┬─────┘  └────┬─────┘  └────┬─────┘
     │            │            │
     └────────────┼────────────┘
                  │
     ┌────────────┼────────────┐
     │            │            │
┌────▼─────┐ ┌───▼────┐ ┌─────▼─────┐
│ Replica  │ │Replica │ │ Replica   │
│ :7003    │ │:7004   │ │ :7005     │
└──────────┘ └────────┘ └───────────┘
```

### Setup Instructions

1. **Create Cluster Configuration**:

```bash
# Create directories
mkdir -p cluster/{7000,7001,7002,7003,7004,7005}

# Create config files
for port in 7000 7001 7002 7003 7004 7005; do
  cat > cluster/$port/redis.conf <<EOF
port $port
cluster-enabled yes
cluster-config-file nodes-$port.conf
cluster-node-timeout 5000
appendonly yes
EOF
done
```

2. **Start Cluster Nodes**:

```bash
for port in 7000 7001 7002 7003 7004 7005; do
  redis-server cluster/$port/redis.conf &
done
```

3. **Create Cluster**:

```bash
redis-cli --cluster create \
  127.0.0.1:7000 127.0.0.1:7001 127.0.0.1:7002 \
  127.0.0.1:7003 127.0.0.1:7004 127.0.0.1:7005 \
  --cluster-replicas 1
```

4. **Configure VibeZ**:

```bash
REDIS_MODE=cluster
REDIS_CLUSTER_NODES=localhost:7000,localhost:7001,localhost:7002
REDIS_PASSWORD=optional_password
```

## Failover Behavior

### Automatic Failover

The system automatically handles:

1. **Connection Failures**: Exponential backoff retry (50ms, 100ms, 150ms... up to 2s)
2. **Master Failover**: Automatic switch to replica (Sentinel mode)
3. **Node Failures**: Automatic routing to available nodes (Cluster mode)
4. **Reconnection**: Automatic reconnection with subscription restoration

### Monitoring

Health checks run every 30 seconds:

```typescript
import { checkRedisHealthStatus } from './config/db.js';

const healthy = await checkRedisHealthStatus();
if (!healthy) {
  // Handle unhealthy state
}
```

### Event Handlers

The system logs important events:

- `Redis connected`: Initial connection established
- `Redis reconnecting`: Reconnection in progress
- `Redis failover completed`: Failover to new master
- `Redis cluster slot moved`: Cluster rebalancing

## WebSocket Gateway Integration

The WebSocket gateway automatically:

1. **Reconnects** on Redis failures
2. **Resubscribes** to channels after reconnection
3. **Continues broadcasting** during failover (with retry)
4. **Handles** cross-process message routing

## Testing Failover

### Test Sentinel Failover

```bash
# 1. Start Redis with Sentinel
# 2. Connect VibeZ
# 3. Simulate master failure
redis-cli -p 6379 DEBUG SEGFAULT

# 4. Verify automatic failover
# Check logs for "Redis failover completed"
```

### Test Cluster Failover

```bash
# 1. Start Redis Cluster
# 2. Connect VibeZ
# 3. Simulate node failure
redis-cli -p 7000 DEBUG SEGFAULT

# 4. Verify automatic routing
# Check logs for "Redis cluster slot moved"
```

## Production Recommendations

1. **Use Sentinel Mode**: Best for high availability with automatic failover
2. **Deploy 3+ Sentinels**: Quorum-based failover decisions
3. **Monitor Health**: Use health check endpoints
4. **Set Passwords**: Always use `REDIS_PASSWORD` in production
5. **Network Isolation**: Use private networks for Redis communication
6. **Backup Strategy**: Regular RDB/AOF backups

## Troubleshooting

### Connection Issues

```bash
# Check Redis connectivity
redis-cli -h localhost -p 6379 ping

# Check Sentinel status
redis-cli -p 26379 SENTINEL masters

# Check Cluster status
redis-cli -p 7000 CLUSTER INFO
```

### Common Errors

1. **ECONNREFUSED**: Redis not running or wrong port
2. **ETIMEDOUT**: Network issues or firewall blocking
3. **MOVED**: Cluster slot moved (normal in cluster mode)
4. **ASK**: Cluster redirection (normal in cluster mode)

## Performance Considerations

- **Pub/Sub**: Separate connections for publisher and subscriber
- **Connection Pooling**: Singleton pattern for connection reuse
- **Retry Strategy**: Exponential backoff prevents thundering herd
- **Health Checks**: 30-second intervals balance responsiveness and overhead
