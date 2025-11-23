//
//  FootnoteDetailView.swift
//  Writing Shed Pro
//
//  Feature 017: Footnotes
//  Created by GitHub Copilot on 21/11/2025.
//

import SwiftUI
import SwiftData

/// View for displaying and editing footnote details
struct FootnoteDetailView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Properties
    
    /// The footnote being displayed/edited
    let footnote: FootnoteModel
    
    /// Callback when footnote is updated
    var onUpdate: (() -> Void)?
    
    /// Callback when footnote is deleted
    var onDelete: (() -> Void)?
    
    /// Callback when footnote is restored from trash
    var onRestore: (() -> Void)?
    
    /// Callback to close the detail view
    var onClose: (() -> Void)?
    
    // MARK: - State
    
    @State private var editedText: String
    @State private var isEditing: Bool = false
    
    // MARK: - Initialization
    
    init(
        footnote: FootnoteModel,
        onUpdate: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onRestore: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.footnote = footnote
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onRestore = onRestore
        self.onClose = onClose
        self._editedText = State(initialValue: footnote.text)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Footnote number badge
                ZStack {
                    Circle()
                        .fill(footnote.isDeleted ? Color.gray.opacity(0.2) : Color.blue.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Text("\(footnote.number)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(footnote.isDeleted ? .gray : .blue)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: NSLocalizedString("footnoteDetail.title", comment: "Footnote title"), footnote.number))
                        .font(.headline)
                    
                    if footnote.isDeleted {
                        Text("footnoteDetail.inTrash")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Text(footnote.createdAt, format: .dateTime.day().month().year().hour().minute())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Close button
                Button(action: {
                    onClose?()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
            
            Divider()
            
            // Footnote content with rich text support
            if isEditing {
                VStack(alignment: .leading, spacing: 8) {
                    // Formatting toolbar
                    HStack(spacing: 16) {
                        Text("footnoteDetail.format")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Note: Rich text formatting will be added in future enhancement
                        // For V1, we support plain text editing
                        Text("footnoteDetail.richTextComingSoon")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    .padding(.horizontal, 8)
                    
                    TextEditor(text: $editedText)
                        .frame(minHeight: 200, maxHeight: 400)
                        .padding(8)
                        .background(Color(uiColor: .systemGray6))
                        .cornerRadius(8)
                        .scrollContentBackground(.hidden)
                }
            } else {
                ScrollView {
                    Text(footnote.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(minHeight: 100, maxHeight: 400)
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(8)
            }
            
            // Action buttons - conditional based on trash state
            if footnote.isDeleted {
                // Trash view: Show Restore and Permanent Delete
                HStack(spacing: 12) {
                    Button(action: restoreFootnote) {
                        Label("footnoteDetail.restore", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("footnoteDetail.restore.accessibility")
                    
                    Button(action: permanentlyDeleteFootnote) {
                        Label("footnoteDetail.deleteForever", systemImage: "trash.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("footnoteDetail.deleteForever.accessibility")
                }
            } else if isEditing {
                // Editing mode: Show Save and Cancel
                HStack(spacing: 12) {
                    Button(action: saveChanges) {
                        Label("button.save", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    
                    Button(action: {
                        editedText = footnote.text
                        isEditing = false
                    }) {
                        Label("button.cancel", systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            } else {
                // View mode: Show Edit and Delete
                HStack(spacing: 12) {
                    Button(action: { isEditing = true }) {
                        Label("footnoteDetail.edit", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("footnoteDetail.edit.accessibility")
                    
                    Button(action: moveToTrash) {
                        Label("footnoteDetail.delete", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .accessibilityLabel("footnoteDetail.delete.accessibility")
                }
            }
            
            // Metadata section
            if !footnote.isDeleted {
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: NSLocalizedString("footnoteDetail.position", comment: "Position label"), footnote.characterPosition))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if footnote.modifiedAt != footnote.createdAt {
                        Text(String(format: NSLocalizedString("footnoteDetail.modified", comment: "Modified label"), 
                                    footnote.modifiedAt.formatted(.dateTime.day().month().year().hour().minute())))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else if let deletedAt = footnote.deletedAt {
                Divider()
                
                Text(String(format: NSLocalizedString("footnoteDetail.deleted", comment: "Deleted label"),
                            deletedAt.formatted(.dateTime.day().month().year().hour().minute())))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Actions
    
    private func saveChanges() {
        guard editedText != footnote.text else {
            isEditing = false
            return
        }
        
        FootnoteManager.shared.updateFootnoteText(footnote, newText: editedText, context: modelContext)
        isEditing = false
        onUpdate?()
    }
    
    private func moveToTrash() {
        FootnoteManager.shared.moveFootnoteToTrash(footnote, context: modelContext)
        onDelete?()
    }
    
    private func restoreFootnote() {
        FootnoteManager.shared.restoreFootnote(footnote, context: modelContext)
        onRestore?()
    }
    
    private func permanentlyDeleteFootnote() {
        FootnoteManager.shared.permanentlyDeleteFootnote(footnote, context: modelContext)
        onDelete?()
    }
}

// MARK: - Preview

#Preview {
    let footnote = FootnoteModel(
        textFileID: UUID(),
        characterPosition: 100,
        text: "This is a sample footnote with detailed information about a specific point in the document.",
        number: 1
    )
    
    return FootnoteDetailView(footnote: footnote)
        .padding()
        .frame(width: 400)
}

#Preview("Deleted Footnote") {
    let footnote = FootnoteModel(
        textFileID: UUID(),
        characterPosition: 100,
        text: "This footnote has been deleted and is in the trash.",
        number: 3,
        isDeleted: true,
        deletedAt: Date()
    )
    
    return FootnoteDetailView(footnote: footnote)
        .padding()
        .frame(width: 400)
}
