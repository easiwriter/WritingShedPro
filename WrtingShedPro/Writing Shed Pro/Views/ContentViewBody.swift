//
//  ContentViewBody.swift
//  Writing Shed Pro
//
//  Extracted body view for ContentView to improve compilation time
//

import SwiftUI
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
    let onHandleImportMenu: () -> Void
    let onHandleJSONImport: (Result<[URL], Error>) -> Void
    let onDeleteAllProjects: () -> Void
    let onPrefetchProjectData: () -> Void
    let onRunMigrations: () -> Void
    
    @Environment(\.requestReview) var requestReview
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack(path: $state.navigationPath) {
            VStack(spacing: 0) {
                ProjectEditableList(
                    projects: projects,
                    selectedSortOrder: $state.selectedSortOrder,
                    isEditMode: Binding(
                        get: { state.editMode == .active },
                        set: { state.editMode = $0 ? .active : .inactive }
                    )
                )
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
            .sheet(isPresented: $state.showManageStyles) {
                StyleSheetListView()
            }
            .sheet(isPresented: $state.showAbout) {
                AboutView()
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
            .sheet(isPresented: $state.showHTMLManual) {
                HTMLManualView()
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
