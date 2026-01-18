//
//  ReferenceModels.swift
//  Writing Shed Pro
//
//  Feature 029: Back Matter Reference System
//  Created by GitHub Copilot on 15/01/2026.
//
//  SwiftData models for Notes, Glossary, Citations, and Index entries
//  All models comply with CloudKit requirements (optional or default values, no unique constraints)
//

import Foundation
import SwiftData

// MARK: - Reference Metadata (for RTF Serialization)

/// Stores metadata about a single reference within a document
/// Used to reconstruct ReferenceAttachment instances after RTF deserialization
/// RTF format doesn't preserve custom NSTextAttachment subclasses, so we store
/// the reference information separately and restore it on deserialization
struct ReferenceEntry: Codable {
    let type: ReferenceType
    let entryID: UUID
    let displayText: String
    let displayNumber: Int
}

/// Collection of reference metadata for all references in a version
/// Stored in Version.referenceMetadataData as JSON-encoded data
struct ReferenceMetadata: Codable {
    var references: [ReferenceEntry] = []
    
    /// Add a reference entry
    mutating func add(type: ReferenceType, entryID: UUID, displayText: String, displayNumber: Int = 0) {
        references.append(ReferenceEntry(type: type, entryID: entryID, displayText: displayText, displayNumber: displayNumber))
    }
    
    /// Remove all references to a specific entry
    mutating func removeReferences(to entryID: UUID) {
        references.removeAll { $0.entryID == entryID }
    }
    
    /// Encode to Data for storage
    func encode() -> Data? {
        let encoder = JSONEncoder()
        return try? encoder.encode(self)
    }
    
    /// Decode from Data
    static func decode(_ data: Data) -> ReferenceMetadata? {
        let decoder = JSONDecoder()
        return try? decoder.decode(ReferenceMetadata.self, from: data)
    }
}

// MARK: - Reference Type Enum

/// Types of references that can be embedded in document text
enum ReferenceType: String, Codable, CaseIterable {
    case note       // [Note n] - General notes
    case endnote    // [n] - Superscript endnotes
    case citation   // [Author, Year] - Bibliography citations
    case glossary   // Styled term - Glossary definitions
    case index      // Invisible marker - Index entries
    case figure     // [Fig n] - Figure references
    case table      // [Table n] - Table references
    
    /// Display format for the reference marker
    var markerFormat: String {
        switch self {
        case .note: return "[Note %d]"
        case .endnote: return "[%d]"
        case .citation: return "[%@, %d]"  // Author, Year
        case .glossary: return "%@"  // Term itself (styled)
        case .index: return ""  // Invisible
        case .figure: return "[Fig %d]"
        case .table: return "[Table %d]"
        }
    }
    
    /// Plain text export format (for non-PDF/RTF exports)
    var plainTextFormat: String {
        switch self {
        case .note: return "(see Note %d)"
        case .endnote: return "(see Note %d)"
        case .citation: return "(%@, %d)"  // Author, Year
        case .glossary: return "%@ (see Glossary)"
        case .index: return ""  // Stripped in plain text
        case .figure: return "(see Figure %d)"
        case .table: return "(see Table %d)"
        }
    }
}

// MARK: - Reference Entry Protocol

/// Protocol for all reference entry types
/// Provides common interface for tracking and management
protocol ReferenceEntryProtocol: Identifiable {
    var id: UUID { get }
    var referenceCount: Int { get set }
    var createdAt: Date { get }
    var modifiedAt: Date { get set }
}

// MARK: - Note Entry Model

/// Represents a note that can be referenced in document text
/// Used for both general notes ([Note n]) and endnotes ([n])
@Model
final class NoteEntry {
    /// Unique identifier
    var id: UUID = UUID()
    
    /// The Project this note belongs to
    var project: Project?
    
    /// Note content (supports rich text, stored as RTF data)
    var content: String = ""
    
    /// Formatted content as RTF data (optional)
    var formattedContentData: Data?
    
    /// Whether this is an endnote (superscript [n]) or general note ([Note n])
    var isEndnote: Bool = false
    
    /// Display number (assigned based on order of appearance)
    var displayNumber: Int = 0
    
    /// Number of references to this note in the document
    var referenceCount: Int = 0
    
    /// List of file IDs that contain references to this note (for efficient deletion)
    var referencingFileIDs: [UUID] = []
    
    /// When the note was created
    var createdAt: Date = Date()
    
    /// When the note was last modified
    var modifiedAt: Date = Date()
    
    /// User-provided title (optional)
    var title: String?
    
    /// User-supplied tag for the note (e.g., "timeline-1", "character-insight")
    /// Used instead of auto-numbering to avoid renumbering issues
    var tag: String?
    
    init(
        id: UUID = UUID(),
        project: Project? = nil,
        content: String = "",
        isEndnote: Bool = false,
        displayNumber: Int = 0,
        title: String? = nil,
        tag: String? = nil
    ) {
        self.id = id
        self.project = project
        self.content = content
        self.isEndnote = isEndnote
        self.displayNumber = displayNumber
        self.title = title
        self.tag = tag
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
    
    /// Update the note content
    func updateContent(_ newContent: String) {
        content = newContent
        modifiedAt = Date()
    }
    
    /// Increment reference count (when marker is added or pasted)
    func incrementReferenceCount() {
        referenceCount += 1
        modifiedAt = Date()
    }
    
    /// Decrement reference count (when marker is removed)
    func decrementReferenceCount() {
        referenceCount = max(0, referenceCount - 1)
        modifiedAt = Date()
    }
    
    /// Check if this note is orphaned (no references)
    var isOrphaned: Bool {
        referenceCount == 0
    }
    
    /// Format the inline marker for this note
    var inlineMarker: String {
        if isEndnote {
            return "[\(displayNumber)]"
        } else {
            return "[Note \(displayNumber)]"
        }
    }
    
    /// Format for plain text export
    var plainTextMarker: String {
        if isEndnote {
            return "(see Note \(displayNumber))"
        } else {
            return "(see Note \(displayNumber))"
        }
    }
}

extension NoteEntry: ReferenceEntryProtocol {}

// MARK: - Glossary Entry Model

/// Represents a glossary term with definition
@Model
final class GlossaryEntry {
    /// Unique identifier
    var id: UUID = UUID()
    
    /// The Project this glossary entry belongs to
    var project: Project?
    
    /// The term being defined
    var term: String = ""
    
    /// Definition of the term
    var definition: String = ""
    
    /// Optional citation reference for academic use
    var citation: CitationEntry?
    
    /// Number of references to this term in the document
    var referenceCount: Int = 0
    
    /// When the entry was created
    var createdAt: Date = Date()
    
    /// When the entry was last modified
    var modifiedAt: Date = Date()
    
    init(
        id: UUID = UUID(),
        project: Project? = nil,
        term: String = "",
        definition: String = "",
        citation: CitationEntry? = nil
    ) {
        self.id = id
        self.project = project
        self.term = term
        self.definition = definition
        self.citation = citation
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
    
    /// Update the definition
    func updateDefinition(_ newDefinition: String) {
        definition = newDefinition
        modifiedAt = Date()
    }
    
    /// Increment reference count (when term is linked in text)
    func incrementReferenceCount() {
        referenceCount += 1
        modifiedAt = Date()
    }
    
    /// Decrement reference count (when link is removed)
    func decrementReferenceCount() {
        referenceCount = max(0, referenceCount - 1)
        modifiedAt = Date()
    }
    
    /// Check if this entry is orphaned (no references)
    var isOrphaned: Bool {
        referenceCount == 0
    }
    
    /// The term is displayed inline (styled, no brackets)
    var inlineMarker: String {
        term
    }
    
    /// Format for plain text export
    var plainTextMarker: String {
        "\(term) (see Glossary)"
    }
}

extension GlossaryEntry: ReferenceEntryProtocol {}

// MARK: - Citation Entry Model

/// Represents a bibliography/citation entry
/// Format-agnostic storage for APA, MLA, Chicago, etc.
@Model
final class CitationEntry {
    /// Unique identifier
    var id: UUID = UUID()
    
    /// The Project this citation belongs to
    var project: Project?
    
    /// Inverse relationship: Glossary entries that reference this citation
    /// Required by CloudKit for relationship integrity
    @Relationship(inverse: \GlossaryEntry.citation)
    var glossaryEntries: [GlossaryEntry]?
    
    // MARK: - Core Citation Fields (format-agnostic)
    
    /// List of author names
    /// Stored as JSON-encoded array for CloudKit compatibility
    var authorsData: Data?
    
    /// Publication year
    var year: Int?
    
    /// Title of the work
    var title: String = ""
    
    /// Source (journal name, publisher, website, etc.)
    var source: String?
    
    /// URL for web sources
    var url: String?
    
    /// DOI (Digital Object Identifier)
    var doi: String?
    
    /// Volume number (for journals)
    var volume: String?
    
    /// Issue number (for journals)
    var issue: String?
    
    /// Page range
    var pages: String?
    
    /// Edition (for books)
    var edition: String?
    
    /// City of publication
    var city: String?
    
    /// Access date (for web sources)
    var accessDate: Date?
    
    /// Type of source (article, book, website, etc.)
    var sourceTypeRaw: String?
    
    /// Number of references to this citation in the document
    var referenceCount: Int = 0
    
    /// When the citation was created
    var createdAt: Date = Date()
    
    /// When the citation was last modified
    var modifiedAt: Date = Date()
    
    /// Computed property for authors array
    var authors: [String] {
        get {
            guard let data = authorsData,
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            authorsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    /// Source type enum
    enum SourceType: String, Codable, CaseIterable {
        case article    // Journal article
        case book       // Book
        case chapter    // Book chapter
        case website    // Website/web page
        case newspaper  // Newspaper article
        case magazine   // Magazine article
        case report     // Technical report
        case thesis     // Thesis/dissertation
        case conference // Conference paper
        case other      // Other source type
        
        var displayName: String {
            switch self {
            case .article: return NSLocalizedString("citation.type.article", comment: "Article")
            case .book: return NSLocalizedString("citation.type.book", comment: "Book")
            case .chapter: return NSLocalizedString("citation.type.chapter", comment: "Book Chapter")
            case .website: return NSLocalizedString("citation.type.website", comment: "Website")
            case .newspaper: return NSLocalizedString("citation.type.newspaper", comment: "Newspaper")
            case .magazine: return NSLocalizedString("citation.type.magazine", comment: "Magazine")
            case .report: return NSLocalizedString("citation.type.report", comment: "Report")
            case .thesis: return NSLocalizedString("citation.type.thesis", comment: "Thesis")
            case .conference: return NSLocalizedString("citation.type.conference", comment: "Conference")
            case .other: return NSLocalizedString("citation.type.other", comment: "Other")
            }
        }
    }
    
    var sourceType: SourceType {
        get {
            guard let raw = sourceTypeRaw else { return .article }
            return SourceType(rawValue: raw) ?? .article
        }
        set {
            sourceTypeRaw = newValue.rawValue
        }
    }
    
    init(
        id: UUID = UUID(),
        project: Project? = nil,
        authors: [String] = [],
        year: Int? = nil,
        title: String = "",
        source: String? = nil,
        url: String? = nil,
        doi: String? = nil,
        sourceType: SourceType = .article
    ) {
        self.id = id
        self.project = project
        self.authorsData = try? JSONEncoder().encode(authors)
        self.year = year
        self.title = title
        self.source = source
        self.url = url
        self.doi = doi
        self.sourceTypeRaw = sourceType.rawValue
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
    
    /// Increment reference count
    func incrementReferenceCount() {
        referenceCount += 1
        modifiedAt = Date()
    }
    
    /// Decrement reference count
    func decrementReferenceCount() {
        referenceCount = max(0, referenceCount - 1)
        modifiedAt = Date()
    }
    
    /// Check if this citation is orphaned (no references)
    var isOrphaned: Bool {
        referenceCount == 0
    }
    
    /// Primary author's last name (for inline citations)
    var primaryAuthorLastName: String {
        guard let firstAuthor = authors.first else { return "Unknown" }
        // Try to extract last name (assumes "First Last" or "Last, First" format)
        if firstAuthor.contains(",") {
            return String(firstAuthor.split(separator: ",").first ?? "Unknown")
        } else {
            return String(firstAuthor.split(separator: " ").last ?? "Unknown")
        }
    }
    
    /// Format the inline marker [Author, Year]
    var inlineMarker: String {
        if authors.count > 2 {
            return "[\(primaryAuthorLastName) et al., \(year ?? 0)]"
        } else if authors.count == 2 {
            let secondAuthor = authors[1]
            let secondLastName: String
            if secondAuthor.contains(",") {
                secondLastName = String(secondAuthor.split(separator: ",").first ?? "")
            } else {
                secondLastName = String(secondAuthor.split(separator: " ").last ?? "")
            }
            return "[\(primaryAuthorLastName) & \(secondLastName), \(year ?? 0)]"
        } else {
            return "[\(primaryAuthorLastName), \(year ?? 0)]"
        }
    }
    
    /// Format for plain text export
    var plainTextMarker: String {
        if authors.count > 2 {
            return "(\(primaryAuthorLastName) et al., \(year ?? 0))"
        } else if authors.count == 2 {
            let secondAuthor = authors[1]
            let secondLastName: String
            if secondAuthor.contains(",") {
                secondLastName = String(secondAuthor.split(separator: ",").first ?? "")
            } else {
                secondLastName = String(secondAuthor.split(separator: " ").last ?? "")
            }
            return "(\(primaryAuthorLastName) & \(secondLastName), \(year ?? 0))"
        } else {
            return "(\(primaryAuthorLastName), \(year ?? 0))"
        }
    }
}

extension CitationEntry: ReferenceEntryProtocol {}

// MARK: - Index Entry Model

/// Represents an index entry with optional sub-entries
@Model
final class IndexEntry {
    /// Unique identifier
    var id: UUID = UUID()
    
    /// The Project this index entry belongs to
    var project: Project?
    
    /// The keyword or phrase for this index entry
    var keyword: String = ""
    
    /// Parent entry for sub-entries (e.g., "Dogs" under "Animals")
    var parentEntry: IndexEntry?
    
    /// Child entries (inverse of parentEntry)
    @Relationship(deleteRule: .cascade, inverse: \IndexEntry.parentEntry)
    var childEntries: [IndexEntry]? = []
    
    /// Number of references to this entry in the document
    var referenceCount: Int = 0
    
    /// When the entry was created
    var createdAt: Date = Date()
    
    /// When the entry was last modified
    var modifiedAt: Date = Date()
    
    /// Page numbers where this entry appears (calculated at export time)
    /// Stored as JSON-encoded array for CloudKit compatibility
    var pageNumbersData: Data?
    
    /// Computed property for page numbers
    var pageNumbers: [Int] {
        get {
            guard let data = pageNumbersData,
                  let decoded = try? JSONDecoder().decode([Int].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            pageNumbersData = try? JSONEncoder().encode(newValue)
        }
    }
    
    init(
        id: UUID = UUID(),
        project: Project? = nil,
        keyword: String = "",
        parentEntry: IndexEntry? = nil
    ) {
        self.id = id
        self.project = project
        self.keyword = keyword
        self.parentEntry = parentEntry
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
    
    /// Update the keyword
    func updateKeyword(_ newKeyword: String) {
        keyword = newKeyword
        modifiedAt = Date()
    }
    
    /// Increment reference count
    func incrementReferenceCount() {
        referenceCount += 1
        modifiedAt = Date()
    }
    
    /// Decrement reference count
    func decrementReferenceCount() {
        referenceCount = max(0, referenceCount - 1)
        modifiedAt = Date()
    }
    
    /// Check if this entry is orphaned (no references)
    var isOrphaned: Bool {
        referenceCount == 0
    }
    
    /// Check if this is a top-level entry (no parent)
    var isTopLevel: Bool {
        parentEntry == nil
    }
    
    /// Get the full hierarchical path (e.g., "Animals > Dogs > Breeds")
    var fullPath: String {
        if let parent = parentEntry {
            return "\(parent.fullPath) > \(keyword)"
        }
        return keyword
    }
    
    /// Index entries have invisible markers in the document
    var inlineMarker: String {
        ""  // Invisible
    }
    
    /// No plain text marker for index (stripped in plain text export)
    var plainTextMarker: String {
        ""
    }
    
    /// Format page numbers for display (e.g., "1, 3, 5-7, 12")
    var formattedPageNumbers: String {
        guard !pageNumbers.isEmpty else { return "" }
        
        let sorted = pageNumbers.sorted()
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
                    result.append("\(rangeStart)-\(rangeEnd)")
                }
                rangeStart = sorted[i]
                rangeEnd = sorted[i]
            }
        }
        
        // Add the last range
        if rangeStart == rangeEnd {
            result.append("\(rangeStart)")
        } else {
            result.append("\(rangeStart)-\(rangeEnd)")
        }
        
        return result.joined(separator: ", ")
    }
}

extension IndexEntry: ReferenceEntryProtocol {}

// MARK: - Comparable Extensions

extension NoteEntry: Comparable {
    static func < (lhs: NoteEntry, rhs: NoteEntry) -> Bool {
        lhs.displayNumber < rhs.displayNumber
    }
}

extension GlossaryEntry: Comparable {
    static func < (lhs: GlossaryEntry, rhs: GlossaryEntry) -> Bool {
        lhs.term.localizedCaseInsensitiveCompare(rhs.term) == .orderedAscending
    }
}

extension CitationEntry: Comparable {
    static func < (lhs: CitationEntry, rhs: CitationEntry) -> Bool {
        // Sort by primary author, then year
        let authorCompare = lhs.primaryAuthorLastName.localizedCaseInsensitiveCompare(rhs.primaryAuthorLastName)
        if authorCompare != .orderedSame {
            return authorCompare == .orderedAscending
        }
        return (lhs.year ?? 0) < (rhs.year ?? 0)
    }
}

extension IndexEntry: Comparable {
    static func < (lhs: IndexEntry, rhs: IndexEntry) -> Bool {
        lhs.keyword.localizedCaseInsensitiveCompare(rhs.keyword) == .orderedAscending
    }
}
