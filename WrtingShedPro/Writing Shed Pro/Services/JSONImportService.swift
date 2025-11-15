//
//  JSONImportService.swift
//  Writing Shed Pro
//
//  Created on 15 November 2025.
//  Feature 009: JSON Import from Writing Shed v1 Export
//

import Foundation
import SwiftData
import UIKit

/// Handles import of JSON files exported from Writing Shed v1
class JSONImportService {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    private let errorHandler: ImportErrorHandler
    
    // Cache for mapping old IDs to new objects
    private var textFileMap: [String: TextFile] = [:]
    private var versionMap: [String: Version] = [:]
    private var publicationMap: [String: Publication] = [:]
    private var submissionMap: [String: Submission] = [:]
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, errorHandler: ImportErrorHandler) {
        self.modelContext = modelContext
        self.errorHandler = errorHandler
    }
    
    // MARK: - Main Import Method
    
    /// Import a project from a Writing Shed v1 JSON export file
    /// - Parameter fileURL: URL to the JSON file
    /// - Returns: The imported project
    /// - Throws: ImportError if import fails
    func importFromJSON(fileURL: URL) throws -> Project {
        // Read JSON file
        let jsonData = try Data(contentsOf: fileURL)
        
        // Decode JSON
        let decoder = JSONDecoder()
        let writingShedData = try decoder.decode(WritingShedData.self, from: jsonData)
        
        // Debug logging
        print("[JSONImport] Project Name: \(writingShedData.projectName)")
        print("[JSONImport] Project Model: \(writingShedData.projectModel)")
        print("[JSONImport] Text Files Count: \(writingShedData.textFileDatas.count)")
        print("[JSONImport] Collection Components Count: \(writingShedData.collectionComponentDatas.count)")
        print("[JSONImport] Scene Components Count: \(writingShedData.sceneComponentDatas.count)")
        
        // Validate project name
        guard !writingShedData.projectName.isEmpty else {
            throw ImportError.missingContent
        }
        
        // Create new project
        let project = try createProject(from: writingShedData)
        modelContext.insert(project)
        
        print("[JSONImport] Created project with type: \(project.type)")
        
        // Import text files and versions
        try importTextFiles(from: writingShedData, into: project)
        
        // Import publications (submissions in old terminology)
        try importPublications(from: writingShedData, into: project)
        
        // Import collections (text collections)
        try importCollections(from: writingShedData, into: project)
        
        // Link collection submissions
        try linkCollectionSubmissions(from: writingShedData, into: project)
        
        // Save
        try modelContext.save()
        
        return project
    }
    
    // MARK: - Project Creation
    
    private func createProject(from data: WritingShedData) throws -> Project {
        // Decode the project string (assuming it's base64 encoded plist or similar)
        var projectName = data.projectName
        
        // Clean up project name (remove timestamp if present)
        if let components = projectName.split(separator: "<>", maxSplits: 1).first {
            projectName = String(components).trimmingCharacters(in: .whitespaces)
        }
        
        // Map project type
        let projectType = mapProjectType(data.projectModel)
        
        // Create project
        let project = Project(name: projectName, type: projectType, creationDate: Date())
        project.modifiedDate = Date()
        
        return project
    }
    
    private func mapProjectType(_ modelString: String) -> ProjectType {
        let typeMapping: [String: ProjectType] = [
            "novel": .novel,
            "poetry": .poetry,
            "script": .script,
            "shortStory": .shortStory,
            "short story": .shortStory,
            "blank": .blank
        ]
        
        return typeMapping[modelString.lowercased()] ?? .blank
    }
    
    // MARK: - Text Files Import
    
    private func importTextFiles(from data: WritingShedData, into project: Project) throws {
        print("[JSONImport] Starting text file import for \(data.textFileDatas.count) files")
        
        for (index, textFileData) in data.textFileDatas.enumerated() {
            print("[JSONImport] Processing text file \(index + 1)/\(data.textFileDatas.count)")
            print("[JSONImport]   ID: \(textFileData.id)")
            print("[JSONImport]   Type: \(textFileData.type)")
            print("[JSONImport]   Versions: \(textFileData.versions.count)")
            
            // Decode text file metadata
            guard let textFileMetadata = try? decodeTextFileMetadata(textFileData.textFile) else {
                errorHandler.addWarning("Failed to decode text file metadata for ID: \(textFileData.id)")
                print("[JSONImport]   ⚠️ Failed to decode metadata")
                continue
            }
            
            print("[JSONImport]   Name: \(textFileMetadata.name)")
            print("[JSONImport]   Folder: \(textFileMetadata.folderName)")
            
            // Get or create folder
            let folder = getOrCreateFolder(name: textFileMetadata.folderName, in: project)
            
            // Create TextFile
            let textFile = TextFile()
            textFile.name = textFileMetadata.name
            textFile.createdDate = textFileMetadata.createdDate ?? Date()
            textFile.modifiedDate = textFileMetadata.modifiedDate ?? Date()
            textFile.parentFolder = folder
            
            // Cache for later linking
            textFileMap[textFileData.id] = textFile
            
            // Import versions
            try importVersions(from: textFileData.versions, into: textFile)
            
            modelContext.insert(textFile)
        }
    }
    
    // MARK: - Versions Import
    
    private func importVersions(from versionDatas: [VersionData], into textFile: TextFile) throws {
        for (index, versionData) in versionDatas.enumerated() {
            let version = Version()
            version.versionNumber = index + 1
            version.createdDate = Date() // Would need to decode from versionData.version
            version.textFile = textFile
            
            // Decode notes
            if let notesString = try? decodeAttributedString(from: versionData.notes, plainText: versionData.notesText) {
                version.comment = notesString.string
            }
            
            // Decode content
            if !versionData.quickfile {
                if let contentString = try? decodeAttributedString(from: versionData.textFile, plainText: versionData.text) {
                    // Apply dark mode fix
                    let cleanedString = AttributedStringSerializer.stripAdaptiveColors(from: contentString)
                    
                    // Convert to RTF
                    let plainText = cleanedString.string
                    version.content = plainText
                    
                    // Try to save as RTF
                    if let rtfData = try? cleanedString.data(
                        from: NSRange(location: 0, length: cleanedString.length),
                        documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
                    ) {
                        version.formattedContent = rtfData
                    }
                }
            }
            
            // Cache for later linking
            versionMap[versionData.id] = version
            
            modelContext.insert(version)
        }
    }
    
    // MARK: - Publications Import
    
    private func importPublications(from data: WritingShedData, into project: Project) throws {
        for componentData in data.collectionComponentDatas {
            // Only process submission entities (publications)
            guard componentData.type == "WS_Submission_Entity" else { continue }
            
            // Decode publication metadata
            guard let metadata = try? decodePublicationMetadata(componentData.collectionComponent) else {
                errorHandler.addWarning("Failed to decode publication metadata")
                continue
            }
            
            // Create Publication
            let publication = Publication()
            publication.name = metadata.name
            publication.type = mapPublicationType(metadata.groupName)
            publication.project = project
            publication.createdDate = Date()
            publication.modifiedDate = Date()
            
            // Decode notes
            if let notesString = try? decodeAttributedString(from: componentData.notes, plainText: componentData.notesText) {
                publication.notes = notesString.string
            }
            
            // Cache for later linking
            publicationMap[componentData.id] = publication
            
            modelContext.insert(publication)
        }
    }
    
    private func mapPublicationType(_ groupName: String) -> PublicationType {
        switch groupName.lowercased() {
        case "magazine", "magazines":
            return .magazine
        case "competition", "competitions":
            return .competition
        case "commission", "commissions":
            return .commission
        default:
            return .other
        }
    }
    
    // MARK: - Collections Import
    
    private func importCollections(from data: WritingShedData, into project: Project) throws {
        for componentData in data.collectionComponentDatas {
            // Skip submission entities (already processed as publications)
            guard componentData.type != "WS_Submission_Entity" else { continue }
            
            // Only process if there are collected texts
            guard let textCollectionData = componentData.textCollectionData,
                  let collectedVersionIds = textCollectionData.collectedVersionIds,
                  let versionIds = try? PropertyListDecoder().decode([String].self, from: collectedVersionIds),
                  !versionIds.isEmpty else {
                continue
            }
            
            // Decode collection metadata
            guard let metadata = try? decodeCollectionMetadata(componentData.collectionComponent) else {
                errorHandler.addWarning("Failed to decode collection metadata")
                continue
            }
            
            // Create Submission (collection in new model)
            let submission = Submission()
            submission.submittedDate = metadata.dateCreated ?? Date()
            submission.project = project
            
            // Decode notes
            if let notesString = try? decodeAttributedString(from: componentData.notes, plainText: componentData.notesText) {
                submission.notes = notesString.string
            }
            
            // Link versions to submission via SubmittedFile
            for versionId in versionIds {
                if let version = versionMap[versionId],
                   let textFile = version.textFile {
                    let submittedFile = SubmittedFile(
                        submission: submission,
                        textFile: textFile,
                        version: version,
                        status: .pending
                    )
                    modelContext.insert(submittedFile)
                }
            }
            
            // Cache for linking to publications
            submissionMap[componentData.id] = submission
            
            modelContext.insert(submission)
        }
    }
    
    // MARK: - Link Collection Submissions
    
    private func linkCollectionSubmissions(from data: WritingShedData, into project: Project) throws {
        for componentData in data.collectionComponentDatas {
            // Only process collection entities
            guard componentData.type != "WS_Submission_Entity" else { continue }
            
            // Check if there are submission links
            guard let submissionIds = componentData.collectionSubmissionIds,
                  let links = try? PropertyListDecoder().decode([String].self, from: submissionIds),
                  !links.isEmpty else {
                continue
            }
            
            // Get the submission (collection)
            guard let submission = submissionMap[componentData.id] else {
                continue
            }
            
            // Link to publication
            for linkId in links {
                if let publication = publicationMap[linkId] {
                    submission.publication = publication
                    break // Only one publication per submission
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getOrCreateFolder(name: String, in project: Project) -> Folder {
        // Check if folder already exists in project's folders
        if let existing = project.folders?.first(where: { $0.name == name && $0.parentFolder == nil }) {
            return existing
        }
        
        // Create new folder at root level
        let folder = Folder(name: name, project: project, parentFolder: nil)
        modelContext.insert(folder)
        
        return folder
    }
    
    /// Decode NSAttributedString from Data (property list archived)
    private func decodeAttributedString(from data: Data, plainText: String) throws -> NSAttributedString {
        // Try to unarchive NSAttributedString
        if let attributedString = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: NSAttributedString.self,
            from: data
        ) {
            return attributedString
        }
        
        // Fallback to plain text
        return NSAttributedString(string: plainText)
    }
    
    /// Decode text file metadata from base64 encoded plist
    private func decodeTextFileMetadata(_ encodedString: String) throws -> TextFileMetadata {
        guard let data = Data(base64Encoded: encodedString),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw ImportError.missingContent
        }
        
        return TextFileMetadata(
            name: dict["name"] as? String ?? "Untitled",
            folderName: dict["groupName"] as? String ?? "Drafts",
            createdDate: dict["dateCreated"] as? Date,
            modifiedDate: dict["dateLastUpdated"] as? Date
        )
    }
    
    /// Decode publication metadata from base64 encoded plist
    private func decodePublicationMetadata(_ encodedString: String) throws -> PublicationMetadata {
        guard let data = Data(base64Encoded: encodedString),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw ImportError.missingContent
        }
        
        return PublicationMetadata(
            name: dict["name"] as? String ?? "Untitled",
            groupName: dict["groupName"] as? String ?? ""
        )
    }
    
    /// Decode collection metadata from base64 encoded plist
    private func decodeCollectionMetadata(_ encodedString: String) throws -> CollectionMetadata {
        guard let data = Data(base64Encoded: encodedString),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw ImportError.missingContent
        }
        
        return CollectionMetadata(
            name: dict["name"] as? String,
            dateCreated: dict["dateCreated"] as? Date
        )
    }
}

// MARK: - Supporting Structures

struct TextFileMetadata {
    let name: String
    let folderName: String
    let createdDate: Date?
    let modifiedDate: Date?
}

struct PublicationMetadata {
    let name: String
    let groupName: String
}

struct CollectionMetadata {
    let name: String?
    let dateCreated: Date?
}

// MARK: - WritingShedData Structures (from original code)

struct WritingShedData: Codable {
    var projectModel: String
    var projectName: String
    var project: String
    var textFileDatas: [TextFileData]
    var sceneComponentDatas: [SceneComponentData]
    var collectionComponentDatas: [CollectionComponentData]
}

struct CollectionComponentData: Codable {
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
}

struct CollectionSubmissionData: Codable {
    var type: String = "WS_CollectionSubmission_Entity"
    var id: String
    var submissionId: String
    var collectionId: String
    var collectionSubmission: String
}

struct SceneComponentData: Codable {
    var type: String
    var id: String
    var sceneComponent: String
    var scenes: Data?
}

struct TextCollectionData: Codable {
    var type: String = "WS_TextCollection_Entity"
    var id: String
    var textCollection: String
    var collectedVersionIds: Data?
}

struct TextFileData: Codable {
    var type: String
    var id: String
    var textFile: String
    var versions: [VersionData]
    var sceneComponents: Data?
    var collectionIds: Data?
}

struct VersionData: Codable {
    var type: String = "WS_Version_Entity"
    var id: String
    var version: String
    var notes: Data
    var notesText: String
    var textString: String?
    var quickfile: Bool = false
    var textFile: Data
    var text: String
    var collectedVersionData: [CollectedVersionData]?
}

struct CollectedVersionData: Codable {
    var type: String = "WS_CollectedVersion_Entity"
    var id: String
    var collectedVersion: String
}
