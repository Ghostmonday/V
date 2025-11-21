#!/bin/bash
# Script to set Railway environment variables
# Run this after: railway login && railway link

set -e

echo "🚂 Setting Railway Environment Variables"
echo "========================================"
echo ""

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo "❌ Railway CLI not found. Installing..."
    npm install -g @railway/cli
fi

# Check if logged in
if ! railway whoami &> /dev/null; then
    echo "⚠️  Not logged in to Railway. Please run: railway login"
    exit 1
fi

echo "✅ Railway CLI ready"
echo ""

# Set Supabase URL
echo "📝 Setting NEXT_PUBLIC_SUPABASE_URL..."
railway variables --set "NEXT_PUBLIC_SUPABASE_URL=https://nqkxynyplrvopjyffrgy.supabase.co"
echo "✅ NEXT_PUBLIC_SUPABASE_URL set"

# Set Supabase Service Role Key
echo "📝 Setting SUPABASE_SERVICE_ROLE_KEY..."
railway variables --set "SUPABASE_SERVICE_ROLE_KEY=sb_secret__AZP7AmEBl-BuST7yk1oeQ_yMrkUnQ7"
echo "✅ SUPABASE_SERVICE_ROLE_KEY set"

# Set JWT Secret
echo "📝 Setting JWT_SECRET..."
railway variables --set "JWT_SECRET=4Ki2rFOYHdzoGpfTbB+5wkdD7sodHIMYXNWuqhjleJCPg+LDoOwVjvG1VbPPFZVNg3oJ/tm39qZ/n7GQml5sgw=="
echo "✅ JWT_SECRET set"

# Set NODE_ENV to production
echo "📝 Setting NODE_ENV..."
railway variables --set "NODE_ENV=production"
echo "✅ NODE_ENV set"

echo ""
echo "✅ All environment variables set!"
echo ""
echo "Next steps:"
echo "1. Add Redis service if not already added: railway add --database redis"
echo "2. Trigger deployment: railway up"
echo "3. Check logs: railway logs"
echo ""

