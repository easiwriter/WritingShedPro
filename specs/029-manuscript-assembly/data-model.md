# Feature 029: Manuscript Assembly - Data Model

**Date**: 2026-01-10  
**Phase**: 1 Design  
**Status**: Draft

---

## Overview

This document defines the data models for Manuscript Assembly. The design follows the existing codebase patterns using SwiftData/CloudKit for persistence and Swift structs for transient computed data.

---

## 1. Persistent Models (SwiftData)

### 1.1 TextFile Extension

Add a single property to track manuscript inclusion:

```swift
// In TextFile.swift - add to existing @Model class
extension TextFile {
    /// Whether this file is included in manuscript assembly
    /// Default: true (all files included by default)
    @Attribute var includedInManuscript: Bool = true
}
```

**CloudKit Compatibility**: ✅ Simple boolean with default value

### 1.2 Project Extension

Add TOC settings as encoded JSON data:

```swift
// In Project.swift - add to existing @Model class  
extension Project {
    /// Encoded TOC settings for this project
    @Attribute var tocSettingsData: Data?
    
    /// Decoded TOC settings (computed)
    var tocSettings: TOCSettings {
        get {
            guard let data = tocSettingsData else { return TOCSettings() }
            return (try? JSONDecoder().decode(TOCSettings.self, from: data)) ?? TOCSettings()
        }
        set {
            tocSettingsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    /// Encoded manuscript settings for this project
    @Attribute var manuscriptSettingsData: Data?
    
    /// Decoded manuscript settings (computed)
    var manuscriptSettings: ManuscriptSettings {
        get {
            guard let data = manuscriptSettingsData else { return ManuscriptSettings() }
            return (try? JSONDecoder().decode(ManuscriptSettings.self, from: data)) ?? ManuscriptSettings()
        }
        set {
            manuscriptSettingsData = try? JSONEncoder().encode(newValue)
        }
    }
}
```

**CloudKit Compatibility**: ✅ Encoded as Data with defaults

---

## 2. Settings Structs (Codable, not persisted directly)

### 2.1 TOCSettings

```swift
/// Configuration for Table of Contents generation
struct TOCSettings: Codable, Equatable {
    /// Whether to include a TOC in the manuscript
    var includeTOC: Bool = true
    
    /// Whether to show page numbers in the TOC
    var showPageNumbers: Bool = true
    
    /// Whether to indent subsections (Level 2+)
    var indentSubsections: Bool = true
    
    /// Title displayed at the top of the TOC
    var tocTitle: String = "Contents"
    
    /// Maximum heading level to include (1-3)
    var maxLevel: Int = 2
    
    /// Font size for TOC entries
    var fontSize: CGFloat = 12.0
    
    /// Whether to use dot leaders between title and page number
    var useDotLeaders: Bool = true
}
```

### 2.2 ManuscriptSettings

```swift
/// Configuration for manuscript assembly
struct ManuscriptSettings: Codable, Equatable {
    /// Style of section break between files
    var sectionBreakStyle: SectionBreakStyle = .pageBreak
    
    /// Whether to include section headings
    var includeSectionHeadings: Bool = true
    
    /// Whether to include file titles as headers
    var includeFileTitles: Bool = true
    
    /// Footnote numbering style
    var footnoteNumbering: FootnoteNumberingStyle = .perFile
    
    /// Section break style options
    enum SectionBreakStyle: String, Codable, CaseIterable {
        case pageBreak = "pageBreak"       // New page for each file
        case sectionMark = "sectionMark"   // *** or --- mark
        case doubleSpace = "doubleSpace"   // Extra blank lines
        case none = "none"                 // No break, continuous text
        
        var localizedName: String {
            switch self {
            case .pageBreak: return NSLocalizedString("manuscript.break.pageBreak", comment: "Page Break")
            case .sectionMark: return NSLocalizedString("manuscript.break.sectionMark", comment: "Section Mark")
            case .doubleSpace: return NSLocalizedString("manuscript.break.doubleSpace", comment: "Double Space")
            case .none: return NSLocalizedString("manuscript.break.none", comment: "None")
            }
        }
    }
    
    /// Footnote numbering options
    enum FootnoteNumberingStyle: String, Codable, CaseIterable {
        case perFile = "perFile"           // Restart at 1 for each file
        case continuous = "continuous"     // Continue numbering throughout
        case perSection = "perSection"     // Restart for each section
        
        var localizedName: String {
            switch self {
            case .perFile: return NSLocalizedString("manuscript.footnotes.perFile", comment: "Per File")
            case .continuous: return NSLocalizedString("manuscript.footnotes.continuous", comment: "Continuous")
            case .perSection: return NSLocalizedString("manuscript.footnotes.perSection", comment: "Per Section")
            }
        }
    }
}
```

---

## 3. Transient Models (Computed, not persisted)

### 3.1 ManuscriptSection

```swift
/// Represents a section in the assembled manuscript
struct ManuscriptSection: Identifiable {
    let id: UUID
    
    /// Display title for this section
    let title: String
    
    /// Type of section (front, body, back)
    let sectionType: SectionType
    
    /// Source folder (nil for virtual sections)
    let sourceFolder: Folder?
    
    /// Files included in this section, in order
    var files: [TextFile]
    
    /// Level in hierarchy (1 = top level, 2 = subsection)
    let level: Int
    
    /// Computed starting page (set during layout calculation)
    var startingPage: Int?
    
    enum SectionType: String, CaseIterable {
        case frontMatter = "frontMatter"
        case body = "body"
        case backMatter = "backMatter"
        
        var localizedName: String {
            switch self {
            case .frontMatter: return NSLocalizedString("manuscript.section.frontMatter", comment: "Front Matter")
            case .body: return NSLocalizedString("manuscript.section.body", comment: "Body")
            case .backMatter: return NSLocalizedString("manuscript.section.backMatter", comment: "Back Matter")
            }
        }
        
        /// Order for sorting sections
        var sortOrder: Int {
            switch self {
            case .frontMatter: return 0
            case .body: return 1
            case .backMatter: return 2
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        sectionType: SectionType,
        sourceFolder: Folder? = nil,
        files: [TextFile] = [],
        level: Int = 1
    ) {
        self.id = id
        self.title = title
        self.sectionType = sectionType
        self.sourceFolder = sourceFolder
        self.files = files
        self.level = level
    }
}
```

### 3.2 ManuscriptContent

```swift
/// Complete assembled manuscript content
struct ManuscriptContent {
    /// Full assembled attributed string
    let attributedString: NSAttributedString
    
    /// All sections in order
    let sections: [ManuscriptSection]
    
    /// Map from file ID to starting page number
    var pageMap: [UUID: Int]
    
    /// Map from file ID to character offset in attributed string
    let fileOffsets: [UUID: Int]
    
    /// Total page count
    var pageCount: Int
    
    /// Word count
    var wordCount: Int {
        let text = attributedString.string
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count
    }
    
    /// Character count (excluding whitespace)
    var characterCount: Int {
        let text = attributedString.string
        return text.filter { !$0.isWhitespace }.count
    }
    
    init(
        attributedString: NSAttributedString,
        sections: [ManuscriptSection],
        pageMap: [UUID: Int] = [:],
        fileOffsets: [UUID: Int] = [:],
        pageCount: Int = 0
    ) {
        self.attributedString = attributedString
        self.sections = sections
        self.pageMap = pageMap
        self.fileOffsets = fileOffsets
        self.pageCount = pageCount
    }
}
```

### 3.3 TOCEntry

```swift
/// Entry in the Table of Contents
struct TOCEntry: Identifiable {
    let id: UUID
    
    /// Display title
    let title: String
    
    /// Page number (1-based)
    let pageNumber: Int
    
    /// Hierarchy level (1 = chapter, 2 = section, 3 = subsection)
    let level: Int
    
    /// Reference to source file (if applicable)
    let fileID: UUID?
    
    /// Reference to section (if applicable)
    let sectionID: UUID?
    
    init(
        id: UUID = UUID(),
        title: String,
        pageNumber: Int,
        level: Int,
        fileID: UUID? = nil,
        sectionID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.pageNumber = pageNumber
        self.level = level
        self.fileID = fileID
        self.sectionID = sectionID
    }
}
```

### 3.4 TableOfContents

```swift
/// Complete Table of Contents
struct TableOfContents {
    /// TOC entries in order
    let entries: [TOCEntry]
    
    /// Formatted attributed string for the TOC
    let attributedString: NSAttributedString
    
    /// Number of pages the TOC will occupy
    let estimatedPageCount: Int
    
    /// Settings used to generate this TOC
    let settings: TOCSettings
}
```

---

## 4. Assembly Result Types

### 4.1 AssemblyProgress

```swift
/// Progress tracking for manuscript assembly
struct AssemblyProgress {
    /// Total number of files to process
    let totalFiles: Int
    
    /// Number of files processed
    var processedFiles: Int
    
    /// Current phase
    var phase: AssemblyPhase
    
    /// Progress percentage (0.0 - 1.0)
    var progress: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(processedFiles) / Double(totalFiles)
    }
    
    enum AssemblyPhase: String {
        case loading = "loading"
        case assembling = "assembling"
        case calculating = "calculating"
        case complete = "complete"
        
        var localizedDescription: String {
            switch self {
            case .loading: return NSLocalizedString("manuscript.progress.loading", comment: "Loading files...")
            case .assembling: return NSLocalizedString("manuscript.progress.assembling", comment: "Assembling content...")
            case .calculating: return NSLocalizedString("manuscript.progress.calculating", comment: "Calculating layout...")
            case .complete: return NSLocalizedString("manuscript.progress.complete", comment: "Complete")
            }
        }
    }
}
```

### 4.2 AssemblyError

```swift
/// Errors that can occur during manuscript assembly
enum AssemblyError: LocalizedError {
    case noFilesFound
    case fileLoadFailed(String)
    case layoutCalculationFailed
    case exportFailed(String)
    case noPageSetup
    
    var errorDescription: String? {
        switch self {
        case .noFilesFound:
            return NSLocalizedString("manuscript.error.noFiles", comment: "No files found for manuscript assembly")
        case .fileLoadFailed(let filename):
            return String(format: NSLocalizedString("manuscript.error.loadFailed", comment: "Failed to load file: %@"), filename)
        case .layoutCalculationFailed:
            return NSLocalizedString("manuscript.error.layoutFailed", comment: "Failed to calculate page layout")
        case .exportFailed(let format):
            return String(format: NSLocalizedString("manuscript.error.exportFailed", comment: "Failed to export as %@"), format)
        case .noPageSetup:
            return NSLocalizedString("manuscript.error.noPageSetup", comment: "Page setup required for manuscript preview")
        }
    }
}
```

---

## 5. Export Types

### 5.1 ExportFormat

```swift
/// Available export formats for manuscripts
enum ExportFormat: String, CaseIterable, Identifiable {
    case pdf = "pdf"
    case rtf = "rtf"
    case plainText = "txt"
    case word = "docx"
    
    var id: String { rawValue }
    
    var fileExtension: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .pdf: return NSLocalizedString("export.format.pdf", comment: "PDF Document")
        case .rtf: return NSLocalizedString("export.format.rtf", comment: "Rich Text Format")
        case .plainText: return NSLocalizedString("export.format.plainText", comment: "Plain Text")
        case .word: return NSLocalizedString("export.format.word", comment: "Word Document")
        }
    }
    
    var mimeType: String {
        switch self {
        case .pdf: return "application/pdf"
        case .rtf: return "application/rtf"
        case .plainText: return "text/plain"
        case .word: return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        }
    }
    
    var icon: String {
        switch self {
        case .pdf: return "doc.fill"
        case .rtf: return "doc.richtext"
        case .plainText: return "doc.text"
        case .word: return "doc"
        }
    }
}
```

### 5.2 ExportOptions

```swift
/// Options for manuscript export
struct ExportOptions: Equatable {
    /// Selected export format
    var format: ExportFormat = .pdf
    
    /// Include front matter
    var includeFrontMatter: Bool = true
    
    /// Include body
    var includeBody: Bool = true
    
    /// Include back matter
    var includeBackMatter: Bool = true
    
    /// Include table of contents (if configured)
    var includeTableOfContents: Bool = true
    
    /// Include title page
    var includeTitlePage: Bool = true
    
    /// Filename for export (without extension)
    var filename: String = "Manuscript"
}
```

---

## 6. View Models

### 6.1 ManuscriptBodyViewModel

```swift
/// View model for ManuscriptBodyView
@Observable
final class ManuscriptBodyViewModel {
    var sections: [ManuscriptSection] = []
    var isLoading: Bool = false
    var error: AssemblyError?
    var progress: AssemblyProgress?
    var manuscriptContent: ManuscriptContent?
    
    private let project: Project
    private let context: ModelContext
    private let assemblyService: ManuscriptAssemblyService
    
    init(project: Project, context: ModelContext) {
        self.project = project
        self.context = context
        self.assemblyService = ManuscriptAssemblyService(context: context)
    }
    
    func loadSections() async {
        // Load section structure from project folders
    }
    
    func assembleManuscript() async throws -> ManuscriptContent {
        // Assemble full content
    }
    
    func toggleFileInclusion(_ file: TextFile) {
        // Toggle includedInManuscript
    }
}
```

### 6.2 ManuscriptPreviewViewModel

```swift
/// View model for manuscript preview
@Observable
final class ManuscriptPreviewViewModel {
    var content: ManuscriptContent?
    var isLoading: Bool = false
    var pageCount: Int = 0
    var currentPage: Int = 1
    var error: AssemblyError?
    
    private let project: Project
    private let context: ModelContext
    
    init(project: Project, context: ModelContext) {
        self.project = project
        self.context = context
    }
    
    func loadPreview() async {
        // Assemble and calculate layout
    }
}
```

---

## 7. Localization Keys

```
// Manuscript Settings
"manuscript.break.pageBreak" = "Page Break";
"manuscript.break.sectionMark" = "Section Mark";
"manuscript.break.doubleSpace" = "Double Space";
"manuscript.break.none" = "None";
"manuscript.footnotes.perFile" = "Per File";
"manuscript.footnotes.continuous" = "Continuous";
"manuscript.footnotes.perSection" = "Per Section";

// Section Types
"manuscript.section.frontMatter" = "Front Matter";
"manuscript.section.body" = "Body";
"manuscript.section.backMatter" = "Back Matter";

// Progress
"manuscript.progress.loading" = "Loading files...";
"manuscript.progress.assembling" = "Assembling content...";
"manuscript.progress.calculating" = "Calculating layout...";
"manuscript.progress.complete" = "Complete";

// Errors
"manuscript.error.noFiles" = "No files found for manuscript assembly";
"manuscript.error.loadFailed" = "Failed to load file: %@";
"manuscript.error.layoutFailed" = "Failed to calculate page layout";
"manuscript.error.exportFailed" = "Failed to export as %@";
"manuscript.error.noPageSetup" = "Page setup required for manuscript preview";

// Export Formats
"export.format.pdf" = "PDF Document";
"export.format.rtf" = "Rich Text Format";
"export.format.plainText" = "Plain Text";
"export.format.word" = "Word Document";

// Folder Names
"folder.frontMatter" = "Front Matter";
"folder.body" = "Body";
"folder.backMatter" = "Back Matter";
```

---

## 8. Migration Notes

### 8.1 Schema Changes

| Entity | Change | Migration |
|--------|--------|-----------|
| TextFile | Add `includedInManuscript: Bool` | Default `true` |
| Project | Add `tocSettingsData: Data?` | Default `nil` |
| Project | Add `manuscriptSettingsData: Data?` | Default `nil` |

### 8.2 CloudKit Compatibility

All changes are CloudKit-compatible:
- New optional attributes with defaults
- Encoded Data fields for complex settings
- No unique constraints
- No breaking changes to existing data

---

## 9. Relationships Diagram

```
┌─────────────┐     ┌─────────────────────┐
│   Project   │────▶│   PageSetup         │
└─────────────┘     └─────────────────────┘
       │
       │ (encoded)
       ▼
┌─────────────────────┐
│   TOCSettings       │
│   ManuscriptSettings│
└─────────────────────┘

┌─────────────┐     ┌─────────────────────┐
│   Folder    │────▶│   TextFile          │
│  (Sections) │     │ +includedInManuscript│
└─────────────┘     └─────────────────────┘
       │
       │ (computed)
       ▼
┌─────────────────────┐
│  ManuscriptSection  │──────┐
└─────────────────────┘      │
       │                     │
       │ (computed)          │
       ▼                     ▼
┌─────────────────────┐  ┌─────────────────────┐
│  ManuscriptContent  │  │   TOCEntry          │
└─────────────────────┘  └─────────────────────┘
```
