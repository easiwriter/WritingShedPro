//
//  AddLocationSheet.swift
//  Writing Shed Pro
//
//  Feature 022: Smart Fiction Creation - Add location form
//

import SwiftUI
import SwiftData

/// Sheet for adding a new location to a fiction project
struct AddLocationSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    
    // MARK: - State
    
    @State private var name: String = ""
    @State private var details: String = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // MARK: - Computed
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Info
                Section {
                    TextField(NSLocalizedString("fiction.location.name", comment: "Name"), text: $name)
                        .accessibilityLabel(NSLocalizedString("fiction.location.name.accessibility", comment: "Location name"))
                } header: {
                    Text(NSLocalizedString("fiction.location.section.basic", comment: "Basic Info"))
                }
                
                // Location Details
                Section {
                    TextEditor(text: $details)
                        .frame(minHeight: 120)
                } header: {
                    Text(NSLocalizedString("fiction.location.section.details", comment: "Location Details"))
                }
            }
            .navigationTitle(NSLocalizedString("fiction.location.add.title", comment: "Add Location"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.add", comment: "Add")) {
                        addLocation()
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
        .navigationViewStyle(.stack)
    }
    
    // MARK: - Actions
    
    private func addLocation() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            errorMessage = NSLocalizedString("fiction.location.error.nameRequired", comment: "Name required")
            showErrorAlert = true
            return
        }
        
        let location = Location(
            name: trimmedName,
            detail: details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : details,
            sights: nil,
            sounds: nil,
            smells: nil
        )
        location.project = project
        
        modelContext.insert(location)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}
