//
//  LocationQuickView.swift
//  Writing Shed Pro
//
//  Quick read-only view of a location's description
//  Displayed when tapping a location in the editor insert menu
//

import SwiftUI

/// Quick read-only view showing location description
struct LocationQuickView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    let location: Location
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Description section
                    if let description = location.locationDescription, !description.isEmpty {
                        descriptionSection(description)
                    } else {
                        noContentMessage
                    }
                }
                .padding()
            }
            .navigationTitle(location.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.done", comment: "Done")) {
                        dismiss()
                    }
                    .buttonStyle(QuickViewButtonStyle())
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("fiction.location.description", comment: "Description"))
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text(description)
                .font(.body)
        }
    }
    
    private var noContentMessage: some View {
        ContentUnavailableView(
            NSLocalizedString("fiction.location.noDetails.title", comment: "No Details"),
            systemImage: "mappin.circle.fill",
            description: Text(NSLocalizedString("fiction.location.noDetails.message", comment: "No description has been added for this location."))
        )
    }
}
