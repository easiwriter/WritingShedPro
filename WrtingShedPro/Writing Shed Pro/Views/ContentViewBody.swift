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
    @Binding var selectedSortOrder: ProjectSortService.SortOrder
    @Binding var editMode: EditMode
    @Binding var showAddProject: Bool
    @Binding var showManageStyles: Bool
    @Binding var showAbout: Bool
    @Binding var showPageSetup: Bool
    @Binding var showContactSupport: Bool
    @Binding var showDeleteAllConfirmation: Bool
    @Binding var showSyncDiagnostics: Bool
    @Binding var showImportOptions: Bool
    @Binding var showLegacyProjectPicker: Bool
    @Binding var showingJSONImportPicker: Bool
    @Binding var showImportError: Bool
    
    let isImporting: Bool
    let appearancePreferences: AppearancePreferences
    let availableLegacyProjects: [LegacyProjectData]
    let importErrorMessage: String
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
                if isImporting {
                    ImportProgressBanner(progressTracker: importService.getProgressTracker())
                }
                
                ProjectEditableList(
                    projects: projects,
                    selectedSortOrder: $selectedSortOrder,
                    isEditMode: Binding(
                        get: { editMode == .active },
                        set: { editMode = $0 ? .active : .inactive }
                    )
                )
            }
            .environment(\.editMode, $editMode)
            #if !targetEnvironment(macCatalyst)
            .preferredColorScheme(appearancePreferences.colorScheme)
            #endif
            .onAppear {
                onInitialize()
                onCheckImport()
            }
            .onChange(of: projects.isEmpty) { _, isEmpty in
                if isEmpty && editMode == .active {
                    withAnimation {
                        editMode = .inactive
                    }
                }
            }
            .navigationTitle(NSLocalizedString("contentView.title", comment: "Title of projects list"))
            .toolbar {
                ContentViewToolbar(
                    showSettings: $showImportOptions,
                    showAddProject: $showAddProject,
                    showAbout: $showAbout,
                    showManageStyles: $showManageStyles,
                    showPageSetup: $showPageSetup,
                    showContactSupport: $showContactSupport,
                    showDeleteAllConfirmation: $showDeleteAllConfirmation,
                    showSyncDiagnostics: $showSyncDiagnostics,
                    showImportMenu: $showImportOptions,
                    selectedSortOrder: $selectedSortOrder,
                    editMode: $editMode,
                    projects: projects
                )
            }
            .sheet(isPresented: $showAddProject) {
                AddProjectSheet(isPresented: $showAddProject)
            }
            .sheet(isPresented: $showManageStyles) {
                StyleSheetListView()
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            .sheet(isPresented: $showPageSetup) {
                PageSetupForm()
            }
            .sheet(isPresented: $showContactSupport) {
                ContactSupportView()
            }
            .sheet(isPresented: $showSyncDiagnostics) {
                SyncDiagnosticsView()
            }
            .sheet(isPresented: $showLegacyProjectPicker) {
                LegacyProjectPickerView(
                    availableProjects: availableLegacyProjects,
                    isPresented: $showLegacyProjectPicker,
                    onImport: { selectedProjects in
                        onImportSelectedProjects(selectedProjects)
                    }
                )
            }
            .confirmationDialog("Choose Import Source", isPresented: $showImportOptions) {
                let displayCount = importService.getDisplayableProjectCount(availableLegacyProjects)
                if displayCount > 0 {
                    Button("Import from Writing Shed (\(displayCount) available)") {
                        showLegacyProjectPicker = true
                    }
                }
                Button("Import from File...") {
                    showingJSONImportPicker = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                let displayCount = importService.getDisplayableProjectCount(availableLegacyProjects)
                if displayCount > 0 {
                    Text("Choose where to import projects from")
                } else {
                    Text("No Writing Shed projects to import")
                }
            }
            .fileImporter(
                isPresented: $showingJSONImportPicker,
                allowedContentTypes: [
                    UTType(filenameExtension: "wsd") ?? .data,
                    .json
                ],
                allowsMultipleSelection: false
            ) { result in
                onHandleJSONImport(result)
            }
            .alert("contentView.importError.title", isPresented: $showImportError) {
                Button("button.ok", role: .cancel) { }
            } message: {
                Text(importErrorMessage)
            }
            #if DEBUG && (targetEnvironment(macCatalyst) || os(macOS))
            .alert("contentView.deleteAll.confirmTitle", isPresented: $showDeleteAllConfirmation) {
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
