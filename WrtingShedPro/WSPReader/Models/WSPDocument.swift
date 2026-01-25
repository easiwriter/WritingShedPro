//
//  WSPDocument.swift
//  WSP Reader
//
//  Parses and represents a WSP document for reading.
//  Feature 026: WSP Reader App
//

import Foundation
import UIKit
import Observation

/// Represents a parsed WSP document for reading
@Observable
class WSPDocument {
    
    // MARK: - Properties
    
    /// Original file URL
    let fileURL: URL
    
    /// Project metadata
    let projectName: String
    let projectType: String
    let exportDate: Date?
    let appVersion: String
    
    /// Whether this is a Manual project type (for TOC navigation)
    var isManualProject: Bool {
        projectType == "manual"
    }
    
    /// Root folders
    let folders: [WSPReaderFolder]
    
    /// All files in flat list for search
    var allFiles: [WSPReaderFile] {
        folders.flatMap { collectFiles(from: $0) }
    }
    
    /// Publications (read-only display)
    let publications: [WSPReaderPublication]
    
    // MARK: - Initialization
    
    init(url: URL) throws {
        self.fileURL = url
        
        // Read file data
        let data = try Data(contentsOf: url)
        
        // Parse JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let wspData = try decoder.decode(WSPExportData.self, from: data)
        
        // Extract project info
        self.projectName = wspData.project.name.isEmpty ? "Untitled" : wspData.project.name
        self.projectType = wspData.project.type
        self.exportDate = wspData.exportDate
        self.appVersion = wspData.appVersion
        
        // Parse folders
        self.folders = wspData.folders.map { WSPReaderFolder(from: $0) }
        
        // Parse publications
        self.publications = wspData.publications.map { WSPReaderPublication(from: $0) }
        
        #if DEBUG
        print("[WSPDocument] Loaded: \(projectName)")
        print("[WSPDocument]   Type: \(projectType)")
        print("[WSPDocument]   Folders: \(folders.count)")
        print("[WSPDocument]   Files: \(allFiles.count)")
        #endif
    }
    
    // MARK: - Helpers
    
    private func collectFiles(from folder: WSPReaderFolder) -> [WSPReaderFile] {
        var files = folder.files
        for subfolder in folder.subfolders {
            files.append(contentsOf: collectFiles(from: subfolder))
        }
        return files
    }
    
    /// Get the first file in the document
    func firstFile() -> WSPReaderFile? {
        for folder in folders {
            if let file = folder.files.first {
                return file
            }
            for subfolder in folder.subfolders {
                if let file = subfolder.files.first {
                    return file
                }
            }
        }
        return nil
    }
    
    /// Find a file by ID
    func file(withID id: String) -> WSPReaderFile? {
        allFiles.first { $0.id == id }
    }
    
    /// Find a file by ID (alias for internal link navigation)
    func findFile(byId id: String) -> WSPReaderFile? {
        file(withID: id)
    }
}

// MARK: - Reader Folder

struct WSPReaderFolder: Identifiable {
    let id: String
    let name: String
    let userOrder: Int?
    let files: [WSPReaderFile]
    let subfolders: [WSPReaderFolder]
    
    init(from data: WSPFolderData) {
        self.id = data.id
        self.name = data.name
        self.userOrder = data.userOrder
        self.files = data.textFiles.map { WSPReaderFile(from: $0) }
        self.subfolders = data.subfolders.map { WSPReaderFolder(from: $0) }
    }
    
    /// Get folder icon based on name
    var iconName: String {
        let lowerName = name.lowercased()
        if lowerName.contains("draft") { return "pencil.circle" }
        if lowerName.contains("ready") { return "checkmark.circle" }
        if lowerName.contains("trash") { return "trash" }
        if lowerName.contains("chapter") { return "book" }
        if lowerName.contains("act") { return "theatermasks" }
        return "folder"
    }
}

// MARK: - Reader File

struct WSPReaderFile: Identifiable, Hashable {
    let id: String
    let name: String
    let createdDate: Date
    let modifiedDate: Date
    let currentVersionIndex: Int
    let versions: [WSPReaderVersion]
    let workflowStatus: String?
    let poetryFormName: String?
    
    init(from data: WSPTextFileData) {
        self.id = data.id
        self.name = data.name
        self.createdDate = data.createdDate
        self.modifiedDate = data.modifiedDate
        self.currentVersionIndex = data.currentVersionIndex
        self.versions = data.versions.map { WSPReaderVersion(from: $0) }
        self.workflowStatus = data.workflowStatus
        self.poetryFormName = data.poetryFormName
    }
    
    // MARK: - Hashable
    
    static func == (lhs: WSPReaderFile, rhs: WSPReaderFile) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    /// Get the current version
    var currentVersion: WSPReaderVersion? {
        guard currentVersionIndex >= 0 && currentVersionIndex < versions.count else {
            return versions.last
        }
        return versions[currentVersionIndex]
    }
    
    /// Get content as AttributedString
    var attributedContent: NSAttributedString {
        guard let version = currentVersion else {
            return NSAttributedString(string: "")
        }
        return version.attributedContent
    }
    
    /// Get plain text content
    var plainContent: String {
        currentVersion?.content ?? ""
    }
    
    /// Word count
    var wordCount: Int {
        plainContent.split { $0.isWhitespace || $0.isNewline }.count
    }
}

// MARK: - Reader Version

struct WSPReaderVersion: Identifiable {
    let id: String
    let content: String
    let formattedContentBase64: String?
    let createdDate: Date
    let versionNumber: Int
    let comment: String?
    let notes: String?
    let comments: [WSPReaderComment]
    let footnotes: [WSPReaderFootnote]
    
    init(from data: WSPVersionData) {
        self.id = data.id
        self.content = data.content
        self.formattedContentBase64 = data.formattedContentBase64
        self.createdDate = data.createdDate
        self.versionNumber = data.versionNumber
        self.comment = data.comment
        self.notes = data.notes
        self.comments = data.comments.map { WSPReaderComment(from: $0) }
        self.footnotes = data.footnotes.map { WSPReaderFootnote(from: $0) }
    }
    
    /// Get formatted attributed string
    var attributedContent: NSAttributedString {
        // Try to decode RTF from base64
        if let base64 = formattedContentBase64,
           let rtfData = Data(base64Encoded: base64) {
            do {
                let attributed = try NSAttributedString(
                    data: rtfData,
                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                    documentAttributes: nil
                )
                return attributed
            } catch {
                #if DEBUG
                print("[WSPReaderVersion] Failed to decode RTF: \(error)")
                #endif
            }
        }
        
        // Fallback to plain text with default formatting
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]
        
        return NSAttributedString(string: content, attributes: attributes)
    }
}

// MARK: - Reader Comment

struct WSPReaderComment: Identifiable {
    let id: String
    let text: String
    let author: String
    let characterPosition: Int
    let createdAt: Date
    let isResolved: Bool
    
    init(from data: WSPCommentData) {
        self.id = data.id
        self.text = data.text
        self.author = data.author
        self.characterPosition = data.characterPosition
        self.createdAt = data.createdAt
        self.isResolved = data.resolvedAt != nil
    }
}

// MARK: - Reader Footnote

struct WSPReaderFootnote: Identifiable {
    let id: String
    let text: String
    let number: Int
    let characterPosition: Int
    
    init(from data: WSPFootnoteData) {
        self.id = data.id
        self.text = data.text
        self.number = data.number
        self.characterPosition = data.characterPosition
    }
}

// MARK: - Reader Publication

struct WSPReaderPublication: Identifiable {
    let id: String
    let name: String
    let type: String?
    let url: String?
    let notes: String?
    
    init(from data: WSPPublicationData) {
        self.id = data.id
        self.name = data.name
        self.type = data.type
        self.url = data.url
        self.notes = data.notes
    }
}
