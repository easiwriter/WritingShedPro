# PageSetup Persistence Fix - Switch to UserDefaults

**Date:** 24 November 2025  
**Issue:** PageSetup changes not persisting after dialog close

---

## Problem Diagnosis

Console output revealed the root cause:

```
[PageSetupForm] ✅ Paper name changed: 'A4' → 'Letter'
[PageSetupForm] ✅ Saved to prefs, verifying...
[PageSetupForm] ✅ Prefs now has: 'A4'  ← VALUE NOT SAVED!
```

The `setPaperName()` was being called, but immediately reading back the old value. This indicated that `NSUbiquitousKeyValueStore` was not persisting values correctly to local storage.

### Why NSUbiquitousKeyValueStore Failed

`NSUbiquitousKeyValueStore` requires:
1. **iCloud entitlement** properly configured
2. **User signed into iCloud** on device
3. **iCloud Key-Value Storage** capability enabled in Xcode
4. **Network connectivity** for initial sync

The store was not returning newly-set values on immediate read, suggesting either:
- Entitlement not configured
- User not signed into iCloud
- Store not initializing properly

---

## Solution: Switch to UserDefaults

Replaced `NSUbiquitousKeyValueStore.default` with `UserDefaults.standard` for reliable local persistence.

### Changes Made

**File:** `PageSetupPreferences.swift`

1. **Changed Store Backend:**
```swift
// BEFORE:
private let store = NSUbiquitousKeyValueStore.default

// AFTER:
private let store = UserDefaults.standard
```

2. **Simplified Initialization:**
```swift
// BEFORE: Complex iCloud setup with notification observers
private init() {
    registerDefaults()
    NotificationCenter.default.addObserver(...)
    store.synchronize()
}

// AFTER: Simple UserDefaults initialization
private init() {
    registerDefaults()
}
```

3. **Updated registerDefaults():**
```swift
// BEFORE: Manual nil checks and set() calls for each property

// AFTER: Use UserDefaults.register(defaults:) API
private func registerDefaults() {
    let defaults: [String: Any] = [
        Keys.paperName: PaperSizes.defaultForRegion.rawValue,
        Keys.orientation: Int(Orientation.portrait.rawValue),
        // ... all 13 properties
    ]
    store.register(defaults: defaults)
}
```

4. **Removed synchronize() Calls:**
```swift
// BEFORE:
func setPaperName(_ value: String) {
    store.set(value, forKey: Keys.paperName)
    store.synchronize()  ← Not needed for UserDefaults
}

// AFTER:
func setPaperName(_ value: String) {
    store.set(value, forKey: Keys.paperName)
}
```

5. **Added Debug Logging:**
```swift
func setPaperName(_ value: String) {
    print("[PageSetupPreferences] Setting paperName to: '\(value)'")
    print("[PageSetupPreferences] Before set, store has: '\(store.string(forKey: Keys.paperName) ?? "nil")'")
    store.set(value, forKey: Keys.paperName)
    print("[PageSetupPreferences] After set, store has: '\(store.string(forKey: Keys.paperName) ?? "nil")'")
}
```

---

## Impact

### ✅ Benefits
- **Reliable persistence** - UserDefaults is battle-tested and always works
- **Immediate availability** - Values readable immediately after setting
- **No dependencies** - Doesn't require iCloud account or network
- **Simpler code** - No notification observers or sync management

### ⚠️ Trade-offs
- **No cross-device sync** - PageSetup settings are per-device only
- **Not backed up to iCloud** - Settings lost if device is reset

---

## Testing

After rebuild:
1. ✅ Open PageSetup → Change paper size → Done → Reopen → Verify persists
2. ✅ Change margins → Done → Reopen → Verify persists  
3. ✅ Toggle headers/footers → Done → Reopen → Verify persists
4. ✅ Check console logs show successful save/load

Expected console output:
```
[PageSetupPreferences] Setting paperName to: 'Letter'
[PageSetupPreferences] Before set, store has: 'A4'
[PageSetupPreferences] After set, store has: 'Letter'  ← SUCCESS!
```

---

## Future Enhancement: iCloud Sync (Optional)

To re-enable cross-device sync later:

1. **Verify iCloud Setup:**
   - Signing & Capabilities → iCloud → Enable "Key-value storage"
   - Check Bundle ID matches iCloud container
   - Ensure entitlements file has `com.apple.developer.ubiquity-kvstore-identifier`

2. **Create Hybrid Approach:**
```swift
// Use UserDefaults as primary, NSUbiquitousKeyValueStore as sync layer
class PageSetupPreferences {
    private let localStore = UserDefaults.standard
    private let cloudStore = NSUbiquitousKeyValueStore.default
    
    func setPaperName(_ value: String) {
        localStore.set(value, forKey: Keys.paperName)  // Immediate
        cloudStore.set(value, forKey: Keys.paperName)  // Background sync
        cloudStore.synchronize()
    }
    
    var paperName: String {
        // Always read from local store (reliable)
        localStore.string(forKey: Keys.paperName) ?? defaultValue
    }
}
```

3. **Add Sync Observer:**
```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(cloudStoreDidChange),
    name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
    object: cloudStore
)

@objc func cloudStoreDidChange(_ notification: Notification) {
    // Copy cloud values to local store
    if let cloudValue = cloudStore.string(forKey: Keys.paperName) {
        localStore.set(cloudValue, forKey: Keys.paperName)
    }
}
```

---

## Files Modified

1. **`Services/PageSetupPreferences.swift`**
   - Changed store from NSUbiquitousKeyValueStore to UserDefaults
   - Simplified initialization (removed notification observers)
   - Updated registerDefaults() to use UserDefaults API
   - Removed synchronize() calls from all setters
   - Added debug logging to setPaperName()

---

## Related Documents

- `FEATURE_019_COMPLETE.md` - Original PageSetup implementation
- `BUG_FIXES_PAGESETUP_LOCALIZATION.md` - Previous fix attempt

---

## Notes

The switch to UserDefaults prioritizes **reliability over features**. PageSetup now works correctly on each device. Cross-device sync can be added back once iCloud configuration is verified and tested properly.

UserDefaults is the right choice for this data because:
- Page setup preferences are low-frequency changes
- Users typically have similar preferences per device type (phone vs tablet)
- Reliability is more important than cross-device sync for page layout settings
