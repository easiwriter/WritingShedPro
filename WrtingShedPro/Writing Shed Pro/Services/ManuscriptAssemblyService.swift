import Foundation
import SwiftData
import Observation

/// Service responsible for assembling manuscript content from source folders (Feature 029)
@Observable
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
        
        // 1. Front Matter
        if let frontMatterFolder = getManuscriptSubfolder(project, named: "Front Matter") {
            let files = collectFilesFromFolder(frontMatterFolder)
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
        
        // 3. Back Matter
        if let backMatterFolder = getManuscriptSubfolder(project, named: "Back Matter") {
            let files = collectFilesFromFolder(backMatterFolder)
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
    
    /// Get body sections for Poetry projects
    /// Uses Body Matter collections if any exist, otherwise falls back to Poems folder
    private func getPoetryBodySections(for project: Project) -> [ManuscriptSection] {
        // Body Matter path: use PoetryCollection items marked for body matter
        let bodyCollections = (project.poetryCollections ?? [])
            .filter { $0.isInBodyMatter }
            .sorted { ($0.bodyMatterOrder ?? 0) < ($1.bodyMatterOrder ?? 0) }
        
        if !bodyCollections.isEmpty {
            var sections: [ManuscriptSection] = []
            for collection in bodyCollections {
                let files = (collection.textFiles ?? [])
                    .filter { $0.includedInManuscript }
                    .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
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
        
        // Fallback: all poems from Poems folder (pre-migration projects)
        guard let poemsFolder = project.folders?.first(where: { $0.name == "Poems" }) else {
            return []
        }
        
        let files = collectFilesFromFolder(poemsFolder)
        guard !files.isEmpty else { return [] }
        
        return [ManuscriptSection(
            title: NSLocalizedString("folder.poems", comment: "Poems"),
            sectionType: .body,
            sourceFolder: poemsFolder,
            files: files,
            level: 1
        )]
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
        // Body Matter path: chapters marked for body matter
        let bodyChapters = (project.chapters ?? [])
            .filter { $0.isInBodyMatter }
            .sorted { ($0.bodyMatterOrder ?? 0) < ($1.bodyMatterOrder ?? 0) }
        
        if !bodyChapters.isEmpty {
            return chaptersToSections(bodyChapters)
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
        // Body Matter path: books marked for body matter
        let bodyBooks = (project.books ?? [])
            .filter { $0.isInBodyMatter }
            .sorted { ($0.bodyMatterOrder ?? 0) < ($1.bodyMatterOrder ?? 0) }
        
        if !bodyBooks.isEmpty {
            return booksToSections(bodyBooks)
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
        // Body Matter path: scenes marked for body matter
        let bodyScenes = (project.scenes ?? [])
            .filter { $0.isInBodyMatter }
            .sorted { ($0.bodyMatterOrder ?? 0) < ($1.bodyMatterOrder ?? 0) }
        
        if !bodyScenes.isEmpty {
            return scenesToSection(bodyScenes, title: NSLocalizedString("folder.stories", comment: "Stories"))
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
        #if DEBUG
        print("[ManuscriptAssembly] getProseBodySections")
        #endif
        
        // Body Matter path: sections marked for body matter
        let bodySections = (project.sections ?? [])
            .filter { $0.isInBodyMatter }
            .sorted { ($0.bodyMatterOrder ?? 0) < ($1.bodyMatterOrder ?? 0) }
        
        if !bodySections.isEmpty {
            #if DEBUG
            print("[ManuscriptAssembly] Using \(bodySections.count) Body Matter sections")
            #endif
            
            var sections: [ManuscriptSection] = []
            for proseSection in bodySections {
                let files = (proseSection.textFiles ?? [])
                    .filter { $0.includedInManuscript }
                    .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
                
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
    
    // MARK: - Content Assembly
    
    /// Assemble complete manuscript content
    /// - Parameter project: The project to assemble
    /// - Returns: ManuscriptContent with assembled attributed string
    /// - Throws: AssemblyError if assembly fails
    func assembleContent(for project: Project, progress: ((Int, Int) -> Void)? = nil) async throws -> ManuscriptContent {
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
        
        // Collect footnotes from all files with positions remapped to the assembled string
        var assembledFootnotes: [ManuscriptFootnote] = []
        
        for section in sections {
            // Once we've passed front matter sections, mark it done
            if section.sectionType != .frontMatter && !frontMatterDone {
                frontMatterDone = true
                frontMatterCharacterLength = assembled.length
            }
            
            for file in section.files {
                // Skip cover files — they contain only an image, not text content
                if file.isCoverFile { continue }
                
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
                    let breakAttr = sectionBreak(for: settings)
                    // Avoid double form feeds if content already ends with one
                    if breakAttr.string == "\u{000C}" && assembled.string.hasSuffix("\u{000C}") {
                        // Skip — content already has a page break
                    } else {
                        assembled.append(breakAttr)
                    }
                }
                isFirstFile = false
                // Record offset before adding
                fileOffsets[file.id] = assembled.length
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
                } else if let version = file.currentVersion, let content = version.attributedContent {
                    print("[ManuscriptAssemblyService] Appending attributedContent for file: \(file.name)")
                    let contentOffset = assembled.length
                    // For TOC files, reformat with right-aligned page numbers and dot leaders for PDF
                    if file.isTOCFile {
                        let exportContent = TOCGenerationService.formatTOCContentForExport(content, project: project)
                        assembled.append(exportContent)
                    } else {
                        assembled.append(content)
                    }
                    
                    // Collect footnotes from this file's version.
                    // FootnoteAttachment objects embedded in the attributed content carry the
                    // footnoteID and number. We look up the text from the FootnoteModel records.
                    let footnotes = FootnoteManager.shared.getActiveFootnotes(forVersion: version, context: context)
                    if !footnotes.isEmpty {
                        // Build a map from attachmentID → FootnoteModel for fast lookup
                        let footnoteMap = Dictionary(uniqueKeysWithValues: footnotes.map { ($0.attachmentID, $0) })
                        
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
                                }
                            }
                        }
                    }
                }
            }
        }

        // If all sections were front matter (no body/back matter), set the length now
        if !frontMatterDone {
            frontMatterCharacterLength = assembled.length
        }

        return ManuscriptContent(
            attributedString: assembled,
            sections: sections,
            fileOffsets: fileOffsets,
            frontMatterFileCount: frontMatterFileCount,
            frontMatterCharacterLength: frontMatterCharacterLength,
            assembledFootnotes: assembledFootnotes
        )
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
        let backMatterGenerator = BackMatterGenerator(context: context, project: project)
        
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
                pageCount: content.pageCount
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
        return (folder.files ?? [])
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
