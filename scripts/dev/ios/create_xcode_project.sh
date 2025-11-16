#!/bin/bash
# Xcode project creation script for VibeZ iOS
# Run from repository root: ./scripts/dev/ios/create_xcode_project.sh

set -e

# Get script directory and navigate to iOS directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
IOS_DIR="$REPO_ROOT/frontend/iOS"

cd "$IOS_DIR"

PROJECT_NAME="VibeZ"
WORKSPACE_DIR="$(pwd)"
PROJECT_DIR="$WORKSPACE_DIR/$PROJECT_NAME.xcodeproj"

echo "🚀 Creating Xcode project for $PROJECT_NAME..."
echo "📁 Working directory: $WORKSPACE_DIR"

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode not found. Please install Xcode from the App Store."
    exit 1
fi

# Create project structure
mkdir -p "$PROJECT_DIR/project.xcworkspace/xcshareddata"
mkdir -p "$PROJECT_DIR/xcshareddata/xcschemes"

# Create project.pbxproj (simplified structure)
cat > "$PROJECT_DIR/project.pbxproj" << 'PROJECT_EOF'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {
		/* Begin PBXBuildFile section */
		/* End PBXBuildFile section */
		/* Begin PBXFileReference section */
		/* End PBXFileReference section */
		/* Begin PBXGroup section */
		/* End PBXGroup section */
		/* Begin PBXNativeTarget section */
		/* End PBXNativeTarget section */
		/* Begin PBXProject section */
		/* End PBXProject section */
		/* Begin XCBuildConfiguration section */
		/* End XCBuildConfiguration section */
		/* Begin XCConfigurationList section */
		/* End XCConfigurationList section */
	};
	rootObject = /* Project object */;
}
PROJECT_EOF

echo "⚠️  Manual Xcode project creation required."
echo ""
echo "📋 INSTRUCTIONS:"
echo "1. Open Xcode"
echo "2. File > New > Project"
echo "3. iOS > App"
echo "4. Product Name: $PROJECT_NAME"
echo "5. Interface: SwiftUI"
echo "6. Language: Swift"
echo "7. Save in: $WORKSPACE_DIR"
echo ""
echo "8. After creation, add all source files:"
echo "   - Drag Models/, Views/, Services/, Managers/, ViewModels/, Components/, Extensions/ into project"
echo "   - Ensure 'Copy items if needed' is UNCHECKED"
echo "   - Ensure 'Create groups' is SELECTED"
echo ""
echo "9. Configure project:"
echo "   - Deployment Target: iOS 17.0"
echo "   - Bundle Identifier: com.vibez.app"
echo "   - Info.plist: Use existing Info.plist"
echo ""
echo "10. Add StoreKit configuration:"
echo "    - File > New > File > StoreKit Configuration File"
echo "    - Or use existing Products.storekit"
echo ""
echo "✅ Project structure ready. Follow instructions above to complete setup."

