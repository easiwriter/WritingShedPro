//
//  GlossaryListView.swift
//  Writing Shed Pro
//
//  Feature 029: Back Matter Reference System
//  Created by GitHub Copilot on 15/01/2026.
//
//  List view for managing glossary terms at project level
//

import SwiftUI
import SwiftData

/// Sort options for glossary list
enum GlossarySortOrder: String, CaseIterable {
    case alphabetical = "Alphabetical"
    case dateCreated = "Date Created"
    case dateModified = "Date Modified"
    case referenceCount = "Most Used"
    
    var localizedTitle: String {
        switch self {
        case .alphabetical:
            return NSLocalizedString("glossaryList.sort.alphabetical", comment: "Alphabetical")
        case .dateCreated:
            return NSLocalizedString("glossaryList.sort.dateCreated", comment: "Date Created")
        case .dateModified:
            return NSLocalizedString("glossaryList.sort.dateModified", comment: "Date Modified")
        case .referenceCount:
            return NSLocalizedString("glossaryList.sort.referenceCount", comment: "Most Used")
        }
    }
}

/// List view showing all glossary terms for a project
struct GlossaryListView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    
    /// Callback when user wants to jump to a term marker in the text
    var onJumpToTerm: ((GlossaryEntry) -> Void)?
    
    /// Callback when list is dismissed
    var onDismiss: (() -> Void)?
    
    /// Callback when term is updated/deleted
    var onTermChanged: (() -> Void)?
    
    /// Callback when term is deleted (needs marker removal from text)
    var onTermDeleted: ((GlossaryEntry) -> Void)?
    
    // MARK: - State
    
    @State private var terms: [GlossaryEntry] = []
    @State private var sortOrder: GlossarySortOrder = .alphabetical
    @State private var searchText: String = ""
    @State private var editingTerm: GlossaryEntry?
    @State private var showDeleteConfirmation: GlossaryEntry?
    @State private var showAddTermSheet = false
    @State private var expandedTermID: UUID?
    
    // MARK: - Computed Properties
    
    private var filteredTerms: [GlossaryEntry] {
        var result = terms
        
        // Apply search
        if !searchText.isEmpty {
            let lowercasedSearch = searchText.lowercased()
            result = result.filter { term in
                term.term.lowercased().contains(lowercasedSearch) ||
                term.definition.lowercased().contains(lowercasedSearch)
            }
        }
        
        // Apply sort
        switch sortOrder {
        case .alphabetical:
            result.sort { $0.term.lowercased() < $1.term.lowercased() }
        case .dateCreated:
            result.sort { $0.createdAt > $1.createdAt }
        case .dateModified:
            result.sort { $0.modifiedAt > $1.modifiedAt }
        case .referenceCount:
            result.sort { $0.referenceCount > $1.referenceCount }
        }
        
        return result
    }
    
    private var orphanedTerms: [GlossaryEntry] {
        terms.filter { $0.referenceCount == 0 }
    }
    
    /// Group terms by first letter for alphabetical display
    private var groupedTerms: [(letter: String, terms: [GlossaryEntry])] {
        guard sortOrder == .alphabetical else {
            return [("", filteredTerms)]
        }
        
        let grouped = Dictionary(grouping: filteredTerms) { term -> String in
            let firstChar = term.term.first?.uppercased() ?? "#"
            return firstChar.first?.isLetter == true ? firstChar : "#"
        }
        
        return grouped.sorted { $0.key < $1.key }.map { (letter: $0.key, terms: $0.value) }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Group {
                if terms.isEmpty {
                    emptyState
                } else {
                    termsList
                }
            }
            .navigationTitle(NSLocalizedString("glossaryList.title", comment: "Glossary"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: NSLocalizedString("glossaryList.search.prompt", comment: "Search terms"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.done", comment: "Done")) {
                        onDismiss?()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddTermSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Picker(selection: $sortOrder) {
                            ForEach(GlossarySortOrder.allCases, id: \.self) { order in
                                Text(order.localizedTitle)
                                    .tag(order)
                            }
                        } label: {
                            Text(NSLocalizedString("glossaryList.sort", comment: "Sort"))
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                }
            }
        }
        .onAppear {
            loadTerms()
        }
        .onChange(of: terms) { oldValue, newValue in
            if newValue.isEmpty && !oldValue.isEmpty {
                onDismiss?()
                dismiss()
            }
        }
        .sheet(isPresented: $showAddTermSheet) {
            GlossaryEditorSheet(
                project: project,
                onSave: { _ in
                    loadTerms()
                    onTermChanged?()
                }
            )
        }
        .sheet(item: $editingTerm) { term in
            GlossaryEditorSheet(
                project: project,
                existingTerm: term,
                onSave: { _ in
                    loadTerms()
                    onTermChanged?()
                }
            )
        }
        .confirmationDialog(
            NSLocalizedString("glossaryList.confirmDelete.title", comment: "Delete Term?"),
            isPresented: .constant(showDeleteConfirmation != nil),
            titleVisibility: .visible,
            presenting: showDeleteConfirmation
        ) { term in
            Button(NSLocalizedString("glossaryList.confirmDelete.button", comment: "Delete"), role: .destructive) {
                deleteTerm(term)
                showDeleteConfirmation = nil
            }
            
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                showDeleteConfirmation = nil
            }
        } message: { term in
            if term.referenceCount > 0 {
                Text(String(format: NSLocalizedString("glossaryList.confirmDelete.messageWithRefs", comment: ""), term.referenceCount))
            } else {
                Text(NSLocalizedString("glossaryList.confirmDelete.message", comment: "This term will be permanently deleted."))
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                NSLocalizedString("glossaryList.empty.title", comment: "No Glossary Terms"),
                systemImage: "text.book.closed"
            )
        } description: {
            Text(NSLocalizedString("glossaryList.empty.description", comment: "Add terms to build your project glossary."))
        } actions: {
            Button {
                showAddTermSheet = true
            } label: {
                Label(
                    NSLocalizedString("glossaryList.addTerm", comment: "Add Term"),
                    systemImage: "plus.circle.fill"
                )
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Terms List
    
    private var termsList: some View {
        List {
            // Summary section
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text(NSLocalizedString("glossaryList.summary.total", comment: "Total Terms"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(terms.count)")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(NSLocalizedString("glossaryList.summary.unreferenced", comment: "Unreferenced"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(orphanedTerms.count)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(orphanedTerms.isEmpty ? .primary : .orange)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Terms grouped by letter (for alphabetical) or flat list
            ForEach(groupedTerms, id: \.letter) { group in
                Section {
                    ForEach(group.terms) { term in
                        termRow(term)
                    }
                } header: {
                    if sortOrder == .alphabetical && !group.letter.isEmpty {
                        Text(group.letter)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Term Row
    
    @ViewBuilder
    private func termRow(_ term: GlossaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Term badge
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.teal.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Text(String(term.term.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.teal)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Term name
                    Text(term.term)
                        .font(.headline)
                    
                    // Definition (truncated or expanded)
                    Text(term.definition)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(expandedTermID == term.id ? nil : 2)
                    
                    // Metadata
                    HStack(spacing: 8) {
                        // Reference count
                        let refCountStyle: Color = term.referenceCount == 0 ? .orange : .secondary
                        Label("\(term.referenceCount)", systemImage: "link")
                            .font(.caption2)
                            .foregroundStyle(refCountStyle)
                        
                        // Modified date
                        Text(term.modifiedAt, style: .date)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Spacer()
                
                // Actions menu
                Menu {
                    Button {
                        editingTerm = term
                    } label: {
                        Label(
                            NSLocalizedString("glossaryList.edit", comment: "Edit"),
                            systemImage: "pencil.circle"
                        )
                    }
                    
                    Button {
                        withAnimation {
                            expandedTermID = expandedTermID == term.id ? nil : term.id
                        }
                    } label: {
                        Label(
                            expandedTermID == term.id
                                ? NSLocalizedString("glossaryList.collapse", comment: "Collapse")
                                : NSLocalizedString("glossaryList.expand", comment: "Expand"),
                            systemImage: expandedTermID == term.id ? "chevron.up" : "chevron.down"
                        )
                    }
                    
                    if term.referenceCount > 0 {
                        Button {
                            onJumpToTerm?(term)
                            dismiss()
                        } label: {
                            Label(
                                NSLocalizedString("glossaryList.jumpToText", comment: "Jump to Reference"),
                                systemImage: "arrow.right"
                            )
                        }
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        showDeleteConfirmation = term
                    } label: {
                        Label(
                            NSLocalizedString("glossaryList.delete", comment: "Delete"),
                            systemImage: "trash"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                expandedTermID = expandedTermID == term.id ? nil : term.id
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                showDeleteConfirmation = term
            } label: {
                Label(
                    NSLocalizedString("glossaryList.delete", comment: "Delete"),
                    systemImage: "trash"
                )
            }
            
            Button {
                editingTerm = term
            } label: {
                Label(
                    NSLocalizedString("glossaryList.edit", comment: "Edit"),
                    systemImage: "pencil.circle"
                )
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if term.referenceCount > 0 {
                Button {
                    onJumpToTerm?(term)
                    dismiss()
                } label: {
                    Label(
                        NSLocalizedString("glossaryList.jump", comment: "Jump"),
                        systemImage: "arrow.right"
                    )
                }
                .tint(.green)
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadTerms() {
        terms = project.glossaryEntries ?? []
        
        #if DEBUG
        print("📖 Loaded \(terms.count) glossary terms for project")
        #endif
    }
    
    private func deleteTerm(_ term: GlossaryEntry) {
        // Remove from project
        let termID: UUID = term.id
        project.glossaryEntries?.removeAll { (entry: GlossaryEntry) -> Bool in entry.id == termID }
        
        // Delete from context
        modelContext.delete(term)
        
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("❌ Error deleting glossary term: \(error)")
            #endif
        }
        
        loadTerms()
        onTermChanged?()
        onTermDeleted?(term)
        
        #if DEBUG
        print("🗑️ Deleted glossary term: \(term.term)")
        #endif
    }
}

// MARK: - Localization Keys

/*
 Add these to Localizable.strings:
 
 "glossaryList.title" = "Glossary";
 "glossaryList.search.prompt" = "Search terms";
 "glossaryList.sort" = "Sort";
 "glossaryList.sort.alphabetical" = "Alphabetical";
 "glossaryList.sort.dateCreated" = "Date Created";
 "glossaryList.sort.dateModified" = "Date Modified";
 "glossaryList.sort.referenceCount" = "Most Used";
 "glossaryList.addTerm" = "Add Term";
 "glossaryList.empty.title" = "No Glossary Terms";
 "glossaryList.empty.description" = "Add terms to build your project glossary.";
 "glossaryList.summary.total" = "Total Terms";
 "glossaryList.summary.unreferenced" = "Unreferenced";
 "glossaryList.edit" = "Edit";
 "glossaryList.expand" = "Expand";
 "glossaryList.collapse" = "Collapse";
 "glossaryList.jumpToText" = "Jump to Reference";
 "glossaryList.jump" = "Jump";
 "glossaryList.delete" = "Delete";
 "glossaryList.confirmDelete.title" = "Delete Term?";
 "glossaryList.confirmDelete.button" = "Delete";
 "glossaryList.confirmDelete.message" = "This term will be permanently deleted. This cannot be undone.";
 "glossaryList.confirmDelete.messageWithRefs" = "This term is referenced %d times. The markers will remain but show as missing. This cannot be undone.";
 */
