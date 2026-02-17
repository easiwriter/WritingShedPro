//
//  PoetryCollection.swift
//  Writing Shed Pro
//
//  Feature 036: Project Folder Revamp
//  A collection is a container for poems (Poetry projects only)
//  Similar to ProseSection in Prose projects
//

import Foundation
import SwiftData

/// A poetry collection groups poems together for manuscript assembly.
/// Poems with 'ready' workflow status can be assigned to a collection.
/// Collections can then be added to Body Matter for manuscript output.
@Model
final class PoetryCollection {
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
    
    @Relationship(deleteRule: .nullify, inverse: \TextFile.poetryCollection)
    var textFiles: [TextFile]?
    
    init(name: String? = nil, synopsis: String? = nil, userOrder: Int? = nil) {
        self.name = name
        self.synopsis = synopsis
        self.userOrder = userOrder
    }
}
