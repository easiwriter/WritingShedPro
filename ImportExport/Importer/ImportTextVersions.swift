//
//  ImportTextVersions.swift
//  Write!
//
//  Created by Keith Lander on 23/11/2021.
//

import Foundation

extension ProjectImporter {
    func importTextVersions(for textFile: TextFile, in textFileData: TextFileData) {
        textFileData.versions.forEach { versionData in
            let draft: Draft = Write_.decode(versionData.version)
            textFile.addToDrafts(draft)
            importTextStringData(for: draft, in: versionData.textString!, with: versionData)
            importCollectedVersionData(for: draft, in: versionData.collectedVersionData!)
            draft.notes = decodeString(attributeData: versionData.notes,
                                       text: versionData.notesText).string
        }
    }
}
