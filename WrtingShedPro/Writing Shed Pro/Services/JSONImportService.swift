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
    
    /// When true, generates new UUIDs for all entities (useful for duplicating projects)
    private let generateNewUUIDs: Bool
    
    // Cache for mapping old IDs to new objects
    private var textFileMap: [String: TextFile] = [:]
    private var versionMap: [String: Version] = [:]
    private var publicationMap: [String: Publication] = [:]
    private var submissionMap: [String: Submission] = [:]
    private var collectedVersionToCollectionMap: [String: String] = [:] // CollectedVersion ID -> TextCollection ID
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, errorHandler: ImportErrorHandler, generateNewUUIDs: Bool = false) {
        self.modelContext = modelContext
        self.errorHandler = errorHandler
        self.generateNewUUIDs = generateNewUUIDs
    }
    
    // MARK: - Main Import Method
    
    /// Import a project from a JSON export file (detects format automatically)
    /// - Parameter fileURL: URL to the JSON file (.wsd or .wsp)
    /// - Returns: The imported project
    /// - Throws: ImportError if import fails
    func importFromJSON(fileURL: URL) throws -> Project {
        #if DEBUG
        print("[JSONImport] ========== IMPORT START ==========")
        print("[JSONImport] File: \(fileURL.lastPathComponent)")
        #endif
        
        // Read JSON file
        let jsonData = try Data(contentsOf: fileURL)
        #if DEBUG
        print("[JSONImport] File size: \(jsonData.count) bytes")
        #endif
        
        // Detect format by trying to decode WSP format first
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // Check file extension first for hint
        let fileExtension = fileURL.pathExtension.lowercased()
        
        if fileExtension == "wsp" {
            // Try WSP format
            do {
                let wspData = try decoder.decode(WSPExportData.self, from: jsonData)
                #if DEBUG
                print("[JSONImport] Detected WSP format (version \(wspData.formatVersion))")
                #endif
                return try importFromWSP(wspData)
            } catch {
                #if DEBUG
                print("[JSONImport] WSP decode failed: \(error), trying legacy format")
                #endif
            }
        }
        
        // Try legacy WSD format (also used for .json files)
        return try importFromLegacyWSD(jsonData: jsonData)
    }
    
    /// Import from Writing Shed Pro native format (.wsp)
    private func importFromWSP(_ data: WSPExportData) throws -> Project {
        #if DEBUG
        print("[JSONImport] ===== WSP IMPORT =====")
        print("[JSONImport] Project Name: \(data.project.name)")
        print("[JSONImport] Format Version: \(data.formatVersion)")
        print("[JSONImport] Folders: \(data.folders.count)")
        #endif
        
        // Create project
        let projectType = ProjectType(rawValue: data.project.type) ?? .prose
        var projectName = data.project.name
        projectName = ensureUniqueName(projectName)
        
        let project = Project(
            name: projectName,
            type: projectType,
            creationDate: data.project.creationDate ?? Date(),
            details: data.project.details,
            notes: data.project.notes
        )
        project.modifiedDate = data.project.modifiedDate ?? Date()
        project.statusRaw = data.project.status
        project.fictionClassRaw = data.project.fictionClass
        project.useMonomyth = data.project.useMonomyth
        
        modelContext.insert(project)
        
        // Create ID maps for linking
        var textFileMap: [String: TextFile] = [:]
        var versionMap: [String: Version] = [:]
        var publicationMap: [String: Publication] = [:]
        
        // Import folders (includes text files and versions)
        for folderData in data.folders {
            let folder = importWSPFolder(folderData, project: project, parentFolder: nil, textFileMap: &textFileMap, versionMap: &versionMap)
            modelContext.insert(folder)
        }
        
        // Import publications
        for pubData in data.publications {
            let publication = Publication(
                id: generateNewUUIDs ? UUID() : (UUID(uuidString: pubData.id) ?? UUID()),
                name: pubData.name,
                type: pubData.type.flatMap { PublicationType(rawValue: $0) } ?? .magazine,
                url: pubData.url,
                notes: pubData.notes,
                deadline: pubData.deadline,
                project: project
            )
            publication.createdDate = pubData.createdDate
            publication.modifiedDate = pubData.modifiedDate
            publicationMap[pubData.id] = publication
            modelContext.insert(publication)
        }
        
        // Import submissions
        for subData in data.submissions {
            let submission = Submission(
                id: generateNewUUIDs ? UUID() : (UUID(uuidString: subData.id) ?? UUID()),
                publication: subData.publicationId.flatMap { publicationMap[$0] },
                project: project,
                submittedDate: subData.submittedDate,
                notes: subData.notes
            )
            submission.name = subData.name
            submission.collectionDescription = subData.collectionDescription
            submission.isCollection = subData.isCollection
            submission.userOrder = subData.userOrder
            submission.createdDate = subData.createdDate
            submission.modifiedDate = subData.modifiedDate
            
            modelContext.insert(submission)
            
            // Import submitted files
            for sfData in subData.submittedFiles {
                let submittedFile = SubmittedFile(
                    id: generateNewUUIDs ? UUID() : (UUID(uuidString: sfData.id) ?? UUID()),
                    submission: submission,
                    textFile: sfData.textFileId.flatMap { textFileMap[$0] },
                    version: sfData.versionId.flatMap { versionMap[$0] },
                    status: sfData.status.flatMap { SubmissionStatus(rawValue: $0) } ?? .pending,
                    statusDate: sfData.statusDate,
                    statusNotes: sfData.statusNotes,
                    project: project
                )
                submittedFile.createdDate = sfData.createdDate
                submittedFile.modifiedDate = sfData.modifiedDate
                modelContext.insert(submittedFile)
            }
        }
        
        // Save
        try modelContext.save()
        
        #if DEBUG
        print("[JSONImport] ===== WSP IMPORT COMPLETE =====")
        #endif
        
        return project
    }
    
    /// Import a folder from WSP format (recursive)
    private func importWSPFolder(_ data: WSPFolderData, project: Project, parentFolder: Folder?, textFileMap: inout [String: TextFile], versionMap: inout [String: Version]) -> Folder {
        let folder = Folder(
            name: data.name,
            project: parentFolder == nil ? project : nil,
            parentFolder: parentFolder,
            userOrder: data.userOrder
        )
        folder.id = generateNewUUIDs ? UUID() : (UUID(uuidString: data.id) ?? UUID())
        
        // Import text files
        for tfData in data.textFiles {
            let textFile = importWSPTextFile(tfData, folder: folder, versionMap: &versionMap)
            textFileMap[tfData.id] = textFile
            modelContext.insert(textFile)
        }
        
        // Import subfolders recursively
        for subfolderData in data.subfolders {
            let subfolder = importWSPFolder(subfolderData, project: project, parentFolder: folder, textFileMap: &textFileMap, versionMap: &versionMap)
            modelContext.insert(subfolder)
        }
        
        return folder
    }
    
    /// Import a text file from WSP format
    private func importWSPTextFile(_ data: WSPTextFileData, folder: Folder, versionMap: inout [String: Version]) -> TextFile {
        let textFile = TextFile()
        textFile.id = generateNewUUIDs ? UUID() : (UUID(uuidString: data.id) ?? UUID())
        textFile.name = data.name
        textFile.createdDate = data.createdDate
        textFile.modifiedDate = data.modifiedDate
        textFile.currentVersionIndex = data.currentVersionIndex
        textFile.userOrder = data.userOrder
        textFile.workflowStatusRaw = data.workflowStatus
        textFile.poetryFormId = data.poetryFormId.flatMap { UUID(uuidString: $0) }
        textFile.poetryFormName = data.poetryFormName
        textFile.parentFolder = folder
        
        // Clear auto-created version
        textFile.versions = []
        
        // Import versions
        for vData in data.versions {
            let version = importWSPVersion(vData)
            version.textFile = textFile
            versionMap[vData.id] = version
            modelContext.insert(version)
        }
        
        return textFile
    }
    
    /// Import a version from WSP format
    private func importWSPVersion(_ data: WSPVersionData) -> Version {
        let version = Version(
            content: data.content,
            versionNumber: data.versionNumber,
            comment: data.comment
        )
        version.id = generateNewUUIDs ? UUID() : (UUID(uuidString: data.id) ?? UUID())
        version.createdDate = data.createdDate
        version.notes = data.notes
        
        // Decode formatted content from base64
        if let base64 = data.formattedContentBase64,
           let rtfData = Data(base64Encoded: base64) {
            version.formattedContent = rtfData
        }
        
        // Import comments
        for cData in data.comments {
            let comment = CommentModel(
                id: generateNewUUIDs ? UUID() : (UUID(uuidString: cData.id) ?? UUID()),
                version: version,
                characterPosition: cData.characterPosition,
                attachmentID: generateNewUUIDs ? UUID() : (UUID(uuidString: cData.attachmentID) ?? UUID()),
                text: cData.text,
                author: cData.author,
                createdAt: cData.createdAt,
                resolvedAt: cData.resolvedAt
            )
            modelContext.insert(comment)
        }
        
        // Import footnotes
        for fData in data.footnotes {
            let footnote = FootnoteModel(
                id: generateNewUUIDs ? UUID() : (UUID(uuidString: fData.id) ?? UUID()),
                version: version,
                characterPosition: fData.characterPosition,
                attachmentID: generateNewUUIDs ? UUID() : (UUID(uuidString: fData.attachmentID) ?? UUID()),
                text: fData.text,
                number: fData.number,
                createdAt: fData.createdAt,
                modifiedAt: fData.modifiedAt
            )
            modelContext.insert(footnote)
        }
        
        return version
    }
    
    /// Import from legacy Writing Shed format (.wsd/.json)
    private func importFromLegacyWSD(jsonData: Data) throws -> Project {
        let decoder = JSONDecoder()
        let writingShedData = try decoder.decode(WritingShedData.self, from: jsonData)
        
        // Debug logging
        #if DEBUG
        print("[JSONImport] ===== FILE STRUCTURE =====")
        #endif
        #if DEBUG
        print("[JSONImport] Project Name: \(writingShedData.projectName)")
        #endif
        #if DEBUG
        print("[JSONImport] Project Model: \(writingShedData.projectModel)")
        #endif
        #if DEBUG
        print("[JSONImport] Text Files Count: \(writingShedData.textFileDatas.count)")
        #endif
        #if DEBUG
        print("[JSONImport] Collection Components Count: \(writingShedData.collectionComponentDatas.count)")
        #endif
        #if DEBUG
        print("[JSONImport] Scene Components Count: \(writingShedData.sceneComponentDatas.count)")
        #endif
        
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
        #if DEBUG
        print("[JSONImport] - Submissions: \(submissionCount)")
        #endif
        #if DEBUG
        print("[JSONImport] - Text Collections: \(textCollectionCount)")
        #endif
        
        // Validate project name
        guard !writingShedData.projectName.isEmpty else {
            throw ImportError.missingContent
        }
        
        // Create new project
        let project = try createProject(from: writingShedData)
        modelContext.insert(project)
        
        #if DEBUG
        print("[JSONImport] Created project with type: \(project.type)")
        #endif
        
        // Create all standard folders for the project type
        createStandardFolders(for: project)
        
        // Import text files and versions
        try importTextFiles(from: writingShedData, into: project)
        
        // Import publications (submissions in old terminology)
        try importPublications(from: writingShedData, into: project)
        
        // Import collections (text collections)
        try importCollections(from: writingShedData, into: project)
        
        // NOTE: We do NOT call importCollectionSubmissions() - see COLLECTION_SUBMISSION_FIX.md
        // In legacy app, WS_CollectionSubmission_Entity is just metadata linking a collection to a publication
        // The collection itself (WS_Collection_Entity) is what appears in Submissions folder
        // The isCollection flag on the WS_Collection_Entity determines folder placement:
        //   - isCollection = true (no collectionSubmissionIds) → Collections folder
        //   - isCollection = false (has collectionSubmissionIds) → Submissions folder
        // Calling importCollectionSubmissions() would create DUPLICATE submission records
        // try importCollectionSubmissions(from: writingShedData, into: project)
        
        // Save
        try modelContext.save()
        
        #if DEBUG
        print("[JSONImport] ===== IMPORT COMPLETE =====")
        #endif
        #if DEBUG
        print("[JSONImport] Warnings: \(errorHandler.warnings.count)")
        #endif
        if !errorHandler.warnings.isEmpty {
            #if DEBUG
            print("[JSONImport] Warnings:")
            #endif
            for (index, warning) in errorHandler.warnings.enumerated() {
                #if DEBUG
                print("[JSONImport]   \(index + 1). \(warning)")
                #endif
            }
        }
        #if DEBUG
        print("[JSONImport] ========== IMPORT END ==========")
        #endif
        
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
        // Take the part AFTER <> if it exists
        if cleaned.contains("<>") {
            let components = cleaned.components(separatedBy: "<>")
            if components.count > 1 {
                cleaned = components[1]
            }
        }
        
        // Remove date/timestamp prefix without parentheses: "03/06/2016, 09:09" before text
        // Pattern: date and time at the start (no parentheses)
        let prefixPattern = "^[\\d/]+,\\s*[\\d:]+"
        if let regex = try? NSRegularExpression(pattern: prefixPattern) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, range: range, withTemplate: "")
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
        
        #if DEBUG
        print("[JSONImport] ⚠️ Duplicate project name detected. Renamed '\(name)' to '\(uniqueName)'")
        #endif
        
        return uniqueName
    }
    
    private func mapProjectType(_ modelString: String) -> ProjectType {
        // Handle numeric values (legacy enum)
        let numericMapping: [String: ProjectType] = [
            "35": .poetry,   // WS_Poetry_Project_Value
            "36": .fiction,  // WS_Novel_Project_Value (legacy novel -> fiction)
            "37": .drama,    // WS_Script_Project_Value (legacy script -> drama)
            "38": .fiction   // WS_Short_Story_Project_Value (legacy shortStory -> fiction)
        ]
        
        // Check numeric first
        if let type = numericMapping[modelString] {
            return type
        }
        
        // Fall back to string names
        let typeMapping: [String: ProjectType] = [
            "novel": .fiction,
            "shortstory": .fiction,
            "short story": .fiction,
            "fiction": .fiction,
            "poetry": .poetry,
            "script": .drama,
            "drama": .drama,
            "prose": .prose,
            "generalpurpose": .prose,
            "general purpose": .prose,
            "blank": .prose  // Legacy support
        ]
        
        return typeMapping[modelString.lowercased()] ?? .prose
    }
    
    // MARK: - Text Files Import
    
    private func importTextFiles(from data: WritingShedData, into project: Project) throws {
        #if DEBUG
        print("[JSONImport] Starting text file import for \(data.textFileDatas.count) files")
        #endif
        
        // Get the content folder for this project type
        let contentFolderNameForProject = contentFolderName(for: project.type)
        let contentFolder = getOrCreateFolder(name: contentFolderNameForProject, in: project)
        
        for (index, textFileData) in data.textFileDatas.enumerated() {
            #if DEBUG
            print("[JSONImport] Processing text file \(index + 1)/\(data.textFileDatas.count)")
            #endif
            #if DEBUG
            print("[JSONImport]   ID: \(textFileData.id)")
            #endif
            #if DEBUG
            print("[JSONImport]   Type: \(textFileData.type)")
            #endif
            #if DEBUG
            print("[JSONImport]   Versions: \(textFileData.versions.count)")
            #endif
            
            // Decode text file metadata
            guard let textFileMetadata = try? decodeTextFileMetadata(textFileData.textFile) else {
                errorHandler.addWarning("Failed to decode text file metadata for ID: \(textFileData.id)")
                #if DEBUG
                print("[JSONImport]   ⚠️ Failed to decode metadata")
                #endif
                continue
            }
            
            #if DEBUG
            print("[JSONImport]   Name: \(textFileMetadata.name)")
            #endif
            #if DEBUG
            print("[JSONImport]   Original Folder: \(textFileMetadata.folderName)")
            #endif
            
            // Determine workflow status from original folder name
            var workflowStatus = mapFolderNameToWorkflowStatus(textFileMetadata.folderName)
            
            // Check if the folder is a content folder (Poems, Scenes, Scripts, Sections, Prose, Files)
            let isContentFolder = ["poems", "scenes", "scripts", "sections", "prose", "files"].contains(textFileMetadata.folderName.lowercased())
            
            // Determine target folder:
            // - Workflow folders (Draft, Ready, etc.) → content folder with status
            // - Content folders (Poems, Scenes, Scripts, Files) → content folder with default .draft status
            // - Other folders (Research, Collections, etc.) → keep original folder
            let targetFolder: Folder
            if workflowStatus != nil {
                // This was a workflow folder, put file in content folder
                targetFolder = contentFolder
                #if DEBUG
                print("[JSONImport]   Mapped to content folder with status: \(workflowStatus?.rawValue ?? "nil")")
                #endif
            } else if isContentFolder {
                // This is a content folder, put file there with default .draft status
                targetFolder = contentFolder
                workflowStatus = .draft
                #if DEBUG
                print("[JSONImport]   Content folder file, defaulting to .draft status")
                #endif
            } else {
                // Keep the original folder (Research, Collections, etc.)
                targetFolder = getOrCreateFolder(name: textFileMetadata.folderName, in: project)
            }
            
            // Create TextFile
            let textFile = TextFile()
            textFile.name = textFileMetadata.name
            textFile.createdDate = textFileMetadata.createdDate ?? Date()
            textFile.modifiedDate = textFileMetadata.modifiedDate ?? Date()
            textFile.parentFolder = targetFolder
            textFile.workflowStatus = workflowStatus
            
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
        #if DEBUG
        print("[JSONImport]   Processing \(versionDatas.count) versions for sorting")
        #endif
        
        // First, create all versions with their dates parsed
        var versionsWithDates: [(version: Version, date: Date, data: VersionData)] = []
        
        for (index, versionData) in versionDatas.enumerated() {
            let version = Version()
            version.textFile = textFile
            
            // Parse creation date from version string
            // The version field contains a date string like "2024-12-10 14:30:00 +0000"
            #if DEBUG
            print("[JSONImport]     Version \(index + 1) raw date string: '\(versionData.version)'")
            #endif
            let createdDate = parseDateFromVersionString(versionData.version)
            #if DEBUG
            print("[JSONImport]     Parsed to: \(createdDate)")
            #endif
            version.createdDate = createdDate
            
            // Decode notes (from WS_Version_Entity notes field)
            if let notesString = try? decodeAttributedString(from: versionData.notes, plainText: versionData.notesText) {
                version.notes = notesString.string
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
            
            versionsWithDates.append((version: version, date: createdDate, data: versionData))
        }
        
        // Sort versions by date (oldest first) and assign version numbers
        let sortedVersions = versionsWithDates.sorted { $0.date < $1.date }
        
        #if DEBUG
        print("[JSONImport]   Sorted order:")
        #endif
        for (index, item) in sortedVersions.enumerated() {
            item.version.versionNumber = index + 1
            #if DEBUG
            print("[JSONImport]     Version \(index + 1): date=\(item.date), raw='\(item.data.version)'")
            #endif
            
            // Cache for later linking
            versionMap[item.data.id] = item.version
            
            modelContext.insert(item.version)
        }
        
        #if DEBUG
        print("[JSONImport]   ✅ Created \(sortedVersions.count) versions in chronological order")
        #endif
    }
    
    /// Parse date from version string (Core Data timestamp format)
    private func parseDateFromVersionString(_ versionString: String) -> Date {
        // The version string is actually a JSON object containing date information
        // Example: {"date": 783237732.3579321, "dateLastUpdated": 785361073.1350951, ...}
        
        if let jsonData = versionString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let dateValue = json["date"] as? Double {
            // Core Data stores dates as TimeInterval since reference date (Jan 1, 2001)
            let date = Date(timeIntervalSinceReferenceDate: dateValue)
            #if DEBUG
            print("[JSONImport]       Parsed JSON date: \(dateValue) -> \(date)")
            #endif
            return date
        }
        
        // Fallback: try to parse as a numeric timestamp
        if let timestamp = Double(versionString) {
            // Core Data stores dates as TimeInterval since reference date (Jan 1, 2001)
            let date = Date(timeIntervalSinceReferenceDate: timestamp)
            // Check if this is a reasonable date (between 2000 and 2030)
            if date.timeIntervalSince1970 > 946684800 && date.timeIntervalSince1970 < 1893456000 {
                return date
            }
            
            // If reference date doesn't work, try Unix timestamp (since 1970)
            let unixDate = Date(timeIntervalSince1970: timestamp)
            if unixDate.timeIntervalSince1970 > 946684800 && unixDate.timeIntervalSince1970 < 1893456000 {
                return unixDate
            }
        }
        
        // Try multiple date string formats
        let formatters = [
            // ISO 8601 with timezone
            { () -> DateFormatter in
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                return formatter
            }(),
            // ISO 8601 without timezone
            { () -> DateFormatter in
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                return formatter
            }(),
            // Timestamp as string
            { () -> DateFormatter in
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                return formatter
            }()
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: versionString) {
                #if DEBUG
                print("[JSONImport]       Successfully parsed with format: \(formatter.dateFormat ?? "unknown")")
                #endif
                return date
            }
        }
        
        #if DEBUG
        print("[JSONImport]   ⚠️ Could not parse version date: '\(versionString)', using current date")
        #endif
        return Date()
    }
    
    // MARK: - Publications Import
    
    private func importPublications(from data: WritingShedData, into project: Project) throws {
        #if DEBUG
        print("[JSONImport] Starting publication import from \(data.collectionComponentDatas.count) collection components")
        #endif
        
        var publicationCount = 0
        for componentData in data.collectionComponentDatas {
            // Only process submission entities (publications)
            guard componentData.type == "WS_Submission_Entity" else { continue }
            
            publicationCount += 1
            #if DEBUG
            print("[JSONImport] Processing publication \(publicationCount), ID: \(componentData.id)")
            #endif
            
            // Decode publication metadata
            guard let metadata = try? decodePublicationMetadata(componentData.collectionComponent) else {
                errorHandler.addWarning("Failed to decode publication metadata")
                #if DEBUG
                print("[JSONImport] ⚠️ Failed to decode publication metadata")
                #endif
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
            
            #if DEBUG
            print("[JSONImport]   Publication name: \(publication.name), type: \(String(describing: publication.type))")
            #endif
            #if DEBUG
            print("[JSONImport]   Caching publication with component ID: \(componentData.id)")
            #endif
            
            // Cache for later linking - use component ID and textCollectionData ID
            publicationMap[componentData.id] = publication
            
            // Also cache by textCollectionData ID if present
            if let textCollectionId = componentData.textCollectionData?.id {
                publicationMap[textCollectionId] = publication
                #if DEBUG
                print("[JSONImport]   Also caching with textCollection ID: \(textCollectionId)")
                #endif
            }
            
            modelContext.insert(publication)
        }
        
        #if DEBUG
        print("[JSONImport] ✅ Imported \(publicationCount) publications")
        #endif
        #if DEBUG
        print("[JSONImport]   Publication IDs cached: \(publicationMap.keys.joined(separator: ", "))")
        #endif
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
        #if DEBUG
        print("[JSONImport] Starting collections/submissions import")
        #endif
        #if DEBUG
        print("[JSONImport] Total collectionComponentDatas: \(data.collectionComponentDatas.count)")
        #endif
        
        // First, build a GLOBAL map of all CollectionSubmissionData from ALL components
        // The collectionSubmissionsDatas might be stored on WS_Submission_Entity or WS_Collection_Entity
        var globalCollectionSubmissionMap: [String: CollectionSubmissionData] = [:]
        for componentData in data.collectionComponentDatas {
            if let submissionDatas = componentData.collectionSubmissionsDatas {
                for submissionData in submissionDatas {
                    // Store by both raw ID and stripped ID
                    globalCollectionSubmissionMap[submissionData.id] = submissionData
                    // Also strip project prefix if present
                    if let lastParenIndex = submissionData.id.lastIndex(of: ")") {
                        let cleanId = String(submissionData.id[submissionData.id.index(after: lastParenIndex)...])
                        globalCollectionSubmissionMap[cleanId] = submissionData
                    }
                }
            }
        }
        #if DEBUG
        print("[JSONImport] Built global CollectionSubmission map with \(globalCollectionSubmissionMap.count) entries")
        if !globalCollectionSubmissionMap.isEmpty {
            print("[JSONImport]   Keys: \(globalCollectionSubmissionMap.keys.joined(separator: ", "))")
        }
        #endif
        
        // Count how many are collections vs submissions
        let collections = data.collectionComponentDatas.filter { $0.type == "WS_Collection_Entity" }
        let submissions = data.collectionComponentDatas.filter { $0.type == "WS_Submission_Entity" }
        #if DEBUG
        print("[JSONImport] Found \(collections.count) WS_Collection_Entity and \(submissions.count) WS_Submission_Entity")
        #endif
        
        var collectionCount = 0
        for componentData in data.collectionComponentDatas {
            // Only process WS_Collection_Entity (NOT WS_Submission_Entity which are publications)
            guard componentData.type == "WS_Collection_Entity" else { continue }
            
            collectionCount += 1
            #if DEBUG
            print("[JSONImport] Processing collection/submission \(collectionCount)")
            #endif
            
            // FIX: Get the collection name from collectionComponent, NOT textCollectionData
            // textCollectionData contains the "Texts in [CollectionName]" internal entity
            // collectionComponent contains the actual collection metadata
            var collectionName = "Untitled Collection"
            var submittedDate = Date()
//            var groupName: String?
            
            // Decode the collectionComponent JSON to get the collection name, date, and groupName
            if let collectionDict = try? JSONSerialization.jsonObject(
                with: componentData.collectionComponent.data(using: .utf8)!
            ) as? [String: Any] {
                collectionName = collectionDict["name"] as? String ?? collectionName
//                groupName = collectionDict["groupName"] as? String
                
                // Get date - try multiple possible keys
                if let timestamp = collectionDict["dateCreated"] as? TimeInterval {
                    submittedDate = Date(timeIntervalSinceReferenceDate: timestamp)
                } else if let timestamp = collectionDict["createdOn"] as? TimeInterval {
                    submittedDate = Date(timeIntervalSinceReferenceDate: timestamp)
                }
            }
            
            // Create Submission (collection in new model)
            // Collections have publication = nil (NOT submitted to a publication)
            let submission = Submission()
            submission.name = collectionName  // Set the collection name!
            submission.submittedDate = submittedDate
            submission.project = project
            
            // In legacy app, folder placement is determined by collectionSubmissions relationship:
            //   Collections folder: WS_Collection_Entity with no collectionSubmissionIds (not yet submitted)
            //   Submissions folder: WS_Collection_Entity with collectionSubmissionIds (has been submitted)
            // Check if this collection has collectionSubmissionIds - need to decode the plist to check if empty
            var hasSubmissionIds = false
            var linkedPublicationId: String?
            
            if let collectionSubmissionIdsData = componentData.collectionSubmissionIds {
                do {
                    let submissionIds = try PropertyListDecoder().decode([String].self, from: collectionSubmissionIdsData)
                    hasSubmissionIds = !submissionIds.isEmpty
                    
                    #if DEBUG
                    print("[JSONImport]   collectionSubmissionIds decoded: \(submissionIds)")
                    #endif
                    
                    // If we have submission IDs, try to find the publication
                    // First try the global map (built from ALL components), then fall back to local
                    if hasSubmissionIds {
                        #if DEBUG
                        print("[JSONImport]   Looking for publication link using global map (\(globalCollectionSubmissionMap.count) entries)")
                        #endif
                        
                        // Find the first collectionSubmission that matches one of our IDs
                        for submissionId in submissionIds {
                            // Strip any project prefix from submissionId
                            let cleanSubmissionId: String
                            if let lastParenIndex = submissionId.lastIndex(of: ")") {
                                cleanSubmissionId = String(submissionId[submissionId.index(after: lastParenIndex)...])
                            } else {
                                cleanSubmissionId = submissionId
                            }
                            
                            #if DEBUG
                            print("[JSONImport]   Looking for collectionSubmission with ID: \(cleanSubmissionId) (original: \(submissionId))")
                            #endif
                            
                            // Try global map first (checks both raw and clean ID)
                            let collectionSubmissionData = globalCollectionSubmissionMap[submissionId] 
                                ?? globalCollectionSubmissionMap[cleanSubmissionId]
                                ?? componentData.collectionSubmissionsDatas?.first(where: { $0.id == cleanSubmissionId || $0.id == submissionId })
                            
                            if let collectionSubmissionData = collectionSubmissionData {
                                // The submissionId in CollectionSubmissionData may also have a project prefix
                                let rawPubId = collectionSubmissionData.submissionId
                                let cleanPubId: String
                                if let lastParenIndex = rawPubId.lastIndex(of: ")") {
                                    cleanPubId = String(rawPubId[rawPubId.index(after: lastParenIndex)...])
                                } else {
                                    cleanPubId = rawPubId
                                }
                                
                                #if DEBUG
                                print("[JSONImport]   Found collectionSubmission, raw submissionId: \(rawPubId), cleaned: \(cleanPubId)")
                                print("[JSONImport]   Available publicationMap keys: \(publicationMap.keys.joined(separator: ", "))")
                                #endif
                                
                                // Try both original and cleaned ID
                                if publicationMap[rawPubId] != nil {
                                    linkedPublicationId = rawPubId
                                } else if publicationMap[cleanPubId] != nil {
                                    linkedPublicationId = cleanPubId
                                } else {
                                    linkedPublicationId = cleanPubId  // Will fail but at least we log it
                                }
                                
                                #if DEBUG
                                print("[JSONImport]   Using publication ID: \(linkedPublicationId ?? "nil")")
                                #endif
                                break
                            }
                        }
                        
                        if linkedPublicationId == nil {
                            #if DEBUG
                            print("[JSONImport]   ⚠️ No matching collectionSubmission found in global map or local data")
                            #endif
                        }
                    }
                } catch {
                    #if DEBUG
                    print("[JSONImport]   ⚠️ Could not decode collectionSubmissionIds: \(error)")
                    #endif
                }
            }
            
            submission.isCollection = !hasSubmissionIds
            
            // Link to publication if this is a submission (not a collection)
            if hasSubmissionIds {
                if let pubId = linkedPublicationId, let publication = publicationMap[pubId] {
                    submission.publication = publication
                    #if DEBUG
                    print("[JSONImport]   ✅ Linked to publication: \(publication.name)")
                    #endif
                } else {
                    #if DEBUG
                    print("[JSONImport]   ⚠️ Has collectionSubmissionIds but could not find publication. ID: \(linkedPublicationId ?? "nil")")
                    #endif
                    // Still mark as submission (not collection) so it appears in Submissions folder
                }
                #if DEBUG
                print("[JSONImport]   ✅ Has collectionSubmissionIds - will appear in Submissions folder")
                #endif
            } else {
                submission.publication = nil  // Explicitly set to nil for collections
                #if DEBUG
                print("[JSONImport]   ✅ No collectionSubmissionIds - will appear in Collections folder")
                #endif
            }
            
            // Decode notes
            if let notesString = try? decodeAttributedString(from: componentData.notes, plainText: componentData.notesText) {
                submission.notes = notesString.string
            }
            
            #if DEBUG
            print("[JSONImport]   Collection name: \(collectionName)")
            #endif
            #if DEBUG
            print("[JSONImport]   Component ID: \(componentData.id)")
            #endif
            if let textCollectionData = componentData.textCollectionData {
                #if DEBUG
                print("[JSONImport]   TextCollection ID: \(textCollectionData.id)")
                #endif
            }
            
            // Cache for linking files and publications
            // IMPORTANT: Cache by textCollectionData.id since that's what versions reference
            if let textCollectionData = componentData.textCollectionData {
                submissionMap[textCollectionData.id] = submission
                #if DEBUG
                print("[JSONImport]   Cached submission with textCollection ID: \(textCollectionData.id)")
                #endif
                
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
                        #if DEBUG
                        print("[JSONImport]   Mapped \(collectedVersionIds.count) collectedVersion(s) to this collection")
                        #endif
                    } catch {
                        #if DEBUG
                        print("[JSONImport]   ⚠️ Could not decode collectedVersionIds: \(error)")
                        #endif
                    }
                }
            }
            // Also cache by componentData.id for linking to publications
            submissionMap[componentData.id] = submission
            #if DEBUG
            print("[JSONImport]   Cached submission with component ID: \(componentData.id)")
            #endif
            
            modelContext.insert(submission)
        }
        
        #if DEBUG
        print("[JSONImport] ✅ Created \(collectionCount) collections/submissions")
        #endif
        #if DEBUG
        print("[JSONImport]   Submission IDs cached: \(submissionMap.keys.joined(separator: ", "))")
        #endif
        
        // Now link files to submissions by examining collectedVersionData in versions
        #if DEBUG
        print("[JSONImport] Linking files to collections...")
        #endif
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
                        #if DEBUG
                        print("[JSONImport]   Version \(versionId) has \(collectedVersionData.count) collection(s)")
                        #endif
                        
                        // Link this version to collections
                        for collectedData in collectedVersionData {
                            // Use the CollectedVersion ID to find which collection this belongs to
                            let collectedVersionId = collectedData.id
                            #if DEBUG
                            print("[JSONImport]     CollectedVersion ID: \(collectedVersionId)")
                            #endif
                            
                            // Look up which textCollection this CollectedVersion belongs to
                            if let textCollectionId = collectedVersionToCollectionMap[collectedVersionId] {
                                #if DEBUG
                                print("[JSONImport]     Found mapping to textCollection ID: \(textCollectionId)")
                                #endif
                                
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
                                    #if DEBUG
                                    print("[JSONImport]     ✅ Linked file '\(textFile.name)' to collection '\(submission.name ?? "unnamed")'")
                                    #endif
                                } else {
                                    #if DEBUG
                                    print("[JSONImport]     ⚠️ Could not find submission for textCollection ID: \(textCollectionId)")
                                    #endif
                                }
                            } else {
                                #if DEBUG
                                print("[JSONImport]     ⚠️ CollectedVersion ID not in mapping. Available mappings: \(collectedVersionToCollectionMap.count)")
                                #endif
                            }
                        }
                    }
                }
            }
        }
        
        #if DEBUG
        print("[JSONImport]   Processed \(versionsProcessed) versions, \(versionsWithCollections) had collections")
        #endif
        #if DEBUG
        print("[JSONImport] ✅ Linked \(linkedCount) files to collections")
        #endif
        
        #if DEBUG
        print("[JSONImport] ✅ Linked \(linkedCount) files to collections")
        #endif
    }
    
    // MARK: - Link Collection Submissions
    
    // MARK: - Collection Submissions Import
    
    private func importCollectionSubmissions(from data: WritingShedData, into project: Project) throws {
        #if DEBUG
        print("[JSONImport] Starting collection submissions import")
        #endif
        #if DEBUG
        print("[JSONImport] This processes WS_CollectionSubmission_Entity - collections that were submitted to publications")
        #endif
        #if DEBUG
        print("[JSONImport] Submissions with publication set will appear in Submissions folder")
        #endif
        
        var submissionCount = 0
        var collectionSubmissionMap: [String: CollectionSubmissionData] = [:]
        
        // First, gather all CollectionSubmissionData from all components
        for componentData in data.collectionComponentDatas {
            if let submissionDatas = componentData.collectionSubmissionsDatas {
                for submissionData in submissionDatas {
                    collectionSubmissionMap[submissionData.id] = submissionData
                    #if DEBUG
                    print("[JSONImport]   Found CollectionSubmission ID: \(submissionData.id)")
                    #endif
                }
            }
        }
        
        #if DEBUG
        print("[JSONImport] Found \(collectionSubmissionMap.count) collection submission entities")
        #endif
        
        // Now process each CollectionSubmission to create a new Submission
        for (_, submissionData) in collectionSubmissionMap {
            submissionCount += 1
            #if DEBUG
            print("[JSONImport] Processing CollectionSubmission \(submissionCount): ID \(submissionData.id)")
            #endif
            
            // Decode the collectionSubmission JSON to get metadata
            guard let metadata = try? decodeCollectionSubmissionMetadata(submissionData.collectionSubmission) else {
                errorHandler.addWarning("Failed to decode collection submission metadata for ID: \(submissionData.id)")
                #if DEBUG
                print("[JSONImport]   ⚠️ Failed to decode metadata")
                #endif
                continue
            }
            
            // Find the publication (WS_Submission_Entity)
            guard let publication = publicationMap[submissionData.submissionId] else {
                errorHandler.addWarning("Could not find publication for submission ID: \(submissionData.submissionId)")
                #if DEBUG
                print("[JSONImport]   ⚠️ Could not find publication for ID: \(submissionData.submissionId)")
                #endif
                continue
            }
            
            // Find the source collection
            let sourceCollectionId = submissionData.collectionId
            guard let sourceCollection = submissionMap[sourceCollectionId] else {
                errorHandler.addWarning("Could not find source collection for ID: \(sourceCollectionId)")
                #if DEBUG
                print("[JSONImport]   ⚠️ Could not find source collection for ID: \(sourceCollectionId)")
                #endif
                continue
            }
            
            let collectionName = sourceCollection.name ?? "Unknown Collection"
            let publicationName = publication.name
            
            #if DEBUG
            print("[JSONImport]   Source collection: \(collectionName)")
            #endif
            #if DEBUG
            print("[JSONImport]   Target publication: \(publicationName)")
            #endif
            
            // Create a NEW Submission for this publication submission
            let newSubmission = Submission()
            newSubmission.name = "\(collectionName) → \(publicationName)"
            newSubmission.project = project
            newSubmission.publication = publication  // Having publication set places it in Submissions folder
            newSubmission.isCollection = false  // This is a submission, not a collection
            newSubmission.submittedDate = metadata.submittedDate
            newSubmission.notes = metadata.notes ?? ""
            newSubmission.createdDate = Date()
            newSubmission.modifiedDate = Date()
            
            // Copy files from source collection to new submission
            var filesLinked = 0
            if let sourceFiles = sourceCollection.submittedFiles {
                for submittedFile in sourceFiles {
                    let newFile = SubmittedFile()
                    newFile.submission = newSubmission
                    newSubmission.submittedFiles?.append(newFile)
                    
                    // Link to the same text file and version
                    newFile.textFile = submittedFile.textFile
                    newFile.version = submittedFile.version
                    
                    // Try to get acceptance status from metadata
                    if let textFileId = submittedFile.textFile?.id.uuidString,
                       let acceptedStatus = metadata.acceptedFiles?[textFileId] {
                        newFile.status = acceptedStatus ? .accepted : .pending
                    } else {
                        newFile.status = .pending
                    }
                    
                    modelContext.insert(newFile)
                    filesLinked += 1
                }
            }
            
            #if DEBUG
            print("[JSONImport]   ✅ Created submission with \(filesLinked) files")
            #endif
            modelContext.insert(newSubmission)
        }
        
        #if DEBUG
        print("[JSONImport] ✅ Imported \(submissionCount) collection submissions")
        #endif
    }
    
    private func decodeCollectionSubmissionMetadata(_ json: String) throws -> CollectionSubmissionMetadata {
        guard let jsonData = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw ImportError.decodingFailed
        }
        
        var metadata = CollectionSubmissionMetadata()
        
        // Get submitted date
        if let timestamp = dict["submittedOn"] as? TimeInterval {
            metadata.submittedDate = Date(timeIntervalSinceReferenceDate: timestamp)
        } else if let timestamp = dict["dateSubmitted"] as? TimeInterval {
            metadata.submittedDate = Date(timeIntervalSinceReferenceDate: timestamp)
        }
        
        // Get notes
        metadata.notes = dict["notes"] as? String
        
        // TODO: Extract accepted file information from WS_CollectedVersion_Entity if available
        // This would require additional data in the export
        
        return metadata
    }
    
    struct CollectionSubmissionMetadata {
        var submittedDate: Date = Date()
        var notes: String?
        var acceptedFiles: [String: Bool]? // fileID -> isAccepted
    }
    
    // MARK: - Helper Methods
    
    /// Map old workflow folder names to WorkflowStatus
    private func mapFolderNameToWorkflowStatus(_ folderName: String) -> WorkflowStatus? {
        switch folderName.lowercased() {
        case "draft":
            return .draft
        case "ready":
            return .ready
        case "accepted", "published":
            return .published
        case "set aside", "setaside":
            return .setAside
        default:
            // Submissions, Collections, Research, etc. are functional folders, not workflow status
            return nil
        }
    }
    
    /// Get the content folder name for a project type
    private func contentFolderName(for projectType: ProjectType) -> String {
        switch projectType {
        case .poetry:
            return "Poems"
        case .fiction:
            return "Scenes"
        case .drama:
            return "Scripts"
        case .prose:
            return "Prose"
        }
    }
    
    /// Create all standard folders for a project based on its type
    /// Updated to use new folder structure with workflow status on files
    private func createStandardFolders(for project: Project) {
        let folderNames: [String]
        
        switch project.type {
        case .prose:
            folderNames = [
                "Manuscript",
                "Sections",
                "Prose",
                "Collections",
                "Submissions",
                "Research",
                "Publishers",
                "Agents",
                "Other",
                "Trash"
            ]
            
        case .poetry:
            // New Poetry structure: single Poems folder (workflow is on files)
            folderNames = [
                "Poems",
                "Collections",
                "Submissions",
                "Manuscript",
                "Research",
                "Magazines",
                "Competitions",
                "Commissions",
                "Other",
                "Trash"
            ]
            
        case .fiction:
            // New Fiction structure: single Scenes folder (workflow is on files)
            folderNames = [
                "Scenes",
                "Characters",
                "Locations",
                "Chapters",
                "Collections",
                "Submissions",
                "Plot",
                "Research",
                "Magazines",
                "Competitions",
                "Other",
                "Trash"
            ]
            
        case .drama:
            // New Drama structure: single Scripts folder (workflow is on files)
            folderNames = [
                "Scripts",
                "Collections",
                "Submissions",
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
        
        #if DEBUG
        print("[JSONImport] Created \(folderNames.count) standard folders")
        #endif
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
        // FIRST: Try custom property list format (used by old Writing Shed)
        do {
            if let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]] {
                #if DEBUG
                print("[JSONImport] 🔍 Found custom plist format with \(plist.count) formatting range(s)")
                #endif
                return decodeCustomFormat(plist: plist, plainText: plainText)
            } else if let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                #if DEBUG
                print("[JSONImport] 🔍 Found custom plist format with single range")
                #endif
                return decodeCustomFormat(plist: [plist], plainText: plainText)
            }
        } catch {
            // Not custom format
        }
        
        // SECOND: Try RTF format
        do {
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.rtf
            ]
            let attributedString = try NSAttributedString(data: data, options: options, documentAttributes: nil)
            if attributedString.length > 0 {
                #if DEBUG
                print("[JSONImport] ✅ Decoded RTF attributed string (\(attributedString.length) chars)")
                #endif
                return attributedString
            }
        } catch {
            // Not RTF
        }
        
        // THIRD: Try NSKeyedArchiver format
        do {
            if let attributedString = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: NSAttributedString.self,
                from: data
            ) {
                #if DEBUG
                print("[JSONImport] ✅ Decoded attributed string from NSKeyedArchiver (\(attributedString.length) chars)")
                #endif
                return attributedString
            }
        } catch {
            // Not NSKeyedArchiver
        }
        
        // Fallback to plain text
        #if DEBUG
        print("[JSONImport] ⚠️ Falling back to plain text (\(plainText.count) chars)")
        #endif
        return NSAttributedString(string: plainText)
    }
    
    /// Decode custom property list format used by old Writing Shed
    /// Format: Array of dictionaries with keys: location, length, fontName, fontSize, bold, italic, underline, strikethrough
    private func decodeCustomFormat(plist: [[String: Any]], plainText: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: plainText)
        
        // Apply each formatting range
        for rangeDict in plist {
            guard let location = rangeDict["location"] as? Int,
                  let length = rangeDict["length"] as? Int,
                  location >= 0,
                  location + length <= plainText.count else {
                #if DEBUG
                print("[JSONImport] ⚠️ Invalid range in custom format")
                #endif
                continue
            }
            
            let range = NSRange(location: location, length: length)
            
            // Get font properties
            let fontName = rangeDict["fontName"] as? String ?? "TimesNewRomanPSMT"
            let fontSize = rangeDict["fontSize"] as? CGFloat ?? 18.0
            let bold = (rangeDict["bold"] as? Int ?? 0) != 0 || (rangeDict["bold"] as? Bool ?? false)
            let italic = (rangeDict["italic"] as? Int ?? 0) != 0 || (rangeDict["italic"] as? Bool ?? false)
            
            // Create font with traits
            var font: UIFont
            if bold && italic {
                font = UIFont(name: fontName.replacingOccurrences(of: "PSMT", with: "PS-BoldItalicMT"), size: fontSize)
                    ?? UIFont.boldSystemFont(ofSize: fontSize)
            } else if bold {
                font = UIFont(name: fontName.replacingOccurrences(of: "PSMT", with: "PS-BoldMT"), size: fontSize)
                    ?? UIFont.boldSystemFont(ofSize: fontSize)
            } else if italic {
                font = UIFont(name: fontName.replacingOccurrences(of: "PSMT", with: "PS-ItalicMT"), size: fontSize)
                    ?? UIFont.italicSystemFont(ofSize: fontSize)
            } else {
                font = UIFont(name: fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
            }
            
            attributedString.addAttribute(.font, value: font, range: range)
            
            // Apply underline
            if let underline = rangeDict["underline"] as? Int, underline != 0 {
                attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            } else if let underline = rangeDict["underline"] as? Bool, underline {
                attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
            
            // Apply strikethrough
            if let strikethrough = rangeDict["strikethrough"] as? Int, strikethrough != 0 {
                attributedString.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            } else if let strikethrough = rangeDict["strikethrough"] as? Bool, strikethrough {
                attributedString.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
        }
        
        #if DEBUG
        print("[JSONImport] ✅ Decoded custom format attributed string (\(attributedString.length) chars, \(plist.count) range(s))")
        #endif
        return attributedString
    }
    
    /// Decode text file metadata from JSON string (dictionary format)
    private func decodeTextFileMetadata(_ jsonString: String) throws -> TextFileMetadata {
        // The textFile field contains a JSON-encoded dictionary, not base64
        guard let data = jsonString.data(using: .utf8) else {
            #if DEBUG
            print("[JSONImport] ❌ Failed to convert string to data")
            #endif
            throw ImportError.missingContent
        }
        
        // Decode as JSON dictionary
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            #if DEBUG
            print("[JSONImport] ❌ Failed to decode as JSON dictionary")
            #endif
            // Try to print what we got for debugging
            #if DEBUG
            print("[JSONImport] String preview: \(jsonString.prefix(200))")
            #endif
            throw ImportError.missingContent
        }
        
        #if DEBUG
        print("[JSONImport] ✅ Decoded metadata keys: \(dict.keys.sorted())")
        #endif
        
        // Extract dates if present (they may be in various formats)
        var createdDate: Date?
        var modifiedDate: Date?
        
        // dateCreated - could be String or Number (Core Data timestamp)
        if let dateString = dict["dateCreated"] as? String {
            createdDate = parseLegacyDate(dateString)
            #if DEBUG
            if createdDate == nil {
                print("[JSONImport] ⚠️ Failed to parse dateCreated string: '\(dateString)'")
            } else {
                print("[JSONImport] ✅ Parsed dateCreated from string: \(createdDate!)")
            }
            #endif
        } else if let dateNumber = dict["dateCreated"] as? Double {
            // Core Data stores dates as TimeInterval since reference date (Jan 1, 2001)
            createdDate = Date(timeIntervalSinceReferenceDate: dateNumber)
            #if DEBUG
            print("[JSONImport] ✅ Parsed dateCreated from number: \(createdDate!)")
            #endif
        }
        
        // dateLastUpdated - could be String or Number (Core Data timestamp)
        if let dateString = dict["dateLastUpdated"] as? String {
            modifiedDate = parseLegacyDate(dateString)
            #if DEBUG
            if modifiedDate == nil {
                print("[JSONImport] ⚠️ Failed to parse dateLastUpdated string: '\(dateString)'")
            } else {
                print("[JSONImport] ✅ Parsed dateLastUpdated from string: \(modifiedDate!)")
            }
            #endif
        } else if let dateNumber = dict["dateLastUpdated"] as? Double {
            // Core Data stores dates as TimeInterval since reference date (Jan 1, 2001)
            modifiedDate = Date(timeIntervalSinceReferenceDate: dateNumber)
            #if DEBUG
            print("[JSONImport] ✅ Parsed dateLastUpdated from number: \(modifiedDate!)")
            #endif
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
    
    /// Parse dates from legacy Writing Shed v1 format
    /// Handles multiple possible date formats
    private func parseLegacyDate(_ dateString: String) -> Date? {
        // Try ISO8601 first (standard format)
        let iso8601 = ISO8601DateFormatter()
        if let date = iso8601.date(from: dateString) {
            return date
        }
        
        // Try ISO8601 with fractional seconds
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601.date(from: dateString) {
            return date
        }
        
        // Try common date formats
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        // Format: "2024-12-10 14:30:00 +0000"
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        if let date = dateFormatter.date(from: dateString) {
            return date
        }
        
        // Format: "2024-12-10T14:30:00Z"
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        if let date = dateFormatter.date(from: dateString) {
            return date
        }
        
        // Format: "2024-12-10T14:30:00.000Z"
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        if let date = dateFormatter.date(from: dateString) {
            return date
        }
        
        // Format: "Dec 10, 2024 at 2:30 PM"
        dateFormatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        if let date = dateFormatter.date(from: dateString) {
            return date
        }
        
        // Format: "12/10/2024"
        dateFormatter.dateFormat = "MM/dd/yyyy"
        if let date = dateFormatter.date(from: dateString) {
            return date
        }
        
        return nil
    }
    
    /// Map legacy Writing Shed v1 folder names to Writing Shed Pro folder names
    private func mapLegacyFolderName(_ legacyName: String) -> String {
        switch legacyName {
        case "Draft", "Ready", "Submitted", "Accepted", "Set Aside", "Published", "Collections", "Submissions", "Research", "Trash":
            return legacyName  // These names are handled by workflow status or kept as-is
        default:
            return legacyName  // Unknown folders keep their original name
        }
    }
    
    /// Decode publication metadata from JSON string (dictionary format)
    private func decodePublicationMetadata(_ jsonString: String) throws -> PublicationMetadata {
        // The collectionComponent field contains a JSON-encoded dictionary
        guard let data = jsonString.data(using: .utf8) else {
            #if DEBUG
            print("[JSONImport] ❌ Publication: Failed to convert string to data")
            #endif
            throw ImportError.missingContent
        }
        
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            #if DEBUG
            print("[JSONImport] ❌ Publication: Failed to decode JSON dictionary")
            #endif
            #if DEBUG
            print("[JSONImport] String preview: \(jsonString.prefix(200))")
            #endif
            throw ImportError.missingContent
        }
        
        #if DEBUG
        print("[JSONImport] ✅ Publication decoded: \(dict["name"] as? String ?? "unnamed") - \(dict["groupName"] as? String ?? "no type")")
        #endif
        
        return PublicationMetadata(
            name: dict["name"] as? String ?? "Untitled",
            groupName: dict["groupName"] as? String ?? ""
        )
    }
    
    /// Decode collection metadata from JSON string (dictionary format)
    private func decodeCollectionMetadata(_ jsonString: String) throws -> CollectionMetadata {
        // The collectionComponent field contains a JSON-encoded dictionary
        guard let data = jsonString.data(using: .utf8) else {
            #if DEBUG
            print("[JSONImport] ❌ Collection: Failed to convert string to data")
            #endif
            throw ImportError.missingContent
        }
        
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            #if DEBUG
            print("[JSONImport] ❌ Collection: Failed to decode JSON dictionary")
            #endif
            #if DEBUG
            print("[JSONImport] String preview: \(jsonString.prefix(200))")
            #endif
            throw ImportError.missingContent
        }
        
        #if DEBUG
        print("[JSONImport] ✅ Collection decoded: \(dict["name"] as? String ?? "unnamed")")
        #endif
        
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
