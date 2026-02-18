//
//  JSONExportService.swift
//  Writing Shed Pro
//
//  Created on 8 January 2026.
//  Feature: Project Export to .wsp format
//

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Errors that can occur during export
public enum ExportError: Error, LocalizedError {
    case noProject
    case encodingFailed
    case fileWriteFailed
    case invalidData
    
    public var errorDescription: String? {
        switch self {
        case .noProject:
            return "No project to export"
        case .encodingFailed:
            return "Failed to encode project data"
        case .fileWriteFailed:
            return "Failed to write export file"
        case .invalidData:
            return "Project contains invalid data"
        }
    }
}

// MARK: - File Document for Export

/// A FileDocument wrapper for exporting project data
struct ProjectExportDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [UTType("com.writing-shed.wsp") ?? .json]
    }
    
    static var writableContentTypes: [UTType] {
        [UTType("com.writing-shed.wsp") ?? .json]
    }
    
    let data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        if let fileData = configuration.file.regularFileContents {
            self.data = fileData
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// Handles export of projects to Writing Shed Pro JSON format (.wsp)
class JSONExportService {
    
    // MARK: - Properties
    
    private let encoder: JSONEncoder
    
    // MARK: - Initialization
    
    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
    }
    
    // MARK: - Main Export Method
    
    /// Export a project to JSON data
    /// - Parameter project: The project to export
    /// - Returns: JSON data representing the project
    /// - Throws: ExportError if export fails
    func exportProject(_ project: Project) throws -> Data {
        #if DEBUG
        print("[JSONExport] ========== EXPORT START ==========")
        print("[JSONExport] Project: \(project.name ?? "Untitled")")
        #endif
        
        // Build export data structure
        let exportData = try buildExportData(from: project)
        
        // Encode to JSON
        let jsonData = try encoder.encode(exportData)
        
        #if DEBUG
        print("[JSONExport] ✅ Export complete: \(jsonData.count) bytes")
        print("[JSONExport] ========== EXPORT END ==========")
        #endif
        
        return jsonData
    }
    
    /// Export a project to a file URL
    /// - Parameters:
    ///   - project: The project to export
    ///   - url: The URL to write the file to
    /// - Throws: ExportError if export fails
    func exportProject(_ project: Project, to url: URL) throws {
        let jsonData = try exportProject(project)
        try jsonData.write(to: url)
    }
    
    // MARK: - Build Export Data
    
    private func buildExportData(from project: Project) throws -> WSPExportData {
        var exportData = WSPExportData()
        
        // Project metadata
        exportData.formatVersion = "1.1"
        exportData.exportDate = Date()
        exportData.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        
        // Project info
        exportData.project = buildProjectData(from: project)
        
        // Folders and files
        exportData.folders = buildFolderData(from: project)
        
        // Prose sections (for Prose projects)
        exportData.proseSections = buildProseSectionData(from: project)
        
        // Publications
        exportData.publications = buildPublicationData(from: project)
        
        // Submissions (including collections)
        exportData.submissions = buildSubmissionData(from: project)
        
        // Feature 036: Poetry collections
        exportData.poetryCollections = buildPoetryCollectionData(from: project)
        
        // Feature 036: Fiction entities
        exportData.books = buildBookData(from: project)
        exportData.chapters = buildChapterData(from: project)
        exportData.acts = buildActData(from: project)
        exportData.scenes = buildStorySceneData(from: project)
        exportData.characters = buildCharacterData(from: project)
        exportData.locations = buildLocationData(from: project)
        
        #if DEBUG
        print("[JSONExport] Built export data:")
        print("[JSONExport]   Folders: \(exportData.folders.count)")
        print("[JSONExport]   Prose Sections: \(exportData.proseSections?.count ?? 0)")
        print("[JSONExport]   Publications: \(exportData.publications.count)")
        print("[JSONExport]   Submissions: \(exportData.submissions.count)")
        print("[JSONExport]   Poetry Collections: \(exportData.poetryCollections?.count ?? 0)")
        print("[JSONExport]   Books: \(exportData.books?.count ?? 0)")
        print("[JSONExport]   Chapters: \(exportData.chapters?.count ?? 0)")
        print("[JSONExport]   Acts: \(exportData.acts?.count ?? 0)")
        print("[JSONExport]   Scenes: \(exportData.scenes?.count ?? 0)")
        print("[JSONExport]   Characters: \(exportData.characters?.count ?? 0)")
        print("[JSONExport]   Locations: \(exportData.locations?.count ?? 0)")
        #endif
        
        return exportData
    }
    
    // MARK: - Project Data
    
    private func buildProjectData(from project: Project) -> WSPProjectData {
        WSPProjectData(
            id: project.id.uuidString,
            name: project.name ?? "Untitled",
            type: project.typeRaw ?? "prose",
            status: project.statusRaw ?? "pro",
            creationDate: project.creationDate,
            modifiedDate: project.modifiedDate,
            details: project.details,
            notes: project.notes,
            fictionClass: project.fictionClassRaw,
            useMonomyth: project.useMonomyth,
            storyStructure: project.storyStructureRaw
        )
    }
    
    // MARK: - Folder Data
    
    private func buildFolderData(from project: Project) -> [WSPFolderData] {
        guard let folders = project.folders else { return [] }
        
        // Only export root-level folders (those without a parent folder) at the top level.
        // Subfolders will be included recursively via their parent's folder.folders relationship.
        // This prevents duplicates when a subfolder also has its project relationship set.
        let rootFolders = folders.filter { $0.parentFolder == nil }
        
        return rootFolders.compactMap { folder in
            buildFolderData(from: folder, parentId: nil)
        }
    }
    
    private func buildFolderData(from folder: Folder, parentId: String?) -> WSPFolderData {
        // Build text files for this folder
        let textFiles = (folder.textFiles ?? []).map { buildTextFileData(from: $0) }
        
        // Recursively build subfolders
        let subfolders = (folder.folders ?? []).map { buildFolderData(from: $0, parentId: folder.id.uuidString) }
        
        return WSPFolderData(
            id: folder.id.uuidString,
            name: folder.name ?? "Untitled",
            userOrder: folder.userOrder,
            parentId: parentId,
            textFiles: textFiles,
            subfolders: subfolders
        )
    }
    
    // MARK: - Text File Data
    
    private func buildTextFileData(from textFile: TextFile) -> WSPTextFileData {
        let versions = (textFile.versions ?? []).map { buildVersionData(from: $0) }
        
        // Encode TOC settings as base64 if this is a TOC file
        var tocSettingsBase64: String? = nil
        if textFile.isTOCFile, let data = textFile.tocSettingsData {
            tocSettingsBase64 = data.base64EncodedString()
        }
        
        return WSPTextFileData(
            id: textFile.id.uuidString,
            name: textFile.name,
            createdDate: textFile.createdDate,
            modifiedDate: textFile.modifiedDate,
            currentVersionIndex: textFile.currentVersionIndex,
            userOrder: textFile.userOrder,
            workflowStatus: textFile.workflowStatusRaw,
            poetryFormId: textFile.poetryFormId?.uuidString,
            poetryFormName: textFile.poetryFormName,
            sectionId: textFile.section?.id.uuidString,
            includedInManuscript: textFile.includedInManuscript,
            contentTypeRaw: textFile.contentTypeRaw != "richText" ? textFile.contentTypeRaw : nil,  // Only export if not default
            isTOCFile: textFile.isTOCFile ? true : nil,  // Only export if true
            tocSettingsBase64: tocSettingsBase64,
            poetryCollectionId: textFile.poetryCollection?.id.uuidString,
            versions: versions
        )
    }
    
    // MARK: - Version Data
    
    private func buildVersionData(from version: Version) -> WSPVersionData {
        // Export formatted content as base64-encoded RTF
        var formattedContentBase64: String? = nil
        if let data = version.formattedContent {
            formattedContentBase64 = data.base64EncodedString()
        }
        
        // Export comments
        let comments = (version.comments ?? []).map { buildCommentData(from: $0) }
        
        // Export footnotes
        let footnotes = (version.footnotes ?? []).map { buildFootnoteData(from: $0) }
        
        return WSPVersionData(
            id: version.id.uuidString,
            content: version.content,
            formattedContentBase64: formattedContentBase64,
            createdDate: version.createdDate,
            versionNumber: version.versionNumber,
            comment: version.comment,
            notes: version.notes,
            comments: comments,
            footnotes: footnotes
        )
    }
    
    // MARK: - Comment Data
    
    private func buildCommentData(from comment: CommentModel) -> WSPCommentData {
        WSPCommentData(
            id: comment.id.uuidString,
            text: comment.text,
            author: comment.author,
            characterPosition: comment.characterPosition,
            attachmentID: comment.attachmentID.uuidString,
            createdAt: comment.createdAt,
            resolvedAt: comment.resolvedAt
        )
    }
    
    // MARK: - Footnote Data
    
    private func buildFootnoteData(from footnote: FootnoteModel) -> WSPFootnoteData {
        WSPFootnoteData(
            id: footnote.id.uuidString,
            text: footnote.text,
            characterPosition: footnote.characterPosition,
            attachmentID: footnote.attachmentID.uuidString,
            number: footnote.number,
            createdAt: footnote.createdAt,
            modifiedAt: footnote.modifiedAt
        )
    }
    
    // MARK: - Prose Section Data
    
    private func buildProseSectionData(from project: Project) -> [WSPProseSectionData] {
        guard let sections = project.sections else { return [] }
        
        return sections.map { section in
            WSPProseSectionData(
                id: section.id.uuidString,
                name: section.name ?? "Untitled",
                synopsis: section.synopsis,
                userOrder: section.userOrder,
                createdDate: section.createdDate,
                modifiedDate: section.modifiedDate,
                bodyMatterOrder: section.bodyMatterOrder,
                isInBodyMatter: section.isInBodyMatter ? true : nil
            )
        }
    }
    
    // MARK: - Publication Data
    
    private func buildPublicationData(from project: Project) -> [WSPPublicationData] {
        guard let publications = project.publications else { return [] }
        
        return publications.map { publication in
            WSPPublicationData(
                id: publication.id.uuidString,
                name: publication.name,
                type: publication.type?.rawValue,
                url: publication.url,
                notes: publication.notes,
                deadline: publication.deadline,
                createdDate: publication.createdDate,
                modifiedDate: publication.modifiedDate
            )
        }
    }
    
    // MARK: - Submission Data
    
    private func buildSubmissionData(from project: Project) -> [WSPSubmissionData] {
        guard let submissions = project.submissions else { return [] }
        
        return submissions.map { submission in
            let submittedFiles = (submission.submittedFiles ?? []).map { buildSubmittedFileData(from: $0) }
            
            return WSPSubmissionData(
                id: submission.id.uuidString,
                publicationId: submission.publication?.id.uuidString,
                name: submission.name,
                collectionDescription: submission.collectionDescription,
                isCollection: submission.isCollection,
                submittedDate: submission.submittedDate,
                returnExpectedBy: submission.returnExpectedBy,
                returnedOn: submission.returnedOn,
                notes: submission.notes,
                userOrder: submission.userOrder,
                createdDate: submission.createdDate,
                modifiedDate: submission.modifiedDate,
                submittedFiles: submittedFiles
            )
        }
    }
    
    // MARK: - Submitted File Data
    
    private func buildSubmittedFileData(from submittedFile: SubmittedFile) -> WSPSubmittedFileData {
        WSPSubmittedFileData(
            id: submittedFile.id.uuidString,
            textFileId: submittedFile.textFile?.id.uuidString,
            versionId: submittedFile.version?.id.uuidString,
            status: submittedFile.status?.rawValue,
            statusDate: submittedFile.statusDate,
            statusNotes: submittedFile.statusNotes,
            createdDate: submittedFile.createdDate,
            modifiedDate: submittedFile.modifiedDate
        )
    }
    
    // MARK: - Feature 036: Poetry Collection Data
    
    private func buildPoetryCollectionData(from project: Project) -> [WSPPoetryCollectionData] {
        guard let collections = project.poetryCollections, !collections.isEmpty else { return [] }
        
        return collections.map { collection in
            WSPPoetryCollectionData(
                id: collection.id.uuidString,
                name: collection.name ?? "Untitled",
                userOrder: collection.userOrder,
                synopsis: collection.synopsis,
                createdDate: collection.createdDate,
                modifiedDate: collection.modifiedDate,
                bodyMatterOrder: collection.bodyMatterOrder,
                isInBodyMatter: collection.isInBodyMatter
            )
        }
    }
    
    // MARK: - Feature 036: Book Data
    
    private func buildBookData(from project: Project) -> [WSPBookData] {
        guard let books = project.books, !books.isEmpty else { return [] }
        
        return books.map { book in
            WSPBookData(
                id: book.id.uuidString,
                name: book.name ?? "Untitled",
                userOrder: book.userOrder,
                synopsis: book.synopsis,
                createdDate: book.createdDate,
                modifiedDate: book.modifiedDate,
                bodyMatterOrder: book.bodyMatterOrder,
                isInBodyMatter: book.isInBodyMatter
            )
        }
    }
    
    // MARK: - Feature 036: Chapter Data
    
    private func buildChapterData(from project: Project) -> [WSPChapterData] {
        guard let chapters = project.chapters, !chapters.isEmpty else { return [] }
        
        return chapters.map { chapter in
            WSPChapterData(
                id: chapter.id.uuidString,
                name: chapter.name ?? "Untitled",
                userOrder: chapter.userOrder,
                synopsis: chapter.synopsis,
                createdDate: chapter.createdDate,
                modifiedDate: chapter.modifiedDate,
                bodyMatterOrder: chapter.bodyMatterOrder,
                isInBodyMatter: chapter.isInBodyMatter
            )
        }
    }
    
    // MARK: - Feature 036: Act Data
    
    private func buildActData(from project: Project) -> [WSPActData] {
        guard let acts = project.acts, !acts.isEmpty else { return [] }
        
        return acts.map { act in
            WSPActData(
                id: act.id.uuidString,
                name: act.name ?? "Untitled",
                userOrder: act.userOrder,
                synopsis: act.synopsis,
                createdDate: act.createdDate,
                modifiedDate: act.modifiedDate,
                bodyMatterOrder: act.bodyMatterOrder,
                isInBodyMatter: act.isInBodyMatter
            )
        }
    }
    
    // MARK: - Feature 036: Story Scene Data
    
    private func buildStorySceneData(from project: Project) -> [WSPStorySceneData] {
        guard let scenes = project.scenes, !scenes.isEmpty else { return [] }
        
        return scenes.map { scene in
            WSPStorySceneData(
                id: scene.id.uuidString,
                name: scene.name ?? "Untitled",
                userOrder: scene.userOrder,
                synopsis: scene.synopsis,
                createdDate: scene.createdDate,
                modifiedDate: scene.modifiedDate,
                bodyMatterOrder: scene.bodyMatterOrder,
                isInBodyMatter: scene.isInBodyMatter,
                chapterId: scene.chapter?.id.uuidString,
                actId: scene.act?.id.uuidString,
                bookId: scene.book?.id.uuidString,
                textFileId: scene.textFile?.id.uuidString,
                isTrashed: scene.isTrashed,
                trashedDate: scene.trashedDate,
                monomythStageRaw: scene.monomythStageRaw,
                campbellStageRaw: scene.campbellStageRaw,
                threeActStageRaw: scene.threeActStageRaw
            )
        }
    }
    
    // MARK: - Feature 036: Character Data
    
    private func buildCharacterData(from project: Project) -> [WSPCharacterData] {
        guard let characters = project.characters, !characters.isEmpty else { return [] }
        
        return characters.map { character in
            WSPCharacterData(
                id: character.id.uuidString,
                name: character.name,
                role: character.role,
                archetypeRaw: character.archetypeRaw,
                history: character.history,
                looks: character.looks,
                traits: character.traits,
                work: character.work
            )
        }
    }
    
    // MARK: - Feature 036: Location Data
    
    private func buildLocationData(from project: Project) -> [WSPLocationData] {
        guard let locations = project.locations, !locations.isEmpty else { return [] }
        
        return locations.map { location in
            WSPLocationData(
                id: location.id.uuidString,
                name: location.name,
                detail: location.detail,
                sights: location.sights,
                sounds: location.sounds,
                smells: location.smells
            )
        }
    }
}

// MARK: - Export Data Structures

/// Root structure for Writing Shed Pro export format
struct WSPExportData: Codable {
    var formatVersion: String = "1.1"
    var exportDate: Date = Date()
    var appVersion: String = "1.0"
    var project: WSPProjectData = WSPProjectData()
    var folders: [WSPFolderData] = []
    var proseSections: [WSPProseSectionData]?  // Optional for backward compatibility
    var publications: [WSPPublicationData] = []
    var submissions: [WSPSubmissionData] = []
    // Feature 036
    var poetryCollections: [WSPPoetryCollectionData]?
    var books: [WSPBookData]?
    var chapters: [WSPChapterData]?
    var acts: [WSPActData]?
    var scenes: [WSPStorySceneData]?
    var characters: [WSPCharacterData]?
    var locations: [WSPLocationData]?
}

struct WSPProjectData: Codable {
    var id: String = ""
    var name: String = ""
    var type: String = "prose"
    var status: String = "pro"
    var creationDate: Date?
    var modifiedDate: Date?
    var details: String?
    var notes: String?
    var fictionClass: String?
    var useMonomyth: Bool = false  // Legacy, kept for backward compatibility
    var storyStructure: String?    // New: StoryStructure raw value
}

struct WSPProseSectionData: Codable {
    var id: String = ""
    var name: String = ""
    var synopsis: String?
    var userOrder: Int?
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    var bodyMatterOrder: Int?  // Feature 036
    var isInBodyMatter: Bool?  // Feature 036 (optional for backward compat)
}

struct WSPFolderData: Codable {
    var id: String = ""
    var name: String = ""
    var userOrder: Int?
    var parentId: String?
    var textFiles: [WSPTextFileData] = []
    var subfolders: [WSPFolderData] = []
}

struct WSPTextFileData: Codable {
    var id: String = ""
    var name: String = ""
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    var currentVersionIndex: Int = 0
    var userOrder: Int?
    var workflowStatus: String?
    var poetryFormId: String?
    var poetryFormName: String?
    var sectionId: String?
    var includedInManuscript: Bool?  // Optional for backward compatibility, defaults to true
    var contentTypeRaw: String?  // Optional for backward compatibility - "richText" or "markdown"
    var isTOCFile: Bool?  // Optional for backward compatibility - Feature 031
    var tocSettingsBase64: String?  // Base64 encoded TOCSettings JSON - Feature 031
    var poetryCollectionId: String?  // Feature 036: link to PoetryCollection
    var versions: [WSPVersionData] = []
}

struct WSPVersionData: Codable {
    var id: String = ""
    var content: String = ""
    var formattedContentBase64: String?
    var createdDate: Date = Date()
    var versionNumber: Int = 1
    var comment: String?
    var notes: String?
    var comments: [WSPCommentData]?  // Optional for backward compatibility
    var footnotes: [WSPFootnoteData]?  // Optional for backward compatibility
}

struct WSPCommentData: Codable {
    var id: String = ""
    var text: String = ""
    var author: String = ""
    var characterPosition: Int = 0
    var attachmentID: String = ""
    var createdAt: Date = Date()
    var resolvedAt: Date?
}

struct WSPFootnoteData: Codable {
    var id: String = ""
    var text: String = ""
    var characterPosition: Int = 0
    var attachmentID: String = ""
    var number: Int = 0
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
}

struct WSPPublicationData: Codable {
    var id: String = ""
    var name: String = ""
    var type: String?
    var url: String?
    var notes: String?
    var deadline: Date?
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
}

struct WSPSubmissionData: Codable {
    var id: String = ""
    var publicationId: String?
    var name: String?
    var collectionDescription: String?
    var isCollection: Bool = false
    var submittedDate: Date = Date()
    var returnExpectedBy: Date?
    var returnedOn: Date?
    var notes: String?
    var userOrder: Int?
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    var submittedFiles: [WSPSubmittedFileData] = []
}

struct WSPSubmittedFileData: Codable {
    var id: String = ""
    var textFileId: String?
    var versionId: String?
    var status: String?
    var statusDate: Date?
    var statusNotes: String?
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
}

// MARK: - Feature 036 Data Structures

struct WSPPoetryCollectionData: Codable {
    var id: String = ""
    var name: String = ""
    var userOrder: Int?
    var synopsis: String?
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    var bodyMatterOrder: Int?
    var isInBodyMatter: Bool = false
}

struct WSPBookData: Codable {
    var id: String = ""
    var name: String = ""
    var userOrder: Int?
    var synopsis: String?
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    var bodyMatterOrder: Int?
    var isInBodyMatter: Bool = false
}

struct WSPChapterData: Codable {
    var id: String = ""
    var name: String = ""
    var userOrder: Int?
    var synopsis: String?
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    var bodyMatterOrder: Int?
    var isInBodyMatter: Bool = false
}

struct WSPActData: Codable {
    var id: String = ""
    var name: String = ""
    var userOrder: Int?
    var synopsis: String?
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    var bodyMatterOrder: Int?
    var isInBodyMatter: Bool = false
}

struct WSPStorySceneData: Codable {
    var id: String = ""
    var name: String = ""
    var userOrder: Int?
    var synopsis: String?
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    var bodyMatterOrder: Int?
    var isInBodyMatter: Bool = false
    var chapterId: String?
    var actId: String?
    var bookId: String?
    var textFileId: String?
    var isTrashed: Bool = false
    var trashedDate: Date?
    var monomythStageRaw: String?
    var campbellStageRaw: String?
    var threeActStageRaw: String?
}

struct WSPCharacterData: Codable {
    var id: String = ""
    var name: String?
    var role: String?
    var archetypeRaw: String?
    var history: String?
    var looks: String?
    var traits: String?
    var work: String?
}

struct WSPLocationData: Codable {
    var id: String = ""
    var name: String?
    var detail: String?
    var sights: String?
    var sounds: String?
    var smells: String?
}
