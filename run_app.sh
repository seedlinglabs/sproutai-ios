#!/bin/bash

# SproutAI iOS App Runner Script
echo "🚀 Starting SproutAI iOS App..."

# Check if Xcode is available
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode command line tools not found. Opening project in Xcode..."
    open SproutAI.xcodeproj
    exit 0
fi

# Try to build and run
echo "📱 Building and running SproutAI app..."
xcodebuild -project SproutAI.xcodeproj -scheme SproutAI -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build

if [ $? -eq 0 ]; then
    echo "✅ Build successful! App should be running in simulator."
else
    echo "⚠️  Build failed or Xcode not properly configured. Opening project in Xcode..."
    open SproutAI.xcodeproj
fi
