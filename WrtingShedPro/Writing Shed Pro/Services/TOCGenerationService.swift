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
    let pageNumber: Int
    let indentLevel: Int
    let sourceFile: TextFile
    let characterPosition: Int  // Position in source file for navigation
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
                        pageNumber: 0,  // Will be calculated during rendering
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
        
        // Get styles for TOC formatting
        let titleStyle = project.styleSheet?.style(named: settings.titleStyleName)
        let entryStyle = project.styleSheet?.style(named: settings.entryStyleName)
        
        // Default fonts if styles not found
        let titleFont = titleStyle?.generateFont(applyPlatformScaling: false) ?? UIFont.boldSystemFont(ofSize: 24)
        let entryFont = entryStyle?.generateFont(applyPlatformScaling: false) ?? UIFont.systemFont(ofSize: 12)
        
        // Add title
        let titlePara = NSMutableParagraphStyle()
        titlePara.alignment = .center
        titlePara.paragraphSpacing = 24
        
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .paragraphStyle: titlePara
        ]
        result.append(NSAttributedString(string: settings.title + "\n\n", attributes: titleAttrs))
        
        // Handle empty TOC with context-aware message
        if entries.isEmpty {
            // Different message depending on whether styles are configured
            let emptyMessage: String
            if stylesConfigured > 0 {
                // Styles are configured but no content uses them
                emptyMessage = NSLocalizedString("toc.noEntriesStyled", comment: "No styled headings found")
            } else {
                // No styles configured for TOC
                emptyMessage = NSLocalizedString("toc.noEntries", comment: "No headings configured for TOC")
            }
            let emptyAttrs: [NSAttributedString.Key: Any] = [
                .font: entryFont,
                .foregroundColor: UIColor.secondaryLabel
            ]
            result.append(NSAttributedString(string: emptyMessage, attributes: emptyAttrs))
            return result
        }
        
        // Add entries
        for entry in entries {
            let entryString = formatEntry(entry, settings: settings, font: entryFont)
            result.append(entryString)
        }
        
        return result
    }
    
    /// Format a single TOC entry
    private func formatEntry(_ entry: TOCEntry, settings: TOCSettings, font: UIFont) -> NSAttributedString {
        // Calculate indent
        let indent = CGFloat(entry.indentLevel) * settings.indentPoints
        
        // Use a reasonable page width for TOC (standard letter width minus margins)
        // 612 points = 8.5 inches, minus 1 inch margins on each side = 540 points
        let lineWidth: CGFloat = 540
        
        // Create paragraph style
        let para = NSMutableParagraphStyle()
        para.firstLineHeadIndent = indent
        para.headIndent = indent
        para.paragraphSpacing = 6
        
        // Build entry text
        let result = NSMutableAttributedString()
        
        // Add the heading text
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: para
        ]
        result.append(NSAttributedString(string: entry.headingText, attributes: textAttrs))
        
        if settings.showPageNumbers {
            // Calculate space needed for page number
            let pageNumString = "\(entry.pageNumber)"
            let pageNumWidth = (pageNumString as NSString).size(withAttributes: [.font: font]).width
            
            // Calculate space available for leaders
            let headingWidth = (entry.headingText as NSString).size(withAttributes: [.font: font]).width
            let availableWidth = lineWidth - indent - headingWidth - pageNumWidth - 20 // 20pt padding
            
            if settings.useDotLeaders && availableWidth > 20 {
                // Create dot leaders
                let dotWidth = (settings.separator as NSString).size(withAttributes: [.font: font]).width
                let spaceBetweenDots: CGFloat = 3
                let dotsNeeded = Int(availableWidth / (dotWidth + spaceBetweenDots))
                
                var leaders = " "
                for _ in 0..<max(3, dotsNeeded) {
                    leaders += settings.separator + " "
                }
                
                // Add leaders with secondary color
                let leaderAttrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.tertiaryLabel
                ]
                result.append(NSAttributedString(string: leaders, attributes: leaderAttrs))
            } else {
                // Just add spacing
                result.append(NSAttributedString(string: "  ", attributes: textAttrs))
            }
            
            // Add page number
            result.append(NSAttributedString(string: pageNumString, attributes: textAttrs))
        }
        
        // Add newline
        result.append(NSAttributedString(string: "\n", attributes: textAttrs))
        
        return result
    }
}

