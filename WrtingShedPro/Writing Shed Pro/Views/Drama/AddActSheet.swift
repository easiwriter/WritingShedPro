//
//  AddActSheet.swift
//  Writing Shed Pro
//
//  Drama - Add act form
//

import SwiftUI
import SwiftData

/// Sheet for adding a new act to a Drama project
struct AddActSheet: View {
    
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
        let acts = project.acts ?? []
        return (acts.map { $0.userOrder ?? 0 }.max() ?? -1) + 1
    }
    
    private var suggestedTitle: String {
        String(format: NSLocalizedString("drama.act.defaultTitle", comment: "Act X"), nextOrderIndex + 1)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Info
                Section {
                    TextField(NSLocalizedString("drama.act.title", comment: "Title"), text: $title)
                        .accessibilityLabel(NSLocalizedString("drama.act.title.accessibility", comment: "Act title"))
                } header: {
                    Text(NSLocalizedString("drama.act.section.basic", comment: "Basic Info"))
                } footer: {
                    Text(String(format: NSLocalizedString("drama.act.number", comment: "Act X"), nextOrderIndex + 1))
                }
                
                // Synopsis
                Section {
                    TextEditor(text: $summary)
                        .frame(minHeight: 80)
                        .accessibilityLabel(NSLocalizedString("drama.act.synopsis.accessibility", comment: "Act synopsis"))
                } header: {
                    Text(NSLocalizedString("drama.act.synopsis", comment: "Synopsis"))
                } footer: {
                    Text(NSLocalizedString("drama.act.synopsis.footer", comment: "Brief overview of the act"))
                }
            }
            .navigationTitle(NSLocalizedString("drama.act.add.title", comment: "Add Act"))
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
                        addAct()
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
    
    private func addAct() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else {
            errorMessage = NSLocalizedString("drama.act.error.titleRequired", comment: "Title required")
            showErrorAlert = true
            return
        }
        
        let act = Act(
            name: trimmedTitle,
            synopsis: summary.isEmpty ? nil : summary,
            userOrder: nextOrderIndex
        )
        act.project = project
        
        modelContext.insert(act)
        
        do {
            project.modifiedDate = Date()
            try WriteCoalescer.shared.requestSaveAndFlush(reason: "add-act")
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}
