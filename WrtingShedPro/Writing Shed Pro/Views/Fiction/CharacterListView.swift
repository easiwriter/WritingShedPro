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
            ForEach(sortedCharacters) { character in
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
        character.project?.modifiedDate = Date()
        WriteCoalescer.shared?.requestSave(reason: "character-list-delete")
        WriteCoalescer.shared?.flush()
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
            
            if let role = character.roleDisplayName {
                Text(role)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
