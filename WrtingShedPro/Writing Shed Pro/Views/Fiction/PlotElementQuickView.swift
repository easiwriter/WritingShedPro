//
//  PlotElementQuickView.swift
//  Writing Shed Pro
//
//  Quick read-only view of a plot element's details
//  Displayed when tapping a plot element in the editor toolbar
//

import SwiftUI

/// Quick read-only view showing plot element details including story stage and linked scenes
struct PlotElementQuickView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    let plotElement: PlotElement
    
    private var isVerseNovel: Bool {
        plotElement.project?.fictionClass == .verseNovel
    }
    
    private var linkedScenes: [StoryScene] {
        (plotElement.linkedScenes ?? []).sorted {
            ($0.userOrder ?? 0) < ($1.userOrder ?? 0)
        }
    }
    
    private var hasAnyContent: Bool {
        if let notes = plotElement.notes, !notes.isEmpty { return true }
        if plotElement.stageOrder != nil { return true }
        if let characters = plotElement.characters, !characters.isEmpty { return true }
        if let locations = plotElement.locations, !locations.isEmpty { return true }
        if let scenes = plotElement.linkedScenes, !scenes.isEmpty { return true }
        return false
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Description section
                    if let notes = plotElement.notes, !notes.isEmpty {
                        descriptionSection(notes)
                    }
                    
                    // Story stage section
                    if let stageOrder = plotElement.stageOrder, let stageName = plotElement.stageLocalizedName {
                        stageSection(order: stageOrder, name: stageName)
                    }
                    
                    // Characters section
                    if let characters = plotElement.characters, !characters.isEmpty {
                        charactersSection(characters)
                    }
                    
                    // Locations section
                    if let locations = plotElement.locations, !locations.isEmpty {
                        locationsSection(locations)
                    }
                    
                    // Linked scenes/episodes section
                    if !linkedScenes.isEmpty {
                        linkedScenesSection
                    }
                    
                    // Show message if no content at all
                    if !hasAnyContent {
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
    
    private func stageSection(order: Int, name: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plotElement.project?.storyStructure.usesMonomyth == true
                ? NSLocalizedString("fiction.plot.element.section.monomyth", comment: "Hero's Journey")
                : NSLocalizedString("fiction.plot.element.section.threeAct", comment: "Three-Act Structure"))
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Label("\(order). \(name)", systemImage: "star.circle.fill")
                .font(.body)
        }
    }
    
    private var linkedScenesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isVerseNovel
                ? NSLocalizedString("fiction.plot.element.section.linkedEpisodes", comment: "Linked Episodes")
                : NSLocalizedString("fiction.plot.element.section.scenes", comment: "Scenes"))
                .font(.headline)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(linkedScenes, id: \.id) { scene in
                    HStack {
                        Label(scene.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"), systemImage: "film")
                            .font(.body)
                        Spacer()
                        if let order = scene.userOrder {
                            Text("#\(order + 1)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
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
