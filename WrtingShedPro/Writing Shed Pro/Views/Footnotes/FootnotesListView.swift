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
    
    // MARK: - State
    
    @State private var footnotes: [FootnoteModel] = []
    @State private var selectedFootnote: FootnoteModel?
    @State private var editingFootnote: FootnoteModel?
    @State private var editText: String = ""
    @State private var showDeleteConfirmation: FootnoteModel?
    @State private var showingTrash: Bool = false
    
    // MARK: - Computed
    
    private var activeFootnotes: [FootnoteModel] {
        footnotes.filter { $0.isDeleted == false }.sorted()
    }
    
    private var deletedFootnotes: [FootnoteModel] {
        footnotes.filter { $0.isDeleted == true }.sorted { ($0.deletedAt ?? Date()) > ($1.deletedAt ?? Date()) }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Group {
                if activeFootnotes.isEmpty && !showingTrash {
                    emptyState
                } else {
                    footnotesList
                }
            }
            .navigationTitle(showingTrash ? "footnotesList.trash.title" : "footnotesList.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.done") {
                        onDismiss?()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingTrash.toggle()
                        loadFootnotes()
                    } label: {
                        Image(systemName: showingTrash ? "doc.text" : "trash")
                    }
                    .accessibilityLabel(showingTrash ? "footnotesList.showActive.accessibility" : "footnotesList.showTrash.accessibility")
                }
            }
        }
        .onAppear {
            loadFootnotes()
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
            if showingTrash {
                if deletedFootnotes.isEmpty {
                    ContentUnavailableView {
                        Label("footnotesList.trashEmpty.title", systemImage: "trash")
                    } description: {
                        Text("footnotesList.trashEmpty.description")
                    }
                } else {
                    Section {
                        ForEach(deletedFootnotes) { footnote in
                            footnoteRow(footnote)
                        }
                    } header: {
                        HStack {
                            Text("footnotesList.deletedFootnotes")
                            Spacer()
                            Text("\(deletedFootnotes.count)")
                                .foregroundStyle(.secondary)
                        }
                    } footer: {
                        Text("footnotesList.trashFooter")
                            .font(.caption)
                    }
                }
            } else {
                if !activeFootnotes.isEmpty {
                    Section {
                        ForEach(activeFootnotes) { footnote in
                            footnoteRow(footnote)
                        }
                    } header: {
                        HStack {
                            Text("footnotesList.documentOrder")
                            Spacer()
                            Text("\(activeFootnotes.count)")
                                .foregroundStyle(.secondary)
                        }
                    } footer: {
                        Text("footnotesList.documentOrderFooter")
                            .font(.caption)
                    }
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
                        .fill(footnote.isDeleted ? Color.gray.opacity(0.1) : Color.blue.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Text("\(footnote.number)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(footnote.isDeleted ? .gray : .blue)
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
                        
                        if footnote.isDeleted, let deletedAt = footnote.deletedAt {
                            Text("• \(Text("footnotesList.deleted")) \(deletedAt, style: .relative)")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                    
                    // Footnote text (truncated)
                    Text(footnote.text)
                        .font(.body)
                        .lineLimit(2)
                        .foregroundStyle(footnote.isDeleted ? .secondary : .primary)
                    
                    // Position info
                    Text(String(format: NSLocalizedString("footnotesList.position", comment: ""), footnote.characterPosition))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                // Actions menu
                Menu {
                    if footnote.isDeleted {
                        Button {
                            restoreFootnote(footnote)
                        } label: {
                            Label("footnotesList.restore", systemImage: "arrow.uturn.backward")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showDeleteConfirmation = footnote
                        } label: {
                            Label("footnotesList.deleteForever", systemImage: "trash.fill")
                        }
                    } else {
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
                            Label("footnotesList.moveToTrash", systemImage: "trash")
                        }
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
                if !footnote.isDeleted {
                    startEditing(footnote)
                }
            }
            .onTapGesture(count: 1) {
                selectedFootnote = footnote
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if footnote.isDeleted {
                    Button(role: .destructive) {
                        permanentlyDeleteFootnote(footnote)
                    } label: {
                        Label("footnotesList.deleteForever", systemImage: "trash.fill")
                    }
                } else {
                    Button(role: .destructive) {
                        moveToTrash(footnote)
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
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if footnote.isDeleted {
                    Button {
                        restoreFootnote(footnote)
                    } label: {
                        Label("footnotesList.restore", systemImage: "arrow.uturn.backward")
                    }
                    .tint(.green)
                } else {
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
    
    private func moveToTrash(_ footnote: FootnoteModel) {
        FootnoteManager.shared.moveFootnoteToTrash(footnote, context: modelContext)
        loadFootnotes()
        onFootnoteChanged?()
    }
    
    private func restoreFootnote(_ footnote: FootnoteModel) {
        FootnoteManager.shared.restoreFootnote(footnote, context: modelContext)
        loadFootnotes()
        onFootnoteChanged?()
    }
    
    private func permanentlyDeleteFootnote(_ footnote: FootnoteModel) {
        FootnoteManager.shared.permanentlyDeleteFootnote(footnote, context: modelContext)
        loadFootnotes()
        onFootnoteChanged?()
    }
}
