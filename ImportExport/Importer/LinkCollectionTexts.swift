//
//  LinkCollectionTexts.swift
//  Write!
//
//  Created by Keith Lander on 26/11/2021.
//

import Foundation

extension ProjectImporter {
    func linkCollectionTexts(project: Project, projectData: WritingShedData) {
        // link texts to collection
        projectData.collectionComponentDatas.forEach({ collectionComponentData in
            linkCollectedVersions(collectionComponentData)
            if collectionComponentData.type == kCollectionEntity || collectionComponentData.type == kChapterEntity {
                var links = [String]()
                do {
                    links = try PropertyListDecoder().decode([String].self,
                                                             from: collectionComponentData.collectedTextIds!)
                } catch {
                }
                if links.count > 0 {
                    var folder = (MyCoreData.getEntity("Folder", withImported: imported(collectionComponentData.id)) as? Folder)
                    if folder == nil {
                        folder = decode(collectionComponentData.collectionComponent)
                    }
                    if folder?.submission == nil {
                        folder!.parent = Folder.getFolder(name: "Collections",
                                                       in: ProjectImporter.theProject!)
                    }
                    links.forEach { link in
                        let text = MyCoreData.getEntity("TextFile",
                                                        withImported: link) as! TextFile
                        folder!.addToTextFiles(text)
                        text.addToFolders(folder!)
                    }
                }
            }
        })
        // link collections to text
        projectData.textFileDatas.forEach({ textFileData in
            let links: [String]
            do {
                links = try PropertyListDecoder().decode([String].self, from: textFileData.collectionIds!)
            } catch {
                return
            }
            if links.count > 0 {
                let text = MyCoreData.getEntity("TextFile",
                                                withImported: imported(textFileData.id)) as! TextFile
                links.forEach { link in
                    let folder = MyCoreData.getEntity("Folder",
                                                      withImported: imported(link)) as! Folder
                    text.addToFolders(folder)
                    folder.addToTextFiles(text)
                }
            }
        })
    }
}
