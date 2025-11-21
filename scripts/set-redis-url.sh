#!/bin/bash
# Set REDIS_URL from Redis service to App service

set -e

echo "🔧 Setting REDIS_URL"
echo "==================="
echo ""

# Check if logged in
if ! railway whoami &> /dev/null; then
    echo "❌ Not logged in. Run: railway login"
    exit 1
fi

echo "✅ Logged in to Railway"
echo ""

# Get current REDIS_URL
CURRENT_REDIS=$(railway variables --json 2>/dev/null | grep -o '"REDIS_URL":"[^"]*"' | cut -d'"' -f4 || echo "")

if [ -n "$CURRENT_REDIS" ] && [ "$CURRENT_REDIS" != "redis://localhost:6379" ]; then
    echo "✅ REDIS_URL is already set correctly:"
    echo "   ${CURRENT_REDIS:0:60}..."
    exit 0
fi

echo "⚠️  REDIS_URL is missing or set to localhost"
echo ""
echo "To fix this:"
echo ""
echo "Method 1: Railway Dashboard (Easiest)"
echo "-------------------------------------"
echo "1. Railway Dashboard → Redis Service → Variables tab"
echo "2. Copy the REDIS_URL value"
echo "3. Railway Dashboard → App Service (@vibez/api) → Variables"
echo "4. Edit REDIS_URL and paste the value"
echo "5. Save"
echo ""
echo "Method 2: CLI (If you have REDIS_URL value)"
echo "-------------------------------------------"
echo "Run: railway variables --set \"REDIS_URL=<value-from-redis-service>\""
echo ""
echo "Method 3: Railway should auto-set it"
echo "-------------------------------------"
echo "If Redis service is properly connected, Railway should auto-set REDIS_URL"
echo "Check Railway Dashboard → App Service → Variables"
echo ""

# Try to help them find it
echo "📋 Current variables on app service:"
railway variables 2>&1 | head -15

echo ""
echo "💡 Tip: The REDIS_URL should be in Redis service → Variables tab"
echo "   Format: redis://default:password@redis.railway.internal:6379"

