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
    @State private var editDetails: String = ""
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
        
        // Location Details
        let detailsText = consolidatedLocationDetails()
        if !detailsText.isEmpty {
            Section {
                Text(detailsText)
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
            TextEditor(text: $editDetails)
                .frame(minHeight: 120)
        } header: {
            Text(NSLocalizedString("fiction.location.section.details", comment: "Location Details"))
        }
    }
    
    // MARK: - Actions
    
    private func startEditing() {
        editName = location.name ?? ""
        editDetails = consolidatedLocationDetails()
        isEditing = true
    }
    
    private func saveChanges() {
        location.name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        location.detail = editDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editDetails
        location.sights = nil
        location.sounds = nil
        location.smells = nil
        
        try? modelContext.save()
        isEditing = false
    }
    
    private func deleteLocation() {
        modelContext.delete(location)
        try? modelContext.save()
        dismiss()
    }

    private func consolidatedLocationDetails() -> String {
        let parts = [location.detail, location.sights, location.sounds, location.smells]
            .compactMap { value -> String? in
                guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                    return nil
                }
                return trimmed
            }
        return parts.joined(separator: "\n\n")
    }
}
