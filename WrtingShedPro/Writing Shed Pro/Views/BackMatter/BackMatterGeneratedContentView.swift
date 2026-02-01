//
//  BackMatterGeneratedContentView.swift
//  Writing Shed Pro
//
//  Feature 029: Back Matter - Display auto-generated back matter content
//  This view shows compiled content for back matter files (Endnotes, Notes, Glossary, References, Index)
//

import SwiftUI
import SwiftData

/// View that displays auto-generated back matter content based on the file name
struct BackMatterGeneratedContentView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let file: TextFile
    let project: Project
    
    // MARK: - State
    
    @State private var entries: [Any] = []
    @State private var showDeletedAlert = false
    @State private var deletedItemName: String = ""
    @State private var previousEndnoteCount: Int = 0
    @State private var previousGlossaryCount: Int = 0
    @State private var previousReferencesCount: Int = 0
    @State private var previousIndexCount: Int = 0
    @State private var previousContributorsCount: Int = 0
    @State private var refreshTrigger = UUID()
    @State private var showAddContributorSheet = false
    @State private var contributorToEdit: ContributorEntry?
    @State private var editMode: EditMode = .inactive
    @State private var selectedContributorIDs: Set<UUID> = []
    @State private var contributorToDelete: ContributorEntry?
    @State private var showDeleteConfirmation = false
    @State private var contributorsToDelete: [ContributorEntry] = []
    
    // MARK: - Computed Properties
    
    /// Determine the back matter type based on file name
    private var backMatterType: BackMatterItem? {
        let fileName = file.name.lowercased()
        
        for item in BackMatterItem.allCases {
            if fileName.contains(item.rawValue.lowercased()) {
                return item
            }
        }
        return nil
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            // Contributors uses List for swipe actions and edit mode
            if backMatterType == .contributors {
                contributorsListContent
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch backMatterType {
                        case .endnotes:
                            endnotesContent
                        case .glossary:
                            glossaryContent
                        case .references:
                            referencesContent
                        case .index:
                            indexContent
                        case .contributors:
                            EmptyView() // Handled above
                        case nil:
                            emptyContent
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
        .id(refreshTrigger)
        .environment(\.editMode, $editMode)
        .toolbar {
            // Edit and Add buttons for contributors
            if backMatterType == .contributors {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        // Edit/Done button
                        if !(project.contributorEntries ?? []).isEmpty {
                            Button {
                                withAnimation {
                                    if editMode == .active {
                                        editMode = .inactive
                                        selectedContributorIDs.removeAll()
                                    } else {
                                        editMode = .active
                                    }
                                }
                            } label: {
                                Text(editMode == .active ? NSLocalizedString("button.done", comment: "Done") : NSLocalizedString("button.edit", comment: "Edit"))
                            }
                        }
                        
                        // Add button (only when not in edit mode)
                        if editMode != .active {
                            Button {
                                showAddContributorSheet = true
                            } label: {
                                Image(systemName: "plus")
                            }
                            .accessibilityLabel(NSLocalizedString("contributor.add.button", comment: "Add Contributor"))
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddContributorSheet) {
            ContributorEditorSheet(project: project, existingContributor: nil) {
                refreshTrigger = UUID()
            }
        }
        .sheet(item: $contributorToEdit) { contributor in
            ContributorEditorSheet(project: project, existingContributor: contributor) {
                refreshTrigger = UUID()
            }
        }
        .alert(
            deleteAlertTitle,
            isPresented: $showDeleteConfirmation
        ) {
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                contributorToDelete = nil
                contributorsToDelete = []
            }
            Button(NSLocalizedString("button.delete", comment: "Delete"), role: .destructive) {
                performDeleteContributors()
            }
        } message: {
            Text(deleteAlertMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Refresh when app returns to foreground (handles changes from other views)
            refreshTrigger = UUID()
        }
    }
    
    // MARK: - Delete Alert Helpers
    
    private var deleteAlertTitle: String {
        if contributorsToDelete.count > 1 {
            return String(format: NSLocalizedString("contributor.deleteMultiple.title", comment: "Delete Contributors"), contributorsToDelete.count)
        } else {
            return NSLocalizedString("contributor.delete.title", comment: "Delete Contributor")
        }
    }
    
    private var deleteAlertMessage: String {
        if contributorsToDelete.count > 1 {
            return String(format: NSLocalizedString("contributor.deleteMultiple.message", comment: "Are you sure?"), contributorsToDelete.count)
        } else if let contributor = contributorToDelete {
            return String(format: NSLocalizedString("contributor.delete.message", comment: "Are you sure you want to delete %@?"), contributor.displayName)
        } else if let first = contributorsToDelete.first {
            return String(format: NSLocalizedString("contributor.delete.message", comment: "Are you sure you want to delete %@?"), first.displayName)
        }
        return ""
    }
    
    /// Actually perform the deletion after confirmation
    private func performDeleteContributors() {
        withAnimation {
            // Handle batch delete
            if !contributorsToDelete.isEmpty {
                for contributor in contributorsToDelete {
                    modelContext.delete(contributor)
                }
                contributorsToDelete = []
                selectedContributorIDs.removeAll()
                editMode = .inactive
            }
            // Handle single delete
            else if let contributor = contributorToDelete {
                modelContext.delete(contributor)
                contributorToDelete = nil
            }
            refreshTrigger = UUID()
        }
    }
    
    // MARK: - Endnotes Content
    
    @ViewBuilder
    private var endnotesContent: some View {
        let endnotes = (project.noteEntries ?? [])
            .filter { $0.isEndnote }
            .sorted { $0.displayNumber < $1.displayNumber }
        
        if endnotes.isEmpty {
            // Check if we just deleted all endnotes (transition from non-empty to empty)
            if previousEndnoteCount > 0 {
                // Trigger alert
                VStack {}
                    .onAppear {
                        showDeletedAlert = true
                        deletedItemName = NSLocalizedString("backMatter.endnotes", comment: "Endnotes")
                    }
            } else {
                // First time viewing - show empty state
                emptyStateView(
                    title: NSLocalizedString("backMatter.endnotes.empty.title", comment: "No Endnotes"),
                    description: NSLocalizedString("backMatter.endnotes.empty.description", comment: "Endnotes added to your manuscript will appear here."),
                    systemImage: "number.circle"
                )
            }
        } else {
            Text(NSLocalizedString("backMatter.endnotes.header", comment: "Endnotes"))
                .font(.title2)
                .fontWeight(.bold)
            
            ForEach(endnotes) { note in
                endnoteRow(note)
            }
            .onAppear {
                previousEndnoteCount = endnotes.count
            }
            .onChange(of: endnotes.count) { _, newCount in
                previousEndnoteCount = newCount
            }
        }
    }
    
    private func endnoteRow(_ note: NoteEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Show tag if available, otherwise show number
            if let tag = note.tag, !tag.isEmpty {
                Text("[\(tag)]")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(minWidth: 50, alignment: .trailing)
            } else {
                Text("\(note.displayNumber).")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(width: 30, alignment: .trailing)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if let title = note.title, !title.isEmpty {
                    Text(title)
                        .font(.headline)
                }
                Text(note.content)
                    .font(.body)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Notes Content
    
    @ViewBuilder
    private var notesContent: some View {
        let notes = (project.noteEntries ?? [])
            .filter { !$0.isEndnote }
            .sorted { $0.displayNumber < $1.displayNumber }
        
        if notes.isEmpty {
            emptyStateView(
                title: NSLocalizedString("backMatter.notes.empty.title", comment: "No Notes"),
                description: NSLocalizedString("backMatter.notes.empty.description", comment: "Notes added to your manuscript will appear here."),
                systemImage: "note.text"
            )
        } else {
            Text(NSLocalizedString("backMatter.notes.header", comment: "Notes"))
                .font(.title2)
                .fontWeight(.bold)
            
            ForEach(notes) { note in
                noteRow(note)
            }
        }
    }
    
    private func noteRow(_ note: NoteEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Show tag if available, otherwise show number
            if let tag = note.tag, !tag.isEmpty {
                Text("[Note: \(tag)]")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(minWidth: 80, alignment: .trailing)
            } else {
                Text("\(note.displayNumber).")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(width: 30, alignment: .trailing)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if let title = note.title, !title.isEmpty {
                    Text(title)
                        .font(.headline)
                }
                Text(note.content)
                    .font(.body)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Glossary Content
    
    @ViewBuilder
    private var glossaryContent: some View {
        let terms = (project.glossaryEntries ?? [])
            .sorted { $0.term.lowercased() < $1.term.lowercased() }
        
        if terms.isEmpty {
            emptyStateView(
                title: NSLocalizedString("backMatter.glossary.empty.title", comment: "No Glossary Terms"),
                description: NSLocalizedString("backMatter.glossary.empty.description", comment: "Glossary terms added to your manuscript will appear here."),
                systemImage: "text.book.closed"
            )
        } else {
            Text(NSLocalizedString("backMatter.glossary.header", comment: "Glossary"))
                .font(.title2)
                .fontWeight(.bold)
            
            ForEach(terms) { term in
                glossaryRow(term)
            }
        }
    }
    
    private func glossaryRow(_ term: GlossaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(term.term)
                .font(.headline)
            Text(term.definition)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - References Content
    
    @ViewBuilder
    private var referencesContent: some View {
        let references = (project.referenceEntries ?? [])
            .sorted { $0.author.lowercased() < $1.author.lowercased() }
        
        if references.isEmpty {
            emptyStateView(
                title: NSLocalizedString("backMatter.references.empty.title", comment: "No References"),
                description: NSLocalizedString("backMatter.references.empty.description", comment: "References added to your manuscript will appear here."),
                systemImage: "books.vertical"
            )
        } else {
            Text(NSLocalizedString("backMatter.references.header", comment: "References"))
                .font(.title2)
                .fontWeight(.bold)
            
            ForEach(references) { reference in
                referenceRow(reference)
            }
        }
    }
    
    private func referenceRow(_ reference: ReferenceEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formatReference(reference))
                .font(.body)
        }
        .padding(.vertical, 4)
    }
    
    /// Format a reference entry for display
    private func formatReference(_ reference: ReferenceEntry) -> String {
        var parts: [String] = []
        
        // Author
        if !reference.author.isEmpty {
            parts.append(reference.author)
        }
        
        // Publication Date
        if !reference.publicationDate.isEmpty {
            parts.append("(\(reference.publicationDate))")
        }
        
        // Details (journal, publisher, URL, etc.)
        if !reference.details.isEmpty {
            parts.append(reference.details)
        }
        
        return parts.joined(separator: ". ") + "."
    }
    
    // MARK: - Index Content
    
    @ViewBuilder
    private var indexContent: some View {
        let indexEntries = (project.indexEntries ?? [])
            .sorted { $0.keyword.lowercased() < $1.keyword.lowercased() }
        
        if indexEntries.isEmpty {
            emptyStateView(
                title: NSLocalizedString("backMatter.index.empty.title", comment: "No Index Entries"),
                description: NSLocalizedString("backMatter.index.empty.description", comment: "Index entries added to your manuscript will appear here."),
                systemImage: "list.bullet.indent"
            )
        } else {
            Text(NSLocalizedString("backMatter.index.header", comment: "Index"))
                .font(.title2)
                .fontWeight(.bold)
            
            // Group by first letter
            let grouped = Dictionary(grouping: indexEntries) { entry -> String in
                let firstChar = entry.keyword.first?.uppercased() ?? "#"
                return firstChar.first?.isLetter == true ? firstChar : "#"
            }
            
            ForEach(grouped.keys.sorted(), id: \.self) { letter in
                indexSection(letter: letter, entries: grouped[letter] ?? [])
            }
        }
    }
    
    private func indexSection(letter: String, entries: [IndexEntry]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(letter)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.accentColor)
            
            ForEach(entries) { entry in
                indexRow(entry)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func indexRow(_ entry: IndexEntry) -> some View {
        HStack {
            Text(entry.keyword)
                .font(.body)
            
            Spacer()
            
            if entry.referenceCount > 0 {
                Text("(\(entry.referenceCount))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Contributors Content
    
    /// List-based view for contributors with swipe-to-delete and edit mode support
    @ViewBuilder
    private var contributorsListContent: some View {
        let contributors = (project.contributorEntries ?? []).sorted()
        
        if contributors.isEmpty {
            // Check if we just deleted all contributors
            if previousContributorsCount > 0 {
                VStack {}
                    .onAppear {
                        showDeletedAlert = true
                        deletedItemName = NSLocalizedString("backMatter.contributors", comment: "Contributors")
                    }
            } else {
                emptyStateView(
                    title: NSLocalizedString("backMatter.contributors.empty.title", comment: "No Contributors"),
                    description: NSLocalizedString("backMatter.contributors.empty.description", comment: "Tap + to add contributors to your publication."),
                    systemImage: "person.2"
                )
            }
        } else {
            List(selection: $selectedContributorIDs) {
                ForEach(contributors) { contributor in
                    contributorRow(contributor)
                        .tag(contributor.id)
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, $editMode)
            .onAppear {
                previousContributorsCount = contributors.count
            }
            // Bottom toolbar when in edit mode with selections
            .safeAreaInset(edge: .bottom) {
                if editMode == .active && !selectedContributorIDs.isEmpty {
                    HStack {
                        Spacer()
                        
                        // Trash button
                        Button(role: .destructive) {
                            let selected = contributors.filter { selectedContributorIDs.contains($0.id) }
                            contributorsToDelete = selected
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel(String(format: NSLocalizedString("contributor.deleteCount", comment: "Delete count"), selectedContributorIDs.count))
                    }
                    .padding()
                    .background(.regularMaterial)
                }
            }
        }
    }
    
    private func contributorRow(_ contributor: ContributorEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Name
            Text(contributor.displayName)
                .font(.headline)
            
            // Biography
            if !contributor.biography.isEmpty {
                Text(contributor.biography)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            contributorToEdit = contributor
        }
        .contextMenu {
            Button {
                contributorToEdit = contributor
            } label: {
                Label(NSLocalizedString("button.edit", comment: "Edit"), systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                contributorToDelete = contributor
                showDeleteConfirmation = true
            } label: {
                Label(NSLocalizedString("button.delete", comment: "Delete"), systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                contributorToDelete = contributor
                showDeleteConfirmation = true
            } label: {
                Label(NSLocalizedString("button.delete", comment: "Delete"), systemImage: "trash")
            }
        }
    }
    
    // MARK: - Empty Content
    
    @ViewBuilder
    private var emptyContent: some View {
        ContentUnavailableView {
            Label(
                NSLocalizedString("backMatter.unknown.title", comment: "Unknown Content Type"),
                systemImage: "questionmark.circle"
            )
        } description: {
            Text(NSLocalizedString("backMatter.unknown.description", comment: "This file doesn't match a known back matter type."))
        }
    }
    
    // MARK: - Helper Views
    
    private func emptyStateView(title: String, description: String, systemImage: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Helper Extension

extension BackMatterGeneratedContentView {
    /// Check if a file is a generated back matter file
    static func isGeneratedBackMatterFile(_ file: TextFile) -> Bool {
        guard let folder = file.parentFolder,
              folder.isBackMatterFolder else {
            return false
        }
        
        let fileName = file.name.lowercased()
        
        // Check if file name matches any back matter item
        for item in BackMatterItem.allCases {
            if fileName.contains(item.rawValue.lowercased()) {
                return true
            }
        }
        return false
    }
}
