//
//  BackMatterGenerator.swift
//  Writing Shed Pro
//
//  Feature 029: Back Matter Reference System - Export Integration
//  Generates Notes, Glossary, Bibliography, and Index sections for manuscript export
//

import Foundation
import SwiftData
import UIKit

/// Represents a page reference with primary indicator for index generation
struct IndexPageReference: Hashable {
    let pageNumber: Int
    let isPrimary: Bool
}

/// Service for generating back matter sections for manuscript export
final class BackMatterGenerator {
    
    private let context: ModelContext
    private let project: Project
    
    // MARK: - Style Resolution
    
    /// Resolve a style using StyleSheetService (properly falls back to default stylesheet)
    private func resolveStyle(_ textStyle: UIFont.TextStyle) -> TextStyleModel? {
        return StyleSheetService.resolveStyle(textStyle, for: project, context: context)
    }
    
    /// Get heading style attributes from the project's stylesheet (Title 1)
    private var headingAttributes: [NSAttributedString.Key: Any] {
        if let style = resolveStyle(.title1) {
            return style.generateAttributes()
        }
        // Fallback if style resolution fails completely
        return [
            .font: UIFont.preferredFont(forTextStyle: .title1),
            .foregroundColor: UIColor.label
        ]
    }
    
    /// Get entry heading style attributes from the project's stylesheet (Headline)
    private var entryHeadingAttributes: [NSAttributedString.Key: Any] {
        if let style = resolveStyle(.headline) {
            return style.generateAttributes()
        }
        // Fallback if style resolution fails completely
        return [
            .font: UIFont.preferredFont(forTextStyle: .headline),
            .foregroundColor: UIColor.label
        ]
    }
    
    /// Get body text style attributes from the project's stylesheet (Body)
    private var bodyAttributes: [NSAttributedString.Key: Any] {
        if let style = resolveStyle(.body) {
            return style.generateAttributes()
        }
        // Fallback if style resolution fails completely
        return [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label
        ]
    }
    
    /// Get secondary text style attributes from the project's stylesheet (Caption 1)
    private var secondaryAttributes: [NSAttributedString.Key: Any] {
        if let style = resolveStyle(.caption1) {
            return style.generateAttributes()
        }
        // Fallback if style resolution fails completely
        return [
            .font: UIFont.preferredFont(forTextStyle: .caption1),
            .foregroundColor: UIColor.secondaryLabel
        ]
    }
    
    /// Paragraph style for entries with hanging indent (for index)
    private var hangingIndentStyle: NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = 0
        style.headIndent = 20
        style.lineSpacing = 2
        style.paragraphSpacing = 4
        return style
    }
    
    /// Paragraph style for sub-entries (indented)
    private var subEntryStyle: NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = 20
        style.headIndent = 40
        style.lineSpacing = 2
        style.paragraphSpacing = 4
        return style
    }
    
    // MARK: - Initialization
    
    init(context: ModelContext, project: Project) {
        self.context = context
        self.project = project
    }
    
    // MARK: - Public Methods
    
    /// Generate complete back matter content
    /// - Parameters:
    ///   - includeNotes: Include Notes/Endnotes section
    ///   - includeGlossary: Include Glossary section
    ///   - includeBibliography: Include Bibliography section
    ///   - includeIndex: Include Index section (requires page map)
    ///   - includeContributors: Include Contributors section
    ///   - pageMap: Map of reference ID to page numbers with primary indicators (for index)
    /// - Returns: Attributed string with all requested back matter sections
    func generateBackMatter(
        includeNotes: Bool = true,
        includeGlossary: Bool = true,
        includeBibliography: Bool = true,
        includeIndex: Bool = true,
        includeContributors: Bool = true,
        pageMap: [UUID: [IndexPageReference]] = [:]
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        if includeNotes {
            if let notesSection = generateNotesSection() {
                result.append(notesSection)
            }
        }
        
        if includeGlossary {
            if let glossarySection = generateGlossarySection() {
                result.append(glossarySection)
            }
        }
        
        if includeBibliography {
            if let bibliographySection = generateBibliographySection() {
                result.append(bibliographySection)
            }
        }
        
        if includeIndex {
            if let indexSection = generateIndexSection(pageMap: pageMap) {
                result.append(indexSection)
            }
        }
        
        if includeContributors {
            if let contributorsSection = generateContributorsSection() {
                result.append(contributorsSection)
            }
        }
        
        return result
    }
    
    // MARK: - Notes Section
    
    /// Generate the Notes/Endnotes section
    /// - Returns: Attributed string with notes section, or nil if no notes
    func generateNotesSection() -> NSAttributedString? {
        // Fetch notes for this project that have active references (refCount > 0)
        let projectID = project.id
        let descriptor = FetchDescriptor<NoteEntry>(
            predicate: #Predicate<NoteEntry> { entry in
                entry.project?.id == projectID && entry.referenceCount > 0
            },
            sortBy: [SortDescriptor(\.displayNumber)]
        )
        
        guard let notes = try? context.fetch(descriptor), !notes.isEmpty else {
            return nil
        }
        
        let result = NSMutableAttributedString()
        
        // Section heading with blank line after
        let heading = NSAttributedString(
            string: NSLocalizedString("backMatter.notes.heading", comment: "Notes") + "\n\n",
            attributes: headingAttributes
        )
        result.append(heading)
        
        // Separate endnotes from general notes
        let endnotes = notes.filter { $0.isEndnote }.sorted()
        let generalNotes = notes.filter { !$0.isEndnote }.sorted()
        
        // Add endnotes first (numbered)
        if !endnotes.isEmpty {
            for note in endnotes {
                let noteText = formatNoteEntry(note)
                result.append(noteText)
            }
        }
        
        // Add general notes
        if !generalNotes.isEmpty {
            if !endnotes.isEmpty {
                // Add separator if we had endnotes
                result.append(NSAttributedString(string: "\n"))
            }
            for note in generalNotes {
                let noteText = formatNoteEntry(note)
                result.append(noteText)
            }
        }
        
        return result
    }
    
    /// Format a single note entry
    private func formatNoteEntry(_ note: NoteEntry) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        // Note marker - use tag if available, otherwise use display number for backward compatibility
        let marker: String
        if let tag = note.tag, !tag.isEmpty {
            // Use tag-based marker
            if note.isEndnote {
                marker = "[\(tag)] "
            } else {
                marker = "[Note: \(tag)] "
            }
        } else {
            // Fallback to number-based marker
            if note.isEndnote {
                marker = "[\(note.displayNumber)] "
            } else {
                marker = "[Note \(note.displayNumber)] "
            }
        }
        
        let markerAttr = NSAttributedString(
            string: marker,
            attributes: entryHeadingAttributes
        )
        result.append(markerAttr)
        
        // Title on same line as marker (if present), followed by newline
        if let title = note.title, !title.isEmpty {
            let titleAttr = NSAttributedString(
                string: title + "\n",
                attributes: entryHeadingAttributes
            )
            result.append(titleAttr)
        } else {
            // No title, just add newline after marker
            result.append(NSAttributedString(string: "\n", attributes: entryHeadingAttributes))
        }
        
        // Content with paragraph spacing from body style
        let contentAttr = NSAttributedString(
            string: note.content + "\n",
            attributes: bodyAttributes
        )
        result.append(contentAttr)
        
        return result
    }
    
    // MARK: - Glossary Section
    
    /// Generate the Glossary section
    /// - Returns: Attributed string with glossary section, or nil if no entries
    func generateGlossarySection() -> NSAttributedString? {
        // Fetch glossary entries for this project that have active references (refCount > 0)
        let projectID = project.id
        let descriptor = FetchDescriptor<GlossaryEntry>(
            predicate: #Predicate<GlossaryEntry> { entry in
                entry.project?.id == projectID && entry.referenceCount > 0
            },
            sortBy: [SortDescriptor(\.term)]
        )
        
        guard let entries = try? context.fetch(descriptor), !entries.isEmpty else {
            return nil
        }
        
        let result = NSMutableAttributedString()
        
        // Section heading
        var headingAttrs = headingAttributes
        // Add extra spacing before for section separation
        if let existingStyle = headingAttrs[.paragraphStyle] as? NSParagraphStyle {
            let mutableStyle = existingStyle.mutableCopy() as! NSMutableParagraphStyle
            mutableStyle.paragraphSpacingBefore = 24
            headingAttrs[.paragraphStyle] = mutableStyle
        }
        let heading = NSAttributedString(
            string: NSLocalizedString("backMatter.glossary.heading", comment: "Glossary") + "\n",
            attributes: headingAttrs
        )
        result.append(heading)
        
        // Group entries by first letter
        let grouped = Dictionary(grouping: entries.sorted()) { entry -> String in
            String(entry.term.prefix(1)).uppercased()
        }
        
        for letter in grouped.keys.sorted() {
            // Letter heading
            var letterAttrs = entryHeadingAttributes
            letterAttrs[.foregroundColor] = UIColor.secondaryLabel
            let letterHeading = NSAttributedString(
                string: letter + "\n",
                attributes: letterAttrs
            )
            result.append(letterHeading)
            
            // Entries for this letter
            for entry in grouped[letter] ?? [] {
                let entryText = formatGlossaryEntry(entry)
                result.append(entryText)
            }
            
            result.append(NSAttributedString(string: "\n"))
        }
        
        return result
    }
    
    /// Format a single glossary entry
    private func formatGlossaryEntry(_ entry: GlossaryEntry) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        // Term (bold)
        let termAttr = NSAttributedString(
            string: entry.term,
            attributes: entryHeadingAttributes
        )
        result.append(termAttr)
        
        // Separator
        result.append(NSAttributedString(string: " — "))
        
        // Definition
        var defAttrs = bodyAttributes
        defAttrs[.paragraphStyle] = hangingIndentStyle
        let definitionAttr = NSAttributedString(
            string: entry.definition + "\n",
            attributes: defAttrs
        )
        result.append(definitionAttr)
        
        return result
    }
    
    // MARK: - References Section
    
    /// Generate the References section
    /// - Returns: Attributed string with references section, or nil if no entries
    func generateReferencesSection() -> NSAttributedString? {
        // Fetch reference entries for this project that have active references (refCount > 0)
        let projectID = project.id
        let descriptor = FetchDescriptor<ReferenceEntry>(
            predicate: #Predicate<ReferenceEntry> { entry in
                entry.project?.id == projectID && entry.referenceCount > 0
            },
            sortBy: [SortDescriptor(\.author)]
        )
        
        guard let references = try? context.fetch(descriptor), !references.isEmpty else {
            return nil
        }
        
        let result = NSMutableAttributedString()
        
        // Section heading
        var headingAttrs = headingAttributes
        // Add extra spacing before for section separation
        if let existingStyle = headingAttrs[.paragraphStyle] as? NSParagraphStyle {
            let mutableStyle = existingStyle.mutableCopy() as! NSMutableParagraphStyle
            mutableStyle.paragraphSpacingBefore = 24
            headingAttrs[.paragraphStyle] = mutableStyle
        }
        let heading = NSAttributedString(
            string: NSLocalizedString("backMatter.references.heading", comment: "References") + "\n",
            attributes: headingAttrs
        )
        result.append(heading)
        
        // Sort by author
        let sorted = references.sorted { $0.author.lowercased() < $1.author.lowercased() }
        
        for reference in sorted {
            let referenceText = formatReferenceEntry(reference)
            result.append(referenceText)
        }
        
        return result
    }
    
    /// Format a single reference entry
    private func formatReferenceEntry(_ reference: ReferenceEntry) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        // Format: Author (Date). Details
        var parts: [String] = []
        
        // Author
        if !reference.author.isEmpty {
            parts.append(reference.author)
        }
        
        // Date
        if !reference.publicationDate.isEmpty {
            parts.append("(\(reference.publicationDate))")
        }
        
        // Details
        if !reference.details.isEmpty {
            parts.append(reference.details)
        }
        
        let fullReference = parts.joined(separator: " ") + "\n"
        
        var refAttrs = bodyAttributes
        refAttrs[.paragraphStyle] = hangingIndentStyle
        let referenceAttr = NSAttributedString(
            string: fullReference,
            attributes: refAttrs
        )
        result.append(referenceAttr)
        
        return result
    }
    
    // MARK: - Bibliography Section
    
    /// Generate the Bibliography/Works Cited section
    /// - Returns: Attributed string with bibliography section, or nil if no citations
    func generateBibliographySection() -> NSAttributedString? {
        // Fetch citations for this project
        let projectID = project.id
        let descriptor = FetchDescriptor<CitationEntry>(
            predicate: #Predicate<CitationEntry> { entry in
                entry.project?.id == projectID
            }
        )
        
        guard let citations = try? context.fetch(descriptor), !citations.isEmpty else {
            return nil
        }
        
        let result = NSMutableAttributedString()
        
        // Section heading
        var headingAttrs = headingAttributes
        // Add extra spacing before for section separation
        if let existingStyle = headingAttrs[.paragraphStyle] as? NSParagraphStyle {
            let mutableStyle = existingStyle.mutableCopy() as! NSMutableParagraphStyle
            mutableStyle.paragraphSpacingBefore = 24
            headingAttrs[.paragraphStyle] = mutableStyle
        }
        let heading = NSAttributedString(
            string: NSLocalizedString("backMatter.bibliography.heading", comment: "Bibliography") + "\n",
            attributes: headingAttrs
        )
        result.append(heading)
        
        // Sort by author, then year
        let sorted = citations.sorted()
        
        for citation in sorted {
            let citationText = formatCitationEntry(citation)
            result.append(citationText)
        }
        
        return result
    }
    
    /// Format a single citation entry (APA-style as default)
    private func formatCitationEntry(_ citation: CitationEntry) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        // Authors
        let authors = citation.authors
        var authorText = ""
        
        if authors.isEmpty {
            authorText = NSLocalizedString("citation.unknownAuthor", comment: "Unknown Author")
        } else if authors.count == 1 {
            authorText = authors[0]
        } else if authors.count == 2 {
            authorText = "\(authors[0]) & \(authors[1])"
        } else {
            authorText = "\(authors[0]) et al."
        }
        
        // Format: Author(s). (Year). Title. Source. URL/DOI
        var fullCitation = authorText
        
        // Year
        if let year = citation.year {
            fullCitation += " (\(year))."
        } else {
            fullCitation += "."
        }
        
        // Title (italicized)
        var citationAttrs = bodyAttributes
        citationAttrs[.paragraphStyle] = hangingIndentStyle
        let beforeTitle = NSAttributedString(
            string: fullCitation + " ",
            attributes: citationAttrs
        )
        result.append(beforeTitle)
        
        // Title (get italic version of body font)
        var titleAttrs = bodyAttributes
        if let bodyFont = titleAttrs[.font] as? UIFont {
            titleAttrs[.font] = bodyFont.italicized
        }
        let titleAttr = NSAttributedString(
            string: citation.title,
            attributes: titleAttrs
        )
        result.append(titleAttr)
        
        // Source details
        var sourceDetails = ""
        
        if let source = citation.source, !source.isEmpty {
            sourceDetails += ". " + source
        }
        
        if let volume = citation.volume, !volume.isEmpty {
            sourceDetails += ", \(volume)"
            if let issue = citation.issue, !issue.isEmpty {
                sourceDetails += "(\(issue))"
            }
        }
        
        if let pages = citation.pages, !pages.isEmpty {
            sourceDetails += ", \(pages)"
        }
        
        if let city = citation.city, !city.isEmpty {
            sourceDetails += ". " + city
        }
        
        // URL or DOI
        if let doi = citation.doi, !doi.isEmpty {
            sourceDetails += ". https://doi.org/\(doi)"
        } else if let url = citation.url, !url.isEmpty {
            sourceDetails += ". \(url)"
        }
        
        sourceDetails += "\n"
        
        var sourceAttrs = bodyAttributes
        sourceAttrs[.paragraphStyle] = hangingIndentStyle
        let sourceAttr = NSAttributedString(
            string: sourceDetails,
            attributes: sourceAttrs
        )
        result.append(sourceAttr)
        
        return result
    }
    
    // MARK: - Index Section
    
    /// Generate the Index section with page numbers
    /// - Parameter pageMap: Map of index entry ID to page numbers where it appears
    /// - Returns: Attributed string with index section, or nil if no entries
    func generateIndexSection(pageMap: [UUID: [IndexPageReference]]) -> NSAttributedString? {
        // Fetch index entries for this project (top-level only) that have active references (refCount > 0)
        let projectID = project.id
        let descriptor = FetchDescriptor<IndexEntry>(
            predicate: #Predicate<IndexEntry> { entry in
                entry.project?.id == projectID && entry.parentEntry == nil && entry.referenceCount > 0
            },
            sortBy: [SortDescriptor(\.keyword)]
        )
        
        guard let entries = try? context.fetch(descriptor), !entries.isEmpty else {
            return nil
        }
        
        let result = NSMutableAttributedString()
        
        // Section heading
        var headingAttrs = headingAttributes
        // Add extra spacing before for section separation
        if let existingStyle = headingAttrs[.paragraphStyle] as? NSParagraphStyle {
            let mutableStyle = existingStyle.mutableCopy() as! NSMutableParagraphStyle
            mutableStyle.paragraphSpacingBefore = 24
            headingAttrs[.paragraphStyle] = mutableStyle
        }
        let heading = NSAttributedString(
            string: NSLocalizedString("backMatter.index.heading", comment: "Index") + "\n",
            attributes: headingAttrs
        )
        result.append(heading)
        
        // Group entries by first letter
        let grouped = Dictionary(grouping: entries.sorted()) { entry -> String in
            String(entry.keyword.prefix(1)).uppercased()
        }
        
        for letter in grouped.keys.sorted() {
            // Letter heading
            var letterAttrs = entryHeadingAttributes
            letterAttrs[.foregroundColor] = UIColor.secondaryLabel
            let letterHeading = NSAttributedString(
                string: letter + "\n",
                attributes: letterAttrs
            )
            result.append(letterHeading)
            
            // Entries for this letter
            for entry in grouped[letter] ?? [] {
                let entryText = formatIndexEntry(entry, pageMap: pageMap, indentLevel: 0)
                result.append(entryText)
            }
            
            result.append(NSAttributedString(string: "\n"))
        }
        
        return result
    }
    
    /// Format a single index entry with its sub-entries
    /// - Note: Primary page references are displayed in bold
    private func formatIndexEntry(_ entry: IndexEntry, pageMap: [UUID: [IndexPageReference]], indentLevel: Int) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        // Determine paragraph style based on indent level
        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = CGFloat(indentLevel * 20)
        style.headIndent = CGFloat(indentLevel * 20 + 20)
        style.lineSpacing = 2
        style.paragraphSpacing = 2
        
        // Keyword
        var keywordAttrs = indentLevel == 0 ? entryHeadingAttributes : bodyAttributes
        keywordAttrs[.paragraphStyle] = style
        let keywordAttr = NSAttributedString(
            string: entry.keyword,
            attributes: keywordAttrs
        )
        result.append(keywordAttr)
        
        // Page numbers with primary references in bold
        if let pages = pageMap[entry.id], !pages.isEmpty {
            result.append(NSAttributedString(string: ", ", attributes: secondaryAttributes))
            let formattedPages = formatPageReferencesWithPrimary(pages)
            result.append(formattedPages)
        }
        
        // Cross-references ("see" and "see also")
        // Look up "see" entry by ID
        if let seeEntryID = entry.seeEntryID {
            let allEntries = project.indexEntries ?? []
            if let seeEntry = allEntries.first(where: { $0.id == seeEntryID }) {
                result.append(NSAttributedString(string: ". ", attributes: secondaryAttributes))
                result.append(NSAttributedString(
                    string: NSLocalizedString("index.see", comment: "See"),
                    attributes: [.font: UIFont.italicSystemFont(ofSize: 12), .foregroundColor: UIColor.secondaryLabel]
                ))
                result.append(NSAttributedString(string: " \(seeEntry.keyword)", attributes: secondaryAttributes))
            }
        }
        
        // "See also" references - look up entries by ID
        let seeAlsoIDs = entry.seeAlsoEntryIDs
        if !seeAlsoIDs.isEmpty {
            // Fetch the referenced entries from the project's index entries
            let allEntries = project.indexEntries ?? []
            let seeAlsoKeywords = seeAlsoIDs.compactMap { id in
                allEntries.first { $0.id == id }?.keyword
            }.joined(separator: ", ")
            
            if !seeAlsoKeywords.isEmpty {
                result.append(NSAttributedString(string: ". ", attributes: secondaryAttributes))
                result.append(NSAttributedString(
                    string: NSLocalizedString("index.seeAlso", comment: "See also"),
                    attributes: [.font: UIFont.italicSystemFont(ofSize: 12), .foregroundColor: UIColor.secondaryLabel]
                ))
                result.append(NSAttributedString(string: " \(seeAlsoKeywords)", attributes: secondaryAttributes))
            }
        }
        
        result.append(NSAttributedString(string: "\n"))
        
        // Sub-entries (children)
        if let children = entry.childEntries, !children.isEmpty {
            for child in children.sorted() {
                let childText = formatIndexEntry(child, pageMap: pageMap, indentLevel: indentLevel + 1)
                result.append(childText)
            }
        }
        
        return result
    }
    
    /// Format page numbers with ranges (e.g., "1, 3, 5-7, 12")
    private func formatPageNumbers(_ pages: [Int]) -> String {
        guard !pages.isEmpty else { return "" }
        
        let sorted = pages.sorted()
        var result: [String] = []
        var rangeStart = sorted[0]
        var rangeEnd = sorted[0]
        
        for i in 1..<sorted.count {
            if sorted[i] == rangeEnd + 1 {
                rangeEnd = sorted[i]
            } else {
                if rangeStart == rangeEnd {
                    result.append("\(rangeStart)")
                } else {
                    result.append("\(rangeStart)–\(rangeEnd)")
                }
                rangeStart = sorted[i]
                rangeEnd = sorted[i]
            }
        }
        
        // Add the last range
        if rangeStart == rangeEnd {
            result.append("\(rangeStart)")
        } else {
            result.append("\(rangeStart)–\(rangeEnd)")
        }
        
        return result.joined(separator: ", ")
    }
    
    /// Format page references with ranges and bold for primary references
    /// Example: [1, 2, 3, 5 (primary), 7, 8] → "1-3, **5**, 7-8"
    private func formatPageReferencesWithPrimary(_ refs: [IndexPageReference]) -> NSAttributedString {
        guard !refs.isEmpty else { return NSAttributedString() }
        
        let sorted = refs.sorted { $0.pageNumber < $1.pageNumber }
        
        // Build ranges with primary tracking
        struct PageRange {
            var start: Int
            var end: Int
            var hasPrimary: Bool
        }
        var ranges: [PageRange] = []
        
        for ref in sorted {
            if let lastIndex = ranges.indices.last,
               ranges[lastIndex].end == ref.pageNumber - 1 {
                ranges[lastIndex].end = ref.pageNumber
                ranges[lastIndex].hasPrimary = ranges[lastIndex].hasPrimary || ref.isPrimary
            } else {
                ranges.append(PageRange(start: ref.pageNumber, end: ref.pageNumber, hasPrimary: ref.isPrimary))
            }
        }
        
        let result = NSMutableAttributedString()
        
        for (index, range) in ranges.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: ", ", attributes: secondaryAttributes))
            }
            
            let text: String
            if range.start == range.end {
                text = "\(range.start)"
            } else {
                text = "\(range.start)–\(range.end)"
            }
            
            // Apply bold if this range includes a primary reference
            var attrs = secondaryAttributes
            if range.hasPrimary {
                if let font = attrs[.font] as? UIFont {
                    attrs[.font] = UIFont.boldSystemFont(ofSize: font.pointSize)
                }
            }
            
            result.append(NSAttributedString(string: text, attributes: attrs))
        }
        
        return result
    }
    
    // MARK: - Contributors Section
    
    /// Generate the Contributors section
    /// - Returns: Attributed string with contributors section, or nil if no contributors
    func generateContributorsSection() -> NSAttributedString? {
        // Get contributors for this project, sorted by surname
        let contributors = (project.contributorEntries ?? []).sorted()
        
        guard !contributors.isEmpty else { return nil }
        
        let result = NSMutableAttributedString()
        
        // Section heading
        let heading = NSLocalizedString("backMatter.contributors.header", comment: "CONTRIBUTORS")
        result.append(NSAttributedString(string: "\n\n"))
        result.append(NSAttributedString(string: heading.uppercased(), attributes: headingAttributes))
        result.append(NSAttributedString(string: "\n\n"))
        
        // Add each contributor
        for contributor in contributors {
            result.append(formatContributor(contributor))
        }
        
        return result
    }
    
    /// Format a single contributor entry
    private func formatContributor(_ contributor: ContributorEntry) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        // Name (bold)
        let name = contributor.displayName
        result.append(NSAttributedString(string: name, attributes: entryHeadingAttributes))
        result.append(NSAttributedString(string: "\n"))
        
        // Biography
        if !contributor.biography.isEmpty {
            result.append(NSAttributedString(string: contributor.biography, attributes: bodyAttributes))
            result.append(NSAttributedString(string: "\n"))
        }
        
        result.append(NSAttributedString(string: "\n"))
        
        return result
    }
}

// MARK: - Plain Text Back Matter

extension BackMatterGenerator {
    
    /// Generate plain text back matter (for plain text export)
    /// - Parameters:
    ///   - includeNotes: Include Notes/Endnotes section
    ///   - includeGlossary: Include Glossary section
    ///   - includeBibliography: Include Bibliography section
    ///   - includeContributors: Include Contributors section
    /// - Returns: Plain text string with back matter
    func generatePlainTextBackMatter(
        includeNotes: Bool = true,
        includeGlossary: Bool = true,
        includeBibliography: Bool = true,
        includeContributors: Bool = true
    ) -> String {
        var result = ""
        
        if includeNotes {
            if let notesSection = generatePlainTextNotesSection() {
                result += notesSection
            }
        }
        
        if includeGlossary {
            if let glossarySection = generatePlainTextGlossarySection() {
                result += glossarySection
            }
        }
        
        if includeBibliography {
            if let bibliographySection = generatePlainTextBibliographySection() {
                result += bibliographySection
            }
        }
        
        if includeContributors {
            if let contributorsSection = generatePlainTextContributorsSection() {
                result += contributorsSection
            }
        }
        
        // Note: Index is not included in plain text (no page numbers)
        
        return result
    }
    
    /// Generate plain text notes section
    private func generatePlainTextNotesSection() -> String? {
        let projectID = project.id
        let descriptor = FetchDescriptor<NoteEntry>(
            predicate: #Predicate<NoteEntry> { entry in
                entry.project?.id == projectID
            },
            sortBy: [SortDescriptor(\.displayNumber)]
        )
        
        guard let notes = try? context.fetch(descriptor), !notes.isEmpty else {
            return nil
        }
        
        var result = "\n\n" + NSLocalizedString("backMatter.notes.heading", comment: "Notes") + "\n"
        result += String(repeating: "-", count: 40) + "\n\n"
        
        for note in notes.sorted() {
            // Use tag if available, otherwise use display number
            if let tag = note.tag, !tag.isEmpty {
                if note.isEndnote {
                    result += "[\(tag)] "
                } else {
                    result += "[Note: \(tag)] "
                }
            } else {
                if note.isEndnote {
                    result += "[\(note.displayNumber)] "
                } else {
                    result += "[Note \(note.displayNumber)] "
                }
            }
            
            if let title = note.title, !title.isEmpty {
                result += title + ": "
            }
            
            result += note.content + "\n\n"
        }
        
        return result
    }
    
    /// Generate plain text glossary section
    private func generatePlainTextGlossarySection() -> String? {
        let projectID = project.id
        let descriptor = FetchDescriptor<GlossaryEntry>(
            predicate: #Predicate<GlossaryEntry> { entry in
                entry.project?.id == projectID
            },
            sortBy: [SortDescriptor(\.term)]
        )
        
        guard let entries = try? context.fetch(descriptor), !entries.isEmpty else {
            return nil
        }
        
        var result = "\n\n" + NSLocalizedString("backMatter.glossary.heading", comment: "Glossary") + "\n"
        result += String(repeating: "-", count: 40) + "\n\n"
        
        for entry in entries.sorted() {
            result += entry.term + " — " + entry.definition + "\n\n"
        }
        
        return result
    }
    
    /// Generate plain text bibliography section
    private func generatePlainTextBibliographySection() -> String? {
        let projectID = project.id
        let descriptor = FetchDescriptor<CitationEntry>(
            predicate: #Predicate<CitationEntry> { entry in
                entry.project?.id == projectID
            }
        )
        
        guard let citations = try? context.fetch(descriptor), !citations.isEmpty else {
            return nil
        }
        
        var result = "\n\n" + NSLocalizedString("backMatter.bibliography.heading", comment: "Bibliography") + "\n"
        result += String(repeating: "-", count: 40) + "\n\n"
        
        for citation in citations.sorted() {
            // Simple APA-style format
            let authors = citation.authors
            var authorText = ""
            
            if authors.isEmpty {
                authorText = NSLocalizedString("citation.unknownAuthor", comment: "Unknown Author")
            } else if authors.count == 1 {
                authorText = authors[0]
            } else if authors.count == 2 {
                authorText = "\(authors[0]) & \(authors[1])"
            } else {
                authorText = "\(authors[0]) et al."
            }
            
            result += authorText
            
            if let year = citation.year {
                result += " (\(year))."
            } else {
                result += "."
            }
            
            result += " " + citation.title + "."
            
            if let source = citation.source, !source.isEmpty {
                result += " " + source + "."
            }
            
            if let doi = citation.doi, !doi.isEmpty {
                result += " https://doi.org/\(doi)"
            } else if let url = citation.url, !url.isEmpty {
                result += " \(url)"
            }
            
            result += "\n\n"
        }
        
        return result
    }
    
    /// Generate plain text contributors section
    private func generatePlainTextContributorsSection() -> String? {
        let contributors = (project.contributorEntries ?? []).sorted()
        
        guard !contributors.isEmpty else { return nil }
        
        var result = "\n\n" + NSLocalizedString("backMatter.contributors.header", comment: "Contributors").uppercased() + "\n"
        result += String(repeating: "-", count: 40) + "\n\n"
        
        for contributor in contributors {
            result += contributor.displayName + "\n"
            if !contributor.biography.isEmpty {
                result += contributor.biography + "\n"
            }
            result += "\n"
        }
        
        return result
    }}