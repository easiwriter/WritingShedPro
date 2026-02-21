//
//  SceneListView.swift
//  Writing Shed Pro
//
//  Feature 022: Smart Fiction Creation - Scene management
//

import SwiftUI
import SwiftData
import TipKit
import UniformTypeIdentifiers

/// List view showing scenes - either for entire project (Short Fiction) or within a chapter (Novel)
/// Matches FileListView pattern with:
/// - Edit mode with selection circles
/// - Bottom toolbar for multi-select actions
/// - Confirmation dialog with Delete (to trash) and Delete Forever options
struct SceneListView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
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
    @State private var selectedScene: StoryScene?
    
    /// Scene to navigate to for editing
    @State private var navigateToScene: StoryScene?
    
    /// Edit mode binding
    @State private var editMode: EditMode = .inactive
    
    /// Selected scene IDs for multi-select
    @State private var selectedSceneIDs: Set<UUID> = []
    
    /// Delete confirmation dialog
    @State private var showDeleteConfirmation = false
    @State private var scenesToDelete: [StoryScene] = []
    
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
    
    /// Submission state
    @State private var showSubmissionPicker = false
    @State private var filesToSubmit: [TextFile] = []
    
    /// Chapter grouping: tracks which chapter sections are expanded
    @State private var chapterExpandedSections: Set<String> = []
    
    /// Act grouping: tracks which act sections are expanded (Drama only)
    @State private var actExpandedSections: Set<String> = []
    
    /// Scene/Episode list toolbar tip — uses correct variant for verse novels
    private let sceneListToolbarTip = SceneListToolbarTip()
    private let episodeListToolbarTip = EpisodeListToolbarTip()
    @State private var toolbarTipDismissed = false
    
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
        
        // Filter out trashed scenes
        var result = scenes.filter { !$0.isTrashed }
        
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
        
        return scenes.filter { !$0.isTrashed }
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
    
    /// Get the scenes folder at project level
    private var scenesFolder: Folder? {
        project.folders?.first { $0.name == "Scenes" }
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
        
        let chapters = project.chapters ?? []
        guard !chapters.isEmpty else { return nil }
        
        let currentSceneIDs = Set(sortedScenes.map { $0.id })
        var groups: [SceneChapterGroup] = []
        
        // Sort chapters by userOrder, then by name
        let sortedChapters = chapters.sorted {
            let order0 = $0.userOrder ?? Int.max
            let order1 = $1.userOrder ?? Int.max
            if order0 != order1 { return order0 < order1 }
            return ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending
        }
        
        for ch in sortedChapters {
            let chapterScenes = sortedScenes.filter { scene in
                scene.chapter?.id == ch.id && currentSceneIDs.contains(scene.id)
            }
            if !chapterScenes.isEmpty {
                groups.append(SceneChapterGroup(
                    id: ch.id.uuidString,
                    name: ch.name ?? fictionClass.chapterSingularName,
                    scenes: chapterScenes
                ))
            }
        }
        
        // Add unassigned scenes (those not belonging to any chapter)
        let assignedSceneIDs = Set(groups.flatMap { $0.scenes.map { $0.id } })
        let unassignedScenes = sortedScenes.filter { !assignedSceneIDs.contains($0.id) }
        if !unassignedScenes.isEmpty {
            groups.append(SceneChapterGroup(
                id: "__unassigned__",
                name: NSLocalizedString("fiction.scenes.unassigned", comment: "Unassigned"),
                scenes: unassignedScenes
            ))
        }
        
        return groups.isEmpty ? nil : groups
    }
    
    /// Groups scenes by their parent act for disclosure section display (Drama projects)
    /// Returns nil when there are no acts or when viewing a specific act's scenes
    private var actGroups: [SceneActGroup]? {
        // Only group when viewing all scenes (no chapter/act/book filter) and project is Drama
        guard chapter == nil && act == nil && book == nil else { return nil }
        guard project.type == .drama else { return nil }
        
        let acts = project.acts ?? []
        guard !acts.isEmpty else { return nil }
        
        let currentSceneIDs = Set(sortedScenes.map { $0.id })
        var groups: [SceneActGroup] = []
        
        // Sort acts by userOrder, then by name
        let sortedActs = acts.sorted {
            let order0 = $0.userOrder ?? Int.max
            let order1 = $1.userOrder ?? Int.max
            if order0 != order1 { return order0 < order1 }
            return ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending
        }
        
        for a in sortedActs {
            let actScenes = sortedScenes.filter { scene in
                scene.act?.id == a.id && currentSceneIDs.contains(scene.id)
            }
            if !actScenes.isEmpty {
                groups.append(SceneActGroup(
                    id: a.id.uuidString,
                    name: a.name ?? NSLocalizedString("drama.act", comment: "Act"),
                    scenes: actScenes
                ))
            }
        }
        
        // Add unassigned scenes (those not belonging to any act)
        let assignedSceneIDs = Set(groups.flatMap { $0.scenes.map { $0.id } })
        let unassignedScenes = sortedScenes.filter { !assignedSceneIDs.contains($0.id) }
        if !unassignedScenes.isEmpty {
            groups.append(SceneActGroup(
                id: "__unassigned__",
                name: NSLocalizedString("fiction.scenes.unassigned", comment: "Unassigned"),
                scenes: unassignedScenes
            ))
        }
        
        return groups.isEmpty ? nil : groups
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            workflowStatusFilter
            
            Group {
                if sortedScenes.isEmpty && statusFilter == nil {
                    emptyState
                } else if sortedScenes.isEmpty {
                    // Filtered but no results
                    ContentUnavailableView {
                        Label(NSLocalizedString("workflow.filter.noResults", comment: "No files"), systemImage: "doc.text")
                    } description: {
                        Text(NSLocalizedString("workflow.filter.noResultsHint", comment: "No files with this status"))
                    }
                } else {
                    sceneList
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        // Scene list toolbar guide tip — placed in safeAreaInset so it doesn't
        // break the navigation title rendering.
        .safeAreaInset(edge: .top, spacing: 0) {
            if TipKitConfiguration.tipsEnabled {
                if !toolbarTipDismissed {
                    if isVerseNovel {
                        TipView(episodeListToolbarTip)
                    } else {
                        TipView(sceneListToolbarTip)
                    }
                } else {
                    VStack(spacing: 0) {
                        TipView(FolderOrganisationTip()) { action in
                            TipActionHandler.handle(action, guideSection: FolderOrganisationTip.guideSection)
                        }
                        // FR-5.3: Scene Info tip (shown in scene list)
                        TipView(SceneInfoTip()) { action in
                            TipActionHandler.handle(action, guideSection: SceneInfoTip.guideSection)
                        }
                    }
                }
            }
        }
        // When the toolbar tip is dismissed, donate the event so
        // FolderOrganisationTip becomes eligible to appear.
        .task {
            for await status in isVerseNovel ? episodeListToolbarTip.statusUpdates : sceneListToolbarTip.statusUpdates {
                if case .invalidated = status {
                    toolbarTipDismissed = true
                    FolderOrganisationTip.fileListToolbarTipDismissed.sendDonation()
                }
            }
        }
        // Use native iOS back button - immune to SwiftUI render blocking
        .navigationBarBackButtonHidden(false)
        .onPopToRoot {
            dismiss()
        }
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Chapter expand/collapse button (only when chapter grouping is active)
                if useChapterGrouping {
                    chapterExpandCollapseButton
                }
                
                // Act expand/collapse button (only when act grouping is active)
                if useActGrouping {
                    actExpandCollapseButton
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
                
                // Import button
                Button {
                    showImportPicker = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .accessibilityLabel(NSLocalizedString("sceneList.import.accessibility", comment: "Import document"))
                .disabled(editMode == .active)
                
                // Header/Footer button
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
            }
            
            // Bottom toolbar for multi-select actions
            ToolbarItemGroup(placement: .bottomBar) {
                if showToolbar {
                    bottomToolbarContent
                }
            }
        }
        .sheet(isPresented: $showAddScene) {
            AddSceneSheet(project: project, chapter: chapter, act: act, book: book)
        }
        .sheet(item: $selectedScene) { scene in
            SceneDetailView(scene: scene, project: project)
        }
        .sheet(isPresented: $showSearchView) {
            // Multi-file search across all scene files
            if let folder = scenesFolder {
                MultiFileSearchView(folder: folder, files: sceneFiles)
            }
        }
        .sheet(isPresented: $showHeaderFooterEditor) {
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
                        try? modelContext.save()
                    }
                    showHeaderFooterEditor = false
                }
            )
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
        .navigationDestination(item: $navigateToScene) { scene in
            // Navigate to file editor for the scene's associated text file
            if let textFile = scene.textFile {
                if project.type == .drama {
                    DramaSceneEditorView(file: textFile, project: project)
                } else {
                    FileEditView(file: textFile)
                }
            } else {
                // Scene has no file - show detail view to create one
                SceneDetailView(scene: scene, project: project)
            }
        }
        .confirmationDialog(
            scenesToDelete.count == 1
                ? (isVerseNovel
                    ? NSLocalizedString("fiction.episodes.deleteConfirm.title", comment: "Delete episode?")
                    : NSLocalizedString("fiction.scenes.deleteConfirm.title", comment: "Delete scene?"))
                : (isVerseNovel
                    ? String(format: NSLocalizedString("fiction.episodes.deleteMultiple.title", comment: "Delete episodes?"), scenesToDelete.count)
                    : String(format: NSLocalizedString("fiction.scenes.deleteMultiple.title", comment: "Delete scenes?"), scenesToDelete.count)),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
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
        } message: {
            Text(isVerseNovel
                ? NSLocalizedString("fiction.episodes.deleteConfirm.message.enhanced", comment: "Move to Trash keeps the episode's file, Delete Forever is permanent")
                : NSLocalizedString("fiction.scenes.deleteConfirm.message.enhanced", comment: "Move to Trash keeps the scene's file, Delete Forever is permanent"))
        }
        .onChange(of: editMode) { _, newValue in
            if newValue == .inactive {
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
            let sceneFiles = selectedScenes.compactMap { $0.textFile }
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
        .sheet(isPresented: $showSubmissionPicker) {
            NavigationStack {
                SubmissionPickerView(
                    project: project,
                    filesToSubmit: filesToSubmit,
                    collectionToSubmit: nil,
                    onPublicationSelected: { publication, name, expectedDate, reminderDate in
                        createSubmission(for: publication, name: name, expectedResponseDate: expectedDate, reminderDate: reminderDate)
                        showSubmissionPicker = false
                        exitEditMode()
                    },
                    onCancel: {
                        showSubmissionPicker = false
                    }
                )
            }
        }
        .onAppear {
            initializeHeaderFooterFields()
            
            // FR-5.4: Update Verse Novel tip parameter
            VerseNovelTip.isVerseNovel = isVerseNovel
            
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
        // Hidden when all selected scenes are still in draft
        if project.type == .drama && act == nil && chapter == nil {
            let hasNonDraft = selectedScenes.contains { $0.textFile?.workflowStatus != .draft }
            if hasNonDraft {
                Button {
                    showActPicker = true
                } label: {
                    Label(
                        NSLocalizedString("drama.scenes.addToAct", comment: "Add to Act"),
                        systemImage: "theatermasks"
                    )
                }
                .disabled(selectedScenes.isEmpty)
            }
        }
        
        // Add to Chapter/Story/Book button (Fiction projects, main scene list only)
        // Assigning to a chapter/story/book automatically sets the scene's status to ready
        // Hidden when all selected scenes are still in draft
        if project.type == .fiction && act == nil && chapter == nil {
            let hasNonDraft = selectedScenes.contains { $0.textFile?.workflowStatus != .draft }
            if hasNonDraft {
                let isShortFiction = fictionClass == .shortFiction
                Button {
                    showChapterPicker = true
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
                .disabled(selectedScenes.isEmpty)
            }
        }
        
        // Submit button — hidden when all selected scenes are still in draft
        if selectedScenes.contains(where: { $0.textFile?.workflowStatus != .draft }) {
            Button {
                filesToSubmit = selectedScenes.compactMap { $0.textFile }
                showSubmissionPicker = true
            } label: {
                Label(NSLocalizedString("submissions.button.submit", comment: "Submit"), systemImage: "paperplane")
            }
            .disabled(selectedScenes.isEmpty)
        }
        
        Spacer()
        
        Button(role: .destructive) {
            prepareDelete(selectedScenes)
        } label: {
            Label(
                String(format: isVerseNovel
                    ? NSLocalizedString("fiction.episodes.deleteCount", comment: "Delete count")
                    : NSLocalizedString("fiction.scenes.deleteCount", comment: "Delete count"), selectedScenes.count),
                systemImage: "trash"
            )
        }
        .disabled(selectedScenes.isEmpty)
        .accessibilityLabel(isVerseNovel
            ? NSLocalizedString("fiction.episodes.deleteSelected", comment: "Delete selected episodes")
            : NSLocalizedString("fiction.scenes.deleteSelected", comment: "Delete selected scenes"))
    }
    
    // MARK: - Scene List
    
    private var sceneList: some View {
        List {
            if useChapterGrouping, let groups = chapterGroups {
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
            } else if useActGrouping, let groups = actGroups {
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
        .listStyle(.plain)
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
            // Selection circle in edit mode
            if isEditMode {
                Image(systemName: selectedSceneIDs.contains(scene.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedSceneIDs.contains(scene.id) ? .blue : .gray)
                    .imageScale(.large)
            }
            
            SceneRowView(scene: scene)
            
            Spacer(minLength: 8)
            
            // Info button to show scene details
            if !isEditMode {
                Button {
                    selectedScene = scene
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditMode {
                toggleSelection(for: scene)
            } else {
                // Navigate directly to file editor
                navigateToScene = scene
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            // FR-5.1: Scenes & Chapters tip
            if TipKitConfiguration.tipsEnabled {
                TipView(ScenesAndChaptersTip()) { action in
                    TipActionHandler.handle(action, guideSection: ScenesAndChaptersTip.guideSection)
                }
                .padding(.horizontal)
            }
            
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
    
    private func toggleSelection(for scene: StoryScene) {
        if selectedSceneIDs.contains(scene.id) {
            selectedSceneIDs.remove(scene.id)
        } else {
            selectedSceneIDs.insert(scene.id)
        }
    }
    
    private func prepareDelete(_ scenes: [StoryScene]) {
        scenesToDelete = scenes
        showDeleteConfirmation = true
    }
    
    private func moveScenesToTrash(_ scenes: [StoryScene]) {
        for scene in scenes {
            // Soft delete the scene (marks as trashed)
            scene.moveToTrash()
        }
        
        try? modelContext.save()
        renumberScenes()
    }
    
    private func deleteScenesPermanently(_ scenes: [StoryScene]) {
        for scene in scenes {
            // Delete associated TextFile if exists
            if let textFile = scene.textFile {
                // Clean up index references before deleting
                FileMoveService.cleanupIndexReferences(for: textFile, context: modelContext)
                modelContext.delete(textFile)
            }
            // Delete the scene
            modelContext.delete(scene)
        }
        
        try? modelContext.save()
        renumberScenes()
    }
    
    private func moveScenes(from source: IndexSet, to destination: Int) {
        var scenes = sortedScenes
        scenes.move(fromOffsets: source, toOffset: destination)
        
        // Update order indices
        for (index, scene) in scenes.enumerated() {
            scene.userOrder = index
        }
        
        try? modelContext.save()
    }
    
    private func renumberScenes() {
        for (index, scene) in sortedScenes.enumerated() {
            scene.userOrder = index
        }
        try? modelContext.save()
    }
    
    private func exitEditMode() {
        withAnimation {
            editMode = .inactive
        }
    }
    
    // MARK: - Submission Actions
    
    private func createSubmission(for publication: Publication, name: String, expectedResponseDate: Date?, reminderDate: Date? = nil) {
        let submission = Submission(
            publication: publication,
            project: project,
            submittedDate: Date(),
            notes: nil
        )
        submission.name = name
        submission.isCollection = false
        submission.returnExpectedBy = expectedResponseDate
        
        // Schedule reminder notification if requested
        if let reminderDate = reminderDate {
            submission.reminderDate = reminderDate
            let pubName = publication.name
            let subName = name
            Task {
                let notifId = await NotificationReminderService.shared.scheduleSubmissionReminder(
                    submissionId: UUID().uuidString,
                    publicationName: pubName,
                    submissionName: subName,
                    reminderDate: reminderDate
                )
                if let notifId = notifId {
                    await MainActor.run {
                        submission.reminderNotificationId = notifId
                    }
                }
            }
        }
        
        modelContext.insert(submission)
        
        for file in filesToSubmit {
            if let currentVersion = file.currentVersion {
                let submittedFile = SubmittedFile(
                    submission: submission,
                    textFile: file,
                    version: currentVersion,
                    status: .pending,
                    statusDate: Date(),
                    project: project
                )
                modelContext.insert(submittedFile)
            }
        }
        
        try? modelContext.save()
        filesToSubmit = []
    }
    
    private func assignScenesToAct(_ scenes: [StoryScene], act: Act?) {
        for scene in scenes {
            scene.act = act
            // Automatically set status to ready when assigning to an act
            if act != nil, let textFile = scene.textFile {
                textFile.workflowStatus = .ready
            }
        }
        try? modelContext.save()
    }
    
    private func assignScenesToChapter(_ scenes: [StoryScene], chapter: Chapter?) {
        for scene in scenes {
            scene.chapter = chapter
            // Automatically set status to ready when assigning to a chapter/story
            if chapter != nil, let textFile = scene.textFile {
                textFile.workflowStatus = .ready
            }
        }
        try? modelContext.save()
    }

    private func changeScenesStatus(_ scenes: [StoryScene], to newStatus: WorkflowStatus) {
        for scene in scenes {
            if let textFile = scene.textFile {
                textFile.workflowStatus = newStatus
            }
        }
        try? modelContext.save()
    }
    
    // MARK: - Chapter Expand/Collapse Button
    
    @ViewBuilder
    private var chapterExpandCollapseButton: some View {
        let groups = chapterGroups ?? []
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
    private var actExpandCollapseButton: some View {
        let groups = actGroups ?? []
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
                    firstVersion.content = plainText
                    firstVersion.formattedContent = rtfData
                }
                
                modelContext.insert(newScene)
                modelContext.insert(textFile)
                try modelContext.save()
                
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                // Scene number
                if let userOrder = scene.userOrder {
                    Text("\(userOrder + 1).")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .frame(width: 30, alignment: .leading)
                }
                
                Text(scene.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
                    .font(.body)
                    .fontWeight(.semibold)
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
                
                if let location = scene.location {
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
