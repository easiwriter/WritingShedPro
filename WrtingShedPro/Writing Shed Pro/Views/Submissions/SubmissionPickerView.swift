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
                    Label("publications.button.add", systemImage: "plus.circle.fill")
                        .foregroundStyle(.blue)
                }
                .accessibilityLabel(Text("accessibility.add.publication"))
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
                    Text("publications.existing.title")
                }
            } else {
                // Empty state
                Section {
                    ContentUnavailableView {
                        Label("publications.empty.title", systemImage: "doc.text.magnifyingglass")
                    } description: {
                        Text("publications.empty.message")
                    }
                }
            }
        }
        .navigationTitle("submissions.submit.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("button.cancel") {
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
                TextField("publications.form.name.placeholder", text: $name)
                    .accessibilityLabel(Text("publications.form.name.label"))
            } header: {
                Text("publications.form.name.label")
            }
            
            Section {
                Picker("publications.form.type.label", selection: $selectedType) {
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
                Text("publications.form.type.label")
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
                Text("submissions.files.label")
            }
        }
        .navigationTitle("publications.new.quick.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("button.cancel") {
                    onCancel()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("publications.button.create") {
                    createPublicationAndSubmit()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .alert("publications.error.title", isPresented: $showingError) {
            Button("button.ok", role: .cancel) { }
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
