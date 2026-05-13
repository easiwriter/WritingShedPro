//
//  WSPDocument.swift
//  WSP Reader
//
//  Parses and represents a WSP document for reading.
//  Feature 026: WSP Reader App
//

import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Represents a parsed WSP document for reading
@Observable
class WSPDocument {
    
    // MARK: - Properties
    
    /// Original file URL
    let fileURL: URL
    
    /// Project metadata
    let projectName: String
    let projectType: String
    let fictionClass: String?
    let dramaScriptType: String?
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

    /// Files included in manuscript assembly order
    var manuscriptFiles: [WSPReaderFile] {
        allFiles.filter { $0.includedInManuscript }
    }

    /// Manuscript-ordered files: TOC files first, then included body files
    var manuscriptOrderedFiles: [WSPReaderFile] {
        let tocFiles = allFiles
            .filter { $0.isTOCFile }
            .sorted(by: Self.manuscriptSort)

        let bodyFiles = manuscriptFiles
            .filter { !$0.isTOCFile }
            .sorted(by: Self.manuscriptSort)

        return tocFiles + bodyFiles
    }

    /// Top-level folders shown in Reader (work-only view)
    var readerVisibleFolders: [WSPReaderFolder] {
        folders.filter { Self.isReaderVisibleFolderName($0.name) }
    }

    /// Primary folders for Reader UI: one container folder + one file/content folder
    var readerPrimaryFolders: [WSPReaderFolder] {
        let visible = readerVisibleFolders.filter { Self.hasBrowsableContent($0) }
        guard visible.count > 2 else { return visible }

        let preferred = Self.preferredFolderNames(for: projectType)
        let container = firstFolder(in: visible, matchingAny: preferred.container)
        let content = firstFolder(in: visible, matchingAny: preferred.content, excludingID: container?.id)

        if let container, let content {
            return [container, content]
        }
        if let container {
            if let fallback = visible.first(where: { $0.id != container.id }) {
                return [container, fallback]
            }
            return [container]
        }
        if let content {
            if let fallback = visible.first(where: { $0.id != content.id }) {
                return [fallback, content]
            }
            return [content]
        }

        return Array(visible.prefix(2))
    }

    /// Container folder used as manuscript source when available
    var readerContainerFolder: WSPReaderFolder? {
        let visible = readerVisibleFolders.filter { Self.hasBrowsableContent($0) }
        let preferred = Self.preferredFolderNames(for: projectType)
        return firstFolder(in: visible, matchingAny: preferred.container) ?? readerPrimaryFolders.first
    }

    /// Manuscript preview files assembled in the same order as ManuscriptAssemblyService:
    /// Front Matter → Body (from project-type source folder) → Back Matter
    var manuscriptPreviewFiles: [WSPReaderFile] {
        var result: [WSPReaderFile] = []

        // 1. Front Matter — files inside Manuscript/Front Matter
        if let frontMatter = manuscriptSubfolder(named: "Front Matter") {
            result.append(contentsOf: frontMatter.files)
        }

        // 2. Body — files from the project-type source folder, filtered by includedInManuscript
        let bodyFolderName = bodySourceFolderName()
        if let bodyFolder = folders.first(where: { $0.name.caseInsensitiveCompare(bodyFolderName) == .orderedSame }) {
            result.append(contentsOf: bodyFolder.files.filter { $0.includedInManuscript && !$0.isTOCFile })
        }

        // 3. Back Matter — files inside Manuscript/Back Matter
        if let backMatter = manuscriptSubfolder(named: "Back Matter") {
            result.append(contentsOf: backMatter.files)
        }

        // Fallback: if nothing found, use all includedInManuscript files except TOC
        if result.isEmpty {
            return manuscriptOrderedFiles.filter { !$0.isTOCFile }
        }
        return result
    }

    /// Manuscript preview title
    var manuscriptPreviewTitle: String { "Manuscript" }

    /// Returns the subfolder of the top-level "Manuscript" folder with the given name.
    private func manuscriptSubfolder(named name: String) -> WSPReaderFolder? {
        guard let manuscriptFolder = folders.first(where: {
            $0.name.caseInsensitiveCompare("Manuscript") == .orderedSame
        }) else { return nil }
        return manuscriptFolder.subfolders.first(where: {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        })
    }

    /// Returns the folder name containing body content — mirrors ManuscriptAssemblyService.getBodySourceFolderName()
    private func bodySourceFolderName() -> String {
        switch projectType.lowercased() {
        case "poetry":   return "Poems"
        case "drama":    return "Scenes"
        case "prose":    return "Prose"
        case "fiction":
            switch fictionClass?.lowercased() {
            case "novel":      return "Chapters"
            case "versenovel": return "Episodes"
            default:           return "Scenes"
            }
        default: return "Scenes"
        }
    }
    
    /// Publications (read-only display)
    let publications: [WSPReaderPublication]

    /// Submissions with linked files
    let submissions: [WSPReaderSubmission]
    
    // MARK: - Initialization
    
    init(url: URL) throws {
        self.fileURL = url
        
        // Read file data
        print("[WSPDocument] reading data from \(url.lastPathComponent)")
        let data = try Data(contentsOf: url)
        print("[WSPDocument] read \(data.count) bytes")
        
        // Check if the file looks like a ZIP (some exporters may compress)
        if data.prefix(2) == Data([0x50, 0x4B]) {
            print("[WSPDocument] WARNING: file starts with PK — this is a ZIP, not plain JSON")
        } else if let preview = String(data: data.prefix(100), encoding: .utf8) {
            print("[WSPDocument] file preview: \(preview.prefix(80))")
        }
        
        // Parse JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let wspData = try decoder.decode(WSPExportData.self, from: data)
        
        // Extract project info
        self.projectName = wspData.project.name.isEmpty ? "Untitled" : wspData.project.name
        self.projectType = wspData.project.type
        self.fictionClass = wspData.project.fictionClass
        self.dramaScriptType = wspData.project.dramaScriptType
        self.exportDate = wspData.exportDate
        self.appVersion = wspData.appVersion
        
        // Parse folders, sorted by userOrder to match WSP display order
        let parsedFolders = wspData.folders
            .map { WSPReaderFolder(from: $0) }
            .sorted { ($0.userOrder ?? Int.max) < ($1.userOrder ?? Int.max) }
        self.folders = parsedFolders

        let flattenedFiles = parsedFolders.flatMap { Self.collectFilesStatic(from: $0) }
        let fileByID = Dictionary(uniqueKeysWithValues: flattenedFiles.map { ($0.id, $0) })
        
        // Parse publications
        self.publications = wspData.publications.map { WSPReaderPublication(from: $0) }
        self.submissions = wspData.submissions
            .sorted { ($0.userOrder ?? Int.max) < ($1.userOrder ?? Int.max) }
            .map { WSPReaderSubmission(from: $0, fileByID: fileByID) }
        
        print("[WSPDocument] Loaded: \(projectName) type=\(projectType) folders=\(folders.count) files=\(allFiles.count)")
        } catch let decodeError {
            print("[WSPDocument] JSON decode FAILED: \(decodeError)")
            throw decodeError
        }
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

    /// Return the file immediately before or after `file` in the flat `allFiles` list.
    /// Returns nil if already at the start/end.
    func adjacentFile(to file: WSPReaderFile, forward: Bool) -> WSPReaderFile? {
        let flat = allFiles
        guard let idx = flat.firstIndex(where: { $0.id == file.id }) else { return nil }
        let next = forward ? flat.index(after: idx) : flat.index(before: idx)
        guard next >= flat.startIndex && next < flat.endIndex else { return nil }
        return flat[next]
    }

    func submissions(for publicationID: String) -> [WSPReaderSubmission] {
        submissions.filter { $0.publicationId == publicationID }
    }

    func manuscriptFiles(in folder: WSPReaderFolder) -> [WSPReaderFile] {
        Self.collectFilesStatic(from: folder)
            .filter { $0.includedInManuscript && !$0.isTOCFile }
            .sorted(by: Self.manuscriptSort)
    }

    private func manuscriptFilesPreservingFolderOrder(in folder: WSPReaderFolder) -> [WSPReaderFile] {
        var files = folder.files
            .filter { $0.includedInManuscript && !$0.isTOCFile }
        for subfolder in folder.subfolders {
            files.append(contentsOf: manuscriptFilesPreservingFolderOrder(in: subfolder))
        }
        return files
    }

    nonisolated private static func manuscriptSort(_ lhs: WSPReaderFile, _ rhs: WSPReaderFile) -> Bool {
        let leftOrder = lhs.userOrder ?? Int.max
        let rightOrder = rhs.userOrder ?? Int.max
        if leftOrder != rightOrder {
            return leftOrder < rightOrder
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private static func collectFilesStatic(from folder: WSPReaderFolder) -> [WSPReaderFile] {
        var files = folder.files
        for subfolder in folder.subfolders {
            files.append(contentsOf: collectFilesStatic(from: subfolder))
        }
        return files
    }

    private static func isReaderVisibleFolderName(_ name: String) -> Bool {
        let lower = name.lowercased()
        let hiddenKeywords = [
            "trash", "research", "submission", "submissions",
            "publication", "publications", "magazine", "magazines",
            "back matter", "manuscript"
        ]
        return !hiddenKeywords.contains { lower.contains($0) }
    }

    private static func preferredFolderNames(for projectType: String) -> (container: [String], content: [String]) {
        switch projectType.lowercased() {
        case "poetry":
            return (
                container: ["Collections", "Collection", "Sections", "Section"],
                content: ["Poems", "Poem", "Files"]
            )
        case "manual":
            return (
                container: ["Sections", "Section", "Collections", "Collection"],
                content: ["Entries", "Files", "Prose"]
            )
        case "drama":
            return (
                container: ["Acts", "Act", "Scenes", "Scene"],
                content: ["Scenes", "Scene", "Files"]
            )
        case "fiction", "shortfiction", "short_fiction", "short fiction", "prose":
            return (
                container: ["Books", "Book", "Chapters", "Chapter", "Sections", "Section"],
                content: ["Prose", "Stories", "Story", "Files"]
            )
        default:
            return (
                container: ["Collections", "Sections", "Books", "Chapters", "Acts"],
                content: ["Poems", "Prose", "Scenes", "Stories", "Entries", "Files"]
            )
        }
    }

    private func firstFolder(in folders: [WSPReaderFolder], matchingAny names: [String], excludingID: String? = nil) -> WSPReaderFolder? {
        for preferredName in names {
            if let folder = folders.first(where: {
                $0.name.caseInsensitiveCompare(preferredName) == .orderedSame &&
                (excludingID == nil || $0.id != excludingID)
            }) {
                return folder
            }
        }
        // Fallback: contains match for robustness with localized/variant names
        for preferredName in names {
            if let folder = folders.first(where: {
                $0.name.localizedCaseInsensitiveContains(preferredName) &&
                (excludingID == nil || $0.id != excludingID)
            }) {
                return folder
            }
        }
        return nil
    }

    private static func hasBrowsableContent(_ folder: WSPReaderFolder) -> Bool {
        if !folder.files.isEmpty {
            return true
        }
        for subfolder in folder.subfolders {
            if hasBrowsableContent(subfolder) {
                return true
            }
        }
        return false
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
        self.files = data.textFiles
            .sorted { ($0.userOrder ?? Int.max) < ($1.userOrder ?? Int.max) }
            .map { WSPReaderFile(from: $0) }
        self.subfolders = data.subfolders
            .sorted { ($0.userOrder ?? Int.max) < ($1.userOrder ?? Int.max) }
            .map { WSPReaderFolder(from: $0) }
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
    let userOrder: Int?
    let includedInManuscript: Bool
    let isTOCFile: Bool
    let versions: [WSPReaderVersion]
    let workflowStatus: String?
    let poetryFormName: String?
    
    init(from data: WSPTextFileData) {
        self.id = data.id
        self.name = data.name
        self.createdDate = data.createdDate
        self.modifiedDate = data.modifiedDate
        self.currentVersionIndex = data.currentVersionIndex
        self.userOrder = data.userOrder
        self.includedInManuscript = data.includedInManuscript ?? true
        self.isTOCFile = data.isTOCFile ?? false
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

/// Uses a class (not struct) so the decoded NSAttributedString can be cached
/// after first access — decoding the binary plist is expensive and must not
/// repeat on every SwiftUI render.
final class WSPReaderVersion: Identifiable {
    let id: String
    let content: String
    let formattedContentBase64: String?
    let createdDate: Date
    let versionNumber: Int
    let comment: String?
    let notes: String?
    let comments: [WSPReaderComment]
    let footnotes: [WSPReaderFootnote]

    /// Decoded once on first access, then returned from cache.
    private var _attributedContent: NSAttributedString?

    init(from data: WSPVersionData) {
        self.id = data.id
        self.content = data.content
        self.formattedContentBase64 = data.formattedContentBase64
        self.createdDate = data.createdDate
        self.versionNumber = data.versionNumber
        self.comment = data.comment
        self.notes = data.notes
        self.comments = (data.comments ?? []).map { WSPReaderComment(from: $0) }
        self.footnotes = (data.footnotes ?? []).map { WSPReaderFootnote(from: $0) }
    }

    /// Get formatted attributed string — decoded on first call, cached thereafter.
    var attributedContent: NSAttributedString {
        if let cached = _attributedContent { return cached }
        let result = decodeAttributedContent()
        _attributedContent = result
        return result
    }

    private func decodeAttributedContent() -> NSAttributedString {
        if let base64 = formattedContentBase64,
           let data = Data(base64Encoded: base64),
           !data.isEmpty {
            // Primary format: binary PropertyList ([WSPAttributeValues]) written by AttributedStringSerializer
            if let decoded = WSPAttributeDecoder.decode(data, text: content) {
                return decoded
            }
            // Legacy format: RTF data (Word imports, Writing Shed 1.x)
            #if canImport(UIKit)
            if let attributed = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil) {
                return attributed
            }
            #endif
        }
        // Plain-text fallback
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        #if canImport(UIKit)
        return NSAttributedString(string: content, attributes: [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ])
        #elseif canImport(AppKit)
        return NSAttributedString(string: content, attributes: [
            .font: NSFont.preferredFont(forTextStyle: .body),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ])
        #endif
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

// MARK: - Reader Submission

struct WSPReaderSubmission: Identifiable {
    let id: String
    let publicationId: String?
    let name: String
    let submittedDate: Date
    let userOrder: Int?
    let submittedFiles: [WSPReaderSubmittedFile]

    init(from data: WSPSubmissionData, fileByID: [String: WSPReaderFile]) {
        self.id = data.id
        self.publicationId = data.publicationId
        self.name = data.name ?? "Untitled Submission"
        self.submittedDate = data.submittedDate
        self.userOrder = data.userOrder
        self.submittedFiles = data.submittedFiles.compactMap { item in
            guard let textFileID = item.textFileId,
                  let file = fileByID[textFileID] else {
                return nil
            }
            return WSPReaderSubmittedFile(file: file, status: item.status, statusDate: item.statusDate)
        }
    }
}

struct WSPReaderSubmittedFile: Identifiable {
    var id: String { file.id }
    let file: WSPReaderFile
    let status: String?
    let statusDate: Date?
}
