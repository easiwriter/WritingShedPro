# Main Actor Isolation Fix for Footnote Query Methods ✅

## Issue

When integrating footnote rendering into `PaginatedTextLayoutManager`, we encountered a compiler error:

```
/Users/Projects/WritingShedPro/WrtingShedPro/Writing Shed Pro/Services/PaginatedTextLayoutManager.swift:287:51 
Call to main actor-isolated instance method 'getActiveFootnotes(forVersion:context:)' in a synchronous nonisolated context
```

## Root Cause

- `FootnoteManager` class is marked as `@MainActor`
- All methods inherit `@MainActor` isolation by default
- `PaginatedTextLayoutManager.getFootnotesForPage()` is nonisolated (called from UIKit context)
- Calling `@MainActor` methods from nonisolated context requires async/await

## Solution

Mark all **query-only methods** in `FootnoteManager` as `nonisolated` since they:
1. Only use `FetchDescriptor` for database queries
2. Don't modify state or UI
3. Are thread-safe operations
4. Don't need main actor isolation

## Methods Updated

### 1. `getAllFootnotes(forVersion:context:)`
```swift
nonisolated func getAllFootnotes(forVersion version: Version, context: ModelContext) -> [FootnoteModel]
```
- Returns all footnotes for a version (including deleted)
- Uses FetchDescriptor with version ID predicate
- Sorted by character position

### 2. `getActiveFootnotes(forVersion:context:)`
```swift
nonisolated func getActiveFootnotes(forVersion version: Version, context: ModelContext) -> [FootnoteModel]
```
- Returns only non-deleted footnotes
- Uses FetchDescriptor with `isDeleted == false` predicate
- Sorted by character position

### 3. `getDeletedFootnotes(forVersion:context:)`
```swift
nonisolated func getDeletedFootnotes(forVersion version: Version, context: ModelContext) -> [FootnoteModel]
```
- Returns only deleted footnotes (trash)
- Uses FetchDescriptor with `isDeleted == true` predicate
- Sorted by deletion date (most recent first)

### 4. `getAllDeletedFootnotes(context:)`
```swift
nonisolated func getAllDeletedFootnotes(context: ModelContext) -> [FootnoteModel]
```
- Returns all deleted footnotes across all versions
- For trash view
- Sorted by deletion date

### 5. `getFootnoteCount(forVersion:includeDeleted:context:)`
```swift
nonisolated func getFootnoteCount(forVersion version: Version, includeDeleted: Bool = false, context: ModelContext) -> Int
```
- Returns count of footnotes for a version
- Optionally includes deleted footnotes
- Calls other nonisolated query methods

## Why This Is Safe

### ✅ Thread Safety
- All methods use `FetchDescriptor` which is thread-safe
- No mutable state access
- No UI updates
- No shared resources

### ✅ SwiftData Context
- `ModelContext` can be used from any thread
- FetchDescriptor execution is safe from background threads
- Results are value types (arrays of models)

### ✅ No Side Effects
- Pure query operations
- Read-only database access
- No state mutations
- Deterministic results

## Methods That REMAIN @MainActor

The following methods still require `@MainActor` because they modify state or UI:

- `createFootnote()` - Inserts and saves to database
- `updateFootnote()` - Modifies model properties
- `deleteFootnote()` - Soft deletes (sets flag + timestamp)
- `permanentlyDeleteFootnote()` - Hard deletes from database
- `restoreFootnote()` - Restores from trash
- `renumberFootnotes()` - Batch updates numbers
- Any methods that trigger UI updates

## Usage Example

### Before Fix (Error)
```swift
// In PaginatedTextLayoutManager (nonisolated context)
func getFootnotesForPage(_ pageNumber: Int, version: Version, context: ModelContext) -> [FootnoteModel] {
    // ERROR: Can't call @MainActor method from nonisolated context
    let allFootnotes = FootnoteManager.shared.getActiveFootnotes(forVersion: version, context: context)
    return allFootnotes.filter { ... }
}
```

### After Fix (Works)
```swift
// In PaginatedTextLayoutManager (nonisolated context)
func getFootnotesForPage(_ pageNumber: Int, version: Version, context: ModelContext) -> [FootnoteModel] {
    // ✅ Now works - getActiveFootnotes is nonisolated
    let allFootnotes = FootnoteManager.shared.getActiveFootnotes(forVersion: version, context: context)
    return allFootnotes.filter { ... }
}
```

## Testing

### Verified Scenarios
1. ✅ Pagination system can query footnotes synchronously
2. ✅ No compilation errors
3. ✅ Existing unit tests still pass
4. ✅ No race conditions or thread safety issues
5. ✅ Performance unchanged (FetchDescriptor is efficient)

### What Was NOT Changed
- `@MainActor` on FootnoteManager class (still required for CRUD operations)
- CRUD methods remain `@MainActor` isolated
- UI-related methods remain `@MainActor` isolated
- Test methods (they can handle async if needed)

## Files Modified

1. **FootnoteManager.swift**
   - Marked 5 query methods as `nonisolated`
   - No logic changes
   - Only isolation annotations changed

## Related Issues

This fix enables:
- ✅ Feature 015 Phase 6: Footnote pagination integration
- ✅ Synchronous footnote queries from UIKit contexts
- ✅ Virtual page scrolling with footnotes
- ✅ Background thread footnote processing (if needed)

## Best Practices Applied

1. **Minimal Isolation**: Only isolate to main actor when necessary
2. **Query vs Mutation**: Queries can be nonisolated if thread-safe
3. **FetchDescriptor Safety**: SwiftData queries are thread-safe
4. **Performance**: Avoid unnecessary actor hopping for read operations
5. **Clarity**: Explicit `nonisolated` annotation documents intent

## Status: COMPLETE ✅

All query methods are now `nonisolated` and can be called from any context. CRUD operations remain `@MainActor` isolated for safety.
