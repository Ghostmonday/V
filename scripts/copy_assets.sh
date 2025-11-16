#!/bin/bash
set -e

# Use environment variable or default to relative path from script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ASSETS_SOURCE_DIR:-$SCRIPT_DIR/../pixxx}"
DST="$SCRIPT_DIR/frontend/iOS/Assets.xcassets/Images"

# Create directories
mkdir -p "$DST/Hero/WelcomeHero.imageset"
mkdir -p "$DST/Tiers/TierCardStarter.imageset"
mkdir -p "$DST/Tiers/TierCardPro.imageset"
mkdir -p "$DST/Tiers/TierCardEnterprise.imageset"
mkdir -p "$DST/Paywall/PaywallHero.imageset"
mkdir -p "$DST/Voice/VoicePresenceWaveform.imageset"
mkdir -p "$DST/Marketing/AppIconMarketing.imageset"

# Copy and rename WelcomeHero
cp "$SRC/WelcomeHero.png" "$DST/Hero/WelcomeHero.imageset/"
cp "$SRC/WelcomeHero%402x.png" "$DST/Hero/WelcomeHero.imageset/WelcomeHero@2x.png"
cp "$SRC/WelcomeHero%403x.png" "$DST/Hero/WelcomeHero.imageset/WelcomeHero@3x.png"

# Copy and rename TierCardStarter
cp "$SRC/TierCardStarter.png" "$DST/Tiers/TierCardStarter.imageset/"
cp "$SRC/TierCardStarter%402x.png" "$DST/Tiers/TierCardStarter.imageset/TierCardStarter@2x.png"
cp "$SRC/TierCardStarter%403x.png" "$DST/Tiers/TierCardStarter.imageset/TierCardStarter@3x.png"

# Copy and rename TierCardPro
cp "$SRC/TierCardPro.png" "$DST/Tiers/TierCardPro.imageset/"
cp "$SRC/TierCardPro%402x.png" "$DST/Tiers/TierCardPro.imageset/TierCardPro@2x.png"
cp "$SRC/TierCardPro%403x.png" "$DST/Tiers/TierCardPro.imageset/TierCardPro@3x.png"

# Copy and rename TierCardEnterprise
cp "$SRC/TierCardEnterprise.png" "$DST/Tiers/TierCardEnterprise.imageset/"
cp "$SRC/TierCardEnterprise%402x.png" "$DST/Tiers/TierCardEnterprise.imageset/TierCardEnterprise@2x.png"
cp "$SRC/TierCardEnterprise%403x.png" "$DST/Tiers/TierCardEnterprise.imageset/TierCardEnterprise@3x.png"

# Copy and rename PaywallHero
cp "$SRC/PaywallHero.png" "$DST/Paywall/PaywallHero.imageset/"
cp "$SRC/PaywallHero%402x.png" "$DST/Paywall/PaywallHero.imageset/PaywallHero@2x.png"
cp "$SRC/PaywallHero%403x.png" "$DST/Paywall/PaywallHero.imageset/PaywallHero@3x.png"

# Copy and rename VoicePresenceWaveform
cp "$SRC/VoicePresenceWaveform.png" "$DST/Voice/VoicePresenceWaveform.imageset/"
cp "$SRC/VoicePresenceWaveform%402x.png" "$DST/Voice/VoicePresenceWaveform.imageset/VoicePresenceWaveform@2x.png"
cp "$SRC/VoicePresenceWaveform%403x.png" "$DST/Voice/VoicePresenceWaveform.imageset/VoicePresenceWaveform@3x.png"

# Copy AppIconMarketing
cp "$SRC/AppIconMarketing.png" "$DST/Marketing/AppIconMarketing.imageset/"

echo "All files copied successfully!"

