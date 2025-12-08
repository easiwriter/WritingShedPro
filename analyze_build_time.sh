#!/bin/bash

# Script to analyze Swift compilation times
# This will identify files taking the longest to compile

echo "Starting build with timing analysis..."
echo "This may take a few minutes..."
echo ""

cd "/Users/Projects/WritingShedPro/WrtingShedPro" || exit 1

# Build with timing flags and capture output
xcodebuild \
  -project "Writing Shed Pro.xcodeproj" \
  -scheme "Writing Shed Pro" \
  -configuration Debug \
  OTHER_SWIFT_FLAGS="-Xfrontend -debug-time-compilation" \
  clean build 2>&1 | tee /tmp/build_timing_full.log

echo ""
echo "============================================"
echo "TOP 30 SLOWEST FILES TO COMPILE:"
echo "============================================"
echo ""

# Extract timing information and sort by duration
grep -E "^\s*[0-9]+\.[0-9]+ms\s+" /tmp/build_timing_full.log | \
  sort -rn | \
  head -30

echo ""
echo "============================================"
echo "Full build log saved to: /tmp/build_timing_full.log"
echo "============================================"
