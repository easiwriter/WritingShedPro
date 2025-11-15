//
//  LinkCollectedVersions.swift
//  Write!
//
//  Created by Keith Lander on 26/11/2021.
//

import Foundation
import CoreData

extension ProjectImporter {
    func linkCollectedVersions(_ collectionComponentData: CollectionComponentData) {
        if collectionComponentData.type != kSubmissionEntity {
            var folder: Folder
            var fldr = MyCoreData.getEntity("Folder",
                                            withImported: imported(collectionComponentData.id)) as? Folder
            if fldr == nil {
                let folderName = collectionComponentData.type == kChapterEntity ? "Chapters" : "Collections"
                fldr = Write_.decode(collectionComponentData.collectionComponent)
                fldr!.parent = Folder.getFolder(name: folderName,
                                                  in: ProjectImporter.theProject!)
            }
            folder = fldr!
            if ["Magazines", "Competitions", "Commissions", "Other"].contains(folder.name) {
                folder.kind = FolderKind.publications.rawValue
            } else {
                folder.kind = FolderKind.submissions.rawValue
            }
            let tcd = collectionComponentData.textCollectionData
            let collectedText: CollectedText = Write_.decode(tcd!.textCollection)
            folder.collectedText = collectedText
            collectedText.folder = folder
            var links = [String]()
            do {
                links = try PropertyListDecoder().decode([String].self,
                                                         from: tcd!.collectedVersionIds!)
            } catch {
            }
            if links.count > 0 {
                links.forEach { link in
                    let collectedDraft = MyCoreData.getEntity("CollectedDraft", withImported: link) as! CollectedDraft
                    collectedText.addToCollectedDrafts(collectedDraft)
                    if folder.kind != FolderKind.publications.rawValue && folder.parent == nil {
                        folder.parent = Folder.getFolder(name: folder.group!,
                                                         in: ProjectImporter.theProject!)
                    }
                }
            }
        }
    }
}
