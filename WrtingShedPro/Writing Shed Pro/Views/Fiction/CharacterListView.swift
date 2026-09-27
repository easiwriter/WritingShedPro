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
        #if targetEnvironment(macCatalyst)
        .overlay { characterOverlay }
        #else
        .sheet(isPresented: $showAddCharacter) {
            AddCharacterSheet(project: project) { showAddCharacter = false }
        }
        .sheet(item: $selectedCharacter) { character in
            CharacterDetailView(character: character) { selectedCharacter = nil }
        }
        #endif
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

    #if targetEnvironment(macCatalyst)
    @ViewBuilder
    private var characterOverlay: some View {
        if showAddCharacter || selectedCharacter != nil {
            modalOverlay {
                if showAddCharacter {
                    AddCharacterSheet(project: project) { showAddCharacter = false }
                } else if let character = selectedCharacter {
                    CharacterDetailView(character: character) { selectedCharacter = nil }
                }
            }
        }
    }

    private func modalOverlay<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.28).ignoresSafeArea()
                content()
                    .frame(width: min(620, max(320, geometry.size.width - 48)), height: min(720, max(420, geometry.size.height - 48)))
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 12)
            }
        }
        .zIndex(1000)
    }
    #endif
    
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
        guard EntitlementManager.shared.canModifyContent else { return }
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
