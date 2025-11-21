#!/bin/bash

# Test Docker Build Script
# Verifies that the Dockerfile builds successfully before deploying to Railway

set -e  # Exit on error

echo "🔍 Testing Docker build for Railway deployment..."
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Docker is not running${NC}"
    echo "Please start Docker Desktop and try again"
    exit 1
fi

echo -e "${GREEN}✅ Docker is running${NC}"
echo ""

# Clean up previous builds
echo "🧹 Cleaning up previous builds..."
docker rmi vibez-test 2>/dev/null || true
echo ""

# Build the Docker image
echo "🔨 Building Docker image..."
echo "This may take 2-3 minutes for the first build..."
echo ""

if docker build -t vibez-test -f Dockerfile .; then
    echo ""
    echo -e "${GREEN}✅ Docker build successful!${NC}"
else
    echo ""
    echo -e "${RED}❌ Docker build failed${NC}"
    echo "Check the error messages above for details"
    exit 1
fi

# Check if dist folder exists in the image
echo ""
echo "🔍 Verifying dist folder exists in image..."
if docker run --rm vibez-test ls -la dist/ > /dev/null 2>&1; then
    echo -e "${GREEN}✅ dist/ folder found in image${NC}"
else
    echo -e "${RED}❌ dist/ folder not found in image${NC}"
    exit 1
fi

# Check if package.json exists in the image
echo "🔍 Verifying package.json exists in image..."
if docker run --rm vibez-test ls -la package.json > /dev/null 2>&1; then
    echo -e "${GREEN}✅ package.json found in image${NC}"
else
    echo -e "${RED}❌ package.json not found in image${NC}"
    exit 1
fi

# Check if node_modules exists
echo "🔍 Verifying node_modules exists in image..."
if docker run --rm vibez-test ls -la node_modules/ > /dev/null 2>&1; then
    echo -e "${GREEN}✅ node_modules/ folder found in image${NC}"
else
    echo -e "${RED}❌ node_modules/ folder not found in image${NC}"
    exit 1
fi

# Check image size
echo ""
echo "📦 Image size:"
docker images vibez-test --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

echo ""
echo -e "${GREEN}🎉 All checks passed!${NC}"
echo ""
echo "Next steps:"
echo "1. Commit and push your changes:"
echo "   git add .dockerignore Dockerfile railway.json"
echo "   git commit -m 'fix: Railway deployment configuration'"
echo "   git push"
echo ""
echo "2. Railway will automatically rebuild and deploy"
echo ""
echo "3. Monitor the deployment at:"
echo "   https://railway.app/project/[your-project-id]"
echo ""

# Optional: Run the container for manual testing
read -p "Do you want to start the container for manual testing? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🚀 Starting container on port 3000..."
    echo "Press Ctrl+C to stop"
    echo ""
    echo "Note: You'll need to set environment variables for full functionality"
    echo ""
    docker run -p 3000:3000 \
        -e NODE_ENV=production \
        -e PORT=3000 \
        vibez-test
fi

