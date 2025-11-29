//
//  ContentViewBody.swift
//  Writing Shed Pro
//
//  Extracted body view for ContentView to improve compilation time
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentViewBody: View {
    let projects: [Project]
    @ObservedObject var state: ContentViewState
    let importService: ImportService
    
    let onInitialize: () -> Void
    let onCheckImport: () -> Void
    let onHandleImportMenu: () -> Void
    let onImportSelectedProjects: ([LegacyProjectData]) -> Void
    let onHandleJSONImport: (Result<[URL], Error>) -> Void
    let onDeleteAllProjects: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if state.isImporting {
                    ImportProgressBanner(progressTracker: importService.getProgressTracker())
                }
                
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
                onCheckImport()
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
                ContentViewToolbar(state: state, projects: projects)
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
            .sheet(isPresented: $state.showPageSetup) {
                PageSetupForm()
            }
            .sheet(isPresented: $state.showContactSupport) {
                ContactSupportView()
            }
            .sheet(isPresented: $state.showSyncDiagnostics) {
                SyncDiagnosticsView()
            }
            .sheet(isPresented: $state.showLegacyProjectPicker) {
                LegacyProjectPickerView(
                    availableProjects: state.availableLegacyProjects,
                    isPresented: $state.showLegacyProjectPicker,
                    onImport: { selectedProjects in
                        onImportSelectedProjects(selectedProjects)
                    }
                )
            }
            .confirmationDialog("Choose Import Source", isPresented: $state.showImportOptions) {
                let displayCount = importService.getDisplayableProjectCount(state.availableLegacyProjects)
                if displayCount > 0 {
                    Button("Import from Writing Shed (\(displayCount) available)") {
                        state.showLegacyProjectPicker = true
                    }
                }
                Button("Import from File...") {
                    state.showingJSONImportPicker = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                let displayCount = importService.getDisplayableProjectCount(state.availableLegacyProjects)
                if displayCount > 0 {
                    Text("Choose where to import projects from")
                } else {
                    Text("No Writing Shed projects to import")
                }
            }
            .fileImporter(
                isPresented: $state.showingJSONImportPicker,
                allowedContentTypes: [
                    UTType(filenameExtension: "wsd") ?? .data,
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
    }
}
