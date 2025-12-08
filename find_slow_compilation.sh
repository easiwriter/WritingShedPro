#!/bin/bash

echo "=================================================="
echo "Swift Build Time Analysis"
echo "=================================================="
echo ""
echo "RECOMMENDED APPROACH:"
echo "1. Open Xcode"
echo "2. Go to: Product → Scheme → Edit Scheme..."
echo "3. Select 'Build' on the left"
echo "4. Click 'Arguments' tab (if not visible, it's under Build Options)"
echo "5. Under 'Build' section, add to 'Other Swift Flags':"
echo "   -Xfrontend -warn-long-function-bodies=100"
echo "   -Xfrontend -warn-long-expression-type-checking=100"
echo ""
echo "6. Clean Build Folder (⌘⇧K)"
echo "7. Build (⌘B)"
echo "8. View → Navigators → Show Report Navigator (⌘9)"
echo "9. Select the latest build"
echo "10. Look for yellow warnings about slow compilation"
echo ""
echo "The warnings will show you exactly which functions/expressions"
echo "are taking a long time to type-check."
echo ""
echo "=================================================="
echo "ALTERNATIVE: Check recent Xcode build times"
echo "=================================================="
echo ""

# Try to find the most recent build log
DERIVED_DATA=~/Library/Developer/Xcode/DerivedData
PROJECT_DERIVED=$(find "$DERIVED_DATA" -maxdepth 1 -name "*Writing_Shed_Pro*" -type d | head -1)

if [ -n "$PROJECT_DERIVED" ]; then
    echo "Found derived data at: $PROJECT_DERIVED"
    echo ""
    echo "Recent build logs:"
    find "$PROJECT_DERIVED/Logs/Build" -name "*.xcactivitylog" -mtime -1 2>/dev/null | head -3
    echo ""
    echo "To analyze these logs, you can use:"
    echo "  xcrun xccov view --archive <path-to-xcactivitylog>"
else
    echo "No derived data found for Writing Shed Pro"
fi

echo ""
echo "=================================================="
echo "QUICK CHECK: Module compilation times"
echo "=================================================="
echo ""

# Check if there are any .swiftmodule files and their sizes
if [ -n "$PROJECT_DERIVED" ]; then
    echo "Largest .swift files in your project:"
    find /Users/Projects/WritingShedPro/WrtingShedPro -name "*.swift" -type f -exec wc -l {} \; | sort -rn | head -20 | awk '{printf "%5d lines: %s\n", $1, $2}'
fi
