# Feature 017: Search and Replace

## Overview
Provide comprehensive search and replace functionality across different scopes: single file, collection, or entire project. Users can find text patterns and optionally replace them with new text, with support for case sensitivity, whole word matching, and regex patterns.

## User Stories

### US1: Single File Search
**As a** writer editing a document  
**I want to** search for text within the current file  
**So that** I can quickly navigate to specific content or references

**Acceptance Criteria:**
- Search bar appears in file editor toolbar/interface
- Matches are highlighted in the text
- Navigation between matches (previous/next)
- Live search updates as user types
- Match count displayed (e.g., "3 of 12")
- Search persists when switching between files

### US2: Single File Replace
**As a** writer editing a document  
**I want to** replace found text with new text  
**So that** I can quickly correct repeated errors or update terminology

**Acceptance Criteria:**
- Replace field appears alongside search field
- "Replace" button replaces current match
- "Replace All" button replaces all matches in file
- Undo/redo support for replace operations
- Confirmation for "Replace All" with count preview
- Replace operations update match count in real-time

### US3: Project-Wide Search
**As a** writer managing a large project  
**I want to** search across all files in my project  
**So that** I can find where specific content or references appear

**Acceptance Criteria:**
- Search interface accessible from project view
- Results grouped by file with match counts
- Each result shows context (surrounding text)
- Clicking result navigates to file and highlights match
- Results update in real-time as search query changes
- Shows file path/location for each result

### US4: Collection Search
**As a** writer working with related documents  
**I want to** search within a specific collection  
**So that** I can scope my search to relevant files only

**Acceptance Criteria:**
- Search scope selector: File / Collection / Project
- Collection search only searches files in that collection
- Results display shows which files are included
- Same result format as project-wide search
- Easy switching between scopes without losing query

### US5: Project-Wide Replace
**As a** writer updating terminology across multiple files  
**I want to** replace text across all matching files  
**So that** I can make consistent changes efficiently

**Acceptance Criteria:**
- Replace interface available in project/collection search
- Preview shows all matches before replacing
- Checkbox to select/deselect files for replacement
- "Replace All in Selected Files" button
- Progress indicator for multi-file operations
- Undo support (per-file or batch undo)
- Confirmation dialog with count of changes

### US6: Advanced Search Options
**As a** power user with specific search needs  
**I want to** use case-sensitive, whole word, and regex searches  
**So that** I can find exactly what I need

**Acceptance Criteria:**
- Case sensitive toggle (default: off)
- Whole word toggle (default: off)
- Regex toggle (default: off)
- Options persist between sessions
- Invalid regex shows error message
- Regex capture groups supported in replace

## Functional Requirements

### FR1: Search Interface
- **FR1.1:** In-editor search bar with find field and navigation buttons
- **FR1.2:** Standalone search panel for project/collection scope
- **FR1.3:** Scope selector: Current File / Collection / Project
- **FR1.4:** Search options: Case Sensitive, Whole Word, Use Regex
- **FR1.5:** Match counter: "X of Y matches" or "X matches in Y files"
- **FR1.6:** Keyboard shortcuts: ⌘F (find), ⌘G (next), ⌘⇧G (previous)

### FR2: Search Behavior
- **FR2.1:** Live search updates results as user types (debounced)
- **FR2.2:** Search includes all text content (not comments/footnotes)
- **FR2.3:** Highlights all matches in current file
- **FR2.4:** Current match highlighted differently from other matches
- **FR2.5:** Auto-scroll to show current match in viewport
- **FR2.6:** Empty search clears all highlights

### FR3: Replace Interface
- **FR3.1:** Replace field appears when "Replace" mode enabled
- **FR3.2:** "Replace" button (single match)
- **FR3.3:** "Replace All" button (all matches in scope)
- **FR3.4:** Preview mode for project/collection replace
- **FR3.5:** File selection checkboxes in multi-file replace
- **FR3.6:** Confirmation dialog for "Replace All" with match count

### FR4: Multi-File Results
- **FR4.1:** Results list grouped by file/folder hierarchy
- **FR4.2:** Each result shows: filename, match count, preview text
- **FR4.3:** Context preview: 50 characters before/after match
- **FR4.4:** Click result navigates to file and highlights match
- **FR4.5:** Expand/collapse file groups
- **FR4.6:** Export results to text file

### FR5: Search Options
- **FR5.1:** Case sensitive: exact case matching
- **FR5.2:** Whole word: match word boundaries only
- **FR5.3:** Regex: support standard regex patterns
- **FR5.4:** Options saved in UserDefaults per-scope
- **FR5.5:** Regex validation with error messages
- **FR5.6:** Regex capture groups ($1, $2, etc.) in replace

### FR6: Performance
- **FR6.1:** Search debounced (300ms delay) to avoid excessive updates
- **FR6.2:** Background thread for project-wide search
- **FR6.3:** Progress indicator for long operations (>1 second)
- **FR6.4:** Cancel button for long-running searches
- **FR6.5:** Index-based search for large projects (optional future)
- **FR6.6:** Limit results display (e.g., first 1000 matches)

### FR7: Replace Operations
- **FR7.1:** Single replace moves to next match automatically
- **FR7.2:** Replace All creates single undo operation per file
- **FR7.3:** Multi-file replace shows progress with file count
- **FR7.4:** Replace All confirmation shows: "Replace X matches in Y files?"
- **FR7.5:** Failed replacements show error messages
- **FR7.6:** Replace updates version history (auto-saves)

## Non-Functional Requirements

### NFR1: Performance
- Single file search completes in <50ms for files up to 10,000 words
- Project-wide search completes in <2 seconds for 100 files
- UI remains responsive during background searches
- Regex search performance acceptable (max 5s for complex patterns)

### NFR2: Usability
- Search interface follows platform conventions (iOS/macOS)
- Keyboard navigation fully supported
- Clear visual feedback for all operations
- Accessible to VoiceOver/accessibility tools
- Error messages are clear and actionable

### NFR3: Reliability
- Replace operations are atomic per file (all or nothing)
- Undo/redo works correctly for all replace operations
- Search doesn't modify file content or timestamps
- Handles files with special characters in names/content
- Graceful handling of locked/read-only files

### NFR4: Compatibility
- Works with all text file types in project
- Supports Unicode/emoji in search patterns
- Regex engine compatible with Swift's NSRegularExpression
- Search history persists between app launches
- Works with version control (creates new versions on replace)

## User Interface

### In-Editor Search Bar (Single File)
```
┌─────────────────────────────────────────────────────────┐
│ Find: [search text____________] ⊗  [≡] ↑ ↓  3 of 12    │
│ Replace: [replacement text____] ⊗  Replace | Replace All│
│ □ Aa (Case) □ ⌶ (Whole Word) □ .* (Regex)              │
└─────────────────────────────────────────────────────────┘
```

### Project/Collection Search Panel
```
┌─────────────────────────────────────────────────────────┐
│  Search & Replace                                    ✕   │
├─────────────────────────────────────────────────────────┤
│ Scope: ⦿ Project  ○ Collection  ○ Current File         │
│                                                          │
│ Find: [search text________________] ⊗  [≡]             │
│ Replace: [replacement text________] ⊗                   │
│ □ Aa (Case) □ ⌶ (Whole Word) □ .* (Regex)              │
│                                                          │
│ [Search] [Replace in Selected Files]  42 matches in 8 files│
├─────────────────────────────────────────────────────────┤
│ Results:                                                 │
│                                                          │
│ ▼ 📁 Chapter 1                                          │
│   ☑ 📄 Scene 1.txt (5 matches)                         │
│      ...the search term appears here...                │
│      ...another search term instance...                │
│   ☑ 📄 Scene 2.txt (3 matches)                         │
│                                                          │
│ ▼ 📁 Chapter 2                                          │
│   ☑ 📄 Opening.txt (1 match)                           │
│   ☑ 📄 Climax.txt (8 matches)                          │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### macOS: Find Panel Style
- Separate floating panel (traditional Mac style)
- Always on top when visible
- Can be moved but stays with document window
- Show/hide with ⌘F

### iOS: Bottom Sheet Style
- Slides up from bottom
- Covers lower portion of editor
- Dismiss by dragging down or tap outside
- Show/hide with magnifying glass icon

## Technical Design

### Data Model

#### SearchQuery
```swift
struct SearchQuery: Codable {
    var id: UUID = UUID()
    var searchText: String
    var replaceText: String?
    var isCaseSensitive: Bool = false
    var isWholeWord: Bool = false
    var isRegex: Bool = false
    var scope: SearchScope
    var timestamp: Date = Date()
}

enum SearchScope: String, Codable {
    case currentFile
    case collection
    case project
}
```

#### SearchResult
```swift
struct SearchResult: Identifiable {
    let id = UUID()
    let file: TextFile
    let version: Version
    let matches: [SearchMatch]
}

struct SearchMatch: Identifiable {
    let id = UUID()
    let range: NSRange
    let context: String  // Surrounding text
    let lineNumber: Int
}
```

#### SearchOptions (UserDefaults)
```swift
struct SearchOptions: Codable {
    var caseSensitive: Bool = false
    var wholeWord: Bool = false
    var useRegex: Bool = false
    var searchHistory: [String] = []  // Last 20 searches
    var replaceHistory: [String] = []  // Last 20 replacements
}
```

### Services

#### SearchService
```swift
@MainActor
class SearchService: ObservableObject {
    @Published var currentQuery: SearchQuery?
    @Published var results: [SearchResult] = []
    @Published var isSearching: Bool = false
    @Published var errorMessage: String?
    
    private var searchTask: Task<Void, Never>?
    
    func search(
        query: SearchQuery,
        in scope: SearchScope,
        context: ModelContext
    ) async throws -> [SearchResult]
    
    func cancelSearch()
    
    func replace(
        match: SearchMatch,
        with replacement: String,
        in version: Version
    ) throws
    
    func replaceAll(
        in results: [SearchResult],
        with replacement: String,
        context: ModelContext
    ) async throws -> Int  // Returns count of replacements
    
    private func searchInVersion(
        _ version: Version,
        query: SearchQuery
    ) -> [SearchMatch]
    
    private func buildRegex(from query: SearchQuery) throws -> NSRegularExpression
}
```

#### InEditorSearchManager
```swift
@MainActor
class InEditorSearchManager: ObservableObject {
    @Published var searchText: String = ""
    @Published var replaceText: String = ""
    @Published var currentMatchIndex: Int = 0
    @Published var totalMatches: Int = 0
    @Published var isReplaceMode: Bool = false
    
    weak var textView: UITextView?
    private var matches: [NSRange] = []
    
    func performSearch()
    func nextMatch()
    func previousMatch()
    func replaceCurrentMatch()
    func replaceAllMatches()
    func clearSearch()
    
    private func highlightMatches()
    private func scrollToCurrentMatch()
}
```

### Views

#### SearchAndReplacePanel (Project/Collection)
```swift
struct SearchAndReplacePanel: View {
    @StateObject private var searchService = SearchService()
    @State private var query = SearchQuery(searchText: "", scope: .project)
    @State private var selectedFiles: Set<UUID> = []
    @State private var showConfirmation = false
    
    var body: some View {
        // Search interface with results list
    }
}
```

#### InEditorSearchBar (Single File)
```swift
struct InEditorSearchBar: View {
    @Binding var isVisible: Bool
    @StateObject private var searchManager: InEditorSearchManager
    
    var body: some View {
        // Compact search/replace bar
    }
}
```

#### SearchResultRow
```swift
struct SearchResultRow: View {
    let result: SearchResult
    let match: SearchMatch
    let onSelect: () -> Void
    
    var body: some View {
        // File name, match context, navigation
    }
}
```

### Key Algorithms

#### Text Search (Non-Regex)
```swift
func findMatches(
    in text: String,
    searchText: String,
    caseSensitive: Bool,
    wholeWord: Bool
) -> [NSRange] {
    var matches: [NSRange] = []
    let options: String.CompareOptions = caseSensitive ? [] : .caseInsensitive
    let searchString = text as NSString
    var searchRange = NSRange(location: 0, length: searchString.length)
    
    while searchRange.location < searchString.length {
        let foundRange = searchString.range(
            of: searchText,
            options: options,
            range: searchRange
        )
        
        guard foundRange.location != NSNotFound else { break }
        
        if wholeWord {
            let isWordStart = foundRange.location == 0 ||
                isWordBoundary(at: foundRange.location - 1, in: text)
            let isWordEnd = foundRange.location + foundRange.length == text.count ||
                isWordBoundary(at: foundRange.location + foundRange.length, in: text)
            
            if isWordStart && isWordEnd {
                matches.append(foundRange)
            }
        } else {
            matches.append(foundRange)
        }
        
        searchRange.location = foundRange.location + foundRange.length
        searchRange.length = searchString.length - searchRange.location
    }
    
    return matches
}
```

#### Regex Search with Error Handling
```swift
func findRegexMatches(
    in text: String,
    pattern: String
) throws -> [NSRange] {
    let regex = try NSRegularExpression(pattern: pattern)
    let nsString = text as NSString
    let range = NSRange(location: 0, length: nsString.length)
    let matches = regex.matches(in: text, range: range)
    return matches.map { $0.range }
}
```

#### Replace with Regex Capture Groups
```swift
func replaceWithCaptureGroups(
    text: String,
    pattern: String,
    replacement: String
) throws -> String {
    let regex = try NSRegularExpression(pattern: pattern)
    let range = NSRange(location: 0, length: text.utf16.count)
    return regex.stringByReplacingMatches(
        in: text,
        range: range,
        withTemplate: replacement
    )
}
```

### Integration Points

#### FileEditView Integration
- Add search bar to toolbar
- Connect to InEditorSearchManager
- Handle keyboard shortcuts (⌘F, ⌘G, ⌘⇧G)
- Highlight matches in text view
- Scroll to current match

#### ProjectView Integration
- Add search button to toolbar
- Present SearchAndReplacePanel as sheet/popover
- Navigate to files from search results

#### CollectionView Integration
- Add collection-scoped search
- Filter results to collection files only

#### Version History
- Replace operations create new version (optional)
- Or auto-save after replace (user preference)

## Keyboard Shortcuts

### macOS
- `⌘F` - Show find
- `⌘⇧F` - Show find panel (project-wide)
- `⌘G` - Find next
- `⌘⇧G` - Find previous
- `⌘⌥F` - Replace mode
- `⌘⏎` - Replace all
- `⎋` - Close search/cancel

### iOS
- External keyboard same as macOS
- On-screen: magnifying glass icon for search

## User Preferences

### Settings > Search
- Default scope (File / Collection / Project)
- Show replace field by default
- Maximum search history items (default: 20)
- Debounce delay (default: 300ms)
- Auto-save after replace
- Create version on replace (vs. in-place edit)

## Testing Strategy

### Unit Tests
- SearchService: query parsing, regex validation
- Text matching algorithms (case, whole word, regex)
- Replace operations with various patterns
- Capture group replacement
- Edge cases: empty strings, special characters

### Integration Tests
- Multi-file search across project structure
- Replace operations with undo/redo
- Search results navigation
- Version creation on replace
- Performance with large files/projects

### UI Tests
- Search bar appearance/dismissal
- Navigation between matches
- Replace single/all operations
- Multi-file selection and replace
- Keyboard shortcuts

### Performance Tests
- Search 1000 files with 10,000 words each
- Complex regex patterns on large text
- UI responsiveness during background search
- Memory usage with many results

## Future Enhancements

### Phase 2
- Search in comments/footnotes (toggle option)
- Search in file names/metadata
- Saved search queries
- Search history with auto-complete
- Advanced regex builder UI

### Phase 3
- Full-text search index for instant results
- Fuzzy search (typo tolerance)
- Multi-pattern search (OR conditions)
- Search result statistics/analytics
- Export search results to CSV/JSON

## Migration & Rollout

### Phase 1: Single File Search (Week 1-2)
- Implement InEditorSearchManager
- Add search bar to FileEditView
- Basic text search (no regex)
- Replace single/all in current file

### Phase 2: Project-Wide Search (Week 3-4)
- Implement SearchService
- Create SearchAndReplacePanel
- Multi-file results display
- Navigation to search results

### Phase 3: Advanced Features (Week 5-6)
- Regex support
- Collection scope
- Replace with preview
- Search history

### Phase 4: Polish & Optimization (Week 7)
- Performance optimization
- Error handling refinement
- Accessibility improvements
- User testing and feedback

## Success Metrics
- Search completion time <100ms for single file
- Search completion time <2s for 100-file project
- User satisfaction >4.5/5 for search UX
- 90% of users use search feature monthly
- <1% error rate for replace operations

## Dependencies
- Swift String searching APIs
- NSRegularExpression for regex
- UITextView/NSTextView highlighting
- SwiftData for file access
- Undo/Redo system (Feature 004)

## Risks & Mitigations

### Risk 1: Performance with Large Projects
**Mitigation:** Background threading, progress indicators, search cancellation, result limits

### Risk 2: Regex Complexity
**Mitigation:** Comprehensive regex validation, user-friendly error messages, regex tester

### Risk 3: Undo/Redo Complexity
**Mitigation:** Batch undo operations, clear confirmation dialogs, undo limits

### Risk 4: UI Complexity on iOS
**Mitigation:** Progressive disclosure, simplified mobile UI, essential features only

## Open Questions
1. Should replace operations create new versions or modify in-place?
   - **Decision needed:** User preference setting?
2. Search in locked versions?
   - **Decision:** Yes, search but disable replace
3. Maximum search result limit?
   - **Decision:** 1000 matches with "Show More" option
4. Real-time search or manual trigger?
   - **Decision:** Real-time with debounce for single file, manual for project-wide
