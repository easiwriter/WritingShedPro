//
//  WSPDataModels.swift
//  WSP Reader
//
//  Shared data models for WSP file format parsing.
//  These mirror the export models from Writing Shed Pro.
//  Feature 026: WSP Reader App
//

import Foundation

// MARK: - Export Data Root

struct WSPExportData: Codable {
    var formatVersion: String = "1.0"
    var exportDate: Date?
    var appVersion: String = ""
    var project: WSPProjectData = WSPProjectData()
    var folders: [WSPFolderData] = []
    var publications: [WSPPublicationData] = []
    var submissions: [WSPSubmissionData] = []
}

// MARK: - Project Data

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
    var useMonomyth: Bool = false
    var storyStructure: String?
}

// MARK: - Folder Data

struct WSPFolderData: Codable {
    var id: String = ""
    var name: String = ""
    var userOrder: Int?
    var parentId: String?
    var textFiles: [WSPTextFileData] = []
    var subfolders: [WSPFolderData] = []
}

// MARK: - Text File Data

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

// MARK: - Version Data

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

// MARK: - Comment Data

struct WSPCommentData: Codable {
    var id: String = ""
    var text: String = ""
    var author: String = ""
    var characterPosition: Int = 0
    var attachmentID: String = ""
    var createdAt: Date = Date()
    var resolvedAt: Date?
}

// MARK: - Footnote Data

struct WSPFootnoteData: Codable {
    var id: String = ""
    var text: String = ""
    var characterPosition: Int = 0
    var attachmentID: String = ""
    var number: Int = 0
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
}

// MARK: - Publication Data

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

// MARK: - Submission Data

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

// MARK: - Submitted File Data

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
