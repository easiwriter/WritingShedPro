#!/bin/bash

# Script to analyze Swift compilation times
# This will identify files taking the longest to compile

set -euo pipefail

echo "Starting build with timing analysis..."
echo "This may take a few minutes..."
echo ""

cd "/Users/Projects/WritingShedPro/WrtingShedPro" || exit 1

# Build with timing flags and capture output
xcodebuild \
  -project "Writing Shed Pro.xcodeproj" \
  -scheme "Writing Shed Pro" \
  -configuration Debug \
  -showBuildTimingSummary \
  OTHER_SWIFT_FLAGS="-Xfrontend -warn-long-function-bodies=200 -Xfrontend -warn-long-expression-type-checking=200" \
  clean build 2>&1 | tee /tmp/build_timing_full.log

echo ""
echo "============================================"
echo "BUILD TIMING SUMMARY (SLOWEST STEPS):"
echo "============================================"
echo ""

# Extract build timing summary lines
grep -E "Build timing summary|^\s*[0-9]+\.[0-9]+s\s+" /tmp/build_timing_full.log | head -60 || true

echo ""
echo "============================================"
echo "SLOW FUNCTION BODIES (WARNINGS > 200ms):"
echo "============================================"
echo ""
grep -E "warning:.*long function body" /tmp/build_timing_full.log | head -30 || true

echo ""
echo "============================================"
echo "SLOW TYPE-CHECK EXPRESSIONS (WARNINGS > 200ms):"
echo "============================================"
echo ""
grep -E "warning:.*long expression" /tmp/build_timing_full.log | head -30 || true

echo ""
echo "============================================"
echo "Full build log saved to: /tmp/build_timing_full.log"
echo "============================================"
