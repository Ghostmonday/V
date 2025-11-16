#!/usr/bin/env python3
"""
Script to rename files and set up Assets.xcassets structure
Run this from the VibeZ directory: python3 scripts/setup_assets.py
"""

import os
import shutil
import json
from pathlib import Path

# Paths - configurable via environment variable or relative to script location
SCRIPT_DIR = Path(__file__).parent.parent
SOURCE_DIR = Path(os.environ.get('ASSETS_SOURCE_DIR', SCRIPT_DIR.parent / 'pixxx'))
ASSETS_BASE = SCRIPT_DIR / 'frontend/iOS/Assets.xcassets/Images'

# Image mapping: name -> folder
IMAGE_MAPPING = {
    "WelcomeHero": "Hero",
    "TierCardStarter": "Tiers",
    "TierCardPro": "Tiers",
    "TierCardEnterprise": "Tiers",
    "PaywallHero": "Paywall",
    "VoicePresenceWaveform": "Voice",
    "AppIconMarketing": "Marketing"
}

def create_imageset(name, folder):
    """Create an imageset with Contents.json and copy files"""
    imageset_dir = ASSETS_BASE / folder / f"{name}.imageset"
    imageset_dir.mkdir(parents=True, exist_ok=True)
    
    print(f"\nCreating {name}.imageset in {folder}/...")
    
    # Copy files (handle %40 -> @ renaming)
    copied_files = []
    for scale in ["", "@2x", "@3x"]:
        if name == "AppIconMarketing" and scale:
            continue  # Skip @2x and @3x for marketing icon
        
        # Try both encoded and decoded names
        source_file_encoded = f"{name}{scale.replace('@', '%40')}.png"
        source_file = f"{name}{scale}.png"
        dest_file = f"{name}{scale}.png"
        
        source_path_encoded = SOURCE_DIR / source_file_encoded
        source_path = SOURCE_DIR / source_file
        
        if source_path.exists():
            shutil.copy(source_path, imageset_dir / dest_file)
            copied_files.append(source_file)
            print(f"  ✓ Copied: {source_file}")
        elif source_path_encoded.exists():
            shutil.copy(source_path_encoded, imageset_dir / dest_file)
            copied_files.append(f"{source_file_encoded} -> {dest_file}")
            print(f"  ✓ Copied and renamed: {source_file_encoded} -> {dest_file}")
        else:
            print(f"  ⚠ Warning: {source_file} not found")
    
    # Create Contents.json
    if name == "AppIconMarketing":
        contents = {
            "images": [{
                "filename": "AppIconMarketing.png",
                "idiom": "universal",
                "scale": "1x"
            }],
            "info": {"author": "xcode", "version": 1}
        }
    else:
        contents = {
            "images": [
                {"filename": f"{name}.png", "idiom": "universal", "scale": "1x"},
                {"filename": f"{name}@2x.png", "idiom": "universal", "scale": "2x"},
                {"filename": f"{name}@3x.png", "idiom": "universal", "scale": "3x"}
            ],
            "info": {"author": "xcode", "version": 1}
        }
    
    contents_path = imageset_dir / "Contents.json"
    with open(contents_path, "w") as f:
        json.dump(contents, f, indent=2)
    print(f"  ✓ Created: Contents.json")
    
    return len(copied_files)

def main():
    print("=" * 60)
    print("Setting up Assets.xcassets structure")
    print("=" * 60)
    
    # Verify source directory exists
    if not SOURCE_DIR.exists():
        print(f"❌ Error: Source directory not found: {SOURCE_DIR}")
        return
    
    # Create base Images directory
    ASSETS_BASE.mkdir(parents=True, exist_ok=True)
    
    # Create all imagesets
    total_files = 0
    for name, folder in IMAGE_MAPPING.items():
        files_copied = create_imageset(name, folder)
        total_files += files_copied
    
    print("\n" + "=" * 60)
    print(f"✅ Done! Created {len(IMAGE_MAPPING)} imagesets")
    print(f"   Total files copied: {total_files}")
    print(f"   Location: {ASSETS_BASE}")
    print("=" * 60)
    print("\nNext steps:")
    print("1. Open Xcode")
    print("2. Right-click Assets.xcassets → Add Files to 'VibeZ'...")
    print("3. Select the Images folder")
    print("4. Make sure 'Create groups' is selected")
    print("5. Click Add")

if __name__ == "__main__":
    main()

