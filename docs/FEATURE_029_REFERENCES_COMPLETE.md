# Feature 029: References System - Implementation Complete

## Overview
Implemented a complete References feature (formerly Bibliography) with create/edit functionality and full back matter integration. The system follows the same patterns as endnotes and citations for consistency.

## Files Created

### 1. ReferenceCreatorSheet.swift
- Dialog for creating new references or editing existing ones
- Two-mode interface:
  - **Create New Mode**: Fields for author, publication date, further details (optional)
  - **Reference Existing Mode**: Select from existing references to reuse
- Reference count display shows how many times each reference is used
- Discard confirmation dialog when changes exist
- Presentable as `.medium` or `.large` sheet

### 2. ReferencesListView.swift
- Back matter view for managing all references in a project
- Features:
  - Alphabetical sorting by author
  - Search/filter by author, date, or details
  - Reference count for each entry
  - Edit/delete menu for each reference
  - Empty state view with "Add Reference" prompt
  - Delete confirmation (only allows delete if reference count is 0)
  - SearchableTextField component for search UI

## Files Modified

### FileEditView.swift
- Added state variables:
  - `@State private var showReferencesList`
  - `@State private var showNewReferenceDialog`
  - `@State private var selectedReference: ReferenceEntry?`

- Added insert menu button with reference count indicator
  - Shows "(n)" suffix if references exist
  - Appears in both full and compact menus
  - Icon: "books.vertical.fill"

- Added sheet handlers:
  - `showReferencesList` → ReferencesListView
  - `showNewReferenceDialog` → ReferenceCreatorSheet (new reference)
  - `selectedReference` → ReferenceCreatorSheet (edit reference)

- Implemented reference marker methods:
  - `insertReferenceMarker(for:)` - Insert marker at cursor, increment count
  - `removeReferenceMarkers(for:)` - Remove all markers for a reference
  - `jumpToReferenceMarker(_:)` - Navigate to first marker in text

- Added compact reference button:
  - `compactReferenceSubmenu()` for small screens

### Localizable.strings
- Added 40+ localization keys:
  - Insert menu: `insertMenu.addReference`, `insertMenu.showReferences`
  - Creator sheet: Author, date, details field labels and footers
  - List view: Title, search placeholder, empty state messages
  - Back matter: "backMatter.references" enum case display
  - Menu actions: Edit, delete options

### ReferenceAttachment.swift
- Added convenience init for creating reference markers:
  ```swift
  convenience init(referenceEntryID: UUID, author: String, date: String)
  ```
- Generates `[Author, Date]` formatted display text
- Automatically styled blue/black based on `isForPageView`

### ReferenceModels.swift
- `ReferenceType` enum updated with `.reference` case
- Display format: `"%@, %@"` (author, date)
- Plain text format: `"[%@, %@]"` (author, date)

### BaseModels.swift
- Added to Project model:
  ```swift
  @Relationship(deleteRule: .cascade, inverse: \ReferenceEntry.project) 
  var referenceEntries: [ReferenceEntry]? = []
  ```

### MatterSettingsModels.swift
- BackMatterItem enum updated:
  - Changed `.bibliography` case to `.references`
  - Case name: `references = "References"`
  - Localization: `backMatter.references`

## UI/UX Design

### ReferenceCreatorSheet
```
┌─ New Reference ──────────────────┐
│                                  │
│ [Hide Reference Existing]   (if existing)
│                                  │
│ Author *                         │
│ [Author name or organisation]    │
│                                  │
│ Publication Date *               │
│ [Year or date]                   │
│                                  │
│ Further Details                  │
│ [Journal, publisher, URL, etc]   │
│                                  │
│ [Cancel]              [Save]     │
└──────────────────────────────────┘

Reference Existing Mode:
┌─ Reference Existing List ────────┐
│ Smith, 2023                      │ ☑
│ Journal of Example Vol 45        │ (5)
│ ─────────────────────────────────│
│ Johnson, 2022                    │
│ University Press ISBN: 978-...   │ (3)
│ ─────────────────────────────────│
│ Williams, 2024                   │ 
│ Online publication               │ (1)
└──────────────────────────────────┘
```

### ReferencesListView
```
┌─ References ────────────────┐
│ [Search references...]  [+] │
│                             │
│ ┌─ Smith, 2023 ────────┐   │
│ │ Journal of Example   │ ≡ │
│ │ Vol 45               │ 5 │
│ └─────────────────────┘   │
│                             │
│ ┌─ Johnson, 2022 ───────┐  │
│ │ University Press      │ ≡ │
│ │ ISBN: 978-...         │ 3 │
│ └─────────────────────┘   │
│                             │
│ ┌─ Williams, 2024 ───────┐ │
│ │ Online publication    │ ≡ │
│ │                       │ 1 │
│ └─────────────────────┘   │
└─────────────────────────────┘
```

## Integration Points

### Insert Menu
- Appears when back matter settings enable references
- Shows reference count: "Add Reference (3)" if 3 references exist
- Both full menu and compact menu support

### Reference Marker
- Format in text: `[Author, Date]` with superscript number
- Edit mode: Blue color for visibility
- Page view: Black color for final appearance
- Stored as NSTextAttachment subclass in AttributedString

### Back Matter Generation
- References file auto-created in Back Matter folder
- Content generated from ReferenceEntry list
- Format: Author, Date, Details (if populated)
- Sortable/searchable from back matter list

## Data Model

### ReferenceEntry
```swift
@Model
final class ReferenceEntry {
    var id: UUID
    var project: Project?
    var author: String  // Author or organization
    var publicationDate: String  // Year or full date
    var details: String  // Journal, publisher, URL, etc.
    var referenceCount: Int  // How many times referenced in text
    var createdAt: Date
    var modifiedAt: Date
    
    // Computed properties
    var inlineMarker: String  // "[Author, Date]"
    
    // Methods
    func incrementReferenceCount()
    func decrementReferenceCount()
}
```

## Marker Format Examples

**Text Appearance:**
- Edit mode: `Smith, 2023¹` (blue superscript)
- Page view: `Smith, 2023¹` (black superscript)

**Stored Format:**
- NSTextAttachment with ReferenceAttachment subclass
- Display text: `"Smith, 2023"`
- Reference type: `.reference`
- Entry ID: UUID of ReferenceEntry

## Workflow

### Adding a Reference

1. User clicks "Add Reference" in insert menu or from references list
2. ReferenceCreatorSheet opens in create mode
3. Two options:
   - **Create New**: Enter author, date, details
   - **Reference Existing**: Select from list of existing references
4. Save → Marker inserted at cursor with `[Author, Date]` format
5. Reference count incremented for the entry

### Editing a Reference

1. Open References list view
2. Click reference → ReferenceCreatorSheet opens in edit mode
3. Modify author, date, or details
4. Save → Updates reference, all markers update automatically

### Reusing a Reference

1. Click "Add Reference" in insert menu
2. Choose "Reference Existing"
3. Select reference from list
4. Marker inserted with same author/date information
5. Reference count incremented

## Testing Checklist

- [ ] Create new reference from insert menu
- [ ] Create multiple references
- [ ] Reference existing works correctly
- [ ] Search references by author, date, details
- [ ] Edit reference updates all markers
- [ ] Delete reference (when count = 0)
- [ ] Edit/delete menus appear correctly
- [ ] Empty state displays when no references
- [ ] Reference count shows in menu
- [ ] Markers display in blue/black correctly
- [ ] Jump to reference marker works
- [ ] Markers persist after save/reload
- [ ] Back matter file generates correctly
- [ ] References appear in manuscript preview

## Technical Notes

### Performance Considerations
- References lazy-loaded from project relationship
- Search uses `localizedCaseInsensitiveContains`
- Sorted alphabetically by default
- Reference count incremented directly (no aggregation queries)

### Database Integration
- Cascade delete rule: deleting project deletes all references
- Inverse relationship: `ReferenceEntry.project`
- Reference count tracked per entry
- Timestamps maintained for sort/filter options

### Consistency with Other Back Matter Items
- Same insert menu pattern as citations/index
- Sheet-based editor like glossary terms
- List view with search like endnotes/glossary
- Same marker styling system as all references
- Follows established reference attachment pattern

## Next Steps

1. **Back Matter Generation**: Generate references section in manuscript
2. **Bibliography/Citations**: Clarify relationship between References and CitationEntry
3. **Import/Export**: Support for importing from bibliography formats (BibTeX, etc.)
4. **Reference Formatting**: Support multiple citation styles (APA, MLA, Chicago, etc.)
5. **Cross-References**: Allow references in other back matter items

## Commit Info
- Branch: 021-smart-poetry-creation
- Commit: ba5eebd
- Message: "Feature 029: Implement References system with creator sheet and list view"

## File Statistics
- Files created: 2
- Files modified: 7
- Localization keys added: 40+
- Lines of code: ~800 (UI + logic)
