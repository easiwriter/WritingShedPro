# Feature 017: Search and Replace - Task Breakdown

## Task List (81 tasks across 7 phases)

### Phase 1: Foundation & Single File Search (19 tasks)

**1.1 Data Models (4 tasks)**
- [ ] Create SearchQuery struct with all properties (searchText, replaceText, options, scope)
- [ ] Create SearchMatch struct (id, range, context, lineNumber)
- [ ] Create SearchOptions struct with Codable support and UserDefaults
- [ ] Write unit tests for SearchQuery, SearchMatch, SearchOptions

**1.2 Core Search Engine (5 tasks)**
- [ ] Create TextSearchEngine.swift class with search methods
- [ ] Implement case-sensitive text search algorithm
- [ ] Implement whole-word boundary detection
- [ ] Implement context extraction (50 chars before/after match)
- [ ] Write unit tests for all search variations (15+ test cases)

**1.3 In-Editor Search Manager (5 tasks)**
- [ ] Create InEditorSearchManager.swift as ObservableObject
- [ ] Implement performSearch() with match highlighting
- [ ] Implement nextMatch()/previousMatch() navigation
- [ ] Implement auto-scroll to current match
- [ ] Write unit tests for search manager (10+ test cases)

**1.4 Search Bar UI (3 tasks)**
- [ ] Create InEditorSearchBar.swift SwiftUI view
- [ ] Add search field, navigation buttons, match counter, options toggles
- [ ] Add keyboard shortcut handlers (⌘F, ⌘G, ⌘⇧G, ⎋)

**1.5 FileEditView Integration (2 tasks)**
- [ ] Add search bar toggle to FileEditView toolbar
- [ ] Connect search bar to InEditorSearchManager and test end-to-end

---

### Phase 2: Single File Replace (8 tasks)

**2.1 Replace Logic (4 tasks)**
- [ ] Add replaceCurrentMatch() method to InEditorSearchManager
- [ ] Add replaceAllMatches() method with batch operation
- [ ] Integrate replace with TextFileUndoManager for undo/redo
- [ ] Write unit tests for replace operations (8+ test cases)

**2.2 Replace UI (3 tasks)**
- [ ] Add replace text field and buttons to InEditorSearchBar
- [ ] Add replace mode toggle and "Replace All" confirmation dialog
- [ ] Update match counter dynamically after replacements

**2.3 Replace Integration (1 task)**
- [ ] Test all replace scenarios: single, all, undo, redo, edge cases

---

### Phase 3: Project-Wide Search Infrastructure (13 tasks)

**3.1 Multi-File Search Service (6 tasks)**
- [ ] Create SearchService.swift with @MainActor and @Published properties
- [ ] Implement search(query:scope:context:) method with Task/async
- [ ] Add cancelSearch() method with task cancellation
- [ ] Create SearchResult model (file, version, matches array)
- [ ] Add progress tracking (@Published progress: Double)
- [ ] Write unit tests for SearchService (12+ test cases)

**3.2 Search Results Data (4 tasks)**
- [ ] Implement results grouping by file/folder hierarchy
- [ ] Calculate match counts per file/folder
- [ ] Implement result sorting options (by file, by count, alphabetical)
- [ ] Write unit tests for results processing

**3.3 Search Panel UI (1 task)**
- [ ] Create SearchAndReplacePanel.swift with scope selector, search field, options, progress indicator

**3.4 Results Display UI (1 task)**
- [ ] Create SearchResultsView.swift with hierarchical list, expand/collapse, context preview

**3.5 Navigation Integration (1 task)**
- [ ] Implement navigation from search result to file with match highlighting

---

### Phase 4: Collection Scope & Multi-File Replace (10 tasks)

**4.1 Collection Search (3 tasks)**
- [ ] Add collection scope filtering to SearchService
- [ ] Update SearchAndReplacePanel with collection selector
- [ ] Write unit tests for collection-scoped search

**4.2 Multi-File Replace Logic (4 tasks)**
- [ ] Implement replaceAll(in:with:context:) async method in SearchService
- [ ] Add file selection state management (Set<UUID>)
- [ ] Add per-file error handling and reporting
- [ ] Write unit tests for multi-file replace (10+ test cases)

**4.3 Multi-File Replace UI (2 tasks)**
- [ ] Add file selection checkboxes and "Select All/None" buttons
- [ ] Add "Replace in Selected Files" button with confirmation dialog and progress

**4.4 Multi-File Replace Integration (1 task)**
- [ ] Test multi-file replace: full, partial, error scenarios, version history

---

### Phase 5: Regex Support (7 tasks)

**5.1 Regex Engine (4 tasks)**
- [ ] Add buildRegex(from:) method with NSRegularExpression
- [ ] Implement regex validation with error messages
- [ ] Add regex search with match extraction
- [ ] Write unit tests for regex patterns (15+ test cases)

**5.2 Regex UI (2 tasks)**
- [ ] Add regex toggle to search options with validation feedback
- [ ] Add regex error display and help documentation link

**5.3 Regex Replace (1 task)**
- [ ] Implement capture group replacement ($1, $2, etc.) and test thoroughly

---

### Phase 6: Polish & Optimization (14 tasks)

**6.1 Performance Optimization (3 tasks)**
- [ ] Profile and optimize search on 10k+ word files (<100ms target)
- [ ] Profile and optimize project search on 100+ files (<2s target)
- [ ] Add result pagination if needed (first 1000 results)

**6.2 Search History (3 tasks)**
- [ ] Implement search/replace history storage in SearchOptions
- [ ] Add history dropdown with auto-complete suggestions
- [ ] Add clear history option in settings

**6.3 Keyboard Navigation (2 tasks)**
- [ ] Implement and test all keyboard shortcuts (macOS and iOS external keyboard)
- [ ] Document shortcuts in help/tooltip system

**6.4 Accessibility (3 tasks)**
- [ ] Add VoiceOver labels and hints to all search UI controls
- [ ] Test with VoiceOver and adjust for usability
- [ ] Add Dynamic Type support to search UI

**6.5 Edge Cases & Error Handling (2 tasks)**
- [ ] Test edge cases: empty strings, Unicode, emoji, very long strings, locked files
- [ ] Add proper error handling and user feedback for all failure scenarios

**6.6 User Preferences (1 task)**
- [ ] Add search preferences to Settings: default scope, auto-save, version creation, debounce delay

---

### Phase 7: Testing & Documentation (10 tasks)

**7.1 Unit Tests (2 tasks)**
- [ ] Achieve >90% code coverage for all search/replace logic
- [ ] Add tests for all option combinations and error conditions

**7.2 Integration Tests (2 tasks)**
- [ ] Write integration tests for all workflows: single file, project-wide, multi-file replace
- [ ] Test undo/redo and navigation integration

**7.3 Performance Tests (2 tasks)**
- [ ] Create performance benchmarks for all search scenarios
- [ ] Document performance characteristics and limits

**7.4 User Documentation (2 tasks)**
- [ ] Create user guide with keyboard shortcuts and regex examples
- [ ] Add in-app help text, tooltips, and contextual hints

**7.5 Final QA (2 tasks)**
- [ ] Complete feature testing on iOS and macOS with CloudKit sync
- [ ] Fix all discovered bugs and verify against acceptance criteria

---

## Task Summary by Phase

| Phase | Tasks | Est. Duration |
|-------|-------|---------------|
| Phase 1: Single File Search | 19 | 10 days |
| Phase 2: Single File Replace | 8 | 4 days |
| Phase 3: Project-Wide Search | 13 | 8 days |
| Phase 4: Multi-File Replace | 10 | 6 days |
| Phase 5: Regex Support | 7 | 5 days |
| Phase 6: Polish & Optimization | 14 | 8 days |
| Phase 7: Testing & Documentation | 10 | 6 days |
| **TOTAL** | **81 tasks** | **47 days** |

## Priority Tasks (Must Have for MVP)

1. ✅ Phase 1: Single file search with highlighting
2. ✅ Phase 2: Single file replace with undo
3. ✅ Phase 3: Project-wide search with results
4. ✅ Phase 4: Multi-file replace

## Optional Tasks (Can Defer)

- Phase 5: Regex support (can ship without, add later)
- Phase 6: Search history (nice to have)
- Some optimization work (if performance is acceptable)

## Critical Path

```
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 7
(Must complete in sequence)

Phase 5 & Phase 6 can be done in parallel with final testing
```

## Task Dependencies

- **Phase 2** depends on Phase 1 (search must work before replace)
- **Phase 3** depends on Phase 1 (single-file search is foundation)
- **Phase 4** depends on Phase 3 (multi-file needs search infrastructure)
- **Phase 5** is independent (can be added anytime after Phase 1)
- **Phase 6** depends on all previous phases
- **Phase 7** depends on all feature phases being complete

## Estimated Effort

- **Full implementation:** 7-9 weeks (with all features)
- **MVP (Phases 1-4 + 7):** 5-6 weeks
- **Per-phase average:** 6-8 days

## Next Steps

1. **User answers open questions** (from plan.md)
2. **Start Phase 1, Task 1.1:** Create data models
3. **Daily progress tracking:** Mark tasks complete as we go
4. **Weekly reviews:** Assess progress, adjust timeline if needed
