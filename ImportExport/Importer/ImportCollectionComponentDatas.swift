//
//  ImportCollectionComponents.swift
//  Write!
//
//  Created by Keith Lander on 25/11/2021.
//

import Foundation

extension ProjectImporter {
    func importCollectionComponentDatas(project: Project, projectData: WritingShedData) {
        projectData.collectionComponentDatas.forEach { collectionComponentData in
            if collectionComponentData.type == kSubmissionEntity {
                let submission: Folder = Write_.decode(collectionComponentData.collectionComponent)
                submission.notes = collectionComponentData.notesText
            }
        }
    }
}
