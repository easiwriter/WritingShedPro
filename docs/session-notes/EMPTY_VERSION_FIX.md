# Empty Version Fix

## Date
November 18, 2025

## Problem
After importing from the legacy system, files would sometimes display blank/empty versions when navigating. The legacy system had 3 versions, but the new app would show extra empty versions mixed in with the real ones.

## Root Cause
**TextFile init was creating a default empty version**

When TextFile is initialized, its init method creates a default first version:
```swift
init(name: String = "", initialContent: String = "", parentFolder: Folder? = nil) {
    // ...
    let firstVersion = Version(content: initialContent, versionNumber: 1)
    self.versions = [firstVersion]
    firstVersion.textFile = self
}
```

During legacy import:
1. `let newTextFile = TextFile()` is called
2. Init creates empty version with versionNumber: 1, content: ""
3. Import then adds the REAL versions from legacy database (version 1, 2, 3 with actual content)
4. **Result**: File now has 4 versions - the empty default one PLUS the 3 real ones

The empty version would appear at random positions depending on how SwiftData stored them, causing blank displays when navigating.

## Solution
Clear the default versions array before importing real versions from the legacy database:

**LegacyImportEngine.swift:**
```swift
// Map text file
let newTextFile = try mapper.mapTextFile(legacyText, parentFolder: parentFolder)
modelContext.insert(newTextFile)
textFileMap[legacyText] = newTextFile

// Clear the default empty version created by TextFile init
// We'll add versions from the legacy database instead
newTextFile.versions = []

// Import versions (now starting with empty array)
let legacyVersions = try legacyService.fetchVersions(for: legacyText)
for (index, legacyVersion) in legacyVersions.enumerated() {
    let newVersion = try mapper.mapVersion(...)
    // ...
}
```

## Why It Works
- TextFile init creates the default version (can't avoid this with current design)
- We immediately clear it: `newTextFile.versions = []`
- Then add only the real versions from the legacy database
- No mixing of empty and real versions
- Version count matches legacy system exactly

## Impact
- ✅ No more extra empty versions
- ✅ Version count matches legacy system (3 versions = 3 versions)
- ✅ All versions have proper content
- ✅ No blank displays when navigating
- ✅ Predictable, consistent behavior

## Testing
1. **Re-import** a project from the legacy system
2. **Count versions**: Should match exactly what legacy system had
3. **Navigate through all versions**: Each should display content, none blank
4. **Check version numbers**: Should be sequential (1, 2, 3) not (1, 1, 2, 3)

## Related Fixes
Works with:
- **@Bindable fix** (VERSION_NAVIGATOR_FIX.md): Makes UI respond to changes
- **Index sorting fix** (VERSION_INDEX_SORTING_FIX.md): Ensures correct version accessed
- **Caching fix** (COMPLETE_5C2FF75_RESTORATION.md): Makes loading fast

Together these create a complete, working version navigation system!

## Notes
This issue was already fixed in commit 5c2ff75 but was lost during the TextKit 2 rollback. The fix has now been restored.

Alternative solutions considered:
1. **Don't create default version in init**: Would require major refactoring
2. **Check for duplicates during import**: More complex, error-prone
3. **Clear before import (chosen)**: Simple, direct, foolproof
