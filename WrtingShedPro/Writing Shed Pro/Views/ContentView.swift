import SwiftUI
import SwiftData

struct ContentView: View {
    @Query var projects: [Project]
    @State private var showAddProject = false
    @State private var showManageStyles = false
    @Environment(\.modelContext) var modelContext
    
    var body: some View {
        NavigationStack {
            ProjectEditableList(projects: projects)
            .onAppear {
                initializeUserOrderIfNeeded()
            }
            .navigationTitle(NSLocalizedString("contentView.title", comment: "Title of projects list"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showManageStyles = true }) {
                        Label("Manage Stylesheets", systemImage: "paintbrush")
                    }
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
                NavigationStack {
                    StyleSheetListView()
                        .navigationTitle("Manage Stylesheets")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    showManageStyles = false
                                }
                            }
                        }
                }
            }
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
