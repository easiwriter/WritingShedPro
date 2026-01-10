# Feature 029: Manuscript Assembly - Quickstart Guide

**For Developers**  
**Date**: 2026-01-10

---

## Overview

This guide provides the essential information to start implementing Manuscript Assembly. Read [research.md](research.md) for full context and [data-model.md](data-model.md) for complete model definitions.

---

## 1. Key Concepts

### What Manuscript Assembly Does

1. **Assembles** content from source folders (Poems, Scenes, Scripts, Sections)
2. **Combines** with Front Matter and Back Matter folders
3. **Previews** the complete work with pagination
4. **Exports** to PDF, RTF, Plain Text, Word
5. **Generates** Table of Contents with page numbers

### Three-Subfolder Structure

Every project's Manuscript folder contains:
```
Manuscript/
├── Front Matter  → User-created files (title page, dedication, etc.)
├── Body          → VIRTUAL: Shows assembled content from source folders
└── Back Matter   → User-created files (appendix, bibliography, etc.)
```

**Body is virtual** - it shows files from source folders, not a copy.

---

## 2. Existing Code to Reuse

### Pagination (Feature 010)

```swift
// Location: Services/PaginatedTextLayoutManager.swift

// Create layout manager with assembled content
let textStorage = NSTextStorage(attributedString: assembledContent)
let layoutManager = PaginatedTextLayoutManager(
    textStorage: textStorage,
    pageSetup: project.pageSetup
)

// Calculate layout - this gives us page count
let pageCount = layoutManager.calculateLayout()

// Get page for specific character position
let page = layoutManager.pageContainingCharacter(at: characterIndex)
```

### PDF Export (Feature 020)

```swift
// Location: Services/PrintService.swift

// For assembled manuscript content
let renderer = CustomPDFPageRenderer(
    layoutManager: layoutManager,
    pageSetup: pageSetup,
    version: nil,  // No version for multi-file
    context: context,
    project: project
)

// Generate PDF data
let pdfData = PrintService.createPDF(
    from: assembledContent,
    pageSetup: pageSetup,
    title: "Manuscript",
    version: nil,
    project: project,
    context: context
)
```

### Folder Capabilities

```swift
// Location: Services/FolderCapabilityService.swift

// Add new folders to readOnlyFolders
private static let readOnlyFolders: Set<String> = [
    "Collections", "Trash", "Manuscript",
    "Front Matter", "Back Matter", "Body",  // ADD THESE
    // ...
]

// Body is special - doesn't allow file additions
// Front/Back Matter DO allow file additions
```

---

## 3. Implementation Starting Points

### Phase 1: Folder Structure

**Files to modify:**

1. **ProjectTemplateService.swift** - Create subfolders
```swift
// In createProjectFolders() after creating Manuscript folder:
func createManuscriptSubfolders(in manuscriptFolder: Folder, context: ModelContext) {
    let subfolderNames = ["folder.frontMatter", "folder.body", "folder.backMatter"]
    for (index, nameKey) in subfolderNames.enumerated() {
        let subfolder = Folder(
            name: NSLocalizedString(nameKey, comment: ""),
            displayOrder: Int16(index),
            parentFolder: manuscriptFolder
        )
        context.insert(subfolder)
    }
}
```

2. **FolderCapabilityService.swift** - Define capabilities
```swift
// Front/Back Matter can have files added
private static let fileOnlyFolders: Set<String> = [
    "Files", "Research", "Poems", "Scenes", "Scripts",
    "Front Matter", "Back Matter"  // ADD THESE
]

// Body is read-only (virtual content)
private static let readOnlyFolders: Set<String> = [
    "Collections", "Trash", "Manuscript", "Body",  // ADD Body
    // ...
]
```

3. **FolderListView.swift** - Update folder order
```swift
private func folderOrderForProjectType(_ projectType: ProjectType) -> [String] {
    switch projectType {
    // For Manuscript subfolder view:
    case .manuscript:
        return ["Front Matter", "Body", "Back Matter"]
    // ...
    }
}
```

### Phase 2: Assembly Service

**New file: Services/ManuscriptAssemblyService.swift**

```swift
import Foundation
import SwiftData

@Observable
final class ManuscriptAssemblyService {
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    /// Get source folder for body content based on project type
    func getBodySourceFolder(for project: Project) -> Folder? {
        let sourceMapping: [ProjectType: String] = [
            .poetry: "Poems",
            .fiction: "Scenes",  // Or Chapters - check hierarchy
            .drama: "Scripts",
            .generalPurpose: "Sections"
        ]
        
        guard let sourceName = sourceMapping[project.projectType],
              let folders = project.folders else { return nil }
        
        return folders.first { $0.name == sourceName }
    }
    
    /// Assemble manuscript sections
    func getSections(for project: Project) -> [ManuscriptSection] {
        var sections: [ManuscriptSection] = []
        
        // 1. Front Matter
        if let frontMatter = getManuscriptSubfolder(project, named: "Front Matter") {
            let files = frontMatter.files?.sorted(by: { 
                ($0.displayOrder ?? 0) < ($1.displayOrder ?? 0) 
            }) ?? []
            sections.append(ManuscriptSection(
                title: "Front Matter",
                sectionType: .frontMatter,
                sourceFolder: frontMatter,
                files: files.filter { $0.includedInManuscript }
            ))
        }
        
        // 2. Body (from source folder)
        if let bodySource = getBodySourceFolder(for: project) {
            let files = collectFilesRecursively(from: bodySource)
                .filter { $0.includedInManuscript }
            sections.append(ManuscriptSection(
                title: "Body",
                sectionType: .body,
                sourceFolder: bodySource,
                files: files
            ))
        }
        
        // 3. Back Matter
        if let backMatter = getManuscriptSubfolder(project, named: "Back Matter") {
            let files = backMatter.files?.sorted(by: {
                ($0.displayOrder ?? 0) < ($1.displayOrder ?? 0)
            }) ?? []
            sections.append(ManuscriptSection(
                title: "Back Matter",
                sectionType: .backMatter,
                sourceFolder: backMatter,
                files: files.filter { $0.includedInManuscript }
            ))
        }
        
        return sections
    }
    
    /// Assemble full manuscript content
    func assembleContent(for project: Project) async throws -> ManuscriptContent {
        let sections = getSections(for: project)
        
        guard sections.contains(where: { !$0.files.isEmpty }) else {
            throw AssemblyError.noFilesFound
        }
        
        let settings = project.manuscriptSettings
        let assembled = NSMutableAttributedString()
        var fileOffsets: [UUID: Int] = [:]
        
        for section in sections {
            for file in section.files {
                // Record offset before adding
                fileOffsets[file.id] = assembled.length
                
                // Add file content
                if let content = file.currentVersion?.content {
                    assembled.append(content)
                }
                
                // Add section break
                assembled.append(sectionBreak(for: settings))
            }
        }
        
        return ManuscriptContent(
            attributedString: assembled,
            sections: sections,
            fileOffsets: fileOffsets
        )
    }
    
    private func sectionBreak(for settings: ManuscriptSettings) -> NSAttributedString {
        switch settings.sectionBreakStyle {
        case .pageBreak:
            return NSAttributedString(string: "\u{0C}")  // Form feed
        case .sectionMark:
            return NSAttributedString(string: "\n\n* * *\n\n")
        case .doubleSpace:
            return NSAttributedString(string: "\n\n\n\n")
        case .none:
            return NSAttributedString(string: "")
        }
    }
    
    private func getManuscriptSubfolder(_ project: Project, named: String) -> Folder? {
        guard let manuscript = project.folders?.first(where: { $0.name == "Manuscript" }) else {
            return nil
        }
        return manuscript.subfolders?.first { $0.name == named }
    }
    
    private func collectFilesRecursively(from folder: Folder) -> [TextFile] {
        var files = folder.files?.sorted(by: {
            ($0.displayOrder ?? 0) < ($1.displayOrder ?? 0)
        }) ?? []
        
        for subfolder in (folder.subfolders ?? []).sorted(by: {
            ($0.displayOrder ?? 0) < ($1.displayOrder ?? 0)
        }) {
            files.append(contentsOf: collectFilesRecursively(from: subfolder))
        }
        
        return files
    }
}
```

### Phase 3: Body View

**New file: Views/Manuscript/ManuscriptBodyView.swift**

```swift
import SwiftUI
import SwiftData

struct ManuscriptBodyView: View {
    let project: Project
    @Environment(\.modelContext) private var context
    @State private var viewModel: ManuscriptBodyViewModel
    @State private var showingPreview = false
    @State private var showingExport = false
    
    init(project: Project, context: ModelContext) {
        self.project = project
        self._viewModel = State(initialValue: ManuscriptBodyViewModel(
            project: project,
            context: context
        ))
    }
    
    var body: some View {
        List {
            ForEach(viewModel.sections) { section in
                Section(header: Text(section.title)) {
                    ForEach(section.files) { file in
                        ManuscriptFileRow(
                            file: file,
                            onToggleInclude: { viewModel.toggleFileInclusion(file) }
                        )
                    }
                }
            }
        }
        .navigationTitle("manuscript.body.title")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingPreview = true
                    } label: {
                        Label("manuscript.preview", systemImage: "doc.text.magnifyingglass")
                    }
                    
                    Button {
                        showingExport = true
                    } label: {
                        Label("manuscript.export", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingPreview) {
            ManuscriptPreviewView(project: project)
        }
        .sheet(isPresented: $showingExport) {
            ManuscriptExportSheet(project: project)
        }
        .task {
            await viewModel.loadSections()
        }
    }
}

struct ManuscriptFileRow: View {
    let file: TextFile
    let onToggleInclude: () -> Void
    
    var body: some View {
        HStack {
            Text(file.name ?? "Untitled")
            Spacer()
            Button {
                onToggleInclude()
            } label: {
                Image(systemName: file.includedInManuscript ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(file.includedInManuscript ? .green : .secondary)
            }
            .buttonStyle(.plain)
        }
    }
}
```

---

## 4. Testing Approach

### Unit Tests

```swift
// ManuscriptAssemblyServiceTests.swift

final class ManuscriptAssemblyServiceTests: XCTestCase {
    func testGetSectionsForPoetryProject() async throws {
        // Given: Poetry project with Poems folder containing files
        let project = createPoetryProject()
        let service = ManuscriptAssemblyService(context: context)
        
        // When: Get sections
        let sections = service.getSections(for: project)
        
        // Then: Should have 3 sections
        XCTAssertEqual(sections.count, 3)
        XCTAssertEqual(sections[0].sectionType, .frontMatter)
        XCTAssertEqual(sections[1].sectionType, .body)
        XCTAssertEqual(sections[2].sectionType, .backMatter)
    }
    
    func testAssembleContentPreservesOrder() async throws {
        // Test file order is preserved
    }
    
    func testExcludedFilesNotIncluded() async throws {
        // Test includedInManuscript = false files are excluded
    }
}
```

---

## 5. Key Patterns to Follow

### Navigation (from copilot-instructions.md)

```swift
// For ManuscriptBodyView and other nested views:
struct ManuscriptBodyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        content
            .navigationBarBackButtonHidden(true)
            .onPopToRoot { dismiss() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PopToRootBackButton()
                }
            }
    }
}
```

### Observable (from copilot-instructions.md)

```swift
// ALWAYS use @Observable, never ObservableObject
@Observable
final class ManuscriptBodyViewModel {
    var sections: [ManuscriptSection] = []
    var isLoading = false
    // NO @Published!
}
```

### SwiftData (from copilot-instructions.md)

```swift
// All attributes must have defaults for CloudKit
extension TextFile {
    @Attribute var includedInManuscript: Bool = true  // ✅ Has default
}
```

---

## 6. File Checklist

### Phase 1 Files

- [ ] `Services/ProjectTemplateService.swift` - Add subfolder creation
- [ ] `Services/FolderCapabilityService.swift` - Add folder rules
- [ ] `Views/FolderListView.swift` - Handle Manuscript folder display
- [ ] `Resources/en.lproj/Localizable.strings` - Add folder names

### Phase 2 Files

- [ ] `Models/ManuscriptModels.swift` - New model structs
- [ ] `Services/ManuscriptAssemblyService.swift` - Assembly logic
- [ ] `Tests/ManuscriptAssemblyServiceTests.swift` - Unit tests

### Phase 3 Files

- [ ] `Views/Manuscript/ManuscriptBodyView.swift` - Body content view
- [ ] `Views/Manuscript/ManuscriptFileRow.swift` - File row component

### Phase 4 Files

- [ ] `Views/Manuscript/ManuscriptPreviewView.swift` - Preview wrapper

### Phase 5 Files

- [ ] `Views/Manuscript/ManuscriptExportSheet.swift` - Export options
- [ ] `Services/ManuscriptExportService.swift` - Export logic

### Phase 6 Files

- [ ] Update TextFile model for `includedInManuscript`

### Phase 7 Files

- [ ] `Services/TOCGeneratorService.swift` - TOC generation
- [ ] `Views/Manuscript/TOCSettingsSheet.swift` - TOC options

---

## 7. Quick Commands

```bash
# Run tests
xcodebuild test -scheme WritingShedPro -destination 'platform=iOS Simulator,name=iPhone 15'

# Check for compile errors
xcodebuild build -scheme WritingShedPro

# Format code (if SwiftFormat is installed)
swiftformat .
```

---

## 8. Questions? Check These Files

| Topic | File |
|-------|------|
| Folder capabilities | `Services/FolderCapabilityService.swift` |
| Project creation | `Services/ProjectTemplateService.swift` |
| Pagination | `Services/PaginatedTextLayoutManager.swift` |
| PDF generation | `Services/PrintService.swift` |
| Navigation patterns | `Views/FolderFilesView.swift` |
| Existing specs | `specs/010-pagination/`, `specs/020-printing/` |
