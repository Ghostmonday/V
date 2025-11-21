#!/bin/bash
# Validate Railway Connection and Configuration

set -e

echo "🔍 Validating Railway Connection"
echo "================================="
echo ""

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo "❌ Railway CLI not installed"
    echo "   Install: npm install -g @railway/cli"
    exit 1
fi
echo "✅ Railway CLI installed"

# Check if logged in
echo ""
echo "🔐 Checking login status..."
if ! railway whoami &> /dev/null; then
    echo "❌ Not logged in to Railway"
    echo "   Run: railway login"
    exit 1
fi

WHOAMI=$(railway whoami 2>&1 | grep -v "Unauthorized" || echo "")
if [ -n "$WHOAMI" ]; then
    echo "✅ Logged in: $WHOAMI"
else
    echo "❌ Login check failed"
    exit 1
fi

# Check if project is linked
echo ""
echo "🔗 Checking project link..."
if [ ! -f .railway/project.json ]; then
    echo "❌ Project not linked"
    echo "   Run: railway link"
    exit 1
fi
echo "✅ Project linked"

# Get project status
echo ""
echo "📋 Project Status:"
railway status 2>&1 | grep -v "Failed to prompt" || echo "Status check failed"

# Check environment variables
echo ""
echo "🔧 Checking Environment Variables..."
echo ""

VARS=$(railway variables --json 2>&1 || echo "{}")

# Check required variables
check_var() {
    local var_name=$1
    local value=$(echo "$VARS" | grep -o "\"$var_name\":\"[^\"]*\"" | cut -d'"' -f4 || echo "")
    
    if [ -z "$value" ]; then
        echo "❌ $var_name: NOT SET"
        return 1
    elif [ "$value" = "redis://localhost:6379" ] && [ "$var_name" = "REDIS_URL" ]; then
        echo "⚠️  $var_name: Set to localhost (won't work in Railway)"
        return 1
    else
        echo "✅ $var_name: Set (${value:0:50}...)"
        return 0
    fi
}

ERRORS=0

echo "Required Variables:"
check_var "NEXT_PUBLIC_SUPABASE_URL" || ERRORS=$((ERRORS + 1))
check_var "SUPABASE_SERVICE_ROLE_KEY" || ERRORS=$((ERRORS + 1))
check_var "JWT_SECRET" || ERRORS=$((ERRORS + 1))
check_var "NODE_ENV" || ERRORS=$((ERRORS + 1))
check_var "REDIS_URL" || ERRORS=$((ERRORS + 1))

echo ""
echo "📊 Summary:"
if [ $ERRORS -eq 0 ]; then
    echo "✅ All required variables are set correctly!"
    echo ""
    echo "🚀 Ready to deploy!"
    echo "   Railway will auto-deploy on git push, or run: railway up"
    exit 0
else
    echo "❌ Found $ERRORS issue(s) that need to be fixed"
    echo ""
    echo "🔧 Next steps:"
    echo "   1. Fix missing/incorrect variables"
    echo "   2. If REDIS_URL is localhost, add Redis service in Railway Dashboard"
    echo "   3. Run this script again to verify"
    exit 1
fi

