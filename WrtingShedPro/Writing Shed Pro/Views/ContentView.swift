import SwiftUI
import SwiftData

struct ContentView: View {
    @Query var projects: [Project]
    @State private var showAddProject = false
    @State private var showManageStyles = false
    @State private var showImportProgress = false
    @State private var showReimportAlert = false
    @State private var isReimporting = false
    @Environment(\.modelContext) var modelContext
    
    var body: some View {
        ZStack {
            NavigationStack {
                ProjectEditableList(projects: projects)
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showReimportAlert = true }) {
                        Label("Re-import", systemImage: "arrow.trianglehead.2.clockwise")
                    }
                    .disabled(isReimporting)
                    .accessibilityLabel("Re-import projects (temp debug button)")
                }
                
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
            .confirmationDialog(
                "Re-import Projects",
                isPresented: $showReimportAlert,
                actions: {
                    Button("Delete & Re-import", role: .destructive) {
                        performReimport()
                    }
                    Button("Cancel", role: .cancel) { }
                },
                message: {
                    Text("This will delete all current projects and re-import from the legacy database.")
                }
            )
            }
            
            // Show import progress overlay if needed
            if showImportProgress {
                ImportProgressView(isPresented: $showImportProgress)
            }
        }
    }
    
    private func performReimport() {
        isReimporting = true
        let importService = ImportService()
        
        do {
            try importService.resetForReimport(modelContext: modelContext)
            print("[ContentView] Deletion complete, triggering import...")
            
            // Show import progress view which will handle the import
            showImportProgress = true
            isReimporting = false
        } catch {
            print("[ContentView] Re-import reset failed: \(error)")
            isReimporting = false
        }
    }
    
    private func checkForImport() {
        let importService = ImportService()
        if importService.shouldPerformImport() {
            print("[ContentView] Import should be performed")
            showImportProgress = true
            // ImportProgressView will handle starting the import
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
}

//#Preview {
//    ContentView()
//        .modelContainer(for: Project.self, inMemory: true)
//}
