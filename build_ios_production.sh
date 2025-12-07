#!/bin/bash

# Script to build and install iOS app directly to connected device
# Usage: ./build_ios_production.sh

set -e

echo "🚀 Building iOS app for production..."

# Navigate to project directory
cd "$(dirname "$0")"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean
cd ios
pod install
cd ..

# Build for release (production)
echo "📱 Building iOS release..."
flutter build ios --release

echo ""
echo "✅ Build complete!"
echo ""
echo "📋 Next steps:"
echo "1. Open Xcode: open ios/Runner.xcworkspace"
echo "2. Connect your iPhone via USB"
echo "3. Select your device from the device dropdown in Xcode"
echo "4. Click the Play button (▶️) or press Cmd+R to build and install"
echo ""
echo "⚠️  Note: You may need to:"
echo "   - Sign in with your Apple ID in Xcode (Preferences > Accounts)"
echo "   - Select your development team in the Runner target settings"
echo "   - Trust the developer certificate on your iPhone (Settings > General > VPN & Device Management)"
echo ""
