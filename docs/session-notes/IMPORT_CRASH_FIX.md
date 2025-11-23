# Import Crash Fix - Version Array Clearing

## Date
November 18, 2025

## Problem
Legacy import was crashing with pthread_kill signal after adding the empty version fix:
```
libsystem_kernel.dylib`__pthread_kill:
-> 0x7ff8141a882e <+10>: jae 0x7ff8141a8838
```

## Root Cause
**SwiftData tracking conflict when modifying versions array**

The crash was caused by modifying the `versions` array AFTER the TextFile was inserted into the modelContext:

```swift
// PROBLEMATIC ORDER:
let newTextFile = try mapper.mapTextFile(...)
modelContext.insert(newTextFile)  // ← SwiftData starts tracking
newTextFile.versions = []          // ← Modifying tracked relationship = CRASH
```

When SwiftData inserts an object, it immediately starts tracking all its relationships. The `versions` array is a tracked relationship. Clearing it after insertion causes SwiftData's change tracking to conflict with the modification, leading to memory corruption and crash.

## Solution
**Clear versions BEFORE inserting into modelContext**

```swift
// CORRECT ORDER:
let newTextFile = try mapper.mapTextFile(...)
newTextFile.versions = []          // ← Modify BEFORE tracking starts
modelContext.insert(newTextFile)   // ← SwiftData tracks already-cleared state
```

Also removed the redundant nil check since we always set versions to empty array:
```swift
// REMOVED:
if newTextFile.versions == nil {
    newTextFile.versions = []
}

// NOW:
newTextFile.versions?.append(newVersion)  // Safe - always initialized
```

## Code Changes

**LegacyImportEngine.swift:**
```swift
// Map text file
let newTextFile = try mapper.mapTextFile(legacyText, parentFolder: parentFolder)

// Clear the default empty version created by TextFile init
// IMPORTANT: Do this BEFORE inserting into context to avoid SwiftData tracking issues
newTextFile.versions = []

modelContext.insert(newTextFile)
textFileMap[legacyText] = newTextFile

// Import versions
let legacyVersions = try legacyService.fetchVersions(for: legacyText)
for (index, legacyVersion) in legacyVersions.enumerated() {
    let newVersion = try mapper.mapVersion(...)
    modelContext.insert(newVersion)
    versionMap[legacyVersion] = newVersion
    
    newTextFile.versions?.append(newVersion)  // No nil check needed
}
```

## Why It Works
1. **Before insert**: Object modifications are local, no tracking conflicts
2. **During insert**: SwiftData captures the current state (empty versions array)
3. **After insert**: Appending to tracked array is safe - normal SwiftData operation

## Important Lessons

### SwiftData Modification Rules
1. **Modify BEFORE insert**: Safe - object not yet tracked
2. **Modify AFTER insert**: Risky - must follow SwiftData's change tracking rules
3. **Array replacement**: Especially dangerous after insert (can break tracking)
4. **Array append/remove**: Safe after insert (designed for this)

### When Modifying Relationships
- ✅ DO: Modify before `modelContext.insert()`
- ✅ DO: Use append/remove on tracked arrays
- ❌ DON'T: Replace entire arrays after insert
- ❌ DON'T: Set to nil after insert (unless explicitly deleting)

## Impact
- ✅ Import no longer crashes
- ✅ Empty versions properly removed
- ✅ Clean, predictable behavior
- ✅ Follows SwiftData best practices

## Testing
1. **Re-import** a project from legacy database
2. **Verify** no crashes during import
3. **Check** version counts match legacy system
4. **Navigate** through all versions - should work smoothly

## Related Fixes
- **Empty version fix** (EMPTY_VERSION_FIX.md): The fix that revealed this issue
- **Version navigation** (VERSION_NAVIGATOR_FIX.md, VERSION_INDEX_SORTING_FIX.md): Work together

## Technical Note
This is a common SwiftData pitfall: modifying tracked objects. Always make structural changes (like clearing arrays, replacing values) BEFORE inserting into the context. After insertion, use additive operations (append, insert at index) that work with SwiftData's change tracking.

The crash manifested as pthread_kill because SwiftData's internal tracking tried to access memory that had been invalidated by the array replacement, causing a segmentation fault that the OS caught and terminated with SIGKILL.
