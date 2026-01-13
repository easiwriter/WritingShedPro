//
//  AddSectionSheet.swift
//  Writing Shed Pro
//
//  Prose - Add section form
//

import SwiftUI
import SwiftData

/// Sheet for adding a new section to a Prose project
struct AddSectionSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    
    // MARK: - State
    
    @State private var title: String = ""
    @State private var summary: String = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // MARK: - Computed
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var nextOrderIndex: Int {
        let sections = project.sections ?? []
        return (sections.map { $0.userOrder ?? 0 }.max() ?? -1) + 1
    }
    
    private var suggestedTitle: String {
        String(format: NSLocalizedString("prose.section.defaultTitle", comment: "Section X"), nextOrderIndex + 1)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Info
                Section {
                    TextField(NSLocalizedString("prose.section.title", comment: "Title"), text: $title)
                        .accessibilityLabel(NSLocalizedString("prose.section.title.accessibility", comment: "Section title"))
                } header: {
                    Text(NSLocalizedString("prose.section.section.basic", comment: "Basic Info"))
                } footer: {
                    Text(String(format: NSLocalizedString("prose.section.number", comment: "Section X"), nextOrderIndex + 1))
                }
                
                // Synopsis
                Section {
                    TextEditor(text: $summary)
                        .frame(minHeight: 80)
                        .accessibilityLabel(NSLocalizedString("prose.section.synopsis.accessibility", comment: "Section synopsis"))
                } header: {
                    Text(NSLocalizedString("prose.section.synopsis", comment: "Synopsis"))
                } footer: {
                    Text(NSLocalizedString("prose.section.synopsis.footer", comment: "Brief overview of the section"))
                }
            }
            .navigationTitle(NSLocalizedString("prose.section.add.title", comment: "Add Section"))
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
                        addSection()
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
    
    private func addSection() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else {
            errorMessage = NSLocalizedString("prose.section.error.titleRequired", comment: "Title required")
            showErrorAlert = true
            return
        }
        
        let section = ProseSection(
            name: trimmedTitle,
            synopsis: summary.isEmpty ? nil : summary,
            userOrder: nextOrderIndex
        )
        section.project = project
        
        modelContext.insert(section)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}
