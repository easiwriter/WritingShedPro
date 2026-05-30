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
        exportData.formatVersion = "1.3"
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
        exportData.plotElements = buildPlotElementData(from: project)
        
        // Feature 029: Back matter references
        exportData.noteEntries = buildNoteEntryData(from: project)
        exportData.glossaryEntries = buildGlossaryEntryData(from: project)
        exportData.referenceEntries = buildReferenceEntryData(from: project)
        exportData.citationEntries = buildCitationEntryData(from: project)
        exportData.indexEntries = buildIndexEntryData(from: project)
        exportData.contributorEntries = buildContributorEntryData(from: project)
        
        // Stylesheet
        exportData.stylesheet = buildStyleSheetData(from: project)
        
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
        print("[JSONExport]   Plot Elements: \(exportData.plotElements?.count ?? 0)")
        print("[JSONExport]   Note Entries: \(exportData.noteEntries?.count ?? 0)")
        print("[JSONExport]   Glossary Entries: \(exportData.glossaryEntries?.count ?? 0)")
        print("[JSONExport]   Reference Entries: \(exportData.referenceEntries?.count ?? 0)")
        print("[JSONExport]   Citation Entries: \(exportData.citationEntries?.count ?? 0)")
        print("[JSONExport]   Index Entries: \(exportData.indexEntries?.count ?? 0)")
        print("[JSONExport]   Contributor Entries: \(exportData.contributorEntries?.count ?? 0)")
        print("[JSONExport]   Stylesheet: \(exportData.stylesheet?.name ?? "none") (\(exportData.stylesheet?.textStyles.count ?? 0) text styles)")
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
            author: project.author,
            fictionClass: project.fictionClassRaw,
            useMonomyth: project.useMonomyth,
            storyStructure: project.storyStructureRaw,
            dramaScriptType: project.dramaScriptTypeRaw,
            manuscriptSettingsBase64: project.manuscriptSettingsData?.base64EncodedString(),
            tocSettingsBase64: project.tocSettingsData?.base64EncodedString(),
            contributorDisplaySurnameFirst: project.contributorDisplaySurnameFirst,
            contributorDisplayRunTogether: project.contributorDisplayRunTogether,
            contributorBodyStyleName: project.contributorBodyStyleName != "body" ? project.contributorBodyStyleName : nil
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
            subfolders: subfolders,
            frontMatterSettingsBase64: folder.frontMatterSettingsData?.base64EncodedString(),
            backMatterSettingsBase64: folder.backMatterSettingsData?.base64EncodedString(),
            dramaFrontMatterSettingsBase64: folder.dramaFrontMatterSettingsData?.base64EncodedString(),
            dramaBackMatterSettingsBase64: folder.dramaBackMatterSettingsData?.base64EncodedString()
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
        
        // Encode cover image as base64 if this is a cover file
        var coverImageBase64: String? = nil
        if textFile.isCoverFile, let data = textFile.coverImageData {
            coverImageBase64 = data.base64EncodedString()
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
            sectionIds: textFile.sections?.map { $0.id.uuidString },
            includedInManuscript: textFile.includedInManuscript,
            contentTypeRaw: textFile.contentTypeRaw != "richText" ? textFile.contentTypeRaw : nil,  // Only export if not default
            isTOCFile: textFile.isTOCFile ? true : nil,  // Only export if true
            tocSettingsBase64: tocSettingsBase64,
            poetryCollectionId: textFile.poetryCollection?.id.uuidString,
            poetryCollectionIds: textFile.poetryCollections?.map { $0.id.uuidString },
            isCoverFile: textFile.isCoverFile ? true : nil,  // Only export if true
            coverImageBase64: coverImageBase64,
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

        var notesFormattedContentBase64: String? = nil
        if let data = version.notesFormattedContent {
            notesFormattedContentBase64 = data.base64EncodedString()
        }
        
        // Export comments
        let comments = (version.comments ?? []).map { buildCommentData(from: $0) }
        
        // Export footnotes
        let footnotes = (version.footnotes ?? []).map { buildFootnoteData(from: $0) }
        
        return WSPVersionData(
            id: version.id.uuidString,
            content: version.content,
            formattedContentBase64: formattedContentBase64,
            notesFormattedContentBase64: notesFormattedContentBase64,
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
                chapterIds: scene.chapters?.map { $0.id.uuidString },
                actId: scene.act?.id.uuidString,
                actIds: scene.acts?.map { $0.id.uuidString },
                bookId: scene.book?.id.uuidString,
                bookIds: scene.books?.map { $0.id.uuidString },
                textFileId: scene.textFile?.id.uuidString,
                isTrashed: scene.isTrashed,
                trashedDate: scene.trashedDate,
                monomythStageRaw: scene.monomythStageRaw,
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
                archetypeRaw: nil,
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
    
    // MARK: - Plot Element Data
    
    private func buildPlotElementData(from project: Project) -> [WSPPlotElementData] {
        guard let plotElements = project.plotElements, !plotElements.isEmpty else { return [] }
        
        return plotElements.map { element in
            WSPPlotElementData(
                id: element.id.uuidString,
                name: element.name,
                notes: element.notes,
                userOrder: element.userOrder,
                monomythStageRaw: element.monomythStageRaw,
                threeActStageRaw: element.threeActStageRaw,
                createdDate: element.createdDate,
                modifiedDate: element.modifiedDate,
                linkedSceneIds: element.linkedScenes?.map { $0.id.uuidString },
                characterIds: element.characters?.map { $0.id.uuidString },
                locationIds: element.locations?.map { $0.id.uuidString }
            )
        }
    }
    
    // MARK: - Feature 029: Note Entry Data
    
    private func buildNoteEntryData(from project: Project) -> [WSPNoteEntryData] {
        guard let notes = project.noteEntries, !notes.isEmpty else { return [] }
        
        return notes.map { note in
            WSPNoteEntryData(
                id: note.id.uuidString,
                content: note.content,
                formattedContentBase64: note.formattedContentData?.base64EncodedString(),
                isEndnote: note.isEndnote,
                displayNumber: note.displayNumber,
                referenceCount: note.referenceCount,
                referencingFileIDs: note.referencingFileIDs.map { $0.uuidString },
                createdAt: note.createdAt,
                modifiedAt: note.modifiedAt,
                title: note.title,
                tag: note.tag
            )
        }
    }
    
    // MARK: - Feature 029: Glossary Entry Data
    
    private func buildGlossaryEntryData(from project: Project) -> [WSPGlossaryEntryData] {
        guard let entries = project.glossaryEntries, !entries.isEmpty else { return [] }
        
        return entries.map { entry in
            WSPGlossaryEntryData(
                id: entry.id.uuidString,
                term: entry.term,
                definition: entry.definition,
                citationId: entry.citation?.id.uuidString,
                referenceCount: entry.referenceCount,
                createdAt: entry.createdAt,
                modifiedAt: entry.modifiedAt
            )
        }
    }
    
    // MARK: - Feature 029: Reference Entry Data
    
    private func buildReferenceEntryData(from project: Project) -> [WSPReferenceEntryData] {
        guard let entries = project.referenceEntries, !entries.isEmpty else { return [] }
        
        return entries.map { entry in
            WSPReferenceEntryData(
                id: entry.id.uuidString,
                author: entry.author,
                publicationDate: entry.publicationDate,
                details: entry.details,
                referenceCount: entry.referenceCount,
                createdAt: entry.createdAt,
                modifiedAt: entry.modifiedAt
            )
        }
    }
    
    // MARK: - Feature 029: Citation Entry Data
    
    private func buildCitationEntryData(from project: Project) -> [WSPCitationEntryData] {
        guard let entries = project.citationEntries, !entries.isEmpty else { return [] }
        
        return entries.map { entry in
            WSPCitationEntryData(
                id: entry.id.uuidString,
                authors: entry.authors,
                year: entry.year,
                title: entry.title,
                source: entry.source,
                url: entry.url,
                doi: entry.doi,
                volume: entry.volume,
                issue: entry.issue,
                pages: entry.pages,
                edition: entry.edition,
                city: entry.city,
                accessDate: entry.accessDate,
                sourceTypeRaw: entry.sourceTypeRaw,
                referenceCount: entry.referenceCount,
                createdAt: entry.createdAt,
                modifiedAt: entry.modifiedAt
            )
        }
    }
    
    // MARK: - Feature 029: Index Entry Data
    
    private func buildIndexEntryData(from project: Project) -> [WSPIndexEntryData] {
        guard let entries = project.indexEntries, !entries.isEmpty else { return [] }
        
        return entries.map { entry in
            WSPIndexEntryData(
                id: entry.id.uuidString,
                keyword: entry.keyword,
                parentEntryId: entry.parentEntry?.id.uuidString,
                seeEntryID: entry.seeEntryID?.uuidString,
                seeAlsoEntryIDs: entry.seeAlsoEntryIDs.map { $0.uuidString },
                referenceCount: entry.referenceCount,
                referencingFileIDs: entry.referencingFileIDs.map { $0.uuidString },
                createdAt: entry.createdAt,
                modifiedAt: entry.modifiedAt
            )
        }
    }
    
    // MARK: - Feature 029: Contributor Entry Data
    
    private func buildContributorEntryData(from project: Project) -> [WSPContributorEntryData] {
        guard let entries = project.contributorEntries, !entries.isEmpty else { return [] }
        
        return entries.map { entry in
            WSPContributorEntryData(
                id: entry.id.uuidString,
                name: entry.name,
                firstName: entry.firstName,
                surname: entry.surname,
                biography: entry.biography,
                userOrder: entry.userOrder,
                createdAt: entry.createdAt,
                modifiedAt: entry.modifiedAt
            )
        }
    }
    
    // MARK: - Stylesheet Data
    
    private func buildStyleSheetData(from project: Project) -> WSPStyleSheetData? {
        guard let sheet = project.styleSheet else { return nil }
        
        let textStyles = (sheet.textStyles ?? []).map { style in
            WSPTextStyleData(
                id: style.id.uuidString,
                name: style.name,
                displayName: style.displayName,
                displayOrder: style.displayOrder,
                fontFamily: style.fontFamily,
                fontName: style.fontName,
                fontSize: style.fontSize,
                isBold: style.isBold,
                isItalic: style.isItalic,
                isUnderlined: style.isUnderlined,
                isStrikethrough: style.isStrikethrough,
                textColorHex: style.textColorHex,
                alignmentRaw: style.alignmentRaw,
                lineSpacing: style.lineSpacing,
                paragraphSpacingBefore: style.paragraphSpacingBefore,
                paragraphSpacingAfter: style.paragraphSpacingAfter,
                firstLineIndent: style.firstLineIndent,
                headIndent: style.headIndent,
                tailIndent: style.tailIndent,
                lineHeightMultiple: style.lineHeightMultiple,
                minimumLineHeight: style.minimumLineHeight,
                maximumLineHeight: style.maximumLineHeight,
                numberFormatRaw: style.numberFormatRaw,
                numberAdornmentRaw: style.numberAdornmentRaw,
                followOnStyleName: style.followOnStyleName,
                parentStyleName: style.parentStyleName,
                styleCategoryRaw: style.styleCategoryRaw,
                isSystemStyle: style.isSystemStyle,
                includeInTOC: style.includeInTOC,
                tocLevel: style.tocLevel
            )
        }
        
        let imageStyles = (sheet.imageStyles ?? []).map { style in
            WSPImageStyleData(
                id: style.id.uuidString,
                name: style.name,
                displayName: style.displayName,
                displayOrder: style.displayOrder,
                defaultScale: style.defaultScale,
                defaultAlignmentRaw: style.defaultAlignmentRaw,
                hasCaptionByDefault: style.hasCaptionByDefault,
                defaultCaptionStyle: style.defaultCaptionStyle,
                isSystemStyle: style.isSystemStyle
            )
        }
        
        return WSPStyleSheetData(
            id: sheet.id.uuidString,
            name: sheet.name,
            isSystemStyleSheet: sheet.isSystemStyleSheet,
            createdDate: sheet.createdDate,
            modifiedDate: sheet.modifiedDate,
            textStyles: textStyles,
            imageStyles: imageStyles.isEmpty ? nil : imageStyles
        )
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
    var plotElements: [WSPPlotElementData]?
    // Feature 029: Back Matter References
    var noteEntries: [WSPNoteEntryData]?
    var glossaryEntries: [WSPGlossaryEntryData]?
    var referenceEntries: [WSPReferenceEntryData]?
    var citationEntries: [WSPCitationEntryData]?
    var indexEntries: [WSPIndexEntryData]?
    var contributorEntries: [WSPContributorEntryData]?
    // Stylesheet
    var stylesheet: WSPStyleSheetData?
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
    var author: String?
    var fictionClass: String?
    var useMonomyth: Bool = false  // Legacy, kept for backward compatibility
    var storyStructure: String?    // New: StoryStructure raw value
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
    // Matter settings (Base64-encoded JSON)
    var frontMatterSettingsBase64: String?
    var backMatterSettingsBase64: String?
    var dramaFrontMatterSettingsBase64: String?
    var dramaBackMatterSettingsBase64: String?
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
    var sectionIds: [String]?  // v1.3: many-to-many sections
    var includedInManuscript: Bool?  // Optional for backward compatibility, defaults to true
    var contentTypeRaw: String?  // Optional for backward compatibility - "richText" or "markdown"
    var isTOCFile: Bool?  // Optional for backward compatibility - Feature 031
    var tocSettingsBase64: String?  // Base64 encoded TOCSettings JSON - Feature 031
    var poetryCollectionId: String?  // Feature 036: link to PoetryCollection
    var poetryCollectionIds: [String]?  // v1.3: many-to-many poetry collections
    var isCoverFile: Bool?  // Cover image file (Front Cover / Back Cover)
    var coverImageBase64: String?  // Base64 encoded cover image data (JPEG/PNG)
    var versions: [WSPVersionData] = []
}

struct WSPVersionData: Codable {
    var id: String = ""
    var content: String = ""
    var formattedContentBase64: String?
    var notesFormattedContentBase64: String?
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
    var chapterIds: [String]?  // v1.3: many-to-many chapters
    var actId: String?
    var actIds: [String]?  // v1.3: many-to-many acts
    var bookId: String?
    var bookIds: [String]?  // v1.3: many-to-many books
    var textFileId: String?
    var isTrashed: Bool = false
    var trashedDate: Date?
    var monomythStageRaw: String?
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
    var threeActStageRaw: String?
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

// MARK: - Stylesheet Data Structures

struct WSPStyleSheetData: Codable {
    var id: String = ""
    var name: String = ""
    var isSystemStyleSheet: Bool = false
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    var textStyles: [WSPTextStyleData] = []
    var imageStyles: [WSPImageStyleData]?
}

struct WSPTextStyleData: Codable {
    var id: String = ""
    var name: String = ""
    var displayName: String = ""
    var displayOrder: Int = 0
    
    // Font attributes
    var fontFamily: String?
    var fontName: String?
    var fontSize: CGFloat = 17
    var isBold: Bool = false
    var isItalic: Bool = false
    var isUnderlined: Bool = false
    var isStrikethrough: Bool = false
    var textColorHex: String?
    
    // Paragraph attributes
    var alignmentRaw: Int = 0
    var lineSpacing: CGFloat = 0
    var paragraphSpacingBefore: CGFloat = 0
    var paragraphSpacingAfter: CGFloat = 0
    var firstLineIndent: CGFloat = 0
    var headIndent: CGFloat = 0
    var tailIndent: CGFloat = 0
    var lineHeightMultiple: CGFloat = 0
    var minimumLineHeight: CGFloat = 0
    var maximumLineHeight: CGFloat = 0
    
    // Numbering
    var numberFormatRaw: String = "none"
    var numberAdornmentRaw: String = "period"
    
    // Follow-on and hierarchy
    var followOnStyleName: String?
    var parentStyleName: String?
    
    // Classification
    var styleCategoryRaw: String = "text"
    var isSystemStyle: Bool = false
    
    // TOC
    var includeInTOC: Bool = false
    var tocLevel: Int = 0
}

struct WSPImageStyleData: Codable {
    var id: String = ""
    var name: String = ""
    var displayName: String = ""
    var displayOrder: Int = 0
    var defaultScale: CGFloat = 1.0
    var defaultAlignmentRaw: String = "center"
    var hasCaptionByDefault: Bool = false
    var defaultCaptionStyle: String = "UICTFontTextStyleCaption1"
    var isSystemStyle: Bool = false
}
