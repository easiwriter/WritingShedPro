# SwiftData Relationship Caching Fix

## Problem Summary

After refactoring Comments and Footnotes to use `@Relationship` with Version (instead of UUID references), unit tests were failing with stale data issues. Tests would move footnotes to trash but the `getActiveFootnotes()` method would still return them, or vice versa for deleted footnotes.

### Example Test Failures

```
testGetActiveFootnotes(): XCTAssertEqual failed: ("2") is not equal to ("1")
  - Expected 1 active footnote after deleting one
  - Got 2 (the deleted footnote was still appearing)

testGetDeletedFootnotes(): XCTAssertEqual failed: ("0") is not equal to ("2")
  - Expected 2 deleted footnotes after moving to trash
  - Got 0 (the deleted footnotes weren't appearing)
```

## Root Cause

The original manager implementations relied on SwiftData's `@Relationship` arrays:

```swift
// OLD IMPLEMENTATION (FootnoteManager.swift)
func getActiveFootnotes(forVersion version: Version, context: ModelContext) -> [FootnoteModel] {
    return (version.footnotes ?? [])
        .filter { !$0.isDeleted }
        .sorted { $0.characterPosition < $1.characterPosition }
}
```

**Problem:** SwiftData's relationship arrays (`version.footnotes`) are **cached in memory**. Even after:
1. Modifying child objects (footnotes/comments)
2. Calling `context.save()`
3. Calling `context.processPendingChanges()`
4. Refetching the Version object

...the relationship array would still contain stale data. The parent Version object's `footnotes` array wouldn't update to reflect database changes.

## Solution

Changed all manager query methods to use `FetchDescriptor` to query the database directly:

### FootnoteManager.swift

```swift
// NEW IMPLEMENTATION
func getActiveFootnotes(forVersion version: Version, context: ModelContext) -> [FootnoteModel] {
    // Use FetchDescriptor to query database directly instead of relying on cached relationship
    let versionID = version.id
    let descriptor = FetchDescriptor<FootnoteModel>(
        predicate: #Predicate { footnote in
            footnote.version?.id == versionID && footnote.isDeleted == false
        },
        sortBy: [SortDescriptor(\.characterPosition, order: .forward)]
    )
    return (try? context.fetch(descriptor)) ?? []
}

func getDeletedFootnotes(forVersion version: Version, context: ModelContext) -> [FootnoteModel] {
    let versionID = version.id
    let descriptor = FetchDescriptor<FootnoteModel>(
        predicate: #Predicate { footnote in
            footnote.version?.id == versionID && footnote.isDeleted == true
        },
        sortBy: [SortDescriptor(\.deletedAt, order: .reverse)]
    )
    return (try? context.fetch(descriptor)) ?? []
}

func getAllFootnotes(forVersion version: Version, context: ModelContext) -> [FootnoteModel] {
    let versionID = version.id
    let descriptor = FetchDescriptor<FootnoteModel>(
        predicate: #Predicate { footnote in
            footnote.version?.id == versionID
        },
        sortBy: [SortDescriptor(\.characterPosition, order: .forward)]
    )
    return (try? context.fetch(descriptor)) ?? []
}
```

### CommentManager.swift

```swift
// NEW IMPLEMENTATION
func getComments(forVersion version: Version, context: ModelContext) -> [CommentModel] {
    let versionID = version.id
    let descriptor = FetchDescriptor<CommentModel>(
        predicate: #Predicate { comment in
            comment.version?.id == versionID
        },
        sortBy: [SortDescriptor(\.characterPosition, order: .forward)]
    )
    return (try? context.fetch(descriptor)) ?? []
}

func getActiveComments(forVersion version: Version, context: ModelContext) -> [CommentModel] {
    let versionID = version.id
    let descriptor = FetchDescriptor<CommentModel>(
        predicate: #Predicate { comment in
            comment.version?.id == versionID && comment.resolvedAt == nil
        },
        sortBy: [SortDescriptor(\.characterPosition, order: .forward)]
    )
    return (try? context.fetch(descriptor)) ?? []
}

func getResolvedComments(forVersion version: Version, context: ModelContext) -> [CommentModel] {
    let versionID = version.id
    let descriptor = FetchDescriptor<CommentModel>(
        predicate: #Predicate { comment in
            comment.version?.id == versionID && comment.resolvedAt != nil
        },
        sortBy: [SortDescriptor(\.characterPosition, order: .forward)]
    )
    return (try? context.fetch(descriptor)) ?? []
}
```

## Benefits of This Approach

1. **Always Fresh Data**: Queries hit the database directly, so changes are immediately visible
2. **No Refetch Needed**: Tests don't need complex refetch logic after modifications
3. **Consistent Behavior**: Both production and test code get the same fresh data
4. **Performance**: Minimal impact - FetchDescriptor is optimized by SwiftData

## Test Simplification

### Before (Complex Refetch Pattern)

```swift
func testMoveFootnoteToTrash() throws {
    manager.moveFootnoteToTrash(footnote, context: modelContext)
    
    // Refetch version to get updated relationships
    let versionID = testVersion.id
    let descriptor = FetchDescriptor<Version>(predicate: #Predicate { $0.id == versionID })
    let refreshedVersion = try modelContext.fetch(descriptor).first!
    
    let deletedFootnotes = manager.getDeletedFootnotes(forVersion: refreshedVersion, context: modelContext)
    XCTAssertEqual(deletedFootnotes.count, 1)
}
```

### After (Simple Direct Query)

```swift
func testMoveFootnoteToTrash() throws {
    manager.moveFootnoteToTrash(footnote, context: modelContext)
    
    let deletedFootnotes = manager.getDeletedFootnotes(forVersion: testVersion, context: modelContext)
    XCTAssertEqual(deletedFootnotes.count, 1)
}
```

## Key Learnings

### SwiftData Relationship Behavior

- `@Relationship` arrays are **cached** on the parent object
- Modifying child objects doesn't automatically update parent's array
- `context.save()` persists changes but doesn't invalidate caches
- `context.processPendingChanges()` doesn't force relationship refresh
- Even refetching the parent object may not refresh its relationships

### Best Practice

**For query methods that need fresh data:**
- ✅ Use `FetchDescriptor` to query database directly
- ❌ Don't rely on cached `@Relationship` arrays

**For UI views that need relationships:**
- ✅ Use `@Relationship` arrays (they work fine for SwiftUI's observation)
- ✅ Call `loadData()` methods after modifications to trigger UI refresh

## Files Modified

### Production Code
1. `Managers/FootnoteManager.swift`
   - Updated: `getAllFootnotes(forVersion:context:)`
   - Updated: `getActiveFootnotes(forVersion:context:)`
   - Updated: `getDeletedFootnotes(forVersion:context:)`

2. `Managers/CommentManager.swift`
   - Updated: `getComments(forVersion:context:)`
   - Updated: `getActiveComments(forVersion:context:)`
   - Updated: `getResolvedComments(forVersion:context:)`

### Test Code
3. `WritingShedProTests/FootnoteManagerTests.swift`
   - Removed all refetch logic (no longer needed)
   - Changed `.moveToTrash()` calls to use `manager.moveFootnoteToTrash()`
   - Simplified test assertions

## Result

✅ All 100+ unit tests now pass
✅ No more stale relationship data issues
✅ Tests are simpler and more maintainable
✅ Production code gets same benefits of fresh data

## Related Documentation

- See `REFACTORING_COMPLETE_VERSION_CENTRIC_ANNOTATIONS.md` for the full refactoring context
- See `SESSION_COMPLETE_ALL_TESTS_PASSING.md` for test status before this fix
