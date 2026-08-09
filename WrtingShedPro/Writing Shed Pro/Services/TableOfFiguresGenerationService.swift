//
//  TableOfFiguresGenerationService.swift
//  Writing Shed Pro
//
//  Service for generating Table of Figures entries from manuscript images
//  Feature 112: Table of Figures
//

import Foundation
import SwiftData
import UIKit

/// Represents a single entry in the Table of Figures
struct FigureEntry: Identifiable {
    let id = UUID()
    let imageID: UUID
    let figureNumber: Int  // Sequential number based on document order
    let captionText: String?  // nil if no caption
    let captionPrefix: String?  // From image attachment
    var pageNumber: Int  // Mutable - calculated during pagination
    let sourceFile: TextFile
    let characterPosition: Int  // Position in source file
    let globalCharacterPosition: Int  // Position in assembled manuscript (for page calculation)
    
    /// Whether this figure has a caption
    var hasCaption: Bool {
        if let caption = captionText {
            return !caption.isEmpty
        }
        return false
    }
}

/// Service for generating Table of Figures from manuscript images
@MainActor
final class TableOfFiguresGenerationService {
    private let context: ModelContext
    private let assemblyService: ManuscriptAssemblyService
    
    init(context: ModelContext) {
        self.context = context
        self.assemblyService = ManuscriptAssemblyService(context: context)
    }
    
    // MARK: - Figure Entry Generation
    
    /// Generate figure entries for a project
    /// - Parameters:
    ///   - project: The project to scan for images
    ///   - tofFile: The Table of Figures file itself (to exclude from scanning)
    /// - Returns: Array of figure entries in manuscript order
    func generateEntries(for project: Project, tofFile: TextFile? = nil) -> [FigureEntry] {
        var entries: [FigureEntry] = []
        var figureNumber = 1
        var globalOffset = 0
        
        #if DEBUG
        print("[TOFGeneration] Starting entry generation for project: \(project.name ?? "unnamed")")
        #endif
        
        // Get all manuscript sections in order
        let sections = assemblyService.getSections(for: project)
        
        #if DEBUG
        print("[TOFGeneration] Found \(sections.count) manuscript sections")
        #endif
        
        for section in sections {
            for file in section.files {
                // Skip the TOF file itself
                if let tofFile = tofFile, file.id == tofFile.id {
                    continue
                }
                if shouldSkipForFigurePagination(file, in: section) {
                    continue
                }
                
                // Find images in this file
                let fileEntries = findImagesInFile(file, startingFigureNumber: figureNumber, globalOffset: globalOffset)
                entries.append(contentsOf: fileEntries)
                figureNumber += fileEntries.count
                
                // Update global offset for next file
                if let version = file.currentVersion, let content = version.attributedContent {
                    globalOffset += content.length + 2  // +2 for paragraph breaks between files
                }
            }
        }
        
        #if DEBUG
        print("[TOFGeneration] Generated \(entries.count) figure entries total")
        #endif
        
        return entries
    }
    
    // MARK: - Page Number Calculation
    
    /// Calculate page numbers for figure entries by paginating the manuscript
    func calculatePageNumbers(for entries: [FigureEntry], project: Project, tofFile: TextFile?) async -> [FigureEntry] {
        #if DEBUG
        print("[TOFGeneration] ========== PAGE NUMBER CALCULATION START ==========")
        #endif
        
        var fileOffsets: [UUID: Int] = [:]
        let assembledContent = NSMutableAttributedString()
        var isFirstFile = true
        
        // Get page setup
        let pageSetup = project.pageSetup ?? PageSetup()
        let usePageBreaks = pageSetup.hasPageBreakBetweenFiles
        let pageBreak = NSAttributedString(string: "\u{0C}") // Form feed character
        
        let sections = assemblyService.getSections(for: project)
        
        // Assemble content excluding the TOF file
        for section in sections {
            for file in section.files {
                // Skip the TOF file
                if let tofFile = tofFile, file.id == tofFile.id {
                    continue
                }
                if shouldSkipForFigurePagination(file, in: section) {
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
        
        // Create text storage and paginate
        let textStorage = NSTextStorage(attributedString: assembledContent)
        let layoutManager = PaginatedTextLayoutManager(textStorage: textStorage, pageSetup: pageSetup)
        
        // Calculate layout
        let layoutResult = layoutManager.calculateLayout()
        
        #if DEBUG
        print("[TOFGeneration] Pagination complete: \(layoutResult.totalPages) pages")
        #endif
        
        // Update entries with page numbers
        var updatedEntries: [FigureEntry] = []
        
        for var entry in entries {
            let fileOffset = fileOffsets[entry.sourceFile.id] ?? 0
            let globalPosition = fileOffset + entry.characterPosition
            
            // Find which page this position falls on
            let pageNumber = findPageForCharacterPosition(globalPosition, in: layoutResult)
            entry.pageNumber = pageNumber
            
            #if DEBUG
            print("[TOFGeneration] Figure \(entry.figureNumber) '\(entry.captionText ?? "no caption")' -> page \(pageNumber)")
            #endif
            
            updatedEntries.append(entry)
        }
        
        #if DEBUG
        print("[TOFGeneration] ========== PAGE NUMBER CALCULATION COMPLETE ==========")
        #endif
        
        return updatedEntries
    }
    
    // MARK: - Rendering
    
    /// Render the Table of Figures as attributed string
    func renderTableOfFigures(
        entries: [FigureEntry],
        settings: TableOfFiguresSettings,
        project: Project,
        missingCaptionCount: Int = 0,
        missingCaptionPages: [Int] = []
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        // Get stylesheet for styling
        let styleSheet = StyleSheetService.getStyleSheet(for: project, context: context)
        
        // Add title using the project's matter heading style (falls back to the TOF's own title style)
        let matterHeadingStyle = styleSheet?.textStyles?.first { $0.name == project.matterHeadingStyleName }
        let titleStyle = matterHeadingStyle ?? styleSheet?.textStyles?.first { $0.name == settings.titleStyleName }
        var titleAttributes: [NSAttributedString.Key: Any] = titleStyle?.generateAttributes() ?? [
            .font: UIFont.preferredFont(forTextStyle: .largeTitle).withSize(28)
        ]
        // Enforce minimum space after heading
        if let existingPara = titleAttributes[.paragraphStyle] as? NSParagraphStyle {
            if existingPara.paragraphSpacing < 12 {
                let mutablePara = existingPara.mutableCopy() as! NSMutableParagraphStyle
                mutablePara.paragraphSpacing = 12
                titleAttributes[.paragraphStyle] = mutablePara
            }
        } else {
            let para = NSMutableParagraphStyle()
            para.paragraphSpacing = 12
            titleAttributes[.paragraphStyle] = para
        }
        
        result.append(NSAttributedString(string: settings.title + "\n", attributes: titleAttributes))
        
        // Filter entries based on settings
        let filteredEntries: [FigureEntry]
        if settings.showMissingCaption {
            filteredEntries = entries
        } else {
            filteredEntries = entries.filter { $0.hasCaption }
        }
        
        // Add each entry
        for entry in filteredEntries {
            let entryString = formatEntry(entry, settings: settings, styleSheet: styleSheet, project: project)
            result.append(entryString)
            result.append(NSAttributedString(string: "\n"))
        }
        
        return result
    }
    
    // MARK: - Private Helpers
    
    /// Find images in a single file
    private func findImagesInFile(_ file: TextFile, startingFigureNumber: Int, globalOffset: Int) -> [FigureEntry] {
        var entries: [FigureEntry] = []
        var figureNumber = startingFigureNumber
        
        guard let version = file.currentVersion,
              let content = version.attributedContent else {
            return []
        }
        
        // Enumerate through content looking for image attachments
        content.enumerateAttribute(.attachment, in: NSRange(location: 0, length: content.length)) { value, range, _ in
            if let imageAttachment = value as? ImageAttachment {
                let entry = FigureEntry(
                    imageID: imageAttachment.imageID,
                    figureNumber: figureNumber,
                    captionText: imageAttachment.hasCaption ? imageAttachment.captionText : nil,
                    captionPrefix: imageAttachment.captionPrefix,
                    pageNumber: 0,  // Will be calculated later
                    sourceFile: file,
                    characterPosition: range.location,
                    globalCharacterPosition: globalOffset + range.location
                )
                entries.append(entry)
                figureNumber += 1
                
                #if DEBUG
                print("[TOFGeneration] Found image in \(file.name): figure \(entry.figureNumber), caption: '\(entry.captionText ?? "none")'")
                #endif
            }
        }
        
        return entries
    }

    private func shouldSkipForFigurePagination(_ file: TextFile, in section: ManuscriptSection) -> Bool {
        if file.isCoverFile || file.isTOCFile || file.isTableOfFiguresFile {
            return true
        }
        if ManuscriptAssemblyService.generatedBackMatterType(for: file) != nil {
            return true
        }
        guard section.sectionType == .frontMatter || section.sectionType == .backMatter else {
            return false
        }
        if let attributedContent = file.currentVersion?.attributedContent {
            return Self.isEffectivelyEmpty(attributedContent)
        }
        return Self.isEffectivelyEmpty(file.currentVersion?.content ?? "")
    }

    private static func isEffectivelyEmpty(_ content: NSAttributedString) -> Bool {
        guard isEffectivelyEmpty(content.string) else { return false }

        var hasImageAttachment = false
        content.enumerateAttribute(.attachment, in: NSRange(location: 0, length: content.length), options: []) { value, _, stop in
            if value is ImageAttachment {
                hasImageAttachment = true
                stop.pointee = true
            }
        }
        return !hasImageAttachment
    }

    private static func isEffectivelyEmpty(_ text: String) -> Bool {
        text
            .replacingOccurrences(of: "\u{FFFC}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }
    
    /// Find which page a character position falls on
    private func findPageForCharacterPosition(_ position: Int, in layoutResult: PaginatedTextLayoutManager.LayoutResult) -> Int {
        for (index, page) in layoutResult.pageInfos.enumerated() {
            if position >= page.characterRange.location &&
               position < page.characterRange.location + page.characterRange.length {
                return index + 1  // 1-based page numbers
            }
        }
        // If position is past all pages, return last page
        return max(1, layoutResult.totalPages)
    }
    
    /// Format a single figure entry (simple format for editor/storage — dot leaders added at export time)
    private func formatEntry(_ entry: FigureEntry, settings: TableOfFiguresSettings, styleSheet: StyleSheet?, project: Project? = nil) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        // Get entry style from the project's matter body style
        let entryStyle: TextStyleModel? = project.flatMap { p in
            styleSheet?.textStyles?.first { $0.name == p.matterBodyStyleName }
        }
        var entryAttributes: [NSAttributedString.Key: Any] = entryStyle?.generateAttributes() ?? [
            .font: UIFont.preferredFont(forTextStyle: .body)
        ]
        
        // Override paragraph spacing for compact entries
        let para = NSMutableParagraphStyle()
        para.paragraphSpacing = 4
        if let existingPara = entryAttributes[.paragraphStyle] as? NSParagraphStyle {
            para.alignment = existingPara.alignment
            para.lineSpacing = existingPara.lineSpacing
            para.firstLineHeadIndent = existingPara.firstLineHeadIndent
            para.headIndent = existingPara.headIndent
        }
        entryAttributes[.paragraphStyle] = para
        
        // Build entry text
        var entryText = ""
        if let prefix = settings.captionPrefix {
            entryText = "\(prefix) \(entry.figureNumber): "
        }
        
        if let caption = entry.captionText, !caption.isEmpty {
            entryText += caption
        } else {
            entryText += NSLocalizedString("tof.missingCaption", comment: "Missing caption")
        }
        
        // Append entry text, optionally followed by page number
        // Use "text  number" (2+ spaces) format — dot leaders added at export by formatTOFContentForExport
        if settings.showPageNumbers {
            result.append(NSAttributedString(string: "\(entryText)  \(entry.pageNumber)", attributes: entryAttributes))
        } else {
            result.append(NSAttributedString(string: entryText, attributes: entryAttributes))
        }
        
        return result
    }
    
    // MARK: - Export Formatting
    
    /// Reformat TOF content for PDF export with right-aligned page numbers and dot leaders.
    /// Mirrors the approach used by TOCGenerationService.formatTOCContentForExport.
    /// Parses each paragraph to detect entry lines ("heading  pageNumber") and reformats them
    /// with dot leaders and a right-aligned page number. Non-entry lines (title, empty) pass through unchanged.
    /// - Parameters:
    ///   - content: The rendered TOF attributed string (simple editor format)
    ///   - project: The project (for page setup dimensions)
    /// - Returns: Reformatted attributed string suitable for PDF rendering
    static func formatTOFContentForExport(_ content: NSAttributedString, project: Project) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let fullString = content.string as NSString
        let fullRange = NSRange(location: 0, length: content.length)
        
        // Calculate content width from page setup (in print points)
        let pageSetup = project.pageSetup ?? PageSetup()
        let paperDims = pageSetup.paperSize.dimensions
        let isLandscape = pageSetup.orientationEnum == .landscape
        let paperWidth = isLandscape ? paperDims.height : paperDims.width
        let contentWidth = paperWidth - pageSetup.marginLeft - pageSetup.marginRight
        
        // Entry line regex: "entry text  page_number" (2+ spaces before trailing digits)
        let entryRegex = try? NSRegularExpression(pattern: "^(.+?)\\s{2,}(\\d+)$")
        
        fullString.enumerateSubstrings(in: fullRange, options: .byParagraphs) { substring, substringRange, enclosingRange, _ in
            guard let text = substring, !text.isEmpty else {
                result.append(content.attributedSubstring(from: enclosingRange))
                return
            }
            
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            
            if let match = entryRegex?.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.count)),
               let entryRange = Range(match.range(at: 1), in: trimmed),
               let pageNumRange = Range(match.range(at: 2), in: trimmed) {
                
                let entryText = String(trimmed[entryRange])
                let pageNumStr = String(trimmed[pageNumRange])
                
                var attrs = content.attributes(at: substringRange.location, effectiveRange: nil)
                
                let existingPara = attrs[.paragraphStyle] as? NSParagraphStyle
                let indent = existingPara?.firstLineHeadIndent ?? 0
                let tabPosition = contentWidth
                let textSpace = tabPosition - indent
                
                let para = NSMutableParagraphStyle()
                para.firstLineHeadIndent = indent
                para.headIndent = indent
                para.paragraphSpacing = existingPara?.paragraphSpacing ?? 4
                let tabStop = NSTextTab(textAlignment: .right, location: tabPosition, options: [:])
                para.tabStops = [tabStop]
                para.defaultTabInterval = 1000
                attrs[.paragraphStyle] = para
                
                // Measure using print-size font (matches what renders after removePlatformScaling)
                let catalystFont = attrs[.font] as? UIFont ?? UIFont.systemFont(ofSize: 14)
                let printFont = catalystFont.withSize(catalystFont.pointSize / kCatalystFontScale)
                let fillChar = "."
                let padding: CGFloat = 4
                
                let titleWidth = (entryText as NSString).size(withAttributes: [.font: printFont]).width
                let pageNumWidth = (pageNumStr as NSString).size(withAttributes: [.font: printFont]).width
                let dotWidth = (fillChar as NSString).size(withAttributes: [.font: printFont]).width
                
                let spaceForDots = textSpace - titleWidth - pageNumWidth - (padding * 2)
                let dotCount = dotWidth > 0 ? max(0, Int(floor(spaceForDots / dotWidth))) : 0
                let dots = String(repeating: fillChar, count: dotCount)
                
                let lineStr = entryText + " " + dots + "\t" + pageNumStr + "\n"
                result.append(NSAttributedString(string: lineStr, attributes: attrs))
            } else {
                // Title line or non-entry line — keep as-is
                result.append(content.attributedSubstring(from: enclosingRange))
            }
        }
        
        return result
    }
}
