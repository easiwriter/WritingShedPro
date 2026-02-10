//
//  ContentViewBody.swift
//  Writing Shed Pro
//
//  Extracted body view for ContentView to improve compilation time
//

import SwiftUI
import UniformTypeIdentifiers
import TipKit

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
    let onHandleImportMenu: () -> Void
    let onHandleJSONImport: (Result<[URL], Error>) -> Void
    let onDeleteAllProjects: () -> Void
    let onPrefetchProjectData: () -> Void
    let onRunMigrations: () -> Void
    
    @Environment(\.requestReview) var requestReview
    @Environment(\.modelContext) private var modelContext
    

    @State private var showProjectTrash = false

    private var trashedProjects: [Project] {
        projects.filter { $0.isTrashed == true }
    }

    private let toolbarGuideTip = ToolbarGuideTip()
    
    /// Show the toolbar guide tip on the first launch.
    /// Uses UserDefaults directly instead of TipKit @Parameter rules, which have
    /// unreliable persistence timing across launches.
    private var shouldShowToolbarTip: Bool {
        // configureTipKit increments AFTER reading, so by the time the view
        // appears the stored value is launchCount+1.
        // First launch: original count 0, stored as 1.
        let storedCount = UserDefaults.standard.integer(forKey: "tipkit.appLaunchCount")
        return storedCount == 1  // Was launchCount==0 before increment
    }

    var body: some View {
        NavigationStack(path: $state.navigationPath) {
            VStack(spacing: 0) {
                let activeProjects = projects.filter { !$0.isTrashed }
                
                ProjectEditableList(
                    projects: activeProjects,
                    selectedSortOrder: $state.selectedSortOrder,
                    isEditMode: Binding(
                        get: { state.editMode == .active },
                        set: { state.editMode = $0 ? .active : .inactive }
                    )
                )
                
                // Only show Trash bin button if there are trashed projects
                if !trashedProjects.isEmpty {
                    Button(action: { showProjectTrash = true }) {
                        Label(NSLocalizedString("projectTrash.title", comment: "Deleted Projects"), systemImage: "trash")
                    }
                    .padding(.vertical, 8)
                }
            }
            // FR-2.7: Toolbar Guide tip — placed in safeAreaInset so it doesn't
            // break the large navigation title rendering.
            // Display timing controlled by UserDefaults, dismiss state by TipKit.
            .safeAreaInset(edge: .top, spacing: 0) {
                if shouldShowToolbarTip && TipKitConfiguration.tipsEnabled {
                    TipView(toolbarGuideTip) { action in
                        switch action.id {
                        case "interface-tour":
                            GuideNavigationService.shared.openGuideSection("23-the-interface-tour")
                        case "settings-guide":
                            GuideNavigationService.shared.openGuideSection("25-application-settings")
                        default:
                            break
                        }
                    }
                }
            }
            .environment(\.editMode, $state.editMode)
            #if !targetEnvironment(macCatalyst)
            .preferredColorScheme(state.appearancePreferences.colorScheme)
            #endif
            .onAppear {
                onInitialize()
                
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
            }
            .onChange(of: projects.isEmpty) { _, isEmpty in
                if isEmpty && state.editMode == .active {
                    withAnimation {
                        state.editMode = .inactive
                    }
                }
            }
            .navigationTitle(NSLocalizedString("contentView.title", comment: "Title of projects list"))
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
                    onImport: onHandleImportMenu
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
            .sheet(isPresented: $state.showSyncDiagnostics) {
                SyncDiagnosticsView()
            }
            .sheet(isPresented: $state.showHTMLManual, onDismiss: {
                state.htmlManualSection = nil
            }) {
                HTMLManualView(section: state.htmlManualSection)
            }
            .alert(guideImportAlertTitle, isPresented: $state.showManualImportConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button(guideImportButtonTitle) {
                    importUserGuide()
                }
            } message: {
                Text(guideImportMessage)
            }
            .alert("Import Error", isPresented: $state.showManualImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(state.manualImportErrorMessage)
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
            #if DEBUG && (targetEnvironment(macCatalyst) || os(macOS))
            .alert("contentView.deleteAll.confirmTitle", isPresented: $state.showDeleteAllConfirmation) {
                Button("button.cancel", role: .cancel) { }
                Button("contentView.deleteAll", role: .destructive) {
                    onDeleteAllProjects()
                }
            } message: {
                Text("contentView.deleteAll.confirmMessage \(projects.count)")
            }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: .popToRootNavigation)) { _ in
            // Clear navigation path to pop all views to root
            state.navigationPath = NavigationPath()
        }
        .onReceive(NotificationCenter.default.publisher(for: GuideNavigationService.openGuideSectionNotification)) { notification in
            let section = notification.userInfo?["section"] as? String
            // Open in-app HTML manual sheet — uses WKWebView with JS scrollIntoView
            // for section navigation (works on both iOS and Catalyst).
            state.htmlManualSection = section
            state.showHTMLManual = true
        }
    }
    
    // MARK: - User Guide Import
    
    /// Check if the User Guide is already imported
    private var isGuideAlreadyImported: Bool {
        UserGuideImportService.isGuideImported(modelContext: modelContext)
    }
    
    /// Alert title depends on whether guide exists
    private var guideImportAlertTitle: String {
        isGuideAlreadyImported ? "Replace User Guide?" : "Import User Guide"
    }
    
    /// Button title depends on whether guide exists
    private var guideImportButtonTitle: String {
        isGuideAlreadyImported ? "Replace" : "Import"
    }
    
    /// Message depends on whether guide exists
    private var guideImportMessage: String {
        if isGuideAlreadyImported {
            return "This will delete your existing Writing Shed Pro Guide project and import a fresh copy. Any notes you added will be lost."
        } else {
            return "This will import the Writing Shed Pro Guide as an example project you can explore and annotate."
        }
    }
    
    /// Import the bundled User Guide project
    private func importUserGuide() {
        do {
            try UserGuideImportService.importGuide(modelContext: modelContext, replaceExisting: isGuideAlreadyImported)
        } catch {
            state.manualImportErrorMessage = error.localizedDescription
            state.showManualImportError = true
        }
    }
}
