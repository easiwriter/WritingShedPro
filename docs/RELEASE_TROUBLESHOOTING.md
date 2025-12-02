# Release Build Troubleshooting Checklist

**Baseline**: Commit 7c3ea68 - Debug build with 800 files syncing correctly

## If Release/TestFlight Build Fails to Sync

### Step 1: Verify App Launches
- [ ] App opens without crashing
- [ ] Can see projects from Debug build OR see empty state
- [ ] No obvious errors in Xcode console

### Step 2: Check CloudKit Configuration

```bash
# In Xcode, select Release scheme
# Project → WritingShedPro → Build Settings
# Search for: "PRODUCT_BUNDLE_IDENTIFIER"
```

- [ ] Bundle ID matches what you expect
- [ ] CloudKit container is `iCloud.com.appworks.writingshedpro`
- [ ] iCloud capabilities enabled in signing & capabilities

### Step 3: Compare Entitlements

```bash
# Check the active entitlements file
diff WritingShedProDebug.entitlements WritingShedProRelease.entitlements
```

**Critical differences to look for**:
- `com.apple.security.app-sandbox`: Should be `true` for Release
- `com.apple.developer.icloud-container-identifiers`: Must match
- `com.apple.developer.icloud-services`: Must include CloudKit
- `com.apple.developer.aps-environment`: Should be `production`

### Step 4: Code Signing

- [ ] Release scheme uses correct code signing identity
- [ ] Provisioning profile is valid and not expired
- [ ] Team ID matches between signing and CloudKit container
- [ ] Certificate is not revoked

### Step 5: Build Scheme Settings

```bash
# Check Xcode scheme
Product → Scheme → Edit Scheme...
```

- [ ] Pre-actions and post-actions are not interfering
- [ ] Run configuration matches Release build
- [ ] No code signing overrides

### Step 6: Compare Info.plist

- [ ] Bundle version and version string are correct
- [ ] Any custom CloudKit settings in plist
- [ ] Check for conflicting configurations

### Step 7: Network/Account

- [ ] Device is signed into correct iCloud account
- [ ] Same iCloud account used on all test devices
- [ ] Network is not blocking CloudKit (check firewall)
- [ ] iCloud is actually enabled in Settings

### Step 8: Check Console Output

If still failing:
1. Run Release build
2. Open Console.app on Mac or device
3. Search for:
   - `CloudKit` errors
   - `CoreData+CloudKit` errors  
   - `Service Unavailable`
   - `Request Rate Limited`
   - `model incompatible`

### Step 9: Force Reset (Last Resort)

If nothing else works:
1. Delete app from all devices
2. Log out of iCloud and back in
3. Clean Xcode build folder: `Cmd+Shift+K`
4. Rebuild and reinstall fresh

---

## Quick File Comparison Commands

```bash
# See all differences between Debug and Release entitlements
diff -u WritingShedProDebug.entitlements WritingShedProRelease.entitlements

# Check bundle identifier
grep -A5 "PRODUCT_BUNDLE_IDENTIFIER" project.pbxproj

# Check CloudKit container in code
grep -r "iCloud.com.appworks" WrtingShedPro/
```

## If You Need to Revert

```bash
# Go back to known-working Debug state
git checkout 7c3ea68

# See what changed between then and now
git diff 7c3ea68..HEAD
```

---

**Remember**: Debug build works perfectly with all 800 files syncing.  
The issue is **configuration, not code**.
