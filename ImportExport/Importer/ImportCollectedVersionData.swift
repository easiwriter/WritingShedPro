//
//  ImportCollectedVersionData.swift
//  Write!
//
//  Created by Keith Lander on 27/11/2021.
//

import Foundation

extension ProjectImporter {
    func importCollectedVersionData(for draft: Draft, in collectedVersionData: [CollectedVersionData]) {
        collectedVersionData.forEach { collectedVersion in
            let collectedDraft: CollectedDraft = Write_.decode(collectedVersion.collectedVersion)
            collectedDraft.draft = draft
            draft.collectedDrafts?.adding(collectedDraft)
        }
    }
}
