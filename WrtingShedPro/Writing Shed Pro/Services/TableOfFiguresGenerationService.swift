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
        
        // Add title
        let titleStyle = styleSheet?.textStyles?.first { $0.name == settings.titleStyleName }
        let titleAttributes: [NSAttributedString.Key: Any] = titleStyle?.generateAttributes() ?? [
            .font: UIFont.preferredFont(forTextStyle: .largeTitle).withSize(28)
        ]
        
        result.append(NSAttributedString(string: settings.title + "\n\n", attributes: titleAttributes))
        
        // Filter entries based on settings
        let filteredEntries: [FigureEntry]
        if settings.showMissingCaption {
            filteredEntries = entries
        } else {
            filteredEntries = entries.filter { $0.hasCaption }
        }
        
        // Add each entry
        for entry in filteredEntries {
            let entryString = formatEntry(entry, settings: settings, styleSheet: styleSheet)
            result.append(entryString)
            result.append(NSAttributedString(string: "\n"))
        }
        
        // If not showing missing captions but some exist, add summary message
        if !settings.showMissingCaption && missingCaptionCount > 0 {
            result.append(NSAttributedString(string: "\n"))
            let summaryText: String
            if missingCaptionPages.count <= 5 {
                let pagesList = missingCaptionPages.map { String($0) }.joined(separator: ", ")
                summaryText = String(format: NSLocalizedString("tof.missingCaption.summary.withPages", comment: ""), missingCaptionCount, pagesList)
            } else {
                summaryText = String(format: NSLocalizedString("tof.missingCaption.summary", comment: ""), missingCaptionCount)
            }
            let summaryAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.preferredFont(forTextStyle: .footnote),
                .foregroundColor: UIColor.secondaryLabel
            ]
            result.append(NSAttributedString(string: summaryText, attributes: summaryAttributes))
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
    
    /// Format a single figure entry
    private func formatEntry(_ entry: FigureEntry, settings: TableOfFiguresSettings, styleSheet: StyleSheet?) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        // Get entry style attributes
        let entryStyle = styleSheet?.textStyles?.first { $0.name == settings.entryStyleName }
        let entryAttributes: [NSAttributedString.Key: Any] = entryStyle?.generateAttributes() ?? [
            .font: UIFont.preferredFont(forTextStyle: .body)
        ]
        
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
        if settings.showPageNumbers {
            result.append(NSAttributedString(string: "\(entryText)  \(entry.pageNumber)", attributes: entryAttributes))
        } else {
            result.append(NSAttributedString(string: entryText, attributes: entryAttributes))
        }
        
        return result
    }
}
