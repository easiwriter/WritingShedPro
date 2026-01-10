# Feature 029: Manuscript Assembly - Implementation Tasks

**Status:** Not Started  
**Estimated Duration:** 14-18 days  
**Start Date:** TBD  
**Completion Date:** TBD  

---

## Overview

This document breaks down the Manuscript Assembly feature into discrete implementation tasks. Tasks are organized by phase and include acceptance criteria, code snippets, and dependencies.

**Reference Documents:**
- [spec.md](spec.md) - Feature specification
- [implementation-plan.md](implementation-plan.md) - Phase overview
- [research.md](research.md) - Technical research
- [data-model.md](data-model.md) - Data models
- [quickstart.md](quickstart.md) - Developer guide

---

## Task Breakdown

### Phase 1: Folder Structure (2-3 days)

#### Task 1.1: Update ProjectTemplateService for Manuscript Subfolders
**Estimated Time:** 2-3 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Modify ProjectTemplateService to create Front Matter, Body, and Back Matter subfolders inside the Manuscript folder for all project types.

**Acceptance Criteria:**
- [ ] Method `createManuscriptSubfolders(in:context:)` added
- [ ] Creates "Front Matter" subfolder with displayOrder 0
- [ ] Creates "Body" subfolder with displayOrder 1
- [ ] Creates "Back Matter" subfolder with displayOrder 2
- [ ] Called from `createProjectFolders()` after Manuscript folder creation
- [ ] Works for all project types (Poetry, Fiction, Drama, General Purpose)
- [ ] Localized folder names used

**File to Modify:** `Services/ProjectTemplateService.swift`

**Code Structure:**
```swift
/// Creates the standard subfolders within the Manuscript folder
/// - Parameters:
///   - manuscriptFolder: The parent Manuscript folder
///   - context: SwiftData model context
private func createManuscriptSubfolders(in manuscriptFolder: Folder, context: ModelContext) {
    let subfolderKeys = ["folder.frontMatter", "folder.body", "folder.backMatter"]
    
    for (index, nameKey) in subfolderKeys.enumerated() {
        let subfolder = Folder(
            name: NSLocalizedString(nameKey, comment: ""),
            displayOrder: Int16(index),
            parentFolder: manuscriptFolder
        )
        subfolder.project = manuscriptFolder.project
        context.insert(subfolder)
    }
}
```

**Dependencies:**
- None (modifying existing service)

---

#### Task 1.2: Update FolderCapabilityService for New Folders
**Estimated Time:** 1-2 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Add the new Manuscript subfolders to appropriate capability sets in FolderCapabilityService.

**Acceptance Criteria:**
- [ ] "Front Matter" added to `fileOnlyFolders` (can add files, no subfolders)
- [ ] "Back Matter" added to `fileOnlyFolders` (can add files, no subfolders)
- [ ] "Body" added to `readOnlyFolders` (virtual view, no manual additions)
- [ ] All capability checks pass for new folders
- [ ] Existing folder capabilities unchanged

**File to Modify:** `Services/FolderCapabilityService.swift`

**Code Changes:**
```swift
/// Folders that can ONLY contain files (no subfolders)
private static let fileOnlyFolders: Set<String> = [
    "Files", "Research",
    "Poems", "Scenes", "Scripts",
    "Front Matter", "Back Matter"  // ADD
]

/// Folders that receive content from elsewhere (no manual additions)
private static let readOnlyFolders: Set<String> = [
    "Collections", "Trash", "Manuscript",
    "Characters", "Locations", "Chapters", "Plot",
    "Body"  // ADD
]
```

**Dependencies:**
- Task 1.1 (folders must exist to test capabilities)

---

#### Task 1.3: Add Localization Strings for Folders
**Estimated Time:** 30 minutes  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Add localization keys for the new folder names.

**Acceptance Criteria:**
- [ ] `folder.frontMatter` key added
- [ ] `folder.body` key added
- [ ] `folder.backMatter` key added
- [ ] English translations provided

**File to Modify:** `Resources/en.lproj/Localizable.strings`

**Strings to Add:**
```
// Manuscript Subfolders
"folder.frontMatter" = "Front Matter";
"folder.body" = "Body";
"folder.backMatter" = "Back Matter";
```

**Dependencies:**
- None

---

#### Task 1.4: Update FolderListView for Manuscript Navigation
**Estimated Time:** 2-3 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Update FolderListView to properly display Manuscript subfolders and navigate to ManuscriptBodyView for the Body folder.

**Acceptance Criteria:**
- [ ] Manuscript folder shows subfolders when tapped
- [ ] Front Matter navigates to FolderFilesView (standard behavior)
- [ ] Body navigates to ManuscriptBodyView (new view)
- [ ] Back Matter navigates to FolderFilesView (standard behavior)
- [ ] Subfolder order: Front Matter, Body, Back Matter
- [ ] Follows existing navigation patterns

**File to Modify:** `Views/FolderListView.swift`

**Code Structure:**
```swift
// In folder navigation destination
NavigationLink(value: folder) {
    // ...
}
.navigationDestination(for: Folder.self) { folder in
    if folder.name == "Body",
       folder.parentFolder?.name == "Manuscript" {
        ManuscriptBodyView(project: project)
    } else {
        FolderFilesView(folder: folder)
    }
}
```

**Dependencies:**
- Task 1.1 (folders must exist)
- Task 3.1 (ManuscriptBodyView must exist - can stub initially)

---

#### Task 1.5: Create Migration for Existing Projects
**Estimated Time:** 2-3 hours  
**Priority:** Medium  
**Status:** ⬜ Not Started

**Description:**  
Create migration logic to add Manuscript subfolders to existing projects that don't have them.

**Acceptance Criteria:**
- [ ] Migration runs on app launch for projects without subfolders
- [ ] Only creates missing subfolders (idempotent)
- [ ] Preserves existing content in Manuscript folder
- [ ] Logs migration activity for debugging
- [ ] Does not block UI (runs on background thread)

**File to Create:** `Services/MigrationService.swift` (or add to existing)

**Code Structure:**
```swift
func migrateManuscriptFolders(for project: Project, context: ModelContext) async {
    guard let manuscriptFolder = project.folders?.first(where: { $0.name == "Manuscript" }) else {
        return
    }
    
    let existingSubfolders = manuscriptFolder.subfolders?.compactMap { $0.name } ?? []
    let requiredSubfolders = ["Front Matter", "Body", "Back Matter"]
    
    for (index, name) in requiredSubfolders.enumerated() where !existingSubfolders.contains(name) {
        let subfolder = Folder(name: name, displayOrder: Int16(index), parentFolder: manuscriptFolder)
        subfolder.project = project
        context.insert(subfolder)
    }
    
    try? context.save()
}
```

**Dependencies:**
- Task 1.1 (template service changes)

---

#### Task 1.6: Write Unit Tests for Folder Structure
**Estimated Time:** 2-3 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Create unit tests for folder structure creation and capabilities.

**Acceptance Criteria:**
- [ ] Test Manuscript subfolders created for new Poetry project
- [ ] Test Manuscript subfolders created for new Fiction project
- [ ] Test Manuscript subfolders created for new Drama project
- [ ] Test Manuscript subfolders created for new General Purpose project
- [ ] Test Front Matter allows file additions
- [ ] Test Back Matter allows file additions
- [ ] Test Body does not allow file additions
- [ ] Test migration creates missing subfolders
- [ ] All tests pass

**File to Modify:** `WritingShedProTests/ProjectTemplateServiceTests.swift`

**Test Cases:**
```swift
func testManuscriptSubfoldersCreatedForPoetry()
func testManuscriptSubfoldersCreatedForFiction()
func testFrontMatterAllowsFiles()
func testBodyDoesNotAllowFiles()
func testMigrationCreatesSubfolders()
```

**Dependencies:**
- Tasks 1.1-1.5

---

### Phase 2: Body Assembly Service (3-4 days)

#### Task 2.1: Create ManuscriptModels.swift
**Estimated Time:** 2-3 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Create the model structs for manuscript assembly as defined in data-model.md.

**Acceptance Criteria:**
- [ ] `ManuscriptSection` struct created with all properties
- [ ] `ManuscriptContent` struct created with all properties
- [ ] `ManuscriptSettings` struct created (Codable)
- [ ] `AssemblyProgress` struct created
- [ ] `AssemblyError` enum created
- [ ] All types conform to required protocols (Identifiable, Equatable, etc.)

**File to Create:** `Models/ManuscriptModels.swift`

**Code Structure:**
```swift
import Foundation

/// Represents a section in the assembled manuscript
struct ManuscriptSection: Identifiable {
    let id: UUID
    let title: String
    let sectionType: SectionType
    let sourceFolder: Folder?
    var files: [TextFile]
    let level: Int
    var startingPage: Int?
    
    enum SectionType: String, CaseIterable {
        case frontMatter, body, backMatter
    }
}

/// Complete assembled manuscript content
struct ManuscriptContent {
    let attributedString: NSAttributedString
    let sections: [ManuscriptSection]
    var pageMap: [UUID: Int]
    let fileOffsets: [UUID: Int]
    var pageCount: Int
}

// ... additional types from data-model.md
```

**Dependencies:**
- None

---

#### Task 2.2: Create ManuscriptAssemblyService
**Estimated Time:** 4-5 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Create the core service that assembles manuscript content from source folders.

**Acceptance Criteria:**
- [ ] Class created as `@Observable` (not ObservableObject)
- [ ] Method `getSections(for:)` returns sections for project
- [ ] Method `getBodySourceFolder(for:)` returns correct folder per project type
- [ ] Method `assembleContent(for:)` returns assembled ManuscriptContent
- [ ] Handles all project types (Poetry, Fiction, Drama, General Purpose)
- [ ] Respects file order (displayOrder)
- [ ] Adds section breaks between files
- [ ] Async/await for non-blocking assembly

**File to Create:** `Services/ManuscriptAssemblyService.swift`

**Code Structure:**
```swift
import Foundation
import SwiftData
import Observation

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
            .fiction: "Scenes",
            .drama: "Scripts",
            .generalPurpose: "Sections"
        ]
        // ...
    }
    
    /// Get all sections for manuscript assembly
    func getSections(for project: Project) -> [ManuscriptSection] {
        // Front Matter + Body + Back Matter
    }
    
    /// Assemble complete manuscript content
    func assembleContent(for project: Project) async throws -> ManuscriptContent {
        // Combine all file contents with section breaks
    }
}
```

**Dependencies:**
- Task 2.1 (ManuscriptModels)

---

#### Task 2.3: Implement Section Break Formatting
**Estimated Time:** 1-2 hours  
**Priority:** Medium  
**Status:** ⬜ Not Started

**Description:**  
Implement the section break formatting based on ManuscriptSettings.

**Acceptance Criteria:**
- [ ] Page break inserts form feed character
- [ ] Section mark inserts "* * *" with spacing
- [ ] Double space inserts blank lines
- [ ] None inserts no break
- [ ] Breaks work correctly in assembled content
- [ ] Settings read from project.manuscriptSettings

**File to Modify:** `Services/ManuscriptAssemblyService.swift`

**Code Structure:**
```swift
private func sectionBreak(for settings: ManuscriptSettings) -> NSAttributedString {
    switch settings.sectionBreakStyle {
    case .pageBreak:
        return NSAttributedString(string: "\u{0C}")
    case .sectionMark:
        return NSAttributedString(string: "\n\n* * *\n\n")
    case .doubleSpace:
        return NSAttributedString(string: "\n\n\n\n")
    case .none:
        return NSAttributedString(string: "")
    }
}
```

**Dependencies:**
- Task 2.2

---

#### Task 2.4: Add Project Extension for Settings
**Estimated Time:** 1-2 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Add the manuscript settings properties to the Project model.

**Acceptance Criteria:**
- [ ] `manuscriptSettingsData: Data?` attribute added
- [ ] `manuscriptSettings` computed property added
- [ ] `tocSettingsData: Data?` attribute added (for Phase 7)
- [ ] `tocSettings` computed property added (for Phase 7)
- [ ] CloudKit compatible (optional with defaults)
- [ ] Encoding/decoding works correctly

**File to Modify:** `Models/Project.swift` (or extension file)

**Code Structure:**
```swift
extension Project {
    @Attribute var manuscriptSettingsData: Data?
    
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

**Dependencies:**
- Task 2.1 (ManuscriptSettings struct)

---

#### Task 2.5: Handle Fiction Project Hierarchy
**Estimated Time:** 2-3 hours  
**Priority:** Medium  
**Status:** ⬜ Not Started

**Description:**  
Fiction projects have Chapters containing Scenes. Assembly must respect this hierarchy.

**Acceptance Criteria:**
- [ ] Chapters folder detected as source for Fiction projects
- [ ] Chapter subfolders processed in order
- [ ] Scenes within each chapter assembled in order
- [ ] Chapter names can be used as section headings
- [ ] Handles projects with no chapters (fallback to Scenes folder)

**File to Modify:** `Services/ManuscriptAssemblyService.swift`

**Code Structure:**
```swift
private func collectFictionBody(for project: Project) -> [ManuscriptSection] {
    var sections: [ManuscriptSection] = []
    
    guard let chaptersFolder = project.folders?.first(where: { $0.name == "Chapters" }) else {
        // Fallback to Scenes folder
        return collectFromFolder(named: "Scenes", project: project)
    }
    
    for chapter in (chaptersFolder.subfolders ?? []).sorted(by: displayOrder) {
        let scenes = chapter.files?.sorted(by: displayOrder) ?? []
        sections.append(ManuscriptSection(
            title: chapter.name ?? "Chapter",
            sectionType: .body,
            sourceFolder: chapter,
            files: scenes.filter { $0.includedInManuscript },
            level: 2
        ))
    }
    
    return sections
}
```

**Dependencies:**
- Task 2.2

---

#### Task 2.6: Write Unit Tests for Assembly Service
**Estimated Time:** 3-4 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Create comprehensive unit tests for the ManuscriptAssemblyService.

**Acceptance Criteria:**
- [ ] Test `getSections` for each project type
- [ ] Test `getBodySourceFolder` returns correct folder
- [ ] Test `assembleContent` combines files correctly
- [ ] Test section breaks inserted between files
- [ ] Test file order preserved
- [ ] Test empty project returns error
- [ ] Test excluded files not included
- [ ] All tests pass

**File to Create:** `WritingShedProTests/ManuscriptAssemblyServiceTests.swift`

**Test Cases:**
```swift
func testGetSectionsForPoetryProject()
func testGetSectionsForFictionProject()
func testGetBodySourceFolderPoetry()
func testGetBodySourceFolderFiction()
func testAssembleContentPreservesOrder()
func testAssembleContentWithSectionBreaks()
func testAssembleContentExcludesExcludedFiles()
func testAssembleContentEmptyProjectThrows()
```

**Dependencies:**
- Tasks 2.1-2.5

---

### Phase 3: Front/Back Matter Management (2 days)

#### Task 3.1: Create ManuscriptBodyView
**Estimated Time:** 3-4 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Create the view that displays the assembled manuscript structure (Body folder view).

**Acceptance Criteria:**
- [ ] Shows list of sections (Front Matter, Body sections, Back Matter)
- [ ] Each section shows list of files
- [ ] Files show include/exclude toggle
- [ ] Preview button in toolbar
- [ ] Export button in toolbar
- [ ] Settings button in toolbar
- [ ] Loading state while assembling
- [ ] Error state if assembly fails
- [ ] Follows navigation patterns (PopToRootBackButton, .onPopToRoot)

**File to Create:** `Views/Manuscript/ManuscriptBodyView.swift`

**Code Structure:**
```swift
import SwiftUI
import SwiftData

struct ManuscriptBodyView: View {
    let project: Project
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ManuscriptBodyViewModel
    
    var body: some View {
        List {
            ForEach(viewModel.sections) { section in
                Section(header: Text(section.title)) {
                    ForEach(section.files) { file in
                        ManuscriptFileRow(file: file, onToggle: { 
                            viewModel.toggleFileInclusion(file)
                        })
                    }
                }
            }
        }
        .navigationTitle("manuscript.body.title")
        .navigationBarBackButtonHidden(true)
        .onPopToRoot { dismiss() }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                PopToRootBackButton()
            }
            ToolbarItem(placement: .primaryAction) {
                manuscriptMenu
            }
        }
    }
}
```

**Dependencies:**
- Task 2.2 (ManuscriptAssemblyService)
- Task 3.2 (ManuscriptBodyViewModel)

---

#### Task 3.2: Create ManuscriptBodyViewModel
**Estimated Time:** 2-3 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Create the view model for ManuscriptBodyView using @Observable pattern.

**Acceptance Criteria:**
- [ ] Uses `@Observable` macro (not ObservableObject)
- [ ] `sections` property contains manuscript sections
- [ ] `isLoading` tracks loading state
- [ ] `error` holds any assembly errors
- [ ] `loadSections()` async method
- [ ] `toggleFileInclusion(_:)` method
- [ ] `assembleManuscript()` async method

**File to Create:** `ViewModels/ManuscriptBodyViewModel.swift`

**Code Structure:**
```swift
import Foundation
import SwiftData
import Observation

@Observable
final class ManuscriptBodyViewModel {
    var sections: [ManuscriptSection] = []
    var isLoading = false
    var error: AssemblyError?
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
        isLoading = true
        sections = assemblyService.getSections(for: project)
        isLoading = false
    }
    
    func toggleFileInclusion(_ file: TextFile) {
        file.includedInManuscript.toggle()
        try? context.save()
    }
}
```

**Dependencies:**
- Task 2.1 (ManuscriptModels)
- Task 2.2 (ManuscriptAssemblyService)

---

#### Task 3.3: Create ManuscriptFileRow Component
**Estimated Time:** 1 hour  
**Priority:** Medium  
**Status:** ⬜ Not Started

**Description:**  
Create the reusable row component for files in the manuscript list.

**Acceptance Criteria:**
- [ ] Shows file name
- [ ] Shows include/exclude toggle button
- [ ] Green checkmark when included
- [ ] Gray circle when excluded
- [ ] Tapping toggle calls callback
- [ ] Accessible labels

**File to Create:** `Views/Manuscript/ManuscriptFileRow.swift`

**Code Structure:**
```swift
import SwiftUI

struct ManuscriptFileRow: View {
    let file: TextFile
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            Text(file.name ?? "Untitled")
            Spacer()
            Button(action: onToggle) {
                Image(systemName: file.includedInManuscript ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(file.includedInManuscript ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(file.includedInManuscript ? 
                "manuscript.file.included" : "manuscript.file.excluded")
        }
    }
}
```

**Dependencies:**
- Task 6.1 (TextFile.includedInManuscript property)

---

#### Task 3.4: Add Manuscript Localization Strings
**Estimated Time:** 30 minutes  
**Priority:** Medium  
**Status:** ⬜ Not Started

**Description:**  
Add all localization strings for manuscript UI.

**File to Modify:** `Resources/en.lproj/Localizable.strings`

**Strings to Add:**
```
// Manuscript UI
"manuscript.body.title" = "Manuscript";
"manuscript.preview" = "Preview";
"manuscript.export" = "Export";
"manuscript.settings" = "Settings";
"manuscript.file.included" = "Included in manuscript";
"manuscript.file.excluded" = "Excluded from manuscript";

// Section Types
"manuscript.section.frontMatter" = "Front Matter";
"manuscript.section.body" = "Body";
"manuscript.section.backMatter" = "Back Matter";

// Settings
"manuscript.break.pageBreak" = "Page Break";
"manuscript.break.sectionMark" = "Section Mark";
"manuscript.break.doubleSpace" = "Double Space";
"manuscript.break.none" = "None";

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
```

**Dependencies:**
- None

---

### Phase 4: Preview & Print (2-3 days)

#### Task 4.1: Create ManuscriptPreviewView
**Estimated Time:** 3-4 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Create the preview view that shows the assembled manuscript with pagination.

**Acceptance Criteria:**
- [ ] Assembles manuscript content on appear
- [ ] Uses existing PaginatedDocumentView infrastructure
- [ ] Shows page count and current page
- [ ] Zoom controls work
- [ ] Print button works
- [ ] Loading indicator during assembly
- [ ] Error state if no page setup

**File to Create:** `Views/Manuscript/ManuscriptPreviewView.swift`

**Code Structure:**
```swift
import SwiftUI
import SwiftData

struct ManuscriptPreviewView: View {
    let project: Project
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var content: ManuscriptContent?
    @State private var isLoading = true
    @State private var error: AssemblyError?
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("manuscript.progress.assembling")
                } else if let error {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error.localizedDescription)
                    }
                } else if let content {
                    ManuscriptPaginatedView(
                        content: content,
                        pageSetup: project.pageSetup,
                        project: project
                    )
                }
            }
            .navigationTitle("manuscript.preview")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
        .task {
            await loadPreview()
        }
    }
    
    private func loadPreview() async {
        // Use ManuscriptAssemblyService to assemble content
    }
}
```

**Dependencies:**
- Task 2.2 (ManuscriptAssemblyService)
- Existing PaginatedDocumentView components

---

#### Task 4.2: Create ManuscriptPaginatedView
**Estimated Time:** 3-4 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Adapt the existing pagination infrastructure for assembled manuscript content.

**Acceptance Criteria:**
- [ ] Accepts ManuscriptContent instead of single file
- [ ] Uses PaginatedTextLayoutManager for layout
- [ ] Virtual scrolling for large manuscripts
- [ ] Zoom controls (25%-200%)
- [ ] Page navigation
- [ ] Print integration

**File to Create:** `Views/Manuscript/ManuscriptPaginatedView.swift`

**Code Structure:**
```swift
import SwiftUI

struct ManuscriptPaginatedView: View {
    let content: ManuscriptContent
    let pageSetup: PageSetup?
    let project: Project
    
    @State private var layoutManager: PaginatedTextLayoutManager?
    @State private var currentPage = 1
    @State private var zoomLevel: CGFloat = 1.0
    
    var body: some View {
        // Similar to PaginatedDocumentView but for assembled content
        VStack {
            zoomControls
            pageView
            pageNavigator
        }
        .onAppear {
            setupLayoutManager()
        }
    }
    
    private func setupLayoutManager() {
        guard let pageSetup else { return }
        let textStorage = NSTextStorage(attributedString: content.attributedString)
        layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        let _ = layoutManager?.calculateLayout()
    }
}
```

**Dependencies:**
- Task 4.1
- Existing PaginatedTextLayoutManager

---

#### Task 4.3: Integrate Print Functionality
**Estimated Time:** 2-3 hours  
**Priority:** Medium  
**Status:** ⬜ Not Started

**Description:**  
Connect manuscript preview to existing PrintService for printing.

**Acceptance Criteria:**
- [ ] Print button shows print dialog
- [ ] Uses CustomPDFPageRenderer for correct layout
- [ ] Respects page setup settings
- [ ] Works on iOS and Mac Catalyst

**File to Modify:** `Views/Manuscript/ManuscriptPaginatedView.swift`

**Code Structure:**
```swift
private func printManuscript() {
    guard let pageSetup = project.pageSetup,
          let layoutManager else { return }
    
    PrintService.presentPrintDialog(
        content: content.attributedString,
        pageSetup: pageSetup,
        title: project.name ?? "Manuscript",
        version: nil,
        project: project,
        context: context
    )
}
```

**Dependencies:**
- Task 4.2
- Existing PrintService

---

#### Task 4.4: Add Page Number Display
**Estimated Time:** 1-2 hours  
**Priority:** Medium  
**Status:** ⬜ Not Started

**Description:**  
Show current page and total pages in the preview UI.

**Acceptance Criteria:**
- [ ] "Page X of Y" display
- [ ] Updates as user scrolls
- [ ] Tap to jump to specific page
- [ ] Localized format

**File to Modify:** `Views/Manuscript/ManuscriptPaginatedView.swift`

**Dependencies:**
- Task 4.2

---

### Phase 5: Export (2-3 days)

#### Task 5.1: Create ManuscriptExportSheet
**Estimated Time:** 2-3 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Create the export options sheet for manuscript export.

**Acceptance Criteria:**
- [ ] Format picker (PDF, RTF, Plain Text, Word)
- [ ] Include Front Matter toggle
- [ ] Include Body toggle
- [ ] Include Back Matter toggle
- [ ] Include TOC toggle (if configured)
- [ ] Filename field
- [ ] Export button
- [ ] Progress indicator during export
- [ ] Error handling

**File to Create:** `Views/Manuscript/ManuscriptExportSheet.swift`

**Code Structure:**
```swift
import SwiftUI

struct ManuscriptExportSheet: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @State private var options = ExportOptions()
    @State private var isExporting = false
    @State private var error: AssemblyError?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("export.format") {
                    Picker("export.format", selection: $options.format) {
                        ForEach(ExportFormat.allCases) { format in
                            Label(format.localizedName, systemImage: format.icon)
                                .tag(format)
                        }
                    }
                }
                
                Section("export.include") {
                    Toggle("manuscript.section.frontMatter", isOn: $options.includeFrontMatter)
                    Toggle("manuscript.section.body", isOn: $options.includeBody)
                    Toggle("manuscript.section.backMatter", isOn: $options.includeBackMatter)
                    Toggle("export.includeTOC", isOn: $options.includeTableOfContents)
                }
                
                Section("export.filename") {
                    TextField("export.filename", text: $options.filename)
                }
            }
            .navigationTitle("manuscript.export")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("export.export") { 
                        Task { await exportManuscript() }
                    }
                    .disabled(isExporting)
                }
            }
        }
    }
}
```

**Dependencies:**
- Task 2.1 (ExportOptions, ExportFormat)
- Task 5.2 (ManuscriptExportService)

---

#### Task 5.2: Create ManuscriptExportService
**Estimated Time:** 4-5 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Create the service that handles export to various formats.

**Acceptance Criteria:**
- [ ] `export(content:project:options:)` main method
- [ ] `exportToPDF()` uses existing PrintService
- [ ] `exportToRTF()` generates RTF data
- [ ] `exportToPlainText()` strips formatting
- [ ] `exportToWord()` generates DOCX
- [ ] Async/await for non-blocking export
- [ ] Progress reporting

**File to Create:** `Services/ManuscriptExportService.swift`

**Code Structure:**
```swift
import Foundation
import SwiftData

final class ManuscriptExportService {
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    func export(
        content: ManuscriptContent,
        project: Project,
        options: ExportOptions
    ) async throws -> Data {
        switch options.format {
        case .pdf:
            return try await exportToPDF(content: content, project: project, options: options)
        case .rtf:
            return try await exportToRTF(content: content, options: options)
        case .plainText:
            return try await exportToPlainText(content: content, options: options)
        case .word:
            return try await exportToWord(content: content, options: options)
        }
    }
    
    private func exportToPDF(
        content: ManuscriptContent,
        project: Project,
        options: ExportOptions
    ) async throws -> Data {
        guard let pageSetup = project.pageSetup else {
            throw AssemblyError.noPageSetup
        }
        
        guard let data = PrintService.generatePDF(
            from: content.attributedString,
            pageSetup: pageSetup,
            title: options.filename,
            project: project,
            context: context
        ) else {
            throw AssemblyError.exportFailed("PDF")
        }
        
        return data
    }
    
    // ... other export methods
}
```

**Dependencies:**
- Task 2.2 (ManuscriptAssemblyService)
- Existing PrintService, RTFService, WordDocumentService

---

#### Task 5.3: Implement Share Sheet Integration
**Estimated Time:** 1-2 hours  
**Priority:** Medium  
**Status:** ⬜ Not Started

**Description:**  
Connect export to iOS share sheet for saving/sharing files.

**Acceptance Criteria:**
- [ ] Export data passed to UIActivityViewController
- [ ] Correct MIME type set for each format
- [ ] Filename includes extension
- [ ] Works on iOS and Mac Catalyst

**File to Modify:** `Views/Manuscript/ManuscriptExportSheet.swift`

**Code Structure:**
```swift
private func shareExportedFile(_ data: Data, format: ExportFormat, filename: String) {
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(filename)
        .appendingPathExtension(format.fileExtension)
    
    try? data.write(to: tempURL)
    
    let activityVC = UIActivityViewController(
        activityItems: [tempURL],
        applicationActivities: nil
    )
    
    // Present activity view controller
}
```

**Dependencies:**
- Task 5.2

---

#### Task 5.4: Add Export Localization Strings
**Estimated Time:** 30 minutes  
**Priority:** Low  
**Status:** ⬜ Not Started

**Description:**  
Add localization strings for export UI.

**File to Modify:** `Resources/en.lproj/Localizable.strings`

**Strings to Add:**
```
// Export
"export.format" = "Format";
"export.include" = "Include";
"export.filename" = "Filename";
"export.export" = "Export";
"export.includeTOC" = "Include Table of Contents";
"export.format.pdf" = "PDF Document";
"export.format.rtf" = "Rich Text Format";
"export.format.plainText" = "Plain Text";
"export.format.word" = "Word Document";
```

**Dependencies:**
- None

---

### Phase 6: Include/Exclude Toggle (1 day)

#### Task 6.1: Add includedInManuscript to TextFile
**Estimated Time:** 1 hour  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Add the `includedInManuscript` property to the TextFile model.

**Acceptance Criteria:**
- [ ] Property added with default `true`
- [ ] CloudKit compatible (has default value)
- [ ] SwiftData migration handles existing files

**File to Modify:** `Models/TextFile.swift`

**Code Changes:**
```swift
@Model
final class TextFile {
    // ... existing properties
    
    /// Whether this file is included in manuscript assembly
    @Attribute var includedInManuscript: Bool = true
}
```

**Dependencies:**
- None

---

#### Task 6.2: Update ManuscriptAssemblyService to Filter Files
**Estimated Time:** 30 minutes  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Update assembly service to respect the includedInManuscript flag.

**Acceptance Criteria:**
- [ ] Excluded files not included in sections
- [ ] Excluded files not included in assembled content
- [ ] Filter applied at collection time

**File to Modify:** `Services/ManuscriptAssemblyService.swift`

**Code Changes:**
```swift
// When collecting files
let files = folder.files?
    .filter { $0.includedInManuscript }
    .sorted(by: { ($0.displayOrder ?? 0) < ($1.displayOrder ?? 0) }) ?? []
```

**Dependencies:**
- Task 6.1

---

#### Task 6.3: Test Include/Exclude Functionality
**Estimated Time:** 1-2 hours  
**Priority:** Medium  
**Status:** ⬜ Not Started

**Description:**  
Write tests for the include/exclude functionality.

**Acceptance Criteria:**
- [ ] Test excluded files not in sections
- [ ] Test excluded files not in assembled content
- [ ] Test toggle works correctly
- [ ] Test default value is true

**File to Modify:** `WritingShedProTests/ManuscriptAssemblyServiceTests.swift`

**Test Cases:**
```swift
func testExcludedFilesNotInSections()
func testExcludedFilesNotInAssembledContent()
func testToggleInclusionWorks()
func testNewFilesIncludedByDefault()
```

**Dependencies:**
- Tasks 6.1, 6.2

---

### Phase 7: Table of Contents (2-3 days)

#### Task 7.1: Create TOCModels.swift
**Estimated Time:** 1 hour  
**Priority:** Medium  
**Status:** ⬜ Not Started

**Description:**  
Create the TOC-related model structs.

**Acceptance Criteria:**
- [ ] `TOCEntry` struct created
- [ ] `TableOfContents` struct created
- [ ] `TOCSettings` struct created (Codable)

**File to Create:** `Models/TOCModels.swift`

**Code Structure:**
```swift
import Foundation

/// Entry in the Table of Contents
struct TOCEntry: Identifiable {
    let id: UUID
    let title: String
    let pageNumber: Int
    let level: Int
    let fileID: UUID?
    let sectionID: UUID?
}

/// Complete Table of Contents
struct TableOfContents {
    let entries: [TOCEntry]
    let attributedString: NSAttributedString
    let estimatedPageCount: Int
    let settings: TOCSettings
}

/// TOC configuration
struct TOCSettings: Codable, Equatable {
    var includeTOC: Bool = true
    var showPageNumbers: Bool = true
    var indentSubsections: Bool = true
    var tocTitle: String = "Contents"
    var maxLevel: Int = 2
    var useDotLeaders: Bool = true
}
```

**Dependencies:**
- None

---

#### Task 7.2: Create TOCGeneratorService
**Estimated Time:** 3-4 hours  
**Priority:** Medium  
**Status:** ⬜ Not Started

**Description:**  
Create the service that generates Table of Contents.

**Acceptance Criteria:**
- [ ] `generateEntries()` creates TOCEntry array from sections
- [ ] `formatTOC()` creates formatted attributed string
- [ ] Respects TOCSettings for formatting
- [ ] Dot leaders between title and page number
- [ ] Proper indentation for levels
- [ ] Page numbers aligned right

**File to Create:** `Services/TOCGeneratorService.swift`

**Code Structure:**
```swift
import Foundation
import UIKit

final class TOCGeneratorService {
    
    func generateEntries(
        from sections: [ManuscriptSection],
        pageMap: [UUID: Int],
        settings: TOCSettings
    ) -> [TOCEntry] {
        var entries: [TOCEntry] = []
        
        for section in sections {
            // Add section as level 1 entry
            entries.append(TOCEntry(
                title: section.title,
                pageNumber: section.startingPage ?? 1,
                level: 1,
                sectionID: section.id
            ))
            
            // Add files as level 2 entries
            if settings.maxLevel >= 2 {
                for file in section.files {
                    let page = pageMap[file.id] ?? 1
                    entries.append(TOCEntry(
                        title: file.name ?? "Untitled",
                        pageNumber: page,
                        level: 2,
                        fileID: file.id
                    ))
                }
            }
        }
        
        return entries
    }
    
    func formatTOC(
        entries: [TOCEntry],
        settings: TOCSettings
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        // Add title
        result.append(formatTitle(settings.tocTitle))
        
        // Add entries
        for entry in entries {
            result.append(formatEntry(entry, settings: settings))
        }
        
        return result
    }
    
    private func formatEntry(_ entry: TOCEntry, settings: TOCSettings) -> NSAttributedString {
        // Format with indentation, dot leaders, and page number
    }
}
```

**Dependencies:**
- Task 7.1

---

#### Task 7.3: Integrate TOC into Assembly
**Estimated Time:** 2-3 hours  
**Priority:** Medium  
**Status:** ⬜ Not Started

**Description:**  
Integrate TOC generation into the manuscript assembly process.

**Acceptance Criteria:**
- [ ] TOC generated after body layout calculated
- [ ] TOC page count estimated
- [ ] Body/back matter page numbers offset by TOC pages
- [ ] TOC inserted at start of Front Matter
- [ ] Two-pass calculation for accurate page numbers

**File to Modify:** `Services/ManuscriptAssemblyService.swift`

**Code Structure:**
```swift
func assembleContentWithTOC(for project: Project) async throws -> ManuscriptContent {
    // Phase 1: Assemble without TOC
    var content = try await assembleContent(for: project)
    
    // Phase 2: Calculate layout to get page numbers
    content = calculateLayout(for: content, pageSetup: project.pageSetup)
    
    // Phase 3: Generate TOC
    let tocService = TOCGeneratorService()
    let entries = tocService.generateEntries(
        from: content.sections,
        pageMap: content.pageMap,
        settings: project.tocSettings
    )
    let tocContent = tocService.formatTOC(entries: entries, settings: project.tocSettings)
    
    // Phase 4: Insert TOC and recalculate
    let assembledWithTOC = NSMutableAttributedString()
    assembledWithTOC.append(tocContent)
    assembledWithTOC.append(content.attributedString)
    
    // Phase 5: Update page map with TOC offset
    // ...
    
    return ManuscriptContent(
        attributedString: assembledWithTOC,
        sections: content.sections,
        pageMap: offsetPageMap,
        fileOffsets: offsetFileOffsets,
        pageCount: newPageCount
    )
}
```

**Dependencies:**
- Task 7.2
- Task 4.2 (layout calculation)

---

#### Task 7.4: Create TOCSettingsSheet
**Estimated Time:** 2-3 hours  
**Priority:** Low  
**Status:** ⬜ Not Started

**Description:**  
Create the settings sheet for TOC configuration.

**Acceptance Criteria:**
- [ ] Toggle for include TOC
- [ ] Toggle for show page numbers
- [ ] Toggle for indent subsections
- [ ] Text field for TOC title
- [ ] Picker for max level (1-3)
- [ ] Toggle for dot leaders
- [ ] Preview of TOC format

**File to Create:** `Views/Manuscript/TOCSettingsSheet.swift`

**Code Structure:**
```swift
import SwiftUI

struct TOCSettingsSheet: View {
    @Binding var settings: TOCSettings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("toc.include", isOn: $settings.includeTOC)
                }
                
                if settings.includeTOC {
                    Section("toc.format") {
                        TextField("toc.title", text: $settings.tocTitle)
                        Toggle("toc.showPageNumbers", isOn: $settings.showPageNumbers)
                        Toggle("toc.indentSubsections", isOn: $settings.indentSubsections)
                        Toggle("toc.dotLeaders", isOn: $settings.useDotLeaders)
                        
                        Stepper("toc.maxLevel: \(settings.maxLevel)", 
                                value: $settings.maxLevel, in: 1...3)
                    }
                }
            }
            .navigationTitle("toc.settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }
}
```

**Dependencies:**
- Task 7.1

---

#### Task 7.5: Add TOC Localization Strings
**Estimated Time:** 30 minutes  
**Priority:** Low  
**Status:** ⬜ Not Started

**Description:**  
Add localization strings for TOC UI.

**File to Modify:** `Resources/en.lproj/Localizable.strings`

**Strings to Add:**
```
// Table of Contents
"toc.settings" = "Table of Contents";
"toc.include" = "Include Table of Contents";
"toc.format" = "Format";
"toc.title" = "Title";
"toc.showPageNumbers" = "Show Page Numbers";
"toc.indentSubsections" = "Indent Subsections";
"toc.dotLeaders" = "Use Dot Leaders";
"toc.maxLevel" = "Maximum Level";
```

**Dependencies:**
- None

---

#### Task 7.6: Write Unit Tests for TOC Generation
**Estimated Time:** 2-3 hours  
**Priority:** Medium  
**Status:** ⬜ Not Started

**Description:**  
Create tests for TOC generation.

**Acceptance Criteria:**
- [ ] Test entries generated from sections
- [ ] Test page numbers correct
- [ ] Test level hierarchy correct
- [ ] Test formatting with dot leaders
- [ ] Test settings respected

**File to Create:** `WritingShedProTests/TOCGeneratorServiceTests.swift`

**Test Cases:**
```swift
func testGenerateEntriesFromSections()
func testEntriesHaveCorrectPageNumbers()
func testEntriesHaveCorrectLevels()
func testFormatWithDotLeaders()
func testFormatWithoutDotLeaders()
func testMaxLevelRespected()
```

**Dependencies:**
- Tasks 7.1, 7.2

---

## Summary

### Phase Breakdown

| Phase | Tasks | Estimated Days |
|-------|-------|----------------|
| Phase 1: Folder Structure | 6 tasks | 2-3 days |
| Phase 2: Body Assembly | 6 tasks | 3-4 days |
| Phase 3: Front/Back Matter | 4 tasks | 2 days |
| Phase 4: Preview & Print | 4 tasks | 2-3 days |
| Phase 5: Export | 4 tasks | 2-3 days |
| Phase 6: Include/Exclude | 3 tasks | 1 day |
| Phase 7: TOC Generation | 6 tasks | 2-3 days |
| **Total** | **33 tasks** | **14-18 days** |

### Priority Tasks (Must Complete First)

1. Task 1.1: Update ProjectTemplateService
2. Task 1.2: Update FolderCapabilityService
3. Task 2.1: Create ManuscriptModels
4. Task 2.2: Create ManuscriptAssemblyService
5. Task 3.1: Create ManuscriptBodyView
6. Task 6.1: Add includedInManuscript to TextFile

### Files to Create

- `Models/ManuscriptModels.swift`
- `Models/TOCModels.swift`
- `Services/ManuscriptAssemblyService.swift`
- `Services/ManuscriptExportService.swift`
- `Services/TOCGeneratorService.swift`
- `Services/MigrationService.swift`
- `Views/Manuscript/ManuscriptBodyView.swift`
- `Views/Manuscript/ManuscriptFileRow.swift`
- `Views/Manuscript/ManuscriptPreviewView.swift`
- `Views/Manuscript/ManuscriptPaginatedView.swift`
- `Views/Manuscript/ManuscriptExportSheet.swift`
- `Views/Manuscript/TOCSettingsSheet.swift`
- `ViewModels/ManuscriptBodyViewModel.swift`
- `WritingShedProTests/ManuscriptAssemblyServiceTests.swift`
- `WritingShedProTests/TOCGeneratorServiceTests.swift`

### Files to Modify

- `Services/ProjectTemplateService.swift`
- `Services/FolderCapabilityService.swift`
- `Views/FolderListView.swift`
- `Models/TextFile.swift`
- `Models/Project.swift`
- `Resources/en.lproj/Localizable.strings`
- `WritingShedProTests/ProjectTemplateServiceTests.swift`
