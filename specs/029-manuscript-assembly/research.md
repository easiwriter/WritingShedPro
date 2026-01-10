# Feature 029: Manuscript Assembly - Research

## Phase 0 Research Output

**Date**: 2026-01-10  
**Researcher**: Copilot  
**Status**: Complete

---

## Executive Summary

Manuscript Assembly builds on existing infrastructure for pagination (Feature 010) and printing (Feature 020). The existing `PaginatedTextLayoutManager`, `CustomPDFPageRenderer`, and `PrintService` provide all necessary capabilities for preview and export. The main new work is content assembly logic that combines files from source folders into a unified document view.

---

## 1. Existing Infrastructure Analysis

### 1.1 Pagination System (Feature 010)

**Location**: `Services/PaginatedTextLayoutManager.swift`, `Views/PaginatedDocumentView.swift`

**Key Capabilities**:
- Virtual scrolling for documents up to 200+ pages
- Uses TextKit 1 with `NSTextStorage` and `NSLayoutManager`
- Respects `PageSetup` settings (paper size, margins, headers/footers)
- Memory efficient: renders only visible pages + 2-page buffer
- Footnote-aware layout calculation

**Reuse Opportunity**: ✅ Full reuse for manuscript preview
- `PaginatedTextLayoutManager.calculateLayout()` can accept assembled content
- Page count calculation is already built-in
- No modifications needed for single-file preview

**Gap**: Current pagination is single-file only. Need to:
- Concatenate multiple file contents with section breaks
- Track page number offsets for TOC generation

### 1.2 Print/PDF System (Feature 020)

**Location**: `Services/PrintService.swift`, `Views/CustomPDFPageRenderer.swift`

**Key Capabilities**:
```swift
// Single file PDF
PrintService.generatePDF(from: file, project: project, context: context) -> Data?

// Multiple files PDF  
PrintService.generatePDF(from: files, title: String) -> Data?

// Share sheet
PrintService.sharePDF(data, filename: String, from: viewController)

// Save to Documents
PrintService.savePDF(data, filename: String) -> URL?
```

**Reuse Opportunity**: ✅ Full reuse for PDF export
- Multi-file `generatePDF()` already exists
- Uses `CustomPDFPageRenderer` with full layout manager support
- Footnote rendering is built-in

**Gap**: Multi-file version doesn't track individual file page boundaries. For TOC, need to:
- Calculate page numbers for each section before rendering
- Pass section metadata to renderer for TOC page generation

### 1.3 Folder System

**Location**: `Services/FolderCapabilityService.swift`, `Services/ProjectTemplateService.swift`

**Key Capabilities**:
- `readOnlyFolders`: Folders that receive content automatically (includes "Manuscript")
- `fileOnlyFolders`: Content source folders ("Poems", "Scenes", "Scripts")
- `mixedContentFolders`: Flexible containers ("Folders", "Sections")

**Current Structure** (General Purpose):
```
Project/
├── Manuscript (read-only)
├── Sections (mixed content)
└── Trash (read-only)
```

**Gap**: Manuscript folder needs three subfolders:
```
Manuscript/
├── Front Matter (new)
├── Body (new, special - assembles from content folders)
└── Back Matter (new)
```

### 1.4 File Navigation Patterns

**Location**: `Views/FolderListView.swift`, `Views/FolderFilesView.swift`

**Patterns Used**:
- Folders displayed in project-type-specific order
- Files displayed in list with navigation links
- Long-press back button support (`PopToRootBackButton`, `.onPopToRoot`)
- Toolbar actions based on folder capabilities

**Reuse Opportunity**: ✅ Similar patterns for Manuscript views
- Front/Back Matter behave like normal file folders
- Body is special view showing assembled content

---

## 2. Content Assembly Logic

### 2.1 Source Folder Mapping by Project Type

| Project Type | Source Folder | Assembly Behavior |
|--------------|---------------|-------------------|
| Poetry | Poems | All poems in order |
| Fiction | Chapters | Chapter folders with scenes |
| Drama | Scripts | Script files in order |
| General Purpose | Sections | Files from Sections hierarchy |

### 2.2 Assembly Algorithm

```swift
protocol ManuscriptAssemblyService {
    /// Returns assembled content for preview/export
    func assembleManuscript(for project: Project) async -> ManuscriptContent
    
    /// Returns sections with file lists for TOC generation
    func getSectionMetadata(for project: Project) -> [ManuscriptSection]
}

struct ManuscriptSection {
    let title: String
    let sourceFolder: Folder?
    let files: [TextFile]
    let sectionType: SectionType // frontMatter, body, backMatter
    
    enum SectionType {
        case frontMatter
        case body  
        case backMatter
    }
}

struct ManuscriptContent {
    let attributedString: NSAttributedString
    let sections: [ManuscriptSection]
    let pageMap: [UUID: Int] // fileID -> starting page number
}
```

### 2.3 Section Breaks

Between files/sections, insert:
- Page break (form feed character or TextKit page break)
- Optional section heading (configurable)
- Consistent spacing

---

## 3. TOC Generation

### 3.1 Requirements

1. **Automatic generation** from section structure
2. **Page numbers** calculated during pagination
3. **Multiple levels**: 
   - Level 1: Major sections (Front Matter, Chapter 1, etc.)
   - Level 2: Individual files (Poem titles, Scene titles)
4. **Project-type specific formatting**

### 3.2 Technical Approach

**Phase 1: Calculate Layout** (during preview generation)
```swift
func calculateManuscriptLayout(content: ManuscriptContent, pageSetup: PageSetup) -> LayoutResult {
    // Use existing PaginatedTextLayoutManager
    let layoutManager = PaginatedTextLayoutManager(textStorage: storage, pageSetup: pageSetup)
    layoutManager.calculateLayout()
    
    // Record page number for each section/file start position
    for section in content.sections {
        for file in section.files {
            let charPosition = content.fileStartPosition[file.id]
            let pageNumber = layoutManager.pageContainingCharacter(charPosition)
            pageMap[file.id] = pageNumber
        }
    }
    
    return LayoutResult(pageCount: layoutManager.pageCount, pageMap: pageMap)
}
```

**Phase 2: Generate TOC Content**
```swift
func generateTOC(sections: [ManuscriptSection], pageMap: [UUID: Int]) -> NSAttributedString {
    var toc = NSMutableAttributedString()
    
    for section in sections {
        // Add section heading
        toc.append(formatTOCEntry(section.title, level: 1, page: nil))
        
        for file in section.files {
            let page = pageMap[file.id] ?? 0
            toc.append(formatTOCEntry(file.name, level: 2, page: page))
        }
    }
    
    return toc
}
```

**Phase 3: Insert TOC** (optional, based on settings)
- TOC goes in Front Matter
- User can choose to generate/regenerate
- TOC itself affects page numbers (chicken-and-egg problem)

### 3.3 Chicken-and-Egg Solution

Since TOC needs page numbers, but inserting TOC changes page numbers:

1. **First pass**: Calculate layout without TOC
2. **Estimate TOC pages**: Based on entry count
3. **Offset page numbers**: Add TOC page count to all body/back matter pages
4. **Generate TOC**: With offset numbers
5. **Validate**: Re-calculate to ensure TOC fits estimated pages

---

## 4. Export Formats

### 4.1 PDF Export

**Existing**: `PrintService.generatePDF(from:project:context:)` ✅  
**Enhancement**: Use assembled content with `CustomPDFPageRenderer`

### 4.2 RTF Export

**Existing**: `RTFService` for single files  
**Enhancement**: Combine multiple RTF sections with page breaks

### 4.3 Plain Text Export

**Approach**: Strip formatting, add text dividers between sections  
**Implementation**: Simple text concatenation with markers

### 4.4 Word (.docx) Export

**Existing**: `WordDocumentService` for single files  
**Enhancement**: Multi-section document with section breaks

---

## 5. Data Model Decisions

### 5.1 ManuscriptSection Entity

**Decision**: Store as transient computed model, not SwiftData
**Rationale**: 
- Section structure derives from folder hierarchy
- No need to persist (can always recompute)
- Avoids sync complexity with CloudKit

### 5.2 TOCEntry Entity

**Decision**: Store TOC configuration in Project settings
**Rationale**:
- TOC format preferences are per-project
- Page numbers are ephemeral (recalculate each time)

```swift
extension Project {
    var tocSettings: TOCSettings {
        get { /* decode from JSON in tocSettingsData */ }
        set { /* encode to JSON */ }
    }
}

struct TOCSettings: Codable {
    var includeTOC: Bool = true
    var showPageNumbers: Bool = true
    var indentSubsections: Bool = true
    var tocTitle: String = "Contents"
}
```

### 5.3 Include/Exclude Files

**Decision**: Add `includedInManuscript` flag to TextFile
**Rationale**:
- Simple boolean on existing entity
- CloudKit compatible
- Easy to toggle per-file

```swift
extension TextFile {
    @Attribute var includedInManuscript: Bool = true
}
```

---

## 6. Performance Considerations

### 6.1 Large Manuscripts

| Scale | Estimated Performance | Mitigation |
|-------|----------------------|------------|
| 50 files, 50k words | < 1 second | None needed |
| 100 files, 100k words | 1-2 seconds | Background assembly |
| 200+ files, 200k+ words | 3-5 seconds | Progress indicator |

### 6.2 Memory Optimization

- **Lazy loading**: Only load file content when assembling
- **Streaming**: For very large documents, stream to PDF page by page
- **Caching**: Cache assembled content until source files change

### 6.3 Background Processing

Use Swift concurrency for assembly:
```swift
func assembleManuscript(for project: Project) async -> ManuscriptContent {
    // Run on background thread
    await withTaskGroup(of: (UUID, NSAttributedString).self) { group in
        for file in files {
            group.addTask {
                return (file.id, await loadFileContent(file))
            }
        }
        // Collect and combine results
    }
}
```

---

## 7. UI/UX Patterns

### 7.1 Navigation

```
Project (folder list)
  └── Manuscript
        ├── Front Matter → FolderFilesView (standard)
        ├── Body → ManuscriptBodyView (special)
        └── Back Matter → FolderFilesView (standard)
```

### 7.2 ManuscriptBodyView

**Purpose**: Show assembled content structure, not editable  
**Features**:
- List of sections/files with order indicators
- Include/exclude toggle per file
- Drag to reorder (if supported)
- Preview button → PaginatedDocumentView
- Export button → ManuscriptExportSheet

### 7.3 Toolbar Actions

| Action | Icon | Behavior |
|--------|------|----------|
| Preview | `doc.text.magnifyingglass` | Open paginated preview |
| Export | `square.and.arrow.up` | Open export sheet |
| Settings | `gearshape` | Open manuscript settings |

---

## 8. Migration Strategy

### 8.1 Existing Projects

**Approach**: Non-destructive migration
1. Detect projects without Manuscript subfolders
2. Create subfolders on first access to Manuscript
3. Preserve any existing content in Manuscript folder

### 8.2 New Projects

ProjectTemplateService already creates Manuscript. Update to:
```swift
// For all project types
createManuscriptSubfolders(in: manuscriptFolder):
    - Front Matter
    - Body (virtual, no actual folder?)
    - Back Matter
```

**Decision Point**: Is Body a real folder or virtual view?
- **Real folder**: Simpler model, but where do copies of files go?
- **Virtual view**: Shows files from source folders, no duplication

**Recommendation**: Virtual view for Body. Front/Back Matter are real folders.

---

## 9. Open Questions Resolved

| Question | Decision | Rationale |
|----------|----------|-----------|
| Store section structure? | Computed from folders | Avoids sync issues |
| Body as real folder? | Virtual view | Avoids file duplication |
| TOC page number accuracy? | Two-pass calculation | Industry standard approach |
| Multi-file footnotes? | Per-file numbering | Restart at 1 per file |
| Section break style? | Configurable | Let user choose |

---

## 10. Dependencies

### 10.1 Feature Dependencies

| Dependency | Status | Notes |
|------------|--------|-------|
| Feature 010 (Pagination) | ✅ Complete | Full reuse |
| Feature 020 (Printing) | ✅ Complete | Full reuse |
| PageSetup | ✅ Exists | No changes needed |

### 10.2 Code Dependencies

| Module | Usage |
|--------|-------|
| `PaginatedTextLayoutManager` | Layout calculation |
| `CustomPDFPageRenderer` | PDF generation |
| `PrintService` | Export methods |
| `FolderCapabilityService` | Folder rules |
| `ProjectTemplateService` | Subfolder creation |

---

## 11. Recommendations

### 11.1 Implementation Order

1. **Phase 1**: Folder structure (ProjectTemplateService, FolderCapabilityService)
2. **Phase 2**: ManuscriptAssemblyService (content assembly)
3. **Phase 3**: ManuscriptBodyView (UI for assembly)
4. **Phase 4**: ManuscriptPreviewView (use existing pagination)
5. **Phase 5**: Export (extend existing PrintService)
6. **Phase 6**: Include/exclude toggle
7. **Phase 7**: TOC generation

### 11.2 Risk Mitigations

| Risk | Mitigation |
|------|------------|
| Large document performance | Background assembly + progress indicator |
| TOC page accuracy | Two-pass calculation with validation |
| CloudKit sync | Use existing patterns, no new entities |

### 11.3 Testing Strategy

- **Unit tests**: ManuscriptAssemblyService, TOCGeneratorService
- **Integration tests**: Full export pipeline
- **UI tests**: Navigation, preview, export flow
- **Performance tests**: 100+ file manuscripts

---

## Appendix A: File Locations

| Component | Path |
|-----------|------|
| PaginatedTextLayoutManager | `Services/PaginatedTextLayoutManager.swift` |
| CustomPDFPageRenderer | `Services/CustomPDFPageRenderer.swift` |
| PrintService | `Services/PrintService.swift` |
| FolderCapabilityService | `Services/FolderCapabilityService.swift` |
| ProjectTemplateService | `Services/ProjectTemplateService.swift` |
| PageSetup | `Models/PageSetupModels.swift` |

## Appendix B: Pagination Decisions (from Feature 010)

| Decision | Choice |
|----------|--------|
| Architecture | Virtual scrolling |
| View Mode | Always start in edit mode |
| Editing | Read-only in paginated mode |
| Page Numbers | In headers/footers |
| Performance | Visible pages + 2-page buffer |
| Export Integration | WYSIWYG print preview |
