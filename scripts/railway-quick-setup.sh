#!/bin/bash
# Quick Railway Setup - Run AFTER: railway login && railway link

set -e

echo "🚀 Quick Railway Setup"
echo "====================="
echo ""

# Add Redis service
echo "🔴 Adding Redis service..."
railway add --database redis 2>&1 | grep -v "already exists" || echo "✅ Redis service ready"

echo ""
echo "📝 Setting environment variables..."

# Set variables
railway variables --set "NEXT_PUBLIC_SUPABASE_URL=https://nqkxynyplrvopjyffrgy.supabase.co"
railway variables --set "SUPABASE_SERVICE_ROLE_KEY=sb_secret__AZP7AmEBl-BuST7yk1oeQ_yMrkUnQ7"
railway variables --set "JWT_SECRET=4Ki2rFOYHdzoGpfTbB+5wkdD7sodHIMYXNWuqhjleJCPg+LDoOwVjvG1VbPPFZVNg3oJ/tm39qZ/n7GQml5sgw=="
railway variables --set "NODE_ENV=production"

echo ""
echo "✅ Setup complete!"
echo ""
echo "📋 Verifying variables..."
railway variables | grep -E "(NEXT_PUBLIC_SUPABASE_URL|SUPABASE_SERVICE_ROLE_KEY|JWT_SECRET|NODE_ENV|REDIS_URL)" || railway variables

echo ""
echo "🚀 Next: Railway will auto-deploy, or run: railway up"

