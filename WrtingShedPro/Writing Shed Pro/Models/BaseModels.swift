import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID = UUID()
    var name: String?
    var typeRaw: String?
    var creationDate: Date?
    var modifiedDate: Date?
    var details: String?
    var notes: String?
    var userOrder: Int?
    @Relationship(deleteRule: .cascade, inverse: \Folder.project) var folders: [Folder]?
    
    var type: ProjectType {
        get {
            guard let typeRaw = typeRaw, let projectType = ProjectType(rawValue: typeRaw) else {
                return .blank
            }
            return projectType
        }
        set {
            typeRaw = newValue.rawValue
        }
    }
    
    init(name: String?, type: ProjectType = ProjectType.blank, creationDate: Date? = Date(), details: String? = nil, notes: String? = nil, userOrder: Int? = nil) {
        self.name = name
        self.typeRaw = type.rawValue
        self.creationDate = creationDate
        self.modifiedDate = creationDate
        self.details = details
        self.notes = notes
        self.userOrder = userOrder
    }
}

enum ProjectType: String, Codable, CaseIterable {
    case blank, novel, poetry, script, shortStory
}

@Model
final class Folder {
    var id: UUID = UUID()
    var name: String?
    @Relationship(deleteRule: .cascade, inverse: \File.parentFolder) var files: [File]?
    @Relationship(deleteRule: .cascade) var folders: [Folder]?  // Inverse is parentFolder
    @Relationship(deleteRule: .cascade) var textFiles: [TextFile]?  // Inverse is TextFile.parentFolder
    @Relationship(inverse: \Folder.folders) var parentFolder: Folder?  // Inverse is folders
    var project: Project?
    
    init(name: String?, project: Project? = nil, parentFolder: Folder? = nil) {
        self.name = name
        self.project = project
        self.parentFolder = parentFolder
        self.files = []
        self.folders = []
        self.textFiles = []
    }
}

@Model
final class File {
    var id: UUID = UUID()
    var name: String?
    var content: String? // Legacy - will be migrated to versions
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    var userOrder: Int?
    var currentVersionIndex: Int = 0
    var parentFolder: Folder?
    
    // Undo/Redo support
    var undoStackData: Data?
    var redoStackData: Data?
    var undoStackMaxSize: Int = 100
    var lastUndoSaveDate: Date?
    
    @Relationship(deleteRule: .cascade, inverse: \Version.file) var versions: [Version]?
    
    init(name: String?, content: String? = nil, userOrder: Int? = nil) {
        self.name = name
        self.content = content
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.userOrder = userOrder
        self.currentVersionIndex = 0
        
        // Create initial version
        let initialVersion = Version(content: content ?? "", versionNumber: 1)
        self.versions = [initialVersion]
    }
    
    // MARK: - Version Management
    
    /// Returns the current version label for display (e.g., "Version 1/3")
    func versionLabel() -> String {
        let total = versions?.count ?? 0
        let current = currentVersionIndex + 1
        return "Version \(current)/\(total)"
    }
    
    /// Returns the currently active version
    var currentVersion: Version? {
        guard let versions = versions, !versions.isEmpty, currentVersionIndex < versions.count else {
            return nil
        }
        return versions.sorted(by: { $0.versionNumber < $1.versionNumber })[currentVersionIndex]
    }
    
    /// Check if we're at the first version
    func atFirstVersion() -> Bool {
        return currentVersionIndex == 0
    }
    
    /// Check if we're at the last version
    func atLastVersion() -> Bool {
        return currentVersionIndex >= (versions?.count ?? 1) - 1
    }
    
    /// Navigate between versions
    func changeVersion(by offset: Int) {
        let newIndex = currentVersionIndex + offset
        let maxIndex = (versions?.count ?? 1) - 1
        currentVersionIndex = max(0, min(newIndex, maxIndex))
    }
    
    /// Add a new version (duplicate current)
    func addVersion() {
        guard let currentVersion = currentVersion else { return }
        let newVersionNumber = (versions?.count ?? 0) + 1
        let newVersion = Version(
            content: currentVersion.content,
            versionNumber: newVersionNumber,
            comment: "Duplicated from Version \(currentVersion.versionNumber)"
        )
        versions?.append(newVersion)
        currentVersionIndex = (versions?.count ?? 1) - 1
        modifiedDate = Date()
    }
    
    /// Delete the current version
    func deleteVersion() {
        guard let versions = versions, versions.count > 1 else { return }
        let sortedVersions = versions.sorted(by: { $0.versionNumber < $1.versionNumber })
        let versionToDelete = sortedVersions[currentVersionIndex]
        
        // Remove from array
        self.versions?.removeAll { $0.id == versionToDelete.id }
        
        // Adjust current index if needed
        if currentVersionIndex >= (self.versions?.count ?? 0) {
            currentVersionIndex = max(0, (self.versions?.count ?? 1) - 1)
        }
        
        modifiedDate = Date()
    }
}

@Model
final class Version {
    var id: UUID = UUID()
    var content: String = ""
    var createdDate: Date = Date()
    var versionNumber: Int = 1
    var comment: String?
    
    // MARK: - Text Formatting (Phase 005)
    /// Formatted content stored as RTF data
    var formattedContent: Data?
    
    // SwiftData Relationships
    var textFile: TextFile?
    var file: File?
    
    init(content: String = "", versionNumber: Int = 1, comment: String? = nil) {
        self.content = content
        self.versionNumber = versionNumber
        self.comment = comment
        self.createdDate = Date()
    }
    
    func updateContent(_ newContent: String) {
        self.content = newContent
    }
    
    // MARK: - Formatted Content Support
    
    /// Computed property for working with NSAttributedString
    var attributedContent: NSAttributedString? {
        get {
            guard let data = formattedContent else {
                // Fall back to plain text if no formatted content
                return NSAttributedString(string: content)
            }
            // Convert RTF data to NSAttributedString
            do {
                return try NSAttributedString(
                    data: data,
                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                    documentAttributes: nil
                )
            } catch {
                print("⚠️ Error loading formatted content: \(error.localizedDescription)")
                // Fall back to plain text on error
                return NSAttributedString(string: content)
            }
        }
        set {
            if let attributed = newValue {
                // Store as RTF data
                let range = NSRange(location: 0, length: attributed.length)
                do {
                    formattedContent = try attributed.data(
                        from: range,
                        documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
                    )
                    // Also update plain text for search/compatibility
                    content = attributed.string
                } catch {
                    print("⚠️ Error storing formatted content: \(error.localizedDescription)")
                    // Fall back to plain text
                    content = attributed.string
                    formattedContent = nil
                }
            } else {
                formattedContent = nil
            }
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
    
    // SwiftData Relationships - all must be optional for CloudKit
    @Relationship(deleteRule: .nullify, inverse: \Folder.textFiles) 
    var parentFolder: Folder?
    
    @Relationship(deleteRule: .cascade, inverse: \Version.textFile) 
    var versions: [Version]? = nil
    
    init(name: String = "", initialContent: String = "", parentFolder: Folder? = nil) {
        self.name = name
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.parentFolder = parentFolder
        self.currentVersionIndex = 0
        
        // Create initial version and assign to optional array
        let firstVersion = Version(content: initialContent, versionNumber: 1)
        self.versions = [firstVersion]
        firstVersion.textFile = self
    }
    
    // MARK: - Computed Properties
    
    /// Returns the currently active version
    var currentVersion: Version? {
        guard let versions = versions, currentVersionIndex < versions.count else { 
            return versions?.first 
        }
        return versions[currentVersionIndex]
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

