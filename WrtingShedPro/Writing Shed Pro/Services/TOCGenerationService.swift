//
//  TOCGenerationService.swift
//  Writing Shed Pro
//
//  Service for generating Table of Contents entries from manuscript headings
//  Feature 031: Table of Contents
//

import Foundation
import SwiftData
import UIKit

/// Represents a single entry in the Table of Contents
struct TOCEntry: Identifiable {
    let id = UUID()
    let headingText: String
    var pageNumber: Int  // Mutable - calculated during pagination
    let indentLevel: Int
    let sourceFile: TextFile
    let characterPosition: Int  // Position in source file for navigation
    let globalCharacterPosition: Int  // Position in assembled manuscript (for page calculation)
    /// Whether this entry's page number should be displayed as a lowercase roman numeral (front matter)
    var isRomanNumeral: Bool
    
    /// Create entry with just source file position (page number calculated later)
    init(headingText: String, indentLevel: Int, sourceFile: TextFile, characterPosition: Int, globalCharacterPosition: Int = 0, isRomanNumeral: Bool = false) {
        self.headingText = headingText
        self.pageNumber = 0
        self.indentLevel = indentLevel
        self.sourceFile = sourceFile
        self.characterPosition = characterPosition
        self.globalCharacterPosition = globalCharacterPosition
        self.isRomanNumeral = isRomanNumeral
    }
    
    /// The page number formatted for display (roman numeral for front matter, arabic for body)
    var formattedPageNumber: String {
        if isRomanNumeral {
            return Self.toRomanNumeral(pageNumber)
        }
        return "\(pageNumber)"
    }
    
    /// Convert an integer to a lowercase roman numeral string
    static func toRomanNumeral(_ number: Int) -> String {
        guard number > 0 else { return "" }
        let values = [(1000, "m"), (900, "cm"), (500, "d"), (400, "cd"),
                      (100, "c"), (90, "xc"), (50, "l"), (40, "xl"),
                      (10, "x"), (9, "ix"), (5, "v"), (4, "iv"), (1, "i")]
        var result = ""
        var remaining = number
        for (value, numeral) in values {
            while remaining >= value {
                result += numeral
                remaining -= value
            }
        }
        return result
    }
}

/// Service for generating Table of Contents from manuscript content
final class TOCGenerationService {
    private let context: ModelContext
    private let assemblyService: ManuscriptAssemblyService
    
    init(context: ModelContext) {
        self.context = context
        self.assemblyService = ManuscriptAssemblyService(context: context)
    }
    
    // MARK: - TOC Generation
    
    /// Generate TOC entries for a project
    /// - Parameters:
    ///   - project: The project to scan for headings
    ///   - tocFile: The TOC file itself (to exclude from scanning)
    /// - Returns: Array of TOC entries in manuscript order
    func generateEntries(for project: Project, tocFile: TextFile? = nil) -> [TOCEntry] {
        var entries: [TOCEntry] = []
        
        #if DEBUG
        print("[TOCGeneration] Starting entry generation for project: \(project.name ?? "unnamed")")
        #endif
        
        // Get styles that should appear in TOC
        let tocStyles = getTOCStyles(for: project)
        guard !tocStyles.isEmpty else {
            #if DEBUG
            print("[TOCGeneration] ❌ No styles configured for TOC")
            print("[TOCGeneration] Checking stylesheet...")
            if let sheet = project.styleSheet {
                print("[TOCGeneration]   StyleSheet: \(sheet.name)")
                if let styles = sheet.textStyles {
                    print("[TOCGeneration]   Total styles: \(styles.count)")
                    for style in styles {
                        print("[TOCGeneration]     - \(style.displayName): includeInTOC=\(style.includeInTOC), tocLevel=\(style.tocLevel)")
                    }
                } else {
                    print("[TOCGeneration]   ❌ No textStyles array")
                }
            } else {
                print("[TOCGeneration]   ❌ No stylesheet assigned to project")
            }
            #endif
            return []
        }
        
        #if DEBUG
        print("[TOCGeneration] Found \(tocStyles.count) styles configured for TOC:")
        for style in tocStyles {
            print("[TOCGeneration]   - \(style.displayName) (name: '\(style.name)', level \(style.tocLevel))")
        }
        #endif
        
        // Get all manuscript sections in order
        let sections = assemblyService.getSections(for: project)
        
        #if DEBUG
        print("[TOCGeneration] Found \(sections.count) manuscript sections")
        for section in sections {
            print("[TOCGeneration]   Section: \(section.title) with \(section.files.count) files")
        }
        
        // If no sections, check if there are any files in the project at all
        if sections.isEmpty {
            print("[TOCGeneration] ⚠️ No sections found - checking project structure...")
            if let folders = project.folders {
                print("[TOCGeneration]   Project has \(folders.count) top-level folders")
                for folder in folders {
                    print("[TOCGeneration]     - \(folder.name ?? "unnamed")")
                    if let files = folder.files {
                        print("[TOCGeneration]       Files: \(files.count)")
                    }
                }
            }
        }
        #endif
        
        // Process each file in order
        for section in sections {
            for file in section.files {
                // Skip the TOC file itself to avoid circular reference
                if let tocFile = tocFile, file.id == tocFile.id {
                    #if DEBUG
                    print("[TOCGeneration] Skipping TOC file: \(file.name)")
                    #endif
                    continue
                }
                
                #if DEBUG
                print("[TOCGeneration] Scanning file: \(file.name)")
                #endif
                
                // Find TOC entries in this file
                let fileEntries = findEntriesInFile(file, tocStyles: tocStyles)
                
                #if DEBUG
                print("[TOCGeneration]   Found \(fileEntries.count) entries in \(file.name)")
                #endif
                
                entries.append(contentsOf: fileEntries)
            }
        }
        
        // If no entries found via manuscript sections, try scanning all project files directly
        if entries.isEmpty {
            #if DEBUG
            print("[TOCGeneration] ⚠️ No entries from sections, trying direct file scan...")
            #endif
            let allFiles = getAllFilesInProject(project, excluding: tocFile)
            for file in allFiles {
                let fileEntries = findEntriesInFile(file, tocStyles: tocStyles)
                entries.append(contentsOf: fileEntries)
            }
            #if DEBUG
            print("[TOCGeneration] Direct scan found \(entries.count) entries from \(allFiles.count) files")
            #endif
        }
        
        #if DEBUG
        print("[TOCGeneration] Generated \(entries.count) TOC entries total")
        #endif
        
        return entries
    }
    
    // MARK: - Page Number Calculation
    
    /// Calculate page numbers for TOC entries by paginating the manuscript
    /// Approach: paginate body+back matter for raw page numbers, then calculate
    /// front matter page count (including TOC size) as an offset.
    func calculatePageNumbers(for entries: [TOCEntry], project: Project, tocFile: TextFile?) async -> [TOCEntry] {
        #if DEBUG
        print("[TOCGeneration] ========== PAGE NUMBER CALCULATION START ==========")
        #endif
        
        let pageSetup = project.pageSetup ?? PageSetup()
        let usePageBreaks = pageSetup.hasPageBreakBetweenFiles
        let sections = assemblyService.getSections(for: project)
        
        // === STEP 1: Paginate body + back matter to get raw page numbers ===
        let bodyBackSections: [ManuscriptSection] = sections.filter { (s: ManuscriptSection) -> Bool in s.sectionType != .frontMatter }
        var updatedEntries: [TOCEntry] = entries
        let frontMatterSections: [ManuscriptSection] = sections.filter { (s: ManuscriptSection) -> Bool in s.sectionType == .frontMatter }
        let frontMatterFileIds: Set<UUID> = Set(
            frontMatterSections.flatMap { (s: ManuscriptSection) -> [UUID] in s.files.map { (f: TextFile) -> UUID in f.id } }
        )
        var bodyTotalPages = 0
        
        if usePageBreaks {
            // Paginate each file individually — no form feeds needed for counting
            for section in bodyBackSections {
                for file in section.files {
                    guard let version = file.currentVersion, let content = version.attributedContent, content.length > 0 else {
                        continue
                    }
                    let prepared = prepareForPageCounting(content)
                    guard prepared.length > 0 else { continue }
                    let storage = NSTextStorage(attributedString: prepared)
                    let layout = PaginatedTextLayoutManager(textStorage: storage, pageSetup: pageSetup)
                    let result = layout.calculateLayout()
                    
                    // Map TOC entries that belong to this file
                    for i in 0..<updatedEntries.count {
                        guard updatedEntries[i].sourceFile.id == file.id,
                              !frontMatterFileIds.contains(file.id) else { continue }
                        let page = findPageForCharacterPosition(updatedEntries[i].characterPosition, in: result)
                        updatedEntries[i].pageNumber = bodyTotalPages + page
                    }
                    
                    bodyTotalPages += result.totalPages
                }
            }
        } else {
            // Files flow together — assemble with separators and paginate as a whole
            var bodyFileOffsets: [UUID: Int] = [:]
            let bodyContent = NSMutableAttributedString()
            var isFirst = true
            
            for section in bodyBackSections {
                for file in section.files {
                    if !isFirst {
                        bodyContent.append(NSAttributedString(string: "\n\n"))
                    }
                    isFirst = false
                    bodyFileOffsets[file.id] = bodyContent.length
                    if let version = file.currentVersion, let content = version.attributedContent {
                        bodyContent.append(content)
                    }
                }
            }
            
            let preparedBody = PrintFormatter.removePlatformScaling(from: bodyContent)
            let bodyStorage = NSTextStorage(attributedString: preparedBody)
            let bodyLayout = PaginatedTextLayoutManager(textStorage: bodyStorage, pageSetup: pageSetup)
            let bodyResult = bodyLayout.calculateLayout()
            bodyTotalPages = bodyResult.totalPages
            
            for i in 0..<updatedEntries.count {
                guard !frontMatterFileIds.contains(updatedEntries[i].sourceFile.id) else { continue }
                let fileOffset = bodyFileOffsets[updatedEntries[i].sourceFile.id] ?? 0
                let globalPos = fileOffset + updatedEntries[i].characterPosition
                updatedEntries[i].pageNumber = findPageForCharacterPosition(globalPos, in: bodyResult)
            }
        }
        
        #if DEBUG
        print("[TOCGeneration] Body pagination: \(bodyTotalPages) pages (perFile: \(usePageBreaks))")
        for entry in updatedEntries where !frontMatterFileIds.contains(entry.sourceFile.id) {
            print("[TOCGeneration]   '\(entry.headingText.prefix(30))': raw page \(entry.pageNumber)")
        }
        #endif
        
        // === STEP 2: Calculate front matter page numbers (roman numerals) ===
        // Front matter uses its own 1-based page numbering displayed as lowercase roman numerals.
        // Body + back matter keep their own 1-based arabic numbering from STEP 1.
        // No offset is applied — the two numbering schemes are independent.
        let frontMatterFiles = sections
            .filter { $0.sectionType == .frontMatter }
            .flatMap { $0.files }
            .filter { !$0.isCoverFile }  // Cover files don't contribute to page count
        
        // Render TOC with the raw body page numbers to estimate its size.
        // Use the export-formatted version (with dot leaders + tab stops) so the
        // page count matches what will actually appear in the PDF.
        var tocRendered: NSAttributedString? = nil
        if let tocFile = tocFile {
            let settings = tocFile.tocSettings
            let simpleTOC = renderTOC(entries: updatedEntries, settings: settings, project: project)
            tocRendered = TOCGenerationService.formatTOCContentForExport(simpleTOC, project: project)
        }
        
        var frontMatterPageCount = 0
        
        for file in frontMatterFiles {
            let fileContent: NSAttributedString
            if let toc = tocFile, file.id == toc.id, let rendered = tocRendered {
                // The export-formatted TOC still has Catalyst-sized fonts.
                // Don't descale here — prepareForPageCounting will handle it.
                fileContent = rendered
                #if DEBUG
                print("[TOCGeneration] FM file '\(file.name)': export-formatted TOC (\(rendered.length) chars)")
                #endif
            } else if let version = file.currentVersion, let content = version.attributedContent {
                fileContent = content
                #if DEBUG
                print("[TOCGeneration] FM file '\(file.name)': saved content (\(content.length) chars)")
                #endif
            } else {
                fileContent = NSAttributedString()
                #if DEBUG
                print("[TOCGeneration] FM file '\(file.name)': empty")
                #endif
            }
            
            if fileContent.length > 0 {
                let prepared = prepareForPageCounting(fileContent)
                guard prepared.length > 0 else {
                    frontMatterPageCount += 1  // Content was only form feeds
                    continue
                }
                let storage = NSTextStorage(attributedString: prepared)
                let layout = PaginatedTextLayoutManager(textStorage: storage, pageSetup: pageSetup)
                let result = layout.calculateLayout()
                
                // Map any front matter TOC entries in this file
                for i in 0..<updatedEntries.count where updatedEntries[i].sourceFile.id == file.id {
                    let page = findPageForCharacterPosition(updatedEntries[i].characterPosition, in: result)
                    updatedEntries[i].pageNumber = frontMatterPageCount + page
                    updatedEntries[i].isRomanNumeral = true
                }
                
                frontMatterPageCount += result.totalPages
            } else {
                // Empty front matter file still occupies 1 page
                frontMatterPageCount += 1
            }
        }
        
        #if DEBUG
        print("[TOCGeneration] Front matter: \(frontMatterFiles.count) files → \(frontMatterPageCount) pages (roman numerals)")
        print("[TOCGeneration] Body pages start at 1 (arabic), no offset applied")
        print("[TOCGeneration] Page setup: \(pageSetup.paperSize.rawValue), margins T:\(pageSetup.marginTop) B:\(pageSetup.marginBottom) L:\(pageSetup.marginLeft) R:\(pageSetup.marginRight)")
        for entry in updatedEntries {
            let fmt = entry.isRomanNumeral ? TOCEntry.toRomanNumeral(entry.pageNumber) : "\(entry.pageNumber)"
            print("[TOCGeneration]   '\(entry.headingText.prefix(30))': page \(fmt) (\(entry.isRomanNumeral ? "roman" : "arabic"))")
        }
        print("[TOCGeneration] ========== PAGE NUMBER CALCULATION END ==========")
        #endif
        
        return updatedEntries
    }
    
    /// Prepare content for accurate page counting:
    /// 1. Strip trailing form feed characters (artifacts from previous assembly/save)
    /// 2. Remove Catalyst font scaling so fonts match print/display sizes
    private func prepareForPageCounting(_ content: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: content)
        // Strip trailing form feed characters
        while mutable.length > 0 && mutable.string.hasSuffix("\u{000C}") {
            mutable.deleteCharacters(in: NSRange(location: mutable.length - 1, length: 1))
        }
        // Remove Catalyst font scaling (÷kCatalystFontScale) to get print-accurate sizes
        return PrintFormatter.removePlatformScaling(from: mutable)
    }
    
    /// Find which page a character position falls on
    private func findPageForCharacterPosition(_ position: Int, in layoutResult: PaginatedTextLayoutManager.LayoutResult) -> Int {
        for pageInfo in layoutResult.pageInfos {
            if position >= pageInfo.characterRange.location &&
               position < pageInfo.characterRange.location + pageInfo.characterRange.length {
                return pageInfo.pageIndex + 1  // 1-based page numbers
            }
        }
        // If not found, estimate based on position
        if let lastPage = layoutResult.pageInfos.last {
            return lastPage.pageIndex + 1
        }
        return 1
    }
    
    /// Get all files in project by traversing folder hierarchy
    private func getAllFilesInProject(_ project: Project, excluding tocFile: TextFile?) -> [TextFile] {
        var allFiles: [TextFile] = []
        
        guard let folders = project.folders else {
            #if DEBUG
            print("[TOCGeneration] Project has no folders")
            #endif
            return []
        }
        
        func collectFiles(from folder: Folder) {
            if let files = folder.files {
                for file in files {
                    // Skip the TOC file
                    if let tocFile = tocFile, file.id == tocFile.id {
                        continue
                    }
                    // Skip TOC files by name/flag
                    if file.isTOCFile || file.name == "Table of Contents" || file.name == "Contents" {
                        continue
                    }
                    allFiles.append(file)
                }
            }
            // Recurse into subfolders
            if let subfolders = folder.subfolders {
                for subfolder in subfolders {
                    collectFiles(from: subfolder)
                }
            }
        }
        
        for folder in folders {
            collectFiles(from: folder)
        }
        
        #if DEBUG
        print("[TOCGeneration] getAllFilesInProject found \(allFiles.count) files")
        for file in allFiles.prefix(10) {
            print("[TOCGeneration]   - \(file.name)")
        }
        if allFiles.count > 10 {
            print("[TOCGeneration]   ... and \(allFiles.count - 10) more")
        }
        #endif
        
        return allFiles
    }
    
    /// Count how many styles are configured for TOC (public for display purposes)
    func countConfiguredTOCStyles(for project: Project) -> Int {
        guard let styleSheet = StyleSheetService.getStyleSheet(for: project, context: context),
              let styles = styleSheet.textStyles else {
            return 0
        }
        return styles.filter { $0.includeInTOC }.count
    }
    
    /// Get all styles configured for TOC from project's stylesheet
    private func getTOCStyles(for project: Project) -> [TextStyleModel] {
        // Use StyleSheetService to get the stylesheet (handles fallback to default)
        guard let styleSheet = StyleSheetService.getStyleSheet(for: project, context: context),
              let styles = styleSheet.textStyles else {
            #if DEBUG
            print("[TOCGeneration] getTOCStyles: No stylesheet or styles found")
            print("[TOCGeneration]   project.styleSheet: \(project.styleSheet?.name ?? "nil")")
            #endif
            return []
        }
        
        #if DEBUG
        print("[TOCGeneration] getTOCStyles: Using stylesheet '\(styleSheet.name)'")
        print("[TOCGeneration]   Total styles: \(styles.count)")
        let tocEnabled = styles.filter { $0.includeInTOC }
        print("[TOCGeneration]   Styles with includeInTOC=true: \(tocEnabled.count)")
        for style in styles.prefix(15) {
            print("[TOCGeneration]     - \(style.displayName): includeInTOC=\(style.includeInTOC), tocLevel=\(style.tocLevel)")
        }
        #endif
        
        return styles.filter { $0.includeInTOC }
            .sorted { $0.tocLevel < $1.tocLevel }  // Sort by level
    }
    
    /// Find TOC entries within a single file
    private func findEntriesInFile(_ file: TextFile, tocStyles: [TextStyleModel]) -> [TOCEntry] {
        var entries: [TOCEntry] = []
        
        // Get the current version's formatted content
        guard let versions = file.versions,
              file.currentVersionIndex >= 0,
              file.currentVersionIndex < versions.count else {
            #if DEBUG
            print("[TOCGeneration]   ⚠️ No valid version for file: \(file.name)")
            #endif
            return []
        }
        
        let version = versions.sorted { $0.versionNumber < $1.versionNumber }[file.currentVersionIndex]
        
        #if DEBUG
        print("[TOCGeneration]   Version \(version.versionNumber), hasFormattedContent: \(version.formattedContent != nil)")
        #endif
        
        // Use AttributedStringSerializer to properly decode the content (preserves .textStyle attributes)
        let attributedString: NSAttributedString
        if let formattedData = version.formattedContent {
            // Check if it's JSON format (which is what we use now)
            if AttributedStringSerializer.isJSONFormat(formattedData) {
                attributedString = AttributedStringSerializer.decode(formattedData, text: version.content)
                #if DEBUG
                print("[TOCGeneration]   Loaded JSON content: \(attributedString.length) chars")
                #endif
            } else {
                // Try legacy RTF format
                if let rtfString = AttributedStringSerializer.fromRTF(formattedData) {
                    attributedString = rtfString
                    #if DEBUG
                    print("[TOCGeneration]   Loaded legacy RTF content: \(attributedString.length) chars")
                    #endif
                } else {
                    #if DEBUG
                    print("[TOCGeneration]   ⚠️ Could not parse formatted content, using plain text")
                    #endif
                    attributedString = NSAttributedString(string: version.content)
                }
            }
        } else {
            #if DEBUG
            print("[TOCGeneration]   No formatted content, using plain text: \(version.content.count) chars")
            #endif
            attributedString = NSAttributedString(string: version.content)
        }
        
        // Create a map of style names to their TOC info
        var styleNameToTOCInfo: [String: (level: Int, displayName: String)] = [:]
        for style in tocStyles {
            styleNameToTOCInfo[style.name] = (level: style.tocLevel, displayName: style.displayName)
        }
        
        #if DEBUG
        print("[TOCGeneration]   Looking for styles: \(styleNameToTOCInfo.keys.joined(separator: ", "))")
        #endif
        
        // Scan paragraphs for TOC-enabled styles
        let fullString = attributedString.string as NSString
        let fullRange = NSRange(location: 0, length: attributedString.length)
        
        #if DEBUG
        // Check what .textStyle attributes exist in this content
        var foundTextStyles: Set<String> = []
        attributedString.enumerateAttribute(.textStyle, in: fullRange, options: []) { value, _, _ in
            if let styleName = value as? String {
                foundTextStyles.insert(styleName)
            }
        }
        print("[TOCGeneration]   Found .textStyle attributes in file: \(foundTextStyles.sorted().joined(separator: ", "))")
        if foundTextStyles.isEmpty {
            print("[TOCGeneration]   ⚠️ No .textStyle attributes found - content may be plain text or missing style markers")
        }
        #endif
        
        fullString.enumerateSubstrings(in: fullRange, options: .byParagraphs) { substring, substringRange, _, _ in
            guard let paragraphText = substring, !paragraphText.isEmpty else { return }
            
            // Get attributes at the start of this paragraph
            if substringRange.location < attributedString.length {
                let attrs = attributedString.attributes(at: substringRange.location, effectiveRange: nil)
                
                // Check if this paragraph has a TOC-enabled style
                // The .textStyle attribute stores the style name
                if let styleName = attrs[.textStyle] as? String,
                   let tocInfo = styleNameToTOCInfo[styleName] {
                    
                    // Extract heading text (first line only, trimmed)
                    let headingText = paragraphText.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Skip empty headings
                    guard !headingText.isEmpty else { return }
                    
                    let entry = TOCEntry(
                        headingText: headingText,
                        indentLevel: tocInfo.level,
                        sourceFile: file,
                        characterPosition: substringRange.location
                    )
                    entries.append(entry)
                }
            }
        }
        
        return entries
    }
    
    // MARK: - TOC Rendering
    
    /// Generate formatted attributed string for TOC display
    /// - Parameters:
    ///   - entries: TOC entries to render
    ///   - settings: TOC formatting settings
    ///   - project: The project (for style lookup)
    ///   - stylesConfigured: Number of styles configured for TOC (for appropriate empty message)
    /// - Returns: Formatted attributed string
    func renderTOC(entries: [TOCEntry], settings: TOCSettings, project: Project, stylesConfigured: Int = 0) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        // Get stylesheet using the service (handles fallback to default)
        let styleSheet = StyleSheetService.getStyleSheet(for: project, context: context)
        
        #if DEBUG
        print("📑 [TOC Render] Project: \(project.name ?? "unknown")")
        print("📑 [TOC Render] StyleSheet: \(styleSheet?.name ?? "nil")")
        print("📑 [TOC Render] Title style name in settings: '\(settings.titleStyleName)'")
        #endif
        
        // Get title style and generate full attributes
        let titleStyle = styleSheet?.style(named: settings.titleStyleName)
        
        #if DEBUG
        if let style = titleStyle {
            print("📑 [TOC Render] Found title style: \(style.displayName)")
            print("📑 [TOC Render]   textColor: \(style.textColor?.description ?? "nil")")
            print("📑 [TOC Render]   textColorHex: \(style.textColorHex ?? "nil")")
        } else {
            print("📑 [TOC Render] ❌ Title style NOT FOUND!")
            if let styles = styleSheet?.textStyles {
                print("📑 [TOC Render] Available style names:")
                for s in styles.prefix(10) {
                    print("📑 [TOC Render]   - '\(s.name)' (\(s.displayName))")
                }
            }
        }
        #endif
        
        var titleAttrs = titleStyle?.generateAttributes() ?? [
            .font: UIFont.boldSystemFont(ofSize: 28),
            .foregroundColor: UIColor.label
        ]
        
        #if DEBUG
        if let color = titleAttrs[.foregroundColor] as? UIColor {
            print("📑 [TOC Render] Title foreground color: \(color)")
        }
        #endif
        
        // Override paragraph style for TOC-specific formatting
        let titlePara = NSMutableParagraphStyle()
        if let style = titleStyle {
            titlePara.alignment = style.alignment
            titlePara.paragraphSpacing = style.paragraphSpacingAfter > 0 ? style.paragraphSpacingAfter : 12
        } else {
            titlePara.alignment = .natural
            titlePara.paragraphSpacing = 12
        }
        titleAttrs[.paragraphStyle] = titlePara
        
        result.append(NSAttributedString(string: settings.title + "\n", attributes: titleAttrs))
        
        // Handle empty TOC with context-aware message
        if entries.isEmpty {
            // Different message depending on whether styles are configured
            let emptyMessage: String
            let defaultEntryFont = UIFont.systemFont(ofSize: 14)
            if stylesConfigured > 0 {
                // Styles are configured but no content uses them
                emptyMessage = NSLocalizedString("toc.noEntriesStyled", comment: "No styled headings found")
            } else {
                // No styles configured for TOC
                emptyMessage = NSLocalizedString("toc.noEntries", comment: "No headings configured for TOC")
            }
            let emptyAttrs: [NSAttributedString.Key: Any] = [
                .font: defaultEntryFont,
                .foregroundColor: UIColor.secondaryLabel
            ]
            result.append(NSAttributedString(string: emptyMessage, attributes: emptyAttrs))
            return result
        }
        
        // Add entries with per-level styles
        for entry in entries {
            let entryString = formatEntry(entry, settings: settings, styleSheet: styleSheet)
            result.append(entryString)
        }
        
        return result
    }
    
    // MARK: - Pre-Export TOC Regeneration
    
    /// Regenerate the TOC file content before PDF export.
    /// This ensures the TOC includes all current headings with accurate page numbers
    /// (roman numerals for front matter, arabic for body) regardless of when the user
    /// last opened or refreshed the TOC in the editor.
    /// - Parameter project: The project to regenerate the TOC for
    func regenerateTOCForExport(project: Project) async {
        // Find the TOC file in front matter
        guard let manuscriptFolder = project.folders?.first(where: { $0.name == "Manuscript" }),
              let frontMatterFolder = manuscriptFolder.folders?.first(where: { $0.name == "Front Matter" }),
              let tocFile = frontMatterFolder.textFiles?.first(where: { $0.isTOCFile }) else {
            #if DEBUG
            print("[TOCGeneration] No TOC file found for pre-export regeneration")
            #endif
            return
        }
        
        #if DEBUG
        print("[TOCGeneration] ========== PRE-EXPORT TOC REGENERATION ==========")
        #endif
        
        // Generate fresh entries from all manuscript files
        let entries = generateEntries(for: project, tocFile: tocFile)
        
        guard !entries.isEmpty else {
            #if DEBUG
            print("[TOCGeneration] No entries found, skipping regeneration")
            #endif
            return
        }
        
        // Calculate page numbers (with roman numerals for front matter)
        let entriesWithPages = await calculatePageNumbers(for: entries, project: project, tocFile: tocFile)
        
        // Render TOC content
        let settings = tocFile.tocSettings
        let tocContent = renderTOC(entries: entriesWithPages, settings: settings, project: project)
        
        #if DEBUG
        print("[TOCGeneration] Regenerated TOC: \(entriesWithPages.count) entries")
        for entry in entriesWithPages {
            print("[TOCGeneration]   '\(entry.headingText)': page \(entry.formattedPageNumber) (\(entry.isRomanNumeral ? "roman" : "arabic"))")
        }
        print("[TOCGeneration] ========== PRE-EXPORT TOC REGENERATION END ==========")
        #endif
        
        // Save the regenerated content to the TOC file's current version
        if let version = tocFile.currentVersion {
            version.attributedContent = tocContent
            version.content = tocContent.string
        }
    }
    
    /// Format a single TOC entry with per-level styling (simple format for editor display)
    private func formatEntry(_ entry: TOCEntry, settings: TOCSettings, styleSheet: StyleSheet?) -> NSAttributedString {
        // Get the style for this entry's level and generate full attributes
        let styleName = settings.styleName(forLevel: entry.indentLevel)
        let entryStyle = styleSheet?.style(named: styleName)
        var textAttrs = entryStyle?.generateAttributes() ?? [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.label
        ]
        
        // Calculate indent
        let indent = CGFloat(entry.indentLevel) * settings.indentPoints
        
        // Paragraph style with indent
        let para = NSMutableParagraphStyle()
        para.firstLineHeadIndent = indent
        para.headIndent = indent
        para.paragraphSpacing = 4
        textAttrs[.paragraphStyle] = para
        
        // Build entry: heading text, optionally followed by page number
        let result = NSMutableAttributedString()
        
        if settings.showPageNumbers {
            result.append(NSAttributedString(string: "\(entry.headingText)  \(entry.formattedPageNumber)\n", attributes: textAttrs))
        } else {
            result.append(NSAttributedString(string: entry.headingText + "\n", attributes: textAttrs))
        }
        
        return result
    }
    
    // MARK: - Export Formatting
    
    /// Reformat stored TOC content for PDF export with right-aligned page numbers and dot leaders.
    /// Parses each paragraph to detect entry lines ("heading  pageNumber") and reformats them
    /// with dot leaders and a right-aligned page number. Non-entry lines (title, empty) pass through unchanged.
    ///
    /// Uses a right-aligned NSTextTab so the page number snaps to the right edge of the content area.
    /// Dot leaders are measured at print-font size (post-descale) so they align correctly after
    /// PrintService.removePlatformScaling divides all font sizes by kCatalystFontScale.
    /// - Parameters:
    ///   - content: The stored TOC attributed string (simple editor format)
    ///   - project: The project (for page setup dimensions)
    /// - Returns: Reformatted attributed string suitable for PDF rendering
    static func formatTOCContentForExport(_ content: NSAttributedString, project: Project) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let fullString = content.string as NSString
        let fullRange = NSRange(location: 0, length: content.length)
        
        // Calculate content width from page setup (in print points)
        let pageSetup = project.pageSetup ?? PageSetup()
        let paperDims = pageSetup.paperSize.dimensions
        let isLandscape = pageSetup.orientationEnum == .landscape
        let paperWidth = isLandscape ? paperDims.height : paperDims.width
        let contentWidth = paperWidth - pageSetup.marginLeft - pageSetup.marginRight
        
        // Entry line regex: "heading text  page_number" (2+ spaces before trailing digits or roman numerals)
        let entryRegex = try? NSRegularExpression(pattern: "^(.+?)\\s{2,}([ivxlcdm]+|\\d+)$")
        
        fullString.enumerateSubstrings(in: fullRange, options: .byParagraphs) { substring, substringRange, enclosingRange, _ in
            guard let text = substring, !text.isEmpty else {
                // Preserve empty lines / paragraph separators
                result.append(content.attributedSubstring(from: enclosingRange))
                return
            }
            
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            
            // Try to match an entry line: "heading  123"
            if let match = entryRegex?.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.count)),
               let headingRange = Range(match.range(at: 1), in: trimmed),
               let pageNumRange = Range(match.range(at: 2), in: trimmed) {
                
                let headingText = String(trimmed[headingRange])
                let pageNumStr = String(trimmed[pageNumRange])
                
                // Get original attributes
                var attrs = content.attributes(at: substringRange.location, effectiveRange: nil)
                
                // Get indent from existing paragraph style
                let existingPara = attrs[.paragraphStyle] as? NSParagraphStyle
                let indent = existingPara?.firstLineHeadIndent ?? 0
                
                // Tab stop location is from the LEFT EDGE of the container, not from the indent.
                // Place it at contentWidth so ALL page numbers align at the same right-edge
                // position regardless of indent level.
                let tabPosition = contentWidth
                
                // The actual space for heading + dots is from indent to the tab stop.
                let textSpace = tabPosition - indent
                
                // Create paragraph style with right-aligned tab stop
                let para = NSMutableParagraphStyle()
                para.firstLineHeadIndent = indent
                para.headIndent = indent
                para.paragraphSpacing = existingPara?.paragraphSpacing ?? 4
                let tabStop = NSTextTab(textAlignment: .right, location: tabPosition, options: [:])
                para.tabStops = [tabStop]
                para.defaultTabInterval = 1000  // Prevent default tab stops from interfering
                attrs[.paragraphStyle] = para
                
                // Measure using print-size font (matches what renders after removePlatformScaling)
                let catalystFont = attrs[.font] as? UIFont ?? UIFont.systemFont(ofSize: 14)
                let printFont = catalystFont.withSize(catalystFont.pointSize / kCatalystFontScale)
                let fillChar = "."
                let padding: CGFloat = 4
                
                let titleWidth = (headingText as NSString).size(withAttributes: [.font: printFont]).width
                let pageNumWidth = (pageNumStr as NSString).size(withAttributes: [.font: printFont]).width
                let dotWidth = (fillChar as NSString).size(withAttributes: [.font: printFont]).width
                
                // Space for dots = text area (indent→tab) minus heading, page num, and padding
                let spaceForDots = textSpace - titleWidth - pageNumWidth - (padding * 2)
                let dotCount = dotWidth > 0 ? max(0, Int(floor(spaceForDots / dotWidth))) : 0
                let dots = String(repeating: fillChar, count: dotCount)
                
                // Keep font at Catalyst size — PrintService.removePlatformScaling will
                // descale all fonts to print size before rendering into the print-point container.
                
                // Build: "Title ......\t23\n" — tab right-aligns the page number
                let lineStr = headingText + " " + dots + "\t" + pageNumStr + "\n"
                result.append(NSAttributedString(string: lineStr, attributes: attrs))
            } else {
                // Title line or non-entry line — keep as-is
                result.append(content.attributedSubstring(from: enclosingRange))
            }
        }
        
        return result
    }
}
