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
        
        // Get styles that should appear in TOC
        let tocStyles = getTOCStyles(for: project)
        guard !tocStyles.isEmpty else {
            #if DEBUG
            print("[TOCGeneration] No styles configured for TOC")
            #endif
            return []
        }
        
        #if DEBUG
        print("[TOCGeneration] Found \(tocStyles.count) styles configured for TOC:")
        for style in tocStyles {
            print("  - \(style.displayName) (level \(style.tocLevel))")
        }
        #endif
        
        // Get all manuscript sections in order
        let sections = assemblyService.getSections(for: project)
        
        // Process each file in order
        for section in sections {
            for file in section.files {
                // Skip the TOC file itself to avoid circular reference
                if let tocFile = tocFile, file.id == tocFile.id {
                    continue
                }
                
                // Find TOC entries in this file
                let fileEntries = findEntriesInFile(file, tocStyles: tocStyles)
                entries.append(contentsOf: fileEntries)
            }
        }
        
        #if DEBUG
        print("[TOCGeneration] Generated \(entries.count) TOC entries")
        #endif
        
        return entries
    }
    
    /// Get all styles configured for TOC from project's stylesheet
    private func getTOCStyles(for project: Project) -> [TextStyleModel] {
        guard let styleSheet = project.styleSheet,
              let styles = styleSheet.textStyles else {
            return []
        }
        
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
            return []
        }
        
        let version = versions.sorted { $0.versionNumber < $1.versionNumber }[file.currentVersionIndex]
        
        // Try to get formatted content first, fall back to plain text
        let attributedString: NSAttributedString
        if let formattedData = version.formattedContent {
            do {
                attributedString = try NSAttributedString(
                    data: formattedData,
                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                    documentAttributes: nil
                )
            } catch {
                // Fall back to plain text if RTF parsing fails
                attributedString = NSAttributedString(string: version.content)
            }
        } else {
            attributedString = NSAttributedString(string: version.content)
        }
        
        // Create a map of style names to their TOC info
        var styleNameToTOCInfo: [String: (level: Int, displayName: String)] = [:]
        for style in tocStyles {
            styleNameToTOCInfo[style.name] = (level: style.tocLevel, displayName: style.displayName)
        }
        
        // Scan paragraphs for TOC-enabled styles
        let fullString = attributedString.string as NSString
        let fullRange = NSRange(location: 0, length: attributedString.length)
        
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
    /// - Returns: Formatted attributed string
    func renderTOC(entries: [TOCEntry], settings: TOCSettings, project: Project) -> NSAttributedString {
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
        
        // Handle empty TOC
        if entries.isEmpty {
            let emptyMessage = NSLocalizedString("toc.noEntries", comment: "No headings configured for TOC")
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
        
        // Create paragraph style with tabs for right-aligned page numbers
        let para = NSMutableParagraphStyle()
        para.firstLineHeadIndent = indent
        para.headIndent = indent
        para.tabStops = [
            NSTextTab(textAlignment: .right, location: 450, options: [:])  // Right tab for page number
        ]
        para.paragraphSpacing = 4
        
        // Build entry text
        var entryText = entry.headingText
        
        if settings.showPageNumbers && settings.useDotLeaders {
            // Add dot leaders and page number
            entryText += "\t\(entry.pageNumber)\n"
        } else if settings.showPageNumbers {
            // Just add page number with tab
            entryText += "\t\(entry.pageNumber)\n"
        } else {
            entryText += "\n"
        }
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: para
        ]
        
        return NSAttributedString(string: entryText, attributes: attrs)
    }
}

