//
//  DataMapper.swift
//  Writing Shed Pro
//
//  Created on 12 November 2025.
//  Feature 009: Database Import
//

import Foundation
import CoreData
import SwiftData

/// Maps legacy Core Data entities to new SwiftData models
class DataMapper {
    
    // MARK: - Properties
    
    private let legacyService: LegacyDatabaseService
    private let errorHandler: ImportErrorHandler
    private var uuidCache: [String: UUID] = [:]  // Cache for UUID lookups
    
    // MARK: - Initialization
    
    init(legacyService: LegacyDatabaseService, errorHandler: ImportErrorHandler) {
        self.legacyService = legacyService
        self.errorHandler = errorHandler
    }
    
    // MARK: - Project Mapping
    
    /// Map LegacyProjectData to Project
    func mapProject(_ legacyData: LegacyProjectData) throws -> Project {
        var name = legacyData.name
        
        // Legacy database stores name with metadata appended like "name<>DD/MM/YYYY, HH:MM"
        // Extract just the project name part
        if let components = name.split(separator: "<>", maxSplits: 1, omittingEmptySubsequences: false).first {
            name = String(components).trimmingCharacters(in: .whitespaces)
        }
        
        let type = mapProjectType(legacyData.projectType)
        let creationDate = legacyData.createdOn
        
        let project = Project(name: name, type: type, creationDate: creationDate)
        project.modifiedDate = creationDate
        
        return project
    }
    
    /// Map legacy project type string to new ProjectType enum
    private func mapProjectType(_ legacyType: String) -> ProjectType {
        let typeMapping: [String: ProjectType] = [
            "novel": .novel,
            "poetry": .poetry,
            "script": .script,
            "shortStory": .shortStory,
            "blank": .blank
        ]
        
        return typeMapping[legacyType.lowercased()] ?? .blank
    }
    
    // MARK: - TextFile Mapping
    
    /// Map WS_Text_Entity to TextFile
    func mapTextFile(
        _ legacyText: NSManagedObject,
        parentFolder: Folder
    ) throws -> TextFile {
        let file = TextFile()
        
        // Name
        file.name = (legacyText.value(forKey: "name") as? String) ?? "Untitled"
        
        // Dates
        file.createdDate = (legacyText.value(forKey: "dateCreated") as? Date) ?? Date()
        file.modifiedDate = (legacyText.value(forKey: "dateLastUpdated") as? Date) ?? Date()
        
        // Parent folder
        file.parentFolder = parentFolder
        
        // UUID mapping
        if let uniqueId = legacyText.value(forKey: "uniqueIdentifier") as? String {
            if let uuid = UUID(uuidString: uniqueId) {
                file.id = uuid
                uuidCache[uniqueId] = uuid
            } else {
                errorHandler.addWarning("Invalid UUID for text: \(uniqueId), using new UUID")
                file.id = UUID()
            }
        }
        
        return file
    }
    
    // MARK: - Version Mapping
    
    /// Map WS_Version_Entity to Version
    func mapVersion(
        _ legacyVersion: NSManagedObject,
        file: TextFile,
        versionNumber: Int
    ) throws -> Version {
        let version = Version()
        
        // Dates
        version.createdDate = (legacyVersion.value(forKey: "date") as? Date) ?? Date()
        version.versionNumber = versionNumber
        
        // Comments/notes
        version.comment = legacyVersion.value(forKey: "notes") as? String
        
        // TextFile relationship
        version.textFile = file
        
        // UUID mapping
        if let uniqueId = legacyVersion.value(forKey: "uniqueIdentifier") as? String {
            if let uuid = UUID(uuidString: uniqueId) {
                version.id = uuid
                uuidCache[uniqueId] = uuid
            } else {
                errorHandler.addWarning("Invalid UUID for version: \(uniqueId), using new UUID")
                version.id = UUID()
            }
        }
        
        // Get TextString (content)
        if let textStringEntity = legacyVersion.value(forKey: "textString") as? NSManagedObject {
            do {
                let (plainText, rtfData) = try mapTextStringToContent(textStringEntity)
                version.content = plainText
                version.formattedContent = rtfData
            } catch {
                errorHandler.addWarning("Failed to extract content for version: \(error.localizedDescription)")
                version.content = "[Content unavailable]"
            }
        }
        
        return version
    }
    
    /// Map WS_TextString_Entity to (plainText, rtfData)
    private func mapTextStringToContent(_ legacyTextString: NSManagedObject) throws -> (String, Data?) {
        // Get NSAttributedString from transformable attribute
        guard let nsAttributedString = legacyTextString.value(forKey: "textFile") as? NSAttributedString else {
            throw ImportError.missingContent
        }
        
        // Convert using AttributedStringConverter
        let (plainText, rtfData) = AttributedStringConverter.convert(nsAttributedString)
        
        return (plainText, rtfData)
    }
    
    // MARK: - Collection Mapping
    
    // MARK: - Publication Mapping
    
    /// Safely get value from NSManagedObject, returning nil if key doesn't exist
    private func safeValue<T>(from object: NSManagedObject, forKey key: String) -> T? {
        // Check if the entity has this key
        guard object.entity.attributesByName.keys.contains(key) || 
              object.entity.relationshipsByName.keys.contains(key) else {
            return nil
        }
        return object.value(forKey: key) as? T
    }
    
    /// Map WS_Submission_Entity to Publication
    /// WS_Submission_Entity inherits from WS_CollectionComponent_Entity
    /// Available fields: name, createdOn, notes (NSAttributedString), sectionIdentifier, uniqueIdentifier, groupName
    func mapPublication(
        _ legacyPublication: NSManagedObject,
        project: Project
    ) throws -> Publication {
        let publication = Publication()
        
        publication.project = project
        
        // Get publication name (from WS_CollectionComponent_Entity)
        publication.name = safeValue(from: legacyPublication, forKey: "name") ?? "Untitled Publication"
        
        // Map groupName to PublicationType
        let groupName: String = safeValue(from: legacyPublication, forKey: "groupName") ?? ""
        publication.type = mapPublicationType(groupName)
        
        // Map createdOn date (from WS_CollectionComponent_Entity)
        if let createdOn: Date = safeValue(from: legacyPublication, forKey: "createdOn") {
            publication.createdDate = createdOn
            publication.modifiedDate = createdOn
        } else {
            publication.createdDate = Date()
            publication.modifiedDate = Date()
        }
        
        // Map notes if they exist (NSAttributedString in legacy, convert to String)
        if let attributedNotes: NSAttributedString = safeValue(from: legacyPublication, forKey: "notes") {
            publication.notes = attributedNotes.string
        }
        
        // Note: Legacy WS_Submission_Entity does NOT have: deadline, url, submissionGuidelines
        // These fields don't exist in the schema
        
        return publication
    }
    
    /// Map legacy groupName to PublicationType
    private func mapPublicationType(_ groupName: String) -> PublicationType {
        switch groupName.lowercased() {
        case "magazines":
            return .magazine
        case "competitions":
            return .competition
        case "commissions":
            return .commission
        default:
            return .other
        }
    }
    
    /// Map WS_Collection_Entity to Submission (publication=nil)
    /// WS_Collection_Entity inherits from WS_CollectionComponent_Entity
    /// Available fields from parent: name, createdOn, notes (NSAttributedString), sectionIdentifier, uniqueIdentifier
    /// Own fields: dateCreated, groupName, position
    func mapCollection(
        _ legacyCollection: NSManagedObject,
        project: Project
    ) throws -> Submission {
        let submission = Submission()
        
        submission.project = project
        submission.publication = nil  // Mark as collection
        
        // Get collection name from WS_CollectionComponent_Entity parent
        submission.name = safeValue(from: legacyCollection, forKey: "name") ?? "Untitled Collection"
        
        // Get creation date - try dateCreated first, fall back to createdOn from parent
        if let dateCreated: Date = safeValue(from: legacyCollection, forKey: "dateCreated") {
            submission.submittedDate = dateCreated
        } else if let createdOn: Date = safeValue(from: legacyCollection, forKey: "createdOn") {
            submission.submittedDate = createdOn
        } else {
            submission.submittedDate = Date()
        }
        
        // Get notes from parent if they exist (NSAttributedString)
        if let attributedNotes: NSAttributedString = safeValue(from: legacyCollection, forKey: "notes") {
            submission.notes = attributedNotes.string
        }
        
        return submission
    }
    
    /// Map WS_CollectedVersion_Entity to SubmittedFile
    func mapCollectedVersion(
        _ legacyCollectedVersion: NSManagedObject,
        collection: Submission,
        textFileMap: [NSManagedObject: TextFile],
        versionMap: [NSManagedObject: Version]
    ) throws -> SubmittedFile? {
        let submittedFile = SubmittedFile()
        
        submittedFile.submission = collection
        submittedFile.project = collection.project
        submittedFile.createdDate = Date()
        submittedFile.modifiedDate = Date()
        
        // Map version and text file
        if let legacyVersion = legacyCollectedVersion.value(forKey: "version") as? NSManagedObject {
            // Find mapped version
            if let mappedVersion = versionMap[legacyVersion] {
                submittedFile.version = mappedVersion
                submittedFile.textFile = mappedVersion.textFile
            } else {
                errorHandler.addWarning("Version not found in mapping for collected version")
                return nil
            }
        }
        
        // Map status
        if let statusInt = legacyCollectedVersion.value(forKey: "status") as? Int16 {
            submittedFile.status = mapSubmissionStatus(statusInt)
        }
        
        return submittedFile
    }
    
    /// Map legacy status integer to SubmissionStatus
    private func mapSubmissionStatus(_ legacyStatus: Int16) -> SubmissionStatus {
        switch legacyStatus {
        case 0: return .pending
        case 1: return .accepted
        case 2: return .rejected
        default: return .pending
        }
    }
    
    /// Map WS_CollectionSubmission_Entity to Submission (publication=set)
    func mapCollectionSubmission(
        _ legacySubmission: NSManagedObject,
        collectionSubmission: Submission,
        modelContext: ModelContext
    ) throws -> Submission? {
        // Create new Submission for publication
        let pubSubmission = Submission()
        pubSubmission.project = collectionSubmission.project
        
        // Get publication (if mapped)
        if let pubEntity = legacySubmission.value(forKey: "publication") as? NSManagedObject {
            // Try to find mapped publication - for now, skip if not found
            // In future phases, could auto-create publications
            errorHandler.addWarning("Publication submissions require manual mapping - skipping for now")
            return nil
        }
        
        pubSubmission.submittedDate = (legacySubmission.value(forKey: "submittedDate") as? Date) ?? Date()
        
        return pubSubmission
    }
    
    // MARK: - Scene Component Mapping
    
    /// Map WS_Scene_Entity to TextFile
    func mapScene(
        _ legacyScene: NSManagedObject,
        parentFolder: Folder
    ) throws -> TextFile {
        let file = try mapTextFile(legacyScene, parentFolder: parentFolder)
        
        // Scene metadata can be stored in comments or custom properties in future phases
        // For now, scenes are just TextFiles in their folder
        
        return file
    }
    
    /// Map WS_Character_Entity to TextFile
    func mapCharacter(
        _ legacyCharacter: NSManagedObject,
        parentFolder: Folder
    ) throws -> TextFile {
        let file = TextFile()
        file.name = (legacyCharacter.value(forKey: "name") as? String) ?? "Character"
        file.parentFolder = parentFolder
        file.createdDate = Date()
        file.modifiedDate = Date()
        
        // Import character description as first version if available
        if let description = legacyCharacter.value(forKey: "description") as? NSAttributedString {
            let version = Version()
            version.content = description.string
            version.versionNumber = 1
            version.textFile = file
            version.createdDate = Date()
            file.versions = [version]
        } else {
            // Create empty version
            let version = Version()
            version.content = ""
            version.versionNumber = 1
            version.textFile = file
            version.createdDate = Date()
            file.versions = [version]
        }
        
        return file
    }
    
    /// Map WS_Location_Entity to TextFile
    func mapLocation(
        _ legacyLocation: NSManagedObject,
        parentFolder: Folder
    ) throws -> TextFile {
        let file = TextFile()
        file.name = (legacyLocation.value(forKey: "name") as? String) ?? "Location"
        file.parentFolder = parentFolder
        file.createdDate = Date()
        file.modifiedDate = Date()
        
        // Import location description as first version if available
        if let description = legacyLocation.value(forKey: "description") as? NSAttributedString {
            let version = Version()
            version.content = description.string
            version.versionNumber = 1
            version.textFile = file
            version.createdDate = Date()
            file.versions = [version]
        } else {
            // Create empty version
            let version = Version()
            version.content = ""
            version.versionNumber = 1
            version.textFile = file
            version.createdDate = Date()
            file.versions = [version]
        }
        
        return file
    }
}
