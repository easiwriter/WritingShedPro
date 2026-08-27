//
//  ContentViewBody.swift
//  Writing Shed Pro
//
//  Extracted body view for ContentView to improve compilation time
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Custom UTTypes for Writing Shed files
extension UTType {
    /// Writing Shed legacy export format (.wsd)
    static var writingShedLegacy: UTType {
        UTType(importedAs: "com.writing-shed.wsd")
    }
    
    /// Writing Shed Pro project format (.wsp)
    static var writingShedPro: UTType {
        UTType(exportedAs: "com.writing-shed.wsp")
    }
}

struct ContentViewBody: View {
    let projects: [Project]
    @Bindable var state: ContentViewState
    
    let onInitialize: () -> Void
    let onInitializeStyleSheets: () -> Void
    let onSyncNow: () -> Void
    let onHandleImportMenu: () -> Void
    let onHandleJSONImport: (Result<[URL], Error>) -> Void
    let onPrefetchProjectData: () -> Void
    let onRunMigrations: () -> Void
    @Bindable var onboardingCoordinator: OnboardingCoordinator
    let onEvaluateOnboarding: () -> Void
    let onRestartOnboarding: () -> Void
    let onOpenProject: (Project) -> Void
    
    @Environment(\.requestReview) var requestReview
    @Environment(\.modelContext) private var modelContext
    

    @State private var showProjectTrash = false
    @State private var didProcessLaunchProjectRestore = false

    private var trashedProjects: [Project] {
        projects.filter { $0.isTrashed == true }
    }

    private var activeProjects: [Project] {
        return DeduplicationService.presentedProjects(
            from: projects.filter { !$0.isTrashed && !state.isProjectHidden($0.id) }
        )
    }

    private var visibleActiveProjectCount: Int {
        activeProjects.count
    }

    private var storedActiveProjectCount: Int {
        projects.filter { !$0.isTrashed }.count
    }

    private var shouldShowProjectTrashButton: Bool {
        !trashedProjects.isEmpty
    }

    var body: some View {
        navigationRoot
    }

    private var navigationRoot: some View {
        NavigationStack(path: $state.navigationPath) {
            navigationStackContent
        }
        .environment(state)
        .onReceive(NotificationCenter.default.publisher(for: GuideNavigationService.openGuideSectionNotification)) { notification in
            let section = notification.userInfo?["section"] as? String
            // Open in-app HTML manual sheet — uses WKWebView with JS scrollIntoView
            // for section navigation (works on both iOS and Catalyst).
            state.htmlManualSection = section
            state.showHTMLManual = true
        }
    }

    private var navigationStackContent: some View {
        projectListSection
            .environment(\.editMode, $state.editMode)
            #if !targetEnvironment(macCatalyst)
            .preferredColorScheme(state.appearancePreferences.colorScheme)
            #endif
            .onAppear {
                onInitialize()
                adoptUserOrderSortIfNeeded()
                
                // Initialize stylesheets in background (moved from Write_App)
                onInitializeStyleSheets()
                
                // Prefetch project data in background to prevent UI freeze
                onPrefetchProjectData()
                
                // Run data migrations for new features
                onRunMigrations()
                
                // Track app launch and check review in background to avoid blocking UI
                Task.detached(priority: .utility) {
                    ReviewManager.shared.recordAppLaunch()
                    
                    // Request review if appropriate (respects timing rules)
                    if ReviewManager.shared.shouldRequestReview() {
                        ReviewManager.shared.recordReviewRequest()
                        await MainActor.run {
                            requestReview()
                        }
                    }
                }

                restoreLastOpenedProjectIfNeeded()
                onEvaluateOnboarding()
            }
            .onChange(of: projects.count) { _, _ in
                adoptUserOrderSortIfNeeded()
                restoreLastOpenedProjectIfNeeded()
            }
            .onChange(of: projects.isEmpty) { _, isEmpty in
                if isEmpty && state.editMode == .active {
                    withAnimation {
                        state.editMode = .inactive
                    }
                }
            }
            #if targetEnvironment(macCatalyst)
            .navigationTitle("Writing Shed Pro")
            #else
            .navigationTitle(NSLocalizedString("contentView.title", comment: "Title of projects list"))
            #endif
            .toolbar {
                ContentViewToolbar(state: state, projects: projects, onHandleImportMenu: onHandleImportMenu)
            }
            .sheet(isPresented: $state.showAddProject) {
                AddProjectSheet(isPresented: $state.showAddProject)
            }
            .sheet(isPresented: $showProjectTrash) {
                ProjectTrashBinView()
            }
            .sheet(isPresented: $state.showSettings) {
                SettingsSheet(
                    isPresented: $state.showSettings,
                    state: state,
                    projects: projects,
                    onImport: onHandleImportMenu,
                    onSyncNow: onSyncNow,
                    onRestartOnboarding: onRestartOnboarding
                )
            }
            .sheet(isPresented: $state.showOnboarding) {
                OnboardingView(
                    coordinator: onboardingCoordinator,
                    onSkip: {
                        state.showOnboarding = false
                    },
                    onCreate: createOnboardingProjectAndFile
                )
            }
            .sheet(isPresented: $state.showManageStyles) {
                StyleSheetListView()
            }
            .sheet(isPresented: $state.showAbout) {
                AboutView()
            }
            .sheet(isPresented: $state.showStore) {
                StoreView()
            }
            .sheet(item: $state.projectForPageSetup) { project in
                PageSetupForm(project: project)
            }
            .sheet(isPresented: $state.showContactSupport) {
                ContactSupportView()
            }
            .sheet(isPresented: $state.showSupportMessages) {
                SupportMessagesView()
            }
            .sheet(isPresented: $state.showSyncDiagnostics) {
                SyncDiagnosticsView()
            }
            .sheet(isPresented: $state.showHTMLManual, onDismiss: {
                state.htmlManualSection = nil
            }) {
                HTMLManualView(section: state.htmlManualSection)
                    .presentationDetents([.large])
                    .modifier(PagePresentationSizingModifier())
            }
            .fileImporter(
                isPresented: $state.showingJSONImportPicker,
                allowedContentTypes: [
                    .writingShedLegacy,
                    .writingShedPro,
                    .json
                ],
                allowsMultipleSelection: false
            ) { result in
                onHandleJSONImport(result)
            }
            .alert("contentView.importError.title", isPresented: $state.showImportError) {
                Button("button.ok", role: .cancel) { }
            } message: {
                Text(state.importErrorMessage)
            }
            .alert(NSLocalizedString("messages.launchAlert.title", comment: ""), isPresented: $state.showNewSupportMessagesAlert) {
                Button(NSLocalizedString("messages.launchAlert.open", comment: "")) {
                    SupportMessagesService().acknowledgeNewMessageAlert(state.pendingSupportMessageAlertVersions)
                    state.pendingSupportMessageAlertVersions = [:]
                    state.showSupportMessages = true
                }
                Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) {
                    SupportMessagesService().acknowledgeNewMessageAlert(state.pendingSupportMessageAlertVersions)
                    state.pendingSupportMessageAlertVersions = [:]
                }
            } message: {
                Text(NSLocalizedString("messages.launchAlert.body", comment: ""))
            }
            .navigationDestination(for: TextFile.self) { file in
                editorDestination(for: file)
                    .alert(NSLocalizedString("onboarding.editorIntro.title", comment: "Editor introduction title"), isPresented: $state.showOnboardingEditorIntro) {
                        Button(NSLocalizedString("button.ok", comment: "OK"), role: .cancel) {
                            onboardingCoordinator.markEditorIntroShown()
                        }
                    } message: {
                        Text(NSLocalizedString("onboarding.editorIntro.body", comment: "Editor introduction body"))
                    }
            }
            .navigationDestination(for: ProjectContentRoute.self) { route in
                projectContentDestination(for: route)
            }
    }

    private var projectListSection: some View {
        VStack(spacing: 0) {
            if state.hideAllProjects && storedActiveProjectCount > visibleActiveProjectCount {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Projects are hidden")
                        .font(.headline)
                    Text("\(storedActiveProjectCount - visibleActiveProjectCount) project(s) are hidden by the demo visibility setting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        state.showAllProjects()
                    } label: {
                        Label("Show Hidden Projects", systemImage: "eye")
                    }
                }
                .padding()
            }

            ProjectEditableList(
                projects: activeProjects,
                selectedSortOrder: $state.selectedSortOrder,
                isEditMode: Binding(
                    get: { state.editMode == .active },
                    set: { state.editMode = $0 ? .active : .inactive }
                ),
                onOpenProject: onOpenProject
            )

            if shouldShowProjectTrashButton {
                Button(action: { showProjectTrash = true }) {
                    Label(NSLocalizedString("projectTrash.title", comment: "Deleted Projects"), systemImage: "trash")
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func restoreLastOpenedProjectIfNeeded() {
        guard !didProcessLaunchProjectRestore else { return }

        guard state.navigationPath.count == 0 else { return }
        guard state.autoOpenLastProjectOnLaunch else {
            didProcessLaunchProjectRestore = true
            return
        }
        guard let projectID = state.lastOpenedProjectID,
              let project = projects.first(where: { $0.id == projectID }),
              !state.isProjectHidden(project.id) else {
            didProcessLaunchProjectRestore = true
            return
        }

        state.showProject(project, rememberForResume: false)
        didProcessLaunchProjectRestore = true
    }

    private func adoptUserOrderSortIfNeeded() {
        guard let preferredSortOrder = ProjectSortService.preferredDefaultSortOrder(
            for: projects,
            hasStoredSortOrder: state.hasStoredSortOrder
        ) else {
            return
        }

        if state.selectedSortOrder != preferredSortOrder {
            state.selectedSortOrder = preferredSortOrder
        }
    }

    @ViewBuilder
    private func editorDestination(for file: TextFile) -> some View {
        let isNamedCoverInMatterFolder = (file.parentFolder?.isFrontMatterFolder == true || file.parentFolder?.isBackMatterFolder == true)
            && (file.name == FrontMatterItem.frontCover.fileName || file.name == BackMatterItem.backCover.fileName)

        if let project = file.project,
           project.type == .drama,
           let folder = file.parentFolder,
           FolderCapabilityService.isContentFolder(folder) {
            DramaSceneEditorView(file: file, project: project)
        } else if file.isCoverFile || isNamedCoverInMatterFolder {
            CoverImageEditorView(file: file)
        } else if let project = file.project,
                  BackMatterGeneratedContentView.isGeneratedBackMatterFile(file) {
            BackMatterGeneratedContentView(file: file, project: project)
        } else {
            FileEditView(file: file)
        }
    }

    @ViewBuilder
    private func projectContentDestination(for route: ProjectContentRoute) -> some View {
        if let project = projects.first(where: { $0.id == route.projectID }) {
            switch project.type {
            case .prose:
                ProseListView(project: project)
            case .poetry:
                if let poemsFolder = contentFolder(named: "Poems", for: project) {
                    FolderFilesView(folder: poemsFolder)
                } else {
                    ContentUnavailableView(
                        NSLocalizedString("folder.notFound.title", comment: "Folder not found"),
                        systemImage: "folder.badge.questionmark"
                    )
                }
            case .fiction, .drama:
                SceneListView(project: project)
            }
        }
    }

    private func contentFolder(named name: String, for project: Project) -> Folder? {
        let projectID = project.id
        let descriptor = FetchDescriptor<Folder>(
            predicate: #Predicate<Folder> { folder in
                folder.name == name && folder.project?.id == projectID
            }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func createOnboardingProjectAndFile(_ defaults: OnboardingDefaults, projectName: String, fileName: String) throws {
        let (project, file) = try OnboardingCreationService.createStarterProjectAndFile(
            defaults: defaults,
            projectName: projectName,
            fileName: fileName,
            allProjects: projects,
            modelContext: modelContext
        )

        onboardingCoordinator.markCompleted()
        state.showOnboarding = false
        state.showProjectAndFile(project, file: file)

        guard !onboardingCoordinator.hasShownEditorIntro else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            state.showOnboardingEditorIntro = true
        }
    }
}
