//
//  FootnotesListView.swift
//  Writing Shed Pro
//
//  Feature 015: Footnotes - List view for all document footnotes
//  Created by GitHub Copilot on 21/11/2025.
//

import SwiftUI
import SwiftData

/// List view showing all footnotes for a document
struct FootnotesListView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let version: Version
    
    /// Callback when user wants to jump to a footnote in the text
    var onJumpToFootnote: ((FootnoteModel) -> Void)?
    
    /// Callback when list is dismissed
    var onDismiss: (() -> Void)?
    
    /// Callback when footnote is updated/deleted
    var onFootnoteChanged: (() -> Void)?
    
    /// Callback when footnote is deleted (needs marker removal)
    var onFootnoteDeleted: ((FootnoteModel) -> Void)?
    
    // MARK: - State
    
    @State private var footnotes: [FootnoteModel] = []
    @State private var selectedFootnote: FootnoteModel?
    @State private var editingFootnote: FootnoteModel?
    @State private var editText: String = ""
    @State private var showDeleteConfirmation: FootnoteModel?
    
    // MARK: - Body

    var body: some View {
        NavigationView {
            Group {
                if footnotes.isEmpty {
                    emptyState
                } else {
                    footnotesList
                }
            }
            .navigationTitle("footnotesList.title")
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
            loadFootnotes()
        }
        .onChange(of: footnotes) { oldValue, newValue in
            // Auto-dismiss when all footnotes are deleted
            if newValue.isEmpty && !oldValue.isEmpty {
                onDismiss?()
                dismiss()
            }
        }
        .confirmationDialog(
            "footnotesList.confirmDelete.title",
            isPresented: .constant(showDeleteConfirmation != nil),
            titleVisibility: .visible,
            presenting: showDeleteConfirmation
        ) { footnote in
            Button("footnotesList.confirmDelete.button", role: .destructive) {
                deleteFootnote(footnote)
                showDeleteConfirmation = nil
            }

            Button("button.cancel", role: .cancel) {
                showDeleteConfirmation = nil
            }
        } message: { footnote in
            Text("footnotesList.confirmDelete.message")
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("footnotesList.empty.title", systemImage: "number.circle")
        } description: {
            Text("footnotesList.empty.description")
        }
    }
    
    // MARK: - Footnotes List

    private var footnotesList: some View {
        List {
            if !footnotes.isEmpty {
                Section {
                    ForEach(footnotes) { footnote in
                        footnoteRow(footnote)
                    }
                } header: {
                    HStack {
                        Text("footnotesList.documentOrder")
                        Spacer()
                        Text("\(footnotes.count)")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("footnotesList.documentOrderFooter")
                        .font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Footnote Row
    
    @ViewBuilder
    private func footnoteRow(_ footnote: FootnoteModel) -> some View {
        if editingFootnote?.id == footnote.id {
            // Editing mode
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 28, height: 28)
                        Text("\(footnote.number)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                    
                    Text(footnote.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(footnote.createdAt, style: .time)
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
                        editingFootnote = nil
                        editText = ""
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("button.save") {
                        saveEdit(footnote)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("footnotesList.editingFootnote.accessibility")
        } else {
            // View mode
            HStack(alignment: .top, spacing: 12) {
                // Footnote number badge
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Text("\(footnote.number)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    // Date and time
                    HStack(spacing: 8) {
                        Text(footnote.createdAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(footnote.createdAt, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Footnote text (truncated)
                    Text(footnote.text)
                        .font(.body)
                        .lineLimit(2)
                        .foregroundStyle(.primary)

                    // Position info
                    Text(String(format: NSLocalizedString("footnotesList.position", comment: ""), footnote.characterPosition))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Actions menu
                Menu {
                    Button {
                        startEditing(footnote)
                    } label: {
                        Label("footnotesList.edit", systemImage: "pencil")
                    }

                    Button {
                        onJumpToFootnote?(footnote)
                        dismiss()
                    } label: {
                        Label("footnotesList.jumpToText", systemImage: "arrow.right")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteConfirmation = footnote
                    } label: {
                        Label("footnotesList.delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .accessibilityLabel("footnotesList.actions.accessibility")
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                startEditing(footnote)
            }
            .onTapGesture(count: 1) {
                selectedFootnote = footnote
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    showDeleteConfirmation = footnote
                } label: {
                    Label("footnotesList.delete", systemImage: "trash")
                }

                Button {
                    startEditing(footnote)
                } label: {
                    Label("footnotesList.edit", systemImage: "pencil")
                }
                .tint(.blue)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    onJumpToFootnote?(footnote)
                    dismiss()
                } label: {
                    Label("footnotesList.jump", systemImage: "arrow.right")
                }
                .tint(.green)
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadFootnotes() {
        // Use the relationship directly - much more efficient!
        footnotes = version.footnotes ?? []
    }
    
    private func startEditing(_ footnote: FootnoteModel) {
        editingFootnote = footnote
        editText = footnote.text
    }
    
    private func saveEdit(_ footnote: FootnoteModel) {
        guard !editText.isEmpty else {
            editingFootnote = nil
            editText = ""
            return
        }
        
        FootnoteManager.shared.updateFootnoteText(footnote, newText: editText, context: modelContext)
        editingFootnote = nil
        editText = ""
        loadFootnotes()
        onFootnoteChanged?()
    }
    
    private func deleteFootnote(_ footnote: FootnoteModel) {
        FootnoteManager.shared.deleteFootnote(footnote, context: modelContext)
        loadFootnotes()
        onFootnoteChanged?()
        onFootnoteDeleted?(footnote) // Notify parent to remove marker from text
    }
}
