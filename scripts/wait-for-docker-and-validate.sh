#!/bin/bash
# Wait for Docker to be available, then run full validation

set -e

echo "🔍 Checking for Docker..."
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed"
    echo ""
    echo "Please install Docker Desktop:"
    echo "  1. Download from: https://www.docker.com/products/docker-desktop"
    echo "  2. Or run: brew install --cask docker"
    echo "  3. Open Docker Desktop from Applications"
    echo ""
    exit 1
fi

echo "✅ Docker is installed: $(docker --version)"
echo ""

# Check if Docker is running
echo "⏳ Waiting for Docker to start..."
for i in {1..60}; do
    if docker ps &>/dev/null; then
        echo "✅ Docker is running!"
        echo ""
        break
    elif [ $i -eq 60 ]; then
        echo "❌ Docker is not running after 60 seconds"
        echo ""
        echo "Please:"
        echo "  1. Open Docker Desktop from Applications"
        echo "  2. Wait for it to start (whale icon in menu bar)"
        echo "  3. Run this script again: ./scripts/wait-for-docker-and-validate.sh"
        echo ""
        exit 1
    else
        echo -n "."
        sleep 2
    fi
done

echo ""
echo "🚀 Starting validation environment..."
echo ""

# Run full validation
cd "$(dirname "$0")/.."
npm run validate:docker:full

