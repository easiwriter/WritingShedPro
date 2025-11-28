//
//  FootnoteDetailView.swift
//  Writing Shed Pro
//
//  Feature 015: Footnotes
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
    
    
    /// Callback to close the detail view
    var onClose: (() -> Void)?
    
    // MARK: - State
    
    @State private var editedText: String
    @State private var isEditing: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    
    // MARK: - Initialization
    
    init(
        footnote: FootnoteModel,
        onUpdate: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.footnote = footnote
        self.onUpdate = onUpdate
        self.onDelete = onDelete
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
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 36, height: 36)

                    Text("\(footnote.number)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: NSLocalizedString("footnoteDetail.title", comment: "Footnote title"), footnote.number))
                        .font(.headline)

                    Text(footnote.createdAt, format: .dateTime.day().month().year().hour().minute())
                        .font(.caption)
                        .foregroundColor(.secondary)
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
            
            // Action buttons
            if isEditing {
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

                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Label("footnoteDetail.delete", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .accessibilityLabel("footnoteDetail.delete.accessibility")
                }
            }
            
            // Metadata section
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
        }
        .padding(16)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        .confirmationDialog(
            "footnoteDetail.confirmDelete.title",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("footnoteDetail.confirmDelete.button", role: .destructive) {
                deleteFootnote()
            }
            Button("button.cancel", role: .cancel) {}
        } message: {
            Text("footnoteDetail.confirmDelete.message")
        }
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
        // Migrate to permanent delete - kept for backward compatibility but now removed
        deleteFootnote()
    }
    
    private func deleteFootnote() {
        FootnoteManager.shared.deleteFootnote(footnote, context: modelContext)
        onDelete?()
    }
}
