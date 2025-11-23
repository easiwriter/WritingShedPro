import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @Query var projects: [Project]
    @State private var showAddProject = false
    @State private var showManageStyles = false
    @State private var isImporting = false
    @State private var importService = ImportService()
    @State private var showingJSONImportPicker = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    @State private var showDeleteAllConfirmation = false
    @Environment(\.modelContext) var modelContext
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Simple import progress banner at top
                if isImporting {
                    ImportProgressBanner(progressTracker: importService.getProgressTracker())
                }
                
                ProjectEditableList(projects: projects)
            }
            .onAppear {
                initializeUserOrderIfNeeded()
                checkForImport()
            }
            .navigationTitle(NSLocalizedString("contentView.title", comment: "Title of projects list"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showManageStyles = true }) {
                        Label("contentView.manageStylesheets", systemImage: "paintbrush")
                    }
                    .accessibilityLabel("contentView.manageStylesheets.accessibility")
                }
                
                #if DEBUG
                // Delete all projects button (debug only)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive, action: { showDeleteAllConfirmation = true }) {
                        Label("contentView.deleteAll", systemImage: "trash")
                    }
                    .accessibilityLabel("contentView.deleteAll.accessibility")
                }
                #endif
                
                #if DEBUG && (targetEnvironment(macCatalyst) || os(macOS))
                // Re-import only available on Mac where legacy database is accessible
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { triggerReimport() }) {
                        Label("contentView.reimport", systemImage: "arrow.trianglehead.2.clockwise")
                    }
                    .accessibilityLabel("contentView.reimport.accessibility")
                }
                #endif
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingJSONImportPicker = true }) {
                        Label(NSLocalizedString("contentView.import", comment: "Import button label"), systemImage: "arrow.down.doc")
                    }
                    .accessibilityLabel(NSLocalizedString("contentView.importAccessibility", comment: "Accessibility label for import button"))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddProject = true }) {
                        Label(NSLocalizedString("contentView.addProject", comment: "Button to add new project"), systemImage: "plus")
                    }
                    .accessibilityLabel(NSLocalizedString("contentView.addProjectAccessibility", comment: "Accessibility label for add project button"))
                }
            }
            .sheet(isPresented: $showAddProject) {
                AddProjectSheet(isPresented: $showAddProject)
            }
            .sheet(isPresented: $showManageStyles) {
                StyleSheetListView()
            }
            .fileImporter(
                isPresented: $showingJSONImportPicker,
                allowedContentTypes: [
                    UTType(filenameExtension: "wsd") ?? .data,
                    .json
                ],
                allowsMultipleSelection: false
            ) { result in
                handleJSONImport(result)
            }
            .alert("contentView.importError.title", isPresented: $showImportError) {
                Button("button.ok", role: .cancel) { }
            } message: {
                Text(importErrorMessage)
            }
            .alert("contentView.deleteAll.confirmTitle", isPresented: $showDeleteAllConfirmation) {
                Button("button.cancel", role: .cancel) { }
                Button("contentView.deleteAll", role: .destructive) {
                    deleteAllProjects()
                }
            } message: {
                Text("contentView.deleteAll.confirmMessage \(projects.count)")
            }
        }
    }
    
    private func checkForImport() {
        if importService.shouldPerformImport() {
            print("[ContentView] Import should be performed")
            isImporting = true
            startImport()
        }
    }
    
    private func startImport() {
        // Capture the container from the main thread context
        let container = modelContext.container
        
        Task.detached {
            // Create a background ModelContext for this thread
            let backgroundContext = ModelContext(container)
            
            let success = await importService.executeImport(modelContext: backgroundContext)
            
            await MainActor.run {
                isImporting = false
                
                if success {
                    print("[ContentView] Import completed successfully")
                } else {
                    print("[ContentView] Import failed with errors")
                }
            }
        }
    }
    
    #if DEBUG && (targetEnvironment(macCatalyst) || os(macOS))
    /// Debug-only: Re-enable legacy import for testing (Mac only)
    private func triggerReimport() {
        print("[ContentView] Re-import triggered (debug only)")
        // Enable legacy import
        UserDefaults.standard.set(true, forKey: "legacyImportAllowed")
        // Trigger import
        isImporting = true
        startImport()
    }
    #endif
    
    private func handleJSONImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let fileURL = urls.first else { return }
            
            print("[ContentView] Starting JSON import from: \(fileURL)")
            
            Task {
                // CRITICAL: Start accessing security-scoped resource inside the Task
                guard fileURL.startAccessingSecurityScopedResource() else {
                    await MainActor.run {
                        importErrorMessage = NSLocalizedString("contentView.importError.accessDenied", comment: "Unable to access the selected file")
                        showImportError = true
                    }
                    print("[ContentView] Failed to access security-scoped resource")
                    return
                }
                
                // Ensure we stop accessing when done
                defer {
                    fileURL.stopAccessingSecurityScopedResource()
                    print("[ContentView] Stopped accessing security-scoped resource")
                }
                
                do {
                    // Create error handler
                    let errorHandler = ImportErrorHandler()
                    
                    // Create JSON importer
                    let jsonImporter = JSONImportService(
                        modelContext: modelContext,
                        errorHandler: errorHandler
                    )
                    
                    // Perform import
                    let project = try jsonImporter.importFromJSON(fileURL: fileURL)
                    
                    print("[ContentView] JSON import succeeded: \(project.name ?? "Untitled")")
                    
                    // Show warnings if any
                    if !errorHandler.warnings.isEmpty {
                        print("[ContentView] Import completed with \(errorHandler.warnings.count) warnings:")
                        errorHandler.warnings.forEach { print("  - \($0)") }
                    }
                    
                } catch ImportError.missingContent {
                    await MainActor.run {
                        importErrorMessage = NSLocalizedString("contentView.importError.emptyFile", comment: "The selected file is empty or corrupt")
                        showImportError = true
                    }
                } catch {
                    await MainActor.run {
                        importErrorMessage = String(format: NSLocalizedString("contentView.importError.failed", comment: "Failed to import project"), error.localizedDescription)
                        showImportError = true
                    }
                    print("[ContentView] JSON import failed: \(error)")
                }
            }
            
        case .failure(let error):
            importErrorMessage = String(format: NSLocalizedString("contentView.importError.selectFailed", comment: "Failed to select file"), error.localizedDescription)
            showImportError = true
            print("[ContentView] File selection failed: \(error)")
        }
    }
    
    private func initializeUserOrderIfNeeded() {
        // Ensure all existing projects have a userOrder
        let projectsNeedingOrder = projects.filter { $0.userOrder == nil }
        if !projectsNeedingOrder.isEmpty {
            for (index, project) in projects.enumerated() {
                if project.userOrder == nil {
                    project.userOrder = index
                }
            }
            try? modelContext.save()
        }
    }
    
    #if DEBUG
    private func deleteAllProjects() {
        print("[ContentView] DEBUG: Deleting all \(projects.count) projects")
        for project in projects {
            modelContext.delete(project)
        }
        do {
            try modelContext.save()
            print("[ContentView] DEBUG: Successfully deleted all projects")
        } catch {
            print("[ContentView] DEBUG: Failed to delete projects: \(error)")
        }
    }
    #endif
}

//#Preview {
//    ContentView()
//        .modelContainer(for: Project.self, inMemory: true)
//}
