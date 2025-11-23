//
//  PublicationFormView.swift
//  Writing Shed Pro
//
//  Feature 008b Phase 2: Publications Management UI
//

import SwiftUI
import SwiftData

struct PublicationFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let project: Project
    let publication: Publication? // nil = add, non-nil = edit
    
    @Query private var allPublications: [Publication]
    
    @State private var name: String = ""
    @State private var selectedType: PublicationType = .magazine
    @State private var url: String = ""
    @State private var hasDeadline: Bool = false
    @State private var deadline: Date = Date().addingTimeInterval(86400 * 30) // 30 days default
    @State private var notes: String = ""
    
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDuplicateWarning = false
    @State private var pendingSaveName: String = ""
    
    var isEditing: Bool { publication != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                // Name section
                Section {
                    TextField(
                        NSLocalizedString("publications.form.name.placeholder", comment: "Name placeholder"),
                        text: $name
                    )
                    .accessibilityLabel(Text(NSLocalizedString("publications.form.name.label", comment: "Name label")))
                } header: {
                    Text(NSLocalizedString("publications.form.name.label", comment: "Name label"))
                }
                
                // Type section
                Section {
                    Picker(
                        NSLocalizedString("publications.form.type.label", comment: "Type label"),
                        selection: $selectedType
                    ) {
                        ForEach([PublicationType.magazine, PublicationType.competition, PublicationType.commission, PublicationType.other], id: \.self) { type in
                            Text(type.displayName)
                                .tag(type)
                        }
                    }
                    .accessibilityLabel(Text(NSLocalizedString("accessibility.type.picker", comment: "Type picker")))
                } header: {
                    Text(NSLocalizedString("publications.form.type.label", comment: "Type label"))
                }
                
                // Deadline section
                Section {
                    Toggle(isOn: $hasDeadline) {
                        Text(NSLocalizedString("publications.form.deadline.label", comment: "Deadline label"))
                    }
                    .accessibilityLabel(Text(NSLocalizedString("accessibility.deadline.toggle", comment: "Deadline toggle")))
                    .accessibilityHint(Text(NSLocalizedString("accessibility.deadline.toggle.hint", comment: "Toggle deadline hint")))
                    
                    if hasDeadline {
                        DatePicker(
                            "",
                            selection: $deadline,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                    }
                } header: {
                    Text(NSLocalizedString("publications.form.deadline.label", comment: "Deadline label"))
                }
                
                // URL section
                Section {
                    TextField(
                        NSLocalizedString("publications.form.url.placeholder", comment: "URL placeholder"),
                        text: $url
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .accessibilityLabel(Text(NSLocalizedString("publications.form.url.label", comment: "URL label")))
                } header: {
                    Text(NSLocalizedString("publications.form.url.label", comment: "URL label"))
                }
                
                // Notes section
                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                        .accessibilityLabel(Text(NSLocalizedString("publications.form.notes.label", comment: "Notes label")))
                } header: {
                    Text(NSLocalizedString("publications.form.notes.label", comment: "Notes label"))
                }
            }
            .navigationTitle(Text(NSLocalizedString(
                isEditing ? "publications.edit.title" : "publications.add.title",
                comment: "Form title"
            )))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("publications.button.cancel", comment: "Cancel button")) {
                        dismiss()
                    }
                    .accessibilityHint(Text(NSLocalizedString("accessibility.cancel.hint", comment: "Cancel hint")))
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("publications.button.save", comment: "Save button")) {
                        savePublication()
                    }
                    .accessibilityHint(Text(NSLocalizedString("accessibility.save.publication.hint", comment: "Save hint")))
                }
            }
            .alert(
                NSLocalizedString("publications.error.title", comment: "Error title"),
                isPresented: $showingError
            ) {
                Button("button.ok") { }
            } message: {
                Text(errorMessage)
            }
            .confirmationDialog(
                "publications.duplicate.title",
                isPresented: $showingDuplicateWarning,
                titleVisibility: .visible
            ) {
                Button("publications.duplicate.useOriginal") {
                    performSave(withName: pendingSaveName)
                }
                Button("publications.duplicate.makeUnique") {
                    let uniqueName = makeUniqueName(pendingSaveName)
                    name = uniqueName
                    performSave(withName: uniqueName)
                }
                Button("button.cancel", role: .cancel) {
                    pendingSaveName = ""
                }
            } message: {
                Text("publications.duplicate.message")
            }
            .onAppear {
                loadPublication()
            }
        }
    }
    
    private func loadPublication() {
        guard let publication = publication else { return }
        name = publication.name
        selectedType = publication.type ?? .magazine
        url = publication.url ?? ""
        hasDeadline = publication.hasDeadline
        deadline = publication.deadline ?? Date().addingTimeInterval(86400 * 30)
        notes = publication.notes ?? ""
    }
    
    private func savePublication() {
        // Validate
        guard validateInput() else { return }
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for duplicates (only when creating new or changing name)
        if publication == nil || publication?.name != trimmedName {
            if hasDuplicateName(trimmedName) {
                pendingSaveName = trimmedName
                showingDuplicateWarning = true
                return
            }
        }
        
        performSave(withName: trimmedName)
    }
    
    private func performSave(withName finalName: String) {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let publication = publication {
            // Edit existing
            publication.name = finalName
            publication.type = selectedType
            publication.url = trimmedURL.isEmpty ? nil : trimmedURL
            publication.deadline = hasDeadline ? deadline : nil
            publication.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            publication.modifiedDate = Date()
        } else {
            // Create new
            let newPublication = Publication(
                name: finalName,
                type: selectedType,
                url: trimmedURL.isEmpty ? nil : trimmedURL,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                deadline: hasDeadline ? deadline : nil,
                project: project
            )
            modelContext.insert(newPublication)
        }
        
        dismiss()
    }
    
    private func hasDuplicateName(_ name: String) -> Bool {
        let projectPublications = allPublications.filter { pub in
            pub.project?.id == project.id && pub.id != publication?.id
        }
        return projectPublications.contains { $0.name.lowercased() == name.lowercased() }
    }
    
    private func makeUniqueName(_ baseName: String) -> String {
        let projectPublications = allPublications.filter { pub in
            pub.project?.id == project.id && pub.id != publication?.id
        }
        
        var counter = 1
        var uniqueName = "\(baseName)-1"
        
        while projectPublications.contains(where: { $0.name.lowercased() == uniqueName.lowercased() }) {
            counter += 1
            uniqueName = "\(baseName)-\(counter)"
        }
        
        return uniqueName
    }
    
    private func validateInput() -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate name
        if trimmedName.isEmpty {
            errorMessage = NSLocalizedString("publications.error.name.empty", comment: "Empty name error")
            showingError = true
            return false
        }
        
        if trimmedName.count > 100 {
            errorMessage = NSLocalizedString("publications.error.name.toolong", comment: "Name too long error")
            showingError = true
            return false
        }
        
        // Validate URL if provided
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedURL.isEmpty {
            if let url = URL(string: trimmedURL), url.scheme != nil {
                // Valid URL
            } else {
                errorMessage = NSLocalizedString("publications.error.url.invalid", comment: "Invalid URL error")
                showingError = true
                return false
            }
        }
        
        return true
    }
}

#Preview("Add Publication") {
    PublicationFormView(project: Project(name: "Test Project"), publication: nil)
        .modelContainer(for: [Project.self, Publication.self], inMemory: true)
}

#Preview("Edit Publication") {
    let publication = Publication(
        name: "Test Magazine",
        type: .magazine,
        url: "https://example.com",
        notes: "Test notes",
        deadline: Date().addingTimeInterval(86400 * 30)
    )
    return PublicationFormView(project: Project(name: "Test Project"), publication: publication)
        .modelContainer(for: [Project.self, Publication.self], inMemory: true)
}
