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
            if project.fictionClass == .novel {
                return "Chapters"
            } else {
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
    private func getPoetryBodySections(for project: Project) -> [ManuscriptSection] {
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
    private func getFictionBodySections(for project: Project) -> [ManuscriptSection] {
        var sections: [ManuscriptSection] = []
        
        if project.fictionClass == .novel {
            // Novel: Chapters containing Scenes
            guard project.folders?.contains(where: { $0.name == "Chapters" }) == true else {
                // Fallback to Scenes folder
                return getScenesAsSingleSection(for: project)
            }
            
            // Get chapters from the project's chapter entities
            let sortedChapters = (project.chapters ?? []).sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
            
            for chapter in sortedChapters {
                let chapterScenes = (chapter.scenes ?? [])
                    .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
                
                // Get TextFiles for each scene
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
        } else {
            // Short Fiction: Just scenes
            sections = getScenesAsSingleSection(for: project)
        }
        
        return sections
    }
    
    /// Get scenes as a single body section (for short fiction or fallback)
    private func getScenesAsSingleSection(for project: Project) -> [ManuscriptSection] {
        // Get scenes from project entities
        let sortedScenes = (project.scenes ?? []).sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
        
        var files: [TextFile] = []
        for scene in sortedScenes {
            if let textFile = scene.textFile, textFile.includedInManuscript {
                files.append(textFile)
            }
        }
        
        guard !files.isEmpty else { return [] }
        
        return [ManuscriptSection(
            title: NSLocalizedString("folder.scenes", comment: "Scenes"),
            sectionType: .body,
            sourceFolder: project.folders?.first { $0.name == "Scenes" },
            files: files,
            level: 1
        )]
    }
    
    /// Get body sections for Drama projects
    private func getDramaBodySections(for project: Project) -> [ManuscriptSection] {
        var sections: [ManuscriptSection] = []
        
        // Get sorted acts for the project
        let sortedActs = (project.acts ?? []).sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
        
        if !sortedActs.isEmpty {
            // Drama with Acts: Group scenes by act
            for act in sortedActs {
                let actScenes = (act.scenes ?? [])
                    .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
                
                // Get TextFiles for each scene in this act
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
            
            // Also include any scenes not assigned to an act (standalone scenes)
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
        } else {
            // Drama without Acts: Just list all scenes
            let sortedScenes = (project.scenes ?? []).sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
            
            var files: [TextFile] = []
            for scene in sortedScenes {
                if let textFile = scene.textFile, textFile.includedInManuscript {
                    files.append(textFile)
                }
            }
            
            guard !files.isEmpty else { return [] }
            
            sections.append(ManuscriptSection(
                title: NSLocalizedString("folder.scenes", comment: "Scenes"),
                sectionType: .body,
                sourceFolder: project.folders?.first { $0.name == "Scenes" },
                files: files,
                level: 1
            ))
        }
        
        return sections
    }
    
    /// Get body sections for Prose projects
    private func getProseBodySections(for project: Project) -> [ManuscriptSection] {
        #if DEBUG
        print("[ManuscriptAssembly] getProseBodySections - using ProseSection ordering")
        #endif
        
        guard let proseFolder = project.folders?.first(where: { $0.name == "Prose" }) else {
            #if DEBUG
            print("[ManuscriptAssembly] ❌ No Prose folder found")
            #endif
            return []
        }
        
        // Get all prose sections sorted by userOrder
        let sortedSections = (project.sections ?? [])
            .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
        
        #if DEBUG
        print("[ManuscriptAssembly] Found \(sortedSections.count) prose sections")
        for section in sortedSections {
            print("  Section: \(section.name ?? "unnamed") (userOrder: \(section.userOrder ?? -1))")
        }
        #endif
        
        // Collect all files from Prose folder
        let allFiles = collectFilesRecursively(from: proseFolder)
        
        // Build ordered list: files sorted by section order, then by file order within section
        var orderedFiles: [TextFile] = []
        
        // First, add files grouped by their section in section order
        for proseSection in sortedSections {
            let sectionFiles = allFiles
                .filter { $0.section?.id == proseSection.id }
                .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
            orderedFiles.append(contentsOf: sectionFiles)
            
            #if DEBUG
            if !sectionFiles.isEmpty {
                print("[ManuscriptAssembly] Section '\(proseSection.name ?? "")': \(sectionFiles.count) files")
            }
            #endif
        }
        
        // Add any files without a section (shouldn't happen normally, but be safe)
        let unassignedFiles = allFiles
            .filter { $0.section == nil }
            .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
        orderedFiles.append(contentsOf: unassignedFiles)
        
        #if DEBUG
        print("[ManuscriptAssembly] Total ordered files: \(orderedFiles.count)")
        for (idx, file) in orderedFiles.prefix(10).enumerated() {
            print("  \(idx): \(file.name) (section: \(file.section?.name ?? "none"))")
        }
        #endif
        
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
    func assembleContent(for project: Project) async throws -> ManuscriptContent {
        let sections = getSections(for: project)
        
        // Check if there's any content
        let hasContent = sections.contains { !$0.files.isEmpty }
        guard hasContent else {
            throw AssemblyError.noFilesFound
        }
        
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
        for section in sections {
            for file in section.files {
                // Add section break between files (not before first)
                if !isFirstFile {
                    assembled.append(sectionBreak(for: settings))
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
                    assembled.append(content)
                }
            }
        }

        return ManuscriptContent(
            attributedString: assembled,
            sections: sections,
            fileOffsets: fileOffsets
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
            .sorted { ($0.displayOrder ?? 0) < ($1.displayOrder ?? 0) }
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
