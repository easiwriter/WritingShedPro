//
//  ImportSceneComponentDatas.swift
//  Write!
//
//  Created by Keith Lander on 22/11/2021.
//

import Foundation

extension ProjectImporter {
    func importSceneComponentDatas(project: Project, projectData: WritingShedData) {
        projectData.sceneComponentDatas.forEach { sceneComponentData in
            let narrativeUnit: NarrativeUnit = Write_.decode(sceneComponentData.sceneComponent)
            project.addToNarrativeUnits(narrativeUnit)
        }
    }
}
