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
    var plotElements: [WSPPlotElementData]?
    // Feature 029: Back Matter References
    var noteEntries: [WSPNoteEntryData]?
    var glossaryEntries: [WSPGlossaryEntryData]?
    var referenceEntries: [WSPReferenceEntryData]?
    var citationEntries: [WSPCitationEntryData]?
    var indexEntries: [WSPIndexEntryData]?
    var contributorEntries: [WSPContributorEntryData]?
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
    // Feature 023: Drama
    var dramaScriptType: String?
    // Feature 029: Manuscript Assembly
    var manuscriptSettingsBase64: String?
    var tocSettingsBase64: String?
    // Feature 029: Contributor display settings
    var contributorDisplaySurnameFirst: Bool?
    var contributorDisplayRunTogether: Bool?
    var contributorBodyStyleName: String?
}

// MARK: - Prose Section Data

struct WSPProseSectionData: Codable {
    var id: String = ""
    var name: String = ""
    var synopsis: String?
    var userOrder: Int?
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
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
    var sectionId: String?
    var includedInManuscript: Bool?  // Optional for backward compatibility
    var contentTypeRaw: String?  // Optional for backward compatibility - "richText" or "markdown"
    var isTOCFile: Bool?  // Optional for backward compatibility - Feature 031
    var tocSettingsBase64: String?  // Base64 encoded TOCSettings JSON - Feature 031
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
    var comments: [WSPCommentData]?  // Optional for backward compatibility
    var footnotes: [WSPFootnoteData]?  // Optional for backward compatibility
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

struct WSPPlotElementData: Codable {
    var id: String = ""
    var name: String?
    var notes: String?
    var userOrder: Int?
    var monomythStageRaw: String?
    var campbellStageRaw: String?
    var threeActStageRaw: String?
    var pearsonStageRaw: String?
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    var linkedSceneIds: [String]?
    var characterIds: [String]?
    var locationIds: [String]?
}

// MARK: - Feature 029 Data Structures

struct WSPNoteEntryData: Codable {
    var id: String = ""
    var content: String = ""
    var formattedContentBase64: String?
    var isEndnote: Bool = false
    var displayNumber: Int = 0
    var referenceCount: Int = 0
    var referencingFileIDs: [String] = []
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var title: String?
    var tag: String?
}

struct WSPGlossaryEntryData: Codable {
    var id: String = ""
    var term: String = ""
    var definition: String = ""
    var citationId: String?
    var referenceCount: Int = 0
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
}

struct WSPReferenceEntryData: Codable {
    var id: String = ""
    var author: String = ""
    var publicationDate: String = ""
    var details: String = ""
    var referenceCount: Int = 0
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
}

struct WSPCitationEntryData: Codable {
    var id: String = ""
    var authors: [String] = []
    var year: Int?
    var title: String = ""
    var source: String?
    var url: String?
    var doi: String?
    var volume: String?
    var issue: String?
    var pages: String?
    var edition: String?
    var city: String?
    var accessDate: Date?
    var sourceTypeRaw: String?
    var referenceCount: Int = 0
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
}

struct WSPIndexEntryData: Codable {
    var id: String = ""
    var keyword: String = ""
    var parentEntryId: String?
    var seeEntryID: String?
    var seeAlsoEntryIDs: [String] = []
    var referenceCount: Int = 0
    var referencingFileIDs: [String] = []
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
}

struct WSPContributorEntryData: Codable {
    var id: String = ""
    var name: String = ""
    var firstName: String = ""
    var surname: String = ""
    var biography: String = ""
    var userOrder: Int = 0
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
}
