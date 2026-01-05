//
//  AddSceneSheet.swift
//  Writing Shed Pro
//
//  Feature 022: Smart Fiction Creation - Add scene form
//

import SwiftUI
import SwiftData

/// Sheet for adding a new scene to a fiction project
struct AddSceneSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    let chapter: FictionChapter?
    
    // MARK: - State
    
    @State private var title: String = ""
    @State private var summary: String = ""
    @State private var selectedMonomythStage: MonomythStage?
    @State private var selectedLocation: FictionLocation?
    @State private var selectedCharacters: Set<FictionCharacter> = []
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // MARK: - Computed
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var availableLocations: [FictionLocation] {
        (project.locations ?? []).sorted { 
            ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending
        }
    }
    
    private var availableCharacters: [FictionCharacter] {
        (project.characters ?? []).sorted { 
            ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending
        }
    }
    
    private var nextOrderIndex: Int {
        let scenes: [FictionScene]
        if let chapter = chapter {
            scenes = chapter.scenes ?? []
        } else {
            scenes = project.scenes ?? []
        }
        return (scenes.map { $0.userOrder ?? 0 }.max() ?? -1) + 1
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Basic Info
                Section {
                    TextField(NSLocalizedString("fiction.scene.title", comment: "Title"), text: $title)
                        .accessibilityLabel(NSLocalizedString("fiction.scene.title.accessibility", comment: "Scene title"))
                } header: {
                    Text(NSLocalizedString("fiction.scene.section.basic", comment: "Basic Info"))
                }
                
                // Summary
                Section {
                    TextEditor(text: $summary)
                        .frame(minHeight: 80)
                        .accessibilityLabel(NSLocalizedString("fiction.scene.summary.accessibility", comment: "Scene summary"))
                } header: {
                    Text(NSLocalizedString("fiction.scene.summary", comment: "Summary"))
                } footer: {
                    Text(NSLocalizedString("fiction.scene.summary.footer", comment: "Brief description of what happens"))
                }
                
                // Location (optional)
                Section {
                    Picker(NSLocalizedString("fiction.scene.location", comment: "Location"), selection: $selectedLocation) {
                        Text(NSLocalizedString("fiction.scene.location.none", comment: "None"))
                            .tag(nil as FictionLocation?)
                        
                        ForEach(availableLocations) { location in
                            Text(location.name ?? "")
                                .tag(location as FictionLocation?)
                        }
                    }
                } header: {
                    Text(NSLocalizedString("fiction.scene.section.location", comment: "Location"))
                }
                
                // Characters (multi-select)
                if !availableCharacters.isEmpty {
                    Section {
                        ForEach(availableCharacters) { character in
                            Button {
                                toggleCharacter(character)
                            } label: {
                                HStack {
                                    Text(character.name ?? "")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedCharacters.contains(character) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text(NSLocalizedString("fiction.scene.section.characters", comment: "Characters"))
                    } footer: {
                        Text(String(format: NSLocalizedString("fiction.scene.characters.selected", comment: "Selected count"), selectedCharacters.count))
                    }
                }
                
                // Monomyth Stage (if project uses monomyth)
                if project.useMonomyth {
                    Section {
                        Picker(NSLocalizedString("fiction.scene.monomythStage", comment: "Story Stage"), selection: $selectedMonomythStage) {
                            Text(NSLocalizedString("fiction.scene.monomythStage.none", comment: "None"))
                                .tag(nil as MonomythStage?)
                            
                            ForEach(MonomythStage.allCases, id: \.self) { stage in
                                Text(NSLocalizedString("monomyth.\(stage.rawValue)", comment: "Stage name"))
                                    .tag(stage as MonomythStage?)
                            }
                        }
                        
                        if let stage = selectedMonomythStage {
                            Text(NSLocalizedString("monomyth.\(stage.rawValue).description", comment: "Stage description"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text(NSLocalizedString("fiction.scene.section.monomyth", comment: "Hero's Journey"))
                    }
                }
            }
            .navigationTitle(NSLocalizedString("fiction.scene.add.title", comment: "Add Scene"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.add", comment: "Add")) {
                        addScene()
                    }
                    .disabled(!isValid)
                }
            }
            .alert(NSLocalizedString("error.title", comment: "Error"), isPresented: $showErrorAlert) {
                Button(NSLocalizedString("button.ok", comment: "OK"), role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Actions
    
    private func toggleCharacter(_ character: FictionCharacter) {
        if selectedCharacters.contains(character) {
            selectedCharacters.remove(character)
        } else {
            selectedCharacters.insert(character)
        }
    }
    
    private func addScene() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else {
            errorMessage = NSLocalizedString("fiction.scene.error.titleRequired", comment: "Title required")
            showErrorAlert = true
            return
        }
        
        let scene = FictionScene(
            name: trimmedTitle,
            synopsis: summary.isEmpty ? nil : summary,
            userOrder: nextOrderIndex
        )
        scene.project = project
        scene.chapter = chapter
        
        // Set relationships
        scene.location = selectedLocation
        scene.monomythStage = selectedMonomythStage
        scene.characters = Array(selectedCharacters)
        
        modelContext.insert(scene)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}
