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
            onHandleImportMenu: handleImportMenu,
            onHandleJSONImport: handleJSONImport,
            onDeleteAllProjects: deleteAllProjects
        )
    }
    
    /// Handle Import menu action - show file picker directly
    private func handleImportMenu() {
        print("[ContentView] Import menu clicked - showing file picker")
        state.showingJSONImportPicker = true
    }
    

    
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
