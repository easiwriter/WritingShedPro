import Foundation
import SwiftData
import UIKit

struct ScrivenerBinderItem: Identifiable {
    enum Kind: Equatable {
        case folder
        case document
    }

    let id: UUID
    let title: String
    let sourceType: String
    let kind: Kind
    let children: [ScrivenerBinderItem]
    let content: String
    let formattedContent: Data?
    let includedInCompile: Bool
}

struct ScrivenerProjectDraft: Identifiable {
    let id = UUID()
    let projectName: String
    let binderItems: [ScrivenerBinderItem]
    let researchItems: [ScrivenerBinderItem]
    let trashItems: [ScrivenerBinderItem]
    let warnings: [String]

    var folderCount: Int {
        (binderItems + researchItems + trashItems).reduce(0) { $0 + $1.folderCount }
    }

    var documentCount: Int {
        (binderItems + researchItems + trashItems).reduce(0) { $0 + $1.documentCount }
    }
}

extension ScrivenerBinderItem {
    var folderCount: Int {
        (kind == .folder ? 1 : 0) + children.reduce(0) { $0 + $1.folderCount }
    }

    var documentCount: Int {
        (kind == .document ? 1 : 0) + children.reduce(0) { $0 + $1.documentCount }
    }
}

struct ScrivenerImportOptions {
    var projectType: ProjectType = .prose
    var fictionClass: FictionClass = .novel
    var dramaScriptType: DramaScriptType = .film
    var includeResearch = false
    var includeTrash = false
}

enum ScrivenerImportError: Error, LocalizedError {
    case invalidProject
    case unsupportedLegacyProject
    case invalidBinder(String)
    case invalidDocument(String)
    case invalidRichText(String)
    case projectLimit
    case fileLimit
    case accessCheckFailed

    var errorDescription: String? {
        switch self {
        case .invalidProject:
            return NSLocalizedString("scrivener.error.invalidProject", comment: "Invalid Scrivener project")
        case .unsupportedLegacyProject:
            return NSLocalizedString("scrivener.error.unsupportedLegacyProject", comment: "Unsupported legacy Scrivener project")
        case .invalidBinder(let detail):
            return String(
                format: NSLocalizedString("scrivener.error.invalidBinder", comment: "Invalid Scrivener binder"),
                detail
            )
        case .invalidDocument(let name):
            return String(
                format: NSLocalizedString("scrivener.error.invalidDocument", comment: "Invalid Scrivener document"),
                name
            )
        case .invalidRichText(let name):
            return String(
                format: NSLocalizedString("scrivener.error.invalidRichText", comment: "Invalid Scrivener rich text"),
                name
            )
        case .projectLimit:
            return ImportError.projectLimit.localizedDescription
        case .fileLimit:
            return ImportError.fileLimit.localizedDescription
        case .accessCheckFailed:
            return ImportError.accessCheckFailed.localizedDescription
        }
    }
}

@MainActor
final class ScrivenerImportService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    static func readProject(from packageURL: URL) throws -> ScrivenerProjectDraft {
        guard packageURL.pathExtension.caseInsensitiveCompare("scriv") == .orderedSame,
              (try? packageURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
            throw ScrivenerImportError.invalidProject
        }

        let projectFileURL = try findProjectFile(in: packageURL)
        let xmlData = try Data(contentsOf: projectFileURL)
        let parserDelegate = ScrivenerXMLParserDelegate()
        let parser = XMLParser(data: xmlData)
        parser.delegate = parserDelegate
        parser.shouldResolveExternalEntities = false

        guard parser.parse() else {
            throw ScrivenerImportError.invalidBinder(
                parser.parserError?.localizedDescription ?? ScrivenerImportError.invalidProject.localizedDescription
            )
        }

        guard !parserDelegate.items.isEmpty else {
            throw ScrivenerImportError.invalidBinder(
                NSLocalizedString("scrivener.error.emptyBinder", comment: "Empty Scrivener binder")
            )
        }

        let usesLegacyDocuments = !FileManager.default.fileExists(
            atPath: packageURL.appendingPathComponent("Files/Data").path
        ) && FileManager.default.fileExists(atPath: packageURL.appendingPathComponent("Files/Docs").path)
        let roots = try parserDelegate.items.map {
            try makeItem(
                from: $0, packageURL: packageURL, usesLegacyDocuments: usesLegacyDocuments,
                parentIncludedInCompile: true, warnings: &parserDelegate.warnings
            )
        }

        var manuscriptItems: [ScrivenerBinderItem] = []
        var researchItems: [ScrivenerBinderItem] = []
        var trashItems: [ScrivenerBinderItem] = []

        for root in roots {
            let sourceType = root.sourceType.lowercased()
            if ["research", "researchfolder"].contains(sourceType)
                || root.title.localizedCaseInsensitiveCompare("Research") == .orderedSame {
                researchItems.append(root)
            } else if ["trash", "trashfolder"].contains(sourceType)
                || root.title.localizedCaseInsensitiveCompare("Trash") == .orderedSame {
                trashItems.append(root)
            } else if ["draft", "draftfolder"].contains(sourceType)
                || root.title.localizedCaseInsensitiveCompare("Draft") == .orderedSame {
                manuscriptItems.append(contentsOf: root.children)
            } else {
                manuscriptItems.append(root)
            }
        }

        let name = packageURL.deletingPathExtension().lastPathComponent
        return ScrivenerProjectDraft(
            projectName: name,
            binderItems: manuscriptItems,
            researchItems: researchItems,
            trashItems: trashItems,
            warnings: parserDelegate.warnings
        )
    }

    func importProject(
        _ draft: ScrivenerProjectDraft,
        options: ScrivenerImportOptions
    ) throws -> Project {
        let roots = draft.binderItems
            + (options.includeResearch ? draft.researchItems : [])
            + (options.includeTrash ? draft.trashItems : [])
        let fileCount = roots.reduce(0) { $0 + $1.documentCount }
        try validateImportAccess(projectType: options.projectType, importedFileCount: fileCount)

        let projectName = try uniqueProjectName(draft.projectName)
        DeduplicationService.clearTombstone(name: projectName, typeRaw: options.projectType.rawValue)

        let project = Project(
            name: projectName,
            type: options.projectType,
            creationDate: Date(),
            userOrder: ProjectSortService.nextUserOrder(in: modelContext)
        )
        if options.projectType == .fiction {
            project.fictionClass = options.fictionClass
        } else if options.projectType == .drama {
            project.dramaScriptTypeRaw = options.dramaScriptType.rawValue
        }

        modelContext.insert(project)

        do {
            ProjectTemplateService.createDefaultFolders(for: project, in: modelContext, requestSave: false)
            let binderFolder = Folder(
                name: FolderCapabilityService.scrivenerBinderFolderName,
                project: project,
                userOrder: project.folders?.count ?? 0
            )
            modelContext.insert(binderFolder)
            var importedRootDocumentsContainer: ScrivenerSemanticContainer?
            var didCreateRootDocumentsContainer = false
            var nextDocumentOrder = 0
            for (rootOrder, root) in roots.enumerated() {
                let isSupplemental = draft.researchItems.contains(where: { $0.id == root.id })
                    || draft.trashItems.contains(where: { $0.id == root.id })
                let group: ScrivenerSemanticContainer?
                if isSupplemental {
                    group = nil
                } else if root.kind == .folder {
                    group = makeContainer(named: root.title, for: project, userOrder: rootOrder, options: options)
                } else {
                    if !didCreateRootDocumentsContainer {
                        importedRootDocumentsContainer = makeContainer(
                            named: "Imported Documents",
                            for: project,
                            userOrder: rootOrder,
                            options: options
                        )
                        didCreateRootDocumentsContainer = true
                    }
                    group = importedRootDocumentsContainer
                }

                if root.kind == .folder {
                    importFolder(
                        root,
                        project: project,
                        parentFolder: binderFolder,
                        semanticContainer: group,
                        binderPath: [root.title],
                        forceExclude: isSupplemental,
                        includeInProjectStructure: !isSupplemental,
                        userOrder: rootOrder,
                        nextDocumentOrder: &nextDocumentOrder,
                        options: options
                    )
                } else {
                    importDocument(
                        root,
                        in: binderFolder,
                        semanticContainer: group,
                        binderPath: [root.title],
                        forceExclude: isSupplemental,
                        includeInProjectStructure: !isSupplemental,
                        userOrder: nextDocumentOrder,
                        options: options
                    )
                    nextDocumentOrder += 1
                }
            }

            try EnsemblesSaveGate.save(modelContext, reason: "json-import-scrivener-final")
            return project
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func importFolder(
        _ item: ScrivenerBinderItem,
        project: Project,
        parentFolder: Folder?,
        semanticContainer: ScrivenerSemanticContainer?,
        binderPath: [String],
        forceExclude: Bool,
        includeInProjectStructure: Bool,
        userOrder: Int,
        nextDocumentOrder: inout Int,
        options: ScrivenerImportOptions
    ) {
        let folder = Folder(
            name: item.title,
            project: parentFolder == nil ? project : nil,
            parentFolder: parentFolder,
            userOrder: userOrder
        )
        modelContext.insert(folder)

        for (childOrder, child) in item.children.enumerated() {
            if child.kind == .folder {
                importFolder(
                    child,
                    project: project,
                    parentFolder: folder,
                    semanticContainer: semanticContainer,
                    binderPath: binderPath + [child.title],
                    forceExclude: forceExclude,
                    includeInProjectStructure: includeInProjectStructure,
                    userOrder: childOrder,
                    nextDocumentOrder: &nextDocumentOrder,
                    options: options
                )
            } else {
                importDocument(
                    child,
                    in: folder,
                    semanticContainer: semanticContainer,
                    binderPath: binderPath,
                    forceExclude: forceExclude,
                    includeInProjectStructure: includeInProjectStructure,
                    userOrder: nextDocumentOrder,
                    options: options
                )
                nextDocumentOrder += 1
            }
        }
    }

    private func importDocument(
        _ item: ScrivenerBinderItem,
        in folder: Folder,
        semanticContainer: ScrivenerSemanticContainer?,
        binderPath: [String],
        forceExclude: Bool,
        includeInProjectStructure: Bool,
        userOrder: Int,
        options: ScrivenerImportOptions
    ) {
        let file = TextFile(name: item.title, initialContent: item.content, parentFolder: folder)
        file.includedInManuscript = !forceExclude && item.includedInCompile
        file.userOrder = userOrder
        file.modifiedDate = Date()
        modelContext.insert(file)

        if let formattedContent = item.formattedContent,
           let version = file.currentVersion {
            let attributedContent = AttributedStringSerializer.decode(formattedContent, text: item.content)
            _ = ImageAttachment.normalizeFileIDs(in: attributedContent, to: file.id)
            version.setFormattedContentData(
                AttributedStringSerializer.encode(attributedContent),
                sourceText: item.content
            )
            modelContext.insert(version)
        }

        guard includeInProjectStructure else { return }
        switch options.projectType {
        case .prose:
            if let semanticContainer, case .prose(let section) = semanticContainer {
                file.addToSection(section)
            }
        case .poetry:
            if let semanticContainer, case .poetry(let collection) = semanticContainer {
                file.addToPoetryCollection(collection)
                file.userOrder = userOrder
            }
        case .fiction:
            let sceneName = item.title
            let synopsis = binderPath.count > 1
                ? "Scrivener binder path: \((binderPath + [item.title]).joined(separator: " / "))"
                : nil
            let scene = StoryScene(name: sceneName, synopsis: synopsis, userOrder: userOrder)
            scene.isInBodyMatter = file.includedInManuscript
            scene.bodyMatterOrder = file.includedInManuscript ? userOrder : nil
            scene.project = file.project
            scene.textFile = file
            file.scene = scene
            modelContext.insert(scene)

            if let semanticContainer {
                switch semanticContainer {
                case .chapter(let chapter):
                    scene.addToChapter(chapter)
                case .book(let book):
                    scene.addToBook(book)
                default:
                    break
                }
            }
        case .drama:
            let synopsis = binderPath.count > 1
                ? "Scrivener binder path: \((binderPath + [item.title]).joined(separator: " / "))"
                : nil
            let scene = StoryScene(name: item.title, synopsis: synopsis, userOrder: userOrder)
            scene.isInBodyMatter = file.includedInManuscript
            scene.bodyMatterOrder = file.includedInManuscript ? userOrder : nil
            scene.project = file.project
            scene.textFile = file
            file.scene = scene
            modelContext.insert(scene)
            if let semanticContainer, case .act(let act) = semanticContainer {
                scene.addToAct(act)
            }
        }
    }

    private func makeContainer(
        named name: String,
        for project: Project,
        userOrder: Int,
        options: ScrivenerImportOptions
    ) -> ScrivenerSemanticContainer? {
        switch options.projectType {
        case .prose:
            let section = ProseSection(name: name, userOrder: userOrder)
            section.project = project
            section.isInBodyMatter = true
            section.bodyMatterOrder = userOrder
            modelContext.insert(section)
            return .prose(section)
        case .poetry:
            let collection = PoetryCollection(name: name, userOrder: userOrder)
            collection.project = project
            collection.isInBodyMatter = true
            collection.bodyMatterOrder = userOrder
            modelContext.insert(collection)
            return .poetry(collection)
        case .fiction:
            switch options.fictionClass {
            case .novel:
                let chapter = Chapter(name: name, userOrder: userOrder)
                chapter.project = project
                chapter.isInBodyMatter = true
                chapter.bodyMatterOrder = userOrder
                modelContext.insert(chapter)
                return .chapter(chapter)
            case .verseNovel:
                let book = Book(name: name, userOrder: userOrder)
                book.project = project
                book.isInBodyMatter = true
                book.bodyMatterOrder = userOrder
                modelContext.insert(book)
                return .book(book)
            case .shortFiction:
                return nil
            }
        case .drama:
            let act = Act(name: name, userOrder: userOrder)
            act.project = project
            act.isInBodyMatter = true
            act.bodyMatterOrder = userOrder
            modelContext.insert(act)
            return .act(act)
        }
    }

    private func validateImportAccess(projectType: ProjectType, importedFileCount: Int) throws {
        let projects: [Project]
        do {
            projects = try modelContext.fetch(FetchDescriptor<Project>())
        } catch {
            throw ScrivenerImportError.accessCheckFailed
        }

        let existingProjectCount = ProjectGateCounterService.activeProjectCount(
            ofType: projectType,
            in: projects
        )
        switch EntitlementManager.shared.projectImportAccess(
            projectType: projectType,
            existingProjectCount: existingProjectCount,
            importedFileCount: importedFileCount
        ) {
        case .allowed:
            return
        case .projectLimit:
            throw ScrivenerImportError.projectLimit
        case .fileLimit:
            throw ScrivenerImportError.fileLimit
        }
    }

    private func uniqueProjectName(_ name: String) throws -> String {
        let existingNames: Set<String>
        do {
            existingNames = Set(
                try modelContext.fetch(FetchDescriptor<Project>())
                    .compactMap(\.name)
            )
        } catch {
            throw ScrivenerImportError.accessCheckFailed
        }

        guard existingNames.contains(name) else {
            return name
        }

        var suffix = 2
        while existingNames.contains("\(name) \(suffix)") {
            suffix += 1
        }
        return "\(name) \(suffix)"
    }

    private static func findProjectFile(in packageURL: URL) throws -> URL {
        let entries = try FileManager.default.contentsOfDirectory(
            at: packageURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        let preferredName = packageURL.deletingPathExtension().lastPathComponent + ".scrivx"
        if let preferred = entries.first(where: { $0.lastPathComponent == preferredName }) {
            return preferred
        }
        guard let projectFile = entries.first(where: { $0.pathExtension.lowercased() == "scrivx" }) else {
            if entries.contains(where: { $0.lastPathComponent.caseInsensitiveCompare("binder.scrivproj") == .orderedSame }) {
                throw ScrivenerImportError.unsupportedLegacyProject
            }
            throw ScrivenerImportError.invalidProject
        }
        return projectFile
    }

    private static func makeItem(
        from source: ScrivenerMutableBinderItem,
        packageURL: URL,
        usesLegacyDocuments: Bool,
        parentIncludedInCompile: Bool,
        warnings: inout [String]
    ) throws -> ScrivenerBinderItem {
        let title = source.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? NSLocalizedString("scrivener.untitled", comment: "Untitled imported item")
            : source.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let includedInCompile = parentIncludedInCompile && source.includedInCompile
        let normalizedType = source.type.lowercased()
        let isFolder = [
            "draft", "draftfolder", "folder", "research", "researchfolder", "trash", "trashfolder"
        ].contains(normalizedType)

        if isFolder || !source.children.isEmpty {
            let children = try source.children.map {
                try makeItem(
                    from: $0,
                    packageURL: packageURL,
                    usesLegacyDocuments: usesLegacyDocuments,
                    parentIncludedInCompile: includedInCompile,
                    warnings: &warnings
                )
            }
            var preservedChildren = children
            if normalizedType == "text" {
                let documentSource = ScrivenerMutableBinderItem(attributes: [
                    "UUID": source.uuid ?? "", "ID": source.documentID ?? "", "Type": "Text", "Title": title
                ])
                documentSource.includedInCompile = source.includedInCompile
                let document = try makeItem(
                    from: documentSource, packageURL: packageURL, usesLegacyDocuments: usesLegacyDocuments,
                    parentIncludedInCompile: parentIncludedInCompile, warnings: &warnings
                )
                preservedChildren.insert(document, at: 0)
            }
            return ScrivenerBinderItem(
                id: UUID(),
                title: title,
                sourceType: source.type,
                kind: .folder,
                children: preservedChildren,
                content: "",
                formattedContent: nil,
                includedInCompile: includedInCompile
            )
        }

        guard normalizedType == "text" else {
            warnings.append(
                String(
                    format: NSLocalizedString("scrivener.warning.unsupportedItem", comment: "Unsupported Scrivener binder item"),
                    title
                )
            )
            return ScrivenerBinderItem(
                id: UUID(),
                title: title,
                sourceType: source.type,
                kind: .folder,
                children: [],
                content: "",
                formattedContent: nil,
                includedInCompile: false
            )
        }

        let rtfURL: URL
        let textURL: URL
        if usesLegacyDocuments {
            guard let documentID = source.documentID, !documentID.isEmpty,
                  documentID.utf8.allSatisfy({ (48...57).contains($0) }) else {
                throw ScrivenerImportError.invalidDocument(title)
            }
            let directory = packageURL.appendingPathComponent("Files/Docs", isDirectory: true)
            rtfURL = directory.appendingPathComponent("\(documentID).rtf")
            textURL = directory.appendingPathComponent("\(documentID).txt")
        } else {
            guard let uuidString = source.uuid, UUID(uuidString: uuidString) != nil else {
                throw ScrivenerImportError.invalidDocument(title)
            }
            let directory = packageURL.appendingPathComponent("Files/Data", isDirectory: true)
                .appendingPathComponent(uuidString, isDirectory: true)
            rtfURL = directory.appendingPathComponent("content.rtf")
            textURL = directory.appendingPathComponent("content.txt")
        }

        var content = ""
        var formattedContent: Data?
        if FileManager.default.fileExists(atPath: rtfURL.path) {
            let data = try Data(contentsOf: rtfURL)
            guard let attributedContent = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ) else {
                throw ScrivenerImportError.invalidRichText(title)
            }
            content = attributedContent.string
            var hasUnsupportedAttachment = false
            attributedContent.enumerateAttribute(
                .attachment,
                in: NSRange(location: 0, length: attributedContent.length)
            ) { value, _, _ in
                if value != nil && !(value is ImageAttachment) {
                    hasUnsupportedAttachment = true
                }
            }
            if hasUnsupportedAttachment {
                warnings.append(
                    String(
                        format: NSLocalizedString(
                            "scrivener.warning.unsupportedAttachment",
                            comment: "Unsupported embedded attachment"
                        ),
                        title
                    )
                )
            }
            formattedContent = AttributedStringSerializer.encode(attributedContent)
        } else if FileManager.default.fileExists(atPath: textURL.path) {
            let data = try Data(contentsOf: textURL)
            guard let text = String(data: data, encoding: .utf8) else {
                throw ScrivenerImportError.invalidDocument(title)
            }
            content = text
        } else {
            warnings.append(
                String(
                    format: NSLocalizedString(
                        "scrivener.warning.missingContent",
                        comment: "Scrivener document content file is missing"
                    ),
                    title
                )
            )
        }

        return ScrivenerBinderItem(
            id: UUID(),
            title: title,
            sourceType: source.type,
            kind: .document,
            children: [],
            content: content,
            formattedContent: formattedContent,
            includedInCompile: includedInCompile
        )
    }
}

private enum ScrivenerSemanticContainer {
    case prose(ProseSection)
    case poetry(PoetryCollection)
    case chapter(Chapter)
    case book(Book)
    case act(Act)
}

private final class ScrivenerMutableBinderItem {
    let uuid: String?
    let documentID: String?
    let type: String
    var title: String
    var includedInCompile = true
    var children: [ScrivenerMutableBinderItem] = []

    init(attributes: [String: String]) {
        uuid = attributes.first(where: { $0.key.caseInsensitiveCompare("UUID") == .orderedSame })?.value
        documentID = attributes.first(where: { $0.key.caseInsensitiveCompare("ID") == .orderedSame })?.value
        type = attributes.first(where: { $0.key.caseInsensitiveCompare("Type") == .orderedSame })?.value ?? ""
        title = attributes.first(where: { $0.key.caseInsensitiveCompare("Title") == .orderedSame })?.value ?? ""
    }
}

private final class ScrivenerXMLParserDelegate: NSObject, XMLParserDelegate {
    private enum CapturedElement: Equatable {
        case title
        case includeInCompile
    }

    private var binderStack: [ScrivenerMutableBinderItem] = []
    private var capture: CapturedElement?
    private var capturedText = ""
    private(set) var items: [ScrivenerMutableBinderItem] = []
    var warnings: [String] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        if elementName == "BinderItem" {
            let item = ScrivenerMutableBinderItem(attributes: attributeDict)
            if let parent = binderStack.last {
                parent.children.append(item)
            } else {
                items.append(item)
            }
            binderStack.append(item)
        } else if !binderStack.isEmpty && (elementName == "Title" || elementName == "IncludeInCompile") {
            capture = elementName == "Title" ? .title : .includeInCompile
            capturedText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard capture != nil else { return }
        capturedText.append(string)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if let capture {
            if (capture == .title && elementName == "Title")
                || (capture == .includeInCompile && elementName == "IncludeInCompile") {
                if let item = binderStack.last {
                    switch capture {
                    case .title:
                        item.title = capturedText
                    case .includeInCompile:
                        let normalized = capturedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        item.includedInCompile = !["no", "false", "0"].contains(normalized)
                    }
                }
                self.capture = nil
                capturedText = ""
            }
        }

        if elementName == "BinderItem", !binderStack.isEmpty {
            binderStack.removeLast()
        }
    }
}
