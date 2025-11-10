//
//  SubmissionPickerView.swift
//  Writing Shed Pro
//
//  Feature 008b Phase 3: Submission workflow from Ready folder
//

import SwiftUI
import SwiftData

struct SubmissionPickerView: View {
    @Environment(\.modelContext) private var modelContext
    
    let project: Project
    let filesToSubmit: [TextFile]
    let onPublicationSelected: (Publication) -> Void
    let onCancel: () -> Void
    
    @Query private var allPublications: [Publication]
    @State private var showingNewPublicationSheet = false
    
    // Filter publications for this project
    private var projectPublications: [Publication] {
        allPublications.filter { $0.project?.id == project.id }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
    }
    
    var body: some View {
        List {
            // New Publication button section
            Section {
                Button(action: { showingNewPublicationSheet = true }) {
                    Label(NSLocalizedString("publications.button.add", comment: "Add publication"), 
                          systemImage: "plus.circle.fill")
                        .foregroundStyle(.blue)
                }
                .accessibilityLabel(Text(NSLocalizedString("accessibility.add.publication", comment: "Add publication")))
            }
            
            // Existing publications
            if !projectPublications.isEmpty {
                Section {
                    ForEach(projectPublications) { publication in
                        Button(action: {
                            onPublicationSelected(publication)
                        }) {
                            HStack {
                                Text(publication.type?.icon ?? "")
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(publication.name ?? "")
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    
                                    if let type = publication.type {
                                        Text(type.displayName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .accessibilityLabel(Text(String(format: NSLocalizedString("accessibility.submit.to", comment: "Submit to"), publication.name ?? "")))
                    }
                } header: {
                    Text(NSLocalizedString("publications.existing.title", comment: "Existing publications"))
                }
            } else {
                // Empty state
                Section {
                    ContentUnavailableView {
                        Label(NSLocalizedString("publications.empty.title", comment: "No publications"), 
                              systemImage: "doc.text.magnifyingglass")
                    } description: {
                        Text(NSLocalizedString("publications.empty.message", comment: "Create your first publication"))
                    }
                }
            }
        }
        .navigationTitle(String(format: NSLocalizedString("submissions.submit.count", comment: "Submit N files"), filesToSubmit.count))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                    onCancel()
                }
            }
        }
        .sheet(isPresented: $showingNewPublicationSheet) {
            NavigationStack {
                NewPublicationForSubmissionView(
                    project: project,
                    filesToSubmit: filesToSubmit,
                    onPublicationCreated: { publication in
                        showingNewPublicationSheet = false
                        onPublicationSelected(publication)
                    },
                    onCancel: {
                        showingNewPublicationSheet = false
                    }
                )
            }
        }
    }
}

/// View for creating a new publication during submission flow
struct NewPublicationForSubmissionView: View {
    @Environment(\.modelContext) private var modelContext
    
    let project: Project
    let filesToSubmit: [TextFile]
    let onPublicationCreated: (Publication) -> Void
    let onCancel: () -> Void
    
    @State private var name: String = ""
    @State private var selectedType: PublicationType = .magazine
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        Form {
            Section {
                TextField(NSLocalizedString("publications.form.name.placeholder", comment: "Name placeholder"), text: $name)
                    .accessibilityLabel(Text(NSLocalizedString("publications.form.name.label", comment: "Publication name")))
            } header: {
                Text(NSLocalizedString("publications.form.name.label", comment: "Name"))
            }
            
            Section {
                Picker(NSLocalizedString("publications.form.type.label", comment: "Type"), selection: $selectedType) {
                    ForEach([PublicationType.magazine, .competition, .commission, .other], id: \.self) { type in
                        HStack {
                            Text(type.icon)
                            Text(type.displayName)
                        }
                        .tag(type)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text(NSLocalizedString("publications.form.type.label", comment: "Type"))
            }
            
            Section {
                HStack {
                    ForEach(filesToSubmit, id: \.id) { file in
                        Text(file.name)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            } header: {
                Text(String(format: NSLocalizedString("submissions.files.selected", comment: "Files selected"), filesToSubmit.count))
            }
        }
        .navigationTitle(NSLocalizedString("publications.new.quick.title", comment: "Quick add publication"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                    onCancel()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button(NSLocalizedString("publications.button.create", comment: "Create")) {
                    createPublicationAndSubmit()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .alert(NSLocalizedString("publications.error.title", comment: "Error"), isPresented: $showingError) {
            Button(NSLocalizedString("button.ok", comment: "OK"), role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func createPublicationAndSubmit() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedName.isEmpty else {
            errorMessage = NSLocalizedString("publications.error.name.empty", comment: "Name required")
            showingError = true
            return
        }
        
        guard trimmedName.count <= 100 else {
            errorMessage = NSLocalizedString("publications.error.name.toolong", comment: "Name too long")
            showingError = true
            return
        }
        
        // Create publication
        let publication = Publication(
            name: trimmedName,
            type: selectedType,
            project: project
        )
        modelContext.insert(publication)
        
        // Notify parent to create submission
        onPublicationCreated(publication)
    }
}
