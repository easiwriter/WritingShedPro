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
        exportData.formatVersion = "1.0"
        exportData.exportDate = Date()
        exportData.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        
        // Project info
        exportData.project = buildProjectData(from: project)
        
        // Folders and files
        exportData.folders = buildFolderData(from: project)
        
        // Publications
        exportData.publications = buildPublicationData(from: project)
        
        // Submissions (including collections)
        exportData.submissions = buildSubmissionData(from: project)
        
        #if DEBUG
        print("[JSONExport] Built export data:")
        print("[JSONExport]   Folders: \(exportData.folders.count)")
        print("[JSONExport]   Publications: \(exportData.publications.count)")
        print("[JSONExport]   Submissions: \(exportData.submissions.count)")
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
        
        return folders.compactMap { folder in
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
}

// MARK: - Export Data Structures

/// Root structure for Writing Shed Pro export format
struct WSPExportData: Codable {
    var formatVersion: String = "1.0"
    var exportDate: Date = Date()
    var appVersion: String = "1.0"
    var project: WSPProjectData = WSPProjectData()
    var folders: [WSPFolderData] = []
    var publications: [WSPPublicationData] = []
    var submissions: [WSPSubmissionData] = []
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
    var comments: [WSPCommentData] = []
    var footnotes: [WSPFootnoteData] = []
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
