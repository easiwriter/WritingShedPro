//
//  LocationQuickView.swift
//  Writing Shed Pro
//
//  Quick read-only view of a location's details
//  Displayed when tapping a location in the editor insert menu
//

import SwiftUI

/// Quick read-only view showing location details
struct LocationQuickView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    let location: Location
    
    private var hasDetails: Bool {
        !consolidatedDetails.isEmpty
    }

    private var consolidatedDetails: String {
        let parts = [location.detail, location.sights, location.sounds, location.smells]
            .compactMap { value -> String? in
                guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                    return nil
                }
                return trimmed
            }
        return parts.joined(separator: "\n\n")
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Details section
                    if hasDetails {
                        detailsSection
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
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailField(NSLocalizedString("fiction.location.section.details", comment: "Location Details"), value: consolidatedDetails)
        }
    }
    
    private func detailField(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
    }
    
    private var noContentMessage: some View {
        ContentUnavailableView(
            NSLocalizedString("fiction.location.noDetails.title", comment: "No Details"),
            systemImage: "mappin.circle.fill",
            description: Text(NSLocalizedString("fiction.location.noDetails.message", comment: "No details have been added for this location."))
        )
    }
}
