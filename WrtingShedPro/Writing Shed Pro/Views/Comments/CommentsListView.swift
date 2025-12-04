//
//  CommentsListView.swift
//  Writing Shed Pro
//
//  Feature 014: Comments - List view for all document comments
//

import SwiftUI
import SwiftData

/// List view showing all comments for a document
struct CommentsListView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let version: Version
    
    /// Callback when user wants to jump to a comment in the text
    var onJumpToComment: ((CommentModel) -> Void)?
    
    /// Callback when list is dismissed
    var onDismiss: (() -> Void)?
    
    /// Callback when comment resolved state changes
    var onCommentResolvedChanged: ((CommentModel) -> Void)?
    
    /// Callback when comment is deleted
    var onCommentDeleted: ((CommentModel) -> Void)?
    
    // MARK: - State
    
    @State private var comments: [CommentModel] = []
    @State private var selectedComment: CommentModel?
    @State private var editingComment: CommentModel?
    @State private var editText: String = ""
    @State private var showDeleteConfirmation: CommentModel?
    
    // MARK: - Computed
    
    private var sortedComments: [CommentModel] {
        comments.sorted { $0.createdAt > $1.createdAt }
    }
    
    private var activeComments: [CommentModel] {
        sortedComments.filter { !$0.isResolved }
    }
    
    private var resolvedComments: [CommentModel] {
        sortedComments.filter { $0.isResolved }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Group {
                if comments.isEmpty {
                    emptyState
                } else {
                    commentsList
                }
            }
            .navigationTitle("commentsList.title")
            .navigationBarTitleDisplayMode(.inline)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("button.done") {
                    onDismiss?()
                    dismiss()
                }
            }
        }
        .onAppear {
            loadComments()
        }
        .onChange(of: comments) { oldValue, newValue in
            // Auto-dismiss when all comments are deleted
            if newValue.isEmpty && !oldValue.isEmpty {
                onDismiss?()
                dismiss()
            }
        }
        .confirmationDialog(
            "commentsList.confirmDelete.title",
            isPresented: .constant(showDeleteConfirmation != nil),
            titleVisibility: .visible,
            presenting: showDeleteConfirmation
        ) { comment in
            Button("commentsList.confirmDelete.button", role: .destructive) {
                deleteComment(comment)
                showDeleteConfirmation = nil
            }

            Button("button.cancel", role: .cancel) {
                showDeleteConfirmation = nil
            }
        } message: { comment in
            Text("commentsList.confirmDelete.message")
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("commentsList.empty.title", systemImage: "bubble.left")
        } description: {
            Text("commentsList.empty.description")
        }
    }
    
    // MARK: - Comments List
    
    private var commentsList: some View {
        List {
            if !activeComments.isEmpty {
                Section {
                    ForEach(activeComments) { comment in
                        commentRow(comment)
                    }
                } header: {
                    HStack {
                        Text("commentsList.active")
                        Spacer()
                        Text("\(activeComments.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            if !resolvedComments.isEmpty {
                Section {
                    ForEach(resolvedComments) { comment in
                        commentRow(comment)
                    }
                } header: {
                    HStack {
                        Text("commentsList.resolved")
                        Spacer()
                        Text("\(resolvedComments.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Comment Row
    
    @ViewBuilder
    private func commentRow(_ comment: CommentModel) -> some View {
        if editingComment?.id == comment.id {
            // Editing mode
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(comment.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(comment.createdAt, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                
                TextEditor(text: $editText)
                    .frame(minHeight: 100, maxHeight: 200)
                    .padding(8)
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(8)
                    .scrollContentBackground(.hidden)
                
                HStack {
                    Button("button.cancel") {
                        editingComment = nil
                        editText = ""
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("button.save") {
                        saveEdit(comment)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("commentsList.editingComment.accessibility")
        } else {
            // View mode
            HStack(alignment: .top, spacing: 12) {
                // Resolve checkbox
                Button {
                    toggleResolve(comment)
                } label: {
                    Image(systemName: comment.isResolved ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(comment.isResolved ? .green : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(comment.isResolved ? "commentsList.reopen.accessibility" : "commentsList.resolve.accessibility")
                
                VStack(alignment: .leading, spacing: 4) {
                    // Date and time
                    HStack(spacing: 8) {
                        Text(comment.createdAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(comment.createdAt, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if comment.isResolved {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                    }
                    
                    // Comment text (truncated)
                    Text(comment.text)
                        .font(.body)
                        .lineLimit(2)
                        .foregroundStyle(comment.isResolved ? .secondary : .primary)
                    
                    // Author
                    Text(comment.author)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                // Actions menu
                Menu {
                    Button {
                        startEditing(comment)
                    } label: {
                        Label("commentsList.edit", systemImage: "square.and.pencil")
                    }
                    
                    Button {
                        onJumpToComment?(comment)
                        dismiss()
                    } label: {
                        Label("commentsList.jumpToText", systemImage: "arrow.right")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        showDeleteConfirmation = comment
                    } label: {
                        Label("commentsList.delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .accessibilityLabel("commentsList.actions.accessibility")
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                startEditing(comment)
            }
            .onTapGesture(count: 1) {
                selectedComment = comment
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    showDeleteConfirmation = comment
                } label: {
                    Label("commentsList.delete", systemImage: "trash")
                }
                
                Button {
                    startEditing(comment)
                } label: {
                    Label("commentsList.edit", systemImage: "square.and.pencil")
                }
                .tint(.blue)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    toggleResolve(comment)
                } label: {
                    Label(
                        comment.isResolved ? "commentsList.reopen" : "commentsList.resolve",
                        systemImage: comment.isResolved ? "arrow.uturn.backward" : "checkmark"
                    )
                }
                .tint(comment.isResolved ? .orange : .green)
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadComments() {
        // Access comments directly from version relationship
        comments = (version.comments ?? [])
            .filter { !$0.isDeleted }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    private func startEditing(_ comment: CommentModel) {
        editingComment = comment
        editText = comment.text
    }
    
    private func saveEdit(_ comment: CommentModel) {
        guard !editText.isEmpty else {
            editingComment = nil
            editText = ""
            return
        }
        
        CommentManager.shared.updateCommentText(comment, newText: editText, context: modelContext)
        editingComment = nil
        editText = ""
        loadComments()
    }
    
    private func toggleResolve(_ comment: CommentModel) {
        if comment.isResolved {
            CommentManager.shared.reopenComment(comment, context: modelContext)
        } else {
            CommentManager.shared.resolveComment(comment, context: modelContext)
        }
        loadComments()
        
        // Notify FileEditView to update visual marker
        onCommentResolvedChanged?(comment)
    }
    
    private func deleteComment(_ comment: CommentModel) {
        CommentManager.shared.deleteComment(comment, context: modelContext)
        loadComments()
        onCommentDeleted?(comment)
    }
}
