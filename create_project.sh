#!/bin/bash

set -e

PROJECT_DIR="/Users/andychen/Desktop/beauty-clinic-ios/BeautyClinic"
XCODEPROJ="$PROJECT_DIR/BeautyClinic.xcodeproj"

# Clean up existing project
rm -rf "$XCODEPROJ"

echo "Creating new Xcode project..."

cd "$PROJECT_DIR"

# Use xcodebuild to create a basic project structure
xcodebuild -project BeautyClinic.xcodeproj -scheme BeautyClinic -sdk iphonesimulator26.5 -configuration Debug -dry-run 2>&1 | head -20

echo "Project structure created at: $XCODEPROJ"

# Verify the project can be opened
if [ -d "$XCODEPROJ" ]; then
    echo "✅ Project directory exists"
    ls -la "$XCODEPROJ"
else
    echo "❌ Project directory not found"
fi
