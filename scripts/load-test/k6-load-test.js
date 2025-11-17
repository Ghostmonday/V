/**
 * k6 Load Testing Script
 * Tests 10k concurrent users and 10k messages/sec throughput
 * 
 * Install k6: https://k6.io/docs/getting-started/installation/
 * Run: k6 run scripts/load-test/k6-load-test.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const messageLatency = new Trend('message_latency');
const messageCount = new Counter('messages_sent');

// Test configuration
export const options = {
  stages: [
    { duration: '2m', target: 1000 },   // Ramp up to 1k users
    { duration: '5m', target: 5000 },   // Ramp up to 5k users
    { duration: '10m', target: 10000 },  // Ramp up to 10k users
    { duration: '10m', target: 10000 }, // Stay at 10k users
    { duration: '5m', target: 0 },       // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<200', 'p(99)<500'], // 95% < 200ms, 99% < 500ms
    http_req_failed: ['rate<0.01'],                // Error rate < 1%
    errors: ['rate<0.01'],                         // Custom error rate < 1%
    message_latency: ['p(95)<100'],                 // 95% of messages < 100ms
  },
};

// Base URL
const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

// Test user credentials (should be created in test database)
const TEST_USERS = [
  { email: 'loadtest1@example.com', password: 'password123' },
  { email: 'loadtest2@example.com', password: 'password123' },
  // Add more test users as needed
];

/**
 * Login and get access token
 */
function login(userIndex) {
  const user = TEST_USERS[userIndex % TEST_USERS.length];
  const res = http.post(`${BASE_URL}/auth/login`, JSON.stringify({
    email: user.email,
    password: user.password,
  }), {
    headers: { 'Content-Type': 'application/json' },
  });

  const success = check(res, {
    'login successful': (r) => r.status === 200,
    'has access token': (r) => JSON.parse(r.body).accessToken !== undefined,
  });

  if (!success) {
    errorRate.add(1);
    return null;
  }

  return JSON.parse(res.body).accessToken;
}

/**
 * Send a message
 */
function sendMessage(token, roomId, content) {
  const startTime = Date.now();
  
  const res = http.post(
    `${BASE_URL}/api/messages`,
    JSON.stringify({
      roomId,
      content,
    }),
    {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
    }
  );

  const latency = Date.now() - startTime;
  messageLatency.add(latency);
  messageCount.add(1);

  const success = check(res, {
    'message sent': (r) => r.status === 200 || r.status === 201,
  });

  if (!success) {
    errorRate.add(1);
  }

  return success;
}

/**
 * Main test function
 */
export default function () {
  // Login
  const userIndex = __VU; // Virtual user ID
  const token = login(userIndex);
  
  if (!token) {
    return; // Skip if login failed
  }

  // Simulate user behavior
  const roomId = `room-${userIndex % 100}`; // Distribute across 100 rooms
  
  // Send messages at rate of ~10k/sec across all users
  // Each user sends 1 message per second = 10k messages/sec at 10k users
  for (let i = 0; i < 60; i++) { // Run for 60 seconds per user
    sendMessage(token, roomId, `Message ${i} from user ${userIndex}`);
    sleep(1); // 1 message per second
  }
}

/**
 * Setup function (runs once before all VUs)
 */
export function setup() {
  console.log('Setting up load test...');
  console.log(`Base URL: ${BASE_URL}`);
  console.log(`Target: 10k concurrent users`);
  console.log(`Target throughput: 10k messages/sec`);
  
  // Health check
  const healthRes = http.get(`${BASE_URL}/health`);
  check(healthRes, {
    'health check passed': (r) => r.status === 200,
  });
  
  return { baseUrl: BASE_URL };
}

/**
 * Teardown function (runs once after all VUs)
 */
export function teardown(data) {
  console.log('Load test completed');
  console.log(`Base URL: ${data.baseUrl}`);
}

