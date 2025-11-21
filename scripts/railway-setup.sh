#!/bin/bash
# Railway automated setup script
# Run this after connecting your GitHub repo to Railway

set -e

echo "🚂 Railway Auto-Setup Script"
echo "================================"

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo "📦 Installing Railway CLI..."
    npm install -g @railway/cli
fi

# Check if .env exists for local values
if [ ! -f .env ]; then
    echo "⚠️  Warning: .env file not found. You'll need to enter values manually."
fi

# Login to Railway
echo ""
echo "🔐 Logging into Railway..."
railway login

# Link to project
echo ""
echo "🔗 Linking to Railway project..."
railway link

# Add Postgres
echo ""
echo "🗄️  Adding PostgreSQL database..."
railway add --database postgres

# Add Redis
echo ""
echo "🔴 Adding Redis database..."
railway add --database redis

# Set environment variables
echo ""
echo "🔧 Setting environment variables..."

# Prompt for Supabase URL
read -p "Enter your Supabase URL (NEXT_PUBLIC_SUPABASE_URL): " SUPABASE_URL
railway variables set NEXT_PUBLIC_SUPABASE_URL="$SUPABASE_URL"

# Prompt for Supabase service role key
read -s -p "Enter your Supabase Service Role Key (SUPABASE_SERVICE_ROLE_KEY): " SUPABASE_KEY
echo ""
railway variables set SUPABASE_SERVICE_ROLE_KEY="$SUPABASE_KEY"

# Generate JWT secret
echo ""
echo "🔑 Generating JWT secret..."
JWT_SECRET=$(openssl rand -base64 32)
railway variables set JWT_SECRET="$JWT_SECRET"

# Optional: DeepSeek API key
echo ""
read -p "Enter DeepSeek API key (optional, press Enter to skip): " DEEPSEEK_KEY
if [ -n "$DEEPSEEK_KEY" ]; then
    railway variables set DEEPSEEK_API_KEY="$DEEPSEEK_KEY"
fi

# Deploy
echo ""
echo "🚀 Deploying to Railway..."
railway up

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Wait for deployment to finish"
echo "2. Run database migration:"
echo "   railway run psql \$DATABASE_URL < sql/FRESH_START.sql"
echo "3. Test your app:"
echo "   railway open"
echo ""
echo "To view logs: railway logs"
