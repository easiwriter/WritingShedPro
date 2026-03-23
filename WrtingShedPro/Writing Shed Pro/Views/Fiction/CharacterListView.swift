//
//  CharacterListView.swift
//  Writing Shed Pro
//
//  Feature 022: Smart Fiction Creation - Character management
//

import SwiftUI
import SwiftData

/// List view showing all characters for a fiction project
struct CharacterListView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Properties
    
    let project: Project
    
    // MARK: - State
    
    @State private var showAddCharacter = false
    @State private var selectedCharacter: Character?
    @State private var showDeleteConfirmation = false
    @State private var characterToDelete: Character?
    
    // MARK: - Computed
    
    private var sortedCharacters: [Character] {
        (project.characters ?? []).sorted { 
            ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending
        }
    }
    
    // Group characters by archetype
    private var charactersByArchetype: [(archetype: CharacterArchetype?, characters: [Character])] {
        var grouped: [CharacterArchetype?: [Character]] = [:]
        
        for character in sortedCharacters {
            let archetype = character.archetype
            grouped[archetype, default: []].append(character)
        }
        
        // Sort: archetypes first (in order), then nil (unassigned) last
        var result: [(CharacterArchetype?, [Character])] = []
        
        for archetype in CharacterArchetype.allCases {
            if let chars = grouped[archetype], !chars.isEmpty {
                result.append((archetype, chars))
            }
        }
        
        if let unassigned = grouped[nil], !unassigned.isEmpty {
            result.append((nil, unassigned))
        }
        
        return result
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if sortedCharacters.isEmpty {
                emptyState
            } else {
                characterList
            }
        }
        .navigationTitle(NSLocalizedString("fiction.characters.title", comment: "Characters"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddCharacter = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(NSLocalizedString("fiction.characters.add", comment: "Add character"))
            }
        }
        .sheet(isPresented: $showAddCharacter) {
            AddCharacterSheet(project: project)
        }
        .sheet(item: $selectedCharacter) { character in
            CharacterDetailView(character: character)
        }
        .alert(
            NSLocalizedString("fiction.characters.deleteConfirm.title", comment: "Delete character?"),
            isPresented: $showDeleteConfirmation,
            presenting: characterToDelete
        ) { character in
            Button(NSLocalizedString("button.delete", comment: "Delete"), role: .destructive) {
                deleteCharacter(character)
            }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
        } message: { character in
            Text(String(format: NSLocalizedString("fiction.characters.deleteConfirm.message", comment: "Delete message"), character.name ?? ""))
        }
    }
    
    // MARK: - Character List
    
    private var characterList: some View {
        List {
            ForEach(charactersByArchetype, id: \.archetype) { group in
                Section {
                    ForEach(group.characters) { character in
                        CharacterRowView(character: character)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedCharacter = character
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    characterToDelete = character
                                    showDeleteConfirmation = true
                                } label: {
                                    Label(NSLocalizedString("button.delete", comment: "Delete"), systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    if let archetype = group.archetype {
                        Text(archetype.localizedName)
                    } else {
                        Text(NSLocalizedString("fiction.characters.unassigned", comment: "Unassigned"))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("fiction.characters.empty.title", comment: "No characters"))
                .font(.headline)
            
            Text(NSLocalizedString("fiction.characters.empty.message", comment: "Empty message"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showAddCharacter = true
            } label: {
                Label(NSLocalizedString("fiction.characters.add", comment: "Add character"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func deleteCharacter(_ character: Character) {
        modelContext.delete(character)
        try? modelContext.save()
    }
}

// MARK: - Character Row View

struct CharacterRowView: View {
    let character: Character
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
                Text(character.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
                .font(.body)
                .fontWeight(.semibold)
            
            if let role = character.role, !role.isEmpty {
                Text(role)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            
            if let archetype = character.archetype {
                HStack(spacing: 4) {
                    Image(systemName: archetypeIcon(for: archetype))
                        .font(.footnote)
                    Text(archetype.localizedName)
                        .font(.footnote)
                }
                .foregroundColor(.blue)
            }
        }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func archetypeIcon(for archetype: CharacterArchetype) -> String {
        switch archetype {
        case .hero: return "star.fill"
        case .mentor: return "book.fill"
        case .herald: return "megaphone.fill"
        case .thresholdGuardian: return "shield.fill"
        case .shapeshifter: return "arrow.triangle.2.circlepath"
        case .shadow: return "moon.fill"
        case .ally: return "person.2.fill"
        case .trickster: return "theatermasks.fill"
        }
    }
}
