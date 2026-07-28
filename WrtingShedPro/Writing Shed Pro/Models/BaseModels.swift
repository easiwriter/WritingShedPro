import Foundation
import SwiftData
import UIKit

/// Project source status for development re-import
enum ProjectStatus: String, Codable {
    case legacy  // Imported from original Writing Shed
    case pro     // Created in Writing Shed Pro
}

/// Workflow status for text files (Poetry, Fiction, Drama projects)
/// Replaces the old folder-based workflow (Draft, Ready, etc.)
enum WorkflowStatus: String, Codable, CaseIterable {
    case draft      // Work in progress
    case ready      // Ready for submission
    case setAside   // On hold / archived
    case published  // Accepted and/or published
    
    /// Localized display name for the status
    var localizedName: String {
        switch self {
        case .draft:
            return NSLocalizedString("workflow.status.draft", comment: "Draft status")
        case .ready:
            return NSLocalizedString("workflow.status.ready", comment: "Ready status")
        case .setAside:
            return NSLocalizedString("workflow.status.setAside", comment: "Set Aside status")
        case .published:
            return NSLocalizedString("workflow.status.published", comment: "Published status")
        }
    }
    
    /// System image name for the status
    var systemImage: String {
        switch self {
        case .draft:
            return "pencil.circle.fill"
        case .ready:
            return "checkmark.circle.fill"
        case .setAside:
            return "archivebox.fill"
        case .published:
            return "star.circle.fill"
        }
    }
    
    /// Color associated with the status
    var color: UIColor {
        switch self {
        case .draft:
            return .systemBlue
        case .ready:
            return .systemGreen
        case .setAside:
            return .systemRed
        case .published:
            return .label  // Black in light mode, white in dark mode
        }
    }
}

/// Content type for text files
/// Determines editing mode and available features
enum FileContentType: String, Codable, CaseIterable {
    case richText   // Default rich text editing with formatting
    case markdown   // Plain text markdown editing with preview
    
    /// Localized display name for the content type
    var localizedName: String {
        switch self {
        case .richText:
            return NSLocalizedString("contentType.richText", comment: "Rich Text")
        case .markdown:
            return NSLocalizedString("contentType.markdown", comment: "Markdown")
        }
    }
    
    /// System image for the content type
    var systemImage: String {
        switch self {
        case .richText:
            return "richtext.page.fill"
        case .markdown:
            return "number.square"
        }
    }
    
    /// Short description of the content type
    var description: String {
        switch self {
        case .richText:
            return NSLocalizedString("contentType.richText.description", comment: "Formatted text with styles")
        case .markdown:
            return NSLocalizedString("contentType.markdown.description", comment: "Plain text with markdown syntax")
        }
    }
}

@Model
final class Project {
        // Trash support
        var isTrashed: Bool = false
        var deletedDate: Date? = nil
    var id: UUID = UUID()
    var name: String?
    var typeRaw: String?
    var statusRaw: String? // "legacy" or "pro"
    var creationDate: Date?
    var modifiedDate: Date?
    var details: String?
    var notes: String?
    var author: String?
    var userOrder: Int?
    @Relationship(deleteRule: .cascade, inverse: \Folder.project) var folders: [Folder]?
    var trashedItems: [TrashItem]? // Inverse for TrashItem.project
    
    // Feature 008b: Publication Management
    @Relationship(deleteRule: .cascade, inverse: \Publication.project) var publications: [Publication]? = []
    @Relationship(deleteRule: .cascade, inverse: \Submission.project) var submissions: [Submission]? = []
    @Relationship(deleteRule: .cascade, inverse: \SubmittedFile.project) var submittedFiles: [SubmittedFile]? = []
    
    // Style sheet reference (Phase 5)
    var styleSheet: StyleSheet?
    
    // Page setup reference (per-project)
    @Relationship(deleteRule: .cascade)
    var pageSetup: PageSetup?
    
    // Feature 022: Smart Fiction Creation
    var fictionClassRaw: String?  // "novel" or "shortFiction"
    var useMonomyth: Bool = false  // Legacy - use storyStructureRaw instead
    var storyStructureRaw: String?  // StoryStructure raw value
    
    // Feature 023: Smart Drama Creation
    var dramaScriptTypeRaw: String?  // "film" or "stage"
    
    // Feature 029: Manuscript Assembly
    var manuscriptSettingsData: Data?
    var tocSettingsData: Data?
    
    // Feature 029: Back Matter References
    @Relationship(deleteRule: .cascade, inverse: \NoteEntry.project)
    var noteEntries: [NoteEntry]? = []
    
    @Relationship(deleteRule: .cascade, inverse: \GlossaryEntry.project)
    var glossaryEntries: [GlossaryEntry]? = []
    
    @Relationship(deleteRule: .cascade, inverse: \ReferenceEntry.project)
    var referenceEntries: [ReferenceEntry]? = []
    
    @Relationship(deleteRule: .cascade, inverse: \CitationEntry.project)
    var citationEntries: [CitationEntry]? = []
    
    @Relationship(deleteRule: .cascade, inverse: \IndexEntry.project)
    var indexEntries: [IndexEntry]? = []
    
    @Relationship(deleteRule: .cascade, inverse: \ContributorEntry.project)
    var contributorEntries: [ContributorEntry]? = []
    
    /// Display order for contributor names: true = "Surname, Forename", false = "Forename Surname"
    var contributorDisplaySurnameFirst: Bool = true
    
    /// Display layout for contributors: true = continuous paragraph, false = separate rows
    var contributorDisplayRunTogether: Bool = false
    
    /// Style name for contributor entries (references a TextStyleModel name in the project's stylesheet)
    var contributorBodyStyleName: String = "body"
    
    /// Style name for front/back matter section headings (references a TextStyleModel name)
    /// Default is Title 1 (UICTFontTextStyleTitle1)
    var matterHeadingStyleName: String = "UICTFontTextStyleTitle1"
    
    /// Style name for front/back matter body text (references a TextStyleModel name)
    /// Default is Body (UICTFontTextStyleBody)
    var matterBodyStyleName: String = "UICTFontTextStyleBody"
    
    // Fiction relationships
    @Relationship(deleteRule: .cascade, inverse: \StoryScene.project)
    var scenes: [StoryScene]? = []
    
    @Relationship(deleteRule: .cascade, inverse: \Chapter.project)
    var chapters: [Chapter]? = []
    
    // Drama relationships
    @Relationship(deleteRule: .cascade, inverse: \Act.project)
    var acts: [Act]? = []
    
    // Prose relationships
    @Relationship(deleteRule: .cascade, inverse: \ProseSection.project)
    var sections: [ProseSection]? = []
    
    // Feature 036: Poetry Collections
    @Relationship(deleteRule: .cascade, inverse: \PoetryCollection.project)
    var poetryCollections: [PoetryCollection]? = []
    
    // Feature 036: Verse Novel Books
    @Relationship(deleteRule: .cascade, inverse: \Book.project)
    var books: [Book]? = []
    
    @Relationship(deleteRule: .cascade, inverse: \Character.project)
    var characters: [Character]? = []
    
    @Relationship(deleteRule: .cascade, inverse: \Location.project)
    var locations: [Location]? = []
    
    @Relationship(deleteRule: .cascade, inverse: \PlotElement.project)
    var plotElements: [PlotElement]? = []
    
    var fictionClass: FictionClass? {
        get {
            guard let raw = fictionClassRaw else { return nil }
            return FictionClass(rawValue: raw)
        }
        set {
            fictionClassRaw = newValue?.rawValue
        }
    }
    
    /// Story structure for fiction/drama projects
    /// Migrates legacy useMonomyth property to new StoryStructure
    var storyStructure: StoryStructure {
        get {
            // If we have a stored value, use it
            if let raw = storyStructureRaw, let structure = StoryStructure(rawValue: raw) {
                return structure
            }
            // Migrate from legacy useMonomyth
            if useMonomyth {
                return .monomythVogler
            }
            return .freeform
        }
        set {
            storyStructureRaw = newValue.rawValue
            // Keep useMonomyth in sync for backward compatibility
            useMonomyth = newValue.usesMonomyth
        }
    }
    
    var type: ProjectType {
        get {
            guard let typeRaw = typeRaw, let projectType = ProjectType(rawValue: typeRaw) else {
                // Handle legacy "blank" and "generalPurpose" values
                if typeRaw == "blank" || typeRaw == "generalPurpose" {
                    return .prose
                }
                return .prose
            }
            return projectType
        }
        set {
            typeRaw = newValue.rawValue
        }
    }
    
    var status: ProjectStatus {
        get {
            guard let statusRaw = statusRaw, let projectStatus = ProjectStatus(rawValue: statusRaw) else {
                return .pro // Default to .pro for existing projects
            }
            return projectStatus
        }
        set {
            statusRaw = newValue.rawValue
        }
    }
    
    init(name: String?, type: ProjectType = ProjectType.prose, creationDate: Date? = Date(), details: String? = nil, notes: String? = nil, userOrder: Int? = nil, styleSheet: StyleSheet? = nil) {
        self.name = name
        self.typeRaw = type.rawValue
        self.statusRaw = ProjectStatus.pro.rawValue // Default to .pro
        self.creationDate = creationDate
        self.modifiedDate = creationDate
        self.details = details
        self.notes = notes
        self.userOrder = userOrder
        
        // Note: Page setup is now global (stored in UserDefaults), not per-project
    }
    
    // MARK: - Manuscript Settings (Feature 029)
    
    /// Decoded manuscript settings for assembly configuration
    var manuscriptSettings: ManuscriptSettings {
        get {
            guard let data = manuscriptSettingsData else { return ManuscriptSettings() }
            return (try? JSONDecoder().decode(ManuscriptSettings.self, from: data)) ?? ManuscriptSettings()
        }
        set {
            manuscriptSettingsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    // MARK: - Folder Finding Helpers
    
    /// Safely check if a folder is valid (not invalidated/deleted)
    private func isFolderValid(_ folder: Folder) -> Bool {
        // Accessing the id property on an invalidated object will cause a crash
        // We use a workaround: check if we can read a required property
        // Note: This isn't foolproof but helps catch some cases
        return folder.id.uuidString.count > 0
    }
    
    /// Find the Back Matter folder for this project.
    /// Checks both root-level folders (legacy) and Manuscript subfolder (modern structure).
    /// Note: Returns nil if folder objects are invalidated (deleted from store).
    func findBackMatterFolder() -> Folder? {
        guard let allFolders = folders, !allFolders.isEmpty else { return nil }
        
        // First try: Back Matter folder at project level (legacy projects)
        for folder in allFolders {
            // Check folder name safely - if name is nil, skip
            guard let folderName = folder.name else { continue }
            if folderName == "Back Matter" || folderName == NSLocalizedString("folder.backMatter", comment: "") {
                return folder
            }
        }
        
        // Second try: Back Matter folder inside Manuscript (modern structure)
        for folder in allFolders {
            guard let folderName = folder.name, folderName == "Manuscript" else { continue }
            guard let subfolders = folder.folders, !subfolders.isEmpty else { continue }
            for subfolder in subfolders {
                guard let subfolderName = subfolder.name else { continue }
                if subfolderName == "Back Matter" || subfolderName == NSLocalizedString("folder.backMatter", comment: "") {
                    return subfolder
                }
            }
        }
        return nil
    }
    
    /// Find the Front Matter folder for this project.
    /// Checks both root-level folders (legacy) and Manuscript subfolder (modern structure).
    func findFrontMatterFolder() -> Folder? {
        guard let allFolders = folders, !allFolders.isEmpty else { return nil }
        
        // First try: Front Matter folder at project level (legacy projects)
        for folder in allFolders {
            guard let folderName = folder.name else { continue }
            if folderName == "Front Matter" || folderName == NSLocalizedString("folder.frontMatter", comment: "") {
                return folder
            }
        }
        
        // Second try: Front Matter folder inside Manuscript (modern structure)
        for folder in allFolders {
            guard let folderName = folder.name, folderName == "Manuscript" else { continue }
            guard let subfolders = folder.folders, !subfolders.isEmpty else { continue }
            for subfolder in subfolders {
                guard let subfolderName = subfolder.name else { continue }
                if subfolderName == "Front Matter" || subfolderName == NSLocalizedString("folder.frontMatter", comment: "") {
                    return subfolder
                }
            }
        }
        return nil
    }
    
    /// Find the Manuscript folder for this project.
    func findManuscriptFolder() -> Folder? {
        guard let allFolders = folders, !allFolders.isEmpty else { return nil }
        for folder in allFolders {
            if folder.name == "Manuscript" {
                return folder
            }
        }
        return nil
    }
}

enum ProjectType: String, Codable, CaseIterable {
    case prose, poetry, fiction, drama
    
    // Backward compatibility: decode legacy values
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "blank", "generalPurpose":
            self = .prose
        case "novel", "shortStory":
            self = .fiction
        case "script":
            self = .drama
        default:
            self = ProjectType(rawValue: rawValue) ?? .prose
        }
    }
}

@Model
final class Folder {
    var id: UUID = UUID()
    var name: String?
    var userOrder: Int?  // For user-defined ordering in Prose projects
    @Relationship(deleteRule: .cascade) var folders: [Folder]?  // Inverse is parentFolder
    @Relationship(deleteRule: .cascade) var textFiles: [TextFile]?  // Inverse is TextFile.parentFolder
    @Relationship(inverse: \Folder.folders) var parentFolder: Folder?  // Inverse is folders
    var project: Project?
    var trashedItems: [TrashItem]? // Inverse for TrashItem.originalFolder
    
    // Front Matter and Back Matter settings (stored as JSON Data)
    var frontMatterSettingsData: Data?
    var backMatterSettingsData: Data?
    
    // Drama-specific Front Matter and Back Matter settings
    var dramaFrontMatterSettingsData: Data?
    var dramaBackMatterSettingsData: Data?
    
    /// Front matter settings - which items are enabled (for Fiction projects)
    var frontMatterSettings: FrontMatterSettings {
        get {
            guard let data = frontMatterSettingsData else { return FrontMatterSettings() }
            return (try? JSONDecoder().decode(FrontMatterSettings.self, from: data)) ?? FrontMatterSettings()
        }
        set {
            frontMatterSettingsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    /// Back matter settings - which items are enabled (for Fiction projects)
    var backMatterSettings: BackMatterSettings {
        get {
            guard let data = backMatterSettingsData else { return BackMatterSettings() }
            return (try? JSONDecoder().decode(BackMatterSettings.self, from: data)) ?? BackMatterSettings()
        }
        set {
            backMatterSettingsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    /// Drama front matter settings - which items are enabled
    var dramaFrontMatterSettings: DramaFrontMatterSettings {
        get {
            guard let data = dramaFrontMatterSettingsData else { return DramaFrontMatterSettings() }
            return (try? JSONDecoder().decode(DramaFrontMatterSettings.self, from: data)) ?? DramaFrontMatterSettings()
        }
        set {
            dramaFrontMatterSettingsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    /// Drama back matter settings - which items are enabled
    var dramaBackMatterSettings: DramaBackMatterSettings {
        get {
            guard let data = dramaBackMatterSettingsData else { return DramaBackMatterSettings() }
            return (try? JSONDecoder().decode(DramaBackMatterSettings.self, from: data)) ?? DramaBackMatterSettings()
        }
        set {
            dramaBackMatterSettingsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    /// Check if this folder belongs to a Drama project
    var isDramaProject: Bool {
        project?.type == .drama
    }
    
    /// Check if this is a Front Matter folder
    var isFrontMatterFolder: Bool {
        name == "Front Matter" || name == NSLocalizedString("folder.frontMatter", comment: "Front Matter")
    }
    
    /// Check if this is a Back Matter folder
    var isBackMatterFolder: Bool {
        name == "Back Matter" || name == NSLocalizedString("folder.backMatter", comment: "Back Matter")
    }
    
    /// Get the project for this folder, traversing parent chain if needed
    /// For subfolders (like Back Matter inside Manuscript), the direct project link may be nil
    var resolvedProject: Project? {
        project ?? parentFolder?.resolvedProject
    }
    
    init(name: String?, project: Project? = nil, parentFolder: Folder? = nil, userOrder: Int? = nil) {
        self.name = name
        self.project = project
        self.parentFolder = parentFolder
        self.userOrder = userOrder
        self.folders = []
        self.textFiles = []
    }
}

@Model
final class Version {
    var id: UUID = UUID()
    var content: String = ""
    var createdDate: Date = Date()
    var versionNumber: Int = 1
    var comment: String?
    var notes: String?
    @Attribute(.externalStorage) var notesFormattedContent: Data?
    
    // MARK: - Text Formatting (Phase 005)
    /// Formatted content stored as RTF data
    @Attribute(.externalStorage) var formattedContent: Data?
    
    // MARK: - Feature 029: Reference Metadata
    /// Reference metadata for back matter entries (notes, glossary, citations, index)
    /// Stores which entries are referenced at which positions, needed because RTF
    /// doesn't preserve custom ReferenceAttachment subclasses
    var referenceMetadataData: Data?
    
    // PERFORMANCE: Cache for deserialized attributed content
    // Transient - not persisted, cleared when formattedContent changes
    @Transient private var _cachedAttributedContent: NSAttributedString?
    @Transient private var _cachedFormattedContentHash: Data?
    
    // SwiftData Relationships
    var textFile: TextFile?
    
    // Feature 014: Comments - Version-specific annotations
    @Relationship(deleteRule: .cascade, inverse: \CommentModel.version)
    var comments: [CommentModel]? = []
    
    // Feature 015: Footnotes - Version-specific annotations
    @Relationship(deleteRule: .cascade, inverse: \FootnoteModel.version)
    var footnotes: [FootnoteModel]? = []
    
    // Feature 008b: Publication Management
    @Relationship(deleteRule: .nullify, inverse: \SubmittedFile.version) 
    var submittedFiles: [SubmittedFile]? = []
    
    init(content: String = "", versionNumber: Int = 1, comment: String? = nil) {
        self.content = content
        self.versionNumber = versionNumber
        self.comment = comment
        self.createdDate = Date()
        
        // Don't set formattedContent here - it will be initialized from the project's
        // stylesheet when the file is first opened in FileEditView
    }
    
    func updateContent(_ newContent: String) {
        self.content = newContent
        // NOTE: This method is legacy from plain text era (Phase 003/004)
        // It should NOT update formattedContent/attributedContent
        // because that would destroy formatting when called by undo/redo commands
        // The commands work with plain text, but the UI has already saved
        // the full attributed content before the command was created
    }
    
    // MARK: - Formatted Content Support
    
    /// Computed property for working with NSAttributedString
    /// PERFORMANCE: Cached to avoid expensive RTF deserialization on every access
    var attributedContent: NSAttributedString? {
        get {
            // If we have cached content and formattedContent hasn't changed, return cache
            if let cached = _cachedAttributedContent,
               _cachedFormattedContentHash == formattedContent {
                return cached
            }
            
            // No formatted content - return plain text
            guard let data = formattedContent, !data.isEmpty else {
                #if DEBUG
                print("[Version] ⚠️ No formattedContent, returning plain text")
                #endif
                // Fall back to plain text with body font and textStyle attribute if no formatted content
                let plainText = NSAttributedString(
                    string: content,
                    attributes: [
                        .font: UIFont.preferredFont(forTextStyle: .body),
                        .textStyle: UIFont.TextStyle.body.attributeValue
                    ]
                )
                // Cache plain text result too
                _cachedAttributedContent = plainText
                _cachedFormattedContentHash = nil
                return plainText
            }
            
            // Legacy imports from Writing Shed 1.0 store RTF data with font scaling.
            // Modern content is encoded as a plist, so avoid paying a failing RTF decode on every cache miss.
            if AttributedStringSerializer.isLegacyRTFFormat(data),
               let rtfDecoded = AttributedStringSerializer.fromLegacyRTF(data) {
                // DEBUG: Check what traits are in the final result being returned
                var boldCount = 0
                var italicCount = 0
                rtfDecoded.enumerateAttribute(.font, in: NSRange(location: 0, length: rtfDecoded.length)) { value, _, _ in
                    if let font = value as? UIFont {
                        if font.fontDescriptor.symbolicTraits.contains(.traitBold) { boldCount += 1 }
                        if font.fontDescriptor.symbolicTraits.contains(.traitItalic) { italicCount += 1 }
                    }
                }
                #if DEBUG
                print("[Version] Successfully decoded legacy RTF data (\(data.count) bytes)")
                #if DEBUG
                print("[Version] 🎯 RETURNING attributed content with \(boldCount) bold ranges, \(italicCount) italic ranges")
                #endif
                #endif
                // Cache the result
                _cachedAttributedContent = rtfDecoded
                _cachedFormattedContentHash = data
                return rtfDecoded
            }
            
            // Fall back to plist format (for current app format)
            // If decoding fails, it will return plain text with default formatting
            let decoded = AttributedStringSerializer.decode(data, text: content)
            // If decode returned empty or very short content, but we have plain text content, fall back
            if decoded.length < content.count / 2 && !content.isEmpty {
                #if DEBUG
                print("[Version] Decode produced short result (\(decoded.length) vs \(content.count)), falling back to plain text")
                #endif
                let plainText = NSAttributedString(
                    string: content,
                    attributes: [
                        .font: UIFont.preferredFont(forTextStyle: .body),
                        .textStyle: UIFont.TextStyle.body.attributeValue
                    ]
                )
                _cachedAttributedContent = plainText
                _cachedFormattedContentHash = nil
                return plainText
            }
            
            // Cache the result
            _cachedAttributedContent = decoded
            _cachedFormattedContentHash = data
            return decoded
        }
        set {
            if let attributed = newValue {
                // Encode using AttributedStringSerializer (extracts font traits)
                formattedContent = AttributedStringSerializer.encode(attributed)
                
                // CRITICAL: Update plain text for search/compatibility
                // MUST preserve attachment characters (U+FFFC) for proper reconstruction
                // attributed.string already includes these characters
                content = attributed.string
                
                #if DEBUG
                // Debug: Count attachment characters
                let attachmentCharCount = attributed.string.filter { $0 == "\u{FFFC}" }.count
                if attachmentCharCount > 0 {
                    #if DEBUG
                    print("💾 Saving plain text with \(attachmentCharCount) attachment characters (U+FFFC)")
                    #endif
                }
                #endif
                
                // Clear cache when content changes
                _cachedAttributedContent = nil
                _cachedFormattedContentHash = nil
            } else {
                formattedContent = nil
                _cachedAttributedContent = nil
                _cachedFormattedContentHash = nil
            }
        }
    }
    
    // MARK: - Submission Locking (Feature 008b)
    
    /// Returns true if this version is referenced by any submission to a publication
    /// Collections (submissions without a publication) do not lock versions
    var isLocked: Bool {
        guard let submittedFiles = submittedFiles, !submittedFiles.isEmpty else {
            return false
        }
        // Only locked if submitted to an actual publication (not a collection)
        return submittedFiles.contains { $0.submission?.publication != nil }
    }
    
    /// Returns all submissions that reference this version
    var referencingSubmissions: [SubmittedFile] {
        return submittedFiles ?? []
    }
    
    /// Can this version be edited?
    var canEdit: Bool {
        !isLocked
    }
    
    /// Can this version be deleted?
    var canDelete: Bool {
        !isLocked
    }
    
    /// Reason why version is locked (for error messages)
    var lockReason: String? {
        guard isLocked else { return nil }
        let submissions = referencingSubmissions
        if submissions.isEmpty { return nil }
        
        let publicationNames = submissions.compactMap { $0.submission?.publication?.name }
        if publicationNames.count == 1 {
            return "This version is locked because it's part of a submission to \(publicationNames[0])."
        } else {
            return "This version is locked because it's part of \(publicationNames.count) submissions."
        }
    }
}

@Model
final class TextFile {
    var id: UUID = UUID()
    var name: String = ""
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    var currentVersionIndex: Int = 0
    var userOrder: Int?
    
    // Workflow status (replaces folder-based workflow)
    // Only used for Poetry, Fiction, Drama projects - nil for Prose
    var workflowStatusRaw: String?
    
    // Undo/Redo support (for TextFileUndoManager)
    @Attribute(.externalStorage) var undoStackData: Data?
    @Attribute(.externalStorage) var redoStackData: Data?
    var undoStackMaxSize: Int = 100
    var lastUndoSaveDate: Date?
    
    // Feature 021: Smart Poetry Creation
    // Stores the selected poetry form for this file (Poetry projects only)
    var poetryFormId: UUID?
    var poetryFormName: String?  // Denormalized for display without lookup
    
    // SwiftData Relationships - all must be optional for CloudKit
    @Relationship(deleteRule: .nullify, inverse: \Folder.textFiles) 
    var parentFolder: Folder?
    
    @Relationship(deleteRule: .cascade, inverse: \Version.textFile) 
    var versions: [Version]? = nil
    
    var trashItem: TrashItem? // Inverse for TrashItem.textFile
    
    // Feature 008b: Publication Management
    @Relationship(deleteRule: .nullify, inverse: \SubmittedFile.textFile) 
    var submittedFiles: [SubmittedFile]? = []
    
    // Feature 022: Smart Fiction Creation
    // A TextFile can be the content of a Scene
    var scene: StoryScene?
    
    // Prose: A TextFile can belong to multiple ProseSections (via join table for CloudKit)
    @Relationship(deleteRule: .nullify, inverse: \TextFileSectionLink.textFile)
    var sectionLinks: [TextFileSectionLink]? = []
    
    // Feature 036: Poetry Collection membership (via join table for CloudKit)
    @Relationship(deleteRule: .nullify, inverse: \TextFileCollectionLink.textFile)
    var poetryCollectionLinks: [TextFileCollectionLink]? = []
    
    // Feature 029: Manuscript Assembly
    // Whether this file is included in manuscript assembly (default: true)
    var includedInManuscript: Bool = true
    
    // Feature 031: Table of Contents
    // Indicates this file is a TOC file (auto-generated content)
    var isTOCFile: Bool = false
    // JSON-encoded TOCSettings for TOC files
    var tocSettingsData: Data?
    
    // Feature 112: Table of Figures
    // Indicates this file is a Table of Figures file (auto-generated content)
    var isTableOfFiguresFile: Bool = false
    // JSON-encoded TableOfFiguresSettings for Table of Figures files
    var tofSettingsData: Data?
    
    // Cover image file support (Front Cover / Back Cover)
    // Cover files display only an image and do not contribute to page count
    var isCoverFile: Bool = false
    // Image data for cover files (JPEG/PNG compressed)
    @Attribute(.externalStorage) var coverImageData: Data?
    
    // Content type: richText (default) or markdown
    var contentTypeRaw: String = "richText"
    
    /// Workflow status for this file (Draft, Ready, Submitted, etc.)
    var workflowStatus: WorkflowStatus? {
        get {
            guard let raw = workflowStatusRaw else { return nil }
            return WorkflowStatus(rawValue: raw)
        }
        set {
            workflowStatusRaw = newValue?.rawValue
            modifiedDate = Date()
        }
    }
    
    /// Content type for this file (Rich Text or Markdown)
    var contentType: FileContentType {
        get {
            return FileContentType(rawValue: contentTypeRaw) ?? .richText
        }
        set {
            contentTypeRaw = newValue.rawValue
            modifiedDate = Date()
        }
    }
    
    /// Whether this file is a markdown file
    var isMarkdown: Bool {
        return contentType == .markdown
    }
    
    /// Get the project this file belongs to (via parent folder chain)
    var project: Project? {
        return parentFolder?.resolvedProject
    }
    
    /// Check if this file is a back matter file (in Back Matter folder)
    var isBackMatterFile: Bool {
        return parentFolder?.name == "Back Matter"
    }
    
    // MARK: - Many-to-Many Computed Properties (via join tables)
    
    /// Prose sections this file belongs to (derived from join table)
    var sections: [ProseSection]? {
        get { sectionLinks?.compactMap(\.section) }
        set {
            for link in sectionLinks ?? [] { modelContext?.delete(link) }
            sectionLinks = []
            for section in newValue ?? [] {
                let link = TextFileSectionLink(textFile: self, section: section)
                modelContext?.insert(link)
                if sectionLinks == nil { sectionLinks = [] }
                sectionLinks?.append(link)
            }
        }
    }
    
    /// Poetry collections this file belongs to (derived from join table)
    var poetryCollections: [PoetryCollection]? {
        get { poetryCollectionLinks?.compactMap(\.poetryCollection) }
        set {
            for link in poetryCollectionLinks ?? [] { modelContext?.delete(link) }
            poetryCollectionLinks = []
            for collection in newValue ?? [] {
                let link = TextFileCollectionLink(textFile: self, poetryCollection: collection)
                modelContext?.insert(link)
                if poetryCollectionLinks == nil { poetryCollectionLinks = [] }
                poetryCollectionLinks?.append(link)
            }
        }
    }
    
    /// Get the poetry form for this file (if assigned)
    var poetryForm: PoetryForm? {
        guard let formId = poetryFormId else { return nil }
        return PoetryFormService.shared.getForm(byId: formId)
    }
    
    /// Get/set TOC settings (decoded from tocSettingsData)
    var tocSettings: TOCSettings {
        get {
            guard let data = tocSettingsData,
                  let settings = try? JSONDecoder().decode(TOCSettings.self, from: data) else {
                return .default
            }
            return settings
        }
        set {
            tocSettingsData = try? JSONEncoder().encode(newValue)
            modifiedDate = Date()
        }
    }
    
    /// Get/set Table of Figures settings (decoded from tofSettingsData)
    var tableOfFiguresSettings: TableOfFiguresSettings {
        get {
            guard let data = tofSettingsData,
                  let settings = try? JSONDecoder().decode(TableOfFiguresSettings.self, from: data) else {
                return .default
            }
            return settings
        }
        set {
            tofSettingsData = try? JSONEncoder().encode(newValue)
            modifiedDate = Date()
        }
    }
    
    init(name: String = "", initialContent: String = "", parentFolder: Folder? = nil, poetryFormId: UUID? = nil, poetryFormName: String? = nil) {
        self.name = name
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.parentFolder = parentFolder
        self.currentVersionIndex = 0
        self.poetryFormId = poetryFormId
        self.poetryFormName = poetryFormName
        
        // Create initial version and assign to optional array
        let firstVersion = Version(content: initialContent, versionNumber: 1)
        self.versions = [firstVersion]
        firstVersion.textFile = self
    }
    
    // MARK: - Poetry Form Methods
    
    /// Set the poetry form for this file
    /// - Parameter form: The poetry form to assign, or nil to clear
    func setPoetryForm(_ form: PoetryForm?) {
        poetryFormId = form?.id
        poetryFormName = form?.name
        modifiedDate = Date()
        Task { @MainActor in WriteCoalescer.shared?.requestSave() }
    }
    
    // MARK: - Computed Properties
    
    /// Returns the currently active version
    /// IMPORTANT: Always works with sorted versions to match navigation logic
    var currentVersion: Version? {
        guard let versions = versions, !versions.isEmpty else { 
            return nil
        }
        
        // CRITICAL: Sort versions by versionNumber to match navigation
        // The currentVersionIndex refers to position in SORTED array
        let sortedVersions = versions.sorted { $0.versionNumber < $1.versionNumber }
        
        // Ensure currentVersionIndex is valid
        guard currentVersionIndex >= 0 && currentVersionIndex < sortedVersions.count else {
            // Index out of bounds while relationships are still syncing - read the last version without mutating.
            #if DEBUG
            print("⚠️ currentVersionIndex (\(currentVersionIndex)) out of bounds for \(sortedVersions.count) versions, reading last without saving")
            #endif
            return sortedVersions.last
        }
        
        return sortedVersions[currentVersionIndex]
    }
    
    /// Returns the content of the current version
    var currentContent: String {
        return currentVersion?.content ?? ""
    }
    
    // MARK: - Version Management Methods
    
    /// Creates a new version with the provided content
    /// - Parameters:
    ///   - content: The text content for the new version
    ///   - comment: Optional comment describing this version
    /// - Returns: The newly created version
    func createNewVersion(content: String, comment: String? = nil) -> Version {
        let nextVersionNumber = (versions?.map { $0.versionNumber }.max() ?? 0) + 1
        let newVersion = Version(content: content, versionNumber: nextVersionNumber, comment: comment)
        if versions == nil {
            versions = []
        }
        versions?.append(newVersion)
        currentVersionIndex = (versions?.count ?? 1) - 1
        modifiedDate = Date()
        Task { @MainActor in WriteCoalescer.shared?.requestSave() }
        return newVersion
    }
    
    /// Switches the current version to the specified version
    /// - Parameter version: The version to switch to
    func switchToVersion(_ version: Version) {
        guard let versions = versions, !versions.isEmpty else { return }

        // currentVersionIndex is always interpreted in sorted versionNumber space.
        // Using the raw array index can point at a different snapshot when the
        // relationship array is not already sorted.
        let sortedVersions = versions.sorted { $0.versionNumber < $1.versionNumber }
        if let sortedIndex = sortedVersions.firstIndex(where: { $0.id == version.id }) {
            currentVersionIndex = sortedIndex
            modifiedDate = Date()
            Task { @MainActor in WriteCoalescer.shared?.requestSave() }
        }
    }
    
    /// Switches to a version by its number
    /// - Parameter versionNumber: The version number to switch to
    func switchToVersionNumber(_ versionNumber: Int) {
        if let version = versions?.first(where: { $0.versionNumber == versionNumber }) {
            switchToVersion(version)
        }
    }
    
    /// Updates the content of the current version (in-place editing)
    /// - Parameter newContent: The new content for the current version
    func updateCurrentVersion(content newContent: String) {
        currentVersion?.updateContent(newContent)
        modifiedDate = Date()
        Task { @MainActor in WriteCoalescer.shared?.requestSave() }
    }
    
    /// Returns all versions sorted by version number
    var sortedVersions: [Version] {
        return versions?.sorted { $0.versionNumber < $1.versionNumber } ?? []
    }
}

// MARK: - TrashItem (Feature 008a: File Movement System)

/// Represents a deleted file in the Trash with metadata for restoration
@Model
final class TrashItem {
    var id: UUID = UUID()
    var deletedDate: Date = Date()
    
    // SwiftData Relationships
    /// The file that was deleted
    @Relationship(deleteRule: .nullify, inverse: \TextFile.trashItem)
    var textFile: TextFile?
    
    /// The folder the file originally came from (for Put Back)
    @Relationship(deleteRule: .nullify, inverse: \Folder.trashedItems)
    var originalFolder: Folder?
    
    /// The project this trash item belongs to
    @Relationship(deleteRule: .nullify, inverse: \Project.trashedItems)
    var project: Project?
    
    init(textFile: TextFile, originalFolder: Folder?, project: Project?) {
        self.textFile = textFile
        self.originalFolder = originalFolder
        self.project = project
        self.deletedDate = Date()
    }
    
    // MARK: - Computed Properties
    
    /// Display name for the trashed file
    var displayName: String {
        return textFile?.name ?? "Unknown"
    }
    
    /// Original folder name for display ("From: Draft")
    var originalFolderName: String {
        return originalFolder?.name ?? "Unknown"
    }
    
    /// Returns true if the original folder still exists
    var canRestoreToOriginal: Bool {
        return originalFolder != nil
    }
}

