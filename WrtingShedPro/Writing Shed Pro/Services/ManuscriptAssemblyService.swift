import Foundation
import SwiftData
import Observation
import UIKit

/// Service responsible for assembling manuscript content from source folders (Feature 029)
@Observable
@MainActor
final class ManuscriptAssemblyService {
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    // MARK: - Source Folder Mapping
    
    /// Returns the source folder name for body content based on project type
    /// - Parameter project: The project to get source folder for
    /// - Returns: The folder name containing body content (Poems, Scenes, Scripts, etc.)
    func getBodySourceFolderName(for project: Project) -> String {
        switch project.type {
        case .poetry:
            return "Poems"
        case .fiction:
            // For novels, content comes from Chapters/Scenes hierarchy
            // For short fiction, content comes from Scenes
            // For verse novels, content comes from Books/Episodes hierarchy
            switch project.fictionClass {
            case .novel:
                return "Chapters"
            case .verseNovel:
                return "Books"
            case .shortFiction, .none:
                return "Scenes"
            }
        case .drama:
            return "Scenes"
        case .prose:
            return "Prose"
        }
    }
    
    /// Returns the source folder for body content
    /// - Parameter project: The project to get source folder for
    /// - Returns: The folder containing body content, or nil if not found
    func getBodySourceFolder(for project: Project) -> Folder? {
        let sourceName = getBodySourceFolderName(for: project)
        return project.folders?.first { $0.name == sourceName }
    }
    
    // MARK: - Section Assembly
    
    /// Get all sections for manuscript assembly
    /// - Parameter project: The project to get sections for
    /// - Returns: Array of ManuscriptSection in assembly order
    func getSections(for project: Project) -> [ManuscriptSection] {
        var sections: [ManuscriptSection] = []
        
        #if DEBUG
        print("[ManuscriptAssembly] getSections for project '\(project.name ?? "?")' type=\(project.type)")
        print("[ManuscriptAssembly]   project.folders count=\(project.folders?.count ?? 0): \(project.folders?.map { $0.name ?? "?" } ?? [])")
        #endif
        
        // 1. Front Matter
        if let frontMatterFolder = getManuscriptSubfolder(project, named: "Front Matter") {
            let files = collectMatterFiles(from: frontMatterFolder, sectionType: .frontMatter)
            if !files.isEmpty {
                sections.append(ManuscriptSection(
                    title: NSLocalizedString("manuscript.section.frontMatter", comment: "Front Matter"),
                    sectionType: .frontMatter,
                    sourceFolder: frontMatterFolder,
                    files: files,
                    level: 1
                ))
            }
        }
        
        // 2. Body (from source folder based on project type)
        let bodySections = getBodySections(for: project)
        sections.append(contentsOf: bodySections)
        
        #if DEBUG
        print("[ManuscriptAssembly] Body sections: \(bodySections.count) sections, \(bodySections.flatMap { $0.files }.count) total files")
        for s in bodySections {
            print("[ManuscriptAssembly]   Section '\(s.title)': \(s.files.count) files")
        }
        #endif
        
        // 3. Back Matter
        if let backMatterFolder = getManuscriptSubfolder(project, named: "Back Matter") {
            let files = collectMatterFiles(from: backMatterFolder, sectionType: .backMatter)
            if !files.isEmpty {
                sections.append(ManuscriptSection(
                    title: NSLocalizedString("manuscript.section.backMatter", comment: "Back Matter"),
                    sectionType: .backMatter,
                    sourceFolder: backMatterFolder,
                    files: files,
                    level: 1
                ))
            }
        }
        
        return sections
    }
    
    /// Get all body matter TextFile objects for a project, in manuscript order.
    /// Useful for submission workflows where files need to be linked.
    func getBodyMatterFiles(for project: Project) -> [TextFile] {
        return getBodySections(for: project).flatMap { $0.files }
    }
    
    /// Get body sections based on project type
    func getBodySections(for project: Project) -> [ManuscriptSection] {
        switch project.type {
        case .poetry:
            return getPoetryBodySections(for: project)
        case .fiction:
            return getFictionBodySections(for: project)
        case .drama:
            return getDramaBodySections(for: project)
        case .prose:
            return getProseBodySections(for: project)
        }
    }

    private func shouldUseExplicitBodyMatter(for project: Project) -> Bool {
        project.manuscriptSettings.useExplicitBodyMatter
    }
    
    /// Get body sections for Poetry projects
    /// Uses Body Matter collections if any exist, otherwise falls back to Poems folder
    private func getPoetryBodySections(for project: Project) -> [ManuscriptSection] {
        let useExplicitBodyMatter = shouldUseExplicitBodyMatter(for: project)
        // Body Matter path: use PoetryCollection items marked for body matter
        let bodyCollections = (project.poetryCollections ?? [])
            .filter { $0.isInBodyMatter }
            .sorted { ($0.bodyMatterOrder ?? 0) < ($1.bodyMatterOrder ?? 0) }
        
        #if DEBUG
        print("[ManuscriptAssembly] Poetry body sections: \(bodyCollections.count) body-matter collections, \(project.poetryCollections?.count ?? 0) total collections")
        for c in bodyCollections {
            let linkCount = c.textFileLinks?.count ?? 0
            let fileCount = liveCollectionFiles(for: c).count
            print("[ManuscriptAssembly]   Collection '\(c.name ?? "?")' isInBodyMatter=\(c.isInBodyMatter) textFileLinks=\(linkCount) textFiles=\(fileCount)")
        }
        #endif
        
        if !bodyCollections.isEmpty {
            let sections = collectionsToSections(bodyCollections)
            if !sections.isEmpty {
                return sections
            }
            if useExplicitBodyMatter {
                return []
            }
            #if DEBUG
            print("[ManuscriptAssembly] ⚠️ Body-matter collections exist but produced no sections (empty textFiles), falling through")
            #endif
        }

        if useExplicitBodyMatter {
            return []
        }
        
        // Fallback: all collections by userOrder (when none are explicitly marked for body matter,
        // or when body-matter collections had no files)
        let allCollections = (project.poetryCollections ?? [])
            .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
        if !allCollections.isEmpty {
            let sections = collectionsToSections(allCollections)
            if !sections.isEmpty {
                return sections
            }
            #if DEBUG
            print("[ManuscriptAssembly] ⚠️ All collections produced no sections, falling through to Poems folder")
            #endif
        }
        
        // Legacy fallback: all poems from Poems folder (pre-collection projects)
        // The Poems folder may be a top-level project folder OR a subfolder of Manuscript
        let poemsFolder: Folder? = project.folders?.first(where: { $0.name == "Poems" })
            ?? getManuscriptSubfolder(project, named: "Poems")
        
        guard let poemsFolder else {
            #if DEBUG
            print("[ManuscriptAssembly] ❌ No Poems folder found for poetry body sections")
            #endif
            return []
        }
        
        let files = collectFilesFromFolder(poemsFolder)
        #if DEBUG
        print("[ManuscriptAssembly] Poems folder fallback: \(files.count) files")
        #endif
        guard !files.isEmpty else { return [] }
        
        return [ManuscriptSection(
            title: NSLocalizedString("folder.poems", comment: "Poems"),
            sectionType: .body,
            sourceFolder: poemsFolder,
            files: files,
            level: 1
        )]
    }
    
    /// Convert poetry collections to manuscript sections
    private func collectionsToSections(_ collections: [PoetryCollection]) -> [ManuscriptSection] {
        var sections: [ManuscriptSection] = []
        for collection in collections {
            let files = liveCollectionFiles(for: collection)
                .filter { $0.includedInManuscript }
                .sorted {
                    let order0 = $0.userOrder ?? Int.max
                    let order1 = $1.userOrder ?? Int.max
                    if order0 != order1 { return order0 < order1 }
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
            if !files.isEmpty {
                sections.append(ManuscriptSection(
                    title: collection.name ?? NSLocalizedString("poetry.collection.untitled", comment: "Untitled"),
                    sectionType: .body,
                    sourceFolder: nil,
                    files: files,
                    level: 1
                ))
            }
        }
        return sections
    }

    private func liveCollectionFiles(for collection: PoetryCollection) -> [TextFile] {
        let files = (collection.textFiles ?? []).filter { $0.trashItem == nil }

        return files.sorted {
            let order0 = $0.userOrder ?? Int.max
            let order1 = $1.userOrder ?? Int.max
            if order0 != order1 { return order0 < order1 }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
    
    /// Get body sections for Fiction projects
    /// Uses Body Matter items if any exist, otherwise falls back to folder-based logic
    private func getFictionBodySections(for project: Project) -> [ManuscriptSection] {
        if project.fictionClass == .novel {
            return getNovelBodySections(for: project)
        } else if project.fictionClass == .verseNovel {
            return getVerseNovelBodySections(for: project)
        } else {
            return getShortFictionBodySections(for: project)
        }
    }
    
    /// Novel: Chapters with scenes
    private func getNovelBodySections(for project: Project) -> [ManuscriptSection] {
        let useExplicitBodyMatter = shouldUseExplicitBodyMatter(for: project)
        // Body Matter path: chapters marked for body matter
        let bodyChapters = (project.chapters ?? [])
            .filter { $0.isInBodyMatter }
            .sorted { ($0.bodyMatterOrder ?? 0) < ($1.bodyMatterOrder ?? 0) }
        
        if !bodyChapters.isEmpty {
            return chaptersToSections(bodyChapters)
        }

        if useExplicitBodyMatter {
            return []
        }
        
        // Fallback: all chapters by userOrder
        let allChapters = (project.chapters ?? []).sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
        if !allChapters.isEmpty {
            return chaptersToSections(allChapters)
        }
        
        return getScenesAsSingleSection(for: project)
    }
    
    /// Verse Novel: Books with scenes (episodes)
    private func getVerseNovelBodySections(for project: Project) -> [ManuscriptSection] {
        let useExplicitBodyMatter = shouldUseExplicitBodyMatter(for: project)
        // Body Matter path: books marked for body matter
        let bodyBooks = (project.books ?? [])
            .filter { $0.isInBodyMatter }
            .sorted { ($0.bodyMatterOrder ?? 0) < ($1.bodyMatterOrder ?? 0) }
        
        if !bodyBooks.isEmpty {
            return booksToSections(bodyBooks)
        }

        if useExplicitBodyMatter {
            return []
        }
        
        // Fallback: all books/chapters by userOrder
        let allBooks = (project.books ?? []).sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
        if !allBooks.isEmpty {
            return booksToSections(allBooks)
        }
        
        // Legacy fallback: chapters (before Book model existed)
        let allChapters = (project.chapters ?? []).sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
        if !allChapters.isEmpty {
            return chaptersToSections(allChapters)
        }
        
        return getScenesAsSingleSection(for: project)
    }
    
    /// Short Fiction: Scenes (optionally grouped by stories)
    private func getShortFictionBodySections(for project: Project) -> [ManuscriptSection] {
        let useExplicitBodyMatter = shouldUseExplicitBodyMatter(for: project)
        // Body Matter path: scenes marked for body matter
        let bodyScenes = (project.scenes ?? [])
            .filter { $0.isInBodyMatter }
            .sorted { ($0.bodyMatterOrder ?? 0) < ($1.bodyMatterOrder ?? 0) }
        
        if !bodyScenes.isEmpty {
            return scenesToSection(bodyScenes, title: NSLocalizedString("folder.stories", comment: "Stories"))
        }

        if useExplicitBodyMatter {
            return []
        }
        
        // Fallback: all scenes
        return getScenesAsSingleSection(for: project)
    }
    
    /// Convert chapters to manuscript sections
    private func chaptersToSections(_ chapters: [Chapter]) -> [ManuscriptSection] {
        var sections: [ManuscriptSection] = []
        for chapter in chapters {
            let chapterScenes = (chapter.scenes ?? [])
                .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
            
            var files: [TextFile] = []
            for scene in chapterScenes {
                if let textFile = scene.textFile, textFile.includedInManuscript {
                    files.append(textFile)
                }
            }
            
            if !files.isEmpty {
                sections.append(ManuscriptSection(
                    title: chapter.name ?? NSLocalizedString("fiction.chapter", comment: "Chapter"),
                    sectionType: .body,
                    sourceFolder: nil,
                    files: files,
                    level: 1
                ))
            }
        }
        return sections
    }
    
    /// Convert books to manuscript sections
    private func booksToSections(_ books: [Book]) -> [ManuscriptSection] {
        var sections: [ManuscriptSection] = []
        for book in books {
            let bookScenes = (book.scenes ?? [])
                .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
            
            var files: [TextFile] = []
            for scene in bookScenes {
                if let textFile = scene.textFile, textFile.includedInManuscript {
                    files.append(textFile)
                }
            }
            
            if !files.isEmpty {
                sections.append(ManuscriptSection(
                    title: book.name ?? NSLocalizedString("fiction.book", comment: "Book"),
                    sectionType: .body,
                    sourceFolder: nil,
                    files: files,
                    level: 1
                ))
            }
        }
        return sections
    }
    
    /// Convert scenes to a single manuscript section
    private func scenesToSection(_ scenes: [StoryScene], title: String) -> [ManuscriptSection] {
        var files: [TextFile] = []
        for scene in scenes {
            if let textFile = scene.textFile, textFile.includedInManuscript {
                files.append(textFile)
            }
        }
        guard !files.isEmpty else { return [] }
        return [ManuscriptSection(
            title: title,
            sectionType: .body,
            sourceFolder: nil,
            files: files,
            level: 1
        )]
    }
    
    /// Get scenes as a single body section (for short fiction or fallback)
    private func getScenesAsSingleSection(for project: Project) -> [ManuscriptSection] {
        let sortedScenes = (project.scenes ?? []).sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
        return scenesToSection(sortedScenes, title: NSLocalizedString("folder.scenes", comment: "Scenes"))
    }
    
    /// Get body sections for Drama projects
    /// Uses Body Matter acts if any exist, otherwise falls back to all acts/scenes
    private func getDramaBodySections(for project: Project) -> [ManuscriptSection] {
        let useExplicitBodyMatter = shouldUseExplicitBodyMatter(for: project)
        // Body Matter path: acts marked for body matter
        let bodyActs = (project.acts ?? [])
            .filter { $0.isInBodyMatter }
            .sorted { ($0.bodyMatterOrder ?? 0) < ($1.bodyMatterOrder ?? 0) }
        
        if !bodyActs.isEmpty {
            var sections: [ManuscriptSection] = []
            for act in bodyActs {
                let actScenes = (act.scenes ?? [])
                    .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
                
                var files: [TextFile] = []
                for scene in actScenes {
                    if let textFile = scene.textFile, textFile.includedInManuscript {
                        files.append(textFile)
                    }
                }
                
                if !files.isEmpty {
                    sections.append(ManuscriptSection(
                        title: act.name ?? NSLocalizedString("drama.act", comment: "Act"),
                        sectionType: .body,
                        sourceFolder: nil,
                        files: files,
                        level: 1
                    ))
                }
            }
            return sections
        }

        if useExplicitBodyMatter {
            return []
        }
        
        // Fallback: all acts by userOrder
        let sortedActs = (project.acts ?? []).sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
        
        if !sortedActs.isEmpty {
            var sections: [ManuscriptSection] = []
            for act in sortedActs {
                let actScenes = (act.scenes ?? [])
                    .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
                
                var files: [TextFile] = []
                for scene in actScenes {
                    if let textFile = scene.textFile, textFile.includedInManuscript {
                        files.append(textFile)
                    }
                }
                
                if !files.isEmpty {
                    sections.append(ManuscriptSection(
                        title: act.name ?? NSLocalizedString("drama.act", comment: "Act"),
                        sectionType: .body,
                        sourceFolder: nil,
                        files: files,
                        level: 1
                    ))
                }
            }
            
            // Also include standalone scenes not assigned to any act
            let standaloneScenes = (project.scenes ?? [])
                .filter { $0.act == nil }
                .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
            
            var standaloneFiles: [TextFile] = []
            for scene in standaloneScenes {
                if let textFile = scene.textFile, textFile.includedInManuscript {
                    standaloneFiles.append(textFile)
                }
            }
            
            if !standaloneFiles.isEmpty {
                sections.append(ManuscriptSection(
                    title: NSLocalizedString("folder.scenes", comment: "Scenes"),
                    sectionType: .body,
                    sourceFolder: project.folders?.first { $0.name == "Scenes" },
                    files: standaloneFiles,
                    level: 1
                ))
            }
            
            return sections
        }
        
        // No acts at all: list all scenes
        let sortedScenes = (project.scenes ?? []).sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
        return scenesToSection(sortedScenes, title: NSLocalizedString("folder.scenes", comment: "Scenes"))
    }
    
    /// Get body sections for Prose projects
    /// Uses Body Matter sections if any exist, otherwise falls back to folder-based logic
    private func getProseBodySections(for project: Project) -> [ManuscriptSection] {
        let useExplicitBodyMatter = shouldUseExplicitBodyMatter(for: project)
        #if DEBUG
        print("[ManuscriptAssembly] getProseBodySections")
        #endif
        
        // Body Matter path: sections marked for body matter
        let allSections: [ProseSection] = project.sections ?? []
        let bodySections: [ProseSection] = allSections
            .filter { (section: ProseSection) -> Bool in section.isInBodyMatter }
            .sorted { (a: ProseSection, b: ProseSection) -> Bool in (a.bodyMatterOrder ?? 0) < (b.bodyMatterOrder ?? 0) }
        
        if !bodySections.isEmpty {
            #if DEBUG
            print("[ManuscriptAssembly] Using \(bodySections.count) Body Matter sections")
            #endif
            
            var sections: [ManuscriptSection] = []
            for proseSection in bodySections {
                let files: [TextFile] = (proseSection.textFiles ?? [])
                    .filter { (file: TextFile) -> Bool in file.includedInManuscript }
                    .sorted { (a: TextFile, b: TextFile) -> Bool in (a.userOrder ?? 0) < (b.userOrder ?? 0) }
                
                if !files.isEmpty {
                    sections.append(ManuscriptSection(
                        title: proseSection.name ?? NSLocalizedString("prose.section", comment: "Section"),
                        sectionType: .body,
                        sourceFolder: nil,
                        files: files,
                        level: 1
                    ))
                }
            }
            return sections
        }

        if useExplicitBodyMatter {
            return []
        }
        
        // Fallback: folder-based assembly (pre-migration projects)
        guard let proseFolder = project.folders?.first(where: { $0.name == "Prose" }) else {
            #if DEBUG
            print("[ManuscriptAssembly] ❌ No Prose folder found")
            #endif
            return []
        }
        
        let sortedSections = (project.sections ?? [])
            .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
        
        #if DEBUG
        print("[ManuscriptAssembly] Fallback: \(sortedSections.count) prose sections by userOrder")
        #endif
        
        let allFiles = collectFilesRecursively(from: proseFolder)
        var orderedFiles: [TextFile] = []
        
        for proseSection in sortedSections {
            let sectionFiles = allFiles
                .filter { $0.section?.id == proseSection.id }
                .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
            orderedFiles.append(contentsOf: sectionFiles)
        }
        
        let unassignedFiles = allFiles
            .filter { $0.section == nil }
            .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
        orderedFiles.append(contentsOf: unassignedFiles)
        
        guard !orderedFiles.isEmpty else { return [] }
        
        return [ManuscriptSection(
            title: NSLocalizedString("folder.prose", comment: "Prose"),
            sectionType: .body,
            sourceFolder: proseFolder,
            files: orderedFiles,
            level: 1
        )]
    }
    
    // MARK: - DML Assembly (for Fountain/FDX Export)
    
    /// Assemble raw DML content from all drama scenes in manuscript order.
    /// This produces a single combined DML string suitable for conversion to
    /// Fountain or Final Draft format via the respective converters.
    /// - Parameter project: The drama project to assemble
    /// - Returns: Combined DML string with scene breaks
    /// - Throws: AssemblyError if assembly fails or project is not a drama project
    func assembleDML(for project: Project) async throws -> String {
        guard project.type == .drama else {
            throw AssemblyError.noFilesFound
        }
        
        let sections = getSections(for: project)
        let hasContent = sections.contains { !$0.files.isEmpty }
        guard hasContent else {
            throw AssemblyError.noFilesFound
        }
        
        var dmlParts: [String] = []
        
        for section in sections {
            for file in section.files {
                if file.isCoverFile { continue }
                
                if let version = file.currentVersion {
                    let dmlSource = version.content
                    if !dmlSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        dmlParts.append(dmlSource)
                    }
                }
            }
        }
        
        guard !dmlParts.isEmpty else {
            throw AssemblyError.noFilesFound
        }
        
        // Join scenes with double newlines (scene separator)
        return dmlParts.joined(separator: "\n\n")
    }
    
    // MARK: - Content Assembly
    
    /// Assemble complete manuscript content
    /// - Parameter project: The project to assemble
    /// - Returns: ManuscriptContent with assembled attributed string
    /// - Throws: AssemblyError if assembly fails
    func assembleContent(for project: Project, skipPrintOnlyContent: Bool = false, progress: ((Int, Int) -> Void)? = nil) async throws -> ManuscriptContent {
        let sections = getSections(for: project)
        
        // Check if there's any content
        let hasContent = sections.contains { !$0.files.isEmpty }
        guard hasContent else {
            throw AssemblyError.noFilesFound
        }
        
        // Count total non-cover files for progress reporting
        let totalFiles = sections.flatMap { $0.files }.filter { !$0.isCoverFile }.count
        var fileIndex = 0
        
        let settings = project.manuscriptSettings
        let assembled = NSMutableAttributedString()
        var fileOffsets: [UUID: Int] = [:]
        var isFirstFile = true
        
        // Determine if this is a drama project
        let isDrama = project.type == .drama
        // Get script type for drama (default to .stage if missing)
        let scriptType: DramaScriptType = {
            if let raw = project.dramaScriptTypeRaw, let t = DramaScriptType(rawValue: raw) { return t }
            return .stage
        }()
        print("[ManuscriptAssemblyService] Drama project: \(isDrama), Script type: \(scriptType)")
        
        // Track front matter metrics for roman numeral page numbering
        var frontMatterFileCount = 0
        var frontMatterCharacterLength = 0
        var frontMatterDone = false
        
        // Track which chunk (form-feed separated) indices should be vertically centered.
        // Epigraph and Dedication front matter pages are traditionally centered on the page.
        var verticallyCenteredChunkIndices = Set<Int>()
        var currentChunkIndex = 0
        
        // Collect footnotes from all files with positions remapped to the assembled string
        var assembledFootnotes: [ManuscriptFootnote] = []
        let includedFileIDs = sections.flatMap { $0.files }
            .filter { !$0.isCoverFile && !(skipPrintOnlyContent && ($0.isTOCFile || $0.isTableOfFiguresFile)) }
            .map(\.id)
        var processedFileCount = 0
        
        for section in sections {
            // Once we've passed front matter sections, mark it done
            if section.sectionType != .frontMatter && !frontMatterDone {
                frontMatterDone = true
                frontMatterCharacterLength = assembled.length
            }
            
            for file in section.files {
                // Skip cover files — they contain only an image, not text content
                if file.isCoverFile { continue }

                if section.sectionType == .backMatter,
                         project.type != .drama,
                   let backMatterFolder = section.sourceFolder {
                    let item = file.isTableOfFiguresFile
                        ? BackMatterItem.tableOfFigures
                        : Self.generatedBackMatterType(for: file)
                    if let item, !backMatterFolder.backMatterSettings.isEnabled(item) {
                        continue
                    }
                }
                
                // Skip print-only content for EPUB export (TOC with dot leaders,
                // Table of Figures with page numbers, etc.)
                if skipPrintOnlyContent {
                    if file.isTOCFile { continue }
                    if file.isTableOfFiguresFile { continue }
                }

                if shouldSkipEmptyMatterFile(file, in: section) { continue }

                let preparedGeneratedContent: NSAttributedString?
                if file.isTableOfFiguresFile && !skipPrintOnlyContent {
                    print("[ManuscriptAssemblyService] Generating Table of Figures for file: \(file.name)")
                    let tofService = TableOfFiguresGenerationService(context: context)
                    var entries = tofService.generateEntries(for: project, tofFile: file)
                    if !entries.isEmpty {
                        entries = await tofService.calculatePageNumbers(for: entries, project: project, tofFile: file)
                    }
                    let settings = file.tableOfFiguresSettings
                    let visibleEntries = settings.showMissingCaption ? entries : entries.filter { $0.hasCaption }
                    guard !visibleEntries.isEmpty else { continue }
                    let missingCaptionEntries = entries.filter { !$0.hasCaption }
                    let renderedTOF = tofService.renderTableOfFigures(
                        entries: entries,
                        settings: settings,
                        project: project,
                        missingCaptionCount: missingCaptionEntries.count,
                        missingCaptionPages: missingCaptionEntries.map { $0.pageNumber }
                    )
                    preparedGeneratedContent = TableOfFiguresGenerationService.formatTOFContentForExport(renderedTOF, project: project)
                } else if let generatedType = Self.generatedBackMatterType(for: file) {
                    let generator = BackMatterGenerator(
                        context: context,
                        project: project,
                        sourceFolder: section.sourceFolder
                    )
                    let generated: NSAttributedString?
                    switch generatedType {
                    case .endnotes:
                        generated = generator.generateNotesSection()
                    case .glossary:
                        generated = generator.generateGlossarySection()
                    case .references:
                        generated = generator.generateReferencesSection()
                    case .index:
                        let indexPageMap = Self.calculateIndexPageNumbers(
                            from: assembled,
                            pageSetup: project.pageSetup ?? PageSetup()
                        )
                        generated = generator.generateIndexSection(pageMap: indexPageMap)
                    case .contributors:
                        generated = generator.generateContributorsSection()
                    default:
                        generated = nil
                    }
                    guard let generated, !Self.isEffectivelyEmpty(generated.string) else {
                        print("[ManuscriptAssemblyService] No content for back matter: \(file.name) (\(generatedType.rawValue))")
                        continue
                    }
                    preparedGeneratedContent = generated
                } else {
                    preparedGeneratedContent = nil
                }

                let fileStartOffset = assembled.length
                processedFileCount += 1
                
                if section.sectionType == .frontMatter {
                    frontMatterFileCount += 1
                }
                
                fileIndex += 1
                progress?(fileIndex, totalFiles)
                
                // Yield periodically so the UI can process progress updates
                if fileIndex % 10 == 0 {
                    await Task.yield()
                }
                
                // Add section break between files (not before first)
                if !isFirstFile {
                    // Ensure the previous file's content ends with a newline so that paragraphs
                    // are properly delimited. Without this, the last line of one file merges with
                    // the first line of the next file into a single paragraph, corrupting style
                    // attributes (e.g. numbered heading indents get skipped).
                    if !assembled.string.hasSuffix("\n") && assembled.length > 0 {
                        assembled.append(NSAttributedString(string: "\n"))
                    }
                    let breakAttr = sectionBreak(for: settings)
                    // Avoid double form feeds if content already ends with one
                    if breakAttr.string == "\u{000C}" && assembled.string.hasSuffix("\u{000C}") {
                        // Skip — content already has a page break
                    } else {
                        assembled.append(breakAttr)
                    }
                    currentChunkIndex += 1
                }
                isFirstFile = false
                
                // Mark epigraph and dedication front matter pages for vertical centering
                if section.sectionType == .frontMatter {
                    let fileName = file.name.trimmingCharacters(in: .whitespaces)
                    if fileName == FrontMatterItem.epigraph.fileName ||
                       fileName == FrontMatterItem.dedication.fileName {
                        verticallyCenteredChunkIndices.insert(currentChunkIndex)
                    }
                }
                // Record offset before adding
                fileOffsets[file.id] = assembled.length
                if let heading = frontMatterHeading(for: file, in: section, project: project) {
                    assembled.append(heading)
                }
                // Add file content
                if isDrama, let version = file.currentVersion {
                    print("[ManuscriptAssemblyService] Rendering drama file: \(file.name)")
                    let dmlSource = version.content
                    print("[ManuscriptAssemblyService] DML source:\n\(dmlSource)")
                    let document = DramaMarkupParser.shared.parse(dmlSource)
                    let rendered = DramaMarkupRenderer.shared.render(
                        document,
                        scriptType: scriptType,
                        viewMode: .formatted,
                        showNotes: false
                    )
                    print("[ManuscriptAssemblyService] Rendered attributed string: \(rendered.string)")
                    assembled.append(rendered)
                } else if file.isTableOfFiguresFile && !skipPrintOnlyContent {
                    if let content = preparedGeneratedContent {
                        assembled.append(content)
                    }
                } else if let generatedType = Self.generatedBackMatterType(for: file) {
                    if let content = preparedGeneratedContent {
                        print("[ManuscriptAssemblyService] Generated back matter for: \(file.name) (\(generatedType.rawValue))")
                        assembled.append(content)
                    }
                } else if let version = file.currentVersion, let content = version.attributedContent {
                    print("[ManuscriptAssemblyService] Appending attributedContent for file: \(file.name)")
                    let contentOffset = assembled.length
                    // For TOC files, reformat with right-aligned page numbers and dot leaders for PDF
                    if file.isTOCFile {
                        let exportContent = TOCGenerationService.formatTOCContentForExport(
                            content,
                            settings: file.tocSettings,
                            project: project,
                            context: context
                        )
                        assembled.append(exportContent)
                    } else {
                        assembled.append(content)
                    }
                    
                    // Collect footnotes from this file's version.
                    // FootnoteAttachment objects embedded in the attributed content carry the
                    // footnoteID and number. We look up the text from the FootnoteModel records.
                    let footnotes = FootnoteManager.shared.getActiveFootnotes(forVersion: version, context: context)
                    // Build a map from attachmentID → FootnoteModel for fast lookup
                    // Use reduce to safely handle duplicate attachmentIDs (keeps last)
                    let footnoteMap = footnotes.reduce(into: [UUID: FootnoteModel]()) { dict, fn in
                        dict[fn.attachmentID] = fn
                    }
                    
                    // Scan the newly appended range for FootnoteAttachment objects
                    let appendedRange = NSRange(location: contentOffset, length: assembled.length - contentOffset)
                    assembled.enumerateAttribute(.attachment, in: appendedRange, options: []) { value, range, _ in
                        if let fnAttach = value as? FootnoteAttachment {
                            if let fnModel = footnoteMap[fnAttach.footnoteID] {
                                assembledFootnotes.append(ManuscriptFootnote(
                                    attachmentID: fnAttach.footnoteID,
                                    text: fnModel.text,
                                    number: fnAttach.number,
                                    characterPosition: range.location
                                ))
                            } else if let fnModel = fetchFootnoteByAttachment(attachmentID: fnAttach.footnoteID) {
                                // CloudKit may sync FootnoteModel before its Version relationship.
                                // Fallback to attachment-ID lookup so preview footnotes still render.
                                assembledFootnotes.append(ManuscriptFootnote(
                                    attachmentID: fnAttach.footnoteID,
                                    text: fnModel.text,
                                    number: fnAttach.number,
                                    characterPosition: range.location
                                ))
                            }
                        }
                    }
                } else if let plain = file.currentVersion?.content {
                    assembled.append(NSAttributedString(string: plain))
                }

                // Guarantee each file ends with one blank line (two newlines).
                // This preserves paragraph boundaries so the next file's first-line
                // style (e.g. Title2) is rendered from its own paragraph attributes.
                if assembled.length > fileStartOffset && processedFileCount < includedFileIDs.count {
                    ensureTrailingBlankLine(on: assembled)
                }
            }
        }

        // If all sections were front matter (no body/back matter), set the length now
        if !frontMatterDone {
            frontMatterCharacterLength = assembled.length
        }

        // Register the project stylesheet for all manuscript file IDs so that
        // image captions can resolve their style during PDF rendering (TextKit 1 path).
        // Without this, image(forBounds:) falls back to centered caption with no numbering.
        if let styleSheet = project.styleSheet {
            for section in sections {
                for file in section.files {
                    StyleSheetProvider.shared.register(styleSheet: styleSheet, for: file.id)
                }
            }
        }
        
        // Update caption numbers for all images in document order (Feature 016).
        // During editing, numbers are maintained by the editor views (PaginatedDocumentView,
        // FormattedTextEditor). During export assembly, we must assign them so that
        // PDF rendering includes the correct figure numbers in captions.
        ImageAttachment.updateCaptionNumbersInAttributedString(assembled, styleSheet: project.styleSheet)

        var result = ManuscriptContent(
            attributedString: assembled,
            sections: sections,
            fileOffsets: fileOffsets,
            frontMatterFileCount: frontMatterFileCount,
            frontMatterCharacterLength: frontMatterCharacterLength,
            assembledFootnotes: assembledFootnotes,
            verticallyCenteredChunkIndices: verticallyCenteredChunkIndices
        )
        result.buildFileCollectionMap()
        return result
    }
    
    /// Assemble complete manuscript content with back matter (Feature 029)
    /// - Parameters:
    ///   - project: The project to assemble
    ///   - options: Export options including back matter settings
    /// - Returns: ManuscriptContent with assembled attributed string including back matter
    /// - Throws: AssemblyError if assembly fails
    func assembleContentWithBackMatter(for project: Project, options: ExportOptions) async throws -> ManuscriptContent {
        // First assemble the main content
        var content = try await assembleContent(for: project)
        
        // Generate back matter if any options are enabled
        let needsBackMatter = options.includeNotes || options.includeGlossary || 
                              options.includeBibliography || options.includeIndex
        
        guard needsBackMatter else {
            return content
        }
        
        // Create back matter generator
        let backMatterGenerator = BackMatterGenerator(
            context: context,
            project: project,
            sourceFolder: getManuscriptSubfolder(project, named: "Back Matter")
        )
        
        // Note: For index, we need page numbers calculated after pagination
        // This method provides the structure; actual page numbers are resolved in PrintService
        let backMatter = backMatterGenerator.generateBackMatter(
            includeNotes: options.includeNotes,
            includeGlossary: options.includeGlossary,
            includeBibliography: options.includeBibliography,
            includeIndex: options.includeIndex,
            pageMap: [:] // Page numbers will be calculated during PDF generation
        )
        
        // Append back matter to content
        if backMatter.length > 0 {
            let mutableContent = NSMutableAttributedString(attributedString: content.attributedString)
            
            // Add page break before back matter
            let pageBreak = NSAttributedString(string: "\u{0C}") // Form feed
            mutableContent.append(pageBreak)
            mutableContent.append(backMatter)
            
            // Create updated content with back matter
            content = ManuscriptContent(
                attributedString: mutableContent,
                sections: content.sections,
                pageMap: content.pageMap,
                fileOffsets: content.fileOffsets,
                pageCount: content.pageCount,
                fileCollectionMap: content.fileCollectionMap
            )
        }
        
        return content
    }
    
    // MARK: - Helper Methods
    
    /// Get a subfolder of the Manuscript folder by name
    private func getManuscriptSubfolder(_ project: Project, named name: String) -> Folder? {
        guard let manuscriptFolder = project.folders?.first(where: { $0.name == "Manuscript" }) else {
            return nil
        }
        return manuscriptFolder.subfolders?.first { $0.name == name }
    }
    
    /// Collect files from a folder (non-recursive), respecting includedInManuscript flag
    private func collectFilesFromFolder(_ folder: Folder) -> [TextFile] {
        let folderID = folder.id
        let descriptor = FetchDescriptor<TextFile>(
            predicate: #Predicate<TextFile> { file in
                file.parentFolder?.id == folderID
            }
        )
        let fetchedFiles = (try? context.fetch(descriptor)) ?? []
        let relationshipFiles = folder.files ?? []
        var filesByID = relationshipFiles.reduce(into: [UUID: TextFile]()) { result, file in
            result[file.id] = file
        }
        for file in fetchedFiles {
            filesByID[file.id] = file
        }

        return filesByID.values
            .filter { $0.includedInManuscript }
            .sorted {
                let order0 = $0.userOrder ?? Int.max
                let order1 = $1.userOrder ?? Int.max
                if order0 != order1 {
                    return order0 < order1
                }
                // Secondary sort by name for deterministic order when userOrder is equal
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private func collectMatterFiles(from folder: Folder, sectionType: ManuscriptSection.SectionType) -> [TextFile] {
        Self.canonicalMatterFiles(collectFilesFromFolder(folder), in: folder)
            .filter { file in
                switch sectionType {
                case .frontMatter:
                    if folder.isDramaProject {
                        guard let item = DramaFrontMatterItem(rawValue: file.name) else { return true }
                        return folder.dramaFrontMatterSettings.isEnabled(item)
                    }
                    guard let item = FrontMatterItem(rawValue: file.name) else { return true }
                    return folder.frontMatterSettings.isEnabled(item)
                case .backMatter:
                    if folder.isDramaProject {
                        guard let item = DramaBackMatterItem(rawValue: file.name) else { return true }
                        return folder.dramaBackMatterSettings.isEnabled(item)
                    }
                    guard let item = BackMatterItem(rawValue: file.name) else { return true }
                    return folder.backMatterSettings.isEnabled(item)
                default:
                    return true
                }
            }
    }

    /// Collapse distinct records representing the same built-in matter item without deleting data.
    /// Cloud sync can temporarily produce duplicate records with different UUIDs.
    static func canonicalMatterFiles(_ files: [TextFile], in folder: Folder) -> [TextFile] {
        guard folder.isFrontMatterFolder || folder.isBackMatterFolder else { return files }

        var result: [TextFile] = []
        var canonicalIndexByName: [String: Int] = [:]

        for file in files {
            guard isBuiltInMatterFile(file, in: folder) else {
                result.append(file)
                continue
            }

            if let existingIndex = canonicalIndexByName[file.name] {
                result[existingIndex] = preferredMatterFile(result[existingIndex], file)
            } else {
                canonicalIndexByName[file.name] = result.count
                result.append(file)
            }
        }

        return result
    }

    private static func isBuiltInMatterFile(_ file: TextFile, in folder: Folder) -> Bool {
        if folder.isFrontMatterFolder {
            return folder.isDramaProject
                ? DramaFrontMatterItem(rawValue: file.name) != nil
                : FrontMatterItem(rawValue: file.name) != nil
        }

        return folder.isDramaProject
            ? DramaBackMatterItem(rawValue: file.name) != nil
            : BackMatterItem(rawValue: file.name) != nil
    }

    private static func preferredMatterFile(_ lhs: TextFile, _ rhs: TextFile) -> TextFile {
        let lhsContentLength = lhs.currentVersion?.attributedContent?.length
            ?? lhs.currentVersion?.content.count
            ?? 0
        let rhsContentLength = rhs.currentVersion?.attributedContent?.length
            ?? rhs.currentVersion?.content.count
            ?? 0
        if lhsContentLength != rhsContentLength {
            return lhsContentLength > rhsContentLength ? lhs : rhs
        }

        let lhsVersionCount = lhs.versions?.count ?? 0
        let rhsVersionCount = rhs.versions?.count ?? 0
        if lhsVersionCount != rhsVersionCount {
            return lhsVersionCount > rhsVersionCount ? lhs : rhs
        }

        return lhs.id.uuidString < rhs.id.uuidString ? lhs : rhs
    }

    private func shouldSkipEmptyMatterFile(_ file: TextFile, in section: ManuscriptSection) -> Bool {
        guard section.sectionType == .frontMatter || section.sectionType == .backMatter else { return false }
        guard !file.isTOCFile,
              !file.isTableOfFiguresFile,
              Self.generatedBackMatterType(for: file) == nil else { return false }

        if let attributedContent = file.currentVersion?.attributedContent {
            return Self.isEffectivelyEmpty(attributedContent)
        }

        return Self.isEffectivelyEmpty(file.currentVersion?.content ?? "")
    }

    private func frontMatterHeading(
        for file: TextFile,
        in section: ManuscriptSection,
        project: Project
    ) -> NSAttributedString? {
        guard section.sectionType == .frontMatter,
              project.type != .drama,
              let folder = section.sourceFolder,
              let item = FrontMatterItem(rawValue: file.name),
              item.allowsManuscriptTitleConfiguration else { return nil }

        let settings = folder.frontMatterSettings
        guard settings.titleConfig(for: item).showTitle else { return nil }

        var attributes: [NSAttributedString.Key: Any]
        if let style = StyleSheetService.resolveStyle(
            named: project.matterHeadingStyleName,
            for: project,
            context: context
        ) ?? StyleSheetService.resolveStyle(.title1, for: project, context: context) {
            attributes = style.generateAttributes()
        } else {
            attributes = [
                .font: UIFont.preferredFont(forTextStyle: .title1),
                .foregroundColor: UIColor.label
            ]
        }

        if let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle {
            let mutableStyle = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
            mutableStyle.paragraphSpacing = max(mutableStyle.paragraphSpacing, 12)
            attributes[.paragraphStyle] = mutableStyle
        } else {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing = 12
            attributes[.paragraphStyle] = paragraphStyle
        }

        return NSAttributedString(
            string: settings.displayTitle(for: item) + "\n",
            attributes: attributes
        )
    }

    private static func isEffectivelyEmpty(_ content: NSAttributedString) -> Bool {
        guard isEffectivelyEmpty(content.string) else { return false }

        var hasVisibleAttachment = false
        content.enumerateAttribute(.attachment, in: NSRange(location: 0, length: content.length), options: []) { value, _, stop in
            if value is ImageAttachment {
                hasVisibleAttachment = true
                stop.pointee = true
            }
        }
        return !hasVisibleAttachment
    }

    private static func isEffectivelyEmpty(_ text: String) -> Bool {
        text
            .replacingOccurrences(of: "\u{FFFC}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }
    
    /// Collect files recursively from a folder and its subfolders
    private func collectFilesRecursively(from folder: Folder) -> [TextFile] {
        var files = collectFilesFromFolder(folder)
        
        let sortedSubfolders = (folder.subfolders ?? [])
            .sorted { ($0.displayOrder ?? 0) < ($1.displayOrder ?? 0) }
        
        for subfolder in sortedSubfolders {
            files.append(contentsOf: collectFilesRecursively(from: subfolder))
        }
        
        return files
    }

    /// Fallback lookup for footnotes when the Version relationship has not synced yet.
    /// Attachment IDs are generated per marker and are stable across sync.
    private func fetchFootnoteByAttachment(attachmentID: UUID) -> FootnoteModel? {
        let descriptor = FetchDescriptor<FootnoteModel>(
            predicate: #Predicate { footnote in
                footnote.attachmentID == attachmentID
            }
        )
        return try? context.fetch(descriptor).first
    }
    
    /// Generate section break based on settings
    private func sectionBreak(for settings: ManuscriptSettings) -> NSAttributedString {
        switch settings.sectionBreakStyle {
        case .pageBreak:
            // Form feed character for page break
            return NSAttributedString(string: "\u{0C}")
        case .sectionMark:
            return NSAttributedString(string: "\n\n* * *\n\n")
        case .doubleSpace:
            return NSAttributedString(string: "\n\n\n\n")
        case .none:
            return NSAttributedString(string: "")
        }
    }

    /// Ensure content ends with exactly one blank line boundary between files.
    private func ensureTrailingBlankLine(on text: NSMutableAttributedString) {
        guard text.length > 0 else { return }
        if text.string.hasSuffix("\n\n") {
            return
        }
        if text.string.hasSuffix("\n") {
            text.append(NSAttributedString(string: "\n"))
        } else {
            text.append(NSAttributedString(string: "\n\n"))
        }
    }
    
    // MARK: - Generated Back Matter Detection
    
    /// Determine if a back matter file is a generated type (Endnotes, Glossary, etc.)
    /// that should be regenerated fresh at export time rather than using stored attributedContent.
    /// Returns the BackMatterItem type, or nil if this is a regular user-authored file.
    static func generatedBackMatterType(for file: TextFile) -> BackMatterItem? {
        // Only applies to files in the Back Matter folder
        guard let folder = file.parentFolder, folder.isBackMatterFolder else {
            return nil
        }
        // Cover files are handled separately
        if file.isCoverFile { return nil }
        // TOF files are handled by the isTableOfFiguresFile check
        if file.isTableOfFiguresFile { return nil }
        
        let fileName = file.name.lowercased()
        let generatedTypes: [BackMatterItem] = [.endnotes, .glossary, .references, .index, .contributors]
        for item in generatedTypes {
            if fileName.contains(item.rawValue.lowercased()) {
                return item
            }
        }
        return nil
    }
    
    // MARK: - Index Page Number Calculation
    
    /// Calculate page numbers for index entries by paginating the assembled content so far
    /// and scanning for ReferenceAttachment markers with referenceType == .index.
    /// This mirrors the logic in BackMatterGeneratedContentView.calculateIndexPageNumbers().
    static func calculateIndexPageNumbers(
        from assembledContent: NSAttributedString,
        pageSetup: PageSetup
    ) -> [UUID: [IndexPageReference]] {
        guard assembledContent.length > 0 else { return [:] }
        
        // Paginate the assembled content
        let textStorage = NSTextStorage(attributedString: assembledContent)
        let layoutManager = PaginatedTextLayoutManager(textStorage: textStorage, pageSetup: pageSetup)
        let layoutResult = layoutManager.calculateLayout()
        
        #if DEBUG
        print("[ManuscriptAssemblyService] Index page calc: \(assembledContent.length) chars -> \(layoutResult.totalPages) pages")
        #endif
        
        // Scan for index reference markers
        var result: [UUID: [IndexPageReference]] = [:]
        let fullRange = NSRange(location: 0, length: assembledContent.length)
        
        assembledContent.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
            guard let refAttachment = value as? ReferenceAttachment,
                  refAttachment.referenceType == .index else {
                return
            }
            
            let globalPosition = range.location
            
            // Find which page this position falls on
            var pageNumber = 1
            for pageInfo in layoutResult.pageInfos {
                if globalPosition >= pageInfo.characterRange.location &&
                   globalPosition < pageInfo.characterRange.location + pageInfo.characterRange.length {
                    pageNumber = pageInfo.pageIndex + 1
                    break
                }
            }
            // If past the last page range, use last page
            if let lastPage = layoutResult.pageInfos.last,
               globalPosition >= lastPage.characterRange.location + lastPage.characterRange.length {
                pageNumber = lastPage.pageIndex + 1
            }
            
            let ref = IndexPageReference(
                pageNumber: pageNumber,
                isPrimary: refAttachment.isPrimaryReference
            )
            
            if result[refAttachment.entryID] == nil {
                result[refAttachment.entryID] = []
            }
            // Avoid duplicate page numbers
            if !result[refAttachment.entryID]!.contains(ref) {
                result[refAttachment.entryID]!.append(ref)
            }
        }
        
        #if DEBUG
        print("[ManuscriptAssemblyService] Index page map: \(result.count) entries with page numbers")
        #endif
        
        return result
    }
}

// MARK: - Folder Extension for Manuscript

extension Folder {
    /// Returns subfolders of this folder
    var subfolders: [Folder]? {
        return folders
    }
    
    /// Returns files in this folder
    var files: [TextFile]? {
        return textFiles
    }
    
    /// Display order for sorting
    var displayOrder: Int16? {
        return Int16(userOrder ?? 0)
    }
}

// MARK: - TextFile Extension for Manuscript

extension TextFile {
    /// Display order for sorting
    var displayOrder: Int16? {
        return Int16(userOrder ?? 0)
    }
}
