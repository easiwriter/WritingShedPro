//
//  LegacyDataStructs.swift
//  Writing Shed Pro
//
//  Created on 13 November 2025.
//  Feature 009: Database Import
//

import Foundation

/// Plain Swift structs to hold legacy data extracted from Core Data
/// This prevents accessing freed NSManagedObjects across async boundaries

struct LegacyProjectData {
    let objectID: String  // For lookups if needed
    let name: String
    let projectType: String
    let createdOn: Date
    
    // Store object references as strings to avoid holding NSManagedObject references
    var textObjectIDs: [String] = []
    var collectionObjectIDs: [String] = []
}

struct LegacyTextData {
    let objectID: String
    let name: String
    let groupName: String?
    let dateCreated: Date
    var versionObjectIDs: [String] = []
}

struct LegacyVersionData {
    let objectID: String
    let date: Date
    let versionNumber: Int16
    let hasTextString: Bool  // Whether there's associated text
}

struct LegacyCollectionData {
    let objectID: String
    let name: String
    let collectionType: String
    let creationDate: Date
}
