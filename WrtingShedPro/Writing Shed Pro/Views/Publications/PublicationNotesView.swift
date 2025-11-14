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

#Preview("Magazine with notes") {
    let publication = Publication(
        name: "OWP",
        type: .magazine,
        notes: """
        OBSESSED WITH PIPEWORK is a stapled A5 quarterly magazine of new poetry begun in Autumn 1997 as an essential complement to Flarestack Publishing's poetry pamphlet programme, to provide a platform for established or beginning writers' poems that surprise and delight.
        
        Subscription
        Subscriptions cost £12 for four issues by post. Publication dates are normally at the beginning of January, April, July and October.
        """
    )
    return PublicationNotesView(publication: publication)
}
