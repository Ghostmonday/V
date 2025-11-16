#!/bin/bash

# Script to rename files and set up Assets.xcassets structure

SOURCE_DIR="/Users/rentamac/Desktop/pixxx"
ASSETS_DIR="/Users/rentamac/Desktop/VibeZ/frontend/iOS/Assets.xcassets"

echo "=== Step 1: Renaming files ==="
cd "$SOURCE_DIR"

# Rename all files with %40 to @
for file in *%40*.png; do
    if [ -f "$file" ]; then
        newname=$(echo "$file" | sed 's/%40/@/g')
        mv "$file" "$newname" 2>/dev/null && echo "✓ Renamed: $file -> $newname" || echo "✗ Failed: $file"
    fi
done

echo ""
echo "=== Step 2: Creating Assets.xcassets structure ==="

# Create directory structure
mkdir -p "$ASSETS_DIR/Images/Hero"
mkdir -p "$ASSETS_DIR/Images/Tiers"
mkdir -p "$ASSETS_DIR/Images/Paywall"
mkdir -p "$ASSETS_DIR/Images/Voice"
mkdir -p "$ASSETS_DIR/Images/Marketing"

# Function to create imageset with Contents.json
create_imageset() {
    local name=$1
    local folder=$2
    local imageset_dir="$ASSETS_DIR/Images/$folder/${name}.imageset"
    
    mkdir -p "$imageset_dir"
    
    # Copy files
    cp "$SOURCE_DIR/${name}.png" "$imageset_dir/" 2>/dev/null
    cp "$SOURCE_DIR/${name}@2x.png" "$imageset_dir/" 2>/dev/null
    cp "$SOURCE_DIR/${name}@3x.png" "$imageset_dir/" 2>/dev/null
    
    # Create Contents.json
    cat > "$imageset_dir/Contents.json" <<EOF
{
  "images" : [
    {
      "filename" : "${name}.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "filename" : "${name}@2x.png",
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "filename" : "${name}@3x.png",
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF
    echo "✓ Created: $imageset_dir"
}

# Create imagesets
create_imageset "WelcomeHero" "Hero"
create_imageset "TierCardStarter" "Tiers"
create_imageset "TierCardPro" "Tiers"
create_imageset "TierCardEnterprise" "Tiers"
create_imageset "PaywallHero" "Paywall"
create_imageset "VoicePresenceWaveform" "Voice"

# AppIconMarketing (single file)
mkdir -p "$ASSETS_DIR/Images/Marketing/AppIconMarketing.imageset"
cp "$SOURCE_DIR/AppIconMarketing.png" "$ASSETS_DIR/Images/Marketing/AppIconMarketing.imageset/"
cat > "$ASSETS_DIR/Images/Marketing/AppIconMarketing.imageset/Contents.json" <<EOF
{
  "images" : [
    {
      "filename" : "AppIconMarketing.png",
      "idiom" : "universal",
      "scale" : "1x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF
echo "✓ Created: AppIconMarketing.imageset"

echo ""
echo "=== Done! ==="
echo "Assets have been set up in: $ASSETS_DIR/Images/"

