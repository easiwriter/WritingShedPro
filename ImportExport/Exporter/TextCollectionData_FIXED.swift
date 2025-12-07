//
//  TextCollectionData.swift
//  Writing Shed
//
//  Created by Keith Lander on 20/09/2021.
//  Copyright © 2021 www.writing-shed.com. All rights reserved.
//
//  FIXED VERSION - Corrects logic bug in collection encoding
//

import Foundation

class TextCollectionData: Codable {
    var type = kTextCollectionEntity
    var id: String
    var textCollection: String
    var collectedVersionIds: Data?
    
    init(id: String, textCollection: String) {
        self.id = id
        self.textCollection = textCollection
    }

    // FIX: Changed logic from count == 0 to count > 0
    func addCollectedVersionIds(_ collectedVersions: NSSet?) {
        guard let collectedVersions = collectedVersions, collectedVersions.count > 0 else {
            collectedVersionIds = Data()
            return
        }
        var cvIds = [String]()
        collectedVersions.forEach({ cv in
            let cv1 = cv as! WS_CollectedVersion_Entity
            cvIds.append(ProjectExporter.newProjectName! + cv1.uniqueIdentifier!)
        })
        do {
            collectedVersionIds = try PropertyListEncoder().encode(cvIds)
        } catch {
            fatalError("Error encoding: \(error)")
        }
    }
}
