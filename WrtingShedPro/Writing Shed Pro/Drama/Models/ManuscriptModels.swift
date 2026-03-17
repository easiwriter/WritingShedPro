import Foundation
import SwiftData

// MARK: - ManuscriptSection

/// Represents a section in the assembled manuscript (Feature 029)
struct ManuscriptSection: Identifiable, Equatable {
    let id: UUID
    let title: String
    let sectionType: SectionType
    let sourceFolder: Folder?
    var files: [TextFile]
    let level: Int
    var startingPage: Int?
    
    enum SectionType: String, CaseIterable {
        case frontMatter
        case body
        case backMatter
        
        var localizedName: String {
            switch self {
            case .frontMatter:
                return NSLocalizedString("manuscript.section.frontMatter", comment: "Front Matter")
            case .body:
                return NSLocalizedString("manuscript.section.body", comment: "Body")
            case .backMatter:
                return NSLocalizedString("manuscript.section.backMatter", comment: "Back Matter")
            }
        }
        
        var sortOrder: Int {
            switch self {
            case .frontMatter: return 0
            case .body: return 1
            case .backMatter: return 2
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        sectionType: SectionType,
        sourceFolder: Folder? = nil,
        files: [TextFile] = [],
        level: Int = 1,
        startingPage: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.sectionType = sectionType
        self.sourceFolder = sourceFolder
        self.files = files
        self.level = level
        self.startingPage = startingPage
    }
    
    static func == (lhs: ManuscriptSection, rhs: ManuscriptSection) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - ManuscriptFootnote

/// Lightweight representation of a footnote in an assembled manuscript.
/// Unlike FootnoteModel (a SwiftData @Model), this is a plain struct that can be
/// stored in ManuscriptContent without requiring a model context.
struct ManuscriptFootnote {
    let attachmentID: UUID
    let text: String
    let number: Int
    /// Character position in the assembled manuscript string
    let characterPosition: Int
}

// MARK: - ManuscriptContent

/// Complete assembled manuscript content
struct ManuscriptContent {
    let attributedString: NSAttributedString
    let sections: [ManuscriptSection]
    var pageMap: [UUID: Int]
    let fileOffsets: [UUID: Int]
    var pageCount: Int
    
    /// Whether a front cover image page was inserted at the beginning
    var hasFrontCover: Bool
    /// Whether a back cover image page was appended at the end
    var hasBackCover: Bool
    /// Number of non-cover front matter files in the assembled content
    var frontMatterFileCount: Int
    /// Character length of all front matter content (excluding cover) in the assembled string,
    /// including inter-file form feeds. Used by the standard-path renderer to determine
    /// which pages should show roman numeral page numbers.
    var frontMatterCharacterLength: Int
    /// Footnotes collected from all assembled files, with character positions remapped
    /// to the assembled string. Used by PDF renderers when no single Version is available.
    var assembledFootnotes: [ManuscriptFootnote]
    
    /// Chunk indices (form-feed separated) whose content should be vertically centered.
    /// Used for front matter pages like Epigraph and Dedication.
    var verticallyCenteredChunkIndices: Set<Int>
    
    /// Pre-extracted cover image data (JPEG/PNG) for thread-safe PDF rendering.
    /// Loaded on the main thread to avoid SwiftData cross-thread access during background PDF generation.
    var frontCoverImageData: Data?
    var backCoverImageData: Data?
    
    /// Mapping of character offsets to collection/section names for header/footer {{Collection}} placeholder.
    /// Built on main thread from sections + fileOffsets so it's safe to pass to background rendering.
    /// Sorted by offset ascending.
    var fileCollectionMap: [(offset: Int, collectionName: String)] = []
    
    var wordCount: Int {
        let text = attributedString.string
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count
    }
    
    var characterCount: Int {
        let text = attributedString.string
        return text.filter { !$0.isWhitespace }.count
    }
    
    init(
        attributedString: NSAttributedString = NSAttributedString(),
        sections: [ManuscriptSection] = [],
        pageMap: [UUID: Int] = [:],
        fileOffsets: [UUID: Int] = [:],
        pageCount: Int = 0,
        hasFrontCover: Bool = false,
        hasBackCover: Bool = false,
        frontMatterFileCount: Int = 0,
        frontMatterCharacterLength: Int = 0,
        assembledFootnotes: [ManuscriptFootnote] = [],
        verticallyCenteredChunkIndices: Set<Int> = [],
        frontCoverImageData: Data? = nil,
        backCoverImageData: Data? = nil,
        fileCollectionMap: [(offset: Int, collectionName: String)] = []
    ) {
        self.attributedString = attributedString
        self.sections = sections
        self.pageMap = pageMap
        self.fileOffsets = fileOffsets
        self.pageCount = pageCount
        self.hasFrontCover = hasFrontCover
        self.hasBackCover = hasBackCover
        self.frontMatterFileCount = frontMatterFileCount
        self.frontMatterCharacterLength = frontMatterCharacterLength
        self.assembledFootnotes = assembledFootnotes
        self.verticallyCenteredChunkIndices = verticallyCenteredChunkIndices
        self.frontCoverImageData = frontCoverImageData
        self.backCoverImageData = backCoverImageData
        self.fileCollectionMap = fileCollectionMap
    }
    
    /// Build the fileCollectionMap from sections and fileOffsets.
    /// Must be called on the main thread while SwiftData models are accessible.
    /// For each body file, resolves the collection name from poetryCollections or prose sections,
    /// falling back to the ManuscriptSection title (e.g. chapter/act name for fiction).
    /// Front matter and back matter sections are excluded (no meaningful collection name).
    mutating func buildFileCollectionMap() {
        var map: [(offset: Int, collectionName: String)] = []
        for section in sections {
            // Skip front/back matter — those pages shouldn't show a collection name
            guard section.sectionType == .body else { continue }
            for file in section.files {
                guard let offset = fileOffsets[file.id] else { continue }
                let name = file.poetryCollections?.first?.name
                    ?? file.sections?.first?.name
                    ?? section.title
                map.append((offset: offset, collectionName: name))
            }
        }
        map.sort { $0.offset < $1.offset }
        fileCollectionMap = map
    }
}

// MARK: - ManuscriptSettings

/// Configuration for manuscript assembly
struct ManuscriptSettings: Codable, Equatable {
    var sectionBreakStyle: SectionBreakStyle = .pageBreak
    var includeSectionHeadings: Bool = true
    var includeFileTitles: Bool = true
    var footnoteNumbering: FootnoteNumberingStyle = .perFile
    /// Once the user explicitly curates Body Matter, assembly should honor that
    /// selection exactly and stop falling back to "all containers" heuristics.
    var useExplicitBodyMatter: Bool = false
    
    enum SectionBreakStyle: String, Codable, CaseIterable {
        case pageBreak
        case sectionMark
        case doubleSpace
        case none
        
        var localizedName: String {
            switch self {
            case .pageBreak:
                return NSLocalizedString("manuscript.break.pageBreak", comment: "Page Break")
            case .sectionMark:
                return NSLocalizedString("manuscript.break.sectionMark", comment: "Section Mark")
            case .doubleSpace:
                return NSLocalizedString("manuscript.break.doubleSpace", comment: "Double Space")
            case .none:
                return NSLocalizedString("manuscript.break.none", comment: "None")
            }
        }
    }
    
    enum FootnoteNumberingStyle: String, Codable, CaseIterable {
        case perFile
        case continuous
        case perSection
        
        var localizedName: String {
            switch self {
            case .perFile:
                return NSLocalizedString("manuscript.footnotes.perFile", comment: "Per File")
            case .continuous:
                return NSLocalizedString("manuscript.footnotes.continuous", comment: "Continuous")
            case .perSection:
                return NSLocalizedString("manuscript.footnotes.perSection", comment: "Per Section")
            }
        }
    }
}

// MARK: - AssemblyProgress

/// Progress tracking for manuscript assembly
struct AssemblyProgress {
    let totalFiles: Int
    var processedFiles: Int
    var phase: AssemblyPhase
    
    var progress: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(processedFiles) / Double(totalFiles)
    }
    
    enum AssemblyPhase: String {
        case loading
        case assembling
        case calculating
        case complete
        
        var localizedDescription: String {
            switch self {
            case .loading:
                return NSLocalizedString("manuscript.progress.loading", comment: "Loading files...")
            case .assembling:
                return NSLocalizedString("manuscript.progress.assembling", comment: "Assembling content...")
            case .calculating:
                return NSLocalizedString("manuscript.progress.calculating", comment: "Calculating layout...")
            case .complete:
                return NSLocalizedString("manuscript.progress.complete", comment: "Complete")
            }
        }
    }
    
    init(totalFiles: Int = 0, processedFiles: Int = 0, phase: AssemblyPhase = .loading) {
        self.totalFiles = totalFiles
        self.processedFiles = processedFiles
        self.phase = phase
    }
}

// MARK: - AssemblyError

/// Errors that can occur during manuscript assembly
enum AssemblyError: LocalizedError {
    case noFilesFound
    case fileLoadFailed(String)
    case layoutCalculationFailed
    case exportFailed(String)
    case noPageSetup
    
    var errorDescription: String? {
        switch self {
        case .noFilesFound:
            return NSLocalizedString("manuscript.error.noFiles", comment: "No files found")
        case .fileLoadFailed(let filename):
            return String(format: NSLocalizedString("manuscript.error.loadFailed", comment: "Load failed"), filename)
        case .layoutCalculationFailed:
            return NSLocalizedString("manuscript.error.layoutFailed", comment: "Layout failed")
        case .exportFailed(let format):
            return String(format: NSLocalizedString("manuscript.error.exportFailed", comment: "Export failed"), format)
        case .noPageSetup:
            return NSLocalizedString("manuscript.error.noPageSetup", comment: "No page setup")
        }
    }
}

// MARK: - ExportFormat

/// Available export formats for manuscripts
enum ExportFormat: String, CaseIterable, Identifiable {
    case pdf
    case rtf
    case plainText
    case word
    case html
    case epub
    case markdown
    case fountain
    case finalDraft
    
    var id: String { rawValue }
    
    var fileExtension: String {
        switch self {
        case .pdf: return "pdf"
        case .rtf: return "rtf"
        case .plainText: return "txt"
        case .word: return "docx"
        case .html: return "html"
        case .epub: return "epub"
        case .markdown: return "md"
        case .fountain: return "fountain"
        case .finalDraft: return "fdx"
        }
    }
    
    var localizedName: String {
        switch self {
        case .pdf:
            return NSLocalizedString("export.format.pdf", comment: "PDF Document")
        case .rtf:
            return NSLocalizedString("export.format.rtf", comment: "Rich Text Format")
        case .plainText:
            return NSLocalizedString("export.format.plainText", comment: "Plain Text")
        case .word:
            return NSLocalizedString("export.format.word", comment: "Word Document")
        case .html:
            return NSLocalizedString("export.format.html", comment: "HTML (Web page)")
        case .epub:
            return NSLocalizedString("export.format.epub", comment: "EPUB (eBook)")
        case .markdown:
            return NSLocalizedString("export.format.markdown", comment: "Markdown")
        case .fountain:
            return NSLocalizedString("export.format.fountain", comment: "Fountain (Screenplay)")
        case .finalDraft:
            return NSLocalizedString("export.format.finalDraft", comment: "Final Draft (.fdx)")
        }
    }
    
    var mimeType: String {
        switch self {
        case .pdf: return "application/pdf"
        case .rtf: return "application/rtf"
        case .plainText: return "text/plain"
        case .word: return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case .html: return "text/html"
        case .epub: return "application/epub+zip"
        case .markdown: return "text/markdown"
        case .fountain: return "text/plain"
        case .finalDraft: return "application/xml"
        }
    }
    
    var icon: String {
        switch self {
        case .pdf: return "doc.fill"
        case .rtf: return "doc.richtext"
        case .plainText: return "doc.text"
        case .word: return "doc"
        case .html: return "chevron.left.slash.chevron.right"
        case .epub: return "book"
        case .markdown: return "number.square"
        case .fountain: return "doc.text"
        case .finalDraft: return "doc.badge.gearshape"
        }
    }
}

// MARK: - ExportOptions

/// Options for manuscript export
struct ExportOptions: Equatable {
    var format: ExportFormat = .pdf
    var includeFrontMatter: Bool = true
    var includeBody: Bool = true
    var includeBackMatter: Bool = true
    var includeTableOfContents: Bool = true
    var includeTitlePage: Bool = true
    var filename: String = "Manuscript"
    
    // MARK: - Back Matter Reference Options (Feature 029)
    
    /// Include Notes/Endnotes section in back matter
    var includeNotes: Bool = true
    
    /// Include Glossary section in back matter
    var includeGlossary: Bool = true
    
    /// Include Bibliography/Works Cited section in back matter
    var includeBibliography: Bool = true
    
    /// Include Index section in back matter (PDF only - requires page numbers)
    var includeIndex: Bool = true
}
