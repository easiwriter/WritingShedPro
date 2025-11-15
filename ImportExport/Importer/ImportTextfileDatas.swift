//
//  ImportTextfileDatas.swift
//  Write!
//
//  Created by Keith Lander on 22/11/2021.
//

import Foundation

extension ProjectImporter {
    func importTextFileDatas(project: Project, projectData: WritingShedData) {
        projectData.textFileDatas.forEach { textFileData in
            let textFile: TextFile = decode(textFileData.textFile)
            let folder = Folder.getFolder(name: textFile.groupName!, in: project)
            textFile.addToFolders(folder!)
            if textFileData.type == kSceneEntity {

            }
            importTextVersions(for: textFile, in: textFileData)
        }
    }
}
