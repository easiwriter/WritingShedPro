import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Bindable var project: Project
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showProjectInfo = false
    @State private var showDeleteConfirmation = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var editedName = ""
    
    var body: some View {
        // Main content: FolderListView
        FolderListView(project: project)
        .sheet(isPresented: $showProjectInfo) {
            ProjectInfoSheet(
                project: project,
                isPresented: $showProjectInfo,
                showDeleteConfirmation: $showDeleteConfirmation,
                errorMessage: $errorMessage,
                showErrorAlert: $showErrorAlert
            )
        }
        .confirmationDialog(
            NSLocalizedString("projectDetail.deleteTitle", comment: "Delete project confirmation dialog title"),
            isPresented: $showDeleteConfirmation,
            actions: {
                Button(NSLocalizedString("projectDetail.delete", comment: "Delete button"), role: .destructive) {
                    deleteProject()
                }
                Button(NSLocalizedString("projectDetail.cancel", comment: "Cancel button"), role: .cancel) { }
            },
            message: {
                Text(String(format: NSLocalizedString("projectDetail.deleteConfirmMessage", comment: "Delete confirmation message with project name"), project.name ?? ""))
            }
        )
        .alert(NSLocalizedString("projectDetail.error", comment: "Error alert title"), isPresented: $showErrorAlert) {
            Button(NSLocalizedString("projectDetail.ok", comment: "OK button"), role: .cancel) {
                // Revert to original name on error
                project.name = editedName
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func validateAndUpdateName(_ newName: String) {
        // Validate name
        do {
            try NameValidator.validateProjectName(newName)
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
            return
        }
        
        // Update name if valid
        project.name = newName
    }
    
    private func deleteProject() {
        modelContext.delete(project)
        dismiss()
    }
}

// MARK: - Project Info Sheet

struct ProjectInfoSheet: View {
    let project: Project
    @Environment(\.modelContext) var modelContext
    @Query private var allProjects: [Project]
    @Binding var isPresented: Bool
    @Binding var showDeleteConfirmation: Bool
    @Binding var errorMessage: String
    @Binding var showErrorAlert: Bool
    @State private var editedName = ""
    @State private var originalName = ""
    @State private var notesText = ""
    @State private var originalNotes = ""
    @State private var hasInitialized = false
    @State private var nameValidationError = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Simple dismiss button in top-right
            HStack {
                Spacer()
                Button(action: { 
                    // Discard all changes and close
                    if notesText != originalNotes {
                        project.notes = originalNotes.isEmpty ? nil : originalNotes
                    }
                    if editedName != originalName {
                        project.name = originalName
                    }
                    isPresented = false 
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(NSLocalizedString("projectDetail.close", comment: "Close button"))
                .accessibilityHint(NSLocalizedString("projectDetail.closeAccessibility", comment: "Discard changes and close sheet"))
            }
            .padding()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("projectDetail.projectInfo", comment: "Section header for project information"))
                        .font(.headline)
                    
                    Divider()
                    
                    HStack {
                        Text(NSLocalizedString("projectDetail.name", comment: "Field label for project name"))
                        Spacer()
                        TextField("Project Name", text: $editedName)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .padding(.vertical, 4)
                            .background(nameValidationError.isEmpty ? Color(.systemGray6) : Color(.systemRed).opacity(0.1))
                            .cornerRadius(6)
                            .onChange(of: editedName) { oldValue, newValue in
                                // Clear validation error when user starts editing
                                nameValidationError = ""
                            }
                            .accessibilityLabel(NSLocalizedString("projectDetail.name", comment: "Field label for project name"))
                            .accessibilityHint("Double tap to edit the project name")
                    }
                    
                    if !nameValidationError.isEmpty {
                        Text(nameValidationError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    
                    HStack {
                        Text(NSLocalizedString("projectDetail.type", comment: "Field label for project type"))
                        Spacer()
                        Text((project.type).rawValue.capitalized)
                    }
                    
                    HStack {
                        Text(NSLocalizedString("projectDetail.created", comment: "Field label for creation date"))
                        Spacer()
                        Text((project.creationDate ?? Date()).formatted(date: .abbreviated, time: .shortened))
                    }
                    
                    Divider()
                    
                    Text(NSLocalizedString("projectDetail.notes", comment: "Notes label"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    TextEditor(text: $notesText)
                        .border(Color.gray, width: 1)
                        .frame(minHeight: 100)
                        .onChange(of: notesText) { oldValue, newValue in
                            project.notes = newValue.isEmpty ? nil : newValue
                        }
                        .accessibilityLabel(NSLocalizedString("projectDetail.notes", comment: "Notes field"))
                        .accessibilityHint(NSLocalizedString("projectDetail.notesAccessibility", comment: "Edit notes hint"))
                }
                .padding()
            }
            
            Button(action: { 
                // Validate and save name change
                let trimmedName: String = editedName.trimmingCharacters(in: .whitespaces)
                
                // Check for empty name
                if trimmedName.isEmpty {
                    nameValidationError = NSLocalizedString("validation.emptyProjectName", comment: "Error when project name is empty")
                    return
                }
                
                // Check for duplicate name (excluding current project)
                let isDuplicate: Bool = allProjects.contains { (otherProject: Project) -> Bool in
                    guard otherProject.id != project.id else { return false }
                    let otherName: String = otherProject.name ?? ""
                    return otherName.lowercased() == trimmedName.lowercased()
                }
                
                if isDuplicate {
                    nameValidationError = NSLocalizedString("validation.duplicateProjectName", comment: "Error when project name already exists")
                    return
                }
                
                // Name is valid, save it
                project.name = trimmedName
                isPresented = false 
            }) {
                Text(NSLocalizedString("projectDetail.done", comment: "Done button"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(NSLocalizedString("projectDetail.done", comment: "Done button"))
            .accessibilityHint(NSLocalizedString("projectDetail.doneAccessibility", comment: "Save changes hint"))
            .padding()
        }
        .id(project.id)
        .onAppear {
            // Force initialization on appearance
            notesText = project.notes ?? ""
            originalNotes = project.notes ?? ""
            editedName = project.name ?? ""
            originalName = project.name ?? ""
            nameValidationError = ""
        }
        .onChange(of: project.id) { oldValue, newValue in
            // When a different project is selected, update the data
            notesText = project.notes ?? ""
            originalNotes = project.notes ?? ""
            editedName = project.name ?? ""
            originalName = project.name ?? ""
            nameValidationError = ""
        }
    }
    
    private func validateAndUpdateName(_ newName: String) {
        // Validate name
        do {
            try NameValidator.validateProjectName(newName)
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
            return
        }
        
        // Update name if valid
        project.name = newName
    }
}
