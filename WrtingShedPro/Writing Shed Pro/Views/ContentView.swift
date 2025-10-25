import SwiftUI
import SwiftData

struct ContentView: View {
    @Query var projects: [Project]
    @State private var showAddProject = false
    @State private var sortOrder: SortOrder = .byName
    @State private var selectedProjectForDetail: Project? = nil
    @State private var selectedProjectForInfo: Project?
    @State private var showDeleteConfirmation = false
    @State private var projectsToDelete: IndexSet?
    @State private var errorMessage = ""
    @State private var showErrorAlert = false
    @State private var isEditMode = false
    @Environment(\.modelContext) var modelContext
    @Environment(\.editMode) private var editMode
    
    var sortedProjects: [Project] {
        ProjectSortService.sortProjects(projects, by: sortOrder)
    }
    
    var deleteCount: Int {
        projectsToDelete?.count ?? 0
    }
    
    var deleteMessage: String {
        let count = deleteCount
        if count == 1 {
            let projectName = sortedProjects[projectsToDelete?.first ?? 0].name ?? NSLocalizedString("projectItem.untitledProject", comment: "Untitled project")
            return String(format: NSLocalizedString("contentView.deleteConfirmOne", comment: "Delete one project confirmation"), projectName)
        } else {
            return String(format: NSLocalizedString("contentView.deleteConfirmMultiple", comment: "Delete multiple projects confirmation"), count)
        }
    }
    
    var accessibilityHintText: String {
        "Double tap to open project folders"
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(sortedProjects) { project in
                    NavigationLink(destination:
                                    ProjectDetailView(project: project)
                    ) {
                        ProjectItemView(
                            project: project,
                            onInfoTapped: {
                                selectedProjectForInfo = project
                            }
                        )
                    }
                    .isDetailLink(false)
                    .accessibilityHint(accessibilityHintText)
                }
                .onDelete(perform: confirmDelete)
                .onMove(perform: moveProjects)
            }
            .onAppear {
                initializeUserOrderIfNeeded()
            }
            .navigationTitle(NSLocalizedString("contentView.title", comment: "Title of projects list"))
            .navigationDestination(item: $selectedProjectForDetail) { project in
                ProjectDetailView(project: project)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isEditMode ? "Done" : "Edit") {
                        withAnimation {
                            isEditMode.toggle()
                            editMode?.wrappedValue = isEditMode ? .active : .inactive
                        }
                    }
                    .disabled(projects.isEmpty)
                }
                
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: {}) {
                        Label(NSLocalizedString("contentView.import", comment: "Import button label"), systemImage: "arrow.down.doc")
                    }
                    .accessibilityLabel(NSLocalizedString("contentView.importAccessibility", comment: "Accessibility label for import button"))
                    
                    Menu {
                        Picker(NSLocalizedString("contentView.sortBy", comment: "Sort by label"), selection: $sortOrder) {
                            Text(NSLocalizedString("contentView.sortByName", comment: "Sort by name option")).tag(SortOrder.byName)
                            Text(NSLocalizedString("contentView.sortByDate", comment: "Sort by date option")).tag(SortOrder.byCreationDate)
                            Text(NSLocalizedString("contentView.sortByUserOrder", comment: "Sort by user's order option")).tag(SortOrder.byUserOrder)
                        }
                    } label: {
                        Label(NSLocalizedString("contentView.sort", comment: "Sort button label"), systemImage: "arrow.up.arrow.down")
                    }
                    .accessibilityLabel(NSLocalizedString("contentView.sortAccessibility", comment: "Accessibility label for sort menu"))
                    
                    Button(action: { showAddProject = true }) {
                        Label(NSLocalizedString("contentView.addProject", comment: "Button to add new project"), systemImage: "plus")
                    }
                    .accessibilityLabel(NSLocalizedString("contentView.addProjectAccessibility", comment: "Accessibility label for add project button"))
                }
            }
            .confirmationDialog(
                NSLocalizedString("contentView.deleteTitle", comment: "Delete projects confirmation dialog title"),
                isPresented: $showDeleteConfirmation,
                presenting: projectsToDelete,
                actions: { _ in
                    Button(NSLocalizedString("contentView.delete", comment: "Delete button"), role: .destructive) {
                        deleteProjects()
                    }
                    Button(NSLocalizedString("contentView.cancel", comment: "Cancel button"), role: .cancel) {
                        projectsToDelete = nil
                    }
                },
                message: { _ in
                    Text(deleteMessage)
                }
            )
            .sheet(isPresented: $showAddProject) {
                AddProjectSheet(isPresented: $showAddProject, projects: projects)
            }
            .sheet(item: $selectedProjectForInfo) { project in
                ProjectInfoSheet(
                    project: project,
                    isPresented: Binding(
                        get: { selectedProjectForInfo != nil },
                        set: { if !$0 { selectedProjectForInfo = nil } }
                    ),
                    showDeleteConfirmation: $showDeleteConfirmation,
                    errorMessage: $errorMessage,
                    showErrorAlert: $showErrorAlert
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
    
    private func moveProjects(from source: IndexSet, to destination: Int) {
        // If not in User's Order mode, automatically switch to it when user drags
        if sortOrder != .byUserOrder {
            sortOrder = .byUserOrder
        }
        
        // Use your proven approach: adjust userOrder values directly without array manipulation
        guard let sourceIndex = source.first else { return }
        let destIndex = destination
        
        // If dropping in same position, do nothing
        if destIndex == sourceIndex {
            return
        }
        
        let currentProjects = sortedProjects
        
        if sourceIndex > destIndex { 
            // Moving item up the list - shift items down to make room
            let baseOrder = currentProjects[destIndex].userOrder ?? destIndex
            for i in destIndex..<sourceIndex {
                let currentOrder = currentProjects[i].userOrder ?? i
                currentProjects[i].userOrder = currentOrder + 1
            }
            currentProjects[sourceIndex].userOrder = baseOrder
        } else {
            // Moving item down the list - shift items up to fill gap
            for i in sourceIndex + 1..<destIndex {
                let currentOrder = currentProjects[i].userOrder ?? i
                currentProjects[i].userOrder = currentOrder - 1
            }
            currentProjects[sourceIndex].userOrder = destIndex - 1
        }
        
        // Save the changes
        try? modelContext.save()
    }
    
    private func confirmDelete(at offsets: IndexSet) {
        projectsToDelete = offsets
        showDeleteConfirmation = true
    }
    
    private func deleteProjects() {
        guard let offsets = projectsToDelete else { return }
        for index in offsets {
            let project = sortedProjects[index]
            modelContext.delete(project)
        }
        projectsToDelete = nil
        
        // Exit edit mode if no projects remain
        DispatchQueue.main.async {
            if self.projects.isEmpty && (self.isEditMode || self.editMode?.wrappedValue == .active) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.isEditMode = false
                    self.editMode?.wrappedValue = .inactive
                }
            }
        }
    }
}

//#Preview {
//    ContentView()
//        .modelContainer(for: Project.self, inMemory: true)
//}
