import SwiftUI
import SwiftData

struct ContentView: View {
    @Query var projects: [Project]
    @State private var showAddProject = false
    @State private var showManageStyles = false
    @State private var isImporting = false
    @State private var importService = ImportService()
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
                        Label("Manage Stylesheets", systemImage: "paintbrush")
                    }
                }
                
                #if DEBUG && (targetEnvironment(macCatalyst) || os(macOS))
                // Re-import only available on Mac where legacy database is accessible
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { triggerReimport() }) {
                        Label("Re-import", systemImage: "arrow.trianglehead.2.clockwise")
                    }
                    .accessibilityLabel("Re-import legacy projects (debug only)")
                }
                #endif
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
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
}

//#Preview {
//    ContentView()
//        .modelContainer(for: Project.self, inMemory: true)
//}
