//
//  PlotElementDetailView.swift
//  Writing Shed Pro
//
//  Feature 022: Smart Fiction Creation - Plot element detail/edit view
//

import SwiftUI
import SwiftData

/// Detail view for viewing and editing a plot element
struct PlotElementDetailView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    @Bindable var plotElement: PlotElement
    let project: Project
    
    // MARK: - State
    
    @State private var isEditing = false
    @State private var editTitle: String = ""
    @State private var editDescription: String = ""
    @State private var editMonomythStage: MonomythStage?
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
            .navigationTitle(plotElement.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
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
                        .disabled(editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else {
                        Button(NSLocalizedString("button.edit", comment: "Edit")) {
                            startEditing()
                        }
                    }
                }
            }
            .alert(
                NSLocalizedString("fiction.plot.deleteConfirm.title", comment: "Delete?"),
                isPresented: $showDeleteConfirmation
            ) {
                Button(NSLocalizedString("button.delete", comment: "Delete"), role: .destructive) {
                    deletePlotElement()
                }
                Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
            } message: {
                Text(String(format: NSLocalizedString("fiction.plot.deleteConfirm.message", comment: "Delete message"), plotElement.name ?? ""))
            }
        }
    }
    
    // MARK: - Viewing Content
    
    @ViewBuilder
    private var viewingContent: some View {
        // Basic Info
        Section {
            LabeledContent(NSLocalizedString("fiction.plot.element.title", comment: "Title")) {
                Text(plotElement.name ?? "-")
            }
        } header: {
            Text(NSLocalizedString("fiction.plot.element.section.basic", comment: "Basic Info"))
        }
        
        // Description
        if let notes = plotElement.notes, !notes.isEmpty {
            Section {
                Text(notes)
            } header: {
                Text(NSLocalizedString("fiction.plot.element.description", comment: "Description"))
            }
        }
        
        // Monomyth Stage
        if let stage = plotElement.monomythStage {
            Section {
                LabeledContent(NSLocalizedString("fiction.plot.element.stage", comment: "Stage")) {
                    Text("\(stage.order + 1). " + NSLocalizedString("monomyth.\(stage.rawValue)", comment: "Stage name"))
                }
                
                Text(NSLocalizedString("monomyth.\(stage.rawValue).description", comment: "Description"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text(NSLocalizedString("fiction.plot.element.section.monomyth", comment: "Hero's Journey"))
            }
        }
        
        // Delete button
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text(NSLocalizedString("fiction.plot.element.delete", comment: "Delete Plot Element"))
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
            TextField(NSLocalizedString("fiction.plot.element.title", comment: "Title"), text: $editTitle)
        } header: {
            Text(NSLocalizedString("fiction.plot.element.section.basic", comment: "Basic Info"))
        }
        
        // Description
        Section {
            TextEditor(text: $editDescription)
                .frame(minHeight: 100)
        } header: {
            Text(NSLocalizedString("fiction.plot.element.description", comment: "Description"))
        }
        
        // Monomyth Stage
        if project.useMonomyth {
            Section {
                Picker(NSLocalizedString("fiction.plot.element.stage", comment: "Stage"), selection: $editMonomythStage) {
                    Text(NSLocalizedString("fiction.plot.element.stage.none", comment: "None"))
                        .tag(nil as MonomythStage?)
                    
                    ForEach(MonomythStage.allCases, id: \.self) { stage in
                        HStack {
                            Text("\(stage.order + 1).")
                            Text(NSLocalizedString("monomyth.\(stage.rawValue)", comment: "Stage"))
                        }
                        .tag(stage as MonomythStage?)
                    }
                }
                
                if let stage = editMonomythStage {
                    Text(NSLocalizedString("monomyth.\(stage.rawValue).description", comment: "Description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text(NSLocalizedString("fiction.plot.element.section.monomyth", comment: "Hero's Journey"))
            }
        }
    }
    
    // MARK: - Actions
    
    private func startEditing() {
        editTitle = plotElement.name ?? ""
        editDescription = plotElement.notes ?? ""
        editMonomythStage = plotElement.monomythStage
        isEditing = true
    }
    
    private func saveChanges() {
        plotElement.name = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        plotElement.notes = editDescription.isEmpty ? nil : editDescription
        plotElement.monomythStage = editMonomythStage
        
        try? modelContext.save()
        isEditing = false
    }
    
    private func deletePlotElement() {
        modelContext.delete(plotElement)
        try? modelContext.save()
        dismiss()
    }
}
