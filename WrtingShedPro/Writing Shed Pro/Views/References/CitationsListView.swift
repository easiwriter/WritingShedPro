//
//  CitationsListView.swift
//  Writing Shed Pro
//
//  Feature 029: Back Matter Reference System
//  Created by GitHub Copilot on 15/01/2026.
//
//  List view for managing citations/bibliography at project level
//

import SwiftUI
import SwiftData

/// Sort options for citations list
enum CitationsSortOrder: String, CaseIterable {
    case author = "Author"
    case year = "Year"
    case dateCreated = "Date Added"
    case dateModified = "Date Modified"
    case referenceCount = "Most Cited"
    
    var localizedTitle: String {
        switch self {
        case .author:
            return NSLocalizedString("citationsList.sort.author", comment: "Author")
        case .year:
            return NSLocalizedString("citationsList.sort.year", comment: "Year")
        case .dateCreated:
            return NSLocalizedString("citationsList.sort.dateCreated", comment: "Date Added")
        case .dateModified:
            return NSLocalizedString("citationsList.sort.dateModified", comment: "Date Modified")
        case .referenceCount:
            return NSLocalizedString("citationsList.sort.referenceCount", comment: "Most Cited")
        }
    }
}

/// List view showing all citations for a project
struct CitationsListView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    
    /// Callback when user wants to jump to a citation marker in the text
    var onJumpToCitation: ((CitationEntry) -> Void)?
    
    /// Callback when list is dismissed
    var onDismiss: (() -> Void)?
    
    /// Callback when citation is updated/deleted
    var onCitationChanged: (() -> Void)?
    
    /// Callback when citation is deleted (needs marker removal from text)
    var onCitationDeleted: ((CitationEntry) -> Void)?
    
    // MARK: - State
    
    @State private var citations: [CitationEntry] = []
    @State private var sortOrder: CitationsSortOrder = .author
    @State private var searchText: String = ""
    @State private var editingCitation: CitationEntry?
    @State private var showDeleteConfirmation: CitationEntry?
    @State private var showAddCitationSheet = false
    @State private var expandedCitationID: UUID?
    
    // MARK: - Computed Properties
    
    private var filteredCitations: [CitationEntry] {
        var result = citations
        
        // Apply search
        if !searchText.isEmpty {
            let lowercasedSearch = searchText.lowercased()
            result = result.filter { citation in
                citation.authors.joined(separator: " ").lowercased().contains(lowercasedSearch) ||
                citation.title.lowercased().contains(lowercasedSearch) ||
                (citation.year.map { String($0) }?.contains(lowercasedSearch) ?? false) ||
                (citation.source?.lowercased().contains(lowercasedSearch) ?? false)
            }
        }
        
        // Apply sort
        switch sortOrder {
        case .author:
            result.sort { ($0.authors.first ?? "").lowercased() < ($1.authors.first ?? "").lowercased() }
        case .year:
            result.sort { ($0.year ?? 0) > ($1.year ?? 0) }  // Most recent first
        case .dateCreated:
            result.sort { $0.createdAt > $1.createdAt }
        case .dateModified:
            result.sort { $0.modifiedAt > $1.modifiedAt }
        case .referenceCount:
            result.sort { $0.referenceCount > $1.referenceCount }
        }
        
        return result
    }
    
    private var orphanedCitations: [CitationEntry] {
        citations.filter { $0.referenceCount == 0 }
    }
    
    /// Group citations by author for alphabetical display
    private var groupedCitations: [(letter: String, citations: [CitationEntry])] {
        guard sortOrder == .author else {
            return [("", filteredCitations)]
        }
        
        let grouped = Dictionary(grouping: filteredCitations) { citation -> String in
            let firstChar = (citation.authors.first ?? "#").first?.uppercased() ?? "#"
            return firstChar.first?.isLetter == true ? firstChar : "#"
        }
        
        return grouped.sorted { $0.key < $1.key }.map { (letter: $0.key, citations: $0.value) }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Group {
                if citations.isEmpty {
                    emptyState
                } else {
                    citationsList
                }
            }
            .navigationTitle(NSLocalizedString("citationsList.title", comment: "Citations"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: NSLocalizedString("citationsList.search.prompt", comment: "Search citations"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.done", comment: "Done")) {
                        onDismiss?()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddCitationSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Picker(selection: $sortOrder) {
                            ForEach(CitationsSortOrder.allCases, id: \.self) { order in
                                Text(order.localizedTitle)
                                    .tag(order)
                            }
                        } label: {
                            Text(NSLocalizedString("citationsList.sort", comment: "Sort"))
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                }
            }
        }
        .onAppear {
            loadCitations()
        }
        .onChange(of: citations) { oldValue, newValue in
            if newValue.isEmpty && !oldValue.isEmpty {
                onDismiss?()
                dismiss()
            }
        }
        .sheet(isPresented: $showAddCitationSheet) {
            CitationEditorSheet(
                project: project,
                onSave: { _ in
                    loadCitations()
                    onCitationChanged?()
                }
            )
        }
        .sheet(item: $editingCitation) { citation in
            CitationEditorSheet(
                project: project,
                existingCitation: citation,
                onSave: { _ in
                    loadCitations()
                    onCitationChanged?()
                }
            )
        }
        .confirmationDialog(
            NSLocalizedString("citationsList.confirmDelete.title", comment: "Delete Citation?"),
            isPresented: .constant(showDeleteConfirmation != nil),
            titleVisibility: .visible,
            presenting: showDeleteConfirmation
        ) { citation in
            Button(NSLocalizedString("citationsList.confirmDelete.button", comment: "Delete"), role: .destructive) {
                deleteCitation(citation)
                showDeleteConfirmation = nil
            }
            
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                showDeleteConfirmation = nil
            }
        } message: { citation in
            if citation.referenceCount > 0 {
                Text(String(format: NSLocalizedString("citationsList.confirmDelete.messageWithRefs", comment: ""), citation.referenceCount))
            } else {
                Text(NSLocalizedString("citationsList.confirmDelete.message", comment: "This citation will be permanently deleted."))
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                NSLocalizedString("citationsList.empty.title", comment: "No Citations"),
                systemImage: "books.vertical"
            )
        } description: {
            Text(NSLocalizedString("citationsList.empty.description", comment: "Add citations to build your bibliography."))
        } actions: {
            Button {
                showAddCitationSheet = true
            } label: {
                Label(
                    NSLocalizedString("citationsList.addCitation", comment: "Add Citation"),
                    systemImage: "plus.circle.fill"
                )
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Citations List
    
    private var citationsList: some View {
        List {
            // Summary section
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text(NSLocalizedString("citationsList.summary.total", comment: "Total Citations"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(citations.count)")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(NSLocalizedString("citationsList.summary.uncited", comment: "Uncited"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(orphanedCitations.count)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(orphanedCitations.isEmpty ? .primary : .orange)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Citations grouped or flat
            ForEach(groupedCitations, id: \.letter) { group in
                Section {
                    ForEach(group.citations) { citation in
                        citationRow(citation)
                    }
                } header: {
                    if sortOrder == .author && !group.letter.isEmpty {
                        Text(group.letter)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Citation Row
    
    @ViewBuilder
    private func citationRow(_ citation: CitationEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Citation badge
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.indigo.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    VStack(spacing: 0) {
                        Image(systemName: "quote.opening")
                            .font(.system(size: 12))
                        Text(citation.year.map { String($0).suffix(2) }.map(String.init) ?? "--")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.indigo)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Author and year
                    HStack {
                        Text(citation.authors.first ?? NSLocalizedString("citation.unknownAuthor", comment: "Unknown Author"))
                            .font(.headline)
                        
                        Text("(\(citation.year.map { String($0) } ?? "n.d."))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Title (truncated or expanded)
                    Text(citation.title)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(expandedCitationID == citation.id ? nil : 2)
                        .italic()
                    
                    // Source if present
                    if let source = citation.source, !source.isEmpty {
                        Text(source)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Metadata
                    HStack(spacing: 8) {
                        // Reference count
                        Label("\(citation.referenceCount)", systemImage: "link")
                            .font(.caption2)
                            .foregroundStyle(citation.referenceCount == 0 ? .orange : .secondary)
                        
                        // Inline marker preview (e.g., "(Smith, 2024)")
                        let authorName = citation.authors.first?.components(separatedBy: " ").last ?? "Author"
                        let yearText = citation.year.map { String($0) } ?? "n.d."
                        Text("(\(authorName), \(yearText))")
                            .font(.caption2)
                            .foregroundColor(.indigo)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.indigo.opacity(0.1))
                            .cornerRadius(2)
                    }
                }
                
                Spacer()
                
                // Actions menu
                Menu {
                    Button {
                        editingCitation = citation
                    } label: {
                        Label(
                            NSLocalizedString("citationsList.edit", comment: "Edit"),
                            systemImage: "pencil.circle"
                        )
                    }
                    
                    Button {
                        withAnimation {
                            expandedCitationID = expandedCitationID == citation.id ? nil : citation.id
                        }
                    } label: {
                        Label(
                            expandedCitationID == citation.id
                                ? NSLocalizedString("citationsList.collapse", comment: "Collapse")
                                : NSLocalizedString("citationsList.expand", comment: "Expand"),
                            systemImage: expandedCitationID == citation.id ? "chevron.up" : "chevron.down"
                        )
                    }
                    
                    if citation.referenceCount > 0 {
                        Button {
                            onJumpToCitation?(citation)
                            dismiss()
                        } label: {
                            Label(
                                NSLocalizedString("citationsList.jumpToText", comment: "Jump to Reference"),
                                systemImage: "arrow.right"
                            )
                        }
                    }
                    
                    if let urlString = citation.url, !urlString.isEmpty,
                       let url = URL(string: urlString) {
                        Link(destination: url) {
                            Label(
                                NSLocalizedString("citationsList.openURL", comment: "Open URL"),
                                systemImage: "link"
                            )
                        }
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        showDeleteConfirmation = citation
                    } label: {
                        Label(
                            NSLocalizedString("citationsList.delete", comment: "Delete"),
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
                expandedCitationID = expandedCitationID == citation.id ? nil : citation.id
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                showDeleteConfirmation = citation
            } label: {
                Label(
                    NSLocalizedString("citationsList.delete", comment: "Delete"),
                    systemImage: "trash"
                )
            }
            
            Button {
                editingCitation = citation
            } label: {
                Label(
                    NSLocalizedString("citationsList.edit", comment: "Edit"),
                    systemImage: "pencil.circle"
                )
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if citation.referenceCount > 0 {
                Button {
                    onJumpToCitation?(citation)
                    dismiss()
                } label: {
                    Label(
                        NSLocalizedString("citationsList.jump", comment: "Jump"),
                        systemImage: "arrow.right"
                    )
                }
                .tint(.green)
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadCitations() {
        citations = project.citationEntries ?? []
        
        #if DEBUG
        print("📚 Loaded \(citations.count) citations for project")
        #endif
    }
    
    private func deleteCitation(_ citation: CitationEntry) {
        // Remove from project
        project.citationEntries?.removeAll { $0.id == citation.id }
        
        // Delete from context
        modelContext.delete(citation)
        
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("❌ Error deleting citation: \(error)")
            #endif
        }
        
        loadCitations()
        onCitationChanged?()
        onCitationDeleted?(citation)
        
        #if DEBUG
        print("🗑️ Deleted citation: \(citation.authors.first ?? "Unknown") (\(citation.year.map { String($0) } ?? "n.d."))")
        #endif
    }
}

// MARK: - Localization Keys

/*
 Add these to Localizable.strings:
 
 "citationsList.title" = "Citations";
 "citationsList.search.prompt" = "Search citations";
 "citationsList.sort" = "Sort";
 "citationsList.sort.author" = "Author";
 "citationsList.sort.year" = "Year";
 "citationsList.sort.dateCreated" = "Date Added";
 "citationsList.sort.dateModified" = "Date Modified";
 "citationsList.sort.referenceCount" = "Most Cited";
 "citationsList.addCitation" = "Add Citation";
 "citationsList.empty.title" = "No Citations";
 "citationsList.empty.description" = "Add citations to build your bibliography.";
 "citationsList.summary.total" = "Total Citations";
 "citationsList.summary.uncited" = "Uncited";
 "citationsList.edit" = "Edit";
 "citationsList.expand" = "Expand";
 "citationsList.collapse" = "Collapse";
 "citationsList.jumpToText" = "Jump to Reference";
 "citationsList.jump" = "Jump";
 "citationsList.openURL" = "Open URL";
 "citationsList.delete" = "Delete";
 "citationsList.confirmDelete.title" = "Delete Citation?";
 "citationsList.confirmDelete.button" = "Delete";
 "citationsList.confirmDelete.message" = "This citation will be permanently deleted.";
 "citationsList.confirmDelete.messageWithRefs" = "This citation is referenced %d times. The markers will remain but show as missing.";
 */
