//
//  CharacterQuickView.swift
//  Writing Shed Pro
//
//  Quick read-only view of a character's biography and archetype
//  Displayed when tapping a character in the editor insert menu
//

import SwiftUI

/// Quick read-only view showing character biography and archetype
struct CharacterQuickView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    let character: Character
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Archetype section
                    if let archetype = character.archetype {
                        archetypeSection(archetype)
                    }
                    
                    // Biography section
                    if let biography = character.biography, !biography.isEmpty {
                        biographySection(biography)
                    }
                    
                    // Show message if no content
                    if character.archetype == nil && (character.biography?.isEmpty ?? true) {
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
            
            Text(NSLocalizedString("archetype.\(archetype.rawValue)", comment: "Archetype"))
                .font(.title3)
                .fontWeight(.medium)
            
            Text(NSLocalizedString("archetype.\(archetype.rawValue).description", comment: "Description"))
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
    
    private func biographySection(_ biography: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("fiction.character.biography", comment: "Biography"))
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text(biography)
                .font(.body)
        }
    }
    
    private var noContentMessage: some View {
        ContentUnavailableView(
            NSLocalizedString("fiction.character.noDetails.title", comment: "No Details"),
            systemImage: "person.fill",
            description: Text(NSLocalizedString("fiction.character.noDetails.message", comment: "No biography or archetype has been added for this character."))
        )
    }
}
