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
    
    @Relationship(deleteRule: .cascade, inverse: \TextFileCollectionLink.poetryCollection)
    var textFileLinks: [TextFileCollectionLink]? = []
    
    /// Text files in this collection (derived from join table)
    var textFiles: [TextFile]? {
        get { textFileLinks?.compactMap(\.textFile) }
        set {
            for link in textFileLinks ?? [] { modelContext?.delete(link) }
            textFileLinks = []
            for file in newValue ?? [] {
                let link = TextFileCollectionLink(textFile: file, poetryCollection: self)
                modelContext?.insert(link)
                if textFileLinks == nil { textFileLinks = [] }
                textFileLinks?.append(link)
            }
        }
    }
    
    init(name: String? = nil, synopsis: String? = nil, userOrder: Int? = nil) {
        self.name = name
        self.synopsis = synopsis
        self.userOrder = userOrder
    }
}
