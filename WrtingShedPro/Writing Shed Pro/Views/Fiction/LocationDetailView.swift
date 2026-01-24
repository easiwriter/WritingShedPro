//
//  LocationDetailView.swift
//  Writing Shed Pro
//
//  Feature 022: Smart Fiction Creation - Location detail/edit view
//

import SwiftUI
import SwiftData

/// Detail view for viewing and editing a location
struct LocationDetailView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    @Bindable var location: Location
    
    // MARK: - State
    
    @State private var isEditing = false
    @State private var editName: String = ""
    @State private var editDetail: String = ""
    @State private var editSights: String = ""
    @State private var editSounds: String = ""
    @State private var editSmells: String = ""
    @State private var showDeleteConfirmation = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                if isEditing {
                    editingContent
                } else {
                    viewingContent
                }
            }
            .navigationTitle(location.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isEditing {
                        Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                            isEditing = false
                        }
                    } else {
                        Button(NSLocalizedString("button.done", comment: "Done")) {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if isEditing {
                        Button(NSLocalizedString("button.save", comment: "Save")) {
                            saveChanges()
                        }
                        .disabled(editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else {
                        Button(NSLocalizedString("button.edit", comment: "Edit")) {
                            startEditing()
                        }
                    }
                }
            }
            .alert(
                NSLocalizedString("fiction.locations.deleteConfirm.title", comment: "Delete?"),
                isPresented: $showDeleteConfirmation
            ) {
                Button(NSLocalizedString("button.delete", comment: "Delete"), role: .destructive) {
                    deleteLocation()
                }
                Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
            } message: {
                Text(String(format: NSLocalizedString("fiction.locations.deleteConfirm.message", comment: "Delete message"), location.name ?? ""))
            }
        }
    }
    
    // MARK: - Viewing Content
    
    @ViewBuilder
    private var viewingContent: some View {
        // Basic Info
        Section {
            LabeledContent(NSLocalizedString("fiction.location.name", comment: "Name")) {
                Text(location.name ?? "-")
            }
        } header: {
            Text(NSLocalizedString("fiction.location.section.basic", comment: "Basic Info"))
        }
        
        // Location Details (Detail, Sights, Sounds, Smells)
        let hasDetail = location.detail != nil && !location.detail!.isEmpty
        let hasSights = location.sights != nil && !location.sights!.isEmpty
        let hasSounds = location.sounds != nil && !location.sounds!.isEmpty
        let hasSmells = location.smells != nil && !location.smells!.isEmpty
        
        if hasDetail || hasSights || hasSounds || hasSmells {
            Section {
                if hasDetail {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("fiction.location.detail", comment: "Detail"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(location.detail!)
                    }
                }
                if hasSights {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("fiction.location.sights", comment: "Sights"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(location.sights!)
                    }
                }
                if hasSounds {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("fiction.location.sounds", comment: "Sounds"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(location.sounds!)
                    }
                }
                if hasSmells {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("fiction.location.smells", comment: "Smells"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(location.smells!)
                    }
                }
            } header: {
                Text(NSLocalizedString("fiction.location.section.details", comment: "Location Details"))
            }
        }
        
        // Custom Attributes
        if let attributes = location.customAttributes, !attributes.isEmpty {
            Section {
                ForEach(attributes) { attribute in
                    LabeledContent(attribute.key ?? "") {
                        Text(attribute.value ?? "")
                    }
                }
            } header: {
                Text(NSLocalizedString("fiction.location.attributes", comment: "Custom Attributes"))
            }
        }
        
        // Scenes at this location
        if let scenes = location.scenes, !scenes.isEmpty {
            Section {
                ForEach(scenes.sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }) { scene in
                    Text(scene.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
                }
            } header: {
                Text(NSLocalizedString("fiction.location.scenes", comment: "Scenes Here"))
            }
        }
        
        // Delete button
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text(NSLocalizedString("fiction.location.delete", comment: "Delete Location"))
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Editing Content
    
    @ViewBuilder
    private var editingContent: some View {
        // Basic Info
        Section {
            TextField(NSLocalizedString("fiction.location.name", comment: "Name"), text: $editName)
        } header: {
            Text(NSLocalizedString("fiction.location.section.basic", comment: "Basic Info"))
        }
        
        // Location Details
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("fiction.location.detail", comment: "Detail"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $editDetail)
                    .frame(minHeight: 60)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("fiction.location.sights", comment: "Sights"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $editSights)
                    .frame(minHeight: 60)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("fiction.location.sounds", comment: "Sounds"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $editSounds)
                    .frame(minHeight: 60)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("fiction.location.smells", comment: "Smells"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $editSmells)
                    .frame(minHeight: 60)
            }
        } header: {
            Text(NSLocalizedString("fiction.location.section.details", comment: "Location Details"))
        }
    }
    
    // MARK: - Actions
    
    private func startEditing() {
        editName = location.name ?? ""
        editDetail = location.detail ?? ""
        editSights = location.sights ?? ""
        editSounds = location.sounds ?? ""
        editSmells = location.smells ?? ""
        isEditing = true
    }
    
    private func saveChanges() {
        location.name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        location.detail = editDetail.isEmpty ? nil : editDetail
        location.sights = editSights.isEmpty ? nil : editSights
        location.sounds = editSounds.isEmpty ? nil : editSounds
        location.smells = editSmells.isEmpty ? nil : editSmells
        
        try? modelContext.save()
        isEditing = false
    }
    
    private func deleteLocation() {
        modelContext.delete(location)
        try? modelContext.save()
        dismiss()
    }
}
