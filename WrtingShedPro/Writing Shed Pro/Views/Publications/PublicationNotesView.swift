//
//  PublicationNotesView.swift
//  Writing Shed Pro
//
//  Feature 008b: Publication Notes Display/Edit
//

import SwiftUI

/// Sheet view for displaying and editing publication notes
struct PublicationNotesView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var publication: Publication
    
    var body: some View {
        NavigationStack {
            ScrollView {
                TextEditor(text: Binding(
                    get: { publication.notes ?? "" },
                    set: { publication.notes = $0.isEmpty ? nil : $0 }
                ))
                .font(.body)
                .padding()
                .frame(minHeight: 300)
            }
            .navigationTitle(String(
                format: NSLocalizedString("publications.notes.title", comment: "Notes title"),
                publication.name
            ))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.dismiss") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("button.edit") {
                        // Edit button to indicate notes are editable
                        // Could add a separate edit mode if needed
                    }
                    .disabled(true) // Already in edit mode
                    .hidden() // Hide since TextEditor is always editable
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("accessibility.publication.notes.view"))
        }
    }
}
