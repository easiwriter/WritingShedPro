#!/bin/bash

# Simple script to find slow Swift compilation using type checking
# This adds warnings to files that take too long to type-check

echo "Analyzing Swift build performance..."
echo ""
echo "To find slow files, you can:"
echo "1. In Xcode: Product → Scheme → Edit Scheme → Build → Add to Other Swift Flags:"
echo "   -Xfrontend -warn-long-function-bodies=100"
echo "   -Xfrontend -warn-long-expression-type-checking=100"
echo ""
echo "2. Then build in Xcode and look for warnings about slow functions/expressions"
echo ""
echo "Or check the build log from the latest build attempt..."
echo ""

# Check if there's a build log
if [ -f /tmp/build_timing.log ]; then
    echo "Analyzing /tmp/build_timing.log..."
    echo ""
    echo "=== Build Timing Summary ==="
    grep -i "Build timing summary" /tmp/build_timing.log -A 50 2>/dev/null || echo "No timing summary found yet (build may still be running)"
else
    echo "No build log found at /tmp/build_timing.log"
    echo "The build command may still be running in the background."
fi

echo ""
echo "=== Quick Method in Xcode ===="
echo "1. Open Xcode"
echo "2. Product → Clean Build Folder (⌘⇧K)"
echo "3. Product → Build (⌘B)"
echo "4. View → Navigators → Reports (⌘9)"
echo "5. Select latest build"
echo "6. Look for compilation times in the build log"
