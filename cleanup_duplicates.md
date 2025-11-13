# Clean Up Duplicate Projects

## Steps to fix your database:

### Option 1: Clean Slate (Recommended)
```bash
# Stop the app first!
# Delete all app data
rm -rf ~/Library/Containers/com.appworks.writingshedpro

# Rebuild and run - import will happen once correctly
```

### Option 2: Manual Cleanup via App
1. Launch app
2. Manually delete duplicate projects
3. The "No Projects" project (if it exists)
4. Keep only one set of projects

### Option 3: Reset Import Flag
```bash
# If you want to re-import cleanly
defaults write com.appworks.writingshedpro legacyImportAllowed -bool true
# Delete all projects in the app
# Relaunch - will import once
```

## Prevention
The code fix I just made will prevent this from happening again by:
- Migrating the old `hasPerformedImport` flag to `legacyImportAllowed`
- Preventing duplicate imports on upgrade

## After Cleanup
1. Build and run with the fixed code
2. Migration will happen automatically
3. Import won't run again unless you use the debug button
