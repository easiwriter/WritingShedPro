//
//  Book.swift
//  Writing Shed Pro
//
//  Feature 036: Project Folder Revamp
//  A book is a container for episodes (Verse Novel fiction class only)
//  Episodes are scenes with a poetry form. Books replace the incorrect
//  use of Chapter entities for Verse Novel projects.
//

import Foundation
import SwiftData

/// A book groups episodes (verse scenes) together in Verse Novel projects.
/// Books can be added to Body Matter for manuscript output.
@Model
final class Book {
    var id: UUID = UUID()
    var name: String?
    var userOrder: Int?
    var synopsis: String?
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    
    // Feature 036: Body Matter tracking
    var bodyMatterOrder: Int?
    var isInBodyMatter: Bool = false
    
    // Relationships
    var project: Project?
    
    @Relationship(deleteRule: .nullify, inverse: \SceneBookLink.book)
    var sceneLinks: [SceneBookLink]? = []

    @Relationship(deleteRule: .nullify)
    var scenes: [StoryScene]? = []
    
    init(name: String? = nil, synopsis: String? = nil, userOrder: Int? = nil) {
        self.name = name
        self.synopsis = synopsis
        self.userOrder = userOrder
    }
}
