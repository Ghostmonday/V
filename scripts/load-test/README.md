# Load Testing

This directory contains load testing scripts for VibeZ to validate system performance under high load.

## Test Targets

- **10k concurrent users**: System should handle 10,000 simultaneous users
- **10k messages/sec**: Messaging throughput should exceed 10,000 messages per second
- **Response times**: 95% of requests should complete in < 100ms under load

## Tools

### k6

[k6](https://k6.io/) is a modern load testing tool written in Go.

**Installation:**
```bash
# macOS
brew install k6

# Linux
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6

# Windows
choco install k6
```

**Run k6 tests:**
```bash
# Basic run
k6 run scripts/load-test/k6-load-test.js

# With custom base URL
BASE_URL=http://localhost:3000 k6 run scripts/load-test/k6-load-test.js

# With more verbose output
k6 run --verbose scripts/load-test/k6-load-test.js

# Generate HTML report
k6 run --out json=results.json scripts/load-test/k6-load-test.js
k6 report results.json
```

### Artillery

[Artillery](https://www.artillery.io/) is a Node.js-based load testing toolkit.

**Installation:**
```bash
npm install -g artillery
```

**Run Artillery tests:**
```bash
# Basic run
artillery run scripts/load-test/artillery-config.yml

# With custom target
artillery run --target http://localhost:3000 scripts/load-test/artillery-config.yml

# Generate HTML report
artillery run --output results.json scripts/load-test/artillery-config.yml
artillery report results.json
```

## Test Scenarios

### 1. Concurrent Users Test
- Ramp up from 0 to 10,000 concurrent users over 17 minutes
- Sustain 10,000 users for 10 minutes
- Ramp down to 0 over 5 minutes

### 2. Message Throughput Test
- Each user sends 1 message per second
- At 10k users = 10k messages/sec target
- Measures message latency and success rate

### 3. WebSocket Connection Test
- Tests WebSocket connection establishment
- Tests message sending/receiving
- Tests connection stability under load

## Prerequisites

1. **Test Database**: Set up a test database with test users
   ```sql
   -- Create test users
   INSERT INTO users (id, email, password_hash) VALUES
   ('user-1', 'loadtest1@example.com', '$2b$10$...'),
   ('user-2', 'loadtest2@example.com', '$2b$10$...');
   -- ... more test users
   ```

2. **Test Rooms**: Create test rooms for messaging
   ```sql
   INSERT INTO rooms (id, name, is_public) VALUES
   ('room-1', 'Load Test Room 1', true),
   ('room-2', 'Load Test Room 2', true);
   ```

3. **Environment**: Ensure test environment is isolated from production

## Interpreting Results

### Key Metrics

- **Request Duration (p95/p99)**: 95th/99th percentile response times
- **Error Rate**: Percentage of failed requests
- **Throughput**: Requests/messages per second
- **Concurrent Users**: Number of simultaneous users

### Success Criteria

✅ **Pass**: All thresholds met
- p95 latency < 200ms
- p99 latency < 500ms
- Error rate < 1%
- Message latency p95 < 100ms
- Throughput > 10k messages/sec

❌ **Fail**: Any threshold exceeded
- Investigate bottlenecks
- Check database performance
- Review Redis connection pool
- Monitor server resources (CPU, memory)

## Troubleshooting

### High Error Rates
- Check database connection pool size
- Verify Redis is running and accessible
- Check server resource limits (CPU, memory)
- Review rate limiting configuration

### High Latency
- Optimize database queries
- Check Redis cache hit rates
- Review WebSocket connection handling
- Consider horizontal scaling

### Connection Failures
- Check WebSocket server capacity
- Verify load balancer configuration
- Review connection timeout settings

## Continuous Integration

Add load tests to CI/CD pipeline:

```yaml
# .github/workflows/load-test.yml
name: Load Tests
on:
  schedule:
    - cron: '0 2 * * *' # Daily at 2 AM
  workflow_dispatch:

jobs:
  load-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup k6
        run: |
          sudo gpg -k
          sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
          echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
          sudo apt-get update
          sudo apt-get install k6
      - name: Run load tests
        run: k6 run scripts/load-test/k6-load-test.js
```

