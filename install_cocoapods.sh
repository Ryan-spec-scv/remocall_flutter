#!/bin/bash

echo "🔧 Installing CocoaPods for macOS development..."
echo ""
echo "This script will install CocoaPods, which is required for Flutter macOS builds."
echo "You will be prompted for your password."
echo ""

# Install CocoaPods
sudo gem install cocoapods

# Verify installation
if command -v pod &> /dev/null; then
    echo ""
    echo "✅ CocoaPods installed successfully!"
    echo "Version: $(pod --version)"
    echo ""
    echo "Now you can run ./build_macos.sh to build the macOS app."
else
    echo ""
    echo "❌ CocoaPods installation failed!"
    echo "Please try running: sudo gem install cocoapods manually"
fi