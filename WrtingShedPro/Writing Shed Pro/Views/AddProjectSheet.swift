import SwiftUI
import SwiftData

struct AddProjectSheet: View {
    @Binding var isPresented: Bool
    @State var projectName = ""
    @State var selectedType: ProjectType = .prose
    @State var details = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var selectedStyleSheet: StyleSheet?
    @State private var availableStyleSheets: [StyleSheet] = []
    
    // Fiction-specific state
    @State private var selectedFictionClass: FictionClass = .novel
    @State private var selectedStoryStructure: StoryStructure = .freeform
    
    // Upgrade prompt state
    @State private var upgradePromptReason: UpgradePromptReason?
    
    @Environment(\.modelContext) var modelContext
    @Query private var allProjects: [Project]
    
    var body: some View {
        NavigationView {
            Form {
                Section(NSLocalizedString("addProject.projectInfo", comment: "Section header for project information")) {
                    TextField(NSLocalizedString("addProject.projectName", comment: "Field label for project name"), text: $projectName)
                        .accessibilityLabel(NSLocalizedString("addProject.projectNameAccessibility", comment: "Accessibility label for project name field"))
                        .onSubmit {
                            if !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                addProject()
                            }
                        }
                    Picker(NSLocalizedString("addProject.type", comment: "Field label for project type"), selection: $selectedType) {
                        ForEach(ProjectType.allCases, id: \.self) { type in
                            Text(type.localizedName).tag(type)
                        }
                    }
                    .accessibilityLabel(NSLocalizedString("addProject.typeAccessibility", comment: "Accessibility label for project type picker"))
                    
                    // Fiction-specific options
                    if selectedType == .fiction {
                        Picker(NSLocalizedString("fictionClass.label", comment: "Label for fiction class picker"), selection: $selectedFictionClass) {
                            ForEach(FictionClass.allCases, id: \.self) { fictionClass in
                                Text(fictionClass.localizedName).tag(fictionClass)
                            }
                        }
                        .accessibilityLabel(NSLocalizedString("fictionClass.accessibilityLabel", comment: "Accessibility label for fiction class picker"))
                    }
                    
                    if selectedType == .fiction || selectedType == .drama {
                        Picker(NSLocalizedString("addProject.storyStructure", comment: "Story structure picker label"), selection: $selectedStoryStructure) {
                            ForEach(StoryStructure.userFacingCases, id: \.self) { structure in
                                Text(structure.localizedName).tag(structure)
                            }
                        }
                        .accessibilityLabel(NSLocalizedString("addProject.storyStructureAccessibility", comment: "Accessibility label for story structure picker"))
                        
                        if selectedStoryStructure != .freeform {
                            Text(selectedStoryStructure.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
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
                        .accessibilityLabel(NSLocalizedString("addProject.detailsAccessibility", comment: "Accessibility label for details field"))
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
                    .foregroundColor(.blue)
                }
            }
            .alert(NSLocalizedString("addProject.error", comment: "Error alert title"), isPresented: $showErrorAlert) {
                Button(NSLocalizedString("addProject.ok", comment: "OK button"), role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .upgradePrompt(reason: $upgradePromptReason) {
                self.addProject()
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private func addProject() {
        do {
            _ = try ProjectCreationService.createProject(
                name: projectName,
                type: selectedType,
                fictionClass: selectedType == .fiction ? selectedFictionClass : nil,
                storyStructure: selectedStoryStructure,
                details: details,
                styleSheet: selectedStyleSheet,
                allProjects: allProjects,
                modelContext: modelContext
            )
            isPresented = false
        } catch OnboardingCreationError.projectLimit(let projectType) {
            upgradePromptReason = .projectLimit(projectType: projectType)
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    private func loadStyleSheets() {
        let descriptor = FetchDescriptor<StyleSheet>(
            sortBy: [SortDescriptor(\.name)]
        )
        
        if let sheets = try? modelContext.fetch(descriptor) {
            availableStyleSheets = StyleSheetService.uniqueStyleSheets(from: sheets)
            
            // Select default stylesheet by default
            selectedStyleSheet = availableStyleSheets.first(where: { $0.isSystemStyleSheet })
        }
    }
}
