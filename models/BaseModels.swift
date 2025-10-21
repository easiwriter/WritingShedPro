import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var type: ProjectType
    var creationDate: Date
    var details: String?
    @Relationship(deleteRule: .cascade, inverse: \File.project) var files: [File] = []
    
    init(name: String, type: ProjectType, creationDate: Date = Date(), details: String? = nil) {
        self.name = name
        self.type = type
        self.creationDate = creationDate
        self.details = details
    }
}

enum ProjectType: String, Codable, CaseIterable {
    case prose, poetry, drama
}

@Model
final class File {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var content: String
    @Relationship(inverse: \Folder.files) var parentFolder: Folder?
    @Relationship(inverse: \Project.files) var project: Project
    
    init(name: String, content: String = "", project: Project, parentFolder: Folder? = nil) {
        self.name = name
        self.content = content
        self.project = project
        self.parentFolder = parentFolder
    }
}

@Model
final class Folder {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \Folder.parentFolder) var folders: [Folder] = []
    @Relationship(inverse: \Folder.parentFolder) var parentFolder: Folder?
    @Relationship(deleteRule: .cascade, inverse: \Folder.files) var files: [File] = []
    @Relationship(inverse: \Project.files) var project: Project
    
    init(name: String, project: Project, parentFolder: Folder? = nil) {
        self.name = name
        self.project = project
        self.parentFolder = parentFolder
    }
}
