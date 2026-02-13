# Feature 029: Manuscript Assembly

**Status:** MVP Complete  
**Branch:** 021-smart-poetry-creation  
**Date:** 2025-01-10

## Additional Features
The Manuscript feature supports Front and Back matter folders in addition to Body. The contents of the front & back matter folders is determined by settings. In the case of the back matter the following items require app support for Notes, Glossary, Citations, Index.

- Notes are, as the name suggests, text notes that can be referenced in the document. The referencing mechanism is yet to be defined. They need to be referenced from the Project so there needs to be a DocumentNote entry created for each note. 

- Glossary is a list of terms used in the document. The document should contain a reference to each use of the glossary item. Each glossary entry consists of the name of the term plus its definition plus an optional citation. As with Notes there needs to be a Glossarymodel with a link to the glossary from the project.

- Citations are bibiography entries. There should be a CitationModel consisting of data that conforms to a citation style. Initially the app should use the APA style. Again, citations can be reference within the document using the technique TBD.

- Index. The user can choose items to go in an index. Each entry in the index contains the index entry followed by page number(s). Index entries can be referenced from multiple locations in the document. When the user chooses to add an index entry they supply the key word/phase to go in the index. The app looks to see if this key already exists and creates it if not, otherwise it adds the page number to the set of pages.

The way I see this working is that an entry is added to the Insert menu for each type of item supported.

---

## Back Matter Reference System (Design Decisions)

### Reference Marker Formats

Each reference type uses a distinct inline marker format, automatically numbered:

| Type | Marker Format | Example | Notes |
|------|---------------|---------|-------|
| Endnote | `[n]` | `[1]`, `[2]` | Superscript styling, numbered continuously |
| Note | `[Note n]` | `[Note 1]` | Distinct from endnotes, for general notes |
| Citation | `[Author, Year]` | `[Smith, 2024]` | APA-style inline reference |
| Figure | `[Fig n]` | `[Fig 1]` | For list of figures |
| Table | `[Table n]` | `[Table 1]` | For list of tables (future) |
| Glossary | `[see term]` | `[see protagonist]` | Inline marker uses `[see <term>]`; blue in edit mode, black in page view, tag always matches the glossary term |
| Index | *(invisible marker)* | — | No visible marker; stored for page calculation at export |

### Model Definitions

All reference models follow consistent naming and conform to a shared protocol:

```swift
protocol ReferenceEntry: Identifiable {
    var id: UUID { get }
    var referenceCount: Int { get set }
    var createdAt: Date { get }
}
```

| Model | Key Properties |
|-------|----------------|
| `NoteEntry` | `id`, `content: String`, `referenceCount: Int = 0`, `referencingFileIDs: [UUID] = []` |
| `GlossaryEntry` | `id`, `term: String`, `definition: String`, `citation: CitationEntry?`, `referenceCount: Int = 0`, `referencingFileIDs: [UUID] = []` |
| `CitationEntry` | `id`, `authors: [String]`, `year: Int?`, `title: String`, `source: String?`, `url: String?`, `referenceCount: Int = 0`, `referencingFileIDs: [UUID] = []` — format-agnostic storage for APA/MLA/Chicago |
| `IndexEntry` | `id`, `keyword: String`, `parentEntry: IndexEntry?` (for sub-entries), `referenceCount: Int = 0`, `referencingFileIDs: [UUID] = []` |

**SwiftData/CloudKit Compliance:** All properties are optional or have default values. No `@Attribute(.unique)` constraints.

### Efficient Reference Deletion: referencingFileIDs Pattern

When a back matter entry is deleted, all reference markers to it must be removed from ALL files in the project. To avoid expensive iteration through all files, **each reference entry tracks which files contain references to it** using a `referencingFileIDs` array:

**Implementation Details:**
- When a reference is added to a note in a file, add the file's ID to `note.referencingFileIDs`
- When a reference is removed from a file, remove the file ID from the array (or keep it if more references exist in that file)
- When deleting a note, only iterate through files in `referencingFileIDs` instead of scanning all files
- This approach should be applied to **all back matter objects**: `NoteEntry`, `GlossaryEntry`, `CitationEntry`, `IndexEntry`

**Benefits:**
- Deletion operations scale to O(n) where n = number of files with references, not total files in project
- Projects with 50+ files in back matter will see dramatic performance improvement
- Reference tracking is automatic: happens at add/remove time, not at deletion time

**Code Pattern:**
```swift
// When adding a reference
if !note.referencingFileIDs.contains(file.id) {
    note.referencingFileIDs.append(file.id)
}

// When removing a reference
note.referencingFileIDs.removeAll { $0 == file.id }

// When deleting entry
for fileID in note.referencingFileIDs {
    if let file = findFile(withID: fileID) {
        removeMarkersFromFile(file, for: note)
    }
}
```

### NSAttributedString Storage

References are stored using custom attribute keys in the attributed string:

```swift
extension NSAttributedString.Key {
    static let referenceType = NSAttributedString.Key("com.writingshed.referenceType")
    static let referenceID = NSAttributedString.Key("com.writingshed.referenceID")
}
```

Each reference marker in the text carries:
- `referenceType`: String enum (`"note"`, `"endnote"`, `"citation"`, `"glossary"`, `"index"`, `"figure"`)
- `referenceID`: UUID string pointing to the corresponding entry

### Reference Lifecycle

**Copy/Paste:**
- Copying text containing a reference copies the attribute keys
- Pasting increments `referenceCount` on the target entry

**Cut/Delete:**
- Removing text containing a reference decrements `referenceCount`
- If `referenceCount` drops to 0, the entry becomes orphaned (warn user or mark for cleanup)

**Undo/Redo:**
- Reference count changes are tracked with undo/redo operations
- Undoing a paste decrements the count; undoing a delete restores it

**Deletion of Entry:**
- If user deletes an entry with `referenceCount > 0`, warn: "This citation has 3 references. Delete anyway?"
- If confirmed, remove all inline markers referencing that entry (efficiently using `referencingFileIDs`)

### Glossary Workflow

1. User selects a term in the text
2. Context menu shows "Add to Glossary"
3. If term exists in `GlossaryEntry` list → link to existing entry (no additional dialog; each entry is unique)
4. If term is new → present the Glossary Entry sheet (same layout as the EndNote dialog but without the Reference Existing section)
-   Tag field is locked to the selected term and becomes the inline label
-   Definition editor is the primary content area, with an optional citation picker
-   Saving creates the entry and inserts the `[see <tag>]` marker
5. Inserted marker is styled blue in edit mode, black in page view, and tappable so the definition popover can be shown

### Index Workflow

1. User selects text → context menu "Add to Index"
2. User enters keyword/phrase for the index entry
3. App checks if keyword exists:
   - Exists → add invisible marker at selection location
   - New → create `IndexEntry`, add marker
4. Sub-entries supported: user can specify parent entry (e.g., "Dogs" under "Animals")
5. At export/manuscript view time, markers are resolved to actual page numbers

### Export Behavior by Format

| Format | Behavior |
|--------|----------|
| **PDF** | Full rendering: inline markers displayed, back matter sections generated with page numbers for index |
| **RTF** | Markers preserved as styled text; back matter sections included as appendices |
| **Plain Text** | Markers converted to readable text: `(see Note 1)`, `(Smith, 2024)`, `(see Glossary: protagonist)`. Index markers stripped (no pages in plain text). |
| **Manuscript View** | Live preview with clickable references; index entries show calculated page numbers |

---

## Implementation Plan: Back Matter Reference System

### Phase 10: Foundation — Models & Attributed String Keys ✅ COMPLETE
**Priority:** High | **Estimated Effort:** 2-3 days | **Completed:** 15 January 2026

**Tasks:**
1. ✅ Create `Models/ReferenceModels.swift`:
   - `ReferenceEntryProtocol` protocol
   - `ReferenceType` enum with marker formats
   - `NoteEntry` SwiftData model
   - `GlossaryEntry` SwiftData model
   - `CitationEntry` SwiftData model (format-agnostic fields)
   - `IndexEntry` SwiftData model (with optional `parentEntry` for sub-entries)
   
2. ✅ Create `Extensions/NSAttributedString+References.swift`:
   - Define custom attribute keys: `.referenceType`, `.referenceID`
   - `ReferenceMarkerInfo` struct for query results
   - Helper methods: `addReference(type:id:to range:)`, `insertReference()`, `removeReference(at range:)`
   - Query methods: `references(in range:)`, `allReferences()`, `reference(at location:)`
   - Style methods: `applyReferenceStyle(type:to range:)`
   - Plain text conversion: `convertReferencesToPlainText(resolver:)`

3. ✅ Create `Services/ReferenceTrackingService.swift`:
   - `incrementReferenceCount(forEntryID:type:)` 
   - `decrementReferenceCount(forEntryID:type:)`
   - Orphan detection: `orphanedNotes()`, `orphanedGlossaryEntries()`, etc.
   - `deleteEntry(_:force:)` — returns `.hasReferences(count:)` if not forced
   - Entry lookup methods: `notes(for:)`, `glossaryEntries(for:)`, etc.
   - Reference count validation: `recalculateReferenceCounts(for:documentContents:)`
   - Undo/redo support: `registerUndoForIncrement()`, `registerUndoForDecrement()`

4. ✅ Add relationships to `Project` model:
   - `noteEntries: [NoteEntry]`
   - `glossaryEntries: [GlossaryEntry]`
   - `citationEntries: [CitationEntry]`
   - `indexEntries: [IndexEntry]`

**Files:**
- New: `Models/ReferenceModels.swift`
- New: `Extensions/NSAttributedString+References.swift`
- New: `Services/ReferenceTrackingService.swift`
- Modified: `Models/BaseModels.swift` (Project relationships)

---

### Phase 11: Reference Marker Rendering ✅ COMPLETE
**Priority:** High | **Estimated Effort:** 2 days | **Completed:** 15 January 2026

**Tasks:**
1. ✅ Create `Helpers/ReferenceAttachment.swift` (NSTextAttachment subclass):
   - Renders inline marker based on type (`[1]`, `[Note 1]`, `[Smith, 2024]`, etc.)
   - Styled backgrounds for different reference types (blue for notes, indigo for citations, teal for glossary)
   - Tappable for popover/navigation
   - Supports secure coding for persistence

2. ✅ Update `FormattedTextEditor.swift`:
   - Added `onReferenceTapped` callback
   - CustomTextView handles tap gestures on reference attachments
   - Wired up callback to parent coordinator

3. ✅ Create `Views/References/ReferencePopoverView.swift`:
   - Shows content preview on tap (note text, glossary definition, citation details)
   - Different content layouts for each reference type
   - "Edit" and "Go to Entry" action buttons
   - Handles missing/deleted entries gracefully

4. ✅ Update `Services/AttributedStringSerializer.swift`:
   - Added reference attachment properties to AttributeValues struct
   - Encode/decode ReferenceAttachment for persistence
   - Preserves referenceType and referenceID custom attributes

**Files:**
- New: `Helpers/ReferenceAttachment.swift`
- New: `Views/References/ReferencePopoverView.swift`
- Modified: `Views/Components/FormattedTextEditor.swift`
- Modified: `Services/AttributedStringSerializer.swift`

---

### Phase 12: Notes & Endnotes
**Priority:** High | **Estimated Effort:** 2 days

**Tasks:**
1. Add "Insert Note" / "Insert Endnote" to Insert menu
2. Create `Views/Sheets/NoteEditorSheet.swift`:
   - Text editor for note content
   - Save creates `NoteEntry`, inserts marker at cursor
3. Implement automatic numbering:
   - Notes numbered per-document in order of appearance
   - Endnotes numbered continuously across manuscript (configurable)
4. Create `Views/BackMatter/NotesListView.swift`:
   - Lists all notes for a project
   - Edit/delete actions
   - Shows reference count

**Files:**
- New: `Views/Sheets/NoteEditorSheet.swift`
- New: `Views/BackMatter/NotesListView.swift`
- Modified: Insert menu implementation

---

### Phase 13: Glossary
**Priority:** High | **Estimated Effort:** 2-3 days

**Tasks:**
1. Add context menu item "Add to Glossary" when text is selected
2. Create `Views/Sheets/GlossaryEntrySheet.swift`:
   - Mirrors `NoteEditorSheet` (text editor + metadata) but removes the Reference Existing section so each glossary term is defined exactly once
   - Term field is pre-filled from the selection, drives the `tag` value, and represents the name of the glossary entry (the tag is also the inline marker label)
   - Definition editor becomes the entry content and the optional citation picker lets users attach an existing citation
3. Implement term matching:
   - On "Add to Glossary", check if the term already exists in the glossary
   - If it exists, link directly to that entry without presenting Reference Existing controls
   - If it is new, present the GlossaryEntrySheet, save the definition, and create the new entry with the selected term as its tag
4. Insert `[see <tag>]` markers for every glossary reference:
   - Markers are blue in edit mode, black in manuscript/page view, and tappable for the definition popover
   - Reference counts are updated just like endnotes, since the sheet mirrors the EndNote dialog workflow
5. Create `Views/BackMatter/GlossaryListView.swift`:
   - Alphabetically sorted list of terms
   - Edit/delete actions
   - Filter/search

**Files:**
- New: `Views/Sheets/GlossaryEntrySheet.swift`
- New: `Views/BackMatter/GlossaryListView.swift`
- Modified: Context menu in `TextEditView`

---

### Phase 14: Citations (Bibliography)
**Priority:** Medium | **Estimated Effort:** 3-4 days

**Tasks:**
1. Create `Services/CitationFormatterService.swift`:
   - `formatInline(citation:style:)` → `[Smith, 2024]`
   - `formatFull(citation:style:)` → Full bibliography entry
   - Support APA initially, architecture for MLA/Chicago later
2. Add "Insert Citation" to Insert menu
3. Create `Views/Sheets/CitationEntrySheet.swift`:
   - Fields: authors (multiple), year, title, source/journal, URL, DOI, etc.
   - Preview of formatted citation
4. Create `Views/Sheets/CitationPickerSheet.swift`:
   - Search/select from existing citations
   - Or create new
5. Create `Views/BackMatter/BibliographyListView.swift`:
   - All citations formatted in selected style
   - Sort by author/year/title
   - Edit/delete actions

**Files:**
- New: `Services/CitationFormatterService.swift`
- New: `Views/Sheets/CitationEntrySheet.swift`
- New: `Views/Sheets/CitationPickerSheet.swift`
- New: `Views/BackMatter/BibliographyListView.swift`

---

### Phase 15: Index
**Priority:** Medium | **Estimated Effort:** 3-4 days

**Tasks:**
1. Add context menu item "Add to Index" when text is selected
2. Create `Views/Sheets/IndexEntrySheet.swift`:
   - Keyword field (can differ from selected text)
   - Optional parent entry picker (for sub-entries like "Dogs" under "Animals")
   - Shows existing entries for linking
3. Insert invisible marker in attributed string:
   - No visual change at edit time
   - Marker stores entry ID for page calculation
4. Create `Services/IndexPageCalculationService.swift`:
   - At export time, iterate through manuscript pages
   - Find markers, record page numbers per entry
   - Handle sub-entries (indented under parent)
5. Create `Views/BackMatter/IndexListView.swift`:
   - Hierarchical list of index entries
   - Edit keyword, reassign parent
   - Delete with orphan warning
6. Generate index section in manuscript:
   - Alphabetical listing with page numbers
   - Sub-entries indented

**Files:**
- New: `Views/Sheets/IndexEntrySheet.swift`
- New: `Services/IndexPageCalculationService.swift`
- New: `Views/BackMatter/IndexListView.swift`
- Modified: Context menu in `TextEditView`

---

### Phase 16: Reference Lifecycle & Undo/Redo
**Priority:** High | **Estimated Effort:** 2 days

**Tasks:**
1. Hook into text editing operations:
   - On paste: scan for reference attributes, increment counts
   - On delete/cut: scan removed range, decrement counts
2. Integrate with UndoManager:
   - Register inverse count operations with undo
   - Ensure undo of delete restores reference counts
3. Handle entry deletion:
   - Show warning if `referenceCount > 0`
   - On confirm, scan only files in `referencingFileIDs` and remove markers
4. Orphan management:
   - Background check for entries with `referenceCount = 0`
   - Optional cleanup prompt in settings or project view

**Files:**
- Modified: `Services/ReferenceTrackingService.swift`
- Modified: Text editing undo/redo handling
- New: `Views/Sheets/OrphanedReferencesSheet.swift` (optional)

---

### Phase 17: Export Integration
**Priority:** High | **Estimated Effort:** 2-3 days

**Tasks:**
1. Update `PrintService` / PDF export:
   - Render reference markers with proper styling
   - Generate Notes section with numbered entries
   - Generate Glossary section (alphabetical)
   - Generate Bibliography section (formatted per style)
   - Generate Index section with calculated page numbers

2. Update RTF export:
   - Preserve markers as styled text
   - Append back matter sections

3. Update plain text export:
   - Convert markers to readable text:
     - `[1]` → `(see Note 1)`
     - `[Smith, 2024]` → `(Smith, 2024)`
     - Glossary term → `protagonist (see Glossary)`
   - Strip index markers (no page numbers in plain text)
   - Append simplified back matter

4. Add back matter toggle in export options:
   - Include/exclude each section type

**Files:**
- Modified: `Services/PrintService.swift`
- Modified: `Services/ExportService.swift` (RTF, plain text)
- Modified: `Models/ManuscriptModels.swift` (ExportOptions)

---

### Phase 19: Contributors Section
**Priority:** Medium | **Estimated Effort:** 1 day | **Status:** Complete

**Overview:**
The Contributors section is a back matter file that allows magazine/anthology publishers to list contributors to a publication. Each contributor entry consists of their name (first name and surname) and a biographical note.

**Features:**
- User-created entries (not auto-generated from references)
- Add (+) button to create new contributor entries
- Each entry has: first name, surname, and biography text
- List is displayed sorted alphabetically by surname, then first name
- Entries are editable and deletable via swipe actions or context menu
- Export includes Contributors section with formatted entries

**Data Model (`ContributorEntry`):**
| Property | Type | Description |
|----------|------|-------------|
| `id` | UUID | Unique identifier |
| `project` | Project? | Parent project relationship |
| `firstName` | String | Contributor's first name |
| `surname` | String | Contributor's surname/last name |
| `biography` | String | Biographical note |
| `userOrder` | Int | User-defined order (optional, surname sort is default) |
| `createdAt` | Date | When entry was created |
| `modifiedAt` | Date | When entry was last modified |

**UI Components:**
1. `ContributorEditorSheet.swift` - Add/edit contributor form
   - First Name field
   - Surname field
   - Biography text editor (multi-line)
   - Save/Cancel buttons
   
2. Contributors section in `BackMatterGeneratedContentView.swift`
   - List of contributors sorted by surname
   - Each row shows: "Surname, First Name" with biography below
   - Add (+) button in toolbar
   - Swipe to delete
   - Tap to edit

**Export Format:**
```
CONTRIBUTORS

Surname, First Name
Biography text here spanning multiple lines as needed.

Surname, First Name  
Another biography entry.
```

**Files:**
- Modified: `Models/ReferenceModels.swift` (ContributorEntry model)
- Modified: `Models/MatterSettingsModels.swift` (BackMatterItem.contributors)
- Modified: `Models/BaseModels.swift` (Project.contributorEntries)
- New: `Views/Sheets/ContributorEditorSheet.swift`
- Modified: `Views/BackMatter/BackMatterGeneratedContentView.swift`
- Modified: `Services/BackMatterGenerator.swift` (generateContributorsSection)
- Modified: `Resources/en.lproj/Localizable.strings`

---

### Phase 18: Back Matter Management UI
**Priority:** Medium | **Estimated Effort:** 1-2 days

**Tasks:**
1. Create `Views/BackMatter/BackMatterView.swift`:
   - Tab or segmented view: Notes | Glossary | Citations | Index
   - Each tab shows the corresponding list view
2. Add navigation from Project view to Back Matter
3. Add "Manage [Type]" menu items or toolbar buttons

**Files:**
- New: `Views/BackMatter/BackMatterView.swift`
- Modified: Navigation/menu structure

---

### Implementation Order Summary

| Order | Phase | Dependencies | Priority |
|-------|-------|--------------|----------|
| 1 | Phase 10: Foundation | None | High |
| 2 | Phase 11: Marker Rendering | Phase 10 | High |
| 3 | Phase 16: Lifecycle & Undo | Phase 10 | High |
| 4 | Phase 12: Notes & Endnotes | Phases 10, 11 | High |
| 5 | Phase 13: Glossary | Phases 10, 11 | High |
| 6 | Phase 14: Citations | Phases 10, 11 | Medium |
| 7 | Phase 15: Index | Phases 10, 11 | Medium |
| 8 | Phase 17: Export Integration | Phases 12-15 | High |
| 9 | Phase 18: Management UI | Phases 12-15 | Medium |

**Total Estimated Effort:** 19-25 days

---

## Completed Phases

### Phase 1: Folder Structure
- Added Manuscript folder with subfolders: Front Matter, Body, Back Matter
- Updated FolderCapabilityService for folder permissions
- Updated ProjectTemplateService to create subfolders on project creation
- Added folder icons and navigation in FolderListView

### Phase 2: Assembly Service & Models
- Created ManuscriptModels.swift:
  - `ManuscriptSection` - represents a section in the manuscript
  - `ManuscriptContent` - assembled content with metadata
  - `ManuscriptSettings` - section break style, footnote numbering
  - `ExportFormat`, `ExportOptions` - for future export types
- Created ManuscriptAssemblyService.swift:
  - `getSections()` - gets all sections for manuscript
  - `getBodySections()` - gets body sections by project type
  - `assembleContent()` - assembles NSAttributedString from sections
- Added `includedInManuscript` property to TextFile model
- Added `manuscriptSettingsData` to Project model

### Phase 3: ManuscriptBodyView (Dynamic Page View)
- Displays assembled body content in a dynamic, paginated, read-only view
- **Poetry/Fiction:** Shows a page view of the files/scenes folder (each file/scene starts on a new page)
- **Drama:** Shows a page view of formatted script scenes (each scene is rendered using the drama script formatter, not as raw text)
- Section headers (chapters, etc.)
- File titles with edit navigation links
- Source folder info in toolbar menu
- **Static text container is no longer used.**

### Phase 4: PDF Export
- Added `generatePDF(from: ManuscriptContent)` to PrintService
- Export button in ManuscriptBodyView toolbar
- Async PDF generation with share sheet

### Phase 5: Include/Exclude UI
- Context menu toggle: "Include in Manuscript" / "Exclude from Manuscript"
- Visual indicator (eye.slash icon, dimmed opacity) for excluded files
- Works for all project types with Manuscript folder

### Phase 8: TOC Generation & Page Numbering ✅ COMPLETE
**Priority:** High | **Completed:** 2026-02-01

**Overview:**
Auto-generated Table of Contents with accurate page numbers that account for all front matter pages. Body view footers display correct page numbers offset by the front matter page count.

**Features:**
- `TOCGenerationService` generates TOC entries with correct page numbers
- Body view footer numbers start after all front matter pages (e.g., if front matter = 4 pages, first body page = 5)
- `startingPageNumber` parameter threaded through `PaginatedDocumentView` → `VirtualPageScrollView` → individual page footers

**Key Implementation: Per-File Pagination**
Page counts are calculated by paginating each file individually using `NSLayoutManager` text containers sized to the manuscript page dimensions. This avoids assembling files with form feed separators, which previously caused phantom empty pages when form feeds doubled up.

**Algorithm (in `TOCGenerationService.calculatePageNumbers`):**
1. **Body pagination** — When `usePageBreaks` is enabled, each body file is paginated independently. The page count for each file is determined by how many pages `NSLayoutManager` requires for the content.
2. **Front matter pagination** — Each front matter file (Title Page, TOC, Acknowledgements, etc.) is paginated independently using the same technique.
3. **Offset calculation** — The sum of all front matter page counts becomes the offset applied to every body entry's page number.
4. **Footer propagation** — `ManuscriptBodyView` calculates the same front matter page count and passes it as `startingPageNumber` to the paginated view, so footer page numbers match the TOC.

**Files:**
- Modified: `Services/TOCGenerationService.swift` — `calculatePageNumbers()` rewritten with per-file pagination
- Modified: `Views/Manuscript/ManuscriptBodyView.swift` — `calculateFrontMatterPageCount()`, `startingPageNumber` pass-through
- Modified: `Views/PaginatedDocumentView.swift` — Added `startingPageNumber` property
- Modified: `Views/VirtualPageScrollView.swift` — `startingPageNumber` threaded through layout → page creation

---

## Mac Catalyst Font Scaling Pipeline

**CRITICAL ARCHITECTURAL NOTE — Read before modifying any print/pagination code**

### The Problem

Mac Catalyst automatically scales all fonts by a factor of **1.3×** for screen display. When the user sets Body to 17pt, Catalyst stores and renders it at 22.1pt. This is invisible to the user but breaks page-count calculations if not accounted for: text set in 22.1pt needs more pages than text set in 17pt, so pagination using raw stored sizes produces incorrect results.

### The Constant: `kCatalystFontScale`

```swift
// PrintFormatter.swift (global scope)

/// Mac Catalyst multiplies all font sizes by this factor for screen display.
/// Every print / page-count path must divide by this value to recover the
/// true point size the user chose.
///
/// Single source of truth — do NOT hard-code 1.3 anywhere else.
let kCatalystFontScale: CGFloat = 1.3
```

**All code that converts stored font sizes to true print sizes MUST use this constant.** Never hard-code `1.3` in any file.

### The Scaling Pipeline

```
User chooses 17pt Body
        │
        ▼
  Catalyst stores 22.1pt  (17 × 1.3)
        │
        ▼
  ┌─────────────────────────────────┐
  │  removePlatformScaling()        │
  │  Divides every font in an       │
  │  NSAttributedString by           │
  │  kCatalystFontScale on Catalyst  │
  │  (no-op on iOS)                  │
  └─────────────────────────────────┘
        │
        ▼
  True 17pt used for:
    • PDF generation (PrintService)
    • Page-count calculation (TOCGenerationService, ManuscriptBodyView)
    • PaginatedDocumentView display
```

### `prepareForPageCounting()` Helper

A convenience method on `NSAttributedString` (defined in `TOCGenerationService`) that applies two transformations in sequence:

1. **Strip trailing form feed** — Title Page and other files may store a trailing `\u{000C}` (form feed) character in their content. If not stripped, `NSLayoutManager` counts it as an extra page.
2. **Descale fonts** — Calls `PrintFormatter.removePlatformScaling()` to divide all font sizes by `kCatalystFontScale`.

```swift
private func prepareForPageCounting(_ content: NSAttributedString) -> NSAttributedString {
    var text = content
    // 1. Strip trailing form feed
    let str = text.string
    if str.hasSuffix("\u{000C}") {
        let trimmed = NSMutableAttributedString(attributedString: text)
        trimmed.deleteCharacters(in: NSRange(location: str.count - 1, length: 1))
        text = trimmed
    }
    // 2. Descale Catalyst fonts to true print sizes
    return PrintFormatter.removePlatformScaling(from: text)
}
```

### Rendered vs Saved Content: The Double-Descale Trap

**Background:** Saved file content (from the database) is stored at Catalyst-scaled sizes (e.g., 22.1pt). Calling `prepareForPageCounting` descales it once to 17pt — correct.

However, the **rendered TOC** is generated at runtime using the same Catalyst-scaled fonts. If passed directly to `prepareForPageCounting`, it would also be descaled once to 17pt — which is correct for page counting but inconsistent with how the TOC renders on screen.

**The fix:** The rendered TOC content is **pre-descaled** with `PrintFormatter.removePlatformScaling()` before being passed to `prepareForPageCounting()`. This means:
- Rendered TOC: 22.1pt → pre-descale to 17pt → `prepareForPageCounting` descales to ~13pt (matches display size)
- Saved files: 22.1pt → `prepareForPageCounting` descales to 17pt (matches print size)

Both paths now produce page counts that match what the user actually sees on their configured page size.

### Files Using `kCatalystFontScale`

| File | Usage |
|------|-------|
| `Services/PrintFormatter.swift` | Defines the constant; `removePlatformScaling()` divides fonts by it |
| `Services/PrintService.swift` | PDF generation font descaling |
| `Views/PaginatedDocumentView.swift` | Display font descaling |
| `Services/TOCGenerationService.swift` | Page counting via `prepareForPageCounting()` |
| `Views/Manuscript/ManuscriptBodyView.swift` | Front matter page counting |
| `Tests/PrintFormatterTests.swift` | Test assertions use the constant |

### Rules for Future Development

1. **Never hard-code `1.3`** — always use `kCatalystFontScale`
2. **Any new page-counting code must call `removePlatformScaling()`** before measuring with `NSLayoutManager`
3. **Strip trailing form feeds** before page counting — saved content may contain them
4. **Test with Mac Catalyst AND iPad** — font sizes differ, both must produce identical page counts
5. **If Apple changes the Catalyst scale factor**, update `kCatalystFontScale` in one place and all code adapts

---

## Future Phases (Not Implemented)

### Phase 6: Full Manuscript View (Medium Priority)
Combined preview of all sections:
- Front Matter + Body + Back Matter in single scrollable view
- Section dividers between major sections
- Could replace or supplement ManuscriptBodyView

### Phase 7: Manuscript Settings UI (Low Priority)
Settings sheet for manuscript preferences:
- Section break style (page break, section mark, double space, none)
- Footnote numbering style (per file, continuous, per section)
- Would use `manuscriptSettingsData` already on Project model

### Phase 9: Print Support (Low Priority)
Direct print functionality:
- Print dialog from ManuscriptBodyView
- Uses existing PrintService infrastructure

## Files Modified/Created

### New Files
- `Models/ManuscriptModels.swift`
- `Services/ManuscriptAssemblyService.swift`
- `Views/Manuscript/ManuscriptBodyView.swift`

### Modified Files
- `Models/BaseModels.swift` - TextFile.includedInManuscript, Project.manuscriptSettings
- `Services/FolderCapabilityService.swift` - folder rules for manuscript subfolders
- `Services/ProjectTemplateService.swift` - createManuscriptSubfolders()
- `Services/PrintService.swift` - generatePDF(from: ManuscriptContent)
- `Views/FolderListView.swift` - navigation and icons
- `Views/Components/FileListView.swift` - include/exclude context menu
- `Resources/en.lproj/Localizable.strings` - all new strings
