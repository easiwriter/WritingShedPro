//
//  AddPlotElementSheet.swift
//  Writing Shed Pro
//
//  Feature 022: Smart Fiction Creation - Add plot element form
//

import SwiftUI
import SwiftData

/// Sheet for adding a new plot element to a fiction project
struct AddPlotElementSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    
    // MARK: - State
    
    @State private var title: String = ""
    @State private var plotDescription: String = ""
    @State private var selectedMonomythStage: MonomythStage?
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // MARK: - Computed
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var nextOrderIndex: Int {
        let elements = project.plotElements ?? []
        return (elements.map { $0.userOrder ?? 0 }.max() ?? -1) + 1
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Basic Info
                Section {
                    TextField(NSLocalizedString("fiction.plot.element.title", comment: "Title"), text: $title)
                        .accessibilityLabel(NSLocalizedString("fiction.plot.element.title.accessibility", comment: "Plot element title"))
                } header: {
                    Text(NSLocalizedString("fiction.plot.element.section.basic", comment: "Basic Info"))
                }
                
                // Description
                Section {
                    TextEditor(text: $plotDescription)
                        .frame(minHeight: 100)
                        .accessibilityLabel(NSLocalizedString("fiction.plot.element.description.accessibility", comment: "Plot element description"))
                } header: {
                    Text(NSLocalizedString("fiction.plot.element.description", comment: "Description"))
                } footer: {
                    Text(NSLocalizedString("fiction.plot.element.description.footer", comment: "Describe what happens at this plot point"))
                }
                
                // Monomyth Stage (if project uses monomyth)
                if project.useMonomyth {
                    Section {
                        Picker(NSLocalizedString("fiction.plot.element.stage", comment: "Story Stage"), selection: $selectedMonomythStage) {
                            Text(NSLocalizedString("fiction.plot.element.stage.none", comment: "None"))
                                .tag(nil as MonomythStage?)
                            
                            ForEach(MonomythStage.allCases, id: \.self) { stage in
                                HStack {
                                    Text("\(stage.order + 1).")
                                    Text(NSLocalizedString("monomyth.\(stage.rawValue)", comment: "Stage name"))
                                }
                                .tag(stage as MonomythStage?)
                            }
                        }
                        
                        if let stage = selectedMonomythStage {
                            Text(NSLocalizedString("monomyth.\(stage.rawValue).description", comment: "Stage description"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text(NSLocalizedString("fiction.plot.element.section.monomyth", comment: "Hero's Journey"))
                    } footer: {
                        Text(NSLocalizedString("fiction.plot.element.stage.footer", comment: "Assign to a stage of the Hero's Journey"))
                    }
                }
            }
            .navigationTitle(NSLocalizedString("fiction.plot.element.add.title", comment: "Add Plot Element"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.add", comment: "Add")) {
                        addPlotElement()
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
    
    private func addPlotElement() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else {
            errorMessage = NSLocalizedString("fiction.plot.element.error.titleRequired", comment: "Title required")
            showErrorAlert = true
            return
        }
        
        let element = PlotElement(
            name: trimmedTitle,
            notes: plotDescription.isEmpty ? nil : plotDescription,
            monomythStage: selectedMonomythStage,
            userOrder: nextOrderIndex
        )
        element.project = project
        
        modelContext.insert(element)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}
