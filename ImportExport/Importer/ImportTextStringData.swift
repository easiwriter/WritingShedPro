//
//  ImportTextStringData.swift
//  Write!
//
//  Created by Keith Lander on 24/11/2021.
//

import Foundation

extension ProjectImporter {

    func importTextStringData(for draft: Draft, in textStringData: String, with versionData: VersionData) {
        if versionData.quickfile {
            draft.quickfileData = versionData.textFile as NSObject
        } else {
            let text = decodeString(attributeData: versionData.textFile, text: versionData.text)
            draft.attributedText = text as NSAttributedString
        }
    }
}
