#!/bin/bash
# Test VibeZ Backend Endpoints

BASE_URL="http://localhost:3000"

echo "🧪 Testing VibeZ Backend Endpoints"
echo "======================================"
echo ""

# Test Health Endpoint
echo "1️⃣ Testing /health endpoint..."
HEALTH_RESPONSE=$(curl -s "$BASE_URL/health")
echo "Response: $HEALTH_RESPONSE"

if echo "$HEALTH_RESPONSE" | grep -q "status.*ok"; then
    echo "✅ Health check PASSED"
else
    echo "❌ Health check FAILED"
fi

echo ""

# Test API Test Endpoint
echo "2️⃣ Testing /api/test endpoint..."
TEST_RESPONSE=$(curl -s "$BASE_URL/api/test")
echo "Response: $TEST_RESPONSE"

if echo "$TEST_RESPONSE" | grep -q "status.*ok"; then
    echo "✅ API test PASSED"
else
    echo "❌ API test FAILED"
fi

echo ""
echo "✨ Testing complete!"

