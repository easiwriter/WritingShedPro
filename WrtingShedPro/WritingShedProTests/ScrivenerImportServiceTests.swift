import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class ScrivenerImportServiceTests: XCTestCase {
    func testReadsScrivener2NumericDocumentsAndPreservesTextContainerContent() throws {
        let packageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LegacyPoems-\(UUID().uuidString).scriv", isDirectory: true)
        let docs = packageURL.appendingPathComponent("Files/Docs", isDirectory: true)
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: packageURL) }
        let xml = """
        <ScrivenerProject Version="1.5" Creator="SCRMAC-2.8.1.2-26324">
          <Binder>
            <BinderItem ID="0" Type="DraftFolder">
              <Title>Poems</Title>
              <Children>
                <BinderItem ID="12" Type="Text">
                  <Title>Parent Poem</Title>
                  <Children>
                    <BinderItem ID="13" Type="Text">
                      <Title>Child Poem</Title>
                      <MetaData><IncludeInCompile>No</IncludeInCompile></MetaData>
                    </BinderItem>
                  </Children>
                </BinderItem>
              </Children>
            </BinderItem>
          </Binder>
        </ScrivenerProject>
        """
        let projectName = packageURL.deletingPathExtension().lastPathComponent
        try Data(xml.utf8).write(to: packageURL.appendingPathComponent("\(projectName).scrivx"))
        try Data("<broken".utf8).write(to: packageURL.appendingPathComponent("conflicted copy.scrivx"))
        try Data(#"{\rtf1\ansi First line\line Second line}"#.utf8).write(to: docs.appendingPathComponent("12.rtf"))
        try Data(#"{\rtf1\ansi Child text}"#.utf8).write(to: docs.appendingPathComponent("13.rtf"))

        let draft = try ScrivenerImportService.readProject(from: packageURL)
        let group = try XCTUnwrap(draft.binderItems.first)
        XCTAssertEqual(group.kind, .folder)
        XCTAssertEqual(group.children.map(\.title), ["Parent Poem", "Child Poem"])
        XCTAssertTrue(group.children[0].content.contains("First line"))
        XCTAssertTrue(group.children[0].content.contains("Second line"))
        XCTAssertNotNil(group.children[0].formattedContent)
        XCTAssertEqual(group.children[1].content, "Child text")
        XCTAssertFalse(group.children[1].includedInCompile)
        XCTAssertEqual(draft.documentCount, 2)
        XCTAssertTrue(draft.warnings.isEmpty)
    }

    func testRejectsInvalidLegacyDocumentID() throws {
        let packageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("UnsafeID-\(UUID().uuidString).scriv", isDirectory: true)
        try FileManager.default.createDirectory(
            at: packageURL.appendingPathComponent("Files/Docs"), withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: packageURL) }
        try Data("""
        <ScrivenerProject><Binder>
          <BinderItem ID="../outside" Type="Text"><Title>Invalid ID</Title></BinderItem>
        </Binder></ScrivenerProject>
        """.utf8).write(to: packageURL.appendingPathComponent("Project.scrivx"))
        XCTAssertThrowsError(try ScrivenerImportService.readProject(from: packageURL)) { error in
            guard case ScrivenerImportError.invalidDocument = error else {
                return XCTFail("Expected invalid document ID, got \(error)")
            }
        }
    }

    func testPoetryImportExposesBinderPoemsWithoutDuplicatingDocuments() throws {
        let schema = Schema([Project.self, Folder.self, TextFile.self, Version.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let draft = ScrivenerProjectDraft(
            projectName: "Poetry Import",
            binderItems: [binderItem(
                title: "Collection", kind: .folder,
                children: [binderItem(title: "Poem", kind: .document, content: "First line\nSecond line")]
            )],
            researchItems: [], trashItems: [], warnings: []
        )
        var options = ScrivenerImportOptions()
        options.projectType = .poetry

        let project = try ScrivenerImportService(modelContext: context).importProject(draft, options: options)
        let collection = try XCTUnwrap(project.poetryCollections?.first)
        let file = try XCTUnwrap(collection.textFiles?.first)
        XCTAssertEqual(file.currentContent, "First line\nSecond line")
        XCTAssertEqual(project.poetryContentFiles.map(\.id), [file.id])
        XCTAssertTrue(FolderCapabilityService.isInScrivenerBinder(file.parentFolder))
        XCTAssertEqual(file.project?.id, project.id)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TextFile>()), 1)
    }

    func testProseImportCreatesStandardFoldersAndIsolatesSourceBinder() throws {
        let schema = Schema([Project.self, Folder.self, TextFile.self, Version.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let scene = binderItem(title: "Scene", kind: .document, content: "Imported scene")
        let sourceFolders = ["Characters", "Settings", "Front Matter", "Back Matter", "Templates", "Notes"]
            .map { binderItem(title: $0, kind: .folder) }
        let draft = ScrivenerProjectDraft(
            projectName: "Prose Import",
            binderItems: [binderItem(title: "Act", kind: .folder, children: [scene])] + sourceFolders,
            researchItems: [],
            trashItems: [],
            warnings: []
        )

        let project = try ScrivenerImportService(modelContext: context).importProject(
            draft, options: ScrivenerImportOptions()
        )
        let roots = project.folders ?? []
        let names = Set(roots.compactMap(\.name))
        XCTAssertTrue(Set(["Manuscript", "Sections", "Prose", "Submissions", "Research",
                           "Magazines", "Competitions", "Publishers", "Agents", "Other", "Trash"])
            .isSubset(of: names))
        XCTAssertFalse(names.contains("Characters"))
        XCTAssertFalse(names.contains("Front Matter"))
        XCTAssertFalse(names.contains("Imported Documents"))
        let binder = try XCTUnwrap(roots.first { $0.name == FolderCapabilityService.scrivenerBinderFolderName })
        XCTAssertEqual(Set((binder.folders ?? []).compactMap(\.name)), Set(["Act"] + sourceFolders.map(\.title)))
        let importedMatter = try XCTUnwrap(binder.folders?.first { $0.name == "Front Matter" })
        XCTAssertFalse(importedMatter.isFrontMatterFolder)
        let importedBackMatter = try XCTUnwrap(binder.folders?.first { $0.name == "Back Matter" })
        XCTAssertFalse(importedBackMatter.isBackMatterFolder)
        for folder in binder.folders ?? [] {
            XCTAssertTrue(FolderCapabilityService.canAddFile(to: folder))
            XCTAssertTrue(FolderCapabilityService.canAddSubfolder(to: folder))
            XCTAssertNil(folder.project)
            XCTAssertEqual(folder.resolvedProject?.id, project.id)
        }
        let act = try XCTUnwrap(binder.folders?.first { $0.name == "Act" })
        let file = try XCTUnwrap(act.textFiles?.first)
        XCTAssertEqual(file.currentContent, "Imported scene")
        XCTAssertEqual(file.section?.name, "Act")
        XCTAssertEqual(file.section?.bodyMatterOrder, 0)
        XCTAssertEqual(project.proseContentFiles.map(\.id), [file.id])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TextFile>()), 1)
        let manuscript = try XCTUnwrap(roots.first { $0.name == "Manuscript" })
        XCTAssertTrue(manuscript.folders?.first { $0.name == "Front Matter" }?.isFrontMatterFolder == true)
    }

    func testLooseDocumentStaysInBinderAndAppearsInProse() throws {
        let schema = Schema([Project.self, Folder.self, TextFile.self, Version.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let draft = ScrivenerProjectDraft(
            projectName: "Loose Document",
            binderItems: [binderItem(title: "Untitled", kind: .document, content: "Test")],
            researchItems: [],
            trashItems: [],
            warnings: []
        )

        let project = try ScrivenerImportService(modelContext: context).importProject(
            draft, options: ScrivenerImportOptions()
        )
        let binder = try XCTUnwrap(project.folders?.first {
            $0.name == FolderCapabilityService.scrivenerBinderFolderName
        })
        let file = try XCTUnwrap(binder.textFiles?.first)
        XCTAssertEqual(file.currentContent, "Test")
        XCTAssertEqual(project.proseContentFiles.map(\.id), [file.id])
        XCTAssertEqual(file.section?.name, "Imported Documents")
        XCTAssertEqual(file.section?.textFiles?.map(\.id), [file.id])
        XCTAssertFalse(project.folders?.contains { $0.name == "Imported Documents" } == true)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TextFile>()), 1)
    }

    func testOptionalResearchStaysOutsideProseSectionsAndManuscript() throws {
        let schema = Schema([Project.self, Folder.self, TextFile.self, Version.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let research = binderItem(
            title: "Research", kind: .folder,
            children: [binderItem(title: "Notes", kind: .document, content: "Reference")]
        )
        let draft = ScrivenerProjectDraft(
            projectName: "Research Import", binderItems: [], researchItems: [research],
            trashItems: [], warnings: []
        )
        var options = ScrivenerImportOptions()
        options.includeResearch = true

        let project = try ScrivenerImportService(modelContext: context).importProject(draft, options: options)
        let binder = try XCTUnwrap(project.folders?.first {
            $0.name == FolderCapabilityService.scrivenerBinderFolderName
        })
        let importedResearch = try XCTUnwrap(binder.folders?.first { $0.name == "Research" })
        let file = try XCTUnwrap(importedResearch.textFiles?.first)
        XCTAssertFalse(file.includedInManuscript)
        XCTAssertNil(file.section)
        XCTAssertTrue(project.proseContentFiles.isEmpty)
        XCTAssertTrue(project.sections?.isEmpty == true)
        XCTAssertEqual(file.project?.id, project.id)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TextFile>()), 1)
    }

    private func binderItem(
        title: String,
        kind: ScrivenerBinderItem.Kind,
        content: String = "",
        children: [ScrivenerBinderItem] = []
    ) -> ScrivenerBinderItem {
        ScrivenerBinderItem(
            id: UUID(), title: title, sourceType: kind == .folder ? "Folder" : "Text",
            kind: kind, children: children, content: content, formattedContent: nil,
            includedInCompile: true
        )
    }

    func testReadsDraftTreeContentCompileFlagsAndOptionalRoots() throws {
        let packageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestProject-\(UUID().uuidString).scriv", isDirectory: true)
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: packageURL) }

        let chapterID = UUID()
        let includedDocumentID = UUID()
        let excludedDocumentID = UUID()
        let researchID = UUID()
        let trashID = UUID()

        let projectXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ScrivenerProject>
          <Binder>
            <BinderItem UUID="\(UUID().uuidString)" Type="Draft">
              <Title>Draft</Title>
              <BinderItem UUID="\(chapterID.uuidString)" Type="Folder">
                <Title>Chapter One</Title>
                <BinderItem UUID="\(includedDocumentID.uuidString)" Type="Text">
                  <Title>Opening</Title>
                </BinderItem>
                <BinderItem UUID="\(excludedDocumentID.uuidString)" Type="Text">
                  <Title>Outline</Title>
                  <MetaData><IncludeInCompile>No</IncludeInCompile></MetaData>
                </BinderItem>
              </BinderItem>
            </BinderItem>
            <BinderItem UUID="\(UUID().uuidString)" Type="Folder">
              <Title>Research</Title>
              <BinderItem UUID="\(researchID.uuidString)" Type="Text">
                <Title>Notes</Title>
              </BinderItem>
            </BinderItem>
            <BinderItem UUID="\(UUID().uuidString)" Type="Folder">
              <Title>Trash</Title>
              <BinderItem UUID="\(trashID.uuidString)" Type="Text">
                <Title>Deleted draft</Title>
              </BinderItem>
            </BinderItem>
          </Binder>
        </ScrivenerProject>
        """
        let projectFileURL = packageURL.appendingPathComponent("TestProject.scrivx")
        try Data(projectXML.utf8).write(to: projectFileURL)

        try writeText("Opening content", uuid: includedDocumentID, packageURL: packageURL)
        try writeText("Outline content", uuid: excludedDocumentID, packageURL: packageURL)
        try writeText("Research content", uuid: researchID, packageURL: packageURL)
        try writeText("Deleted content", uuid: trashID, packageURL: packageURL)

        let draft = try ScrivenerImportService.readProject(from: packageURL)

        XCTAssertEqual(draft.projectName, packageURL.deletingPathExtension().lastPathComponent)
        XCTAssertEqual(draft.binderItems.count, 1)
        XCTAssertEqual(draft.binderItems[0].title, "Chapter One")
        XCTAssertEqual(draft.binderItems[0].children.map(\.title), ["Opening", "Outline"])
        XCTAssertEqual(draft.binderItems[0].children[0].content, "Opening content")
        XCTAssertTrue(draft.binderItems[0].children[0].includedInCompile)
        XCTAssertFalse(draft.binderItems[0].children[1].includedInCompile)
        XCTAssertEqual(draft.researchItems.first?.children.first?.content, "Research content")
        XCTAssertEqual(draft.trashItems.first?.children.first?.content, "Deleted content")
        XCTAssertEqual(draft.folderCount, 3)
        XCTAssertEqual(draft.documentCount, 4)
        XCTAssertTrue(draft.warnings.isEmpty)
    }

    func testReadsScrivener3FolderTypesWithCustomTitlesAndRichText() throws {
        let packageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Scrivener3-\(UUID().uuidString).scriv", isDirectory: true)
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: packageURL) }

        let documentID = UUID()
        let xml = """
        <ScrivenerProject Version="2.0">
          <Binder>
            <BinderItem UUID="\(UUID().uuidString)" Type="DraftFolder">
              <Title>Manuscript</Title>
              <Children>
                <BinderItem UUID="\(documentID.uuidString)" Type="Text">
                  <MetaData><IncludeInCompile>Yes</IncludeInCompile></MetaData>
                </BinderItem>
              </Children>
            </BinderItem>
            <BinderItem UUID="\(UUID().uuidString)" Type="ResearchFolder">
              <Title>Reference Material</Title>
            </BinderItem>
            <BinderItem UUID="\(UUID().uuidString)" Type="TrashFolder">
              <Title>Deleted Items</Title>
            </BinderItem>
          </Binder>
        </ScrivenerProject>
        """
        try Data(xml.utf8).write(to: packageURL.appendingPathComponent("Project.scrivx"))
        let contentDirectory = packageURL.appendingPathComponent("Files/Data", isDirectory: true)
            .appendingPathComponent(documentID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: contentDirectory, withIntermediateDirectories: true)
        try Data(#"{\rtf1\ansi Test}"#.utf8)
            .write(to: contentDirectory.appendingPathComponent("content.rtf"))

        let draft = try ScrivenerImportService.readProject(from: packageURL)

        XCTAssertEqual(draft.binderItems.count, 1)
        XCTAssertEqual(draft.binderItems.first?.kind, .document)
        XCTAssertEqual(draft.binderItems.first?.content, "Test")
        XCTAssertNotNil(draft.binderItems.first?.formattedContent)
        XCTAssertEqual(draft.researchItems.first?.title, "Reference Material")
        XCTAssertEqual(draft.researchItems.first?.kind, .folder)
        XCTAssertEqual(draft.trashItems.first?.title, "Deleted Items")
        XCTAssertEqual(draft.trashItems.first?.kind, .folder)
        XCTAssertEqual(draft.folderCount, 2)
        XCTAssertEqual(draft.documentCount, 1)
        XCTAssertTrue(draft.warnings.isEmpty)
    }

    func testRejectsNonScrivenerPackage() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotScrivener-\(UUID().uuidString).txt")
        try Data("not a project".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        XCTAssertThrowsError(try ScrivenerImportService.readProject(from: fileURL)) { error in
            XCTAssertTrue(error is ScrivenerImportError)
        }
    }

    func testIdentifiesUnsupportedScrivener1Package() throws {
        let packageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Legacy-\(UUID().uuidString).scriv", isDirectory: true)
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: packageURL) }
        try Data("legacy binder".utf8).write(to: packageURL.appendingPathComponent("binder.scrivproj"))

        XCTAssertThrowsError(try ScrivenerImportService.readProject(from: packageURL)) { error in
            guard case ScrivenerImportError.unsupportedLegacyProject = error else {
                return XCTFail("Expected unsupported legacy format, got \(error)")
            }
        }
    }

    private func writeText(_ text: String, uuid: UUID, packageURL: URL) throws {
        let directory = packageURL
            .appendingPathComponent("Files/Data", isDirectory: true)
            .appendingPathComponent(uuid.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(text.utf8).write(to: directory.appendingPathComponent("content.txt"))
    }
}
