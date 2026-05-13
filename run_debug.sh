#!/bin/bash
set -e

PROJECT_DIR="$(dirname "$0")/WrtingShedPro"
SCHEME="Writing Shed Pro"
BUILD_DIR="/tmp/WSPDebugBuild"

echo "▶ Building $SCHEME (Debug, Mac Catalyst)..."

xcodebuild \
  -project "$PROJECT_DIR/Writing Shed Pro.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=macOS,variant=Mac Catalyst" \
  -derivedDataPath "$BUILD_DIR" \
  build \
  2>&1 | grep -E "^(Build|error:|warning: |CompileSwift|Ld |▸|✓|❌|\*\*)" || true

APP_PATH=$(find "$BUILD_DIR" -name "Writing Shed Pro.app" -not -path "*/iphoneos/*" 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
  echo "❌ Could not find built .app"
  exit 1
fi

echo "✅ Build succeeded: $APP_PATH"
echo "▶ Launching..."
open "$APP_PATH"
