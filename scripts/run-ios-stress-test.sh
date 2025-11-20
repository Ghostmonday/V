#!/bin/bash
set -e

# VibeZ iOS Stress Test Runner
# Usage: ./scripts/run-ios-stress-test.sh

# Configuration
IOS_DIR="$(pwd)/frontend/iOS"
SCHEME="VibeZ"
BUNDLE_ID="com.vibez.app"
SIM_DEVICE="iPhone 15 Pro"
LOG_FILE="stress_test_output.log"

echo "🚀 Starting iOS Stress Test..."

# 1. Check for Simulator
echo "🔍 Finding $SIM_DEVICE..."
SIM_ID=$(xcrun simctl list devices available | grep "$SIM_DEVICE" | head -n 1 | awk -F '[()]' '{print $2}')

if [ -z "$SIM_ID" ]; then
    echo "❌ Error: $SIM_DEVICE not found. Please install the simulator."
    exit 1
fi
echo "📱 Using Simulator ID: $SIM_ID"

# 2. Boot Simulator
echo "🔌 Booting simulator..."
xcrun simctl boot "$SIM_ID" 2>/dev/null || echo "   (Simulator already booted)"

# 3. Build App
echo "🔨 Building VibeZ..."
cd "$IOS_DIR"

# Try to regenerate project if xcodegen is available
if command -v xcodegen &> /dev/null; then
    echo "   Regenerating project with xcodegen..."
    xcodegen > /dev/null
fi

# Build
xcodebuild -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=$SIM_ID" \
    -configuration Debug \
    -derivedDataPath build \
    clean build > /dev/null

if [ $? -ne 0 ]; then
    echo "❌ Build Failed!"
    exit 1
fi

# 4. Install App
APP_PATH=$(find "$IOS_DIR/build/Build/Products/Debug-iphonesimulator" -name "*.app" | head -n 1)
if [ -z "$APP_PATH" ]; then
    echo "❌ Error: App binary not found."
    exit 1
fi

echo "📦 Installing app..."
xcrun simctl install "$SIM_ID" "$APP_PATH"

# 5. Launch and Monitor
echo "🏃 Launching Stress Test (60s)..."
echo "   Logs will be saved to $LOG_FILE"

# Clear previous log
rm -f "$LOG_FILE"

# Launch with console output streamed to log
# -StressTest argument triggers the harness
xcrun simctl launch --console "$SIM_ID" "$BUNDLE_ID" "-StressTest" > "$LOG_FILE" 2>&1 &
LAUNCH_PID=$!

# 6. Watch for Completion
START_TIME=$(date +%s)
TIMEOUT=90

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    
    if [ $ELAPSED -gt $TIMEOUT ]; then
        echo "⏰ Timeout waiting for test to complete."
        kill $LAUNCH_PID 2>/dev/null || true
        xcrun simctl terminate "$SIM_ID" "$BUNDLE_ID"
        exit 1
    fi
    
    # Check for completion marker
    if grep -q "=== STRESS TEST SUMMARY ===" "$LOG_FILE"; then
        break
    fi
    
    # Show progress
    printf "\r   Running... %ds" "$ELAPSED"
    sleep 1
done

echo ""
echo "📊 Test Completed."

# 7. Analyze Results
# Terminate app
kill $LAUNCH_PID 2>/dev/null || true
xcrun simctl terminate "$SIM_ID" "$BUNDLE_ID"

# Print Summary
echo ""
sed -n '/=== STRESS TEST SUMMARY ===/,/===========================/p' "$LOG_FILE"

if grep -q "Result: PASSED" "$LOG_FILE"; then
    echo ""
    echo "✅ STRESS TEST PASSED"
    exit 0
else
    echo ""
    echo "❌ STRESS TEST FAILED"
    echo "   Check $LOG_FILE for details."
    exit 1
fi
