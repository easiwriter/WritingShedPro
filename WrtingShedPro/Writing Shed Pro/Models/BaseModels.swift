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

@Model
final class Project {
    var id: UUID = UUID()
    var name: String?
    var typeRaw: String?
    var statusRaw: String? // "legacy" or "pro"
    var creationDate: Date?
    var modifiedDate: Date?
    var details: String?
    var notes: String?
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
    var useMonomyth: Bool = false
    
    // Fiction relationships
    @Relationship(deleteRule: .cascade, inverse: \FictionScene.project)
    var scenes: [FictionScene]? = []
    
    @Relationship(deleteRule: .cascade, inverse: \FictionChapter.project)
    var chapters: [FictionChapter]? = []
    
    @Relationship(deleteRule: .cascade, inverse: \FictionCharacter.project)
    var characters: [FictionCharacter]? = []
    
    @Relationship(deleteRule: .cascade, inverse: \FictionLocation.project)
    var locations: [FictionLocation]? = []
    
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
    
    var type: ProjectType {
        get {
            guard let typeRaw = typeRaw, let projectType = ProjectType(rawValue: typeRaw) else {
                // Handle legacy "blank" value
                if typeRaw == "blank" {
                    return .generalPurpose
                }
                return .generalPurpose
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
    
    init(name: String?, type: ProjectType = ProjectType.generalPurpose, creationDate: Date? = Date(), details: String? = nil, notes: String? = nil, userOrder: Int? = nil, styleSheet: StyleSheet? = nil) {
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
}

enum ProjectType: String, Codable, CaseIterable {
    case generalPurpose, poetry, fiction, drama
    
    // Backward compatibility: decode legacy values
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "blank":
            self = .generalPurpose
        case "novel", "shortStory":
            self = .fiction
        case "script":
            self = .drama
        default:
            self = ProjectType(rawValue: rawValue) ?? .generalPurpose
        }
    }
}

@Model
final class Folder {
    var id: UUID = UUID()
    var name: String?
    var userOrder: Int?  // For user-defined ordering in General Purpose projects
    @Relationship(deleteRule: .cascade) var folders: [Folder]?  // Inverse is parentFolder
    @Relationship(deleteRule: .cascade) var textFiles: [TextFile]?  // Inverse is TextFile.parentFolder
    @Relationship(inverse: \Folder.folders) var parentFolder: Folder?  // Inverse is folders
    var project: Project?
    var trashedItems: [TrashItem]? // Inverse for TrashItem.originalFolder
    
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
    
    // MARK: - Text Formatting (Phase 005)
    /// Formatted content stored as RTF data
    var formattedContent: Data?
    
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
            
            // Try to decode as RTF first (for legacy imports)
            // Legacy imports from Writing Shed 1.0 store RTF data with font scaling
            if let rtfDecoded = AttributedStringSerializer.fromLegacyRTF(data) {
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
            
            // Fall back to JSON format (for current app format)
            // If decoding fails, it will return plain text with default formatting
            #if DEBUG
            print("[Version] 📦 Trying JSON decode (not legacy RTF)")
            #endif
            let decoded = AttributedStringSerializer.decode(data, text: content)
            
            // DEBUG: Check traits in JSON decoded result
            var boldCount = 0
            decoded.enumerateAttribute(.font, in: NSRange(location: 0, length: decoded.length)) { value, _, _ in
                if let font = value as? UIFont {
                    if font.fontDescriptor.symbolicTraits.contains(.traitBold) { boldCount += 1 }
                }
            }
            #if DEBUG
            print("[Version] 📦 JSON decoded has \(boldCount) bold ranges")
            #endif
            
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
            #if DEBUG
            print("[Version] 🎯 RETURNING JSON decoded content with \(boldCount) bold ranges")
            #endif
            
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
    // Only used for Poetry, Fiction, Drama projects - nil for General Purpose
    var workflowStatusRaw: String?
    
    // Undo/Redo support (for TextFileUndoManager)
    var undoStackData: Data?
    var redoStackData: Data?
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
    // A TextFile can be the content of a FictionScene
    var scene: FictionScene?
    
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
    
    /// Get the project this file belongs to (via parent folder or scene)
    var project: Project? {
        return parentFolder?.project
    }
    
    /// Get the poetry form for this file (if assigned)
    var poetryForm: PoetryForm? {
        guard let formId = poetryFormId else { return nil }
        return PoetryFormService.shared.getForm(byId: formId)
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
            // Index out of bounds - reset to last version (highest version number)
            #if DEBUG
            print("⚠️ currentVersionIndex (\(currentVersionIndex)) out of bounds for \(sortedVersions.count) versions, resetting to last")
            #endif
            currentVersionIndex = sortedVersions.count - 1
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
        return newVersion
    }
    
    /// Switches the current version to the specified version
    /// - Parameter version: The version to switch to
    func switchToVersion(_ version: Version) {
        if let index = versions?.firstIndex(of: version) {
            currentVersionIndex = index
            modifiedDate = Date()
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

