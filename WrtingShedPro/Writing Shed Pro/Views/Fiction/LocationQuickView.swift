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
        (location.detail != nil && !location.detail!.isEmpty) ||
        (location.sights != nil && !location.sights!.isEmpty) ||
        (location.sounds != nil && !location.sounds!.isEmpty) ||
        (location.smells != nil && !location.smells!.isEmpty)
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
            if let detail = location.detail, !detail.isEmpty {
                detailField(NSLocalizedString("fiction.location.detail", comment: "Detail"), value: detail)
            }
            if let sights = location.sights, !sights.isEmpty {
                detailField(NSLocalizedString("fiction.location.sights", comment: "Sights"), value: sights)
            }
            if let sounds = location.sounds, !sounds.isEmpty {
                detailField(NSLocalizedString("fiction.location.sounds", comment: "Sounds"), value: sounds)
            }
            if let smells = location.smells, !smells.isEmpty {
                detailField(NSLocalizedString("fiction.location.smells", comment: "Smells"), value: smells)
            }
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
