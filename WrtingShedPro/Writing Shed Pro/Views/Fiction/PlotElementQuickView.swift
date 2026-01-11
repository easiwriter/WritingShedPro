//
//  PlotElementQuickView.swift
//  Writing Shed Pro
//
//  Quick read-only view of a plot element's description, characters, and locations
//  Displayed when tapping a plot element in the editor insert menu
//  Does not show story stage information
//

import SwiftUI

/// Quick read-only view showing plot element details without story stage
struct PlotElementQuickView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    let plotElement: PlotElement
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Description section
                    if let notes = plotElement.notes, !notes.isEmpty {
                        descriptionSection(notes)
                    }
                    
                    // Characters section
                    if let characters = plotElement.characters, !characters.isEmpty {
                        charactersSection(characters)
                    }
                    
                    // Locations section
                    if let locations = plotElement.locations, !locations.isEmpty {
                        locationsSection(locations)
                    }
                    
                    // Show message if no content
                    if (plotElement.notes?.isEmpty ?? true) &&
                       (plotElement.characters?.isEmpty ?? true) &&
                       (plotElement.locations?.isEmpty ?? true) {
                        noContentMessage
                    }
                }
                .padding()
            }
            .navigationTitle(plotElement.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
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
    
    private func descriptionSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("fiction.plot.element.description", comment: "Description"))
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text(notes)
                .font(.body)
        }
    }
    
    private func charactersSection(_ characters: [Character]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("fiction.plot.element.section.characters", comment: "Characters"))
                .font(.headline)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(characters.sorted { ($0.name ?? "") < ($1.name ?? "") }, id: \.id) { character in
                    Label(character.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"), systemImage: "person.fill")
                        .font(.body)
                }
            }
        }
    }
    
    private func locationsSection(_ locations: [Location]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("fiction.plot.element.section.locations", comment: "Locations"))
                .font(.headline)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(locations.sorted { ($0.name ?? "") < ($1.name ?? "") }, id: \.id) { location in
                    Label(location.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"), systemImage: "mappin.circle.fill")
                        .font(.body)
                }
            }
        }
    }
    
    private var noContentMessage: some View {
        ContentUnavailableView(
            NSLocalizedString("fiction.plot.noDetails.title", comment: "No Details"),
            systemImage: "bookmark",
            description: Text(NSLocalizedString("fiction.plot.noDetails.message", comment: "No description, characters, or locations have been added for this plot element."))
        )
    }
}
