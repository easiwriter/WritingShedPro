#!/bin/bash
# ============================================================
# Writing Shed Pro — Catalyst Database Reset
# ============================================================
# This script backs up the Catalyst app's local SQLite database
# to your Desktop, then deletes it so the app rebuilds from
# CloudKit on next launch.
#
# PREREQUISITES:
#   1. Quit Writing Shed Pro on this Mac
#   2. On iPhone, open Crossborder Poets and make a small edit
#      (touch any poem) to force an export to CloudKit
#   3. Wait ~2 minutes for the iPhone export to complete
#   4. Then run this script and relaunch the app
# ============================================================

set -e

DB_DIR="$HOME/Library/Containers/com.appworks.writingshedpro/Data/Documents"
BACKUP_DIR="$HOME/Desktop/WritingShed_DB_Backup_$(date +%Y%m%d_%H%M%S)"

echo ""
echo "=== Writing Shed Pro — Catalyst Database Reset ==="
echo ""
echo "Database: $DB_DIR/writingshed.sqlite"
echo "Backup:   $BACKUP_DIR/"
echo ""

# Safety: check the app isn't running
# Use bundle ID match to avoid false positives from username paths containing "writingshedpro"
if pgrep -f "com.appworks.writingshedpro" > /dev/null 2>&1 || \
   pgrep -x "Writing Shed Pro" > /dev/null 2>&1; then
    echo "❌ ERROR: Writing Shed Pro appears to be running!"
    echo "   Please quit the app first, then re-run this script."
    exit 1
fi
echo "✅ App is not running"
echo ""

# Check database exists
if [ ! -f "$DB_DIR/writingshed.sqlite" ]; then
    echo "❌ ERROR: Database not found at $DB_DIR/writingshed.sqlite"
    echo "   Has the app been run on this Mac?"
    exit 1
fi

# Show current state
echo "Current database state:"
sqlite3 "$DB_DIR/writingshed.sqlite" "SELECT '  Projects:        ' || count(*) FROM ZPROJECT;"
sqlite3 "$DB_DIR/writingshed.sqlite" "SELECT '  TextFiles:       ' || count(*) FROM ZTEXTFILE;"
sqlite3 "$DB_DIR/writingshed.sqlite" "SELECT '  Versions:        ' || count(*) FROM ZVERSION;"
sqlite3 "$DB_DIR/writingshed.sqlite" "SELECT '  Folders:         ' || count(*) FROM ZFOLDER;"
sqlite3 "$DB_DIR/writingshed.sqlite" "SELECT '  Pending uploads: ' || count(*) FROM ANSCKRECORDMETADATA WHERE ZNEEDSUPLOAD=1;"
echo ""

# List files to back up
echo "Files to back up:"
ls -lh "$DB_DIR"/writingshed.sqlite* 2>/dev/null | awk '{print "  " $NF " (" $5 ")"}'
echo ""

# Confirm
read -p "Proceed with backup and delete? (y/N): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Cancelled."
    exit 0
fi

# Back up
echo ""
echo "📦 Backing up to $BACKUP_DIR/ ..."
mkdir -p "$BACKUP_DIR"
cp "$DB_DIR"/writingshed.sqlite* "$BACKUP_DIR/"
echo "✅ Backup complete ($(ls "$BACKUP_DIR" | wc -l | tr -d ' ') files)"

# Delete
echo "🗑️  Deleting database files..."
rm "$DB_DIR"/writingshed.sqlite*
echo "✅ Database deleted"

echo ""
echo "=== Done! ==="
echo ""
echo "Next steps:"
echo "  1. Launch Writing Shed Pro on this Mac"
echo "  2. Wait 2-5 minutes for CloudKit to sync all projects"
echo "  3. Crossborder Poets should appear (if iPhone exported it)"
echo ""
echo "If the backup is no longer needed:"
echo "  rm -rf \"$BACKUP_DIR\""
echo ""
