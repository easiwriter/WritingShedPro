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

/// Errors that can occur during import
public enum ImportError: Error {
    case missingContent
    case invalidData
    case decodingFailed
    case fileNotFound
    case unknownError
}

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
    private var collectedVersionToCollectionMap: [String: String] = [:] // CollectedVersion ID -> TextCollection ID
    
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
        print("[JSONImport] ========== IMPORT START ==========")
        print("[JSONImport] File: \(fileURL.lastPathComponent)")
        
        // Read JSON file
        let jsonData = try Data(contentsOf: fileURL)
        print("[JSONImport] File size: \(jsonData.count) bytes")
        
        // Decode JSON
        let decoder = JSONDecoder()
        let writingShedData = try decoder.decode(WritingShedData.self, from: jsonData)
        
        // Debug logging
        print("[JSONImport] ===== FILE STRUCTURE =====")
        print("[JSONImport] Project Name: \(writingShedData.projectName)")
        print("[JSONImport] Project Model: \(writingShedData.projectModel)")
        print("[JSONImport] Text Files Count: \(writingShedData.textFileDatas.count)")
        print("[JSONImport] Collection Components Count: \(writingShedData.collectionComponentDatas.count)")
        print("[JSONImport] Scene Components Count: \(writingShedData.sceneComponentDatas.count)")
        
        // Detailed breakdown of collection components
        var submissionCount = 0
        var textCollectionCount = 0
        for component in writingShedData.collectionComponentDatas {
            if component.type == "WS_Submission_Entity" {
                submissionCount += 1
            } else if component.type == "WS_TextCollection_Entity" {
                textCollectionCount += 1
            }
        }
        print("[JSONImport] - Submissions: \(submissionCount)")
        print("[JSONImport] - Text Collections: \(textCollectionCount)")
        
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
        
        print("[JSONImport] ===== IMPORT COMPLETE =====")
        print("[JSONImport] Warnings: \(errorHandler.warnings.count)")
        if !errorHandler.warnings.isEmpty {
            print("[JSONImport] Warnings:")
            for (index, warning) in errorHandler.warnings.enumerated() {
                print("[JSONImport]   \(index + 1). \(warning)")
            }
        }
        print("[JSONImport] ========== IMPORT END ==========")
        
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
            
            // Clear the auto-created initial version - we'll import the real versions
            textFile.versions = []
            
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
            print("[JSONImport] Processing publication \(publicationCount), ID: \(componentData.id)")
            
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
            
            print("[JSONImport]   Publication name: \(publication.name), type: \(String(describing: publication.type))")
            print("[JSONImport]   Caching publication with component ID: \(componentData.id)")
            
            // Cache for later linking - use multiple IDs
            publicationMap[componentData.id] = publication
            
            // Also cache by textCollectionData ID if present
            if let textCollectionId = componentData.textCollectionData?.id {
                publicationMap[textCollectionId] = publication
                print("[JSONImport]   Also caching with textCollection ID: \(textCollectionId)")
            }
            
            // Also cache by collectionSubmissionsDatas IDs (the join table entity IDs)
            if let submissionDatas = componentData.collectionSubmissionsDatas {
                for submissionData in submissionDatas {
                    publicationMap[submissionData.id] = publication
                    print("[JSONImport]   Also caching with collectionSubmission ID: \(submissionData.id)")
                }
            }
            
            modelContext.insert(publication)
        }
        
        print("[JSONImport] ✅ Imported \(publicationCount) publications")
        print("[JSONImport]   Publication IDs cached: \(publicationMap.keys.joined(separator: ", "))")
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
            
            // FIX: Get the collection name from collectionComponent, NOT textCollectionData
            // textCollectionData contains the "Texts in [CollectionName]" internal entity
            // collectionComponent contains the actual collection metadata
            var collectionName = "Untitled Collection"
            var submittedDate = Date()
            
            // Decode the collectionComponent JSON to get the collection name and date
            if let collectionDict = try? JSONSerialization.jsonObject(
                with: componentData.collectionComponent.data(using: .utf8)!
            ) as? [String: Any] {
                collectionName = collectionDict["name"] as? String ?? collectionName
                
                // Get date - try multiple possible keys
                if let timestamp = collectionDict["dateCreated"] as? TimeInterval {
                    submittedDate = Date(timeIntervalSinceReferenceDate: timestamp)
                } else if let timestamp = collectionDict["createdOn"] as? TimeInterval {
                    submittedDate = Date(timeIntervalSinceReferenceDate: timestamp)
                }
            }
            
            // Create Submission (collection in new model)
            // Note: publication will be linked later if this is a submission to a magazine/competition
            let submission = Submission()
            submission.name = collectionName  // Set the collection name!
            submission.submittedDate = submittedDate
            submission.project = project
            
            // Decode notes
            if let notesString = try? decodeAttributedString(from: componentData.notes, plainText: componentData.notesText) {
                submission.notes = notesString.string
            }
            
            print("[JSONImport]   Collection name: \(collectionName)")
            print("[JSONImport]   Component ID: \(componentData.id)")
            if let textCollectionData = componentData.textCollectionData {
                print("[JSONImport]   TextCollection ID: \(textCollectionData.id)")
            }
            
            // Cache for linking files and publications
            // IMPORTANT: Cache by textCollectionData.id since that's what versions reference
            if let textCollectionData = componentData.textCollectionData {
                submissionMap[textCollectionData.id] = submission
                print("[JSONImport]   Cached submission with textCollection ID: \(textCollectionData.id)")
                
                // Build map from CollectedVersion IDs to this TextCollection ID
                // This allows us to link versions to collections
                if let collectedVersionIdsData = textCollectionData.collectedVersionIds {
                    do {
                        let collectedVersionIds = try PropertyListDecoder().decode([String].self, from: collectedVersionIdsData)
                        for collectedVersionId in collectedVersionIds {
                            // Strip project prefix if present
                            let cleanId: String
                            if let lastParenIndex = collectedVersionId.lastIndex(of: ")") {
                                cleanId = String(collectedVersionId[collectedVersionId.index(after: lastParenIndex)...])
                            } else {
                                cleanId = collectedVersionId
                            }
                            collectedVersionToCollectionMap[cleanId] = textCollectionData.id
                        }
                        print("[JSONImport]   Mapped \(collectedVersionIds.count) collectedVersion(s) to this collection")
                    } catch {
                        print("[JSONImport]   ⚠️ Could not decode collectedVersionIds: \(error)")
                    }
                }
            }
            // Also cache by componentData.id for linking to publications
            submissionMap[componentData.id] = submission
            print("[JSONImport]   Cached submission with component ID: \(componentData.id)")
            
            modelContext.insert(submission)
        }
        
        print("[JSONImport] ✅ Created \(collectionCount) collections/submissions")
        print("[JSONImport]   Submission IDs cached: \(submissionMap.keys.joined(separator: ", "))")
        
        // Now link files to submissions by examining collectedVersionData in versions
        print("[JSONImport] Linking files to collections...")
        var linkedCount = 0
        var versionsProcessed = 0
        var versionsWithCollections = 0
        
        for (versionId, version) in versionMap {
            guard let textFile = version.textFile else { continue }
            versionsProcessed += 1
            
            // Find the corresponding version data to get collectedVersionData
            for textFileData in data.textFileDatas {
                for versionData in textFileData.versions {
                    guard versionData.id == versionId else { continue }
                    
                    if let collectedVersionData = versionData.collectedVersionData, !collectedVersionData.isEmpty {
                        versionsWithCollections += 1
                        print("[JSONImport]   Version \(versionId) has \(collectedVersionData.count) collection(s)")
                        
                        // Link this version to collections
                        for collectedData in collectedVersionData {
                            // Use the CollectedVersion ID to find which collection this belongs to
                            let collectedVersionId = collectedData.id
                            print("[JSONImport]     CollectedVersion ID: \(collectedVersionId)")
                            
                            // Look up which textCollection this CollectedVersion belongs to
                            if let textCollectionId = collectedVersionToCollectionMap[collectedVersionId] {
                                print("[JSONImport]     Found mapping to textCollection ID: \(textCollectionId)")
                                
                                if let submission = submissionMap[textCollectionId] {
                                    // Create submitted file link
                                    let submittedFile = SubmittedFile(
                                        submission: submission,
                                        textFile: textFile,
                                        version: version,
                                        status: .pending
                                    )
                                    modelContext.insert(submittedFile)
                                    linkedCount += 1
                                    print("[JSONImport]     ✅ Linked file '\(textFile.name)' to collection '\(submission.name ?? "unnamed")'")
                                } else {
                                    print("[JSONImport]     ⚠️ Could not find submission for textCollection ID: \(textCollectionId)")
                                }
                            } else {
                                print("[JSONImport]     ⚠️ CollectedVersion ID not in mapping. Available mappings: \(collectedVersionToCollectionMap.count)")
                            }
                        }
                    }
                }
            }
        }
        
        print("[JSONImport]   Processed \(versionsProcessed) versions, \(versionsWithCollections) had collections")
        print("[JSONImport] ✅ Linked \(linkedCount) files to collections")
        
        print("[JSONImport] ✅ Linked \(linkedCount) files to collections")
    }
    
    // MARK: - Link Collection Submissions
    
    private func linkCollectionSubmissions(from data: WritingShedData, into project: Project) throws {
        print("[JSONImport] Starting submission-to-publication linking")
        var linkedCount = 0
        
        for componentData in data.collectionComponentDatas {
            // Only process WS_Collection_Entity (collections with textCollectionData)
            // WS_Submission_Entity are publications and don't need submission linking
            guard componentData.type == "WS_Collection_Entity" else { continue }
            
            // Check if this collection has textCollectionData (means it contains files)
            guard let textCollectionId = componentData.textCollectionData?.id else {
                print("[JSONImport]   ⚠️ Collection \(componentData.id) has no textCollectionData, skipping")
                continue
            }
            
            // Get the submission (collection) using the textCollectionData ID
            guard let submission = submissionMap[textCollectionId] else {
                print("[JSONImport]   ⚠️ Could not find submission for textCollection ID: \(textCollectionId)")
                continue
            }
            
            // Check if there are collectionSubmissionIds linking to publications
            if let submissionIds = componentData.collectionSubmissionIds,
               submissionIds.count > 0,
               let links = try? PropertyListDecoder().decode([String].self, from: submissionIds),
               !links.isEmpty {
                
                print("[JSONImport]   Collection '\(componentData.id)' has \(links.count) submission link(s)")
                
                // Link to publication(s)
                // Note: In the old system, collections could be linked to multiple publications
                // but in the new system, a submission belongs to one publication
                // We'll take the first one
                for fullLinkId in links {
                    // Strip the project prefix from the linkId
                    // Format: "ProjectName (timestamp)ActualComponentID"
                    let linkId: String
                    if let lastParenIndex = fullLinkId.lastIndex(of: ")") {
                        linkId = String(fullLinkId[fullLinkId.index(after: lastParenIndex)...])
                        print("[JSONImport]     Stripped '\(fullLinkId)' to '\(linkId)'")
                    } else {
                        linkId = fullLinkId
                        print("[JSONImport]     No prefix to strip: '\(linkId)'")
                    }
                    
                    print("[JSONImport]     Looking for publication ID: \(linkId)")
                    print("[JSONImport]     Available publication IDs: \(publicationMap.keys.joined(separator: ", "))")
                    
                    if let publication = publicationMap[linkId] {
                        submission.publication = publication
                        linkedCount += 1
                        print("[JSONImport]   ✅ Linked collection to publication: \(publication.name) (ID: \(linkId))")
                        break // Only one publication per submission in new model
                    } else {
                        print("[JSONImport]     ⚠️ Could not find publication for ID: \(linkId)")
                    }
                }
            } else {
                print("[JSONImport]   Collection '\(componentData.id)' has no publication links (standalone collection)")
            }
        }
        
        print("[JSONImport] ✅ Linked \(linkedCount) submissions to publications")
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
        // Debug: Print data characteristics
        print("[JSONImport] 🔍 Data size: \(data.count) bytes, plain text length: \(plainText.count) chars")
        if data.count > 0 {
            let preview = data.prefix(50)
            print("[JSONImport] 🔍 Data preview (hex): \(preview.map { String(format: "%02X", $0) }.joined(separator: " "))")
            if let previewString = String(data: preview, encoding: .utf8) {
                print("[JSONImport] 🔍 Data preview (UTF8): \(previewString.prefix(50))")
            }
        }
        
        // FIRST: Try RTF format (most common format from old Writing Shed)
        do {
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.rtf
            ]
            let attributedString = try NSAttributedString(data: data, options: options, documentAttributes: nil)
            if attributedString.length > 0 {
                print("[JSONImport] ✅ Decoded RTF attributed string (\(attributedString.length) chars)")
                return attributedString
            }
        } catch let error {
            print("[JSONImport] ❌ RTF decode failed: \(error.localizedDescription)")
        }
        
        // SECOND: Try PropertyList format
        do {
            if let plistObject = try PropertyListSerialization.propertyList(from: data, format: nil) as? Data {
                print("[JSONImport] 🔍 PropertyList contains Data of \(plistObject.count) bytes")
                // The plist contains archived NSAttributedString data
                if let attributedString = try? NSKeyedUnarchiver.unarchivedObject(
                    ofClass: NSAttributedString.self,
                    from: plistObject
                ) {
                    print("[JSONImport] ✅ Decoded attributed string from PropertyList format (\(attributedString.length) chars)")
                    return attributedString
                } else {
                    print("[JSONImport] ❌ PropertyList decode: NSKeyedUnarchiver failed")
                }
            } else {
                print("[JSONImport] 🔍 PropertyList exists but is not Data type")
            }
        } catch let error {
            print("[JSONImport] ❌ PropertyList decode failed: \(error.localizedDescription)")
        }
        
        // THIRD: Try direct NSKeyedUnarchiver (for newer formats)
        do {
            if let attributedString = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: NSAttributedString.self,
                from: data
            ) {
                print("[JSONImport] ✅ Decoded attributed string directly (\(attributedString.length) chars)")
                return attributedString
            }
        } catch let error {
            print("[JSONImport] ❌ NSKeyedUnarchiver decode failed: \(error.localizedDescription)")
        }
        
        // Fallback to plain text
        print("[JSONImport] ⚠️ Falling back to plain text (\(plainText.count) chars)")
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
