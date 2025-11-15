//
//  LinkSceneComponents.swift
//  Write!
//
//  Created by Keith Lander on 22/11/2021.
//

import Foundation

extension ProjectImporter {
    func linkSceneComponents(project: Project, projectData: WritingShedData) {
        // link scenes to components
        projectData.textFileDatas.forEach({ textFileData in
            // decode the links to the components
            if textFileData.type == kSceneEntity {
                var links = [String]()
                do {
                    links = try PropertyListDecoder().decode([String].self, from: textFileData.sceneComponents!)
                } catch {
                }
                if links.count > 0 {
                    // for each link find its sceneComponent and add it to the scene
                    let textFile = MyCoreData.getEntity("TextFile", withImported: imported(textFileData.id)) as! TextFile
                    links.forEach { link in
                        let narrativeUnit = MyCoreData.getEntity("NarrativeUnit", withImported: link) as! NarrativeUnit
                        textFile.addToNarrativeUnits(narrativeUnit)
                    }
                }
            }
        })
        // link components to scenes
        projectData.sceneComponentDatas.forEach({ sceneComponentData in
            if sceneComponentData.type == kSceneEntity {
                // decode the links to the scenes
                let links: [String]
                do {
                    links = try PropertyListDecoder().decode([String].self, from: sceneComponentData.scenes!)
                } catch {
                    return
                }
                if links.count > 0 {
                    // for each link find its scene and add it to the sceneComponent
                    let narrativeUnit = MyCoreData.getEntity("TextFile",
                                                              withImported: imported(sceneComponentData.id)) as! NarrativeUnit
                    links.forEach { link in
                        let textFile = MyCoreData.getEntity("TextFile", withImported: link) as! TextFile
                        textFile.addToNarrativeUnits(narrativeUnit)
                    }
                }
            }
        })
    }
}
