#!/bin/bash
# CloudKit Sync Diagnostic Script for Writing Shed Pro
# Run this on your Mac to check CloudKit configuration

echo "======================================"
echo "Writing Shed Pro - CloudKit Diagnostics"
echo "======================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check 1: Verify entitlements file exists
echo "1. Checking entitlements file..."
ENTITLEMENTS="WrtingShedPro/Writing Shed Pro/WritingShedPro.entitlements"
if [ -f "$ENTITLEMENTS" ]; then
    echo -e "${GREEN}✓${NC} Entitlements file found"
else
    echo -e "${RED}✗${NC} Entitlements file NOT found"
    exit 1
fi

# Check 2: Verify iCloud container
echo ""
echo "2. Checking iCloud container identifier..."
CONTAINER=$(grep -A1 "icloud-container-identifiers" "$ENTITLEMENTS" | grep "string" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
if [ "$CONTAINER" == "iCloud.com.appworks.writingshedpro" ]; then
    echo -e "${GREEN}✓${NC} Container ID: $CONTAINER"
else
    echo -e "${RED}✗${NC} Container ID mismatch: $CONTAINER"
fi

# Check 3: Verify CloudKit is enabled
echo ""
echo "3. Checking CloudKit service..."
CLOUDKIT=$(grep -A1 "icloud-services" "$ENTITLEMENTS" | grep "CloudKit")
if [ ! -z "$CLOUDKIT" ]; then
    echo -e "${GREEN}✓${NC} CloudKit service enabled"
else
    echo -e "${RED}✗${NC} CloudKit service NOT enabled"
fi

# Check 4: Verify APS environment
echo ""
echo "4. Checking push notification environment..."
APS_ENV=$(grep -A1 "aps-environment" "$ENTITLEMENTS" | grep "string" | sed 's/.*<string>\(.*\)<\/string>.*/\1/' | head -1)
echo "   Environment: $APS_ENV"
if [ "$APS_ENV" == "development" ]; then
    echo -e "${YELLOW}⚠${NC}  Development mode - ensure BOTH iOS and Mac builds use development certificates"
else
    echo -e "${GREEN}✓${NC} Production mode"
fi

# Check 5: Verify Write_App.swift CloudKit configuration
echo ""
echo "5. Checking Write_App.swift configuration..."
WRITE_APP="WrtingShedPro/Writing Shed Pro/Write_App.swift"
if [ -f "$WRITE_APP" ]; then
    CODE_CONTAINER=$(grep "cloudKitDatabase" "$WRITE_APP" | grep -o "iCloud\.com\.appworks\.writingshedpro")
    if [ "$CODE_CONTAINER" == "iCloud.com.appworks.writingshedpro" ]; then
        echo -e "${GREEN}✓${NC} Code uses correct container: $CODE_CONTAINER"
    else
        echo -e "${RED}✗${NC} Container mismatch in code"
    fi
    
    IN_MEMORY=$(grep "isStoredInMemoryOnly" "$WRITE_APP" | grep "false")
    if [ ! -z "$IN_MEMORY" ]; then
        echo -e "${GREEN}✓${NC} Persistent storage enabled (not in-memory)"
    else
        echo -e "${RED}✗${NC} WARNING: Storage might be in-memory only!"
    fi
else
    echo -e "${RED}✗${NC} Write_App.swift not found"
fi

# Check 6: Verify bundle identifier
echo ""
echo "6. Checking bundle identifier..."
BUNDLE_ID=$(grep "PRODUCT_BUNDLE_IDENTIFIER" "WrtingShedPro/Writing Shed Pro.xcodeproj/project.pbxproj" | grep "com.appworks.writingshedpro" | head -1)
if [ ! -z "$BUNDLE_ID" ]; then
    echo -e "${GREEN}✓${NC} Bundle ID: com.appworks.writingshedpro"
else
    echo -e "${RED}✗${NC} Bundle ID not found or incorrect"
fi

# Check 7: Network connectivity to iCloud
echo ""
echo "7. Checking network connectivity to iCloud..."
if ping -c 1 icloud.com &> /dev/null; then
    echo -e "${GREEN}✓${NC} Can reach icloud.com"
else
    echo -e "${RED}✗${NC} Cannot reach icloud.com - check internet connection"
fi

# Check 8: Look for app data directories
echo ""
echo "8. Checking for app data..."
APP_CONTAINER="$HOME/Library/Containers/com.appworks.writingshedpro"
if [ -d "$APP_CONTAINER" ]; then
    echo -e "${GREEN}✓${NC} App container exists"
    SIZE=$(du -sh "$APP_CONTAINER" 2>/dev/null | cut -f1)
    echo "   Size: $SIZE"
else
    echo -e "${YELLOW}⚠${NC}  App container not found (app may not have been run yet)"
fi

# Check 9: Look for CloudKit cache
CLOUDKIT_CACHE="$HOME/Library/Caches/com.appworks.writingshedpro"
if [ -d "$CLOUDKIT_CACHE" ]; then
    echo -e "${GREEN}✓${NC} CloudKit cache exists"
else
    echo -e "${YELLOW}⚠${NC}  CloudKit cache not found"
fi

# Summary
echo ""
echo "======================================"
echo "Summary & Recommendations"
echo "======================================"
echo ""

if [ "$APS_ENV" == "development" ]; then
    echo -e "${YELLOW}⚠ IMPORTANT:${NC} Your app is in DEVELOPMENT mode"
    echo "  This means:"
    echo "  • Mac Catalyst build MUST use Development certificate"
    echo "  • iOS build MUST use Development certificate"
    echo "  • If one uses Distribution/Production, they WON'T sync"
    echo ""
    echo "  To verify:"
    echo "  1. Open Xcode"
    echo "  2. Select 'Writing Shed Pro' target"
    echo "  3. Go to 'Signing & Capabilities'"
    echo "  4. Check BOTH iOS and macOS targets have same certificate type"
    echo ""
fi

echo "Next steps to diagnose sync issue:"
echo "1. Check Console.app for CloudKit errors:"
echo "   - Open Console.app"
echo "   - Filter: 'process:Writing Shed Pro'"
echo "   - Look for 'CloudKit' or 'CKError'"
echo ""
echo "2. Verify same Apple ID on both devices:"
echo "   - Mac: System Settings → Apple ID"
echo "   - iOS: Settings → [Your Name]"
echo ""
echo "3. Verify iCloud Drive is ON for the app:"
echo "   - Mac: System Settings → Apple ID → iCloud Drive"
echo "   - iOS: Settings → [Your Name] → iCloud → iCloud Drive"
echo ""
echo "4. Try the nuclear option (if nothing else works):"
echo "   - Delete app from both devices"
echo "   - Clean Xcode build (Cmd+Shift+K)"
echo "   - Rebuild and reinstall on BOTH devices"
echo ""
echo "5. For detailed logs, add to Xcode scheme environment variables:"
echo "   com.apple.CoreData.CloudKitDebug=3"
echo ""

echo "======================================"
echo "Diagnostics complete!"
echo "======================================"
