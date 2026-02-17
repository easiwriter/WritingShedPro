//
//  AddPoetryCollectionSheet.swift
//  Writing Shed Pro
//
//  Feature 036: Sheet for adding a new Poetry Collection
//

import SwiftUI
import SwiftData

/// Sheet for adding a new poetry collection to a Poetry project
struct AddPoetryCollectionSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    
    // MARK: - State
    
    @State private var title: String = ""
    @State private var synopsis: String = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // MARK: - Computed
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var nextOrderIndex: Int {
        let collections = project.poetryCollections ?? []
        return (collections.map { $0.userOrder ?? 0 }.max() ?? -1) + 1
    }
    
    private var suggestedTitle: String {
        String(format: NSLocalizedString("poetry.collection.defaultTitle", comment: "Collection X"), nextOrderIndex + 1)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Info
                Section {
                    TextField(NSLocalizedString("poetry.collection.name", comment: "Name"), text: $title)
                        .accessibilityLabel(NSLocalizedString("poetry.collection.name.accessibility", comment: "Collection name"))
                } header: {
                    Text(NSLocalizedString("poetry.collection.section.basic", comment: "Basic Info"))
                } footer: {
                    Text(String(format: NSLocalizedString("poetry.collection.number", comment: "Collection X"), nextOrderIndex + 1))
                }
                
                // Synopsis
                Section {
                    TextEditor(text: $synopsis)
                        .frame(minHeight: 80)
                        .accessibilityLabel(NSLocalizedString("poetry.collection.synopsis.accessibility", comment: "Collection synopsis"))
                } header: {
                    Text(NSLocalizedString("poetry.collection.synopsis", comment: "Synopsis"))
                } footer: {
                    Text(NSLocalizedString("poetry.collection.synopsis.footer", comment: "Brief description of this collection"))
                }
            }
            .navigationTitle(NSLocalizedString("poetry.collection.add.title", comment: "Add Collection"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if title.isEmpty {
                    title = suggestedTitle
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.add", comment: "Add")) {
                        addCollection()
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
    
    private func addCollection() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else {
            errorMessage = NSLocalizedString("poetry.collection.error.nameRequired", comment: "Name required")
            showErrorAlert = true
            return
        }
        
        let collection = PoetryCollection(
            name: trimmedTitle,
            synopsis: synopsis.isEmpty ? nil : synopsis,
            userOrder: nextOrderIndex
        )
        collection.project = project
        
        modelContext.insert(collection)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}
