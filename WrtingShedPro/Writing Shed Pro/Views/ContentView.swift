import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @Query var projects: [Project]
    @State private var state = ContentViewState()
    @Environment(\.modelContext) var modelContext
    
    var body: some View {
        ContentViewBody(
            projects: projects,
            state: state,
            onInitialize: initializeUserOrderIfNeeded,
            onInitializeStyleSheets: initializeStyleSheets,
            onHandleImportMenu: handleImportMenu,
            onHandleJSONImport: handleJSONImport,
            onDeleteAllProjects: deleteAllProjects,
            onPrefetchProjectData: prefetchProjectData
        )
    }
    
    /// Prefetch project relationships async to warm up Swift type system
    /// This prevents UI freeze when tapping first project after app launch
    private func prefetchProjectData() {
        guard !projects.isEmpty else { return }
        
        // Only do expensive prefetch in Debug builds where it matters
        #if DEBUG
        print("[ContentView] Starting async prefetch of project relationships...")
        
        Task(priority: .utility) {
            // Access relationships to force SwiftData to materialize them
            // Runs async on main thread (SwiftData objects must stay on their thread)
            for project in projects {
                // Touch each relationship to warm up the object graph
                _ = project.folders?.count ?? 0
                _ = project.publications?.count ?? 0
                _ = project.submissions?.count ?? 0
                _ = project.submittedFiles?.count ?? 0
                _ = project.trashedItems?.count ?? 0
                _ = project.styleSheet?.name
                _ = project.pageSetup?.paperSize
                
                // Access nested relationships in folders
                if let folders = project.folders {
                    for folder in folders {
                        _ = folder.textFiles?.count ?? 0
                        _ = folder.folders?.count ?? 0
                    }
                }
            }
            
            print("[ContentView] ✅ Prefetch complete")
        }
        #endif
    }
    
    /// Initialize default stylesheets async on main thread (moved from Write_App to avoid blocking launch)
    private func initializeStyleSheets() {
        Task(priority: .utility) {
            // Run async on main thread (ModelContext must stay on its creation thread)
            StyleSheetService.initializeStyleSheetsIfNeeded(context: modelContext)
            #if DEBUG
            print("✅ [ContentView] Stylesheets initialized")
            #endif
        }
    }
    
    /// Handle Import menu action - show file picker directly
    private func handleImportMenu() {
        #if DEBUG
        print("[ContentView] Import menu clicked - showing file picker")
        #endif
        state.showingJSONImportPicker = true
    }
    

    
    private func handleJSONImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let fileURL = urls.first else { return }
            
            #if DEBUG
            print("[ContentView] Starting JSON import from: \(fileURL)")
            #endif
            
            Task {
                // CRITICAL: Start accessing security-scoped resource inside the Task
                guard fileURL.startAccessingSecurityScopedResource() else {
                    await MainActor.run {
                        state.importErrorMessage = NSLocalizedString("contentView.importError.accessDenied", comment: "Unable to access the selected file")
                        state.showImportError = true
                    }
                    #if DEBUG
                    print("[ContentView] Failed to access security-scoped resource")
                    #endif
                    return
                }
                
                // Ensure we stop accessing when done
                defer {
                    fileURL.stopAccessingSecurityScopedResource()
                    #if DEBUG
                    print("[ContentView] Stopped accessing security-scoped resource")
                    #endif
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
                    
                    #if DEBUG
                    print("[ContentView] JSON import succeeded: \(project.name ?? "Untitled")")
                    #endif
                    
                    // Show warnings if any
                    if !errorHandler.warnings.isEmpty {
                        #if DEBUG
                        print("[ContentView] Import completed with \(errorHandler.warnings.count) warnings:")
                        #endif
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
                    #if DEBUG
                    print("[ContentView] JSON import failed: \(error)")
                    #endif
                }
            }
            
        case .failure(let error):
            state.importErrorMessage = String(format: NSLocalizedString("contentView.importError.selectFailed", comment: "Failed to select file"), error.localizedDescription)
            state.showImportError = true
            #if DEBUG
            print("[ContentView] File selection failed: \(error)")
            #endif
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
            #if DEBUG
            print("[ContentView] DEBUG: Successfully deleted all projects")
            #endif
        } catch {
            #if DEBUG
            print("[ContentView] DEBUG: Failed to delete projects: \(error)")
            #endif
        }
        #endif
    }
}

//#Preview {
//    ContentView()
//        .modelContainer(for: Project.self, inMemory: true)
//}
