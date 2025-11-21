#!/bin/bash

# Quick Railway Deployment Fix Script
# Run this to commit and deploy the Railway fixes

set -e

echo "🚀 Railway Deployment Fix - Quick Deploy"
echo "========================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check git status
echo "📋 Checking git status..."
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${GREEN}✓ Changes detected${NC}"
    echo ""
    echo "Files changed:"
    git status --short
    echo ""
else
    echo "No changes to commit"
    exit 0
fi

# Confirm deployment
echo -e "${YELLOW}⚠️  This will commit and push the following Railway fixes:${NC}"
echo "  • .dockerignore - Removed 'dist' exclusion, added build artifacts"
echo "  • Dockerfile - Added workspace support and health check"
echo "  • railway.json - Changed start command to 'node dist/server/index.js'"
echo ""

read -p "Continue with commit and push? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Add files
echo ""
echo "📦 Adding files..."
git add .dockerignore Dockerfile railway.json
git add RAILWAY_DEPLOYMENT_FIX.md RAILWAY_FIX_SUMMARY.md
git add scripts/test-docker-build.sh scripts/railway-quick-deploy.sh

# Commit
echo "💾 Committing changes..."
git commit -m "fix: Railway deployment configuration for monorepo

- Remove dist from .dockerignore to include build output
- Update Dockerfile to handle workspace package.json files
- Change railway.json start command from 'npm start' to 'node dist/server/index.js'
- Add health check to Dockerfile
- Add deployment documentation and testing scripts

Fixes: Container crash loop with ENOENT /app/package.json error"

# Push
echo "🚀 Pushing to remote..."
git push

echo ""
echo -e "${GREEN}✅ Deployment initiated!${NC}"
echo ""
echo "Next steps:"
echo "1. Monitor Railway dashboard: https://railway.app"
echo "2. Watch build logs for successful compilation"
echo "3. Check runtime logs - should see 'Server listening on port 3000'"
echo "4. Verify health endpoint: https://your-app.railway.app/health"
echo ""
echo "Build should complete in 2-3 minutes."
echo ""

