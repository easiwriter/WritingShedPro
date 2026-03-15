import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// A specialized EditableList for Project items
struct ProjectEditableList: View {
    @Environment(\.modelContext) private var modelContext
    let projects: [Project]
    @Binding var selectedSortOrder: SortOrder
    @Binding var isEditMode: Bool
    @State private var selectedProjectForInfo: Project?
    @State private var selectedProjectForPageSetup: Project?
    @State private var showingManageForms = false
    @State private var showingPoetrySettings = false
    @State private var showDeleteConfirmation = false
    @State private var projectsToDelete: IndexSet?
    @State private var deleteInfo: (count: Int, firstName: String)?
    
    // Export state
    @State private var projectToExport: Project?
    @State private var exportData: Data?
    @State private var exportFilename: String = ""
    @State private var showExportError = false
    @State private var exportErrorMessage = ""
    @State private var lastSeenNameByProjectID: [UUID: String] = [:]
    
    // Sort and display state
    private var sortedProjects: [Project] {
        ProjectSortService.sortProjects(projects, by: selectedSortOrder)
    }

    private var projectInventorySignature: String {
        sortedProjects.map { "\($0.id.uuidString):\($0.name ?? "")" }.joined(separator: "|")
    }

    private var exportPresentationBinding: Binding<Bool> {
        Binding(
            get: { exportData != nil },
            set: { if !$0 { exportData = nil; projectToExport = nil } }
        )
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
            .fileExporter(
                isPresented: exportPresentationBinding,
                document: exportData.map { ProjectExportDocument(data: $0) },
                contentType: UTType("com.writing-shed.wsp") ?? .json,
                defaultFilename: exportFilename,
                onCompletion: handleExportResult
            )
            .alert("Export Error", isPresented: $showExportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(exportErrorMessage)
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
        NavigationLink(value: project) {
            ProjectItemView(
                project: project,
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
                onExportTapped: {
                    exportProject(project)
                }
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Double tap to open project folders")
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

    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            #if DEBUG
            print("[ProjectExport] ✅ Exported to: \(url.path)")
            #endif
        case .failure(let error):
            #if DEBUG
            print("[ProjectExport] ❌ Export failed: \(error)")
            #endif
            exportErrorMessage = error.localizedDescription
            showExportError = true
        }
        exportData = nil
        projectToExport = nil
    }
    
    // MARK: - Export
    
    private func exportProject(_ project: Project) {
        do {
            let exportService = JSONExportService()
            let data = try exportService.exportProject(project)
            
            // Set filename and trigger file exporter
            exportFilename = "\(project.name ?? "Untitled").wsp"
            projectToExport = project
            exportData = data
            
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
        for index in offsets {
            guard index < sortedProjects.count else { continue }
            let project = sortedProjects[index]
            project.isTrashed = true
            project.deletedDate = Date()
        }
        try? modelContext.save()
        projectsToDelete = nil
        deleteInfo = nil
    }
    
    private func deleteProjectsPermanently() {
        guard let offsets = projectsToDelete else { return }
        for index in offsets {
            guard index < sortedProjects.count else { continue }
            let project = sortedProjects[index]
            modelContext.delete(project)
        }
        try? modelContext.save()
        projectsToDelete = nil
        deleteInfo = nil
        showDeleteConfirmation = false
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
        try? modelContext.save()
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
        let currentNamesByID = Dictionary(uniqueKeysWithValues: sortedProjects.map { ($0.id, $0.name ?? "") })

        if lastSeenNameByProjectID.isEmpty {
            lastSeenNameByProjectID = currentNamesByID
            print("[ProjectNameTransition] baselineCaptured at=\(now) reason=\(reason) count=\(currentNamesByID.count)")
            return
        }

        let throttler = CloudKitSyncThrottler.shared

        for project in sortedProjects {
            let id = project.id
            let newName = project.name ?? ""

            if let oldName = lastSeenNameByProjectID[id], oldName != newName {
                let lastSync = throttler.lastSyncTime?.description ?? "nil"
                print("[ProjectNameTransition] at=\(now) reason=\(reason) id=\(id.uuidString) old='\(oldName)' new='\(newName)' isSyncing=\(throttler.isSyncing) importInProgress=\(throttler.importInProgress) exportInProgress=\(throttler.exportInProgress) lastSync=\(lastSync)")
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
