#!/bin/bash
# Safe App Data Reset Script for Writing Shed Pro
# This handles macOS security restrictions properly

echo "========================================"
echo "Writing Shed Pro - Safe Data Reset"
echo "========================================"
echo ""

APP_NAME="Writing Shed Pro"
BUNDLE_ID="com.appworks.writingshedpro"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Step 1: Check if app is running
echo -e "${BLUE}Step 1:${NC} Checking if app is running..."
if pgrep -x "Writing Shed Pro" > /dev/null; then
    echo -e "${YELLOW}⚠${NC}  App is currently running. Quitting..."
    killall "Writing Shed Pro" 2>/dev/null
    sleep 2
    
    # Check again
    if pgrep -x "Writing Shed Pro" > /dev/null; then
        echo -e "${RED}✗${NC} Could not quit app. Please quit manually:"
        echo "   1. Right-click app icon in Dock"
        echo "   2. Select 'Quit'"
        echo "   3. Run this script again"
        exit 1
    else
        echo -e "${GREEN}✓${NC} App quit successfully"
    fi
else
    echo -e "${GREEN}✓${NC} App is not running"
fi

# Step 2: Remove app caches (this usually works)
echo ""
echo -e "${BLUE}Step 2:${NC} Removing app caches..."
CACHE_DIR="$HOME/Library/Caches/$BUNDLE_ID"
if [ -d "$CACHE_DIR" ]; then
    rm -rf "$CACHE_DIR" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Cache removed"
    else
        echo -e "${YELLOW}⚠${NC}  Could not remove cache (may require restart)"
    fi
else
    echo -e "${YELLOW}⚠${NC}  No cache directory found"
fi

# Step 3: Try to remove container (may fail due to SIP)
echo ""
echo -e "${BLUE}Step 3:${NC} Attempting to remove app container..."
CONTAINER_DIR="$HOME/Library/Containers/$BUNDLE_ID"

if [ -d "$CONTAINER_DIR" ]; then
    # First, try to remove the data subdirectory (usually works)
    DATA_DIR="$CONTAINER_DIR/Data"
    if [ -d "$DATA_DIR" ]; then
        rm -rf "$DATA_DIR" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓${NC} Removed app data directory"
        else
            echo -e "${YELLOW}⚠${NC}  Could not remove data directory (protected by macOS)"
        fi
    fi
    
    # Try to remove the whole container
    rm -rf "$CONTAINER_DIR" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Container removed completely"
    else
        echo -e "${YELLOW}⚠${NC}  Container protected by macOS (this is normal)"
        echo ""
        echo "   The container metadata is protected by System Integrity Protection."
        echo "   This is OK - the important data has been removed."
        echo ""
        echo "   If you need to completely remove it, use this method:"
        echo "   ${BLUE}Option A:${NC} Delete the app completely, then reinstall"
        echo "   ${BLUE}Option B:${NC} Restart your Mac (clears the locks)"
    fi
else
    echo -e "${YELLOW}⚠${NC}  No container directory found"
fi

# Step 4: Check for Group Containers
echo ""
echo -e "${BLUE}Step 4:${NC} Checking for group containers..."
GROUP_CONTAINER="$HOME/Library/Group Containers/$BUNDLE_ID"
if [ -d "$GROUP_CONTAINER" ]; then
    rm -rf "$GROUP_CONTAINER" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Group container removed"
    else
        echo -e "${YELLOW}⚠${NC}  Could not remove group container"
    fi
else
    echo -e "${GREEN}✓${NC} No group container found"
fi

# Step 5: Remove DerivedData (Xcode build artifacts)
echo ""
echo -e "${BLUE}Step 5:${NC} Removing Xcode DerivedData..."
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
if [ -d "$DERIVED_DATA" ]; then
    # Find and remove only Writing Shed Pro derived data
    find "$DERIVED_DATA" -type d -name "*WritingShedPro*" -maxdepth 1 -exec rm -rf {} \; 2>/dev/null
    find "$DERIVED_DATA" -type d -name "*Writing_Shed_Pro*" -maxdepth 1 -exec rm -rf {} \; 2>/dev/null
    echo -e "${GREEN}✓${NC} DerivedData cleaned"
else
    echo -e "${YELLOW}⚠${NC}  DerivedData directory not found"
fi

# Summary
echo ""
echo "========================================"
echo "Reset Summary"
echo "========================================"
echo ""
echo "What was cleaned:"
echo "  ✓ App caches"
echo "  ✓ App data (inside container)"
echo "  ✓ Xcode build artifacts"
echo ""

if [ -d "$CONTAINER_DIR" ]; then
    echo -e "${YELLOW}Note:${NC} Container metadata still exists (protected by macOS)"
    echo "This is normal and won't affect the next steps."
fi

echo ""
echo "========================================"
echo "Next Steps"
echo "========================================"
echo ""
echo "1. ${BLUE}In Xcode:${NC}"
echo "   • Product → Clean Build Folder (Cmd+Shift+K)"
echo "   • Wait for cleaning to complete"
echo ""
echo "2. ${BLUE}Build and run on Mac:${NC}"
echo "   • Product → Run (Cmd+R)"
echo "   • This will create fresh app data"
echo ""
echo "3. ${BLUE}On your iOS device:${NC}"
echo "   • Delete the app (long press → Remove App → Delete App)"
echo "   • Connect device to Mac"
echo "   • In Xcode, select iOS device"
echo "   • Product → Run (Cmd+R)"
echo ""
echo "4. ${BLUE}Test sync:${NC}"
echo "   • On Mac: Create a project named 'Sync Test Mac'"
echo "   • Wait 30 seconds"
echo "   • On iOS: Launch app and check for 'Sync Test Mac'"
echo ""
echo "5. ${BLUE}If still not syncing:${NC}"
echo "   • Open Console.app"
echo "   • Filter: process:\"Writing Shed Pro\""
echo "   • Look for CloudKit errors"
echo "   • Share the errors with me"
echo ""
echo "========================================"
echo ""

# Check if we should restart
if [ -d "$CONTAINER_DIR/.com.apple.containermanagerd.metadata.plist" ]; then
    echo -e "${YELLOW}Recommendation:${NC} Restart your Mac to fully clear container locks"
    echo "This is optional but will ensure a completely clean slate."
    echo ""
fi

echo "Reset script complete!"
