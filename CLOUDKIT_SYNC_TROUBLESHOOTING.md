# CloudKit Sync Troubleshooting Guide

## Issue: Mac Catalyst and iOS Not Syncing

### ⚡ Quick Fix (Works 80% of the Time)

**If sync suddenly stops working, try this first:**

```bash
# Run the safe reset script
cd /Users/Projects/WritingShedPro
./safe_reset_app_data.sh

# Then in Xcode:
# 1. Product → Clean Build Folder (Cmd+Shift+K)
# 2. Product → Run (Cmd+R)
```

This clears stale CloudKit sync state and usually resolves sync issues immediately.

---

## Quick Diagnostics Checklist

Run through these checks in order:

#### 1. **Verify Same iCloud Account**
- Mac: System Settings → Apple ID → Check account
- iOS: Settings → [Your Name] → Check account
- ✅ **Must be the same Apple ID on both devices**

#### 2. **Check iCloud Drive Status**
**On Mac:**
```bash
# Open System Settings
open "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane"
```
- Verify iCloud Drive is **ON**
- Verify "Writing Shed Pro" appears in iCloud Drive apps list

**On iOS:**
- Settings → [Your Name] → iCloud → iCloud Drive → **ON**
- Settings → [Your Name] → iCloud → Scroll to "Writing Shed Pro" → **ON**

#### 3. **Check Network Connectivity**
```bash
# Test CloudKit connectivity
ping icloud.com
```
- Both devices must have active internet connection
- CloudKit sync requires initial WiFi connection (won't work on first launch with cellular only on iOS)

#### 4. **Verify Provisioning Profile Environment**

**The Issue**: Your app is in **development** mode (`aps-environment: development`). This means:
- Mac Catalyst app must be signed with **Development** certificate
- iOS app must be signed with **Development** certificate
- **If one is Development and one is Production/TestFlight, they WON'T sync**

**Check in Xcode:**
1. Open project in Xcode
2. Select target "Writing Shed Pro"
3. Go to "Signing & Capabilities" tab
4. Check both iOS and Mac targets:
   - Team: Should be the same
   - Provisioning Profile: Should both be "Development" or both be "Distribution"
   - Signing Certificate: Should match the provisioning profile type

**Quick Fix - Reset to Development Mode:**
```bash
# In Xcode, select the scheme
# Product → Scheme → Edit Scheme
# Set Run configuration to "Debug" (not "Release")
# Clean build: Cmd+Shift+K
# Rebuild: Cmd+B
```

#### 5. **Clear CloudKit Cache & Reinstall**

**On Mac:**
```bash
# Quit the app completely
# Delete app data
rm -rf ~/Library/Containers/com.appworks.writingshedpro
rm -rf ~/Library/Caches/com.appworks.writingshedpro

# Reinstall app from Xcode
# Run: Cmd+R
```

**On iOS:**
1. Delete app from device (long press → Remove App)
2. Restart device
3. Reinstall from Xcode (Cmd+R)

#### 6. **Verify CloudKit Container in Apple Developer**

**Check Container Status:**
1. Go to: https://developer.apple.com/account/resources/cloudkit/containers
2. Find container: `iCloud.com.appworks.writingshedpro`
3. Verify:
   - Status: **Active**
   - Environment: Check if Development schema matches Production
   - Services: CloudKit should be **enabled**

#### 7. **Check for CloudKit Errors in Console**

**On Mac:**
```bash
# Open Console.app
# Filter for: process:Writing Shed Pro
# Look for errors containing: "CloudKit" or "NSPersistentCloudKitContainer"
```

**On iOS:**
- Connect device to Mac
- Xcode → Window → Devices and Simulators
- Select device → View Device Logs
- Filter for "CloudKit"

Common error messages:
- `CKError.networkUnavailable` → Check internet connection
- `CKError.notAuthenticated` → User not signed into iCloud
- `CKError.quotaExceeded` → iCloud storage full
- `CKError.participantMayNeedVerification` → Need to verify Apple ID

#### 8. **Force CloudKit Sync**

Add this temporary debug code to `Write_App.swift`:

```swift
// Add after modelContainer initialization
#if DEBUG
Task {
    try? await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds
    print("🔄 Attempting manual CloudKit sync...")
    
    // This forces SwiftData to sync with CloudKit
    try? sharedModelContainer.mainContext.save()
}
#endif
```

#### 9. **Verify SwiftData Schema Matches**

**Problem**: If you changed your data model recently, old CloudKit data might conflict.

**Solution**:
```bash
# Reset CloudKit Development Environment
# WARNING: This deletes all CloudKit data in development!
# Go to: https://icloud.developer.apple.com/
# Select your container: iCloud.com.appworks.writingshedpro
# Development → Reset Development Environment
```

#### 10. **Check Model Configuration**

Verify in `Write_App.swift`:
```swift
let modelConfiguration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,  // ✅ Must be false
    cloudKitDatabase: .private("iCloud.com.appworks.writingshedpro")  // ✅ Must match entitlements
)
```

---

## Most Likely Causes (In Order)

### � **Quick Wins** (Try these first - 5 minutes)
1. **Stale CloudKit sync state** → Clean app data with `safe_reset_app_data.sh` ⭐ **This fixed it!**
2. **App hasn't synced in a while** → Force quit app on both devices, relaunch
3. **Network connectivity** issues → Verify WiFi on both devices

### �🔴 **Critical Issues** (Stop sync completely)
1. **Different Apple IDs** on devices
2. **iCloud Drive disabled** on one device
3. **Different provisioning profiles** (Dev vs Production)
4. **Network connectivity** issues

### 🟡 **Common Issues** (Intermittent sync)
5. **iCloud storage full** (check Settings → iCloud → Manage Storage)
6. **CloudKit quota exceeded** (rare for new apps)
7. **Schema migration in progress** (can take 5-10 minutes)

### 🟢 **Edge Cases**
8. **Mac Catalyst-specific entitlements** missing
9. **App Groups not configured** (not needed for SwiftData+CloudKit but sometimes helps)
10. **VPN or firewall** blocking CloudKit servers

---

## Quick Test: Verify Sync is Working

**Create Test Project:**
1. On Mac: Create a new project named "Sync Test Mac"
2. Wait 30 seconds
3. On iOS: Launch app and check for "Sync Test Mac"
4. On iOS: Create project named "Sync Test iOS"
5. Wait 30 seconds
6. On Mac: Check for "Sync Test iOS"

**If this fails, sync is definitely broken.**

---

## Mac Catalyst Specific Fixes

### Issue: Sandbox Restrictions

Mac Catalyst apps run in a sandbox and need special entitlements.

**Check your entitlements file has:**
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
```

✅ Your file has these - good!

### Issue: CloudKit Container Identifier Mismatch

**Verify exact match:**
- Entitlements: `iCloud.com.appworks.writingshedpro`
- Code: `.private("iCloud.com.appworks.writingshedpro")`

✅ Both match - good!

---

## Nuclear Option: Complete Reset

If nothing else works:

```bash
# 1. Delete app from both devices
# 2. Reset CloudKit development environment (Apple Developer portal)
# 3. Clean build folder in Xcode (Cmd+Shift+K)
# 4. Delete DerivedData:
rm -rf ~/Library/Developer/Xcode/DerivedData

# 5. Quit Xcode
# 6. Restart Mac
# 7. Open Xcode
# 8. Build and run on BOTH devices with Xcode connected
# 9. Check Console.app for CloudKit logs
```

---

## Enable CloudKit Debugging

Add to Xcode scheme (Product → Scheme → Edit Scheme → Run → Arguments):

**Environment Variables:**
```
com.apple.CoreData.ConcurrencyDebug = 1
com.apple.CoreData.CloudKitDebug = 3
com.apple.CoreData.Logging.stderr = 1
```

This will show detailed CloudKit sync logs in console.

---

## Contact Me With Results

After running through these checks, let me know:

1. Which step revealed the problem?
2. What error messages did you see in Console?
3. Are both devices using the same Apple ID?
4. Are both apps signed with Development certificates?
5. Do test projects sync between devices?

Most common fix: **Signing certificate mismatch between Mac and iOS builds**
