//
//  FootnotesListView.swift
//  Writing Shed Pro
//
//  Feature 017: Footnotes - List view for all document footnotes
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
    
    let textFileID: UUID
    
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
        footnotes.filter { !$0.isDeleted }.sorted()
    }
    
    private var deletedFootnotes: [FootnoteModel] {
        footnotes.filter { $0.isDeleted }.sorted { ($0.deletedAt ?? Date()) > ($1.deletedAt ?? Date()) }
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
            .navigationTitle(showingTrash ? "Footnotes Trash" : "Footnotes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
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
            Label("No Footnotes", systemImage: "number.circle")
        } description: {
            Text("Add footnotes to your document to provide additional information or citations.")
        }
    }
    
    // MARK: - Footnotes List
    
    private var footnotesList: some View {
        List {
            if showingTrash {
                if deletedFootnotes.isEmpty {
                    ContentUnavailableView {
                        Label("Trash is Empty", systemImage: "trash")
                    } description: {
                        Text("Deleted footnotes will appear here.")
                    }
                } else {
                    Section {
                        ForEach(deletedFootnotes) { footnote in
                            footnoteRow(footnote)
                        }
                    } header: {
                        HStack {
                            Text("Deleted Footnotes")
                            Spacer()
                            Text("\(deletedFootnotes.count)")
                                .foregroundStyle(.secondary)
                        }
                    } footer: {
                        Text("Footnotes can be restored or permanently deleted from trash.")
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
                            Text("Document Order")
                            Spacer()
                            Text("\(activeFootnotes.count)")
                                .foregroundStyle(.secondary)
                        }
                    } footer: {
                        Text("Footnotes are numbered sequentially based on their position in the document.")
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
                    Button("Cancel") {
                        editingFootnote = nil
                        editText = ""
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Save") {
                        saveEdit(footnote)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.vertical, 8)
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
                            Text("• Deleted \(deletedAt, style: .relative)")
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
                    Text("Position: \(footnote.characterPosition)")
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
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showDeleteConfirmation = footnote
                        } label: {
                            Label("Delete Forever", systemImage: "trash.fill")
                        }
                    } else {
                        Button {
                            startEditing(footnote)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        Button {
                            onJumpToFootnote?(footnote)
                            dismiss()
                        } label: {
                            Label("Jump to Text", systemImage: "arrow.right")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showDeleteConfirmation = footnote
                        } label: {
                            Label("Move to Trash", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
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
                        Label("Delete Forever", systemImage: "trash.fill")
                    }
                } else {
                    Button(role: .destructive) {
                        moveToTrash(footnote)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    
                    Button {
                        startEditing(footnote)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if footnote.isDeleted {
                    Button {
                        restoreFootnote(footnote)
                    } label: {
                        Label("Restore", systemImage: "arrow.uturn.backward")
                    }
                    .tint(.green)
                } else {
                    Button {
                        onJumpToFootnote?(footnote)
                        dismiss()
                    } label: {
                        Label("Jump", systemImage: "arrow.right")
                    }
                    .tint(.green)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadFootnotes() {
        let fetchDescriptor = FetchDescriptor<FootnoteModel>(
            predicate: #Predicate { $0.textFileID == textFileID },
            sortBy: [SortDescriptor(\.characterPosition)]
        )
        
        do {
            footnotes = try modelContext.fetch(fetchDescriptor)
        } catch {
            print("❌ Error loading footnotes: \(error)")
        }
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

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FootnoteModel.self, configurations: config)
    
    let textFileID = UUID()
    
    // Add sample footnotes
    let footnote1 = FootnoteModel(
        textFileID: textFileID,
        characterPosition: 100,
        text: "This is the first footnote with additional information about the topic.",
        number: 1
    )
    
    let footnote2 = FootnoteModel(
        textFileID: textFileID,
        characterPosition: 250,
        text: "Second footnote providing a citation: Smith, J. (2024). Writing Guide.",
        number: 2
    )
    
    let footnote3 = FootnoteModel(
        textFileID: textFileID,
        characterPosition: 500,
        text: "Third footnote with more details about the methodology used in the research.",
        number: 3
    )
    
    container.mainContext.insert(footnote1)
    container.mainContext.insert(footnote2)
    container.mainContext.insert(footnote3)
    
    return FootnotesListView(textFileID: textFileID)
        .modelContainer(container)
}

#Preview("With Deleted") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FootnoteModel.self, configurations: config)
    
    let textFileID = UUID()
    
    let footnote1 = FootnoteModel(
        textFileID: textFileID,
        characterPosition: 100,
        text: "Active footnote 1",
        number: 1
    )
    
    let footnote2 = FootnoteModel(
        textFileID: textFileID,
        characterPosition: 250,
        text: "This footnote was deleted",
        number: 2,
        isDeleted: true,
        deletedAt: Date().addingTimeInterval(-3600)
    )
    
    container.mainContext.insert(footnote1)
    container.mainContext.insert(footnote2)
    
    return FootnotesListView(textFileID: textFileID)
        .modelContainer(container)
}
