//
//  PaginatedTextLayoutManager.swift
//  Writing Shed Pro
//
//  Manages text layout across multiple pages using TextKit 1
//  Calculates page count, maps text ranges to pages, and provides layout state
//

import Foundation
import UIKit
import SwiftData

/// Manages the text layout for paginated document view
/// Uses NSLayoutManager to calculate how text flows across pages
@Observable
class PaginatedTextLayoutManager {
    
    // MARK: - Types
    
    /// Information about a single page in the layout
    struct PageInfo {
        let pageIndex: Int              // Zero-based page index
        let glyphRange: NSRange         // Range of glyphs on this page
        let characterRange: NSRange     // Range of characters on this page
        let usedRect: CGRect            // Actual bounds of text on page
    }
    
    /// Result of layout calculation
    struct LayoutResult {
        let totalPages: Int
        let pageInfos: [PageInfo]
        let contentSize: CGSize         // Total scroll content size
        let calculationTime: TimeInterval
    }
    
    // MARK: - Properties
    
    /// The text storage containing the document content
    private(set) var textStorage: NSTextStorage
    
    /// The layout manager that calculates text layout
    private(set) var layoutManager: NSLayoutManager
    
    /// Page setup configuration
    private(set) var pageSetup: PageSetup
    
    /// Cached layout result
    private(set) var layoutResult: LayoutResult?
    
    /// Whether the current layout is valid
    private(set) var isLayoutValid: Bool = false
    
    /// Page spacing between pages in scroll view
    let pageSpacing: CGFloat = 20.0
    
    // MARK: - Initialization
    
    /// Initialize with text storage and page setup
    /// - Parameters:
    ///   - textStorage: The text storage containing document content
    ///   - pageSetup: Page setup configuration
    init(textStorage: NSTextStorage, pageSetup: PageSetup) {
        self.textStorage = textStorage
        self.pageSetup = pageSetup
        
        // Create layout manager
        self.layoutManager = NSLayoutManager()
        self.layoutManager.allowsNonContiguousLayout = true
        
        // Connect text storage to layout manager
        textStorage.addLayoutManager(layoutManager)
        
        // Observe text changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textStorageDidChange),
            name: NSTextStorage.didProcessEditingNotification,
            object: textStorage
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Layout Calculation
    
    /// Calculate the complete page layout
    /// This is the main method that determines how many pages are needed
    /// and which text appears on each page
    /// - Returns: Layout result with page count and page information
    @discardableResult
    func calculateLayout() -> LayoutResult {
        let startTime = Date()
        
        // Get page layout from calculator
        let pageLayout = PageLayoutCalculator.calculateLayout(from: pageSetup)
        let containerSize = pageLayout.contentRect.size
        
        // Calculate pages by measuring how much text fits in each page container
        var pageInfos: [PageInfo] = []
        var characterIndex = 0
        let totalCharacters = textStorage.length
        
        while characterIndex < totalCharacters || pageInfos.isEmpty {
            let pageIndex = pageInfos.count
            
            // Create a temporary container for this page
            let container = NSTextContainer(size: containerSize)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            
            // Get the glyph range for this container
            let glyphRange = layoutManager.glyphRange(for: container)
            
            // Convert to character range
            let characterRange = layoutManager.characterRange(
                forGlyphRange: glyphRange,
                actualGlyphRange: nil
            )
            
            // Get the used rect (actual bounds of text in container)
            let usedRect = layoutManager.usedRect(for: container)
            
            // Create page info
            let pageInfo = PageInfo(
                pageIndex: pageIndex,
                glyphRange: glyphRange,
                characterRange: characterRange,
                usedRect: usedRect
            )
            pageInfos.append(pageInfo)
            
            // Move to next page
            characterIndex = NSMaxRange(characterRange)
            
            // If we've processed all text, we're done
            if characterIndex >= totalCharacters {
                break
            }
            
            // Safety check: if no characters were processed, break to avoid infinite loop
            if characterRange.length == 0 {
                break
            }
        }
        
        // Remove the temporary containers (we only needed them for calculation)
        let containers = layoutManager.textContainers
        for container in containers {
            layoutManager.removeTextContainer(at: 0)
        }
        
        // Always have at least one page (for empty documents)
        if pageInfos.isEmpty {
            let emptyPageInfo = PageInfo(
                pageIndex: 0,
                glyphRange: NSRange(location: 0, length: 0),
                characterRange: NSRange(location: 0, length: 0),
                usedRect: .zero
            )
            pageInfos.append(emptyPageInfo)
        }
        
        // Calculate total content size for scroll view
        let pageHeight = pageLayout.pageRect.height
        let totalHeight = CGFloat(pageInfos.count) * (pageHeight + pageSpacing) - pageSpacing
        let contentSize = CGSize(
            width: pageLayout.pageRect.width,
            height: max(totalHeight, pageHeight) // At least one page height
        )
        
        let calculationTime = Date().timeIntervalSince(startTime)
        
        let result = LayoutResult(
            totalPages: pageInfos.count,
            pageInfos: pageInfos,
            contentSize: contentSize,
            calculationTime: calculationTime
        )
        
        self.layoutResult = result
        self.isLayoutValid = true
        
        return result
    }
    
    /// Invalidate the current layout (call when text or page setup changes)
    func invalidateLayout() {
        isLayoutValid = false
        layoutResult = nil
    }
    
    /// Update page setup and invalidate layout
    /// - Parameter pageSetup: New page setup configuration
    func updatePageSetup(_ pageSetup: PageSetup) {
        self.pageSetup = pageSetup
        invalidateLayout()
    }
    
    // MARK: - Text Range Mapping
    
    /// Get the page index containing a given character position
    /// - Parameter characterIndex: Character position in the document
    /// - Returns: Zero-based page index, or nil if layout not calculated
    func pageIndex(forCharacterAt characterIndex: Int) -> Int? {
        guard let result = layoutResult else { return nil }
        guard characterIndex >= 0 && characterIndex <= textStorage.length else { return nil }
        
        // Find the page containing this character
        for pageInfo in result.pageInfos {
            if NSLocationInRange(characterIndex, pageInfo.characterRange) {
                return pageInfo.pageIndex
            }
        }
        
        // If character is at the very end, return last page
        if characterIndex == textStorage.length && !result.pageInfos.isEmpty {
            return result.pageInfos.count - 1
        }
        
        return nil
    }
    
    /// Get the character range for a given page
    /// - Parameter pageIndex: Zero-based page index
    /// - Returns: Character range for that page, or nil if invalid
    func characterRange(forPage pageIndex: Int) -> NSRange? {
        guard let result = layoutResult else { return nil }
        guard pageIndex >= 0 && pageIndex < result.pageInfos.count else { return nil }
        
        return result.pageInfos[pageIndex].characterRange
    }
    
    /// Get the glyph range for a given page
    /// - Parameter pageIndex: Zero-based page index
    /// - Returns: Glyph range for that page, or nil if invalid
    func glyphRange(forPage pageIndex: Int) -> NSRange? {
        guard let result = layoutResult else { return nil }
        guard pageIndex >= 0 && pageIndex < result.pageInfos.count else { return nil }
        
        return result.pageInfos[pageIndex].glyphRange
    }
    
    /// Get page information for a given page
    /// - Parameter pageIndex: Zero-based page index
    /// - Returns: Page info, or nil if invalid
    func pageInfo(forPage pageIndex: Int) -> PageInfo? {
        guard let result = layoutResult else { return nil }
        guard pageIndex >= 0 && pageIndex < result.pageInfos.count else { return nil }
        
        return result.pageInfos[pageIndex]
    }
    
    // MARK: - Convenience Properties
    
    /// Total number of pages (0 if layout not calculated)
    var pageCount: Int {
        return layoutResult?.totalPages ?? 0
    }
    
    /// Total content size for scroll view (zero if layout not calculated)
    var contentSize: CGSize {
        return layoutResult?.contentSize ?? .zero
    }
    
    /// Time taken for last layout calculation
    var lastCalculationTime: TimeInterval? {
        return layoutResult?.calculationTime
    }
    
    // MARK: - Footnote Support
    
    /// Get all footnotes that appear on a specific page
    /// - Parameters:
    ///   - pageNumber: Zero-based page index
    ///   - version: The version to get footnotes for
    ///   - context: SwiftData model context
    /// - Returns: Array of footnotes appearing on this page, sorted by position
    func getFootnotesForPage(_ pageNumber: Int, version: Version, context: ModelContext) -> [FootnoteModel] {
        // Get text range for this page
        guard let textRange = characterRange(forPage: pageNumber) else {
            return []
        }
        
        // Get all active footnotes for version
        let allFootnotes = FootnoteManager.shared.getActiveFootnotes(forVersion: version, context: context)
        
        // Filter to footnotes within this page's text range
        return allFootnotes.filter { footnote in
            NSLocationInRange(footnote.characterPosition, textRange)
        }
    }
    
    /// Calculate the height needed to display footnotes on a page
    /// - Parameters:
    ///   - footnotes: Array of footnotes to display
    ///   - pageWidth: Width of the page content area
    /// - Returns: Total height needed in points
    func calculateFootnoteHeight(for footnotes: [FootnoteModel], pageWidth: CGFloat) -> CGFloat {
        guard !footnotes.isEmpty else { return 0 }
        
        // Separator line (1.5 inches = 108pt) + 10pt spacing above and below
        let separatorHeight: CGFloat = 30
        
        // Calculate height for each footnote
        let footnoteTextHeight = footnotes.reduce(0) { total, footnote in
            let textHeight = estimateTextHeight(footnote.text, width: pageWidth - 20) // Account for number spacing
            return total + textHeight + 4 // 4pt spacing between footnotes
        }
        
        return separatorHeight + footnoteTextHeight
    }
    
    /// Estimate the height needed to render text at a given width
    /// - Parameters:
    ///   - text: The text to measure
    ///   - width: Available width
    /// - Returns: Estimated height in points
    private func estimateTextHeight(_ text: String, width: CGFloat) -> CGFloat {
        // Default to 10pt if no stylesheet available
        let font = UIFont.systemFont(ofSize: 10)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font
        ]
        
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let boundingRect = attributedText.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        
        return ceil(boundingRect.height)
    }
    
    /// Get the content area for a page, adjusted for footnotes if present
    /// - Parameters:
    ///   - pageNumber: Zero-based page index
    ///   - version: The version to check for footnotes
    ///   - context: SwiftData model context
    /// - Returns: Content rect adjusted for footnote space, or nil if page invalid
    func getContentArea(forPage pageNumber: Int, version: Version, context: ModelContext) -> CGRect? {
        // Validate page number
        guard pageNumber >= 0 && pageNumber < pageCount else {
            return nil
        }
        
        // Get base content area from page layout
        let pageLayout = PageLayoutCalculator.calculateLayout(from: pageSetup)
        var contentArea = pageLayout.contentRect
        
        // Get footnotes for this page
        let footnotes = getFootnotesForPage(pageNumber, version: version, context: context)
        
        if footnotes.isEmpty {
            return contentArea
        }
        
        // Calculate space needed for footnotes
        let footnoteHeight = calculateFootnoteHeight(for: footnotes, pageWidth: contentArea.width)
        
        // Reduce content area height to make room for footnotes
        // Add 20pt buffer between body text and footnotes
        contentArea.size.height = max(0, contentArea.size.height - footnoteHeight - 20)
        
        return contentArea
    }
    
    // MARK: - Private Methods
    
    @objc private func textStorageDidChange(_ notification: Notification) {
        invalidateLayout()
    }
}

// MARK: - Debug Extension

extension PaginatedTextLayoutManager {
    /// Debug description of the layout state
    var debugDescription: String {
        guard let result = layoutResult else {
            return "PaginatedTextLayoutManager: No layout calculated"
        }
        
        var description = """
        PaginatedTextLayoutManager:
        - Total Pages: \(result.totalPages)
        - Content Size: \(result.contentSize.width) x \(result.contentSize.height) pts
        - Calculation Time: \(String(format: "%.2f", result.calculationTime * 1000))ms
        - Layout Valid: \(isLayoutValid)
        - Text Length: \(textStorage.length) characters
        
        """
        
        // Add first few pages info
        let pagesToShow = min(3, result.pageInfos.count)
        for i in 0..<pagesToShow {
            let info = result.pageInfos[i]
            description += """
            Page \(i):
              - Characters: \(info.characterRange.location)-\(NSMaxRange(info.characterRange))
              - Glyphs: \(info.glyphRange.location)-\(NSMaxRange(info.glyphRange))
              - Used Rect: \(info.usedRect.size.width) x \(info.usedRect.size.height) pts
            
            """
        }
        
        if result.pageInfos.count > pagesToShow {
            description += "... and \(result.pageInfos.count - pagesToShow) more pages\n"
        }
        
        return description
    }
}
