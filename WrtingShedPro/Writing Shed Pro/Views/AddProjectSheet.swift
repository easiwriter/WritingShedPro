import SwiftUI
import SwiftData

struct AddProjectSheet: View {
    @Binding var isPresented: Bool
    @State var projectName = ""
    @State var selectedType: ProjectType = .blank
    @State var details = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var selectedStyleSheet: StyleSheet?
    @State private var availableStyleSheets: [StyleSheet] = []
    @Environment(\.modelContext) var modelContext
    @Query private var allProjects: [Project]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("addProject.projectInfo", comment: "Section header for project information")) {
                    TextField(NSLocalizedString("addProject.projectName", comment: "Field label for project name"), text: $projectName)
                        .accessibilityLabel(NSLocalizedString("addProject.projectNameAccessibility", comment: "Accessibility label for project name field"))
                    Picker(NSLocalizedString("addProject.type", comment: "Field label for project type"), selection: $selectedType) {
                        ForEach(ProjectType.allCases, id: \.self) { type in
                            Text(NSLocalizedString("projectType.\(type.rawValue)", comment: "Project type")).tag(type)
                        }
                    }
                    .accessibilityLabel(NSLocalizedString("addProject.typeAccessibility", comment: "Accessibility label for project type picker"))
                }
                
                Section(NSLocalizedString("addProject.stylesheet", comment: "Section header for stylesheet selection")) {
                    Picker(NSLocalizedString("addProject.stylesheetPicker", comment: "Field label for stylesheet picker"), selection: $selectedStyleSheet) {
                        ForEach(availableStyleSheets, id: \.id) { sheet in
                            Text(sheet.name).tag(sheet as StyleSheet?)
                        }
                    }
                    .accessibilityLabel(NSLocalizedString("addProject.stylesheetAccessibility", comment: "Accessibility label for stylesheet picker"))
                }
                
                Section(NSLocalizedString("addProject.details", comment: "Section header for project details")) {
                    TextEditor(text: $details)
                        .frame(height: 100)
                        .accessibilityLabel(NSLocalizedString("addProject.detailsAccessibility", comment: "Accessibility label for project details field"))
                }
            }
            .navigationTitle(NSLocalizedString("addProject.title", comment: "Title for add project sheet"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadStyleSheets()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("addProject.cancel", comment: "Cancel button")) {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("addProject.add", comment: "Add button")) {
                        addProject()
                    }
                    .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert(NSLocalizedString("addProject.error", comment: "Error alert title"), isPresented: $showErrorAlert) {
                Button(NSLocalizedString("addProject.ok", comment: "OK button"), role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func addProject() {
        // Validate project name
        do {
            try NameValidator.validateProjectName(projectName)
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
            return
        }
        
        // Check uniqueness
        if !UniquenessChecker.isProjectNameUnique(projectName, in: allProjects) {
            errorMessage = NSLocalizedString("addProject.duplicateName", comment: "Error when project name already exists")
            showErrorAlert = true
            return
        }
        
        // Create project with userOrder set to maintain custom order
        let newProject = Project(
            name: projectName,
            type: selectedType,
            details: details.isEmpty ? nil : details,
            userOrder: allProjects.count // Place new project at the end
        )
        
        // Assign selected stylesheet
        newProject.styleSheet = selectedStyleSheet
        
        modelContext.insert(newProject)
        
        // Create default folder structure
        ProjectTemplateService.createDefaultFolders(for: newProject, in: modelContext)
        
        // Explicitly save to trigger CloudKit sync
        do {
            try modelContext.save()
            print("✅ Project saved successfully: \(newProject.name ?? "Unnamed")")
            
            // Force CloudKit sync by attempting a fetch
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
                do {
                    // Force the sync by doing a no-op fetch
                    _ = try modelContext.fetch(FetchDescriptor<Project>())
                    print("✅ Forced CloudKit sync with fetch")
                } catch {
                    print("⚠️ Fetch for sync failed (non-critical): \(error)")
                }
            }
        } catch {
            print("❌ Error saving project: \(error)")
            if let nsError = error as? NSError {
                print("   Error domain: \(nsError.domain)")
                print("   Error code: \(nsError.code)")
                print("   UserInfo: \(nsError.userInfo)")
            }
            errorMessage = "Failed to save project: \(error.localizedDescription)"
            showErrorAlert = true
            return
        }
        
        isPresented = false
    }
    
    private func loadStyleSheets() {
        let descriptor = FetchDescriptor<StyleSheet>(
            sortBy: [SortDescriptor(\.name)]
        )
        
        if let sheets = try? modelContext.fetch(descriptor) {
            availableStyleSheets = sheets
            
            // Select default stylesheet by default
            selectedStyleSheet = sheets.first(where: { $0.isSystemStyleSheet })
        }
    }
}
