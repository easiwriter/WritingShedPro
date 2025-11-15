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
        
        // Create all standard folders for the project type
        createStandardFolders(for: project)
        
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
        var projectName = data.projectName
        
        // Clean up project name - remove date/timestamp in brackets
        // e.g., "The 1st World (15:11:2025, 08:47)" -> "The 1st World"
        projectName = cleanProjectName(projectName)
        
        // Check if this name already exists
        projectName = ensureUniqueName(projectName)
        
        // Map project type
        let projectType = mapProjectType(data.projectModel)
        
        // Create project
        let project = Project(name: projectName, type: projectType, creationDate: Date())
        project.modifiedDate = Date()
        
        return project
    }
    
    /// Remove date/timestamp info from project name
    private func cleanProjectName(_ name: String) -> String {
        var cleaned = name
        
        // First, remove any timestamp patterns like "<>03/06/2016, 09:09Poetry"
        if let components = cleaned.split(separator: "<>", maxSplits: 1).first {
            cleaned = String(components)
        }
        
        // Remove date in brackets at end: "(15:11:2025, 08:47)" or "(dd/mm/yyyy, hh:mm)"
        // Pattern: (date, time) at end of string
        let pattern = "\\s*\\([\\d:,\\s/]+\\)\\s*$"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, range: range, withTemplate: "")
        }
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    /// Ensure project name is unique in the context
    private func ensureUniqueName(_ name: String) -> String {
        // Fetch all existing projects
        let descriptor = FetchDescriptor<Project>()
        guard let existingProjects = try? modelContext.fetch(descriptor) else {
            return name
        }
        
        let existingNames = Set(existingProjects.compactMap { $0.name })
        
        // If name is unique, use it as-is
        if !existingNames.contains(name) {
            return name
        }
        
        // Name exists - find unique variant with number suffix
        var counter = 2
        var uniqueName = "\(name) \(counter)"
        
        while existingNames.contains(uniqueName) {
            counter += 1
            uniqueName = "\(name) \(counter)"
        }
        
        print("[JSONImport] ⚠️ Duplicate project name detected. Renamed '\(name)' to '\(uniqueName)'")
        
        return uniqueName
    }
    
    private func mapProjectType(_ modelString: String) -> ProjectType {
        // Handle numeric values (legacy enum)
        let numericMapping: [String: ProjectType] = [
            "35": .poetry,  // WS_Poetry_Project_Value
            "36": .novel,   // WS_Novel_Project_Value
            "37": .script,  // WS_Script_Project_Value
            "38": .shortStory  // WS_Short_Story_Project_Value
        ]
        
        // Check numeric first
        if let type = numericMapping[modelString] {
            return type
        }
        
        // Fall back to string names
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
        print("[JSONImport] Starting publication import from \(data.collectionComponentDatas.count) collection components")
        
        var publicationCount = 0
        for componentData in data.collectionComponentDatas {
            // Only process submission entities (publications)
            guard componentData.type == "WS_Submission_Entity" else { continue }
            
            publicationCount += 1
            print("[JSONImport] Processing publication \(publicationCount)")
            
            // Decode publication metadata
            guard let metadata = try? decodePublicationMetadata(componentData.collectionComponent) else {
                errorHandler.addWarning("Failed to decode publication metadata")
                print("[JSONImport] ⚠️ Failed to decode publication metadata")
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
        
        print("[JSONImport] ✅ Imported \(publicationCount) publications")
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
        print("[JSONImport] Starting collections/submissions import")
        
        var collectionCount = 0
        for componentData in data.collectionComponentDatas {
            // Only process WS_Collection_Entity (NOT WS_Submission_Entity which are publications)
            guard componentData.type == "WS_Collection_Entity" else { continue }
            
            collectionCount += 1
            print("[JSONImport] Processing collection/submission \(collectionCount)")
            
            // Decode collection metadata from collectionComponent
            guard let metadata = try? decodeCollectionMetadata(componentData.collectionComponent) else {
                errorHandler.addWarning("Failed to decode collection metadata")
                print("[JSONImport] ⚠️ Failed to decode collection metadata for ID: \(componentData.id)")
                continue
            }
            
            // Create Submission (collection in new model)
            // Note: publication will be linked later if this is a submission to a magazine/competition
            let submission = Submission()
            submission.submittedDate = metadata.dateCreated ?? Date()
            submission.project = project
            
            // Decode notes
            if let notesString = try? decodeAttributedString(from: componentData.notes, plainText: componentData.notesText) {
                submission.notes = notesString.string
            }
            
            print("[JSONImport]   Collection name: \(metadata.name ?? "unnamed")")
            
            // Cache for linking files and publications
            submissionMap[componentData.id] = submission
            
            modelContext.insert(submission)
        }
        
        print("[JSONImport] ✅ Created \(collectionCount) collections/submissions")
        
        // Now link files to submissions by examining collectedVersionData in versions
        print("[JSONImport] Linking files to collections...")
        var linkedCount = 0
        
        for (versionId, version) in versionMap {
            guard let textFile = version.textFile else { continue }
            
            // Find the corresponding version data to get collectedVersionData
            for textFileData in data.textFileDatas {
                for versionData in textFileData.versions {
                    guard versionData.id == versionId else { continue }
                    guard let collectedVersionData = versionData.collectedVersionData, !collectedVersionData.isEmpty else { continue }
                    
                    // Link this version to collections
                    for collectedData in collectedVersionData {
                        // Decode to get collection ID
                        guard let collectedDict = try? JSONSerialization.jsonObject(
                            with: collectedData.collectedVersion.data(using: .utf8)!
                        ) as? [String: Any],
                        let collectionId = collectedDict["uniqueIdentifier"] as? String else {
                            continue
                        }
                        
                        // Find collection ID by looking in submissionMap
                        // But we need to match against the textCollectionData.id, not the componentData.id
                        // Let's search for the right submission
                        for componentData in data.collectionComponentDatas {
                            guard componentData.type == "WS_Collection_Entity",
                                  let textCollectionData = componentData.textCollectionData,
                                  textCollectionData.id == collectionId,
                                  let submission = submissionMap[componentData.id] else {
                                continue
                            }
                            
                            // Create submitted file link
                            let submittedFile = SubmittedFile(
                                submission: submission,
                                textFile: textFile,
                                version: version,
                                status: .pending
                            )
                            modelContext.insert(submittedFile)
                            linkedCount += 1
                            break
                        }
                    }
                }
            }
        }
        
        print("[JSONImport] ✅ Linked \(linkedCount) files to collections")
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
    
    /// Create all standard folders for a project based on its type
    private func createStandardFolders(for project: Project) {
        let folderNames: [String]
        
        switch project.type {
        case .blank:
            folderNames = ["Files", "Trash"]
            
        case .poetry, .shortStory:
            folderNames = [
                "All",
                "Draft",
                "Ready",
                "Collections",
                "Set Aside",
                "Published",
                "Research",
                "Magazines",
                "Competitions",
                "Commissions",
                "Other",
                "Trash"
            ]
            
        case .novel:
            folderNames = [
                "Novel",
                "Chapters",
                "Scenes",
                "Characters",
                "Locations",
                "Set Aside",
                "Research",
                "Competitions",
                "Commissions",
                "Other",
                "Trash"
            ]
            
        case .script:
            folderNames = [
                "Script",
                "Acts",
                "Scenes",
                "Characters",
                "Locations",
                "Set Aside",
                "Research",
                "Competitions",
                "Commissions",
                "Other",
                "Trash"
            ]
        }
        
        // Create all folders
        for name in folderNames {
            let folder = Folder(name: name, project: project, parentFolder: nil)
            modelContext.insert(folder)
        }
        
        print("[JSONImport] Created \(folderNames.count) standard folders")
    }
    
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
    
    /// Decode text file metadata from JSON string (dictionary format)
    private func decodeTextFileMetadata(_ jsonString: String) throws -> TextFileMetadata {
        // The textFile field contains a JSON-encoded dictionary, not base64
        guard let data = jsonString.data(using: .utf8) else {
            print("[JSONImport] ❌ Failed to convert string to data")
            throw ImportError.missingContent
        }
        
        // Decode as JSON dictionary
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[JSONImport] ❌ Failed to decode as JSON dictionary")
            // Try to print what we got for debugging
            print("[JSONImport] String preview: \(jsonString.prefix(200))")
            throw ImportError.missingContent
        }
        
        print("[JSONImport] ✅ Decoded metadata keys: \(dict.keys.sorted())")
        
        // Extract dates if present (they may be in various formats)
        var createdDate: Date?
        var modifiedDate: Date?
        
        if let dateString = dict["dateCreated"] as? String {
            createdDate = ISO8601DateFormatter().date(from: dateString)
        }
        
        if let dateString = dict["dateLastUpdated"] as? String {
            modifiedDate = ISO8601DateFormatter().date(from: dateString)
        }
        
        // Map old folder names to new folder names
        let originalFolderName = dict["groupName"] as? String ?? "Draft"
        let mappedFolderName = mapLegacyFolderName(originalFolderName)
        
        return TextFileMetadata(
            name: dict["name"] as? String ?? "Untitled",
            folderName: mappedFolderName,
            createdDate: createdDate,
            modifiedDate: modifiedDate
        )
    }
    
    /// Map legacy Writing Shed v1 folder names to Writing Shed Pro folder names
    private func mapLegacyFolderName(_ legacyName: String) -> String {
        switch legacyName {
        case "Accepted":
            return "Published"  // Old app used "Accepted", new app uses "Published"
        case "Draft", "Ready", "Set Aside", "Collections", "Research", "Trash":
            return legacyName  // These names stayed the same
        default:
            return legacyName  // Unknown folders keep their original name
        }
    }
    
    /// Decode publication metadata from JSON string (dictionary format)
    private func decodePublicationMetadata(_ jsonString: String) throws -> PublicationMetadata {
        // The collectionComponent field contains a JSON-encoded dictionary
        guard let data = jsonString.data(using: .utf8) else {
            print("[JSONImport] ❌ Publication: Failed to convert string to data")
            throw ImportError.missingContent
        }
        
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[JSONImport] ❌ Publication: Failed to decode JSON dictionary")
            print("[JSONImport] String preview: \(jsonString.prefix(200))")
            throw ImportError.missingContent
        }
        
        print("[JSONImport] ✅ Publication decoded: \(dict["name"] as? String ?? "unnamed") - \(dict["groupName"] as? String ?? "no type")")
        
        return PublicationMetadata(
            name: dict["name"] as? String ?? "Untitled",
            groupName: dict["groupName"] as? String ?? ""
        )
    }
    
    /// Decode collection metadata from JSON string (dictionary format)
    private func decodeCollectionMetadata(_ jsonString: String) throws -> CollectionMetadata {
        // The collectionComponent field contains a JSON-encoded dictionary
        guard let data = jsonString.data(using: .utf8) else {
            print("[JSONImport] ❌ Collection: Failed to convert string to data")
            throw ImportError.missingContent
        }
        
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[JSONImport] ❌ Collection: Failed to decode JSON dictionary")
            print("[JSONImport] String preview: \(jsonString.prefix(200))")
            throw ImportError.missingContent
        }
        
        print("[JSONImport] ✅ Collection decoded: \(dict["name"] as? String ?? "unnamed")")
        
        // Handle date from timestamp (createdOn field is a TimeInterval)
        var createdDate: Date?
        if let timestamp = dict["createdOn"] as? TimeInterval {
            createdDate = Date(timeIntervalSinceReferenceDate: timestamp)
        }
        
        return CollectionMetadata(
            name: dict["name"] as? String,
            dateCreated: createdDate
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
