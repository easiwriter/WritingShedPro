//
//  DramaMarkupToolbar.swift
//  Writing Shed Pro
//
//  Feature 023: Smart Drama Creation
//  Toolbar for inserting DML elements while writing
//

import SwiftUI

/// Toolbar for inserting Drama Markup Language elements
struct DramaMarkupToolbar: View {
    
    // MARK: - Properties
    
    /// Callback when an element should be inserted
    var onInsert: (DMLElementType, String) -> Void
    
    /// Currently selected text (for wrapping operations)
    var selectedText: String?
    
    // MARK: - State
    
    @State private var showCharacterInput = false
    @State private var characterName = ""
    
    @State private var showTransitionPicker = false
    
    // MARK: - Body
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Scene Heading
                toolbarButton(
                    icon: "film",
                    label: NSLocalizedString("drama.toolbar.sceneHeading", comment: "Scene"),
                    action: insertSceneHeading
                )
                
                // Action/Stage Direction
                toolbarButton(
                    icon: "figure.walk",
                    label: NSLocalizedString("drama.toolbar.action", comment: "Action"),
                    action: insertAction
                )
                
                // Character
                toolbarButton(
                    icon: "person.fill",
                    label: NSLocalizedString("drama.toolbar.character", comment: "Character"),
                    action: { showCharacterInput = true }
                )
                
                // Parenthetical
                toolbarButton(
                    icon: "parentheses",
                    label: NSLocalizedString("drama.toolbar.parenthetical", comment: "Paren"),
                    action: insertParenthetical
                )
                
                // Transition
                toolbarButton(
                    icon: "arrow.right.circle",
                    label: NSLocalizedString("drama.toolbar.transition", comment: "Transition"),
                    action: { showTransitionPicker = true }
                )
                
                // Note
                toolbarButton(
                    icon: "note.text",
                    label: NSLocalizedString("drama.toolbar.note", comment: "Note"),
                    action: insertNote
                )
                
                Divider()
                    .frame(height: 24)
                
                // Location metadata
                toolbarButton(
                    icon: "mappin.circle",
                    label: NSLocalizedString("drama.toolbar.location", comment: "Location"),
                    action: insertLocation
                )
                
                // Time metadata
                toolbarButton(
                    icon: "clock",
                    label: NSLocalizedString("drama.toolbar.time", comment: "Time"),
                    action: insertTime
                )
            }
            .padding(.horizontal)
        }
        .frame(height: 50)
        .background(Color(UIColor.secondarySystemBackground))
        .alert(NSLocalizedString("drama.toolbar.characterName", comment: "Character Name"), isPresented: $showCharacterInput) {
            TextField(NSLocalizedString("drama.toolbar.characterNamePlaceholder", comment: "Enter name"), text: $characterName)
                .textInputAutocapitalization(.characters)
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                characterName = ""
            }
            Button(NSLocalizedString("button.insert", comment: "Insert")) {
                insertCharacter(name: characterName)
                characterName = ""
            }
        } message: {
            Text(NSLocalizedString("drama.toolbar.characterNameMessage", comment: "Enter character name in ALL CAPS"))
        }
        .confirmationDialog(
            NSLocalizedString("drama.toolbar.selectTransition", comment: "Select Transition"),
            isPresented: $showTransitionPicker,
            titleVisibility: .visible
        ) {
            Button("CUT TO:") { insertTransition("CUT TO:") }
            Button("FADE OUT") { insertTransition("FADE OUT") }
            Button("FADE IN:") { insertTransition("FADE IN:") }
            Button("DISSOLVE TO:") { insertTransition("DISSOLVE TO:") }
            Button("SMASH CUT TO:") { insertTransition("SMASH CUT TO:") }
            Button("BLACKOUT") { insertTransition("BLACKOUT") }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
        }
    }
    
    // MARK: - Toolbar Button
    
    private func toolbarButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.caption2)
            }
            .frame(minWidth: 50)
        }
        .buttonStyle(.plain)
        .foregroundColor(.accentColor)
    }
    
    // MARK: - Insert Actions
    
    private func insertSceneHeading() {
        onInsert(.sceneHeading, "# ACT I, Scene 1")
    }
    
    private func insertAction() {
        let text = selectedText?.isEmpty == false ? selectedText! : "Action description"
        onInsert(.action, "> \(text)")
    }
    
    private func insertCharacter(name: String) {
        let uppercaseName = name.uppercased()
        onInsert(.character, uppercaseName)
    }
    
    private func insertParenthetical() {
        let text = selectedText?.isEmpty == false ? selectedText! : "emotion"
        onInsert(.parenthetical, "(\(text))")
    }
    
    private func insertTransition(_ transition: String) {
        onInsert(.transition, ">> \(transition)")
    }
    
    private func insertNote() {
        let text = selectedText?.isEmpty == false ? selectedText! : "Writer's note"
        onInsert(.note, "[[\(text)]]")
    }
    
    private func insertLocation() {
        onInsert(.locationMeta, "@ LOCATION: ")
    }
    
    private func insertTime() {
        onInsert(.timeMeta, "= Day")
    }
}
