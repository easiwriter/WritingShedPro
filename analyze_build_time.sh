#!/bin/bash

# Script to analyze Swift compilation times
# This will identify files taking the longest to compile
# Usage: ./analyze_build_time.sh [--no-clean] [--release] [--destination <xcode-destination>]
#   (default: clean Debug build)
#   --no-clean: runs incremental build (faster, for comparison)
#   --release: profile Release configuration instead of Debug
#   --destination: pass explicit xcodebuild destination

set -euo pipefail

CLEAN_BUILD=true
CONFIGURATION="Debug"
DESTINATION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-clean)
      CLEAN_BUILD=false
      shift
      ;;
    --release)
      CONFIGURATION="Release"
      shift
      ;;
    --destination)
      DESTINATION="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--no-clean] [--release] [--destination <xcode-destination>]"
      exit 1
      ;;
  esac
done

BUILD_MODE=$([ "$CLEAN_BUILD" = true ] && echo "clean" || echo "incremental")
echo "Starting $BUILD_MODE $CONFIGURATION build with timing analysis..."
echo "This may take a few minutes..."
echo ""

cd "/Users/Projects/WritingShedPro/WrtingShedPro" || exit 1

# Build with timing flags and capture output
BUILD_CMD=(
  xcodebuild
  -project "Writing Shed Pro.xcodeproj"
  -scheme "Writing Shed Pro"
  -configuration "$CONFIGURATION"
  -showBuildTimingSummary
  OTHER_SWIFT_FLAGS="-Xfrontend -warn-long-function-bodies=200 -Xfrontend -warn-long-expression-type-checking=200"
)

if [[ -n "$DESTINATION" ]]; then
  BUILD_CMD+=( -destination "$DESTINATION" )
fi

if [ "$CLEAN_BUILD" = true ]; then
  BUILD_CMD+=(clean)
fi

BUILD_CMD+=(build)

"${BUILD_CMD[@]}" 2>&1 | tee /tmp/build_timing_full.log

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
echo "TOP 20 SLOWEST TYPE-CHECK WARNINGS:"
echo "============================================"
echo ""
grep -E "warning:.*took [0-9]+ms to type-check" /tmp/build_timing_full.log \
  | sed -E "s#^.*/Writing Shed Pro/##" \
  | sed -E 's#.*took ([0-9]+)ms to type-check.*#\1\t&#' \
  | sort -nr \
  | head -20 || true

echo ""
echo "============================================"
echo "TOP 20 FILES BY TOTAL TYPE-CHECK TIME:"
echo "============================================"
echo ""
grep -E "warning:.*took [0-9]+ms to type-check" /tmp/build_timing_full.log \
  | sed -E "s#^.*/Writing Shed Pro/##" \
  | awk '
      {
        if ($0 ~ /^@__swiftmacro_/) {
          next
        }
        split($0, parts, ":")
        file = parts[1]
        if (match($0, /took [0-9]+ms/)) {
          msText = substr($0, RSTART + 5, RLENGTH - 7)
          total[file] += msText + 0
          count[file] += 1
        }
      }
      END {
        for (file in total) {
          printf "%6d ms\t%3d hits\t%s\n", total[file], count[file], file
        }
      }
    ' \
  | sort -nr \
  | head -20 || true

echo ""
echo "============================================"
echo "Full build log saved to: /tmp/build_timing_full.log"
echo "============================================"
