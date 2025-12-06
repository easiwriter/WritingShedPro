# Search and Replace Scope Decision

**Date:** 6 December 2025  
**Status:** Deferred

## Decision

The plan to extend search/replace functionality to be project/collection-wide has been **deferred indefinitely**.

## Context

The current implementation provides in-editor search and replace functionality that works within a single document:
- Search with case-sensitive, whole word, and regex options
- Navigate through matches (previous/next)
- Replace individual matches or all matches
- Visual highlighting of matches
- Undo/redo support for individual replacements

## Original Plan

The intention was to extend this to support:
- Searching across all files in a collection
- Searching across all files in the project
- Project-wide replace operations

## Rationale for Deferral

After implementing and debugging the in-editor search/replace functionality, the decision was made to focus on other priorities rather than expanding the scope at this time.

## Current Implementation Status

The in-editor search and replace is **fully functional** with:
- ✅ Search with multiple match navigation
- ✅ Replace individual matches (with undo support)
- ✅ Replace All (batch operation, no undo)
- ✅ Visual feedback via yellow highlights
- ✅ Match count display
- ✅ Options: case-sensitive, whole word, regex
- ✅ Icon-based UI with `arrow.2.squarepath` toggle (macOS-compatible)

## Future Considerations

If project/collection-wide search is revisited in the future, consider:

1. **UI Design:**
   - Separate panel or modal for multi-file search results
   - File list with match counts per file
   - Preview of matches in context

2. **Performance:**
   - Async/background search for large projects
   - Incremental loading of results
   - Search indexing for faster queries

3. **Replace Operations:**
   - Preview all replacements before applying
   - Select/deselect individual files or matches
   - Atomic operation with full undo capability

4. **SwiftData Integration:**
   - Efficient querying across file content
   - Handle locked versions appropriately
   - CloudKit sync considerations

## Related Files

- `InEditorSearchManager.swift` - Current search/replace implementation
- `InEditorSearchBar.swift` - Search UI
- `FileEditView.swift` - Editor integration

## Notes

The current in-editor implementation is sufficient for most user workflows. Project-wide search would add complexity and potential performance issues that may not be worth the benefit at this stage.

---

**Future Status Updates:** Add notes here if/when this is reconsidered.
