import WebSocket from 'ws';
import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';
import fetch from 'node-fetch';

dotenv.config();

/**
 * VibeZ Stress Testing Script
 * Tests WebSocket connections, message throughput, and API performance
 * 
 * Usage:
 *   JWT_SECRET=your_secret npm run stress-test -- --connections 100 --messages 1000 --duration 60
 */

const args = process.argv.slice(2);
const config = {
  connections: parseInt(args.find(a => a.startsWith('--connections'))?.split('=')[1] || '100'),
  messages: parseInt(args.find(a => a.startsWith('--messages'))?.split('=')[1] || '1000'),
  duration: parseInt(args.find(a => a.startsWith('--duration'))?.split('=')[1] || '60'),
  baseUrl: args.find(a => a.startsWith('--url'))?.split('=')[1] || 'ws://localhost:3000',
  apiUrl: args.find(a => a.startsWith('--api'))?.split('=')[1] || 'http://localhost:3000',
  jwtSecret: process.env.JWT_SECRET,
};

interface Metrics {
  connections: {
    total: number;
    successful: number;
    failed: number;
    active: number;
  };
  messages: {
    sent: number;
    received: number;
    failed: number;
    latency: number[];
  };
  api: {
    requests: number;
    success: number;
    failed: number;
    latency: number[];
  };
}

const metrics: Metrics = {
  connections: { total: 0, successful: 0, failed: 0, active: 0 },
  messages: { sent: 0, received: 0, failed: 0, latency: [] },
  api: { requests: 0, success: 0, failed: 0, latency: [] },
};

// Generate test user IDs
function generateUserId(index: number): string {
  return `stress-test-user-${index}-${Date.now()}`;
}

// Get token: either generate locally (fast) or fetch from API (slow/rate-limited)
async function getToken(userId: string): Promise<string> {
  if (config.jwtSecret) {
    // Generate locally
    return jwt.sign({ userId }, config.jwtSecret, { expiresIn: '1h' });
  } else {
    // Fetch from API (fallback)
    // Note: This will likely hit rate limits if used for many users
    // For stress testing without secret, we'll register ONE user and reuse the token
    if (cachedToken) return cachedToken;

    console.log('⚠️  JWT_SECRET not provided. Authenticating via API (single user mode)...');
    try {
      const username = `stress_master_${Date.now()}`;
      const password = 'StressTestPassword123!';

      // Try register
      let response = await fetch(`${config.apiUrl}/api/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password, ageVerified: true }),
      });

      let data: any = await response.json();

      if (!response.ok) {
        // Try login if register failed
        response = await fetch(`${config.apiUrl}/api/auth/login`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ username, password }),
        });
        data = await response.json();
      }

      if (data.jwt) {
        cachedToken = data.jwt;
        return data.jwt;
      } else {
        throw new Error(`Auth failed: ${JSON.stringify(data)}`);
      }
    } catch (error: any) {
      console.error('Failed to authenticate:', error.message);
      process.exit(1);
    }
  }
}

let cachedToken: string | null = null;

// WebSocket stress test
async function testWebSocketConnections() {
  console.log(`\n🔌 Testing ${config.connections} WebSocket connections...`);

  const clients: WebSocket[] = [];
  const startTime = Date.now();

  // Create connections
  for (let i = 0; i < config.connections; i++) {
    const userId = generateUserId(i);
    const token = await getToken(userId);
    // Use /ws path as configured in server
    const url = `${config.baseUrl}/ws?token=${token}`;

    metrics.connections.total++;

    try {
      const ws = new WebSocket(url);

      ws.on('open', () => {
        metrics.connections.successful++;
        metrics.connections.active++;

        // Send test message
        const message = {
          type: 'messaging',
          payload: {
            roomId: 'test-room',
            content: `Test message from ${userId}`,
            timestamp: Date.now(),
          },
        };

        ws.send(JSON.stringify(message));
        metrics.messages.sent++;
      });

      ws.on('message', (data: WebSocket.Data) => {
        metrics.messages.received++;
        try {
          const parsed = JSON.parse(data.toString());
          if (parsed.payload && parsed.payload.timestamp) {
            const latency = Date.now() - parsed.payload.timestamp;
            metrics.messages.latency.push(latency);
          }
        } catch (e) {
          // Ignore parse errors
        }
      });

      ws.on('error', (error) => {
        metrics.connections.failed++;
        metrics.messages.failed++;
        // console.error(`Connection error: ${error.message}`);
      });

      ws.on('close', () => {
        metrics.connections.active--;
      });

      clients.push(ws);
    } catch (error: any) {
      metrics.connections.failed++;
      console.error(`Failed to create connection: ${error.message}`);
    }

    // Rate limit connection creation (20 per second)
    if ((i + 1) % 20 === 0) {
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
  }

  // Wait for all connections to establish
  await new Promise(resolve => setTimeout(resolve, 5000));

  // Send messages at high frequency
  const messageInterval = setInterval(() => {
    clients.forEach((ws, index) => {
      if (ws.readyState === WebSocket.OPEN) {
        const message = {
          type: 'messaging',
          payload: {
            roomId: 'test-room',
            content: `Stress test message ${Date.now()}`,
            timestamp: Date.now(),
          },
        };

        ws.send(JSON.stringify(message));
        metrics.messages.sent++;
      }
    });
  }, 100); // 10 messages per second per connection

  // Run for specified duration
  setTimeout(() => {
    clearInterval(messageInterval);
    clients.forEach(ws => ws.close());

    const duration = (Date.now() - startTime) / 1000;
    console.log(`\n📊 WebSocket Test Results:`);
    console.log(`   Duration: ${duration.toFixed(2)}s`);
    console.log(`   Connections: ${metrics.connections.successful}/${metrics.connections.total} successful`);
    console.log(`   Messages Sent: ${metrics.messages.sent}`);
    console.log(`   Messages Received: ${metrics.messages.received}`);
    console.log(`   Avg Latency: ${metrics.messages.latency.length > 0 ? (metrics.messages.latency.reduce((a, b) => a + b, 0) / metrics.messages.latency.length).toFixed(2) : 0}ms`);
    console.log(`   Throughput: ${(metrics.messages.sent / duration).toFixed(2)} msg/s`);
  }, config.duration * 1000);
}

// API stress test
async function testAPIEndpoints() {
  console.log(`\n🌐 Testing API endpoints...`);

  const endpoints = [
    '/health',
    // '/api/chat-rooms', // Requires auth
  ];

  const startTime = Date.now();
  let requestCount = 0;

  // Get a token for API tests
  const token = await getToken('api-test-user');

  const testInterval = setInterval(async () => {
    for (const endpoint of endpoints) {
      const requestStart = Date.now();
      requestCount++;
      metrics.api.requests++;

      try {
        const response = await fetch(`${config.apiUrl}${endpoint}`, {
          method: 'GET',
          headers: {
            'Authorization': `Bearer ${token}`,
          },
        });

        const latency = Date.now() - requestStart;
        metrics.api.latency.push(latency);

        if (response.ok) {
          metrics.api.success++;
        } else {
          metrics.api.failed++;
        }
      } catch (error) {
        metrics.api.failed++;
        const latency = Date.now() - requestStart;
        metrics.api.latency.push(latency);
      }
    }
  }, 100); // 10 requests per second

  setTimeout(() => {
    clearInterval(testInterval);

    const duration = (Date.now() - startTime) / 1000;
    console.log(`\n📊 API Test Results:`);
    console.log(`   Duration: ${duration.toFixed(2)}s`);
    console.log(`   Requests: ${metrics.api.requests}`);
    console.log(`   Success: ${metrics.api.success}`);
    console.log(`   Failed: ${metrics.api.failed}`);
    console.log(`   Avg Latency: ${metrics.api.latency.length > 0 ? (metrics.api.latency.reduce((a, b) => a + b, 0) / metrics.api.latency.length).toFixed(2) : 0}ms`);
    console.log(`   P95 Latency: ${metrics.api.latency.length > 0 ? calculatePercentile(metrics.api.latency, 95).toFixed(2) : 0}ms`);
    console.log(`   Throughput: ${(metrics.api.requests / duration).toFixed(2)} req/s`);

    printSummary();
  }, config.duration * 1000);
}

function calculatePercentile(arr: number[], percentile: number): number {
  const sorted = [...arr].sort((a, b) => a - b);
  const index = Math.ceil((percentile / 100) * sorted.length) - 1;
  return sorted[index] || 0;
}

function printSummary() {
  console.log(`\n📈 Overall Summary:`);
  console.log(`   Total Connections: ${metrics.connections.total}`);
  console.log(`   Successful Connections: ${metrics.connections.successful} (${((metrics.connections.successful / metrics.connections.total) * 100).toFixed(2)}%)`);
  console.log(`   Total Messages: ${metrics.messages.sent} sent, ${metrics.messages.received} received`);
  console.log(`   API Requests: ${metrics.api.requests} (${metrics.api.success} success, ${metrics.api.failed} failed)`);
  console.log(`\n✅ Stress test complete!\n`);
}

// Run tests
async function runStressTest() {
  console.log(`\n🚀 Starting VibeZ Stress Test`);
  console.log(`   Connections: ${config.connections}`);
  console.log(`   Duration: ${config.duration}s`);
  console.log(`   Base URL: ${config.baseUrl}`);

  if (!config.jwtSecret) {
    console.log(`   ⚠️  JWT_SECRET not found in env. Using API fallback (limited concurrency).`);
  }

  await Promise.all([
    testWebSocketConnections(),
    testAPIEndpoints(),
  ]);
}

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('\n\n⚠️  Test interrupted. Printing current metrics...');
  printSummary();
  process.exit(0);
});

runStressTest().catch(console.error);
