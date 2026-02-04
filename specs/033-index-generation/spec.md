# Feature 033: Index Generation

**Status:** Planning  
**Branch:** TBD  
**Date:** 2026-02-04  
**Related Specs:** 029-manuscript-assembly (defines IndexEntry model and base workflow)

## Overview

Index Generation allows users to mark terms throughout their document for inclusion in an automatically-generated alphabetical index. The index appears in the back matter and includes page numbers for all locations where each term is referenced. This feature is essential for non-fiction works, manuals, textbooks, and reference materials.

The foundational infrastructure for index entries is defined in Feature 029 (Manuscript Assembly), including the `IndexEntry` SwiftData model and the basic index workflow. This spec extends that foundation with the complete user experience, advanced features, and export behaviour.

---

## Requirements

### Functional Requirements

#### FR-1: Index Entry Creation
- [ ] FR-1.1: User can select text and choose "Add to Index" from context menu
- [ ] FR-1.2: User can enter a custom keyword/phrase for the index entry (may differ from selected text)
- [ ] FR-1.3: If keyword already exists, add a new reference to existing entry
- [ ] FR-1.4: If keyword is new, create new `IndexEntry` and add reference
- [ ] FR-1.5: Selected text receives invisible marker with reference to IndexEntry
- [ ] FR-1.6: User can add index entry without text selection (insert point marks the location)
- [ ] FR-1.7: User can mark a reference as "primary" (displayed bold in generated index)

#### FR-2: Sub-Entries (Hierarchical Index)
- [ ] FR-2.1: User can specify a parent entry when creating an index entry
- [ ] FR-2.2: Example: "Puppies" under "Dogs" under "Animals" (3-level hierarchy)
- [ ] FR-2.3: Support at least 3 levels of nesting
- [ ] FR-2.4: Sub-entries appear indented under parent in generated index
- [ ] FR-2.5: Parent entries can have their own page references or be reference-free headings

#### FR-3: Index Entry Management
- [ ] FR-3.1: View all index entries in a dedicated Index panel/list
- [ ] FR-3.2: Edit index entry keyword (updates all references)
- [ ] FR-3.3: Delete index entry (with warning if references exist, removes all markers)
- [ ] FR-3.4: Merge duplicate entries (combine references from two entries)
- [ ] FR-3.5: Change entry's parent (reorganize hierarchy)
- [ ] FR-3.6: View all files containing references to an entry

#### FR-4: Index Navigation
- [ ] FR-4.1: Click index entry in panel to see list of all references
- [ ] FR-4.2: Click individual reference to navigate to that location in document
- [ ] FR-4.3: In manuscript view, click index entry to see back-reference popover
- [ ] FR-4.4: Search/filter index entries by keyword

#### FR-5: Index Display in Manuscript View
- [ ] FR-5.1: Index markers are invisible in normal editing (no visual clutter)
- [ ] FR-5.2: Optional: Show subtle indicator when cursor is on indexed text
- [ ] FR-5.3: Generate live index preview in back matter with calculated page numbers
- [ ] FR-5.4: Index entries sorted alphabetically, case-insensitive, locale-aware
- [ ] FR-5.5: Sub-entries appear indented under parent entries (max 3 levels)
- [ ] FR-5.6: Consecutive page numbers displayed as ranges (e.g., "45-47")
- [ ] FR-5.7: Primary references displayed in bold

#### FR-6: Cross-References
- [ ] FR-6.1: Support "See" references (e.g., "Dogs. See Animals")
- [ ] FR-6.2: Support "See also" references (e.g., "Dogs. See also Cats, Puppies")
- [ ] FR-6.3: Cross-references link to other index entries, not page numbers

#### FR-7: Export Behaviour
- [ ] FR-7.1: **PDF**: Full index rendered as back matter with page numbers
- [ ] FR-7.2: **RTF**: Index included as appendix with page numbers
- [ ] FR-7.3: **HTML**: Index with internal anchor links to each reference location
- [ ] FR-7.4: **Plain Text**: Index with section/chapter references (no page numbers)
- [ ] FR-7.5: **WSP Format**: Index data preserved for round-trip

### Non-Functional Requirements

#### NFR-1: Performance
- [ ] NFR-1.1: Index entry lookup by keyword should be O(1) or O(log n)
- [ ] NFR-1.2: Adding index reference should not cause noticeable delay
- [ ] NFR-1.3: Generating full index for 1000+ entries should complete in <1 second
- [ ] NFR-1.4: Use `referencingFileIDs` pattern for efficient reference management (per spec 029)

#### NFR-2: Usability
- [ ] NFR-2.1: Quick keyboard shortcut for "Add to Index" (e.g., ⌘⌥I)
- [ ] NFR-2.2: Recently used keywords appear at top of suggestion list
- [ ] NFR-2.3: Autocomplete when typing keyword that already exists

#### NFR-3: CloudKit Compatibility
- [ ] NFR-3.1: IndexEntry model uses optional properties or defaults (per CloudKit requirements)
- [ ] NFR-3.2: No unique constraints on IndexEntry
- [ ] NFR-3.3: Relationship syncing handled gracefully (per copilot-instructions.md guidelines)

---

## Technical Design

### IndexEntry Model (from Spec 029)

The IndexEntry SwiftData model is defined in Feature 029:

```swift
@Model
final class IndexEntry: ReferenceEntryProtocol {
    var id: UUID = UUID()
    var keyword: String = ""
    var parentEntry: IndexEntry? = nil  // For sub-entries
    var referenceCount: Int = 0
    var referencingFileIDs: [UUID] = []
    var createdAt: Date = Date()
    
    // Cross-references
    var seeEntry: IndexEntry? = nil      // "See X" reference
    var seeAlsoEntries: [IndexEntry] = [] // "See also X, Y" references
    
    // Inverse relationship for children
    @Relationship(inverse: \IndexEntry.parentEntry)
    var childEntries: [IndexEntry] = []
    
    init(keyword: String, parent: IndexEntry? = nil) {
        self.keyword = keyword
        self.parentEntry = parent
    }
}
```

### Index Marker Storage

Index references use invisible markers stored in NSAttributedString:

```swift
// From spec 029 - attribute keys
extension NSAttributedString.Key {
    static let referenceType = NSAttributedString.Key("com.writingshed.referenceType")
    static let referenceID = NSAttributedString.Key("com.writingshed.referenceID")
    static let referencePrimary = NSAttributedString.Key("com.writingshed.referencePrimary") // Bool for primary reference
}

// Index markers have zero-width or minimal visual representation
// referenceType = "index"
// referenceID = IndexEntry UUID
// referencePrimary = true/false (primary refs shown bold in index)
```

### IndexService

```swift
@Observable
class IndexService {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Entry Management
    
    func findOrCreateEntry(keyword: String, parent: IndexEntry? = nil) -> IndexEntry {
        let normalizedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if entry with this keyword already exists
        let predicate = #Predicate<IndexEntry> { 
            $0.keyword.localizedStandardContains(normalizedKeyword) 
        }
        let descriptor = FetchDescriptor<IndexEntry>(predicate: predicate)
        
        if let existing = try? modelContext.fetch(descriptor).first(where: { 
            $0.keyword.caseInsensitiveCompare(normalizedKeyword) == .orderedSame 
        }) {
            return existing
        }
        
        // Create new entry
        let entry = IndexEntry(keyword: normalizedKeyword, parent: parent)
        modelContext.insert(entry)
        return entry
    }
    
    func deleteEntry(_ entry: IndexEntry, removeMarkers: Bool = true) throws {
        if removeMarkers {
            // Use referencingFileIDs for efficient marker removal
            for fileID in entry.referencingFileIDs {
                // Remove all markers referencing this entry from file
                try removeMarkersFromFile(fileID: fileID, entryID: entry.id)
            }
        }
        
        // Reparent children to grandparent (or make them root)
        for child in entry.childEntries {
            child.parentEntry = entry.parentEntry
        }
        
        modelContext.delete(entry)
    }
    
    func mergeEntries(source: IndexEntry, into target: IndexEntry) throws {
        // Move all file references
        for fileID in source.referencingFileIDs {
            if !target.referencingFileIDs.contains(fileID) {
                target.referencingFileIDs.append(fileID)
            }
            // Update markers in file to point to target
            try updateMarkersInFile(fileID: fileID, fromEntry: source.id, toEntry: target.id)
        }
        
        // Transfer reference count
        target.referenceCount += source.referenceCount
        
        // Reparent children
        for child in source.childEntries {
            child.parentEntry = target
        }
        
        modelContext.delete(source)
    }
    
    // MARK: - Reference Management
    
    func addReference(
        entry: IndexEntry,
        to attributedString: inout NSMutableAttributedString,
        at range: NSRange,
        fileID: UUID
    ) {
        // Add invisible marker
        attributedString.addAttributes([
            .referenceType: "index",
            .referenceID: entry.id.uuidString
        ], range: range)
        
        // Track in entry
        entry.referenceCount += 1
        if !entry.referencingFileIDs.contains(fileID) {
            entry.referencingFileIDs.append(fileID)
        }
    }
    
    func removeReference(entry: IndexEntry, fileID: UUID) {
        entry.referenceCount -= 1
        
        // Check if file still has references to this entry
        // If not, remove fileID from referencingFileIDs
        // (Implementation depends on checking remaining markers)
    }
    
    // MARK: - Index Generation
    
    func generateIndex(for project: Project) -> [IndexSection] {
        let entries = fetchAllEntries(for: project)
        let rootEntries = entries.filter { $0.parentEntry == nil }
        
        // Sort alphabetically
        let sorted = rootEntries.sorted { 
            $0.keyword.localizedCaseInsensitiveCompare($1.keyword) == .orderedAscending 
        }
        
        // Group by first letter
        var sections: [IndexSection] = []
        var currentLetter: Character?
        var currentEntries: [IndexDisplayEntry] = []
        
        for entry in sorted {
            let firstLetter = entry.keyword.first?.uppercased().first ?? "#"
            
            if firstLetter != currentLetter {
                if let letter = currentLetter, !currentEntries.isEmpty {
                    sections.append(IndexSection(letter: String(letter), entries: currentEntries))
                }
                currentLetter = firstLetter
                currentEntries = []
            }
            
            currentEntries.append(buildDisplayEntry(from: entry))
        }
        
        // Add final section
        if let letter = currentLetter, !currentEntries.isEmpty {
            sections.append(IndexSection(letter: String(letter), entries: currentEntries))
        }
        
        return sections
    }
    
    private func buildDisplayEntry(from entry: IndexEntry, level: Int = 0) -> IndexDisplayEntry {
        let children = entry.childEntries
            .sorted { $0.keyword.localizedCaseInsensitiveCompare($1.keyword) == .orderedAscending }
            .map { buildDisplayEntry(from: $0, level: level + 1) }
        
        return IndexDisplayEntry(
            id: entry.id,
            keyword: entry.keyword,
            pageNumbers: calculatePageNumbers(for: entry),
            level: level,
            seeReference: entry.seeEntry?.keyword,
            seeAlsoReferences: entry.seeAlsoEntries.map(\.keyword),
            children: children
        )
    }
    
    private func calculatePageNumbers(for entry: IndexEntry) -> [Int] {
        // Calculate actual page numbers based on marker positions
        // Requires access to pagination engine
        // Returns sorted, deduplicated page numbers
        return []
    }
}
```

### Supporting Types

```swift
struct IndexSection: Identifiable {
    let id = UUID()
    let letter: String
    let entries: [IndexDisplayEntry]
}

struct IndexDisplayEntry: Identifiable {
    let id: UUID
    let keyword: String
    let pageNumbers: [PageReference]  // Includes primary flag
    let level: Int
    let seeReference: String?
    let seeAlsoReferences: [String]
    let children: [IndexDisplayEntry]
    
    var formattedPageNumbers: String {
        formatPageReferences(pageNumbers)
    }
    
    var hasReferences: Bool {
        !pageNumbers.isEmpty || seeReference != nil || !seeAlsoReferences.isEmpty
    }
}

struct PageReference {
    let pageNumber: Int
    let isPrimary: Bool
}

/// Formats page references with ranges and bold for primary
/// Example: [1, 2, 3, 5, 7, 8] → "1-3, 5, 7-8"
/// Primary references are marked for bold rendering
func formatPageReferences(_ refs: [PageReference]) -> AttributedString {
    let sorted = refs.sorted { $0.pageNumber < $1.pageNumber }
    var result = AttributedString()
    var ranges: [(start: Int, end: Int, hasPrimary: Bool)] = []
    
    for ref in sorted {
        if let last = ranges.last, last.end == ref.pageNumber - 1 {
            ranges[ranges.count - 1] = (last.start, ref.pageNumber, last.hasPrimary || ref.isPrimary)
        } else {
            ranges.append((ref.pageNumber, ref.pageNumber, ref.isPrimary))
        }
    }
    
    for (index, range) in ranges.enumerated() {
        if index > 0 {
            result.append(AttributedString(", "))
        }
        
        let text: String
        if range.start == range.end {
            text = "\(range.start)"
        } else {
            text = "\(range.start)-\(range.end)"
        }
        
        var segment = AttributedString(text)
        if range.hasPrimary {
            segment.inlinePresentationIntent = .stronglyEmphasized // Bold
        }
        result.append(segment)
    }
    
    return result
}
```

### Index Panel View

```swift
struct IndexPanelView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \IndexEntry.keyword) private var entries: [IndexEntry]
    @State private var searchText = ""
    @State private var selectedEntry: IndexEntry?
    
    var filteredEntries: [IndexEntry] {
        if searchText.isEmpty {
            return entries.filter { $0.parentEntry == nil }
        }
        return entries.filter { 
            $0.keyword.localizedCaseInsensitiveContains(searchText) 
        }
    }
    
    var body: some View {
        List(selection: $selectedEntry) {
            ForEach(filteredEntries) { entry in
                IndexEntryRowView(entry: entry, level: 0)
            }
        }
        .searchable(text: $searchText, prompt: "Search index entries")
        .toolbar {
            ToolbarItem {
                Button("Add Entry", systemImage: "plus") {
                    // Show add entry sheet
                }
            }
        }
    }
}

struct IndexEntryRowView: View {
    let entry: IndexEntry
    let level: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(entry.keyword)
                    .font(.body)
                Spacer()
                Text("\(entry.referenceCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, CGFloat(level * 16))
            
            // Show children recursively
            ForEach(entry.childEntries.sorted { 
                $0.keyword.localizedCaseInsensitiveCompare($1.keyword) == .orderedAscending 
            }) { child in
                IndexEntryRowView(entry: child, level: level + 1)
            }
        }
    }
}
```

### Add to Index Sheet

```swift
struct AddToIndexSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let selectedText: String
    let onAdd: (IndexEntry) -> Void
    
    @State private var keyword: String
    @State private var selectedParent: IndexEntry?
    @Query(sort: \IndexEntry.keyword) private var existingEntries: [IndexEntry]
    
    init(selectedText: String, onAdd: @escaping (IndexEntry) -> Void) {
        self.selectedText = selectedText
        self.onAdd = onAdd
        _keyword = State(initialValue: selectedText)
    }
    
    var matchingEntries: [IndexEntry] {
        guard !keyword.isEmpty else { return [] }
        return existingEntries.filter { 
            $0.keyword.localizedCaseInsensitiveContains(keyword) 
        }.prefix(5).map { $0 }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Index Entry") {
                    TextField("Keyword", text: $keyword)
                    
                    if !matchingEntries.isEmpty {
                        ForEach(matchingEntries) { entry in
                            Button {
                                keyword = entry.keyword
                            } label: {
                                Label(entry.keyword, systemImage: "arrow.turn.down.right")
                            }
                        }
                    }
                }
                
                Section("Parent Entry (Optional)") {
                    Picker("Parent", selection: $selectedParent) {
                        Text("None (Root Level)").tag(IndexEntry?.none)
                        ForEach(existingEntries.filter { $0.parentEntry == nil }) { entry in
                            Text(entry.keyword).tag(Optional(entry))
                        }
                    }
                }
            }
            .navigationTitle("Add to Index")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addEntry()
                    }
                    .disabled(keyword.isEmpty)
                }
            }
        }
    }
    
    private func addEntry() {
        let service = IndexService(modelContext: modelContext)
        let entry = service.findOrCreateEntry(keyword: keyword, parent: selectedParent)
        onAdd(entry)
        dismiss()
    }
}
```

---

## Generated Index Format

### Standard Format (PDF/Print)

```
INDEX

A
  Animals, 12, 45, 89
    Dogs, 14, 47
      Puppies, 48-49
    Cats, 15, 50-51

B  
  Bibliography. See References

C
  Chapters, 5, 10
    Chapter structure, 10-12
  Citations. See also References
  Code examples, 23, 67, 89

...
```

### HTML Format

```html
<div class="index">
  <h2>Index</h2>
  
  <div class="index-section">
    <h3>A</h3>
    <div class="index-entry level-0">
      <span class="keyword">Animals</span>
      <span class="page-refs">
        <a href="#page-12">12</a>, 
        <a href="#page-45">45</a>, 
        <a href="#page-89">89</a>
      </span>
    </div>
    <div class="index-entry level-1">
      <span class="keyword">Dogs</span>
      <span class="page-refs">
        <a href="#page-14">14</a>, 
        <a href="#page-47">47</a>
      </span>
    </div>
    <!-- ... -->
  </div>
</div>
```

---

## Implementation Plan

### Phase 1: Core Index Functionality
**Estimated Effort:** 3-4 days

**Tasks:**
1. [ ] Verify IndexEntry model exists (from spec 029) or create it
2. [ ] Create IndexService with entry management methods
3. [ ] Add "Add to Index" context menu item
4. [ ] Implement AddToIndexSheet view
5. [ ] Store invisible markers in attributed string
6. [ ] Handle copy/paste/delete of indexed text (reference counting)

### Phase 2: Index Panel & Navigation
**Estimated Effort:** 2-3 days

**Tasks:**
1. [ ] Create IndexPanelView for viewing all entries
2. [ ] Add search/filter functionality
3. [ ] Implement entry editing (rename, reparent)
4. [ ] Add delete with confirmation
5. [ ] Navigation from panel to document location

### Phase 3: Hierarchical Index & Cross-References
**Estimated Effort:** 2 days

**Tasks:**
1. [ ] Implement parent-child relationships in UI
2. [ ] Add "See" reference support
3. [ ] Add "See also" reference support
4. [ ] Merge duplicate entries feature

### Phase 4: Index Generation & Export
**Estimated Effort:** 3 days

**Tasks:**
1. [ ] Generate index sections with alphabetical grouping
2. [ ] Calculate page numbers from marker positions
3. [ ] Render index in manuscript view back matter
4. [ ] PDF export with page numbers
5. [ ] HTML export with anchor links
6. [ ] RTF export
7. [ ] Plain text export (chapter references)

### Phase 5: Polish & Performance
**Estimated Effort:** 1-2 days

**Tasks:**
1. [ ] Keyboard shortcut (⌘⌥I)
2. [ ] Recently used keywords suggestion
3. [ ] Performance testing with 1000+ entries
4. [ ] Undo/redo support for index operations
5. [ ] CloudKit sync testing

---

## Testing

### Unit Tests
- IndexService: entry creation, deletion, merging
- Reference counting: add, remove, copy, paste
- Index generation: sorting, grouping, hierarchy
- Cross-reference formatting

### Integration Tests
- Full workflow: mark term → generate index → export PDF
- CloudKit sync of IndexEntry
- Multi-file project with shared index entries

### UI Tests
- Context menu → Add to Index sheet
- Index panel: search, navigate, edit
- Manuscript view: index in back matter

---

## Design Decisions

1. **Page range formatting**: Consecutive pages shown as ranges (e.g., "45-47" not "45, 46, 47")
2. **Bold page numbers**: Primary/main reference is bolded to distinguish from secondary references
3. **Localization**: Index sorting is locale-aware; heading uses standard "Index" (not localized)
4. **Maximum hierarchy depth**: Limited to 3 levels (entry → sub-entry → sub-sub-entry)
5. **Index style**: APA format (consistent with citation/reference system elsewhere in app)

---

## References

- Feature 029: Manuscript Assembly - defines IndexEntry model and base infrastructure
- Feature 025: Manual Project Type - mentions index generation as future feature
- Chicago Manual of Style, Chapter 16: Indexes
