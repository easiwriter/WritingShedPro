//
//  WSPReaderTests.swift
//  WSP ReaderTests
//
//  Unit tests for WSP Reader models: local comments, annotated export,
//  ReaderAppState persistence, and WSPDocument parsing.
//

import XCTest
@testable import WSP_Reader
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Helpers

/// Builds a minimal valid WSP JSON payload and writes it to a temp file.
@MainActor
private func makeWSPFile(
    projectName: String = "Test Project",
    projectType: String = "prose",
    folders: [WSPFolderData] = [],
    exportDate: Date? = nil,
    to directory: URL = FileManager.default.temporaryDirectory
) throws -> URL {
    var export = WSPExportData()
    export.exportDate = exportDate
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

// MARK: - Attributed String Decoder Tests

final class WSPAttributeDecoderTests: XCTestCase {

    func testLocalReaderCommentMarkerIsInsertedAtAnchoredPosition() throws {
        let comment = ReaderLocalComment(
            id: "reader-comment",
            text: "Check this",
            author: "Reader",
            versionID: "v1",
            fileID: "f1",
            documentName: "Document",
            characterPosition: 5
        )
        let content = NSMutableAttributedString(string: "Hello world")

        WSPCommentMarker.insertLocalMarkers(for: [comment], into: content)

        XCTAssertEqual(content.string, "Hello\u{FFFC} world")
        XCTAssertNotNil(content.attribute(.attachment, at: 5, effectiveRange: nil))
        XCTAssertEqual(
            content.attribute(WSPCommentMarker.localMarkerKey, at: 5, effectiveRange: nil) as? String,
            comment.id
        )
    }

    func testUnanchoredReaderCommentDoesNotInsertMarker() {
        let comment = ReaderLocalComment(
            text: "Legacy comment",
            author: "Reader",
            versionID: "v1",
            fileID: "f1",
            documentName: "Document"
        )
        let content = NSMutableAttributedString(string: "Hello world")

        WSPCommentMarker.insertLocalMarkers(for: [comment], into: content)

        XCTAssertEqual(content.string, "Hello world")
    }

    func testCommentMarkerIsRenderedAsAttachment() throws {
        let runs: [[String: Any]] = [[
            "location": 5,
            "length": 1,
            "isCommentAttachment": true,
            "commentID": UUID().uuidString,
            "commentIsResolved": false
        ]]
        let data = try PropertyListSerialization.data(fromPropertyList: runs, format: .binary, options: 0)

        let decoded = try XCTUnwrap(WSPAttributeDecoder.decode(data, text: "Hello\u{FFFC}"))
        let attachment = try XCTUnwrap(decoded.attribute(.attachment, at: 5, effectiveRange: nil) as? NSTextAttachment)

        XCTAssertNotNil(attachment.image)
        XCTAssertEqual(attachment.bounds.size, CGSize(width: 22, height: 22))
    }

    func testResolvedCommentMarkerIsRenderedAsAttachment() throws {
        let runs: [[String: Any]] = [[
            "location": 0,
            "length": 1,
            "isCommentAttachment": true,
            "commentID": UUID().uuidString,
            "commentIsResolved": true
        ]]
        let data = try PropertyListSerialization.data(fromPropertyList: runs, format: .binary, options: 0)

        let decoded = try XCTUnwrap(WSPAttributeDecoder.decode(data, text: "\u{FFFC}"))
        let attachment = try XCTUnwrap(decoded.attribute(.attachment, at: 0, effectiveRange: nil) as? NSTextAttachment)

        XCTAssertNotNil(attachment.image)
    }

    func testImageCaptionIsRenderedAfterAttachment() throws {
        let onePixelPNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        let runs: [[String: Any]] = [[
            "location": 0,
            "length": 1,
            "isImageAttachment": true,
            "imageData": onePixelPNG,
            "imageScale": 1.0,
            "hasCaption": true,
            "captionPrefix": "Figure",
            "captionText": "Test caption",
            "captionStyle": "Caption"
        ]]
        let data = try PropertyListSerialization.data(
            fromPropertyList: runs,
            format: .binary,
            options: 0
        )

        let decoded = try XCTUnwrap(WSPAttributeDecoder.decode(data, text: "\u{FFFC}"))

        XCTAssertNotNil(decoded.attribute(.attachment, at: 0, effectiveRange: nil))
        XCTAssertTrue(decoded.string.contains("Figure Test caption"))
    }

    func testImageAlignmentAndSpacingArePreserved() throws {
        let onePixelPNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        let runs: [[String: Any]] = [[
            "location": 0,
            "length": 1,
            "isImageAttachment": true,
            "imageData": onePixelPNG,
            "imageAlignment": "right",
            "imageSpacingAbove": 12.0,
            "imageSpacingBelow": 18.0
        ]]
        let data = try PropertyListSerialization.data(fromPropertyList: runs, format: .binary, options: 0)

        let decoded = try XCTUnwrap(WSPAttributeDecoder.decode(data, text: "\u{FFFC}"))
        let paragraph = try XCTUnwrap(decoded.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)

        XCTAssertEqual(paragraph.alignment, .right)
        XCTAssertEqual(paragraph.paragraphSpacingBefore, 12)
        XCTAssertEqual(paragraph.paragraphSpacing, 18)
    }

    func testParagraphSpacingIsDecoded() throws {
        let runs: [[String: Any]] = [[
            "location": 0,
            "length": 7,
            "lineHeightMultiple": 1.4,
            "lineSpacing": 3.0,
            "spaceBefore": 9.0,
            "spaceAfter": 11.0
        ]]
        let data = try PropertyListSerialization.data(fromPropertyList: runs, format: .binary, options: 0)

        let decoded = try XCTUnwrap(WSPAttributeDecoder.decode(data, text: "Heading"))
        let paragraph = try XCTUnwrap(decoded.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)

        XCTAssertEqual(paragraph.lineHeightMultiple, 1.4, accuracy: 0.001)
        XCTAssertEqual(paragraph.lineSpacing, 3)
        XCTAssertEqual(paragraph.paragraphSpacingBefore, 9)
        XCTAssertEqual(paragraph.paragraphSpacing, 11)
    }

    #if canImport(UIKit)
    func testBlackFormattedTextAdaptsToDarkAppearance() throws {
        let runs: [[String: Any]] = [[
            "location": 0,
            "length": 4,
            "textColorHex": "000000"
        ]]
        let data = try PropertyListSerialization.data(fromPropertyList: runs, format: .binary, options: 0)
        let decoded = try XCTUnwrap(WSPAttributeDecoder.decode(data, text: "Text"))
        let color = try XCTUnwrap(decoded.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor)

        XCTAssertTrue(color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).isEqual(UIColor.white))
        XCTAssertTrue(color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).isEqual(UIColor.black))
    }

    func testReaderTextAppearanceMakesGrayscaleTextAdaptive() throws {
        let source = NSAttributedString(
            string: "Text",
            attributes: [.foregroundColor: UIColor(white: 0.2, alpha: 1)]
        )

        let adaptedText = ReaderTextAppearance.stripAdaptiveColors(from: source)
        let color = try XCTUnwrap(adaptedText.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor)

        XCTAssertTrue(color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).isEqual(UIColor.white))
        XCTAssertTrue(color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).isEqual(UIColor.black))
    }

    func testReaderTextAppearanceAddsAdaptiveColorWhenMissing() throws {
        let source = NSAttributedString(string: "Text")

        let adaptedText = ReaderTextAppearance.stripAdaptiveColors(from: source)
        let color = try XCTUnwrap(adaptedText.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor)

        XCTAssertTrue(color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).isEqual(UIColor.white))
        XCTAssertTrue(color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).isEqual(UIColor.black))
    }
    #endif

    func testHeadingNumbersAreMaterializedFromStylesheet() throws {
        let runs: [[String: Any]] = [
            ["location": 0, "length": 4, "textStyle": "Heading1"],
            ["location": 4, "length": 3, "textStyle": "Heading1"]
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: runs, format: .binary, options: 0)
        var headingStyle = WSPTextStyleData()
        headingStyle.name = "Heading1"
        headingStyle.numberFormatRaw = "decimal"
        headingStyle.numberAdornmentRaw = "period"
        var stylesheet = WSPStyleSheetData()
        stylesheet.textStyles = [headingStyle]

        let decoded = try XCTUnwrap(WSPAttributeDecoder.decode(data, text: "One\nTwo", stylesheet: stylesheet))

        XCTAssertEqual(decoded.string, "1.\tOne\n2.\tTwo")
    }

    func testCaptionNumbersContinueAcrossManuscriptFiles() throws {
        let onePixelPNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        func captionVersion(id: String, caption: String) throws -> WSPVersionData {
            let runs: [[String: Any]] = [[
                "location": 0,
                "length": 1,
                "isImageAttachment": true,
                "imageData": onePixelPNG,
                "hasCaption": true,
                "captionPrefix": "Figure",
                "captionText": caption,
                "captionStyle": "Caption"
            ]]
            let payload = try PropertyListSerialization.data(fromPropertyList: runs, format: .binary, options: 0)
            var version = WSPVersionData()
            version.id = id
            version.content = "\u{FFFC}"
            version.formattedContentBase64 = payload.base64EncodedString()
            return version
        }

        var firstFile = WSPTextFileData()
        firstFile.id = "first"
        firstFile.name = "First"
        firstFile.userOrder = 1
        firstFile.versions = [try captionVersion(id: "v1", caption: "First image")]
        var secondFile = WSPTextFileData()
        secondFile.id = "second"
        secondFile.name = "Second"
        secondFile.userOrder = 2
        secondFile.versions = [try captionVersion(id: "v2", caption: "Second image")]
        var folder = WSPFolderData()
        folder.id = "folder"
        folder.name = "Chapters"
        folder.textFiles = [firstFile, secondFile]

        var captionStyle = WSPTextStyleData()
        captionStyle.name = "Caption"
        captionStyle.numberFormatRaw = "decimal"
        captionStyle.numberAdornmentRaw = "period"
        var stylesheet = WSPStyleSheetData()
        stylesheet.textStyles = [captionStyle]
        var export = WSPExportData()
        export.project.name = "Caption Numbering"
        export.folders = [folder]
        export.stylesheet = stylesheet
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("caption-numbering.wsp")
        try encoder.encode(export).write(to: url)

        let document = try WSPDocument(url: url)
        let second = try XCTUnwrap(document.file(withID: "second"))
        let first = try XCTUnwrap(document.file(withID: "first"))

        XCTAssertTrue(second.attributedContent.string.contains("Figure 2. Second image"))
        XCTAssertTrue(first.attributedContent.string.contains("Figure 1. First image"))
    }
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

    func testUpdateAndResolveLocalComment() {
        let comment = ReaderLocalComment(
            text: "Original",
            author: "Reader",
            versionID: "v1",
            fileID: "tf1",
            documentName: "Document",
            characterPosition: 3
        )
        appState.localComments = [comment]

        appState.updateLocalComment(id: comment.id, text: "Edited")
        appState.toggleLocalCommentResolution(id: comment.id)

        XCTAssertEqual(appState.localComments.first?.text, "Edited")
        XCTAssertTrue(appState.localComments.first?.isResolved == true)

        appState.toggleLocalCommentResolution(id: comment.id)
        XCTAssertFalse(appState.localComments.first?.isResolved == true)
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

    func testDeleteLocalCommentsRemovesOnlyExportedIDs() {
        let first = ReaderLocalComment(
            id: "first",
            text: "First",
            author: "A",
            versionID: "v1",
            fileID: "f1",
            documentName: "Doc"
        )
        let second = ReaderLocalComment(
            id: "second",
            text: "Second",
            author: "A",
            versionID: "v1",
            fileID: "f1",
            documentName: "Doc"
        )
        appState.localComments = [first, second]

        appState.deleteLocalComments(ids: [first.id])

        XCTAssertEqual(appState.localComments.map(\.id), [second.id])
    }

    func testNewerWSPExportReconcilesOlderLocalComments() throws {
        let exportDate = Date(timeIntervalSince1970: 2_000)
        let url = try makeWSPFile(
            projectName: "Poetry forms",
            exportDate: exportDate
        )
        let document = try WSPDocument(url: url)
        let staleComment = ReaderLocalComment(
            id: "stale",
            text: "Deleted in WSP",
            author: "Reader",
            versionID: "v1",
            fileID: "f1",
            documentName: "Poetry forms",
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let newerComment = ReaderLocalComment(
            id: "newer",
            text: "Still local",
            author: "Reader",
            versionID: "v1",
            fileID: "f1",
            documentName: "Poetry forms",
            createdAt: Date(timeIntervalSince1970: 3_000)
        )
        let otherDocumentComment = ReaderLocalComment(
            id: "other",
            text: "Other project",
            author: "Reader",
            versionID: "v1",
            fileID: "f1",
            documentName: "Other",
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        appState.localComments = [staleComment, newerComment, otherDocumentComment]

        appState.reconcileLocalComments(with: document)

        XCTAssertEqual(Set(appState.localComments.map(\.id)), ["newer", "other"])
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
            characterPosition: 14,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            resolvedAt: Date(timeIntervalSince1970: 1_700_000_100)
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
        XCTAssertEqual(decoded.characterPosition, original.characterPosition)
        XCTAssertEqual(
            decoded.resolvedAt?.timeIntervalSince1970,
            original.resolvedAt?.timeIntervalSince1970,
            accuracy: 1.0
        )
        XCTAssertEqual(decoded.createdAt.timeIntervalSince1970,
                       original.createdAt.timeIntervalSince1970,
                       accuracy: 1.0)
    }

    func testLegacyCommentWithoutCharacterPositionStillDecodes() throws {
        let json = """
        {
          "id": "legacy",
          "text": "Existing comment",
          "author": "Reader",
          "versionID": "v1",
          "fileID": "f1",
          "documentName": "Document",
          "createdAt": "2023-11-14T22:13:20Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(ReaderLocalComment.self, from: Data(json.utf8))

        XCTAssertNil(decoded.characterPosition)
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

    func testLocalCommentIsExportedAsInlineWSPComment() throws {
        var folder = makeFolder(versionID: "v1", fileID: "tf1")
        folder.textFiles[0].versions[0].content = "Hello world"
        let url = try makeWSPFile(projectName: "Annotated", folders: [folder])
        let doc = try WSPDocument(url: url)

        let localComment = ReaderLocalComment(
            text: "Lovely line",
            author: "Alice",
            versionID: "v1",
            fileID: "tf1",
            documentName: "Annotated",
            characterPosition: 5
        )
        let exportedData = try doc.exportDataMergingLocalComments([localComment])

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let parsed = try decoder.decode(WSPExportData.self, from: exportedData)
        let version = try XCTUnwrap(parsed.folders.first?.textFiles.first?.versions.first)
        let comment = try XCTUnwrap(version.comments?.first)

        XCTAssertEqual(version.content, "Hello\u{FFFC} world")
        XCTAssertNil(version.notes)
        XCTAssertEqual(comment.id, localComment.id)
        XCTAssertEqual(comment.attachmentID, localComment.id)
        XCTAssertEqual(comment.characterPosition, 5)
        XCTAssertEqual(comment.text, "Lovely line")
        XCTAssertEqual(comment.author, "Alice")

        let attributesData = try XCTUnwrap(
            version.formattedContentBase64.flatMap(Data.init(base64Encoded:))
        )
        let decodedContent = try XCTUnwrap(
            WSPAttributeDecoder.decode(attributesData, text: version.content)
        )
        XCTAssertNotNil(decodedContent.attribute(.attachment, at: 5, effectiveRange: nil))
    }

    func testResolvedReaderCommentExportsResolvedMetadataAndMarker() throws {
        var folder = makeFolder(versionID: "v1", fileID: "tf1")
        folder.textFiles[0].versions[0].content = "Hello"
        let url = try makeWSPFile(folders: [folder])
        let doc = try WSPDocument(url: url)
        let resolvedAt = Date(timeIntervalSince1970: 1_700_000_100)
        let comment = ReaderLocalComment(
            text: "Resolved",
            author: "Reader",
            versionID: "v1",
            fileID: "tf1",
            documentName: doc.projectName,
            characterPosition: 2,
            resolvedAt: resolvedAt
        )

        let exportedData = try doc.exportDataMergingLocalComments([comment])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let parsed = try decoder.decode(WSPExportData.self, from: exportedData)
        let version = try XCTUnwrap(parsed.folders.first?.textFiles.first?.versions.first)
        let exportedComment = try XCTUnwrap(version.comments?.first)
        let attributesData = try XCTUnwrap(
            version.formattedContentBase64.flatMap(Data.init(base64Encoded:))
        )
        let runs = try XCTUnwrap(
            PropertyListSerialization.propertyList(
                from: attributesData,
                options: [],
                format: nil
            ) as? [[String: Any]]
        )
        let markerRun = try XCTUnwrap(runs.first(where: { $0["isCommentAttachment"] as? Bool == true }))

        XCTAssertEqual(exportedComment.resolvedAt?.timeIntervalSince1970, resolvedAt.timeIntervalSince1970)
        XCTAssertEqual(markerRun["commentIsResolved"] as? Bool, true)
    }

    func testExistingNotesRemainUnchanged() throws {
        var version = WSPVersionData()
        version.id = "v1"
        version.content = "Text"
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
            documentName: doc.projectName,
            characterPosition: 2
        )
        let exportedData = try doc.exportDataMergingLocalComments([comment])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let parsed = try decoder.decode(WSPExportData.self, from: exportedData)
        let exportedVersion = try XCTUnwrap(parsed.folders.first?.textFiles.first?.versions.first)

        XCTAssertEqual(exportedVersion.notes, "Existing author note")
        XCTAssertEqual(exportedVersion.comments?.first?.text, "Reader note")
    }

    func testMultipleCommentsUseFinalAttachmentPositions() throws {
        var folder = makeFolder(versionID: "v1", fileID: "tf1")
        folder.textFiles[0].versions[0].content = "abcdef"
        let url = try makeWSPFile(folders: [folder])
        let doc = try WSPDocument(url: url)

        let first = ReaderLocalComment(
            text: "First",
            author: "A",
            versionID: "v1",
            fileID: "tf1",
            documentName: doc.projectName,
            characterPosition: 1
        )
        let second = ReaderLocalComment(
            text: "Second",
            author: "B",
            versionID: "v1",
            fileID: "tf1",
            documentName: doc.projectName,
            characterPosition: 4
        )
        let exportedData = try doc.exportDataMergingLocalComments([second, first])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let parsed = try decoder.decode(WSPExportData.self, from: exportedData)
        let version = try XCTUnwrap(parsed.folders.first?.textFiles.first?.versions.first)

        XCTAssertEqual(version.content, "a\u{FFFC}bcd\u{FFFC}ef")
        XCTAssertEqual(version.comments?.map(\.characterPosition), [1, 5])
    }

    func testExistingCommentAndFootnotePositionsShiftAfterInsertion() throws {
        var folder = makeFolder(versionID: "v1", fileID: "tf1")
        folder.textFiles[0].versions[0].content = "abcdef"
        folder.textFiles[0].versions[0].comments = [
            WSPCommentData(
                id: UUID().uuidString,
                text: "Existing",
                author: "Author",
                characterPosition: 4,
                attachmentID: UUID().uuidString
            )
        ]
        folder.textFiles[0].versions[0].footnotes = [
            WSPFootnoteData(
                id: UUID().uuidString,
                text: "Footnote",
                characterPosition: 5,
                attachmentID: UUID().uuidString,
                number: 1
            )
        ]
        let url = try makeWSPFile(folders: [folder])
        let doc = try WSPDocument(url: url)
        let readerComment = ReaderLocalComment(
            text: "Reader",
            author: "Reader",
            versionID: "v1",
            fileID: "tf1",
            documentName: doc.projectName,
            characterPosition: 2
        )

        let exportedData = try doc.exportDataMergingLocalComments([readerComment])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let parsed = try decoder.decode(WSPExportData.self, from: exportedData)
        let version = try XCTUnwrap(parsed.folders.first?.textFiles.first?.versions.first)

        XCTAssertEqual(version.comments?.first?.characterPosition, 5)
        XCTAssertEqual(version.footnotes?.first?.characterPosition, 6)
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
            documentName: doc.projectName,
            characterPosition: 2
        )
        let exportedData = try doc.exportDataMergingLocalComments([wrongVersion])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let parsed = try decoder.decode(WSPExportData.self, from: exportedData)
        let version = try XCTUnwrap(parsed.folders.first?.textFiles.first?.versions.first)
        XCTAssertEqual(version.content, "Hello world")
        XCTAssertTrue((version.comments ?? []).isEmpty)
    }

    func testUnanchoredCommentFailsExport() throws {
        let folder = makeFolder(versionID: "v1", fileID: "tf1")
        let url = try makeWSPFile(folders: [folder])
        let doc = try WSPDocument(url: url)
        let comment = ReaderLocalComment(
            text: "No anchor",
            author: "A",
            versionID: "v1",
            fileID: "tf1",
            documentName: doc.projectName
        )

        XCTAssertThrowsError(try doc.exportDataMergingLocalComments([comment])) { error in
            guard case WSPAnnotatedExportError.missingCharacterPosition = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testExportProducesValidUTF8JSON() throws {
        let folder = makeFolder(versionID: "v1", fileID: "tf1")
        let url = try makeWSPFile(folders: [folder])
        let doc = try WSPDocument(url: url)
        let comment = ReaderLocalComment(
            text: "Ünïcödé çhàr§",
            author: "Ré",
            versionID: "v1",
            fileID: "tf1",
            documentName: doc.projectName,
            characterPosition: 5
        )
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
