# Feature 017: Search and Replace - Design Decisions

## Finalized User Decisions (4 December 2025)

### 1. Replace Behavior
**Decision:** **B - Modify in-place**

Replace operations will modify the current version's content directly without creating new versions. This keeps the version history clean and focused on intentional versioning actions.

**Implementation Notes:**
- Replace updates `version.content` directly
- Replace operations are undoable via TextFileUndoManager
- User can manually create version before replace if desired
- Timestamps (modifiedDate) update automatically

---

### 2. Search Scope Default
**Decision:** **A - Current File**

The search interface defaults to "Current File" scope for focused, quick searches.

**Implementation Notes:**
- InEditorSearchBar defaults to current file only
- SearchAndReplacePanel remembers last used scope (stored in UserDefaults)
- User can easily switch scopes via scope selector
- Most common use case is searching within active file

---

### 3. Auto-save After Replace
**Decision:** **B - No (manual save)**

Replace operations do NOT auto-save. User must manually save changes.

**Implementation Notes:**
- Replace modifies content in memory only
- File marked as "unsaved" after replace (standard behavior)
- User saves via existing save mechanisms (⌘S, auto-save timer, navigation away)
- Allows user to undo replace before saving if desired

---

### 4. Search in Locked Versions
**Decision:** **A - Yes, search but disable replace (with warning)**

Locked versions are searchable but cannot be replaced.

**Implementation Notes:**
- Search includes locked versions in results
- Replace UI shows warning when locked version is active
- "Replace" and "Replace All" buttons disabled for locked versions
- Warning message: "Cannot replace in locked version. This version is locked because [reason]."
- Multi-file replace skips locked versions with notification

---

### 5. Maximum Results Limit
**Decision:** **A - No limit (show everything)**

Search displays all results without pagination or limits.

**Implementation Notes:**
- All matches displayed in results list
- Performance acceptable for typical project sizes
- If performance issues arise in future, can add optional limit
- Results list uses lazy loading for efficiency

---

### 6. Regex Default
**Decision:** **A - Off by default**

Regex mode is disabled by default for simplicity.

**Implementation Notes:**
- Regex toggle starts as unchecked
- SearchOptions stores last used setting in UserDefaults
- Plain text search is default for most users
- Advanced users can enable regex as needed

---

## Implementation Impact

### Code Changes Required:
- `SearchOptions`: Set regex default to `false`
- `InEditorSearchManager`: Check version lock status before replace
- `SearchService`: Filter locked versions for replace operations
- Replace UI: Add lock status checking and warning display
- No auto-save logic needed (rely on existing save system)
- No version creation on replace (direct content modification)

### UI Changes Required:
- Default scope selector to "Current File"
- Show warning badge/message for locked versions
- Disable replace buttons when locked version active
- No pagination UI needed for results

### Testing Changes Required:
- Test replace in unlocked versions (should work)
- Test replace attempt in locked versions (should block)
- Test multi-file replace with mixed locked/unlocked files
- Test undo/redo without auto-save
- Test large result sets (1000+ matches)

---

## Design Rationale

### Why In-Place Replace?
- Cleaner version history (versions are intentional snapshots)
- More intuitive for users (replace is an edit, not a version)
- Consistent with other editing operations
- Undo/redo provides safety net

### Why Current File Default?
- Most searches are within active document
- Faster (no multi-file overhead)
- Less overwhelming for new users
- Easy to expand scope if needed

### Why No Auto-Save?
- Consistent with app's manual save behavior
- Gives user control over persistence timing
- Allows undo before committing changes
- Standard for professional writing apps

### Why Search Locked Versions?
- Users need to find content even in locked files
- Read-only search is still valuable
- Clear warning prevents accidental edit attempts
- Maintains visibility into all content

### Why No Result Limit?
- Most projects are small enough (<1000 files)
- Users expect to see all results
- Simpler implementation (no pagination)
- Can add limit later if performance issues arise

### Why Regex Off by Default?
- Simpler for majority of users
- Plain text search covers 95% of use cases
- Regex errors can be confusing
- Advanced users can easily enable when needed

---

## Future Considerations

### Potential Additions:
1. Optional "Create version before replace" checkbox
2. Result limit preference if performance issues arise
3. Regex pattern library/presets for common patterns
4. Auto-save preference for users who want it
5. Smart unlock for replace (with confirmation)

### Performance Monitoring:
- Track search/replace performance metrics
- Monitor large project behavior (1000+ files)
- Consider indexing if search becomes slow
- Optimize regex engine if complex patterns lag

---

## Status: ✅ Ready for Implementation

All design decisions finalized. Proceeding with Phase 1 implementation.
