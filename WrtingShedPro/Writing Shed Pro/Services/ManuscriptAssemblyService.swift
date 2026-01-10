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
        case .generalPurpose:
            return "Folders"
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
        case .generalPurpose:
            return getGeneralPurposeBodySections(for: project)
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
        // Drama uses scenes similar to short fiction
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
    
    /// Get body sections for General Purpose projects
    private func getGeneralPurposeBodySections(for project: Project) -> [ManuscriptSection] {
        guard let foldersFolder = project.folders?.first(where: { $0.name == "Folders" }) else {
            return []
        }
        
        let files = collectFilesRecursively(from: foldersFolder)
        guard !files.isEmpty else { return [] }
        
        return [ManuscriptSection(
            title: NSLocalizedString("folder.folders", comment: "Folders"),
            sectionType: .body,
            sourceFolder: foldersFolder,
            files: files,
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
                if let version = file.currentVersion, let content = version.attributedContent {
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
