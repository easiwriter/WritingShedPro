//
//  WSPReaderTests.swift
//  WSP ReaderTests
//
//  Unit tests for WSP Reader models: local comments, annotated export,
//  ReaderAppState persistence, and WSPDocument parsing.
//

import XCTest
@testable import WSP_Reader

// MARK: - Helpers

/// Builds a minimal valid WSP JSON payload and writes it to a temp file.
@MainActor
private func makeWSPFile(
    projectName: String = "Test Project",
    projectType: String = "prose",
    folders: [WSPFolderData] = [],
    to directory: URL = FileManager.default.temporaryDirectory
) throws -> URL {
    var export = WSPExportData()
    export.project.name = projectName
    export.project.type = projectType
    export.folders = folders
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(export)
    let url = directory.appendingPathComponent("\(projectName).wsp")
    try data.write(to: url)
    return url
}

/// Builds a folder with one text file containing one version.
@MainActor
private func makeFolder(
    id: String = "f1",
    name: String = "Prose",
    versionID: String = "v1",
    fileID: String = "tf1",
    existingComments: [WSPCommentData] = []
) -> WSPFolderData {
    var version = WSPVersionData()
    version.id = versionID
    version.content = "Hello world"
    version.comments = existingComments
    var file = WSPTextFileData()
    file.id = fileID
    file.name = "Chapter 1"
    file.versions = [version]
    var folder = WSPFolderData()
    folder.id = id
    folder.name = name
    folder.textFiles = [file]
    return folder
}

// MARK: - ReaderAppState Local Comment Tests

@MainActor
final class ReaderAppStateLocalCommentTests: XCTestCase {

    var appState: ReaderAppState!

    override func setUp() {
        super.setUp()
        appState = ReaderAppState()
        // Clear any lingering comments from previous test runs
        appState.localComments = []
    }

    func testAddLocalComment() {
        let comment = ReaderLocalComment(
            text: "Great opening line",
            author: "Alice",
            versionID: "v1",
            fileID: "tf1",
            documentName: "My Novel"
        )
        appState.addLocalComment(comment)
        XCTAssertEqual(appState.localComments.count, 1)
        XCTAssertEqual(appState.localComments.first?.text, "Great opening line")
    }

    func testDeleteLocalComment() {
        let comment = ReaderLocalComment(
            text: "Check this",
            author: "Bob",
            versionID: "v1",
            fileID: "tf1",
            documentName: "My Novel"
        )
        appState.addLocalComment(comment)
        XCTAssertEqual(appState.localComments.count, 1)
        appState.deleteLocalComment(id: comment.id)
        XCTAssertTrue(appState.localComments.isEmpty)
    }

    func testFilterByFileAndVersion() {
        let c1 = ReaderLocalComment(text: "c1", author: "A", versionID: "v1", fileID: "f1", documentName: "Doc")
        let c2 = ReaderLocalComment(text: "c2", author: "A", versionID: "v2", fileID: "f1", documentName: "Doc")
        let c3 = ReaderLocalComment(text: "c3", author: "A", versionID: "v1", fileID: "f2", documentName: "Doc")
        appState.localComments = [c1, c2, c3]

        let result = appState.localComments(forFileID: "f1", versionID: "v1", documentName: "Doc")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.text, "c1")
    }

    func testFilterByDocumentName() {
        let c1 = ReaderLocalComment(text: "c1", author: "A", versionID: "v1", fileID: "f1", documentName: "Doc A")
        let c2 = ReaderLocalComment(text: "c2", author: "A", versionID: "v1", fileID: "f1", documentName: "Doc B")
        appState.localComments = [c1, c2]

        XCTAssertTrue(appState.hasLocalComments(forDocument: "Doc A"))
        XCTAssertTrue(appState.hasLocalComments(forDocument: "Doc B"))
        XCTAssertFalse(appState.hasLocalComments(forDocument: "Doc C"))
    }

    func testDeleteNonExistentCommentIsNoOp() {
        let comment = ReaderLocalComment(text: "keep", author: "A", versionID: "v1", fileID: "f1", documentName: "Doc")
        appState.localComments = [comment]
        appState.deleteLocalComment(id: "does-not-exist")
        XCTAssertEqual(appState.localComments.count, 1)
    }

    func testMultipleCommentsOnSameVersion() {
        let comments = (0..<5).map {
            ReaderLocalComment(text: "Comment \($0)", author: "A", versionID: "v1", fileID: "f1", documentName: "Doc")
        }
        comments.forEach { appState.addLocalComment($0) }
        let filtered = appState.localComments(forFileID: "f1", versionID: "v1", documentName: "Doc")
        XCTAssertEqual(filtered.count, 5)
    }
}

// MARK: - ReaderLocalComment Codable Tests

@MainActor
final class ReaderLocalCommentCodableTests: XCTestCase {

    func testRoundTripCodable() throws {
        let original = ReaderLocalComment(
            id: "abc123",
            text: "Nice passage",
            author: "Carol",
            versionID: "v99",
            fileID: "f42",
            documentName: "Poetry Collection",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ReaderLocalComment.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.text, original.text)
        XCTAssertEqual(decoded.author, original.author)
        XCTAssertEqual(decoded.versionID, original.versionID)
        XCTAssertEqual(decoded.fileID, original.fileID)
        XCTAssertEqual(decoded.documentName, original.documentName)
        XCTAssertEqual(decoded.createdAt.timeIntervalSince1970,
                       original.createdAt.timeIntervalSince1970,
                       accuracy: 1.0)
    }
}

// MARK: - WSPDocument Parsing Tests

@MainActor
final class WSPDocumentParsingTests: XCTestCase {

    func testParseMinimalWSPFile() throws {
        let url = try makeWSPFile(projectName: "My Story", projectType: "fiction")
        let doc = try WSPDocument(url: url)
        XCTAssertEqual(doc.projectName, "My Story")
        XCTAssertEqual(doc.projectType, "fiction")
        XCTAssertTrue(doc.folders.isEmpty)
        XCTAssertTrue(doc.allFiles.isEmpty)
    }

    func testParseFolderWithFile() throws {
        let folder = makeFolder(name: "Chapters", versionID: "v1", fileID: "tf1")
        let url = try makeWSPFile(projectName: "Novel", folders: [folder])
        let doc = try WSPDocument(url: url)
        XCTAssertEqual(doc.folders.count, 1)
        XCTAssertEqual(doc.allFiles.count, 1)
        XCTAssertEqual(doc.allFiles.first?.name, "Chapter 1")
    }

    func testEmptyProjectNameFallsBackToUntitled() throws {
        var export = WSPExportData()
        export.project.name = ""
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(export)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("empty.wsp")
        try data.write(to: url)
        let doc = try WSPDocument(url: url)
        XCTAssertEqual(doc.projectName, "Untitled")
    }

    func testInvalidJSONThrows() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bad.wsp")
        try "not json at all".write(to: url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try WSPDocument(url: url))
    }

    func testFindFileByID() throws {
        let folder = makeFolder(fileID: "unique-file-id")
        let url = try makeWSPFile(folders: [folder])
        let doc = try WSPDocument(url: url)
        let found = doc.findFile(byId: "unique-file-id")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, "unique-file-id")
        XCTAssertNil(doc.findFile(byId: "does-not-exist"))
    }

    func testAdjacentFileNavigation() throws {
        var folder = makeFolder()
        var file2 = WSPTextFileData()
        file2.id = "tf2"
        file2.name = "Chapter 2"
        file2.versions = [{ var v = WSPVersionData(); v.id = "v2"; return v }()]
        folder.textFiles.append(file2)
        let url = try makeWSPFile(folders: [folder])
        let doc = try WSPDocument(url: url)
        let files = doc.allFiles
        XCTAssertEqual(files.count, 2)
        let next = doc.adjacentFile(to: files[0], forward: true)
        XCTAssertEqual(next?.id, "tf2")
        let prev = doc.adjacentFile(to: files[0], forward: false)
        XCTAssertNil(prev)
    }

    func testRawExportDataIsRetained() throws {
        let url = try makeWSPFile(projectName: "Retention Test")
        let doc = try WSPDocument(url: url)
        XCTAssertEqual(doc.rawExportData.project.name, "Retention Test")
    }
}

// MARK: - Annotated Export Tests

@MainActor
final class AnnotatedExportTests: XCTestCase {

    func testExportWithNoLocalCommentsRoundTrips() throws {
        let folder = makeFolder(versionID: "v1", fileID: "tf1")
        let url = try makeWSPFile(projectName: "Clean Export", folders: [folder])
        let doc = try WSPDocument(url: url)

        let exportedData = try doc.exportDataMergingLocalComments([])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let roundTripped = try decoder.decode(WSPExportData.self, from: exportedData)
        XCTAssertEqual(roundTripped.project.name, "Clean Export")
    }

    func testLocalCommentAppearsInVersionNotes() throws {
        let folder = makeFolder(versionID: "v1", fileID: "tf1")
        let url = try makeWSPFile(projectName: "Annotated", folders: [folder])
        let doc = try WSPDocument(url: url)

        let localComment = ReaderLocalComment(
            text: "Lovely line",
            author: "Alice",
            versionID: "v1",
            fileID: "tf1",
            documentName: "Annotated"
        )
        let exportedData = try doc.exportDataMergingLocalComments([localComment])

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let parsed = try decoder.decode(WSPExportData.self, from: exportedData)

        let notes = parsed.folders.first?.textFiles.first?.versions.first?.notes ?? ""
        XCTAssertTrue(notes.contains("Lovely line"), "Comment text should appear in version notes")
        XCTAssertTrue(notes.contains("Alice"), "Author name should appear in version notes")
        XCTAssertTrue(notes.contains("--- Reader Comments ---"), "Header should be present")
    }

    func testCommentsArrayNotModifiedOnExport() throws {
        let folder = makeFolder(versionID: "v1", fileID: "tf1")
        let url = try makeWSPFile(folders: [folder])
        let doc = try WSPDocument(url: url)

        let comment = ReaderLocalComment(
            text: "A note",
            author: "A",
            versionID: "v1",
            fileID: "tf1",
            documentName: doc.projectName
        )
        let exportedData = try doc.exportDataMergingLocalComments([comment])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let parsed = try decoder.decode(WSPExportData.self, from: exportedData)
        // The comments array should be untouched — reader comments go to notes only
        let comments = parsed.folders.first?.textFiles.first?.versions.first?.comments ?? []
        XCTAssertTrue(comments.isEmpty, "Reader comments must not be injected into the comments array")
    }

    func testExistingNotesPreservedOnMerge() throws {
        var version = WSPVersionData()
        version.id = "v1"
        version.notes = "Existing author note"
        var file = WSPTextFileData()
        file.id = "tf1"
        file.name = "Chapter 1"
        file.versions = [version]
        var folder = WSPFolderData()
        folder.id = "f1"
        folder.name = "Prose"
        folder.textFiles = [file]
        let url = try makeWSPFile(folders: [folder])
        let doc = try WSPDocument(url: url)

        let comment = ReaderLocalComment(
            text: "Reader note",
            author: "Reader",
            versionID: "v1",
            fileID: "tf1",
            documentName: doc.projectName
        )
        let exportedData = try doc.exportDataMergingLocalComments([comment])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let parsed = try decoder.decode(WSPExportData.self, from: exportedData)
        let notes = parsed.folders.first?.textFiles.first?.versions.first?.notes ?? ""
        XCTAssertTrue(notes.contains("Existing author note"), "Original notes must be preserved")
        XCTAssertTrue(notes.contains("Reader note"), "Reader comment must be appended")
    }

    func testDuplicateExportDoesNotDoubleAppendNotes() throws {
        let folder = makeFolder(versionID: "v1", fileID: "tf1")
        let url = try makeWSPFile(folders: [folder])
        let doc = try WSPDocument(url: url)

        let comment = ReaderLocalComment(
            text: "Once only",
            author: "A",
            versionID: "v1",
            fileID: "tf1",
            documentName: doc.projectName
        )
        // Export twice — notes block should not appear twice
        let _ = try doc.exportDataMergingLocalComments([comment])
        let secondExport = try doc.exportDataMergingLocalComments([comment])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let parsed = try decoder.decode(WSPExportData.self, from: secondExport)
        let notes = parsed.folders.first?.textFiles.first?.versions.first?.notes ?? ""
        let occurrences = notes.components(separatedBy: "--- Reader Comments ---").count - 1
        XCTAssertEqual(occurrences, 1, "Reader comments header should appear exactly once")
    }

    func testCommentForWrongVersionNotMerged() throws {
        let folder = makeFolder(versionID: "v1", fileID: "tf1")
        let url = try makeWSPFile(folders: [folder])
        let doc = try WSPDocument(url: url)

        let wrongVersion = ReaderLocalComment(
            text: "Wrong version comment",
            author: "A",
            versionID: "v999",   // doesn't exist in this doc
            fileID: "tf1",
            documentName: doc.projectName
        )
        let exportedData = try doc.exportDataMergingLocalComments([wrongVersion])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let parsed = try decoder.decode(WSPExportData.self, from: exportedData)
        let notes = parsed.folders.first?.textFiles.first?.versions.first?.notes
        XCTAssertNil(notes, "Notes should not be set when versionID doesn't match")
    }

    func testExportProducesValidUTF8JSON() throws {
        let folder = makeFolder(versionID: "v1", fileID: "tf1")
        let url = try makeWSPFile(folders: [folder])
        let doc = try WSPDocument(url: url)
        let comment = ReaderLocalComment(text: "Ünïcödé çhàr§", author: "Ré", versionID: "v1", fileID: "tf1", documentName: doc.projectName)
        let data = try doc.exportDataMergingLocalComments([comment])
        XCTAssertNotNil(String(data: data, encoding: .utf8))
    }
}

// MARK: - ReaderAuthorName Tests

@MainActor
final class ReaderAuthorNameTests: XCTestCase {

    func testAuthorNamePersistsToUserDefaults() {
        let appState = ReaderAppState()
        appState.readerAuthorName = "Test Author"
        XCTAssertEqual(UserDefaults.standard.string(forKey: "WSPReaderAuthorName"), "Test Author")
        // Clean up
        UserDefaults.standard.removeObject(forKey: "WSPReaderAuthorName")
    }

    func testAuthorNameEmptyByDefault() {
        UserDefaults.standard.removeObject(forKey: "WSPReaderAuthorName")
        let appState = ReaderAppState()
        XCTAssertEqual(appState.readerAuthorName, "")
    }
}
