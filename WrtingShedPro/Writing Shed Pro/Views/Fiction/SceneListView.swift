//
//  SceneListView.swift
//  Writing Shed Pro
//
//  Feature 022: Smart Fiction Creation - Scene management
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// List view showing scenes - either for entire project (Short Fiction) or within a chapter (Novel)
/// Matches FileListView pattern with:
/// - Edit mode with selection circles
/// - Bottom toolbar for multi-select actions
/// - Confirmation dialog with Delete (to trash) and Delete Forever options
struct SceneListView: View {

    static func sceneFolderName(for project: Project) -> String {
        if project.type == .fiction && project.fictionClass == .verseNovel {
            return "Episodes"
        }
        return "Scenes"
    }
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Properties
    
    let project: Project
    
    /// Optional chapter - if provided, shows scenes for that chapter only (Novel/Short Fiction mode)
    let chapter: Chapter?
    
    /// Optional act - if provided, shows scenes for that act only (Drama mode)
    let act: Act?
    
    /// Optional book - if provided, shows scenes (episodes) for that book only (Verse Novel mode)
    let book: Book?
    
    // MARK: - State
    
    @State private var showAddScene = false
    
    /// Scene to navigate to for editing
    @State private var navigateToScene: StoryScene?
    
    /// Edit mode binding
    @State private var editMode: EditMode = .inactive
    
    /// Selected scene IDs for multi-select
    @State private var selectedSceneIDs: Set<UUID> = []
    
    /// Delete confirmation dialog
    @State private var showDeleteConfirmation = false
    @State private var scenesToDelete: [StoryScene] = []

    /// Destructive action error state
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""
    
    /// Show multi-file search view
    @State private var showSearchView = false
    
    /// Show import picker
    @State private var showImportPicker = false
    
    /// Show header/footer editor
    @State private var showHeaderFooterEditor = false
    
    /// Show act picker for assigning scenes to acts (Drama only)
    @State private var showActPicker = false
    
    /// Show chapter picker for assigning scenes to chapters/stories (Fiction only)
    @State private var showChapterPicker = false
    
    /// Show container assignment dialog
    /// Uses sheet(item:) pattern to atomically provide data + trigger presentation.
    @State private var containerAssignmentItem: ContainerAssignmentItem?
    
    /// Identifiable wrapper for sheet(item:) — avoids timing issues with separate
    /// isPresented bool + data array that can cause intermittent empty sheets.
    struct ContainerAssignmentItem: Identifiable {
        let id = UUID()
        let scenes: [StoryScene]
    }

    /// Show workflow status picker
    @State private var showStatusPicker = false

    /// Workflow status filter (nil = show all)
    @State private var statusFilter: WorkflowStatus? = nil
    
    /// Header/footer editor fields
    @State private var headerLeft: String = ""
    @State private var headerCenter: String = ""
    @State private var headerRight: String = ""
    @State private var footerLeft: String = ""
    @State private var footerCenter: String = ""
    @State private var footerRight: String = ""
    @State private var headerInsertTarget: HeaderFooterField = .left
    @State private var footerInsertTarget: HeaderFooterField = .left
    @State private var showHeaderFooterWarning = false
    
    /// Scene details state — uses sheet(item:) to avoid timing issues/blank sheets
    @State private var sceneForDetails: StoryScene?
    
    /// Export state
    @State private var showExportMenu = false
    @State private var filesToExport: [TextFile] = []
    @State private var exportFormat: ExportFormat = .rtf
    @State private var showExportSaveDialog = false
    @State private var exportData: Data?
    @State private var exportFilename: String = ""
    @State private var saveAsRequested = false
    @State private var showExportImageWarning = false
    @State private var pendingExportAction: (() -> Void)?
    @State private var shareableFileURL: URL?
    @State private var showShareSheet = false
    
    /// IAP gating
    @State private var upgradePromptReason: UpgradePromptReason?
    
    /// Copy to Project state
    @State private var showCopyToProject = false
    @State private var showCopyResult = false
    @State private var copyResultMessage = ""
    @State private var copyResultIsError = false
    
    /// Submission state
    @State private var showSubmissionNamePrompt = false
    @State private var newSubmissionName: String = ""
    @State private var showSubmissionCreated = false
    @State private var createdSubmissionName: String = ""
    @State private var showDuplicateSubmission = false
    
    /// Poetry form change state (verse novel episodes)
    @State private var sceneForFormChange: TextFile?
    
    /// Chapter grouping: tracks which chapter sections are expanded
    @State private var chapterExpandedSections: Set<String> = []
    
    /// Act grouping: tracks which act sections are expanded (Drama only)
    @State private var actExpandedSections: Set<String> = []
    
    // MARK: - Init
    
    init(project: Project, chapter: Chapter? = nil, act: Act? = nil, book: Book? = nil) {
        self.project = project
        self.chapter = chapter
        self.act = act
        self.book = book
    }
    
    // MARK: - Computed
    
    private var sortedScenes: [StoryScene] {
        let scenes: [StoryScene]
        
        if let chapter = chapter {
            // Fiction mode: scenes within a specific chapter/story
            scenes = chapter.scenes ?? []
        } else if let act = act {
            // Drama mode: scenes within a specific act
            scenes = act.scenes ?? []
        } else if let book = book {
            // Verse Novel mode: episodes within a specific book
            scenes = book.scenes ?? []
        } else {
            // Standalone mode: all scenes at project level
            scenes = project.scenes ?? []
        }
        
        // Filter out trashed scenes and scenes whose backing file is no longer live
        var result = scenes.filter(isLiveScene)
        
        // Sort by userOrder for drag-to-reorder, with name as secondary sort
        result = result.sorted {
            let order0 = $0.userOrder ?? Int.max
            let order1 = $1.userOrder ?? Int.max
            if order0 != order1 {
                return order0 < order1
            }
            return ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending
        }
        
        // Apply workflow status filter if set
        if let filter = statusFilter {
            result = result.filter { $0.textFile?.workflowStatus == filter }
        }
        
        return result
    }
    
    /// All scenes (unfiltered) for counting purposes
    private var allScenes: [StoryScene] {
        let scenes: [StoryScene]
        
        if let chapter = chapter {
            scenes = chapter.scenes ?? []
        } else if let act = act {
            scenes = act.scenes ?? []
        } else if let book = book {
            scenes = book.scenes ?? []
        } else {
            scenes = project.scenes ?? []
        }
        
        return scenes.filter(isLiveScene)
    }

    private func isLiveScene(_ scene: StoryScene) -> Bool {
        !scene.isTrashed && scene.textFile?.parentFolder != nil
    }
    
    /// Count scenes by workflow status
    private func sceneCount(for status: WorkflowStatus?) -> Int {
        if let status = status {
            return allScenes.filter { $0.textFile?.workflowStatus == status }.count
        }
        return allScenes.count
    }
    
    private var title: String {
        if let chapter = chapter {
            return chapter.name ?? fictionClass.sceneDisplayName
        }
        if let act = act {
            return act.name ?? NSLocalizedString("fiction.scenes.title", comment: "Scenes")
        }
        if let book = book {
            return book.name ?? NSLocalizedString("fiction.book", comment: "Book")
        }
        return fictionClass.sceneDisplayName
    }
    
    /// The fiction class for this project (for verse novel episode labeling)
    private var fictionClass: FictionClass {
        project.fictionClass ?? .novel
    }
    
    /// Whether this is a verse novel project
    private var isVerseNovel: Bool {
        fictionClass == .verseNovel
    }
    
    /// Whether edit mode is currently active
    private var isEditMode: Bool {
        editMode == .active
    }
    
    /// Selected scenes based on selectedSceneIDs
    private var selectedScenes: [StoryScene] {
        sortedScenes.filter { selectedSceneIDs.contains($0.id) }
    }
    
    /// Whether bottom toolbar should show
    private var showToolbar: Bool {
        isEditMode && !selectedSceneIDs.isEmpty
    }
    
    /// Whether headers or footers are enabled
    private var headersOrFootersEnabled: Bool {
        guard let pageSetup = project.pageSetup else { return false }
        return pageSetup.hasHeaders || pageSetup.hasFooters
    }

    /// Source folder name for scene/episode files.
    private var scenesFolderName: String {
        Self.sceneFolderName(for: project)
    }
    
    /// Get the scenes folder at project level
    private var scenesFolder: Folder? {
        project.folders?.first { $0.name == scenesFolderName }
    }
    
    /// Get scene files for search
    private var sceneFiles: [TextFile] {
        sortedScenes.compactMap { $0.textFile }
    }
    
    /// Whether chapter grouping should be used (only when viewing all scenes at project level)
    private var useChapterGrouping: Bool {
        chapter == nil && act == nil && book == nil && chapterGroups != nil
    }
    
    /// Whether act grouping should be used (Drama projects, viewing all scenes at project level)
    private var useActGrouping: Bool {
        chapter == nil && act == nil && book == nil && actGroups != nil
    }
    
    /// Groups scenes by their parent chapter/story/book for disclosure section display
    /// Returns nil when there are no chapters or when viewing a specific chapter's scenes
    private var chapterGroups: [SceneChapterGroup]? {
        // Only group when viewing all scenes (no chapter/act/book filter)
        guard chapter == nil && act == nil && book == nil else { return nil }

        if isVerseNovel {
            return verseNovelChapterGroups()
        }

        let chapters = project.chapters ?? []
        guard !chapters.isEmpty else { return nil }
        let visibleScenes = sortedScenes
        let sortedChapters: [Chapter] = sortChapters(chapters)
        let groups: [SceneChapterGroup] = buildChapterGroups(from: sortedChapters, scenes: visibleScenes)
        
        var finalGroups = groups
        addUnassignedChapterScenes(to: &finalGroups, scenes: visibleScenes)
        
        return finalGroups.isEmpty ? nil : finalGroups
    }
    
    /// Helper: Sort chapters by userOrder then name
    private func sortChapters(_ chapters: [Chapter]) -> [Chapter] {
        chapters.sorted(by: ContainerDisplayOrder.isOrdered)
    }
    
    /// Helper: Build groups for chapters with their scenes
    private func buildChapterGroups(from chapters: [Chapter], scenes: [StoryScene]) -> [SceneChapterGroup] {
        var groups: [SceneChapterGroup] = []
        
        for chapter in chapters {
            let chapterScenes = scenes.filter { $0.chapter?.id == chapter.id }
            guard !chapterScenes.isEmpty else { continue }

            groups.append(SceneChapterGroup(
                id: chapter.id.uuidString,
                name: chapter.name ?? fictionClass.chapterSingularName,
                scenes: chapterScenes
            ))
        }
        
        return groups
    }
    
    /// Helper: Add unassigned scenes to groups
    private func addUnassignedChapterScenes(to groups: inout [SceneChapterGroup], scenes: [StoryScene]) {
        let assignedSceneIDs: Set<UUID> = Set(groups.flatMap { $0.scenes.map { $0.id } })
        let unassignedScenes: [StoryScene] = scenes.filter { scene in
            !assignedSceneIDs.contains(scene.id)
        }
        
        if !unassignedScenes.isEmpty {
            let unassignedKey: String = isVerseNovel ? "fiction.episodes.unassigned" : "fiction.scenes.unassigned"
            groups.append(SceneChapterGroup(
                id: "__unassigned__",
                name: NSLocalizedString(unassignedKey, comment: "Unassigned"),
                scenes: unassignedScenes
            ))
        }
    }
    
    /// Groups scenes by their parent act for disclosure section display (Drama projects)
    /// Returns nil when there are no acts or when viewing a specific act's scenes
    private var actGroups: [SceneActGroup]? {
        // Only group when viewing all scenes (no chapter/act/book filter) and project is Drama
        guard chapter == nil && act == nil && book == nil else { return nil }
        guard project.type == .drama else { return nil }
        
        let acts = project.acts ?? []
        guard !acts.isEmpty else { return nil }
        let visibleScenes = sortedScenes
        let sortedActs: [Act] = sortActs(acts)
        let groups: [SceneActGroup] = buildActGroups(from: sortedActs, scenes: visibleScenes)
        
        var finalGroups = groups
        addUnassignedActScenes(to: &finalGroups, scenes: visibleScenes)
        
        return finalGroups.isEmpty ? nil : finalGroups
    }
    
    /// Helper: Sort acts by userOrder then name
    private func sortActs(_ acts: [Act]) -> [Act] {
        acts.sorted(by: ContainerDisplayOrder.isOrdered)
    }
    
    /// Helper: Build groups for acts with their scenes
    private func buildActGroups(from acts: [Act], scenes: [StoryScene]) -> [SceneActGroup] {
        var groups: [SceneActGroup] = []
        
        for a in acts {
            let actScenes = scenes.filter { $0.act?.id == a.id }
            guard !actScenes.isEmpty else { continue }

            groups.append(SceneActGroup(
                id: a.id.uuidString,
                name: a.name ?? NSLocalizedString("drama.act", comment: "Act"),
                scenes: actScenes
            ))
        }
        
        return groups
    }
    
    /// Helper: Add unassigned scenes to act groups
    private func addUnassignedActScenes(to groups: inout [SceneActGroup], scenes: [StoryScene]) {
        let assignedSceneIDs: Set<UUID> = Set(groups.flatMap { $0.scenes.map { $0.id } })
        let unassignedScenes: [StoryScene] = scenes.filter { scene in
            !assignedSceneIDs.contains(scene.id)
        }
        
        if !unassignedScenes.isEmpty {
            groups.append(SceneActGroup(
                id: "__unassigned__",
                name: NSLocalizedString("fiction.scenes.unassigned", comment: "Unassigned"),
                scenes: unassignedScenes
            ))
        }
    }

    private func verseNovelChapterGroups() -> [SceneChapterGroup]? {
        let books = project.books ?? []
        guard !books.isEmpty else { return nil }

        let visibleScenes = sortedScenes
        let sortedBooks: [Book] = sortBooks(books)
        let groups: [SceneChapterGroup] = buildVerseNovelGroups(from: sortedBooks, scenes: visibleScenes)
        
        var finalGroups = groups
        addUnassignedVerseNovelScenes(to: &finalGroups, scenes: visibleScenes)
        
        return finalGroups.isEmpty ? nil : finalGroups
    }
    
    /// Helper: Sort books by userOrder then name
    private func sortBooks(_ books: [Book]) -> [Book] {
        books.sorted(by: ContainerDisplayOrder.isOrdered)
    }
    
    /// Helper: Build groups for books with their scenes
    private func buildVerseNovelGroups(from books: [Book], scenes: [StoryScene]) -> [SceneChapterGroup] {
        var groups: [SceneChapterGroup] = []
        
        for book in books {
            let bookScenes = scenes.filter { $0.book?.id == book.id }
            guard !bookScenes.isEmpty else { continue }

            groups.append(SceneChapterGroup(
                id: book.id.uuidString,
                name: book.name ?? fictionClass.chapterSingularName,
                scenes: bookScenes
            ))
        }
        
        return groups
    }
    
    /// Helper: Add unassigned scenes to verse novel groups
    private func addUnassignedVerseNovelScenes(to groups: inout [SceneChapterGroup], scenes: [StoryScene]) {
        let assignedSceneIDs: Set<UUID> = Set(groups.flatMap { $0.scenes.map { $0.id } })
        let unassignedScenes: [StoryScene] = scenes.filter { scene in
            !assignedSceneIDs.contains(scene.id)
        }
        
        if !unassignedScenes.isEmpty {
            groups.append(SceneChapterGroup(
                id: "__unassigned__",
                name: NSLocalizedString("fiction.episodes.unassigned", comment: "Unassigned"),
                scenes: unassignedScenes
            ))
        }
    }
    
    // MARK: - Body

    @ViewBuilder
    private var primaryContent: some View {
        if useChapterGrouping || useActGrouping {
            sceneList
        } else if sortedScenes.isEmpty && statusFilter == nil {
            emptyState
        } else if sortedScenes.isEmpty {
            ContentUnavailableView {
                Label(NSLocalizedString("workflow.filter.noResults", comment: "No files"), systemImage: "doc.text")
            } description: {
                Text(NSLocalizedString("workflow.filter.noResultsHint", comment: "No files with this status"))
            }
        } else {
            sceneList
        }
    }

    private var bodyScaffold: some View {
        VStack(spacing: 0) {
            workflowStatusFilter
            primaryContent
        }
    }

    private var headerFooterEditor: some View {
        HeaderFooterDialog(
            headerEnabled: project.pageSetup?.hasHeaders ?? false,
            footerEnabled: project.pageSetup?.hasFooters ?? false,
            headerLeft: $headerLeft,
            headerCenter: $headerCenter,
            headerRight: $headerRight,
            footerLeft: $footerLeft,
            footerCenter: $footerCenter,
            footerRight: $footerRight,
            headerInsertTarget: $headerInsertTarget,
            footerInsertTarget: $footerInsertTarget,
            showHeaderElementPicker: .constant(false),
            showFooterElementPicker: .constant(false),
            isPresented: $showHeaderFooterEditor,
            headerFooterElements: [],
            onCancel: { showHeaderFooterEditor = false },
            onSave: {
                if let pageSetup = project.pageSetup {
                    pageSetup.headerLeft = headerLeft
                    pageSetup.headerCenter = headerCenter
                    pageSetup.headerRight = headerRight
                    pageSetup.footerLeft = footerLeft
                    pageSetup.footerCenter = footerCenter
                    pageSetup.footerRight = footerRight
                    WriteCoalescer.shared?.requestSave(reason: "scene-list-header-footer-save")
                    WriteCoalescer.shared?.flush()
                }
                showHeaderFooterEditor = false
            }
        )
    }
    
    private var bodyCore: some View {
        bodyScaffold
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                trailingToolbarContent
            }
            
            // Bottom toolbar for multi-select actions
            ToolbarItemGroup(placement: .bottomBar) {
                if showToolbar {
                    bottomToolbarContent
                }
            }
        }
    }

    @ViewBuilder
    private var bodyCoreWithSheets: some View {
        #if targetEnvironment(macCatalyst)
        bodyCoreWithSharedSheets
            .overlay {
                sceneDetailsOverlay
            }
        #else
        bodyCoreWithSharedSheets
            .sheet(item: $sceneForDetails) { scene in
                sceneDetailsSheetContent(for: scene)
            }
        #endif
    }

    private var bodyCoreWithSharedSheets: some View {
        bodyCore
        .sheet(isPresented: $showAddScene) {
            AddSceneSheet(project: project, chapter: chapter, act: act, book: book)
        }
        .sheet(isPresented: $showSearchView) {
            searchSheetContent
        }
        .sheet(isPresented: $showHeaderFooterEditor) {
            headerFooterEditor
        }
        .alert(NSLocalizedString("headerFooter.notEnabled.title", comment: "Headers & Footers Not Enabled"), isPresented: $showHeaderFooterWarning) {
            Button(NSLocalizedString("button.ok", comment: "OK"), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("headerFooter.notEnabled.message", comment: "Enable headers or footers in Page Setup in your project's settings before editing their content."))
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [
                .rtf,
                .init("org.openxmlformats.wordprocessingml.document") ?? .data,
                UTType(filenameExtension: "md") ?? .plainText,
                UTType(filenameExtension: "fountain") ?? .plainText,
                UTType(filenameExtension: "fdx") ?? .xml
            ],
            allowsMultipleSelection: false,
            onCompletion: handleImport
        )
    }
    @ViewBuilder
    private var sceneDetailsOverlay: some View {
        if let scene = sceneForDetails {
            ZStack {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .onTapGesture {
                        sceneForDetails = nil
                    }

                sceneDetailsSheetContent(for: scene)
                    .frame(width: 420, height: 520)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 12)
                    .padding()
            }
            .transition(.opacity)
            .zIndex(1000)
        }
    }

    @ViewBuilder
    private func sceneDetailsSheetContent(for scene: StoryScene) -> some View {
        if let textFile = scene.textFile {
            FileDetailsSheet(file: textFile, onExport: { file in
                sceneForDetails = nil
                filesToExport = [file]
                saveAsRequested = false
                showExportMenu = true
            }, onDismiss: {
                sceneForDetails = nil
            })
        } else {
            SceneDetailView(scene: scene, project: project, onExport: { textFile in
                sceneForDetails = nil
                filesToExport = [textFile]
                saveAsRequested = false
                showExportMenu = true
            }, onDismiss: {
                sceneForDetails = nil
            })
        }
    }

    @ViewBuilder
    private var searchSheetContent: some View {
        // Multi-file search across all scene files
        if let folder = scenesFolder {
            MultiFileSearchView(folder: folder, files: sceneFiles)
        } else {
            NavigationStack {
                ContentUnavailableView {
                    Label(NSLocalizedString("multiFileSearch.folderMissing.title", comment: "Folder missing"), systemImage: "folder.badge.questionmark")
                } description: {
                    Text(String(format: NSLocalizedString("multiFileSearch.folderMissing.message", comment: "Could not find expected folder"), scenesFolderName))
                }
                .navigationTitle(NSLocalizedString("multiFileSearch.title", comment: "Search"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(NSLocalizedString("button.close", comment: "Close")) {
                            showSearchView = false
                        }
                    }
                }
            }
        }
    }
    
    var body: some View {
        bodyCoreWithSheets
        .navigationDestination(item: $navigateToScene) { (scene: StoryScene) in
            sceneNavigationDestination(scene)
        }
        .confirmationDialog(
            deleteConfirmationTitle,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            deleteConfirmationButtons
        } message: {
            Text(deleteConfirmationMessage)
        }
        .onChange(of: editMode) { _, newValue in
            if newValue == .active {
                // Clear status filter so all items are available for container assignment
                statusFilter = nil
            } else if newValue == .inactive {
                selectedSceneIDs.removeAll()
            }
        }
        .sheet(isPresented: $showActPicker) {
            ActPickerSheet(
                project: project,
                selectedScenes: selectedScenes,
                onAssign: { act in
                    assignScenesToAct(selectedScenes, act: act)
                    showActPicker = false
                    exitEditMode()
                },
                onCancel: {
                    showActPicker = false
                }
            )
        }
        .sheet(isPresented: $showChapterPicker) {
            ChapterPickerSheet(
                project: project,
                selectedScenes: selectedScenes,
                onAssign: { chapter in
                    assignScenesToChapter(selectedScenes, chapter: chapter)
                    showChapterPicker = false
                    exitEditMode()
                },
                onCancel: {
                    showChapterPicker = false
                }
            )
        }
        .sheet(isPresented: $showStatusPicker) {
            let sceneFiles: [TextFile] = selectedScenes.compactMap { $0.textFile }
            WorkflowStatusPickerSheet(
                files: sceneFiles,
                onStatusSelected: { newStatus in
                    changeScenesStatus(selectedScenes, to: newStatus)
                    showStatusPicker = false
                    exitEditMode()
                },
                onCancel: {
                    showStatusPicker = false
                }
            )
        }
        .alert(NSLocalizedString("submissions.name.title", comment: "Name Submission"), isPresented: $showSubmissionNamePrompt) {
            TextField(NSLocalizedString("submissions.name.placeholder", comment: "Name"), text: $newSubmissionName)
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                newSubmissionName = ""
            }
            Button(NSLocalizedString("button.create", comment: "Create")) {
                createSubmissionFromScenes(name: newSubmissionName)
                newSubmissionName = ""
            }
            .disabled(newSubmissionName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text(NSLocalizedString("submissions.name.message", comment: "Enter a name"))
        }
        .alert(NSLocalizedString("submissions.created.title", comment: "Submission Created"), isPresented: $showSubmissionCreated) {
            Button(NSLocalizedString("button.ok", comment: "OK")) { }
        } message: {
            Text(String(format: NSLocalizedString("submissions.created.message", comment: "Created message"), createdSubmissionName))
        }
        .alert(NSLocalizedString("submissions.duplicate.title", comment: "Duplicate Submission"), isPresented: $showDuplicateSubmission) {
            Button(NSLocalizedString("button.ok", comment: "OK")) { }
        } message: {
            Text(String(format: NSLocalizedString("submissions.duplicate.message", comment: "Duplicate message"), createdSubmissionName))
        }
        .confirmationDialog(
            NSLocalizedString("export.dialog.title", comment: "Export Format"),
            isPresented: $showExportMenu,
            titleVisibility: .visible
        ) {
            exportDialogButtons
        }
        .alert(NSLocalizedString("export.imageWarning.title", comment: "Images Not Included"), isPresented: $showExportImageWarning) {
            Button(NSLocalizedString("export.imageWarning.continue", comment: "Continue")) {
                pendingExportAction?()
                pendingExportAction = nil
            }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                pendingExportAction = nil
            }
        } message: {
            Text(NSLocalizedString("export.imageWarning.message", comment: "Images will not be included"))
        }
        .sheet(isPresented: $showShareSheet) {
            if let fileURL = shareableFileURL {
                ShareSheet(urls: [fileURL])
            }
        }
        .fileExporter(
            isPresented: $showExportSaveDialog,
            document: ExportDocument(
                data: exportData ?? Data(),
                filename: exportFilename,
                contentType: contentTypeForFormat(exportFormat)
            ),
            contentType: contentTypeForFormat(exportFormat),
            defaultFilename: exportFilename,
            onCompletion: { _ in
                exportData = nil
                exportFilename = ""
                saveAsRequested = false
            }
        )
        .sheet(isPresented: $showCopyToProject) {
            CopyToProjectPickerView(
                sourceProject: project,
                filesToCopy: filesToExport,
                onProjectSelected: { destinationProject in
                    showCopyToProject = false
                    copyFilesToProject(filesToExport, destination: destinationProject)
                    filesToExport = []
                },
                onCancel: {
                    showCopyToProject = false
                    filesToExport = []
                }
            )
        }
        .alert(
            copyResultIsError
                ? NSLocalizedString("copyToProject.error.title", comment: "Copy Failed")
                : NSLocalizedString("copyToProject.success.title", comment: "Files Copied"),
            isPresented: $showCopyResult
        ) {
            Button(NSLocalizedString("button.ok", comment: "OK")) { }
        } message: {
            Text(copyResultMessage)
        }
        .alert("Delete Failed", isPresented: $showDeleteError) {
            Button(NSLocalizedString("button.ok", comment: "OK"), role: .cancel) { }
        } message: {
            Text(deleteErrorMessage)
        }
        .sheet(item: $containerAssignmentItem, onDismiss: {
            withAnimation {
                editMode = .inactive
            }
            selectedSceneIDs.removeAll()
        }) { item in
            containerAssignmentContent(for: item.scenes)
        }
        .sheet(item: $sceneForFormChange) { file in
            PoetryFormPickerSheet(file: file)
        }
        .upgradePrompt(reason: $upgradePromptReason)
        .onAppear {
            initializeHeaderFooterFields()
            
            // Expand all chapter sections by default on first appear
            if chapterExpandedSections.isEmpty, let groups = chapterGroups {
                chapterExpandedSections = Set(groups.map { $0.id })
            }
            
            // Expand all act sections by default on first appear (Drama)
            if actExpandedSections.isEmpty, let groups = actGroups {
                actExpandedSections = Set(groups.map { $0.id })
            }
        }
    }
    
    // MARK: - Extracted Body Helpers
    
    @ViewBuilder
    private func sceneNavigationDestination(_ scene: StoryScene) -> some View {
        if let textFile = scene.textFile {
            if project.type == .drama {
                DramaSceneEditorView(file: textFile, project: project)
            } else {
                FileEditView(file: textFile)
            }
        } else {
            SceneDetailView(scene: scene, project: project)
        }
    }
    
    private var deleteConfirmationTitle: String {
        if scenesToDelete.count == 1 {
            return isVerseNovel
                ? NSLocalizedString("fiction.episodes.deleteConfirm.title", comment: "Delete episode?")
                : NSLocalizedString("fiction.scenes.deleteConfirm.title", comment: "Delete scene?")
        } else {
            return isVerseNovel
                ? String(format: NSLocalizedString("fiction.episodes.deleteMultiple.title", comment: "Delete episodes?"), scenesToDelete.count)
                : String(format: NSLocalizedString("fiction.scenes.deleteMultiple.title", comment: "Delete scenes?"), scenesToDelete.count)
        }
    }
    
    private var deleteConfirmationMessage: String {
        isVerseNovel
            ? NSLocalizedString("fiction.episodes.deleteConfirm.message.enhanced", comment: "Move to Trash keeps the episode's file, Delete Forever is permanent")
            : NSLocalizedString("fiction.scenes.deleteConfirm.message.enhanced", comment: "Move to Trash keeps the scene's file, Delete Forever is permanent")
    }
    
    @ViewBuilder
    private var deleteConfirmationButtons: some View {
        Button(NSLocalizedString("fiction.scenes.delete.toTrash", comment: "Move to Trash"), role: .destructive) {
            moveScenesToTrash(scenesToDelete)
            scenesToDelete = []
            exitEditMode()
        }
        Button(NSLocalizedString("fiction.scenes.delete.permanently", comment: "Delete Forever"), role: .destructive) {
            deleteScenesPermanently(scenesToDelete)
            scenesToDelete = []
            exitEditMode()
        }
        Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
            scenesToDelete = []
        }
    }
    
    // MARK: - Workflow Status Filter
    
    @ViewBuilder
    private var workflowStatusFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" option with count
                workflowStatusButton(nil, label: NSLocalizedString("workflow.filter.all", comment: "All"), count: sceneCount(for: nil))
                
                // Individual status options with counts
                ForEach(WorkflowStatus.allCases, id: \.self) { status in
                    workflowStatusButton(status, label: status.localizedName, count: sceneCount(for: status))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    @ViewBuilder
    private func workflowStatusButton(_ status: WorkflowStatus?, label: String, count: Int) -> some View {
        let isSelected = statusFilter == status
        let statusColor: Color = status.map { Color($0.color) } ?? .primary
        
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                statusFilter = status
            }
        } label: {
            Text("\(label) (\(count))")
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? statusColor.opacity(0.2) : Color(.secondarySystemBackground))
                )
                .foregroundColor(isSelected ? statusColor : .secondary)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Trailing Toolbar
    
    @ViewBuilder
    private var trailingToolbarContent: some View {
        // Chapter expand/collapse button (only when chapter grouping is active)
        if let groups = chapterGroups {
            chapterExpandCollapseButton(groups: groups)
        }
        
        // Act expand/collapse button (only when act grouping is active)
        if let groups = actGroups {
            actExpandCollapseButton(groups: groups)
        }
        
        // Search button
        if !sortedScenes.isEmpty {
            Button {
                showSearchView = true
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .accessibilityLabel(NSLocalizedString("sceneList.search.accessibility", comment: "Search scenes"))
            .disabled(editMode == .active)
        }
        
        #if targetEnvironment(macCatalyst)
        // Import button - Mac only, shown directly in toolbar
        Button {
            showImportPicker = true
        } label: {
            Image(systemName: "square.and.arrow.down")
        }
        .accessibilityLabel(NSLocalizedString("sceneList.import.accessibility", comment: "Import document"))
        .disabled(editMode == .active)
        
        // Header/Footer button - Mac only
        Button {
            if headersOrFootersEnabled {
                initializeHeaderFooterFields()
                showHeaderFooterEditor = true
            } else {
                showHeaderFooterWarning = true
            }
        } label: {
            Image(systemName: "rectangle.and.pencil.and.ellipsis")
        }
        .accessibilityLabel(NSLocalizedString("sceneList.headerFooter.accessibility", comment: "Edit headers and footers"))
        .foregroundStyle(headersOrFootersEnabled ? Color.accentColor : Color.secondary)
        #endif
        
        // Add scene button (hidden when viewing an act's or chapter's scenes)
        if act == nil && chapter == nil {
            Button {
                showAddScene = true
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel(isVerseNovel
                ? NSLocalizedString("fiction.episodes.add", comment: "Add episode")
                : NSLocalizedString("fiction.scenes.add", comment: "Add scene"))
            .disabled(editMode == .active)
        }
        
        // Edit/Done button
        if !sortedScenes.isEmpty {
            Button {
                withAnimation {
                    if editMode == .active {
                        editMode = .inactive
                        selectedSceneIDs.removeAll()
                    } else {
                        editMode = .active
                    }
                }
            } label: {
                Text(isEditMode ? NSLocalizedString("button.done", comment: "Done") : NSLocalizedString("button.edit", comment: "Edit"))
            }
            .accessibilityLabel(isEditMode ? NSLocalizedString("button.done", comment: "Done") : (isVerseNovel
                ? NSLocalizedString("fiction.episodes.edit", comment: "Edit episodes")
                : NSLocalizedString("fiction.scenes.edit", comment: "Edit scenes")))
        }
        
        #if !targetEnvironment(macCatalyst)
        // On iPhone/iPad, show import and header/footer in overflow menu (rightmost)
        Menu {
            Button {
                showImportPicker = true
            } label: {
                Label("Import document", systemImage: "square.and.arrow.down")
            }
            Button {
                if headersOrFootersEnabled {
                    initializeHeaderFooterFields()
                    showHeaderFooterEditor = true
                } else {
                    showHeaderFooterWarning = true
                }
            } label: {
                Label("Edit headers and footers", systemImage: "rectangle.and.pencil.and.ellipsis")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .disabled(editMode == .active)
        #endif
    }
    
    // MARK: - Container Assignment
    
    @ViewBuilder
    private func containerAssignmentContent(for scenes: [StoryScene]) -> some View {
        if project.type == .drama {
            ContainerAssignmentView.forActs(
                project: project,
                selectedScenes: scenes,
                modelContext: modelContext
            )
        } else if project.type == .fiction {
            if isVerseNovel {
                ContainerAssignmentView.forBooks(
                    project: project,
                    selectedScenes: scenes,
                    modelContext: modelContext
                )
            } else {
                ContainerAssignmentView.forChapters(
                    project: project,
                    selectedScenes: scenes,
                    modelContext: modelContext
                )
            }
        }
    }
    
    // MARK: - Bottom Toolbar
    
    @ViewBuilder
    private var bottomToolbarContent: some View {
        // Change Status button
        Button {
            showStatusPicker = true
        } label: {
            Label(
                NSLocalizedString("fileList.changeStatus", comment: "Change status"),
                systemImage: "arrow.triangle.2.circlepath"
            )
        }
        .disabled(selectedScenes.isEmpty)
        
        // Add to Act button (Drama projects, main scene list only)
        // Assigning to an act automatically sets the scene's status to ready
        if project.type == .drama && act == nil && chapter == nil {
            Button {
                containerAssignmentItem = ContainerAssignmentItem(scenes: selectedScenes)
            } label: {
                Label(
                    NSLocalizedString("drama.scenes.addToAct", comment: "Add to Act"),
                    systemImage: "theatermasks"
                )
            }
        }
        
        // Add to Chapter/Story/Book button (Fiction projects, main scene list only)
        // Assigning to a chapter/story/book automatically sets the scene's status to ready
        if project.type == .fiction && act == nil && chapter == nil {
            let isShortFiction = fictionClass == .shortFiction
            Button {
                containerAssignmentItem = ContainerAssignmentItem(scenes: selectedScenes)
            } label: {
                Label(
                    isVerseNovel
                        ? NSLocalizedString("fiction.episodes.addToBook", comment: "Add to Book")
                        : (isShortFiction 
                            ? NSLocalizedString("fiction.scenes.addToStory", comment: "Add to Story")
                            : NSLocalizedString("fiction.scenes.addToChapter", comment: "Add to Chapter")),
                    systemImage: isVerseNovel ? "text.book.closed" : (isShortFiction ? "books.vertical" : "book")
                )
            }
        }
        
        // Add to submission button
        if !selectedScenes.isEmpty {
            Button {
                showSubmissionNamePrompt = true
            } label: {
                Label(NSLocalizedString("fileList.addToSubmission", comment: "Add to submission"), systemImage: "tray.and.arrow.down")
            }
        }
        
        // Export button
        if !selectedScenes.isEmpty {
            Button {
                filesToExport = selectedScenes.compactMap { $0.textFile }
                saveAsRequested = false
                showExportMenu = true
            } label: {
                Label(NSLocalizedString("fileList.export", comment: "Export files"), systemImage: "square.and.arrow.up")
            }

            #if os(macOS) || targetEnvironment(macCatalyst)
            Button {
                filesToExport = selectedScenes.compactMap { $0.textFile }
                saveAsRequested = true
                showExportMenu = true
            } label: {
                Label(NSLocalizedString("manuscript.saveAs", comment: "Save As…"), systemImage: "square.and.arrow.down")
            }
            #endif
        }
        
        // Print button
        Button {
            printSelectedScenes()
        } label: {
            Label(NSLocalizedString("fileList.print", comment: "Print"), systemImage: "printer")
        }
        .disabled(selectedScenes.isEmpty)
        
        Spacer()
        
        Button(role: .destructive) {
            prepareDelete(selectedScenes)
        } label: {
            let deleteFormat: String = isVerseNovel
                ? NSLocalizedString("fiction.episodes.deleteCount", comment: "Delete count")
                : NSLocalizedString("fiction.scenes.deleteCount", comment: "Delete count")
            Label(
                String(format: deleteFormat, selectedScenes.count),
                systemImage: "trash"
            )
        }
        .disabled(selectedScenes.isEmpty)
        .accessibilityLabel({
            let label: String = isVerseNovel
                ? NSLocalizedString("fiction.episodes.deleteSelected", comment: "Delete selected episodes")
                : NSLocalizedString("fiction.scenes.deleteSelected", comment: "Delete selected scenes")
            return Text(label)
        }())
    }
    
    // MARK: - Scene List
    
    private var sceneList: some View {
        List {
            sceneListContent
        }
        .listStyle(.plain)
    }
    
    @ViewBuilder
    private var sceneListContent: some View {
        if let groups = chapterGroups {
                // Show scenes grouped by chapter/story/book with disclosure sections
                ForEach(groups) { group in
                    Section {
                        if chapterExpandedSections.contains(group.id) {
                            ForEach(group.scenes) { scene in
                                sceneRow(for: scene)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        if !isEditMode {
                                            Button(role: .destructive) {
                                                prepareDelete([scene])
                                            } label: {
                                                Label(NSLocalizedString("button.delete", comment: "Delete"), systemImage: "trash")
                                            }
                                        }
                                    }
                            }
                        }
                    } header: {
                        chapterSectionHeader(for: group)
                    }
                }
            } else if let groups = actGroups {
                // Show scenes grouped by act with disclosure sections (Drama)
                ForEach(groups) { group in
                    Section {
                        if actExpandedSections.contains(group.id) {
                            ForEach(group.scenes) { scene in
                                sceneRow(for: scene)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        if !isEditMode {
                                            Button(role: .destructive) {
                                                prepareDelete([scene])
                                            } label: {
                                                Label(NSLocalizedString("button.delete", comment: "Delete"), systemImage: "trash")
                                            }
                                        }
                                    }
                            }
                        }
                    } header: {
                        actSectionHeader(for: group)
                    }
                }
            } else {
                // Flat list (when viewing a specific chapter's scenes, or no chapters exist)
                ForEach(sortedScenes) { scene in
                    sceneRow(for: scene)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !isEditMode {
                                Button(role: .destructive) {
                                    prepareDelete([scene])
                                } label: {
                                    Label(NSLocalizedString("button.delete", comment: "Delete"), systemImage: "trash")
                                }
                            }
                        }
                        // Enable drag-to-reorder without edit mode (only when within an act)
                        .onDrag {
                            return NSItemProvider(object: scene.id.uuidString as NSString)
                        }
                }
                .onMove(perform: moveScenes)
            }
    }
    
    // MARK: - Chapter Section Header
    
    @ViewBuilder
    private func chapterSectionHeader(for group: SceneChapterGroup) -> some View {
        let isExpanded = chapterExpandedSections.contains(group.id)
        
        Button {
            withAnimation {
                if chapterExpandedSections.contains(group.id) {
                    chapterExpandedSections.remove(group.id)
                } else {
                    chapterExpandedSections.insert(group.id)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.body)
                    .fontWeight(.semibold)
                    .frame(width: 20)
                
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                    .font(.title3)
                
                Text(group.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text("(\(group.count))")
                    .font(.body)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(group.name), \(group.count) \(isVerseNovel ? NSLocalizedString("fiction.episodes.title", comment: "Episodes") : NSLocalizedString("fiction.scenes.title", comment: "Scenes"))"))
        .accessibilityHint(Text(isExpanded ?
            NSLocalizedString("section.collapse.hint", comment: "Tap to collapse") :
            NSLocalizedString("section.expand.hint", comment: "Tap to expand")))
    }
    
    // MARK: - Scene Row
    
    @ViewBuilder
    private func sceneRow(for scene: StoryScene) -> some View {
        HStack {
            if isEditMode {
                Image(systemName: selectedSceneIDs.contains(scene.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedSceneIDs.contains(scene.id) ? .blue : .gray)
                    .imageScale(.large)

                SceneRowView(scene: scene)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleSelection(for: scene)
                    }
            } else {
                NavigationLink {
                    sceneNavigationDestination(scene)
                } label: {
                    SceneRowView(scene: scene)
                }
                .buttonStyle(.plain)
            }
            
            Spacer(minLength: 8)
            
            // Options menu (only in normal mode)
            if !isEditMode {
                if let textFile = scene.textFile {
                    FileSubmissionsButton(file: textFile)
                }
                sceneOptionsMenu(for: scene)
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            sceneContextMenuItems(for: scene)
        }
    }
    
    // MARK: - Scene Options Button
    
    /// Ellipsis button that opens scene details directly
    @ViewBuilder
    private func sceneOptionsMenu(for scene: StoryScene) -> some View {
        Button {
            sceneForDetails = scene
        } label: {
            Image(systemName: "ellipsis.circle")
                .imageScale(.large)
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NSLocalizedString("fileList.options", comment: "File options"))
    }
    
    // MARK: - Scene Context Menu
    
    @ViewBuilder
    private func sceneContextMenuItems(for scene: StoryScene) -> some View {
        #if targetEnvironment(macCatalyst)
        Button {
            navigateToScene = scene
        } label: {
            Label("fileList.contextMenu.open", systemImage: "doc")
        }
        
        if isVerseNovel, let textFile = scene.textFile {
            Divider()
            
            Button {
                sceneForFormChange = textFile
            } label: {
                Label("fileList.contextMenu.changeForm", systemImage: "text.book.closed")
            }
        }
        
        Divider()
        
        Button {
            sceneForDetails = scene
        } label: {
            Label(NSLocalizedString("fileDetail.title", comment: "File details title"), systemImage: "info.circle")
        }
        
        Divider()
        
        Button(role: .destructive) {
            scenesToDelete = [scene]
            showDeleteConfirmation = true
        } label: {
            Label("fileList.contextMenu.delete", systemImage: "trash")
        }
        #else
        EmptyView()
        #endif
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: isVerseNovel ? "music.note.list" : "film")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(isVerseNovel
                ? NSLocalizedString("fiction.episodes.empty.title", comment: "No episodes")
                : NSLocalizedString("fiction.scenes.empty.title", comment: "No scenes"))
                .font(.headline)
            
            Text(isVerseNovel
                ? NSLocalizedString("fiction.episodes.empty.message", comment: "Empty message")
                : NSLocalizedString("fiction.scenes.empty.message", comment: "Empty message"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showAddScene = true
            } label: {
                Label(isVerseNovel
                    ? NSLocalizedString("fiction.episodes.add", comment: "Add episode")
                    : NSLocalizedString("fiction.scenes.add", comment: "Add scene"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func createSubmissionFromScenes(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if UniquenessChecker.hasDuplicateSubmissionNamed(trimmedName, in: project) {
            createdSubmissionName = trimmedName
            showDuplicateSubmission = true
            return
        }
        
        let submission = Submission(
            project: project,
            submittedDate: Date()
        )
        submission.name = trimmedName
        submission.isCollection = false
        modelContext.insert(submission)
        
        // Link files from all selected scenes
        for scene in selectedScenes {
            if let file = scene.textFile, file.trashItem == nil {
                let submittedFile = SubmittedFile(
                    submission: submission,
                    textFile: file,
                    version: file.currentVersion,
                    status: .pending,
                    statusDate: Date(),
                    project: project
                )
                modelContext.insert(submittedFile)
            }
        }
        
        WriteCoalescer.shared?.requestSave(reason: "scene-list-create-submission")
        WriteCoalescer.shared?.flush()
        createdSubmissionName = trimmedName
        showSubmissionCreated = true
        selectedSceneIDs.removeAll()
    }
    
    private func toggleSelection(for scene: StoryScene) {
        if selectedSceneIDs.contains(scene.id) {
            selectedSceneIDs.remove(scene.id)
        } else {
            selectedSceneIDs.insert(scene.id)
        }
    }
    
    
    // MARK: - Export
    
    @ViewBuilder
    private var exportDialogButtons: some View {
        Button {
            showExportMenu = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showCopyToProject = true
            }
        } label: {
            Label(NSLocalizedString("export.copyToProject", comment: "Copy to Project…"), systemImage: "doc.on.doc")
        }
        Button(ExportFormat.pdf.localizedName) {
            exportFiles(filesToExport, format: .pdf)
        }
        Button(ExportFormat.rtf.localizedName) {
            pendingExportAction = { [self] in exportFiles(filesToExport, format: .rtf) }
            showImageWarningAfterDelay()
        }
        Button(ExportFormat.html.localizedName) {
            exportFiles(filesToExport, format: .html)
        }
        Button(ExportFormat.word.localizedName) {
            exportFiles(filesToExport, format: .word)
        }
        Button(ExportFormat.markdown.localizedName) {
            pendingExportAction = { [self] in exportFiles(filesToExport, format: .markdown) }
            showImageWarningAfterDelay()
        }
        Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
            filesToExport = []
        }
    }
    
    private func showImageWarningAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showExportImageWarning = true
        }
    }
    
    private func exportFiles(_ files: [TextFile], format: ExportFormat) {
        self.exportFormat = format
        guard !files.isEmpty else { return }
        
        // Check entitlement for export
        if !EntitlementManager.shared.canExport(projectType: project.type) {
            upgradePromptReason = .exportBlocked(projectType: project.type)
            return
        }
        
        var attributedStrings: [NSAttributedString] = []
        
        for file in files {
            guard let version = file.currentVersion else { continue }
            var content: NSAttributedString
            if let formatted = version.attributedContent {
                content = formatted
            } else if !version.content.isEmpty {
                content = NSAttributedString(
                    string: version.content,
                    attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
                )
            } else {
                continue
            }
            
            if file.isMarkdown && format != .markdown && format != .plainText {
                if let rendered = try? MarkdownImportService.importMarkdown(from: content.string, styleSheet: file.project?.styleSheet) {
                    content = rendered
                }
            }
            
            attributedStrings.append(content)
        }
        
        guard !attributedStrings.isEmpty else {
            filesToExport = []
            return
        }
        
        // Single file: direct export
        if attributedStrings.count == 1, let firstFile = files.first {
            performSingleFileExport(format: format, content: attributedStrings[0], filename: firstFile.name, footnotes: firstFile.currentVersion?.footnotes)
            filesToExport = []
            return
        }
        
        // Multiple files: combined export
        let filename = project.name ?? "Export"
        
        Task {
            do {
                let data: Data
                switch format {
                case .pdf:
                    let assembled = NSMutableAttributedString()
                    var isFirst = true
                    for attrStr in attributedStrings {
                        if !isFirst {
                            assembled.append(NSAttributedString(string: "\u{000C}"))
                        }
                        isFirst = false
                        assembled.append(attrStr)
                    }
                    let manuscriptContent = ManuscriptContent(
                        attributedString: assembled,
                        sections: [],
                        fileOffsets: [:],
                        frontMatterFileCount: 0,
                        frontMatterCharacterLength: 0,
                        assembledFootnotes: []
                    )
                    guard let pdfData = PrintService.generatePDF(
                        from: manuscriptContent,
                        project: project,
                        pageSetup: project.pageSetup,
                        context: modelContext
                    ) else { return }
                    data = pdfData
                case .rtf:
                    data = try WordDocumentService.exportMultipleToRTF(attributedStrings, filename: filename)
                case .html:
                    data = try HTMLExportService.exportMultipleToHTMLData(attributedStrings, filename: filename)
                case .word:
                    let exportService = DOCXExportService(modelContext: modelContext)
                    data = try exportService.exportMultipleToDOCX(attributedStrings, filename: filename)
                case .markdown:
                    data = try MarkdownExportService.exportMultipleToMarkdownData(attributedStrings, filename: filename)
                default:
                    return
                }
                
                await MainActor.run {
                    presentShareFile(data: data, filename: "\(filename).\(format.fileExtension)", format: format)
                }
            } catch {
                #if DEBUG
                await MainActor.run {
                    print("❌ [SceneListView] Export failed: \(error)")
                }
                #endif
            }
        }
        
        filesToExport = []
    }
    
    private func performSingleFileExport(format: ExportFormat, content: NSAttributedString, filename: String, footnotes: [FootnoteModel]? = nil) {
        do {
            let data: Data
            switch format {
            case .pdf:
                let assembled = NSMutableAttributedString()
                assembled.append(content)
                let manuscriptContent = ManuscriptContent(
                    attributedString: assembled,
                    sections: [],
                    fileOffsets: [:],
                    frontMatterFileCount: 0,
                    frontMatterCharacterLength: 0,
                    assembledFootnotes: []
                )
                guard let pdfData = PrintService.generatePDF(
                    from: manuscriptContent,
                    project: project,
                    pageSetup: project.pageSetup,
                    context: modelContext
                ) else { return }
                data = pdfData
            case .rtf:
                data = try WordDocumentService.exportToRTF(content, filename: filename)
            case .html:
                data = try HTMLExportService.exportToHTMLData(content, filename: filename)
            case .word:
                let exportService = DOCXExportService(modelContext: modelContext)
                data = try exportService.exportToDOCX(content, filename: filename)
            case .markdown:
                data = try MarkdownExportService.exportToMarkdownData(content, filename: filename, footnotes: footnotes)
            default:
                return
            }
            
            presentShareFile(data: data, filename: "\(filename).\(format.fileExtension)", format: format)
        } catch {
            #if DEBUG
            print("❌ [SceneListView] Single export failed: \(error)")
            #endif
        }
    }

    private func presentShareFile(data: Data, filename: String, format: ExportFormat) {
        if saveAsRequested {
            exportData = data
            exportFilename = filename
            exportFormat = format
            showExportSaveDialog = true
            return
        }

        if let fileURL = ShareService.shared.createShareableFile(
            data: data,
            filename: filename,
            contentType: contentTypeForFormat(format)
        ) {
            shareableFileURL = fileURL
            showShareSheet = true
        }
    }
    
    private func contentTypeForFormat(_ format: ExportFormat) -> UTType {
        switch format {
        case .rtf: return .rtf
        case .html: return .html
        case .word: return UTType("org.openxmlformats.wordprocessingml.document") ?? .data
        case .pdf: return .pdf
        case .markdown: return UTType(filenameExtension: "md") ?? .plainText
        case .plainText: return .plainText
        case .epub: return UTType(filenameExtension: "epub") ?? .data
        case .fountain: return UTType(filenameExtension: "fountain") ?? .plainText
        case .finalDraft: return UTType(filenameExtension: "fdx") ?? .xml
        }
    }
    
    // MARK: - Copy to Project
    
    private func copyFilesToProject(_ files: [TextFile], destination: Project) {
        guard !files.isEmpty else { return }
        
        let sourceFolderName = scenesFolder?.name ?? "Scenes"
        let destinationFolder = findMatchingFolder(in: destination, named: sourceFolderName)
        
        guard let destFolder = destinationFolder else {
            copyResultMessage = String(format: NSLocalizedString("copyToProject.error.noFolder", comment: "No matching folder found"), sourceFolderName, destination.name ?? "")
            copyResultIsError = true
            showCopyResult = true
            return
        }
        
        var usedNames = Set((destFolder.textFiles ?? []).map { $0.name })
        var copiedCount = 0
        let maxSceneOrder = (destination.type == .fiction || destination.type == .drama)
            ? (destination.scenes ?? []).filter({ !$0.isTrashed }).compactMap(\.userOrder).max() ?? -1
            : 0
        
        for file in files {
            guard let currentVersion = file.currentVersion else { continue }
            
            let uniqueName = generateUniqueName(for: file.name, usedNames: usedNames)
            usedNames.insert(uniqueName)
            
            let newFile = TextFile(
                name: uniqueName,
                initialContent: currentVersion.content,
                parentFolder: destFolder,
                poetryFormId: file.poetryFormId,
                poetryFormName: file.poetryFormName
            )
            
            newFile.workflowStatusRaw = file.workflowStatusRaw
            newFile.contentTypeRaw = file.contentTypeRaw
            
            if let formattedData = currentVersion.effectiveFormattedContent,
               let newVersion = newFile.currentVersion {
                newVersion.setFormattedContentData(formattedData, sourceText: currentVersion.content)
            }

            if let newVersion = newFile.currentVersion {
                newVersion.comment = currentVersion.comment
                newVersion.notes = currentVersion.notes
                newVersion.notesFormattedContent = currentVersion.notesFormattedContent
            }
            
            if let refMetadata = currentVersion.referenceMetadataData,
               let newVersion = newFile.currentVersion {
                newVersion.referenceMetadataData = refMetadata
            }
            
            let maxOrder = (destFolder.textFiles ?? []).compactMap { $0.userOrder }.max() ?? -1
            newFile.userOrder = maxOrder + 1 + copiedCount
            
            modelContext.insert(newFile)
            
            // For Fiction/Drama projects, create a StoryScene linked to the TextFile
            if destination.type == .fiction || destination.type == .drama {
                let scene = StoryScene(name: uniqueName, userOrder: maxSceneOrder + 1 + copiedCount)
                scene.project = destination
                scene.textFile = newFile
                modelContext.insert(scene)
            }
            
            copiedCount += 1
        }
        
        do {
            try WriteCoalescer.shared.requestSaveAndFlush(reason: "scene-list-copy-to-project")
            let format = copiedCount == 1
                ? NSLocalizedString("copyToProject.success.single", comment: "1 file copied")
                : NSLocalizedString("copyToProject.success.multiple", comment: "%d files copied")
            copyResultMessage = String(format: format, copiedCount) + " " + String(format: NSLocalizedString("copyToProject.success.destination", comment: "to project"), destination.name ?? "")
            copyResultIsError = false
            showCopyResult = true
        } catch {
            copyResultMessage = NSLocalizedString("copyToProject.error.saveFailed", comment: "Save failed") + ": \(error.localizedDescription)"
            copyResultIsError = true
            showCopyResult = true
        }
    }
    
    private func findMatchingFolder(in project: Project, named sourceName: String) -> Folder? {
        guard let folders = project.folders else { return nil }
        if let match = folders.first(where: { $0.name == sourceName }) {
            return match
        }
        let contentFolderNames: Set<String> = ["Poems", "Scenes", "Stories", "Episodes", "Scripts", "Sections", "Prose"]
        if let contentFolder = folders.first(where: { contentFolderNames.contains($0.name ?? "") }) {
            return contentFolder
        }
        return folders.first(where: { FolderCapabilityService.canAddFile(to: $0) })
    }
    
    private func generateUniqueName(for name: String, usedNames: Set<String>) -> String {
        if !usedNames.contains(name) { return name }
        var counter = 2
        while counter <= 1000 {
            let candidate = "\(name) \(counter)"
            if !usedNames.contains(candidate) { return candidate }
            counter += 1
        }
        return "\(name) \(UUID().uuidString.prefix(6))"
    }
    
    private func prepareDelete(_ scenes: [StoryScene]) {
        scenesToDelete = scenes
        showDeleteConfirmation = true
    }
    
    private func printSelectedScenes() {
        let files = selectedScenes.compactMap { $0.textFile }
        guard !files.isEmpty else { return }
        
        // Check entitlement for printing
        if !EntitlementManager.shared.canPrint(projectType: project.type) {
            upgradePromptReason = .printBlocked(projectType: project.type)
            return
        }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let viewController = window.rootViewController else { return }
        
        PrintService.printFiles(
            files,
            project: project,
            context: modelContext,
            from: viewController
        ) { _, _ in }
    }
    
    private func moveScenesToTrash(_ scenes: [StoryScene]) {
        do {
            for scene in scenes {
                scene.moveToTrash()
            }

            project.modifiedDate = Date()
            WriteCoalescer.shared?.requestSave(reason: "scene-list-trash")
            try WriteCoalescer.shared?.flushOrThrow(reason: "scene-list-trash")
            renumberScenes()
        } catch {
            modelContext.rollback()
            deleteErrorMessage = "Failed to move scenes to Trash: \(error.localizedDescription)"
            showDeleteError = true
        }
    }
    
    private func deleteScenesPermanently(_ scenes: [StoryScene]) {
        do {
            let textFiles = scenes.compactMap { $0.textFile }
            let scenesWithoutTextFiles = scenes.filter { $0.textFile == nil }
            if !textFiles.isEmpty {
                try FileMoveService(modelContext: modelContext).deleteFilesPermanently(textFiles)
            }

            for scene in scenesWithoutTextFiles {
                modelContext.delete(scene)
            }

            project.modifiedDate = Date()
            if !scenesWithoutTextFiles.isEmpty {
                WriteCoalescer.shared?.requestSave(reason: "scene-list-delete-permanent")
                try WriteCoalescer.shared?.flushOrThrow(reason: "scene-list-delete-permanent")
            }
            renumberScenes()
        } catch {
            modelContext.rollback()
            deleteErrorMessage = "Failed to delete scenes permanently: \(error.localizedDescription)"
            showDeleteError = true
        }
    }
    
    private func moveScenes(from source: IndexSet, to destination: Int) {
        var scenes = sortedScenes
        scenes.move(fromOffsets: source, toOffset: destination)
        
        // Update order indices
        for (index, scene) in scenes.enumerated() {
            scene.userOrder = index
            scene.modifiedDate = Date()
        }
        
        project.modifiedDate = Date()
        WriteCoalescer.shared?.requestSave(reason: "scene-list-move")
        WriteCoalescer.shared?.flush()
    }
    
    private func renumberScenes() {
        for (index, scene) in sortedScenes.enumerated() {
            scene.userOrder = index
            scene.modifiedDate = Date()
        }
        project.modifiedDate = Date()
        WriteCoalescer.shared?.requestSave(reason: "scene-list-renumber")
        WriteCoalescer.shared?.flush()
    }
    
    private func exitEditMode() {
        withAnimation {
            editMode = .inactive
        }
    }
    
    private func assignScenesToAct(_ scenes: [StoryScene], act: Act?) {
        for scene in scenes {
            scene.act = act
            // Automatically set status to ready when assigning to an act
            if act != nil, let textFile = scene.textFile {
                textFile.workflowStatus = .ready
            }
        }
        project.modifiedDate = Date()
        WriteCoalescer.shared?.requestSave(reason: "scene-list-assign-act")
        WriteCoalescer.shared?.flush()
    }
    
    private func assignScenesToChapter(_ scenes: [StoryScene], chapter: Chapter?) {
        for scene in scenes {
            scene.chapter = chapter
            // Automatically set status to ready when assigning to a chapter/story
            if chapter != nil, let textFile = scene.textFile {
                textFile.workflowStatus = .ready
            }
        }
        project.modifiedDate = Date()
        WriteCoalescer.shared?.requestSave(reason: "scene-list-assign-chapter")
        WriteCoalescer.shared?.flush()
    }

    private func changeScenesStatus(_ scenes: [StoryScene], to newStatus: WorkflowStatus) {
        for scene in scenes {
            if let textFile = scene.textFile {
                textFile.workflowStatus = newStatus
            }
        }
        WriteCoalescer.shared?.requestSave(reason: "scene-list-change-status")
        WriteCoalescer.shared?.flush()
    }
    
    // MARK: - Chapter Expand/Collapse Button
    
    @ViewBuilder
    private func chapterExpandCollapseButton(groups: [SceneChapterGroup]) -> some View {
        let allExpanded = !groups.isEmpty && chapterExpandedSections.count == groups.count
        
        Button {
            withAnimation {
                if allExpanded {
                    chapterExpandedSections.removeAll()
                } else {
                    chapterExpandedSections = Set(groups.map { $0.id })
                }
            }
        } label: {
            Image(systemName: allExpanded ? "chevron.up.circle" : "chevron.down.circle")
        }
        .disabled(editMode == .active)
        .accessibilityLabel(Text(allExpanded ?
            NSLocalizedString("fileList.collapseAll", comment: "Collapse all") :
            NSLocalizedString("fileList.expandAll", comment: "Expand all")))
    }
    
    // MARK: - Act Expand/Collapse Button
    
    @ViewBuilder
    private func actExpandCollapseButton(groups: [SceneActGroup]) -> some View {
        let allExpanded = !groups.isEmpty && actExpandedSections.count == groups.count
        
        Button {
            withAnimation {
                if allExpanded {
                    actExpandedSections.removeAll()
                } else {
                    actExpandedSections = Set(groups.map { $0.id })
                }
            }
        } label: {
            Image(systemName: allExpanded ? "chevron.up.circle" : "chevron.down.circle")
        }
        .disabled(editMode == .active)
        .accessibilityLabel(Text(allExpanded ?
            NSLocalizedString("fileList.collapseAll", comment: "Collapse all") :
            NSLocalizedString("fileList.expandAll", comment: "Expand all")))
    }
    
    // MARK: - Act Section Header
    
    @ViewBuilder
    private func actSectionHeader(for group: SceneActGroup) -> some View {
        let isExpanded = actExpandedSections.contains(group.id)
        
        Button {
            withAnimation {
                if actExpandedSections.contains(group.id) {
                    actExpandedSections.remove(group.id)
                } else {
                    actExpandedSections.insert(group.id)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.body)
                    .fontWeight(.semibold)
                    .frame(width: 20)
                
                Image(systemName: "theatermasks")
                    .foregroundStyle(.secondary)
                    .font(.title3)
                
                Text(group.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text("(\(group.count))")
                    .font(.body)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(group.name), \(group.count) \(NSLocalizedString("fiction.scenes.title", comment: "Scenes"))"))
        .accessibilityHint(Text(isExpanded ?
            NSLocalizedString("section.collapse.hint", comment: "Tap to collapse") :
            NSLocalizedString("section.expand.hint", comment: "Tap to expand")))
    }
    
    private func initializeHeaderFooterFields() {
        if let pageSetup = project.pageSetup {
            headerLeft = pageSetup.headerLeft ?? ""
            headerCenter = pageSetup.headerCenter ?? ""
            headerRight = pageSetup.headerRight ?? ""
            footerLeft = pageSetup.footerLeft ?? ""
            footerCenter = pageSetup.footerCenter ?? ""
            footerRight = pageSetup.footerRight ?? ""
        }
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                let plainText: String
                let rtfData: Data?
                let fileName: String
                
                // Check file extension to determine import method
                let fileExtension = url.pathExtension.lowercased()
                
                if fileExtension == "fountain" {
                    // Import Fountain file → convert to DML
                    _ = url.startAccessingSecurityScopedResource()
                    defer { url.stopAccessingSecurityScopedResource() }
                    let fountainText = try String(contentsOf: url, encoding: .utf8)
                    plainText = FountainConverter.shared.fountainToDML(fountainText)
                    rtfData = nil  // Drama scenes store DML as plain text, no RTF
                    fileName = url.deletingPathExtension().lastPathComponent
                } else if fileExtension == "fdx" {
                    // Import Final Draft file → convert to DML
                    _ = url.startAccessingSecurityScopedResource()
                    defer { url.stopAccessingSecurityScopedResource() }
                    let fdxData = try Data(contentsOf: url)
                    guard let dml = FinalDraftConverter.shared.fdxToDML(fdxData) else {
                        print("Failed to parse Final Draft file")
                        return
                    }
                    plainText = dml
                    rtfData = nil  // Drama scenes store DML as plain text, no RTF
                    fileName = url.deletingPathExtension().lastPathComponent
                } else if fileExtension == "md" || fileExtension == "markdown" {
                    // Import Markdown file
                    let styleSheet = project.styleSheet
                    let attributedString = try MarkdownImportService.importMarkdown(from: url, styleSheet: styleSheet)
                    plainText = attributedString.string
                    rtfData = try? attributedString.data(
                        from: NSRange(location: 0, length: attributedString.length),
                        documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
                    )
                    fileName = url.deletingPathExtension().lastPathComponent
                } else {
                    // Use WordDocumentService to import RTF or DOCX
                    (plainText, rtfData, fileName) = try WordDocumentService.importWordDocument(from: url)
                }
                
                // Create a new scene
                let newScene = StoryScene(name: fileName)
                newScene.project = project
                newScene.chapter = chapter
                newScene.act = act
                newScene.book = book
                newScene.userOrder = sortedScenes.count
                
                // Also add to project.scenes to ensure relationship is synced
                if project.scenes == nil {
                    project.scenes = []
                }
                project.scenes?.append(newScene)
                
                // Create TextFile for scene content
                let textFile = TextFile(name: fileName, initialContent: "", parentFolder: scenesFolder)
                textFile.workflowStatus = .draft
                textFile.scene = newScene
                newScene.textFile = textFile
                
                // Update the first version with imported content
                if let firstVersion = textFile.versions?.first {
                    if let rtfData,
                       let importedContent = AttributedStringSerializer.fromRTF(rtfData, scaleFonts: false) {
                        let normalizedImport = AttributedStringSerializer.normalizeImportedWordContentToBody(importedContent)
                        firstVersion.attributedContent = normalizedImport
                    } else {
                        firstVersion.content = plainText
                        firstVersion.setFormattedContentData(rtfData, sourceText: plainText)
                    }
                }
                
                modelContext.insert(newScene)
                modelContext.insert(textFile)
                try WriteCoalescer.shared.requestSaveAndFlush(reason: "scene-list-import-scene-file")
                
            } catch {
                print("Failed to import file: \(error)")
            }
            
        case .failure(let error):
            print("Import failed: \(error)")
        }
    }
}

// MARK: - Scene Row View

struct SceneRowView: View {
    let scene: StoryScene

    private var sceneIconName: String {
        if scene.project?.type == .drama {
            return "theatermasks"
        }
        if scene.project?.fictionClass == .verseNovel {
            return "music.note.list"
        }
        return "film"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Image(systemName: sceneIconName)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(width: 22, alignment: .leading)
                
                Text(scene.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(scene.textFile?.workflowStatus.map { Color($0.color) } ?? .primary)
            }
            
            // Summary preview
            if let synopsis = scene.synopsis, !synopsis.isEmpty {
                Text(synopsis)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Character and location indicators
            HStack(spacing: 12) {
                if let characters = scene.characters, !characters.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "person.2")
                            .font(.footnote)
                        Text("\(characters.count)")
                            .font(.footnote)
                    }
                    .foregroundColor(.secondary)
                }
                
                if let location = scene.locations?.first {
                    HStack(spacing: 2) {
                        Image(systemName: "mappin")
                            .font(.footnote)
                        Text(location.name ?? "")
                            .font(.footnote)
                            .lineLimit(1)
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Scene Chapter Group

/// Represents a group of scenes belonging to a chapter/story/book for disclosure section display
struct SceneChapterGroup: Identifiable {
    let id: String
    let name: String
    let scenes: [StoryScene]
    
    var count: Int { scenes.count }
}

// MARK: - Scene Act Group

/// Represents a group of scenes belonging to an act for disclosure section display (Drama projects)
struct SceneActGroup: Identifiable {
    let id: String
    let name: String
    let scenes: [StoryScene]
    
    var count: Int { scenes.count }
}
