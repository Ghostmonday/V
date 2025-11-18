import http from 'http';
import WebSocket from 'ws';

/**
 * VibeZ Stress Testing Script
 * Tests WebSocket connections, message throughput, and API performance
 * 
 * Usage:
 *   node scripts/stress-test.js --connections 100 --messages 1000 --duration 60
 */

const args = process.argv.slice(2);
const config = {
  connections: parseInt(args.find(a => a.startsWith('--connections'))?.split('=')[1] || '100'),
  messages: parseInt(args.find(a => a.startsWith('--messages'))?.split('=')[1] || '1000'),
  duration: parseInt(args.find(a => a.startsWith('--duration'))?.split('=')[1] || '60'),
  baseUrl: args.find(a => a.startsWith('--url'))?.split('=')[1] || 'ws://localhost:3000',
  apiUrl: args.find(a => a.startsWith('--api'))?.split('=')[1] || 'http://localhost:3000',
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
  return `test-user-${index}-${Date.now()}`;
}

// Generate test token (mock - in real test, use actual auth)
function generateToken(userId: string): string {
  return `mock-token-${userId}`;
}

// WebSocket stress test
async function testWebSocketConnections() {
  console.log(`\n🔌 Testing ${config.connections} WebSocket connections...`);
  
  const clients: WebSocket[] = [];
  const startTime = Date.now();
  
  // Create connections
  for (let i = 0; i < config.connections; i++) {
    const userId = generateUserId(i);
    const token = generateToken(userId);
    const url = `${config.baseUrl}?userId=${userId}&token=${token}`;
    
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
        const latency = Date.now() - JSON.parse(data.toString()).timestamp;
        metrics.messages.latency.push(latency);
      });
      
      ws.on('error', (error) => {
        metrics.connections.failed++;
        metrics.messages.failed++;
        console.error(`Connection error: ${error.message}`);
      });
      
      ws.on('close', () => {
        metrics.connections.active--;
      });
      
      clients.push(ws);
    } catch (error: any) {
      metrics.connections.failed++;
      console.error(`Failed to create connection: ${error.message}`);
    }
    
    // Rate limit connections (10 per second)
    if ((i + 1) % 10 === 0) {
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
    '/api/chat-rooms',
    '/api/messaging/test-room',
  ];
  
  const startTime = Date.now();
  let requestCount = 0;
  
  const testInterval = setInterval(async () => {
    for (const endpoint of endpoints) {
      const requestStart = Date.now();
      requestCount++;
      metrics.api.requests++;
      
      try {
        const response = await fetch(`${config.apiUrl}${endpoint}`, {
          method: 'GET',
          headers: {
            'Authorization': `Bearer ${generateToken('test-user')}`,
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

