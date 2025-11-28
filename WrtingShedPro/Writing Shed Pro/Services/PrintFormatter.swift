//
//  PrintFormatter.swift
//  Writing Shed Pro
//
//  Prepares content for printing
//  Handles single files and multi-file documents
//

import UIKit
import SwiftData

/// Service for formatting content for printing
class PrintFormatter {
    
    // MARK: - Single File Formatting
    
    /// Prepare a single file's content for printing
    /// - Parameter file: The text file to format
    /// - Returns: Print-ready attributed string with proper scaling
    static func formatFile(_ file: TextFile) -> NSAttributedString? {
        guard let version = file.currentVersion else {
            print("❌ [PrintFormatter] No current version for file: \(file.name)")
            return nil
        }
        
        guard let attributedContent = version.attributedContent else {
            print("❌ [PrintFormatter] No attributed content for file: \(file.name)")
            return nil
        }
        
        // Remove visual page break markers (editor-only indicators)
        let contentWithoutVisualMarkers = PageBreakAttachment.removeVisualMarkers(from: attributedContent)
        
        // Remove platform scaling to get print-accurate sizes
        let printContent = removePlatformScaling(from: contentWithoutVisualMarkers)
        
        print("✅ [PrintFormatter] Formatted file '\(file.name)' for printing")
        print("   - Original length: \(attributedContent.length)")
        print("   - Print length: \(printContent.length)")
        
        return printContent
    }
    
    // MARK: - Multi-File Formatting
    
    /// Combine multiple files for printing
    /// Files flow continuously without page breaks between them (unless enabled in preferences)
    /// - Parameter files: Array of text files to combine
    /// - Returns: Combined attributed string ready for printing
    static func formatMultipleFiles(_ files: [TextFile]) -> NSAttributedString? {
        guard !files.isEmpty else {
            print("❌ [PrintFormatter] Empty file array")
            return nil
        }
        
        let combined = NSMutableAttributedString()
        let usePageBreaks = PageSetupPreferences.shared.pageBreakBetweenFiles
        
        for (index, file) in files.enumerated() {
            guard let fileContent = formatFile(file) else {
                print("⚠️ [PrintFormatter] Skipping file '\(file.name)' - no content")
                continue
            }
            
            // Add the file content
            combined.append(fileContent)
            
            // Add spacing/page break between files (but not after the last one)
            if index < files.count - 1 {
                if usePageBreaks {
                    // Create a paragraph with page break styling
                    // Use both form feed character AND paragraph style for maximum compatibility
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.paragraphSpacing = 0
                    paragraphStyle.lineSpacing = 0
                    
                    // Create attributed string with form feed and page break paragraph style
                    let pageBreakString = NSMutableAttributedString(string: "\n\u{000C}\n")
                    pageBreakString.addAttribute(
                        .paragraphStyle,
                        value: paragraphStyle,
                        range: NSRange(location: 0, length: pageBreakString.length)
                    )
                    
                    combined.append(pageBreakString)
                    print("   - Added page break after '\(file.name)'")
                } else {
                    // Use paragraph break for visual separation
                    let separator = NSAttributedString(string: "\n\n")
                    combined.append(separator)
                }
            }
        }
        
        print("✅ [PrintFormatter] Combined \(files.count) files for printing")
        print("   - Total length: \(combined.length) characters")
        print("   - Page breaks: \(usePageBreaks ? "enabled" : "disabled")")
        
        return combined
    }
    
    // MARK: - Platform Scaling Removal
    
    /// Remove platform-specific scaling to get print-accurate font sizes
    /// This matches the logic used in PaginatedDocumentView
    /// - Parameter attributedString: The attributed string to scale
    /// - Returns: Attributed string with print-accurate font sizes
    static func removePlatformScaling(from attributedString: NSAttributedString) -> NSAttributedString {
        // GOAL: Convert display fonts to print fonts (database base size)
        // Database stores fonts at base iOS size (17pt for Body)
        // Mac Catalyst scales 1.3x for display, so we need to undo that
        // iOS stores and displays at base size, so no scaling needed
        
        #if targetEnvironment(macCatalyst)
        // On Mac Catalyst, edit view applies 1.3x scaling at render time
        // Divide by 1.3 to get back to database/print size
        // 22.1pt (Mac display) → 17pt (print/PDF)
        let scaleFactor: CGFloat = 1.0 / 1.3
        #else
        // On iOS/iPad, database may contain Mac-scaled fonts (22.1pt)
        // Need to divide by 1.3 to get print size
        // 22.1pt (database) → 17pt (print/PDF)
        let scaleFactor: CGFloat = 1.0 / 1.3
        #endif
        
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: mutableString.length)
        
        var fontSizesFound: Set<CGFloat> = []
        var scaledFontSizes: Set<CGFloat> = []
        
        mutableString.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            guard let font = value as? UIFont else { return }
            fontSizesFound.insert(font.pointSize)
            let newSize = font.pointSize * scaleFactor
            scaledFontSizes.insert(newSize)
            let newFont = font.withSize(newSize)
            mutableString.addAttribute(.font, value: newFont, range: range)
        }
        
        print("   - Applied scaling factor: \(scaleFactor) (Mac=÷1.3, iOS=×1.0)")
        print("   - Original font sizes: \(fontSizesFound.sorted())")
        print("   - Scaled font sizes: \(scaledFontSizes.sorted())")
        
        return mutableString
    }
    
    // MARK: - Page Setup Application
    
    /// Apply page setup configuration to attributed string
    /// Adds paragraph styles for margins and spacing
    /// - Parameters:
    ///   - attributedString: The content to format
    ///   - pageSetup: The page configuration to apply
    /// - Returns: Formatted attributed string with page setup applied
    static func applyPageSetup(to attributedString: NSAttributedString, pageSetup: PageSetup) -> NSAttributedString {
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: mutableString.length)
        
        // Create paragraph style with margins
        let paragraphStyle = NSMutableParagraphStyle()
        
        // Note: Margins are handled by the print layout system
        // This applies text-level paragraph spacing
        paragraphStyle.lineSpacing = 0
        paragraphStyle.paragraphSpacing = 0
        
        // Enumerate existing paragraph styles and preserve them
        // Only add default if no style exists
        mutableString.enumerateAttribute(.paragraphStyle, in: fullRange, options: []) { value, range, _ in
            if value == nil {
                // No paragraph style - add default
                mutableString.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
            }
            // If there's already a paragraph style, preserve it
        }
        
        return mutableString
    }
    
    // MARK: - Content Validation
    
    /// Check if content is valid for printing
    /// - Parameter attributedString: The content to validate
    /// - Returns: True if content can be printed
    static func isValidForPrinting(_ attributedString: NSAttributedString?) -> Bool {
        guard let content = attributedString, content.length > 0 else {
            return false
        }
        return true
    }
    
    /// Get estimated page count for content
    /// Uses standard page setup to estimate
    /// - Parameters:
    ///   - content: The attributed string content
    ///   - pageSetup: The page configuration
    /// - Returns: Estimated number of pages
    static func estimatedPageCount(for content: NSAttributedString, pageSetup: PageSetup) -> Int {
        // This is a rough estimate
        // Actual page count will be calculated by the layout manager
        let printableHeight = pageSetup.paperSize.dimensions.height - pageSetup.marginTop - pageSetup.marginBottom
        let averageLineHeight: CGFloat = 20.0 // Approximate
        let linesPerPage = Int(printableHeight / averageLineHeight)
        
        // Rough character-to-line estimation
        let charactersPerLine = 80 // Approximate
        let estimatedLines = content.length / charactersPerLine
        
        let pages = max(1, (estimatedLines + linesPerPage - 1) / linesPerPage)
        return pages
    }
}
