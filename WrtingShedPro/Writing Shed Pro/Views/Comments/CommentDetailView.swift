//
//  CommentDetailView.swift
//  Writing Shed Pro
//
//  Feature 014: Comments
//  Created by GitHub Copilot on 20/11/2025.
//

import SwiftUI
import SwiftData

/// View for displaying and editing comment details
struct CommentDetailView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Properties
    
    /// The comment being displayed/edited
    let comment: CommentModel
    
    /// Callback when comment is updated
    var onUpdate: (() -> Void)?
    
    /// Callback when comment is deleted (passes the deleted comment)
    var onDelete: ((CommentModel) -> Void)?
    
    /// Callback when comment is resolved/reopened
    var onResolveToggle: (() -> Void)?
    
    /// Callback to close the detail view
    var onClose: (() -> Void)?
    
    // MARK: - State
    
    @State private var editedText: String
    @State private var isEditing: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    
    // MARK: - Initialization
    
    init(
        comment: CommentModel,
        onUpdate: (() -> Void)? = nil,
        onDelete: ((CommentModel) -> Void)? = nil,
        onResolveToggle: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.comment = comment
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onResolveToggle = onResolveToggle
        self.onClose = onClose
        self._editedText = State(initialValue: comment.text)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Status icon
                Image(systemName: comment.isResolved ? "checkmark.circle.fill" : "bubble.left.fill")
                    .foregroundColor(comment.isResolved ? .green : .blue)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(comment.author)
                        .font(.headline)
                    Text(comment.createdAt, format: .dateTime.day().month().year().hour().minute())
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
            
            // Comment content
            if isEditing {
                TextEditor(text: $editedText)
                    .frame(minHeight: 200, maxHeight: 400)
                    .padding(8)
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(8)
                    .scrollContentBackground(.hidden)
            } else {
                ScrollView {
                    Text(comment.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(minHeight: 100, maxHeight: 400)
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(8)
            }
            
            // Action buttons - using flexible layout to prevent truncation
            if isEditing {
                // Editing mode: Show Save and Cancel
                HStack(spacing: 12) {
                    Button(action: saveChanges) {
                        Label("commentDetail.save", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("commentDetail.save.accessibility")
                    
                    Button(action: {
                        editedText = comment.text
                        isEditing = false
                    }) {
                        Label("button.cancel", systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            } else {
                // View mode: Show all action buttons in a grid
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Button(action: { isEditing = true }) {
                            Label("commentDetail.edit", systemImage: "pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("commentDetail.edit.accessibility")
                        
                        Button(action: toggleResolve) {
                            Label(
                                comment.isResolved ? "commentDetail.reopen" : "commentDetail.resolve",
                                systemImage: comment.isResolved ? "arrow.uturn.backward" : "checkmark.circle"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(comment.isResolved ? .blue : .green)
                        .accessibilityLabel(comment.isResolved ? "commentDetail.reopen.accessibility" : "commentDetail.resolve.accessibility")
                    }
                    
                    Button(action: { showDeleteConfirmation = true }) {
                        Label("commentDetail.delete", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .accessibilityLabel("commentDetail.delete.accessibility")
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        .confirmationDialog(
            "commentDetail.confirmDelete.title",
            isPresented: $showDeleteConfirmation,
            presenting: comment
        ) { _ in
            Button("commentDetail.confirmDelete.button", role: .destructive) {
                deleteComment()
            }
            Button("button.cancel", role: .cancel) { }
        } message: { _ in
            Text("commentDetail.confirmDelete.message")
        }
    }
    
    // MARK: - Actions
    
    private func saveChanges() {
        guard editedText != comment.text else {
            isEditing = false
            return
        }
        
        CommentManager.shared.updateCommentText(comment, newText: editedText, context: modelContext)
        isEditing = false
        onUpdate?()
    }
    
    private func toggleResolve() {
        if comment.isResolved {
            CommentManager.shared.reopenComment(comment, context: modelContext)
        } else {
            CommentManager.shared.resolveComment(comment, context: modelContext)
        }
        onResolveToggle?()
    }
    
    private func deleteComment() {
        CommentManager.shared.deleteComment(comment, context: modelContext)
        onDelete?(comment)
    }
}
