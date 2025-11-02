#!/bin/zsh

# Debug console filter for Writing Shed Pro
# This script runs the app and filters console output to show only our debug messages

echo "🚀 Building and running Writing Shed Pro with filtered debug output..."
echo "📊 Showing only: Color detection (🎨🔍💾) and text operations (📝📖)"
echo "=================================================="
echo ""

cd "$(dirname "$0")/WrtingShedPro"

# Build first
echo "Building..."
xcodebuild build -scheme "Writing Shed Pro" -destination 'platform=macOS' 2>&1 | \
  grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)"

echo ""
echo "=================================================="
echo "Starting app with filtered console..."
echo "=================================================="
echo ""

# Run tests with filtered output
# Shows our emoji markers plus any errors
xcodebuild test -scheme "Writing Shed Pro" -destination 'platform=macOS' 2>&1 | \
  grep -E "(🎨|🔍|💾|📝|📖|✅|❌|⚠️|Test Case.*failed|Test Suite.*failed|error:)" | \
  grep -v "appintentsmetadataprocessor"

echo ""
echo "=================================================="
echo "Test run complete"
