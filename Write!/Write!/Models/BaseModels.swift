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
                return .prose
            }
            return projectType
        }
        set {
            typeRaw = newValue.rawValue
        }
    }
    
    init(name: String?, type: ProjectType = ProjectType.prose, creationDate: Date? = Date(), details: String? = nil, notes: String? = nil, userOrder: Int? = nil) {
        self.name = name
        self.typeRaw = type.rawValue
        self.creationDate = creationDate
        self.details = details
        self.notes = notes
        self.userOrder = userOrder
    }
}

enum ProjectType: String, Codable, CaseIterable {
    case prose, poetry, drama
}

@Model
final class Folder {
    var id: UUID = UUID()
    var name: String?
    @Relationship(deleteRule: .cascade, inverse: \Folder.parentFolder) var folders: [Folder]?
    @Relationship(deleteRule: .nullify) var parentFolder: Folder?
    @Relationship(deleteRule: .cascade, inverse: \File.parentFolder) var files: [File]?
    var project: Project?
    
    init(name: String?, project: Project? = nil, parentFolder: Folder? = nil) {
        self.name = name
        self.project = project
        self.parentFolder = parentFolder
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

