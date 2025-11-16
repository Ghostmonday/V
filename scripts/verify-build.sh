#!/bin/bash

# Build Verification Script
# Run this before pushing to ensure the project builds successfully

set -e

echo "🔍 Verifying iOS build..."

cd "$(dirname "$0")/../frontend/iOS"

if [ ! -d "VibeZ.xcodeproj" ]; then
    echo "❌ Error: VibeZ.xcodeproj not found"
    exit 1
fi

echo "📦 Building project..."
if xcodebuild -scheme VibeZ -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -1 | grep -q "BUILD SUCCEEDED"; then
    echo "✅ Build successful!"
    exit 0
else
    echo "❌ Build failed!"
    exit 1
fi

