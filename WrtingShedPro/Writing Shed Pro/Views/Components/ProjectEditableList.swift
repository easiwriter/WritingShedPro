import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// A specialized EditableList for Project items
struct ProjectEditableList: View {
    private enum ProjectExportTarget {
        case share
        case saveAs
    }

    @Environment(\.modelContext) private var modelContext
    let projects: [Project]
    @Binding var selectedSortOrder: SortOrder
    @Binding var isEditMode: Bool
    let onOpenProject: (Project) -> Void
    @State private var selectedProjectForInfo: Project?
    @State private var selectedProjectForPageSetup: Project?
    @State private var showingManageForms = false
    @State private var showingPoetrySettings = false
    @State private var showDeleteConfirmation = false
    @State private var projectsToDelete: IndexSet?
    @State private var deleteInfo: (count: Int, firstName: String)?
    
    // Export state
    @State private var projectToExport: Project?
    @State private var projectForExportOptions: Project?
    @State private var exportData: Data?
    @State private var exportFilename: String = ""
    @State private var showExportSaveDialog = false
    @State private var shareableFileURL: URL?
    @State private var showShareSheet = false
    @State private var showExportError = false
    @State private var exportErrorMessage = ""
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""
    @State private var upgradePromptReason: UpgradePromptReason?
    @State private var lastSeenNameByProjectID: [UUID: String] = [:]
    @Query private var allProjects: [Project]
    
    // Sort and display state
    private var sortedProjects: [Project] {
        ProjectSortService.sortProjects(projects, by: selectedSortOrder)
    }

    private var projectInventorySignature: String {
        sortedProjects.map { "\($0.id.uuidString):\($0.name ?? "")" }.joined(separator: "|")
    }

    private var duplicateIDs: Set<UUID> {
        DeduplicationService.duplicateProjectIDs(in: projects)
    }

    var body: some View {
        projectListView
            .navigationDestination(for: Project.self) { project in
                ProjectDetailView(project: project)
            }
            .onChange(of: projects.isEmpty) { _, isEmpty in
                if isEmpty && isEditMode {
                    withAnimation {
                        isEditMode = false
                    }
                }
            }
            .onAppear {
                trackProjectNameTransitions(reason: "onAppear")
                logProjectInventory(reason: "onAppear")
            }
            .onChange(of: projectInventorySignature) { _, _ in
                trackProjectNameTransitions(reason: "inventoryChanged")
                logProjectInventory(reason: "inventoryChanged")
            }
            .sheet(item: $selectedProjectForInfo) { project in
                projectInfoSheet(project)
            }
            .sheet(item: $selectedProjectForPageSetup) { project in
                PageSetupForm(project: project)
            }
            .sheet(isPresented: $showingManageForms) {
                PoetryFormManagementView()
            }
            .sheet(isPresented: $showingPoetrySettings) {
                PoetrySettingsSheet()
            }
            .sheet(isPresented: $showShareSheet) {
                if let fileURL = shareableFileURL {
                    ShareSheet(urls: [fileURL])
                }
            }
            .fileExporter(
                isPresented: $showExportSaveDialog,
                document: exportData.map { ProjectExportDocument(data: $0) },
                contentType: UTType("com.writing-shed.wsp") ?? .json,
                defaultFilename: exportFilename,
                onCompletion: handleSaveAsResult
            )
            .alert("Export Error", isPresented: $showExportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(exportErrorMessage)
            }
            .alert(NSLocalizedString("project.deleteForever.saveFailed.title", comment: "Delete failed"), isPresented: $showDeleteError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteErrorMessage)
            }
            .upgradePrompt(reason: $upgradePromptReason) {
                // User can retry the original action after upgrading.
            }
            .confirmationDialog(
                NSLocalizedString("projectItem.exportProject", comment: "Export project"),
                isPresented: Binding(
                    get: { projectForExportOptions != nil },
                    set: { if !$0 { projectForExportOptions = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("manuscript.share", comment: "Share")) {
                    guard let project = projectForExportOptions else { return }
                    projectForExportOptions = nil
                    exportProject(project)
                }
                Button(NSLocalizedString("manuscript.saveAs", comment: "Save As…")) {
                    guard let project = projectForExportOptions else { return }
                    projectForExportOptions = nil
                    saveAsProject(project)
                }
                Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                    projectForExportOptions = nil
                }
            }
            .confirmationDialog(
                Text(NSLocalizedString("projectEditableList.deleteTitle", comment: "Delete project(s) confirmation dialog title")),
                isPresented: $showDeleteConfirmation,
                presenting: deleteInfo,
                actions: { _ in
                    Button(NSLocalizedString("projectEditableList.delete", comment: "Delete button"), role: .destructive) {
                        moveProjectsToTrash()
                    }
                    Button(NSLocalizedString("projectEditableList.deleteForever", comment: "Delete Forever button"), role: .destructive) {
                        deleteProjectsPermanently()
                    }
                    Button(NSLocalizedString("button.cancel", comment: "Cancel button"), role: .cancel) {
                        projectsToDelete = nil
                        deleteInfo = nil
                    }
                },
                message: { _ in
                    Text(NSLocalizedString("projectEditableList.deleteMessage", comment: "Delete projects message"))
                }
            )
    }

    private var projectListView: some View {
        List {
            ForEach(sortedProjects) { project in
                projectRow(project)
            }
            .onDelete(perform: deleteProjects)
            .onMove(perform: moveProjects)
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(isEditMode ? .active : .inactive))
    }

    private func projectRow(_ project: Project) -> some View {
        ProjectItemView(
            project: project,
            onOpenTapped: {
                onOpenProject(project)
            },
            onInfoTapped: {
                selectedProjectForInfo = project
            },
            onPageSetupTapped: {
                selectedProjectForPageSetup = project
            },
            onManageFormsTapped: project.type == .poetry ? {
                showingManageForms = true
            } : nil,
            onPoetrySettingsTapped: (project.type == .poetry || (project.type == .fiction && project.fictionClass == .verseNovel)) ? {
                showingPoetrySettings = true
            } : nil,
            onDuplicateTapped: {
                duplicateProject(project)
            },
            onExportTapped: {
                projectForExportOptions = project
            },
            isDuplicate: duplicateIDs.contains(project.id)
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }

    private func projectInfoSheet(_ project: Project) -> some View {
        ProjectInfoSheet(
            project: project,
            isPresented: Binding(
                get: { selectedProjectForInfo != nil },
                set: { if !$0 { selectedProjectForInfo = nil } }
            ),
            showDeleteConfirmation: .constant(false),
            errorMessage: .constant(""),
            showErrorAlert: .constant(false)
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func handleSaveAsResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            #if DEBUG
            print("[ProjectExport] ✅ Saved to: \(url.path)")
            #endif
        case .failure(let error):
            #if DEBUG
            print("[ProjectExport] ❌ Save failed: \(error)")
            #endif
            exportErrorMessage = error.localizedDescription
            showExportError = true
        }
        exportData = nil
        projectToExport = nil
    }

    private func shareExportedProject(data: Data, filename: String) {
        if let fileURL = ShareService.shared.createShareableFile(
            data: data,
            filename: filename,
            contentType: UTType("com.writing-shed.wsp") ?? .json
        ) {
            shareableFileURL = fileURL
            showShareSheet = true
        } else {
            exportErrorMessage = NSLocalizedString("export.error.failed", comment: "Export failed")
            showExportError = true
        }
    }
    
    // MARK: - Export
    
    private func exportProject(_ project: Project) {
        if !EntitlementManager.shared.canExport(projectType: project.type) {
            upgradePromptReason = .exportBlocked(projectType: project.type)
            return
        }

        do {
            let exportService = JSONExportService()
            let data = try exportService.exportProject(project)
            
            // Default project export action is Share
            exportFilename = "\(project.name ?? "Untitled").wsp"
            projectToExport = project
            exportData = data
            shareExportedProject(data: data, filename: exportFilename)
            
            #if DEBUG
            print("[ProjectExport] Prepared export for: \(project.name ?? "Untitled") (\(data.count) bytes)")
            #endif
        } catch {
            #if DEBUG
            print("[ProjectExport] ❌ Export preparation failed: \(error)")
            #endif
            exportErrorMessage = error.localizedDescription
            showExportError = true
        }
    }

    private func saveAsProject(_ project: Project) {
        if !EntitlementManager.shared.canExport(projectType: project.type) {
            upgradePromptReason = .exportBlocked(projectType: project.type)
            return
        }

        do {
            let exportService = JSONExportService()
            let data = try exportService.exportProject(project)

            exportFilename = "\(project.name ?? "Untitled").wsp"
            projectToExport = project
            exportData = data
            showExportSaveDialog = true
        } catch {
            exportErrorMessage = error.localizedDescription
            showExportError = true
        }
    }

    private func duplicateProject(_ project: Project) {
        let existingProjectsOfType = ProjectGateCounterService.activeProjectCount(
            ofType: project.type,
            in: allProjects
        )
        if !EntitlementManager.shared.canCreateProject(ofType: project.type, existingCount: existingProjectsOfType) {
            upgradePromptReason = .projectLimit(projectType: project.type)
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("project-duplicate-\(UUID().uuidString)")
            .appendingPathExtension("wsp")

        do {
            let exportService = JSONExportService()
            let data = try exportService.exportProject(project)
            try data.write(to: tempURL, options: .atomic)

            let errorHandler = ImportErrorHandler()
            DeduplicationService.pauseZombieDeletion(for: 45)
            let importService = JSONImportService(
                modelContext: modelContext,
                errorHandler: errorHandler,
                generateNewUUIDs: true
            )

            _ = try importService.importFromJSON(fileURL: tempURL)
            WriteCoalescer.shared?.requestSave(reason: "project-duplicate-import")
            WriteCoalescer.shared?.flush()
        } catch {
            exportErrorMessage = error.localizedDescription
            showExportError = true
        }

        try? FileManager.default.removeItem(at: tempURL)
    }
    
    // MARK: - Delete
    
    private func deleteProjects(at offsets: IndexSet) {
        // Safely capture project information before showing dialog
        guard let firstIndex = offsets.first, firstIndex < sortedProjects.count else {
            return
        }
        
        projectsToDelete = offsets
        
        // Store count and first project name for the confirmation message
        let firstName = sortedProjects[firstIndex].name ?? "Untitled Project"
        deleteInfo = (count: offsets.count, firstName: firstName)
        
        showDeleteConfirmation = true
    }
    
    private func moveProjectsToTrash() {
        guard let offsets = projectsToDelete else { return }
        guard canPerformProjectDeletion(reason: "project-list-trash") else { return }
        let deletedAt = Date()
        let projects = offsets.compactMap { index in
            index < sortedProjects.count ? sortedProjects[index] : nil
        }

        guard !projects.isEmpty else { return }

        for index in offsets {
            guard index < sortedProjects.count else { continue }
            let project = sortedProjects[index]
            DeduplicationService.trashProjectFamily(project, context: modelContext, deletedAt: deletedAt)
        }
        do {
            try WriteCoalescer.shared.requestSaveAndFlush(reason: "project-list-trash")
        } catch {
            for project in projects {
                DeduplicationService.restoreProjectFamily(project, context: modelContext)
            }
            deleteErrorMessage = String(
                format: NSLocalizedString("project.deleteForever.saveFailed.message", comment: "Delete failed message"),
                error.localizedDescription
            )
            showDeleteError = true
            return
        }
        projectsToDelete = nil
        deleteInfo = nil
        showDeleteConfirmation = false
    }
    
    private func deleteProjectsPermanently() {
        guard let offsets = projectsToDelete else { return }
        guard canPerformProjectDeletion(reason: "project-editable-list-permanent-delete") else { return }
        for index in offsets {
            guard index < sortedProjects.count else { continue }
            let project = sortedProjects[index]
            DeduplicationService.permanentlyDeleteProjectFamily(project, context: modelContext)
        }
        do {
            try WriteCoalescer.shared.requestSaveAndFlush(reason: "project-editable-list-permanent-delete")
        } catch {
            deleteErrorMessage = String(
                format: NSLocalizedString("project.deleteForever.saveFailed.message", comment: "Delete failed message"),
                error.localizedDescription
            )
            showDeleteError = true
            return
        }
        projectsToDelete = nil
        deleteInfo = nil
        showDeleteConfirmation = false
    }

    private func canPerformProjectDeletion(reason: String) -> Bool {
        guard let ensemblesContainer = Write_App.activeEnsemblesContainer,
              !EnsemblesSaveGate.canSaveNow(reason: reason) else {
            return true
        }

        let error = EnsemblesSaveGateError.syncBusy(
            reason: reason,
            attached: ensemblesContainer.isAttached,
            activity: String(describing: ensemblesContainer.currentActivity)
        )
        deleteErrorMessage = String(
            format: NSLocalizedString("project.deleteForever.saveFailed.message", comment: "Delete failed message"),
            error.localizedDescription
        )
        showDeleteError = true
        return false
    }
    
    private func moveProjects(from source: IndexSet, to destination: Int) {
        // Capture the current display order BEFORE switching sort modes.
        // sortedProjects reads selectedSortOrder through the binding, so changing
        // it first would sort by userOrder instead of what the List was showing,
        // making the .onMove indices refer to the wrong items.
        let currentOrder = sortedProjects

        // If not in User's Order mode, automatically switch to it when user drags
        if selectedSortOrder != .byUserOrder {
            selectedSortOrder = .byUserOrder
        }

        // Use the service method which properly reindexes all userOrder values
        _ = ProjectSortService.updateUserOrder(for: currentOrder, movedFromOffsets: source, toOffset: destination)

        // Save the changes
        WriteCoalescer.shared?.requestSave(reason: "project-list-reorder")
        WriteCoalescer.shared?.flush()
    }

    private func logProjectInventory(reason: String) {
        #if DEBUG
        print("[ProjectListDiagnostic] reason=\(reason) count=\(sortedProjects.count) sort=\(selectedSortOrder.rawValue)")
        for project in sortedProjects {
            print("[ProjectListDiagnostic] id=\(project.id.uuidString) | name=\(project.name ?? "") | userOrder=\(project.userOrder.map(String.init) ?? "nil") | trashed=\(project.isTrashed)")
        }
        #endif
    }

    private func trackProjectNameTransitions(reason: String) {
        #if DEBUG
        let now = ISO8601DateFormatter().string(from: Date())
        var currentNamesByID: [UUID: String] = [:]
        for project in sortedProjects {
            if currentNamesByID[project.id] == nil {
                currentNamesByID[project.id] = project.name ?? ""
            } else {
                print("[ProjectNameTransition] duplicateID id=\(project.id.uuidString) name=\(project.name ?? "") reason=\(reason)")
            }
        }

        if lastSeenNameByProjectID.isEmpty {
            lastSeenNameByProjectID = currentNamesByID
            print("[ProjectNameTransition] baselineCaptured at=\(now) reason=\(reason) count=\(currentNamesByID.count)")
            return
        }

        for project in sortedProjects {
            let id = project.id
            let newName = project.name ?? ""

            if let oldName = lastSeenNameByProjectID[id], oldName != newName {
                print("[ProjectNameTransition] at=\(now) reason=\(reason) id=\(id.uuidString) old='\(oldName)' new='\(newName)'")
            } else if lastSeenNameByProjectID[id] == nil {
                print("[ProjectNameTransition] at=\(now) reason=\(reason) id=\(id.uuidString) added name='\(newName)'")
            }
        }

        let removedIDs = Set(lastSeenNameByProjectID.keys).subtracting(currentNamesByID.keys)
        for removedID in removedIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
            let oldName = lastSeenNameByProjectID[removedID] ?? ""
            print("[ProjectNameTransition] at=\(now) reason=\(reason) id=\(removedID.uuidString) removed old='\(oldName)'")
        }

        lastSeenNameByProjectID = currentNamesByID
        #endif
    }
}
