#!/bin/bash
# Fix REDIS_URL - Run this AFTER adding Redis service in Railway Dashboard

set -e

echo "🔧 Fixing REDIS_URL"
echo "==================="
echo ""
echo "⚠️  IMPORTANT: First add Redis service in Railway Dashboard:"
echo "   1. Railway Dashboard → Your Project → 'New' → 'Database' → 'Add Redis'"
echo "   2. Wait 10 seconds for Railway to set REDIS_URL"
echo "   3. Then run this script"
echo ""
read -p "Have you added Redis service? (y/n) " -n 1 -r
echo
if [[ ! $REPO_REPLY =~ ^[Yy]$ ]]; then
    echo "Please add Redis service first, then run this script again."
    exit 1
fi

echo ""
echo "Checking current REDIS_URL..."
CURRENT_REDIS=$(railway variables --json 2>/dev/null | grep -o '"REDIS_URL":"[^"]*"' | cut -d'"' -f4 || echo "")

if [ -z "$CURRENT_REDIS" ]; then
    echo "❌ REDIS_URL not found in variables"
    echo "   Railway should auto-set it. Check Railway Dashboard → Redis Service → Variables"
    exit 1
fi

echo "Current REDIS_URL: $CURRENT_REDIS"

if [ "$CURRENT_REDIS" = "redis://localhost:6379" ]; then
    echo ""
    echo "❌ REDIS_URL is still localhost!"
    echo ""
    echo "Please:"
    echo "1. Go to Railway Dashboard → Redis Service → Variables"
    echo "2. Copy the REDIS_URL value (should be like redis://default:password@redis.railway.internal:6379)"
    echo "3. Run: railway variables --set \"REDIS_URL=<paste-value>\""
    echo ""
    echo "OR wait a bit longer - Railway may still be setting it automatically."
    exit 1
else
    echo "✅ REDIS_URL looks correct: ${CURRENT_REDIS:0:50}..."
    echo ""
    echo "✅ Redis is configured correctly!"
    echo "   Railway will auto-deploy, or run: railway up"
fi

