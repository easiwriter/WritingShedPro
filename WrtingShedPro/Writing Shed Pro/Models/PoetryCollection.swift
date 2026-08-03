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
    
    @Relationship(deleteRule: .nullify)
    var textFileLinks: [TextFileCollectionLink]? = []
    
    /// Text files in this collection (derived from join table)
    var textFiles: [TextFile]? {
        get {
            guard let context = modelContext else {
                return textFileLinks?.compactMap(\.textFile)
            }

            let links = ((try? context.fetch(FetchDescriptor<TextFileCollectionLink>())) ?? [])
                .filter { $0.resolvedPoetryCollectionID == id }
            let linkedFiles = links.compactMap(\.textFile)

            let missingFileIDs = Set(links.compactMap(\.resolvedTextFileID)).subtracting(linkedFiles.map(\.id))
            guard !missingFileIDs.isEmpty else { return linkedFiles }

            let allFiles = (try? context.fetch(FetchDescriptor<TextFile>())) ?? []
            return linkedFiles + allFiles.filter { missingFileIDs.contains($0.id) }
        }
        set {
            guard let context = modelContext else { return }
            let links = (try? context.fetch(FetchDescriptor<TextFileCollectionLink>())) ?? []
            for link in links where link.resolvedPoetryCollectionID == id { context.delete(link) }
            for file in newValue ?? [] {
                let link = TextFileCollectionLink(textFileID: file.id, poetryCollectionID: id)
                context.insert(link)
            }
        }
    }
    
    init(name: String? = nil, synopsis: String? = nil, userOrder: Int? = nil) {
        self.name = name
        self.synopsis = synopsis
        self.userOrder = userOrder
    }
}
