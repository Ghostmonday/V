#!/bin/bash
# Complete Railway Setup Script
# Sets up environment variables and adds Redis service via Railway CLI

set -e

echo "🚂 Railway Complete Setup Script"
echo "=================================="
echo ""

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo "📦 Railway CLI not found. Installing..."
    npm install -g @railway/cli
fi

# Check if logged in
echo "🔐 Checking Railway login status..."
if ! railway whoami &> /dev/null; then
    echo "⚠️  Not logged in. Please log in:"
    railway login
else
    echo "✅ Logged in to Railway"
    railway whoami
fi

echo ""
echo "🔗 Linking to Railway project..."
if [ ! -f .railway/project.json ]; then
    echo "⚠️  Project not linked. Please link your project:"
    railway link
else
    echo "✅ Project already linked"
fi

echo ""
echo "📋 Current project info:"
railway status

echo ""
echo "🔴 Adding Redis service (if not exists)..."
echo "   This will auto-set REDIS_URL"
railway add --database redis || echo "⚠️  Redis service may already exist or command failed"

echo ""
echo "🔧 Setting environment variables..."

# Set Supabase URL
echo "📝 Setting NEXT_PUBLIC_SUPABASE_URL..."
railway variables --set "NEXT_PUBLIC_SUPABASE_URL=https://nqkxynyplrvopjyffrgy.supabase.co"

# Set Supabase Service Role Key
echo "📝 Setting SUPABASE_SERVICE_ROLE_KEY..."
railway variables --set "SUPABASE_SERVICE_ROLE_KEY=sb_secret__AZP7AmEBl-BuST7yk1oeQ_yMrkUnQ7"

# Set JWT Secret
echo "📝 Setting JWT_SECRET..."
railway variables --set "JWT_SECRET=4Ki2rFOYHdzoGpfTbB+5wkdD7sodHIMYXNWuqhjleJCPg+LDoOwVjvG1VbPPFZVNg3oJ/tm39qZ/n7GQml5sgw=="

# Set NODE_ENV
echo "📝 Setting NODE_ENV..."
railway variables --set "NODE_ENV=production"

echo ""
echo "✅ Environment variables set!"
echo ""
echo "📋 Verifying variables..."
railway variables

echo ""
echo "🔍 Checking REDIS_URL..."
REDIS_URL=$(railway variables --json | grep -o '"REDIS_URL":"[^"]*"' | cut -d'"' -f4 || echo "")
if [ -z "$REDIS_URL" ] || [ "$REDIS_URL" = "redis://localhost:6379" ]; then
    echo "⚠️  REDIS_URL not set or is localhost"
    echo "   Make sure Redis service was added successfully"
    echo "   Check: railway status"
else
    echo "✅ REDIS_URL is set: ${REDIS_URL:0:50}..."
fi

echo ""
echo "🚀 Setup complete!"
echo ""
echo "Next steps:"
echo "1. Verify variables: railway variables"
echo "2. Deploy: railway up"
echo "3. Check logs: railway logs"
echo "4. Open app: railway open"

