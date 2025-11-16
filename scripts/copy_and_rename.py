#!/usr/bin/env python3
"""Copy and rename image files from pixxx to Assets.xcassets"""

import os
import shutil

src = "/Users/rentamac/Desktop/pixxx"
dst_base = "/Users/rentamac/Desktop/VibeZ/frontend/iOS/Assets.xcassets/Images"

mappings = [
    ("WelcomeHero", "Hero"),
    ("TierCardStarter", "Tiers"),
    ("TierCardPro", "Tiers"),
    ("TierCardEnterprise", "Tiers"),
    ("PaywallHero", "Paywall"),
    ("VoicePresenceWaveform", "Voice"),
]

print("Copying and renaming files...")
print("=" * 50)

# Copy 3-scale images
for name, folder in mappings:
    imageset = f"{dst_base}/{folder}/{name}.imageset"
    
    # Copy @1x (no rename needed)
    src_file = f"{src}/{name}.png"
    dst_file = f"{imageset}/{name}.png"
    if os.path.exists(src_file):
        shutil.copy(src_file, dst_file)
        print(f"✓ {name}.png")
    
    # Copy @2x (rename from %402x)
    src_file = f"{src}/{name}%402x.png"
    dst_file = f"{imageset}/{name}@2x.png"
    if os.path.exists(src_file):
        shutil.copy(src_file, dst_file)
        print(f"✓ {name}@2x.png (renamed from %402x)")
    
    # Copy @3x (rename from %403x)
    src_file = f"{src}/{name}%403x.png"
    dst_file = f"{imageset}/{name}@3x.png"
    if os.path.exists(src_file):
        shutil.copy(src_file, dst_file)
        print(f"✓ {name}@3x.png (renamed from %403x)")

# Copy AppIconMarketing
src_file = f"{src}/AppIconMarketing.png"
dst_file = f"{dst_base}/Marketing/AppIconMarketing.imageset/AppIconMarketing.png"
if os.path.exists(src_file):
    shutil.copy(src_file, dst_file)
    print(f"✓ AppIconMarketing.png")

print("=" * 50)
print("✅ All files copied and renamed!")

# Verify
png_count = sum(len([f for f in os.listdir(f"{dst_base}/{folder}/{name}.imageset") if f.endswith('.png')]) 
                for name, folder in mappings)
png_count += 1  # AppIconMarketing
print(f"Total PNG files: {png_count}")

