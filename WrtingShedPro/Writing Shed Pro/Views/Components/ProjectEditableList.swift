import SwiftUI
import SwiftData

/// A specialized EditableList for Project items
struct ProjectEditableList: View {
    @Environment(\.modelContext) private var modelContext
    let projects: [Project]
    @State private var selectedSortOrder: SortOrder
    @State private var isEditMode = false
    @State private var selectedProjectForInfo: Project?
    @State private var showDeleteConfirmation = false
    @State private var projectsToDelete: IndexSet?
    @State private var deleteInfo: (count: Int, firstName: String)?
    
    // Sort and display state
    private var sortedProjects: [Project] {
        ProjectSortService.sortProjects(projects, by: selectedSortOrder)
    }
    
    init(projects: [Project], initialSort: SortOrder = .byName) {
        self.projects = projects
        self._selectedSortOrder = State(initialValue: initialSort)
    }
    
    var body: some View {
        List {
            ForEach(sortedProjects) { project in
                NavigationLink(destination: ProjectDetailView(project: project)) {
                    ProjectItemView(
                        project: project,
                        onInfoTapped: {
                            selectedProjectForInfo = project
                        }
                    )
                }
                .isDetailLink(false)
                .accessibilityHint("Double tap to open project folders")
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
            .onDelete(perform: deleteProjects)
            .onMove(perform: isEditMode ? moveProjects : nil)
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(isEditMode ? .active : .inactive))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // Sort Menu
                Menu {
                    ForEach(ProjectSortService.sortOptions(), id: \.order) { option in
                        Button(action: {
                            selectedSortOrder = option.order
                        }) {
                            HStack {
                                Text(option.title)
                                if selectedSortOrder == option.order {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                // Edit Button
                Button(isEditMode ? "Done" : "Edit") {
                    withAnimation {
                        isEditMode.toggle()
                    }
                }
                .disabled(projects.isEmpty)
            }
        }
        .onChange(of: projects.isEmpty) { _, isEmpty in
            if isEmpty && isEditMode {
                withAnimation {
                    isEditMode = false
                }
            }
        }
        .sheet(item: $selectedProjectForInfo) { project in
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
        .confirmationDialog(
            Text("projectEditableList.deleteTitle"),
            isPresented: $showDeleteConfirmation,
            presenting: deleteInfo,
            actions: { _ in
                Button("projectEditableList.delete", role: .destructive) {
                    confirmDeleteProjects()
                }
                Button("button.cancel", role: .cancel) {
                    projectsToDelete = nil
                    deleteInfo = nil
                }
            },
            message: { info in
                if info.count == 1 {
                    return Text(String(format: NSLocalizedString("projectEditableList.deleteSingleWarning", comment: "Delete single project warning"), info.firstName))
                } else {
                    return Text(String(format: NSLocalizedString("projectEditableList.deleteMultipleWarning", comment: "Delete multiple projects warning"), info.count))
                }
            }
        )
    }
    
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
    
    private func confirmDeleteProjects() {
        guard let offsets = projectsToDelete else { return }
        
        // Safely delete projects by checking index bounds
        for index in offsets {
            guard index < sortedProjects.count else { continue }
            let project = sortedProjects[index]
            modelContext.delete(project)
        }
        
        try? modelContext.save()
        projectsToDelete = nil
        deleteInfo = nil
    }
    
    private func moveProjects(from source: IndexSet, to destination: Int) {
        // If not in User's Order mode, automatically switch to it when user drags
        if selectedSortOrder != .byUserOrder {
            selectedSortOrder = .byUserOrder
        }
        
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
}