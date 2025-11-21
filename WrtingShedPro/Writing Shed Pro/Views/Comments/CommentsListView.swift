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
    
    let textFileID: UUID
    
    /// Callback when user wants to jump to a comment in the text
    var onJumpToComment: ((CommentModel) -> Void)?
    
    /// Callback when list is dismissed
    var onDismiss: (() -> Void)?
    
    /// Callback when comment resolved state changes
    var onCommentResolvedChanged: ((CommentModel) -> Void)?
    
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
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onDismiss?()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadComments()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Comments", systemImage: "bubble.left")
        } description: {
            Text("Add comments to your document to provide feedback or notes.")
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
                        Text("Active")
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
                        Text("Resolved")
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
                    Button("Cancel") {
                        editingComment = nil
                        editText = ""
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Save") {
                        saveEdit(comment)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.vertical, 8)
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
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button {
                        onJumpToComment?(comment)
                        dismiss()
                    } label: {
                        Label("Jump to Text", systemImage: "arrow.right")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        showDeleteConfirmation = comment
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
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
                    deleteComment(comment)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                
                Button {
                    startEditing(comment)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.blue)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    toggleResolve(comment)
                } label: {
                    Label(
                        comment.isResolved ? "Reopen" : "Resolve",
                        systemImage: comment.isResolved ? "arrow.uturn.backward" : "checkmark"
                    )
                }
                .tint(comment.isResolved ? .orange : .green)
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadComments() {
        let fetchDescriptor = FetchDescriptor<CommentModel>(
            predicate: #Predicate { $0.textFileID == textFileID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            comments = try modelContext.fetch(fetchDescriptor)
        } catch {
            print("❌ Error loading comments: \(error)")
        }
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
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: CommentModel.self, configurations: config)
    
    let textFileID = UUID()
    
    // Add sample comments
    let comment1 = CommentModel(
        textFileID: textFileID,
        characterPosition: 100,
        text: "This is a great opening paragraph! Really draws the reader in.",
        author: "Jane Editor"
    )
    
    let comment2 = CommentModel(
        textFileID: textFileID,
        characterPosition: 250,
        text: "Consider revising this section for clarity. The metaphor might be confusing.",
        author: "John Reviewer"
    )
    comment2.resolve()
    
    let comment3 = CommentModel(
        textFileID: textFileID,
        characterPosition: 500,
        text: "Excellent dialogue here!",
        author: "Sarah Beta"
    )
    
    container.mainContext.insert(comment1)
    container.mainContext.insert(comment2)
    container.mainContext.insert(comment3)
    
    return CommentsListView(textFileID: textFileID)
        .modelContainer(container)
}
