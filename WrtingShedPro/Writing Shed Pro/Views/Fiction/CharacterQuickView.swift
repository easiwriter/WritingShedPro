//
//  CharacterQuickView.swift
//  Writing Shed Pro
//
//  Quick read-only view of a character's details and archetype
//  Displayed when tapping a character in the editor insert menu
//

import SwiftUI

/// Quick read-only view showing character details and archetype
struct CharacterQuickView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    let character: Character
    
    private var hasDetails: Bool {
        !consolidatedDetails.isEmpty
    }

    private var consolidatedDetails: String {
        let parts = [character.history, character.looks, character.traits, character.work]
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
                    // Archetype section
                    if let archetype = character.archetype {
                        archetypeSection(archetype)
                    }
                    
                    // Character details section
                    if hasDetails {
                        detailsSection
                    }
                    
                    // Show message if no content
                    if character.archetype == nil && !hasDetails {
                        noContentMessage
                    }
                }
                .padding()
            }
            .navigationTitle(character.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
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
    
    private func archetypeSection(_ archetype: CharacterArchetype) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("fiction.character.archetype", comment: "Archetype"))
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text(archetype.localizedName)
                .font(.title3)
                .fontWeight(.medium)
            
            Text(archetype.description)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailField(NSLocalizedString("fiction.character.section.details", comment: "Character Details"), value: consolidatedDetails)
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
            NSLocalizedString("fiction.character.noDetails.title", comment: "No Details"),
            systemImage: "person.fill",
            description: Text(NSLocalizedString("fiction.character.noDetails.message", comment: "No details or archetype has been added for this character."))
        )
    }
}
