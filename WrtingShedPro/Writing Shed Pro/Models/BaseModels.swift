import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID = UUID()
    var name: String?
    var typeRaw: String?
    var creationDate: Date?
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
    @Relationship(deleteRule: .cascade, inverse: \Folder.parentFolder) var folders: [Folder]?
    @Relationship(deleteRule: .nullify) var parentFolder: Folder?
    @Relationship(deleteRule: .cascade, inverse: \File.parentFolder) var files: [File]?
    @Relationship(deleteRule: .cascade, inverse: \TextFile.parentFolder) var textFiles: [TextFile] = []
    var project: Project?
    
    init(name: String?, project: Project? = nil, parentFolder: Folder? = nil) {
        self.name = name
        self.project = project
        self.parentFolder = parentFolder
        self.folders = []
        self.files = []
        self.textFiles = []
    }
}

@Model
final class File {
    var id: UUID = UUID()
    var name: String?
    var content: String?
    var parentFolder: Folder?
    
    init(name: String?, content: String? = nil) {
        self.name = name
        self.content = content
    }
}

@Model
final class Version {
    var id: UUID = UUID()
    var content: String
    var createdDate: Date
    var versionNumber: Int
    var comment: String?
    
    // SwiftData Relationships
    @Relationship(deleteRule: .nullify)
    var textFile: TextFile?
    
    init(content: String, versionNumber: Int, comment: String? = nil) {
        self.content = content
        self.versionNumber = versionNumber
        self.comment = comment
        self.createdDate = Date()
    }
    
    func updateContent(_ newContent: String) {
        self.content = newContent
    }
}

@Model
final class TextFile {
    var id: UUID = UUID()
    var name: String
    var createdDate: Date
    var modifiedDate: Date
    var currentVersionIndex: Int = 0
    
    // SwiftData Relationships
    @Relationship(deleteRule: .nullify) 
    var parentFolder: Folder?
    
    @Relationship(deleteRule: .cascade, inverse: \Version.textFile)
    var versions: [Version] = []
    
    init(name: String, initialContent: String = "", parentFolder: Folder? = nil) {
        self.name = name
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.parentFolder = parentFolder
        
        // Create initial version
        let firstVersion = Version(content: initialContent, versionNumber: 1)
        self.versions = [firstVersion]
    }
    
    // MARK: - Computed Properties
    
    /// Returns the currently active version
    var currentVersion: Version? {
        guard currentVersionIndex < versions.count else { return versions.first }
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
        let nextVersionNumber = (versions.map { $0.versionNumber }.max() ?? 0) + 1
        let newVersion = Version(content: content, versionNumber: nextVersionNumber, comment: comment)
        versions.append(newVersion)
        currentVersionIndex = versions.count - 1
        modifiedDate = Date()
        return newVersion
    }
    
    /// Switches the current version to the specified version
    /// - Parameter version: The version to switch to
    func switchToVersion(_ version: Version) {
        if let index = versions.firstIndex(of: version) {
            currentVersionIndex = index
            modifiedDate = Date()
        }
    }
    
    /// Switches to a version by its number
    /// - Parameter versionNumber: The version number to switch to
    func switchToVersionNumber(_ versionNumber: Int) {
        if let version = versions.first(where: { $0.versionNumber == versionNumber }) {
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
        return versions.sorted { $0.versionNumber < $1.versionNumber }
    }
}

