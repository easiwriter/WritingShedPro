# Feature 017: Search and Replace - Implementation Plan

## Implementation Phases

### Phase 1: Foundation & Single File Search (Week 1-2)
**Goal:** Basic in-editor search with highlighting and navigation

#### Task 1.1: Data Models
- [ ] Create `SearchQuery` struct
- [ ] Create `SearchMatch` struct  
- [ ] Create `SearchOptions` struct with UserDefaults support
- [ ] Add unit tests for data models

#### Task 1.2: Core Search Engine
- [ ] Implement `TextSearchEngine` class
- [ ] Add case-sensitive search
- [ ] Add whole-word search
- [ ] Add context extraction (50 chars before/after)
- [ ] Add unit tests for search algorithms

#### Task 1.3: In-Editor Search Manager
- [ ] Create `InEditorSearchManager` class
- [ ] Implement `performSearch()` method
- [ ] Implement `nextMatch()` / `previousMatch()` navigation
- [ ] Add match highlighting logic
- [ ] Add auto-scroll to current match
- [ ] Add unit tests

#### Task 1.4: Search Bar UI
- [ ] Create `InEditorSearchBar` SwiftUI view
- [ ] Add search text field with clear button
- [ ] Add navigation buttons (previous/next)
- [ ] Add match counter display
- [ ] Add options toggles (case, whole word)
- [ ] Add keyboard shortcut handling (⌘F, ⌘G, ⌘⇧G)

#### Task 1.5: FileEditView Integration
- [ ] Add search bar to FileEditView toolbar
- [ ] Connect search bar to InEditorSearchManager
- [ ] Implement highlight rendering in text view
- [ ] Add search state persistence
- [ ] Test search functionality end-to-end

### Phase 2: Single File Replace (Week 2)
**Goal:** Replace operations in current file

#### Task 2.1: Replace Logic
- [ ] Add `replaceCurrentMatch()` to InEditorSearchManager
- [ ] Add `replaceAllMatches()` to InEditorSearchManager
- [ ] Integrate with undo/redo system
- [ ] Add unit tests for replace operations

#### Task 2.2: Replace UI
- [ ] Add replace text field to search bar
- [ ] Add "Replace" button
- [ ] Add "Replace All" button
- [ ] Add confirmation dialog for Replace All
- [ ] Add replace mode toggle
- [ ] Update match counter after replacements

#### Task 2.3: Replace Integration
- [ ] Connect replace UI to replace logic
- [ ] Test undo/redo for single replace
- [ ] Test undo/redo for replace all
- [ ] Test edge cases (empty replacement, special chars)

### Phase 3: Project-Wide Search Infrastructure (Week 3)
**Goal:** Search across multiple files with results display

#### Task 3.1: Multi-File Search Service
- [ ] Create `SearchService` class
- [ ] Implement background search with Task
- [ ] Add project scope search
- [ ] Add search cancellation
- [ ] Create `SearchResult` model
- [ ] Add progress tracking
- [ ] Add unit tests

#### Task 3.2: Search Results Data
- [ ] Group results by file/folder
- [ ] Calculate match counts per file
- [ ] Extract context for each match
- [ ] Sort results (by file, by match count, etc.)
- [ ] Add unit tests

#### Task 3.3: Search Panel UI
- [ ] Create `SearchAndReplacePanel` view
- [ ] Add scope selector (File/Collection/Project)
- [ ] Add search field and options
- [ ] Add search trigger button
- [ ] Show search progress indicator
- [ ] Add cancellation button

#### Task 3.4: Results Display UI
- [ ] Create `SearchResultsView` component
- [ ] Create `SearchResultRow` component
- [ ] Show file hierarchy with match counts
- [ ] Show context preview for each match
- [ ] Add expand/collapse for files
- [ ] Implement result navigation (tap to open file)

#### Task 3.5: Navigation Integration
- [ ] Navigate to file from search result
- [ ] Highlight selected match in file
- [ ] Maintain search panel state during navigation
- [ ] Test cross-view navigation

### Phase 4: Collection Scope & Multi-File Replace (Week 4)
**Goal:** Collection-scoped search and multi-file replace

#### Task 4.1: Collection Search
- [ ] Add collection scope to SearchService
- [ ] Filter results by collection membership
- [ ] Update UI for collection scope
- [ ] Add collection selection (if multiple)
- [ ] Test collection search

#### Task 4.2: Multi-File Replace Logic
- [ ] Implement `replaceAll(in:with:)` in SearchService
- [ ] Add file selection state management
- [ ] Create batch replace operation
- [ ] Add progress tracking
- [ ] Add error handling per file
- [ ] Add unit tests

#### Task 4.3: Multi-File Replace UI
- [ ] Add checkboxes for file selection
- [ ] Add "Select All" / "Deselect All" buttons
- [ ] Add replace field to search panel
- [ ] Add "Replace in Selected Files" button
- [ ] Add confirmation dialog with preview
- [ ] Show replace progress

#### Task 4.4: Multi-File Replace Integration
- [ ] Connect UI to replace service
- [ ] Test replace across multiple files
- [ ] Test partial replacement (selected files only)
- [ ] Test error scenarios (locked files, etc.)
- [ ] Verify version history updates

### Phase 5: Regex Support (Week 5)
**Goal:** Regular expression search and replace

#### Task 5.1: Regex Engine
- [ ] Add regex validation
- [ ] Implement regex search using NSRegularExpression
- [ ] Add error handling for invalid patterns
- [ ] Add capture group support
- [ ] Add unit tests for regex patterns

#### Task 5.2: Regex UI
- [ ] Add regex toggle to search options
- [ ] Add regex validation feedback
- [ ] Show regex error messages
- [ ] Add regex help/documentation link
- [ ] Test regex toggle behavior

#### Task 5.3: Regex Replace
- [ ] Implement capture group replacement ($1, $2, etc.)
- [ ] Add unit tests for capture groups
- [ ] Test complex regex patterns
- [ ] Test regex performance on large files

### Phase 6: Polish & Optimization (Week 6)
**Goal:** Performance, UX refinement, and edge cases

#### Task 6.1: Performance Optimization
- [ ] Profile search performance on large files (10k+ words)
- [ ] Profile project-wide search on 100+ files
- [ ] Optimize debounce timing
- [ ] Add result pagination if needed
- [ ] Test memory usage with large result sets

#### Task 6.2: Search History
- [ ] Save search history to UserDefaults
- [ ] Add search history dropdown/suggestions
- [ ] Limit history to 20 items
- [ ] Save replace history separately
- [ ] Clear history option

#### Task 6.3: Keyboard Navigation
- [ ] Implement all keyboard shortcuts
- [ ] Test keyboard navigation flow
- [ ] Add iOS external keyboard support
- [ ] Document shortcuts in help

#### Task 6.4: Accessibility
- [ ] Add VoiceOver labels to all controls
- [ ] Test with VoiceOver enabled
- [ ] Add Dynamic Type support
- [ ] Test with accessibility settings
- [ ] Add accessibility hints

#### Task 6.5: Edge Cases & Error Handling
- [ ] Test empty search/replace strings
- [ ] Test special characters (Unicode, emoji)
- [ ] Test very long search strings
- [ ] Test locked/read-only files
- [ ] Test search during file editing
- [ ] Handle search while file is deleted

#### Task 6.6: User Preferences
- [ ] Add search preferences to Settings
- [ ] Default scope preference
- [ ] Auto-save after replace preference
- [ ] Create version on replace preference
- [ ] Debounce delay preference

### Phase 7: Testing & Documentation (Week 7)
**Goal:** Comprehensive testing and user documentation

#### Task 7.1: Unit Tests
- [ ] Achieve >90% code coverage for search logic
- [ ] Test all search options combinations
- [ ] Test all replace scenarios
- [ ] Test regex patterns
- [ ] Test error conditions

#### Task 7.2: Integration Tests
- [ ] Test single file search workflow
- [ ] Test project-wide search workflow
- [ ] Test multi-file replace workflow
- [ ] Test undo/redo integration
- [ ] Test navigation integration

#### Task 7.3: Performance Tests
- [ ] Benchmark single file search (1k, 10k, 100k words)
- [ ] Benchmark project search (10, 100, 1000 files)
- [ ] Benchmark regex performance
- [ ] Benchmark replace all operations
- [ ] Document performance characteristics

#### Task 7.4: User Documentation
- [ ] Create user guide for search feature
- [ ] Document keyboard shortcuts
- [ ] Create regex pattern examples
- [ ] Add tooltips/help text in UI
- [ ] Create video tutorial (optional)

#### Task 7.5: Final QA
- [ ] Full feature testing on iOS
- [ ] Full feature testing on macOS
- [ ] Test with CloudKit sync
- [ ] Test edge cases
- [ ] Fix any discovered bugs

## File Structure

```
WrtingShedPro/
├── Models/
│   ├── SearchQuery.swift          (NEW)
│   └── SearchOptions.swift        (NEW)
├── Services/
│   ├── SearchService.swift        (NEW)
│   ├── TextSearchEngine.swift     (NEW)
│   └── InEditorSearchManager.swift (NEW)
├── Views/
│   ├── Search/
│   │   ├── InEditorSearchBar.swift        (NEW)
│   │   ├── SearchAndReplacePanel.swift    (NEW)
│   │   ├── SearchResultsView.swift        (NEW)
│   │   ├── SearchResultRow.swift          (NEW)
│   │   └── SearchOptionsView.swift        (NEW)
│   └── FileEditView.swift         (MODIFY)
└── Tests/
    ├── SearchServiceTests.swift    (NEW)
    ├── TextSearchEngineTests.swift (NEW)
    ├── InEditorSearchManagerTests.swift (NEW)
    └── SearchIntegrationTests.swift (NEW)
```

## Dependencies

### Internal
- Feature 004: Undo/Redo System (for replace operations)
- BaseModels.swift (TextFile, Version, Folder, Project)
- FileEditView.swift (integration point)

### External
- Foundation (NSRegularExpression, NSRange)
- SwiftUI (UI components)
- SwiftData (ModelContext for file access)
- Combine (for debouncing)

## Risk Mitigation

### Performance Risks
- **Mitigation 1:** Implement search cancellation early
- **Mitigation 2:** Add progress indicators in Phase 3
- **Mitigation 3:** Profile regularly, optimize hot paths
- **Mitigation 4:** Consider result pagination if needed

### Complexity Risks
- **Mitigation 1:** Start with simple text search, add regex later
- **Mitigation 2:** Comprehensive unit tests at each phase
- **Mitigation 3:** Code reviews for search algorithms
- **Mitigation 4:** User testing after each phase

### UX Risks
- **Mitigation 1:** Follow platform conventions (macOS/iOS)
- **Mitigation 2:** User testing after Phase 2 and Phase 4
- **Mitigation 3:** Clear error messages and feedback
- **Mitigation 4:** Progressive disclosure for advanced features

## Success Criteria

### Phase 1 Complete
- ✅ Can search in current file
- ✅ Matches highlighted correctly
- ✅ Navigation works (prev/next)
- ✅ Keyboard shortcuts functional
- ✅ >80% unit test coverage

### Phase 2 Complete
- ✅ Can replace single match
- ✅ Can replace all matches
- ✅ Undo/redo works correctly
- ✅ Replace confirmation works
- ✅ >80% unit test coverage

### Phase 3 Complete
- ✅ Project-wide search works
- ✅ Results grouped by file
- ✅ Can navigate to results
- ✅ Search runs in background
- ✅ >80% unit test coverage

### Phase 4 Complete
- ✅ Collection scope works
- ✅ Multi-file replace works
- ✅ File selection works
- ✅ Progress tracking works
- ✅ >80% unit test coverage

### Phase 5 Complete
- ✅ Regex search works
- ✅ Regex replace works
- ✅ Capture groups work
- ✅ Error handling works
- ✅ >80% unit test coverage

### Phase 6 Complete
- ✅ Search completes <100ms single file
- ✅ Project search <2s for 100 files
- ✅ Search history works
- ✅ All keyboard shortcuts work
- ✅ VoiceOver accessible

### Phase 7 Complete
- ✅ >90% code coverage
- ✅ All integration tests pass
- ✅ Performance benchmarks documented
- ✅ User documentation complete
- ✅ Zero critical bugs

## Timeline

- **Week 1:** Phase 1 (Foundation & Single File Search)
- **Week 2:** Phase 2 (Single File Replace)
- **Week 3:** Phase 3 (Project-Wide Search)
- **Week 4:** Phase 4 (Collection & Multi-File Replace)
- **Week 5:** Phase 5 (Regex Support)
- **Week 6:** Phase 6 (Polish & Optimization)
- **Week 7:** Phase 7 (Testing & Documentation)

**Total Duration:** 7 weeks

## Open Questions for User

Before implementation, please confirm:

1. **Replace Behavior:** Should replace operations create new versions or modify in-place?
   - Option A: Create new version (preserves history, uses more storage)
   - Option B: Modify in-place (cleaner, but loses pre-replace state)
   - Option C: User preference setting

2. **Search Scope Default:** What should be the default search scope?
   - Current File (most focused)
   - Project (most comprehensive)
   - Last used scope (most convenient)

3. **Auto-save After Replace:** Should the app auto-save after replace operations?
   - Yes (immediate persistence)
   - No (manual save required)
   - User preference

4. **Search in Locked Versions:** Should locked versions be searchable?
   - Yes, search but disable replace (read-only search)
   - No, skip locked versions entirely

5. **Maximum Results:** Should we limit search results display?
   - No limit (show everything)
   - Limit to 1000 with "Load More" button
   - Limit to 500 with pagination

6. **Regex Default:** Should regex be opt-in or opt-out?
   - Off by default (simpler for most users)
   - Remember last setting (convenience)

Please provide answers to these questions so I can proceed with implementation!
