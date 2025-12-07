//
//  CollectionComponentData.swift
//  Writing Shed
//
//  Created by Keith Lander on 20/09/2021.
//  Copyright © 2021 www.writing-shed.com. All rights reserved.
//
//  FIXED VERSION - Corrects logic bugs in collection encoding
//

import Foundation

class CollectionComponentData: Codable {
    var type: String
    var id: String
    var collectionComponent: String
    var notes: Data
    var notesText: String
    var collectionSubmissionsDatas: [CollectionSubmissionData]?
    var collectionSubmissionIds: Data?
    var submissionSubmissionIds: Data?
    var textCollectionData: TextCollectionData?
    var collectedTextIds: Data?
    
    init(id: String, collectionComponent: String, collectionEntity: String, notes: NSAttributedString) {
        self.id = id
        self.collectionComponent = collectionComponent
        self.type = collectionEntity
        self.notes = encodeString(text: notes)
        self.notesText = notes.string
    }
    
    // FIX: Changed logic from count == 0 to count > 0
    func addCollectionSubmissions(_ collectionSubmissions: NSSet?) -> [CollectionSubmissionData] {
        var result = [CollectionSubmissionData]()
        guard let cSubmissions = collectionSubmissions, cSubmissions.count > 0 else {
            self.collectionSubmissionsDatas = [CollectionSubmissionData]()
            return result
        }
        cSubmissions.forEach { cs in
            let cs1 = cs as! WS_CollectionSubmission_Entity
            let csub = Writing_Shed.encode(cs1)
            
            // Add submission and collection IDs
            let csd = CollectionSubmissionData(
                id: cs1.uniqueIdentifier!,
                submissionId: cs1.submission?.uniqueIdentifier ?? "",
                collectionId: cs1.collection?.uniqueIdentifier ?? "",
                collectionSubmission: csub
            )
            result.append(csd)
        }
        return result
    }
    
    // FIX: Changed logic from count == 0 to count > 0
    func addCollectionSubmissionIds(_ collectionSubmissions: NSSet?) {
        guard let collectionSubmissions = collectionSubmissions, collectionSubmissions.count > 0 else {
            collectionSubmissionIds = Data()
            return
        }
        var csIds = [String]()
        collectionSubmissions.forEach({ cs in
            let cse = cs as! WS_CollectionSubmission_Entity
            csIds.append(ProjectExporter.newProjectName! + cse.uniqueIdentifier!)
        })
        do {
            collectionSubmissionIds = try PropertyListEncoder().encode(csIds)
        } catch {
            fatalError("Error encoding: \(error)")
        }
    }
    
    // FIX: Changed logic from count == 0 to count > 0
    func addSubmissionSubmissionIds(_ collectionSubmissions: NSSet?) {
        guard let collectionSubmissions = collectionSubmissions, collectionSubmissions.count > 0 else {
            submissionSubmissionIds = Data()
            return
        }
        var csIds = [String]()
        collectionSubmissions.forEach({ cs in
            let cse = cs as! WS_CollectionSubmission_Entity
            csIds.append(ProjectExporter.newProjectName! + cse.uniqueIdentifier!)
        })
        do {
            submissionSubmissionIds = try PropertyListEncoder().encode(csIds)
        } catch {
            fatalError("Error encoding: \(error)")
        }
    }
    
    func addTextCollection(_ textCollection: WS_TextCollection_Entity) {
        let collectedVersions = textCollection.collectedVersions
        let etc = Writing_Shed.encode(textCollection)
        textCollectionData = TextCollectionData(id: textCollection.uniqueIdentifier!,
                                                textCollection: etc)
        textCollectionData?.addCollectedVersionIds(collectedVersions)
    }
    
    // FIX: Changed logic from count == 0 to count > 0
    func addCollectedTextIds(_ texts: NSSet?) {
        guard let texts = texts, texts.count > 0 else {
            collectedTextIds = Data()
            return
        }
        var textIds = [String]()
        texts.forEach({ cv in
            let te = cv as! WS_Text_Entity
            textIds.append(ProjectExporter.newProjectName! + te.uniqueIdentifier!)
        })
        do {
            collectedTextIds = try PropertyListEncoder().encode(textIds)
        } catch {
            fatalError("Error encoding: \(error)")
        }
    }
}

class CollectionSubmissionData: Codable {
    var type = kCollectionSubmissionEntity
    var id: String
    var submissionId: String  // FIX: Added missing field
    var collectionId: String  // FIX: Added missing field
    var collectionSubmission: String
    
    init(id: String, submissionId: String, collectionId: String, collectionSubmission: String) {
        self.id = id
        self.submissionId = submissionId
        self.collectionId = collectionId
        self.collectionSubmission = collectionSubmission
    }
}
