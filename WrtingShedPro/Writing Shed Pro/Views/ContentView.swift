import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @Query var projects: [Project]
    @StateObject private var state = ContentViewState()
    @State private var importService = ImportService()
    @Environment(\.modelContext) var modelContext
    
    var body: some View {
        ContentViewBody(
            projects: projects,
            state: state,
            importService: importService,
            onInitialize: initializeUserOrderIfNeeded,
            onCheckImport: checkForImport,
            onHandleImportMenu: handleImportMenu,
            onImportSelectedProjects: importSelectedLegacyProjects,
            onHandleJSONImport: handleJSONImport,
            onHandleManualDatabase: handleManualDatabaseSelection,
            onDeleteAllProjects: deleteAllProjects
        )
    }
    
    /// Handle Import menu action with smart logic
    /// Checks for legacy database and shows appropriate import options
    private func handleImportMenu() {
        // Check if legacy database exists (Mac only)
        #if targetEnvironment(macCatalyst) || os(macOS)
        if importService.legacyDatabaseExists() {
            // Check if there are unimported projects
            let unimported = importService.getUnimportedProjects(modelContext: modelContext)
            if !unimported.isEmpty {
                // Store available projects and show options dialog
                state.availableLegacyProjects = unimported
                state.showImportOptions = true
                return
            }
        }
        #endif
        
        // No legacy database or no unimported projects - show file picker directly
        state.showingJSONImportPicker = true
    }
    
    /// Import selected legacy projects
    private func importSelectedLegacyProjects(_ selectedProjects: [LegacyProjectData]) {
        print("[ContentView] Importing \(selectedProjects.count) selected projects")
        
        // Start import with progress indicator
        state.isImporting = true
        
        let container = modelContext.container
        
        Task.detached {
            let backgroundContext = ModelContext(container)
            
            let success = await self.importService.executeSelectiveImport(
                projectsToImport: selectedProjects,
                modelContext: backgroundContext
            )
            
            await MainActor.run {
                self.state.isImporting = false
                
                if success {
                    print("[ContentView] Selective import completed successfully")
                } else {
                    print("[ContentView] Selective import failed with errors")
                    // TODO: Show error alert
                }
            }
        }
    }
    
    private func checkForImport() {
        if importService.shouldPerformImport() {
            print("[ContentView] Import should be performed")
            state.isImporting = true
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
                state.isImporting = false
                
                if success {
                    print("[ContentView] Import completed successfully")
                } else {
                    print("[ContentView] Import failed with errors")
                }
            }
        }
    }
    
    /// Handle manual database file selection when auto-detect fails
    private func handleManualDatabaseSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let databaseURL = urls.first else { return }
            
            print("[ContentView] User selected database: \(databaseURL.path)")
            
            // Try to load projects from the manually selected database
            let legacyService = LegacyDatabaseService(databaseURL: databaseURL)
            
            do {
                try legacyService.connect()
                let projects = try legacyService.fetchProjects()
                legacyService.disconnect()
                
                print("[ContentView] Loaded \(projects.count) projects from selected database")
                state.availableLegacyProjects = projects
                state.showImportOptions = true
                
            } catch {
                print("[ContentView] Failed to load database: \(error)")
                state.importErrorMessage = "Unable to read the selected database: \(error.localizedDescription)"
                state.showImportError = true
            }
            
        case .failure(let error):
            print("[ContentView] Database selection failed: \(error)")
            state.importErrorMessage = "Failed to select database: \(error.localizedDescription)"
            state.showImportError = true
        }
    }
    
    #if DEBUG && (targetEnvironment(macCatalyst) || os(macOS))
    /// Debug-only: Re-enable legacy import for testing (Mac only)
    private func triggerReimport() {
        print("[ContentView] Re-import triggered (debug only)")
        // Enable legacy import
        UserDefaults.standard.set(true, forKey: "legacyImportAllowed")
        // Trigger import
        state.isImporting = true
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
                        state.importErrorMessage = NSLocalizedString("contentView.importError.accessDenied", comment: "Unable to access the selected file")
                        state.showImportError = true
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
                        state.importErrorMessage = NSLocalizedString("contentView.importError.emptyFile", comment: "The selected file is empty or corrupt")
                        state.showImportError = true
                    }
                } catch {
                    await MainActor.run {
                        state.importErrorMessage = String(format: NSLocalizedString("contentView.importError.failed", comment: "Failed to import project"), error.localizedDescription)
                        state.showImportError = true
                    }
                    print("[ContentView] JSON import failed: \(error)")
                }
            }
            
        case .failure(let error):
            state.importErrorMessage = String(format: NSLocalizedString("contentView.importError.selectFailed", comment: "Failed to select file"), error.localizedDescription)
            state.showImportError = true
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
    
    private func deleteAllProjects() {
        #if DEBUG
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
        #endif
    }
}

//#Preview {
//    ContentView()
//        .modelContainer(for: Project.self, inMemory: true)
//}
