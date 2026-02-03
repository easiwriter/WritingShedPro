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
    
    /// Create entry with just source file position (page number calculated later)
    init(headingText: String, indentLevel: Int, sourceFile: TextFile, characterPosition: Int, globalCharacterPosition: Int = 0) {
        self.headingText = headingText
        self.pageNumber = 0
        self.indentLevel = indentLevel
        self.sourceFile = sourceFile
        self.characterPosition = characterPosition
        self.globalCharacterPosition = globalCharacterPosition
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
    /// - Parameters:
    ///   - entries: TOC entries to update with page numbers
    ///   - project: The project to paginate
    ///   - tocFile: The TOC file to exclude from pagination
    /// - Returns: Updated entries with calculated page numbers
    func calculatePageNumbers(for entries: [TOCEntry], project: Project, tocFile: TextFile?) async -> [TOCEntry] {
        #if DEBUG
        print("[TOCGeneration] ========== PAGE NUMBER CALCULATION START ==========")
        #endif
        
        // Build assembled content EXCLUDING the TOC file for accurate page numbers
        // The TOC file won't be part of the printed/exported manuscript body
        
        var fileOffsets: [UUID: Int] = [:]
        let assembledContent = NSMutableAttributedString()
        var isFirstFile = true
        
        // Check if page breaks between files are enabled (use project setting, not global)
        let pageSetup = project.pageSetup ?? PageSetup()
        let usePageBreaks = pageSetup.hasPageBreakBetweenFiles
        let pageBreak = NSAttributedString(string: "\u{0C}") // Form feed character
        
        #if DEBUG
        print("[TOCGeneration] Page break between files: \(usePageBreaks ? "ENABLED" : "disabled")")
        #endif
        
        let sections = assemblyService.getSections(for: project)
        
        // Assemble content excluding the TOC file
        for section in sections {
            for file in section.files {
                // Skip the TOC file - it's not part of the main manuscript
                if let tocFile = tocFile, file.id == tocFile.id {
                    continue
                }
                
                // Add section/page break between files (not before first)
                if !isFirstFile {
                    if usePageBreaks {
                        assembledContent.append(pageBreak)
                    } else {
                        assembledContent.append(NSAttributedString(string: "\n\n"))
                    }
                }
                isFirstFile = false
                
                // Record offset before adding
                fileOffsets[file.id] = assembledContent.length
                
                // Add file content
                if let version = file.currentVersion, let content = version.attributedContent {
                    assembledContent.append(content)
                }
            }
        }
        
        #if DEBUG
        print("[TOCGeneration] File offsets calculated (excluding TOC):")
        for (fileId, offset) in fileOffsets {
            print("[TOCGeneration]   \(fileId.uuidString.prefix(8)): offset \(offset)")
        }
        print("[TOCGeneration] Assembled content (excluding TOC): \(assembledContent.length) characters")
        #endif
        
        // Create text storage and paginate
        let textStorage = NSTextStorage(attributedString: assembledContent)
        let layoutManager = PaginatedTextLayoutManager(textStorage: textStorage, pageSetup: pageSetup)
        
        // Calculate layout
        let layoutResult = layoutManager.calculateLayout()
        
        #if DEBUG
        print("[TOCGeneration] Pagination complete: \(layoutResult.totalPages) pages")
        #endif
        
        // Now update entries with page numbers
        var updatedEntries: [TOCEntry] = []
        
        for var entry in entries {
            // Calculate global position from file offset + local position
            let fileOffset = fileOffsets[entry.sourceFile.id] ?? 0
            let globalPosition = fileOffset + entry.characterPosition
            
            // Find which page this position falls on
            let pageNumber = findPageForCharacterPosition(globalPosition, in: layoutResult)
            entry.pageNumber = pageNumber
            
            #if DEBUG
            print("[TOCGeneration]   '\(entry.headingText.prefix(30))': pos \(globalPosition) -> page \(pageNumber)")
            #endif
            
            updatedEntries.append(entry)
        }
        
        #if DEBUG
        print("[TOCGeneration] ========== PAGE NUMBER CALCULATION END ==========")
        #endif
        
        return updatedEntries
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
    
    /// Format a single TOC entry with per-level styling
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
        
        // Tab stop position for page numbers (absolute from left margin)
        let tabPosition = settings.pageNumberPosition
        
        // Build the result
        let result = NSMutableAttributedString()
        
        // Add heading text
        let headingText = entry.headingText
        
        if settings.showPageNumbers {
            let font = textAttrs[.font] as? UIFont ?? UIFont.systemFont(ofSize: 14)
            let pageNumberText = "\(entry.pageNumber)"
            
            // Always use tab stop for consistent page number alignment
            let para = NSMutableParagraphStyle()
            para.firstLineHeadIndent = indent
            para.headIndent = indent
            para.paragraphSpacing = 4
            para.tabStops = [
                NSTextTab(textAlignment: .right, location: tabPosition - indent, options: [:])
            ]
            textAttrs[.paragraphStyle] = para
            
            result.append(NSAttributedString(string: headingText, attributes: textAttrs))
            
            if settings.useDotLeaders && !settings.separator.isEmpty {
                // Calculate available width for dot leaders (before the tab stop)
                let headingWidth = (headingText as NSString).size(withAttributes: [.font: font]).width
                let pageNumberWidth = (pageNumberText as NSString).size(withAttributes: [.font: font]).width
                let availableWidth = tabPosition - indent - headingWidth - pageNumberWidth - 16 // padding
                
                if availableWidth > 20 {
                    // Calculate how many separator units fit
                    let separatorUnit = settings.separator + " "
                    let unitWidth = (separatorUnit as NSString).size(withAttributes: [.font: font]).width
                    let numUnits = max(3, Int(availableWidth / unitWidth))
                    
                    // Add dots (in secondary color), then tab, then page number
                    let leaderString = " " + String(repeating: separatorUnit, count: numUnits)
                    var leaderAttrs = textAttrs
                    leaderAttrs[.foregroundColor] = UIColor.secondaryLabel
                    result.append(NSAttributedString(string: leaderString, attributes: leaderAttrs))
                }
            }
            
            // Tab to align page number, then page number
            result.append(NSAttributedString(string: "\t", attributes: textAttrs))
            result.append(NSAttributedString(string: pageNumberText + "\n", attributes: textAttrs))
        } else {
            // No page numbers
            let para = NSMutableParagraphStyle()
            para.firstLineHeadIndent = indent
            para.headIndent = indent
            para.paragraphSpacing = 4
            textAttrs[.paragraphStyle] = para
            
            result.append(NSAttributedString(string: headingText + "\n", attributes: textAttrs))
        }
        
        return result
    }
}
