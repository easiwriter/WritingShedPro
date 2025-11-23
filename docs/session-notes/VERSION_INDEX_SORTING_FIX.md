# Version Index Sorting Fix

## Date
November 18, 2025

## Problem
Version navigation was showing blank/empty views randomly when navigating through versions imported from the legacy system:
- Legacy system had 3 versions, new app sometimes showed a 4th
- Any version could display as blank, not always the same one
- The issue was intermittent and unpredictable

## Root Cause
**Critical index mismatch between sorted and unsorted version arrays**

### The Architecture Flaw
Versions are stored in SwiftData without guaranteed order, but must be navigated by `versionNumber` in sorted order.

The old code had a **fundamental inconsistency**:
1. `changeVersion(by:)` worked with **sorted** versions to find the right one
2. It then converted that to an index in the **unsorted** array
3. `currentVersion` read from the **unsorted** array using that index
4. **BUG**: An index from a sorted array doesn't match positions in an unsorted array!

### Example of the Bug
```
Legacy data has versions: [V3, V1, V2] (stored in database in this order)
versionNumbers:           [ 3,  1,  2]

User navigates to "Version 2":
1. changeVersion sorts: [V1, V2, V3]
2. Finds V2 at sorted index 1
3. Converts to unsorted: V2 is at array position 2
4. Stores currentVersionIndex = 2

Later, currentVersion reads:
1. Accesses unsorted array at index 2
2. Returns versions[2] = V2 ✓ (by luck this time!)

User navigates forward:
1. changeVersion calculates newIndex = 2 + 1 = 3
2. Sorted array: [V1, V2, V3], index 3 is out of bounds
3. No navigation happens

OR worse:
User taps back:
1. currentVersion is called
2. Reads unsorted[2] but SHOULD read sorted[currentVersionIndex]
3. Wrong version content displayed!
```

### Why It Showed Blank Views
When the index pointed to the wrong version:
- The version might have no content loaded (lazy loading)
- The version might be a duplicate with empty content
- The cached `attributedContent` might be stale
- SwiftData relationship might be faulted/unloaded

## Solution
**Consistent sorted index space throughout**

Changed all version navigation code to work exclusively with **sorted indices**:

### 1. `currentVersion` Computed Property (BaseModels.swift)
```swift
// OLD: Read from unsorted array
return versions[currentVersionIndex]

// NEW: Always sort first, then read
let sortedVersions = versions.sorted { $0.versionNumber < $1.versionNumber }
return sortedVersions[currentVersionIndex]
```

### 2. `changeVersion(by:)` (TextFile+Versions.swift)
```swift
// OLD: Sort, find, convert back to unsorted, store unsorted index
let sortedVersions = versions.sorted { ... }
let currentIndex = sortedVersions.firstIndex(where: { $0.id == currentVersion.id })
let newIndex = currentIndex + offset
let targetVersion = sortedVersions[newIndex]
let actualIndex = versions.firstIndex(where: { $0.id == targetVersion.id })
self.currentVersionIndex = actualIndex

// NEW: Work entirely in sorted space
let newIndex = currentVersionIndex + offset  // Simple arithmetic!
self.currentVersionIndex = newIndex
```

### 3. `selectLatestVersion()` (TextFile+Versions.swift)
```swift
// OLD: Sort, find latest, convert to unsorted index
let sortedVersions = versions.sorted { ... }
let latestVersion = sortedVersions.last
let index = versions.firstIndex(where: { $0.id == latestVersion.id })
self.currentVersionIndex = index

// NEW: Latest is always last in sorted array
let sortedVersions = versions.sorted { ... }
self.currentVersionIndex = sortedVersions.count - 1
```

### 4. `atFirstVersion()` and `atLastVersion()` (TextFile+Versions.swift)
```swift
// OLD: Sort, compare IDs
let sortedVersions = versions.sorted { ... }
return currentVersion.id == sortedVersions.first?.id

// NEW: Simple index comparison
return currentVersionIndex == 0
return currentVersionIndex >= versions.count - 1
```

### 5. `versionLabel()` (TextFile+Versions.swift)
```swift
// OLD: Sort, find index, display
let sortedVersions = versions.sorted { ... }
let index = sortedVersions.firstIndex(where: { $0.id == currentVersion.id })
return "Version \(index + 1) of \(sortedVersions.count)"

// NEW: Use currentVersionIndex directly
return "Version \(currentVersionIndex + 1) of \(versions.count)"
```

## Why This Works

### Single Source of Truth
`currentVersionIndex` now **always** refers to a position in a **sorted** array.

Every function that uses it:
1. Sorts the versions the same way: `{ $0.versionNumber < $1.versionNumber }`
2. Uses `currentVersionIndex` to access that sorted array
3. No conversion, no ID lookups, no mismatch

### Performance Benefit
**BONUS**: This is actually faster!
- Old: Sort → Find ID → Convert → Store → Later sort again → Access
- New: Sort → Access directly (no ID lookups, no conversions)

### Consistency Guarantee
No matter when or how versions are accessed:
- Version 1 (lowest versionNumber) is always at index 0
- Version 2 is always at index 1
- Version N (highest versionNumber) is always at index N-1
- Navigation is predictable and reliable

## Impact
- ✅ No more blank views when navigating versions
- ✅ Correct version always displayed
- ✅ Version label always accurate
- ✅ Button states always correct
- ✅ Works reliably with legacy imported data
- ✅ Faster (fewer array searches)
- ✅ Simpler code (no index conversions)

## Testing
Test with legacy imported projects:
1. **Navigate forward**: Tap > through all versions - each should show correct content
2. **Navigate backward**: Tap < back to first - each should show correct content
3. **Random navigation**: Jump around - should never see blank content
4. **Version label**: Should show "Version 1 of 3", "Version 2 of 3", "Version 3 of 3"
5. **Button states**: < disabled at first, > disabled at last
6. **Edge cases**: Files with 1 version, files with 10+ versions

## Related Fixes
This fix works in conjunction with:
- **@Bindable fix** (VERSION_NAVIGATOR_FIX.md): Makes UI respond to version changes
- **Caching fix** (COMPLETE_5C2FF75_RESTORATION.md): Makes version loading fast
- Together they create smooth, responsive, reliable version navigation

## Technical Note
The key insight: **Don't mix sorted and unsorted index spaces**

If your data needs to be displayed in sorted order but is stored unordered:
- Pick ONE canonical ordering (sorted by versionNumber)
- ALL indices refer to that canonical ordering
- Sort on access, not on storage
- Never store "unsorted" indices

This pattern applies to any ordered collection in SwiftData/Core Data where the storage order is not guaranteed to match the presentation order.
