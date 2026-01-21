//
//  ReferencePopoverView.swift
//  Writing Shed Pro
//
//  Feature 029: Back Matter Reference System
//  Created by GitHub Copilot on 15/01/2026.
//
//  Popover view for displaying reference content when user taps a reference marker
//

import SwiftUI
import SwiftData

/// View for displaying reference content in a popover
/// Shows different content based on reference type (note, glossary, reference, etc.)
struct ReferencePopoverView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    /// The reference attachment that was tapped
    let attachment: ReferenceAttachment
    
    /// The project containing the reference entries
    let project: Project?
    
    /// Callback when user wants to edit the entry
    var onEdit: (() -> Void)?
    
    /// Callback when user wants to navigate to the entry in back matter
    var onNavigateToEntry: (() -> Void)?
    
    /// Callback to close the popover
    var onClose: (() -> Void)?
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            headerView
            
            Divider()
            
            // Content based on reference type
            contentView
            
            Divider()
            
            // Actions
            actionButtons
        }
        .padding()
        .frame(minWidth: 280, maxWidth: 400)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 8)
    }
    
    // MARK: - Header View
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            // Icon and title
            referenceIcon
            
            VStack(alignment: .leading, spacing: 2) {
                Text(referenceTitle)
                    .font(.headline)
                
                Text(referenceSubtitle)
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
    }
    
    @ViewBuilder
    private var referenceIcon: some View {
        ZStack {
            Circle()
                .fill(iconBackgroundColor.opacity(0.1))
                .frame(width: 36, height: 36)
            
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(iconBackgroundColor)
        }
    }
    
    private var iconName: String {
        switch attachment.referenceType {
        case .note, .endnote:
            return "note.text"
        case .reference:
            return "book.closed"
        case .glossary:
            return "textformat.abc"
        case .index:
            return "list.number"
        case .figure:
            return "photo"
        case .table:
            return "tablecells"
        }
    }
    
    private var iconBackgroundColor: Color {
        switch attachment.referenceType {
        case .note, .endnote:
            return .blue
        case .reference:
            return .orange
        case .glossary:
            return .teal
        case .index:
            return .orange
        case .figure, .table:
            return .green
        }
    }
    
    private var referenceTitle: String {
        switch attachment.referenceType {
        case .note:
            return String(format: NSLocalizedString("reference.note.title", comment: "Note title"), attachment.displayNumber)
        case .endnote:
            return String(format: NSLocalizedString("reference.endnote.title", comment: "Endnote title"), attachment.displayNumber)
        case .reference:
            return NSLocalizedString("reference.reference.title", comment: "Reference")
        case .glossary:
            return NSLocalizedString("reference.glossary.title", comment: "Glossary Term")
        case .index:
            return NSLocalizedString("reference.index.title", comment: "Index Entry")
        case .figure:
            return String(format: NSLocalizedString("reference.figure.title", comment: "Figure title"), attachment.displayNumber)
        case .table:
            return String(format: NSLocalizedString("reference.table.title", comment: "Table title"), attachment.displayNumber)
        }
    }
    
    private var referenceSubtitle: String {
        attachment.displayText
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        switch attachment.referenceType {
        case .note, .endnote:
            noteContentView
        case .reference:
            referenceContentView
        case .glossary:
            glossaryContentView
        case .index:
            indexContentView
        case .figure, .table:
            figureTableContentView
        }
    }
    
    @ViewBuilder
    private var noteContentView: some View {
        if let note = fetchNoteEntry() {
            VStack(alignment: .leading, spacing: 8) {
                if let title = note.title, !title.isEmpty {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                }
                
                Text(note.content)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(10)
                
                if note.content.count > 500 {
                    Text(NSLocalizedString("reference.showMore", comment: "Show more..."))
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        } else {
            notFoundView
        }
    }
    
    @ViewBuilder
    private var referenceContentView: some View {
        if let reference = fetchReferenceEntry() {
            VStack(alignment: .leading, spacing: 8) {
                // Author
                if !reference.author.isEmpty {
                    Text(reference.author)
                        .font(.subheadline.weight(.medium))
                }
                
                // Publication Date
                if !reference.publicationDate.isEmpty {
                    Text("("+reference.publicationDate+")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Details (journal, publisher, URL, etc.)
                if !reference.details.isEmpty {
                    Text(reference.details)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } else {
            notFoundView
        }
    }
    
    @ViewBuilder
    private var glossaryContentView: some View {
        if let glossary = fetchGlossaryEntry() {
            VStack(alignment: .leading, spacing: 8) {
                // Term
                Text(glossary.term)
                    .font(.headline)
                    .foregroundColor(.teal)
                
                // Definition
                Text(glossary.definition)
                    .font(.body)
                    .foregroundColor(.primary)
                
                // Citation reference if available
                if let citation = glossary.citation {
                    HStack {
                        Image(systemName: "quote.opening")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(citation.inlineMarker)
                            .font(.caption)
                            .foregroundColor(.indigo)
                    }
                }
            }
        } else {
            notFoundView
        }
    }
    
    @ViewBuilder
    private var indexContentView: some View {
        if let indexEntry = fetchIndexEntry() {
            VStack(alignment: .leading, spacing: 8) {
                // Keyword path
                Text(indexEntry.fullPath)
                    .font(.headline)
                
                // Page numbers (if calculated)
                if !indexEntry.pageNumbers.isEmpty {
                    HStack {
                        Text(NSLocalizedString("reference.index.pages", comment: "Pages:"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(indexEntry.formattedPageNumbers)
                            .font(.caption.weight(.medium))
                    }
                }
                
                // Reference count
                Text(String(format: NSLocalizedString("reference.referenceCount", comment: "References"), indexEntry.referenceCount))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } else {
            notFoundView
        }
    }
    
    @ViewBuilder
    private var figureTableContentView: some View {
        // Placeholder for figure/table content
        VStack(alignment: .leading, spacing: 8) {
            Text(attachment.displayText)
                .font(.body)
            
            Text(NSLocalizedString("reference.figureTable.placeholder", comment: "Figure/Table reference"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var notFoundView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundColor(.orange)
            
            Text(NSLocalizedString("reference.notFound", comment: "Reference not found"))
                .font(.body)
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("reference.notFound.description", comment: "The referenced entry may have been deleted."))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Action Buttons
    
    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Edit button
            Button(action: {
                onEdit?()
            }) {
                Label(NSLocalizedString("reference.action.edit", comment: "Edit"), systemImage: "pencil")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            // Go to entry button
            Button(action: {
                onNavigateToEntry?()
            }) {
                Label(NSLocalizedString("reference.action.goToEntry", comment: "Go to Entry"), systemImage: "arrow.right.circle")
                    .font(.subheadline)
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Data Fetching
    
    private func fetchNoteEntry() -> NoteEntry? {
        let entryID = attachment.entryID
        let descriptor = FetchDescriptor<NoteEntry>(
            predicate: #Predicate { $0.id == entryID }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    private func fetchReferenceEntry() -> ReferenceEntry? {
        let entryID = attachment.entryID
        let descriptor = FetchDescriptor<ReferenceEntry>(
            predicate: #Predicate { $0.id == entryID }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    private func fetchGlossaryEntry() -> GlossaryEntry? {
        let entryID = attachment.entryID
        let descriptor = FetchDescriptor<GlossaryEntry>(
            predicate: #Predicate { $0.id == entryID }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    private func fetchIndexEntry() -> IndexEntry? {
        let entryID = attachment.entryID
        let descriptor = FetchDescriptor<IndexEntry>(
            predicate: #Predicate { $0.id == entryID }
        )
        return try? modelContext.fetch(descriptor).first
    }
}

// MARK: - Localization Keys

/*
 Add these to Localizable.strings:
 
 "reference.note.title" = "Note %d";
 "reference.endnote.title" = "Endnote %d";
 "reference.citation.title" = "Citation";
 "reference.glossary.title" = "Glossary Term";
 "reference.index.title" = "Index Entry";
 "reference.figure.title" = "Figure %d";
 "reference.table.title" = "Table %d";
 "reference.showMore" = "Show more...";
 "reference.index.pages" = "Pages:";
 "reference.referenceCount" = "%d references";
 "reference.figureTable.placeholder" = "Figure/Table reference";
 "reference.notFound" = "Reference Not Found";
 "reference.notFound.description" = "The referenced entry may have been deleted.";
 "reference.action.edit" = "Edit";
 "reference.action.goToEntry" = "Go to Entry";
 */
