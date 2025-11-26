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
    
    /// Calculate the complete page layout with footnote-aware pagination
    /// This method performs iterative layout calculation to ensure footnotes fit properly
    /// - Parameters:
    ///   - version: Optional version to check for footnotes during layout
    ///   - context: Optional model context for footnote queries
    /// - Returns: Layout result with page count and page information
    @discardableResult
    func calculateLayout(version: Version? = nil, context: ModelContext? = nil) -> LayoutResult {
        let startTime = Date()
        
        // Get page layout from calculator
        let pageLayout = PageLayoutCalculator.calculateLayout(from: pageSetup)
        let baseContainerSize = pageLayout.contentRect.size
        
        // If no version/context provided, use simple layout (no footnote adjustment)
        if version == nil || context == nil {
            #if DEBUG
            print("🔧 Using SIMPLE layout (no version/context)")
            #endif
            return calculateSimpleLayout(containerSize: baseContainerSize, pageLayout: pageLayout, startTime: startTime)
        }
        
        #if DEBUG
        print("🔧 Using FOOTNOTE-AWARE layout with version: \(version!.id.uuidString.prefix(8))")
        print("   📏 Base container size: \(baseContainerSize.width) x \(baseContainerSize.height)")
        #endif
        
        // Footnote-aware layout: iteratively adjust for footnote space
        return calculateFootnoteAwareLayout(
            containerSize: baseContainerSize,
            pageLayout: pageLayout,
            version: version!,
            context: context!,
            startTime: startTime
        )
    }
    
    /// Simple layout calculation without footnote adjustment
    private func calculateSimpleLayout(containerSize: CGSize, pageLayout: PageLayoutCalculator.PageLayout, startTime: Date) -> LayoutResult {
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
    
    /// Footnote-aware layout calculation with iterative convergence
    /// Iterates until page breaks stabilize with footnote space reservation
    private func calculateFootnoteAwareLayout(
        containerSize: CGSize,
        pageLayout: PageLayoutCalculator.PageLayout,
        version: Version,
        context: ModelContext,
        startTime: Date
    ) -> LayoutResult {
        // Get all footnotes for this version
        let allFootnotes = FootnoteManager.shared.getActiveFootnotes(forVersion: version, context: context)
        let maxIterations = 5  // Prevent infinite loops
        
        var currentPageInfos: [PageInfo] = []
        var previousPageRanges: [NSRange] = []
        var footnotesPerPage: [[FootnoteModel]] = []  // Track footnotes for each page
        var iteration = 0
        var hasConverged = false
        
        while !hasConverged && iteration < maxIterations {
            iteration += 1
            #if DEBUG
            print("🔄 Footnote layout iteration \(iteration)")
            #endif
            
            // Calculate pagination with current footnote assignments
            var pageInfos: [PageInfo] = []
            var characterIndex = 0
            let totalCharacters = textStorage.length
            var newFootnotesPerPage: [[FootnoteModel]] = []
            
            while characterIndex < totalCharacters || pageInfos.isEmpty {
                let pageIndex = pageInfos.count
                
                // For iteration 1, assume no footnotes (full height)
                // For iterations 2+, check if previous iteration found footnotes on this page
                let footnotesOnPreviousPage: [FootnoteModel]
                if iteration == 1 || pageIndex >= currentPageInfos.count {
                    footnotesOnPreviousPage = []
                } else {
                    let previousPageRange = currentPageInfos[pageIndex].characterRange
                    footnotesOnPreviousPage = allFootnotes.filter { footnote in
                        NSLocationInRange(footnote.characterPosition, previousPageRange)
                    }
                }
                
                // Calculate actual footnote height for this page
                let footnoteHeight: CGFloat
                if !footnotesOnPreviousPage.isEmpty {
                    footnoteHeight = calculateFootnoteHeight(for: footnotesOnPreviousPage, pageWidth: containerSize.width)
                    #if DEBUG
                    print("   📏 Page \(pageIndex): \(footnotesOnPreviousPage.count) footnotes need \(footnoteHeight)pt")
                    #endif
                } else {
                    footnoteHeight = 0
                }
                
                // Determine container size based on actual footnote height
                let pageContainerSize: CGSize
                if footnoteHeight > 0 {
                    pageContainerSize = CGSize(
                        width: containerSize.width,
                        height: containerSize.height - footnoteHeight
                    )
                    #if DEBUG
                    print("   📐 Container adjusted: \(containerSize.height)pt - \(footnoteHeight)pt = \(pageContainerSize.height)pt")
                    #endif
                } else {
                    pageContainerSize = containerSize
                }
                
                // Create container for this page
                let container = NSTextContainer(size: pageContainerSize)
                container.lineFragmentPadding = 0
                layoutManager.addTextContainer(container)
                
                let glyphRange = layoutManager.glyphRange(for: container)
                let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
                let usedRect = layoutManager.usedRect(for: container)
                
                let pageInfo = PageInfo(
                    pageIndex: pageIndex,
                    glyphRange: glyphRange,
                    characterRange: characterRange,
                    usedRect: usedRect
                )
                pageInfos.append(pageInfo)
                
                characterIndex = NSMaxRange(characterRange)
                
                if characterIndex >= totalCharacters || characterRange.length == 0 {
                    break
                }
            }
            
            // Remove temporary containers
            while !layoutManager.textContainers.isEmpty {
                layoutManager.removeTextContainer(at: 0)
            }
            
            // Check if page ranges have stabilized (converged)
            let currentRanges = pageInfos.map { $0.characterRange }
            if iteration > 1 && currentRanges == previousPageRanges {
                hasConverged = true
                #if DEBUG
                print("✅ Footnote layout converged after \(iteration) iterations")
                #endif
            }
            
            currentPageInfos = pageInfos
            previousPageRanges = currentRanges
        }
        
        if !hasConverged {
            #if DEBUG
            print("⚠️ Footnote layout did not converge after \(maxIterations) iterations, using last result")
            #endif
        }
        
        // Now add final containers based on converged page ranges with actual footnote heights
        var finalPageInfos: [PageInfo] = []
        for (pageIndex, pageInfo) in currentPageInfos.enumerated() {
            // Check if THIS page has footnotes in the converged layout
            let footnotesOnPage = allFootnotes.filter { footnote in
                NSLocationInRange(footnote.characterPosition, pageInfo.characterRange)
            }
            
            // Calculate actual footnote height for final container
            let footnoteHeight: CGFloat
            if !footnotesOnPage.isEmpty {
                footnoteHeight = calculateFootnoteHeight(for: footnotesOnPage, pageWidth: containerSize.width)
            } else {
                footnoteHeight = 0
            }
            
            let pageContainerSize: CGSize
            if footnoteHeight > 0 {
                pageContainerSize = CGSize(
                    width: containerSize.width,
                    height: containerSize.height - footnoteHeight
                )
                #if DEBUG
                print("📐 Final: Page \(pageIndex) has \(footnotesOnPage.count) footnotes, reserved \(footnoteHeight)pt")
                #endif
            } else {
                pageContainerSize = containerSize
                #if DEBUG
                print("📐 Final: Page \(pageIndex) has no footnotes, full height")
                #endif
            }
            
            let container = NSTextContainer(size: pageContainerSize)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            
            finalPageInfos.append(pageInfo)
        }
        
        // Ensure at least one page
        if finalPageInfos.isEmpty {
            let emptyPageInfo = PageInfo(
                pageIndex: 0,
                glyphRange: NSRange(location: 0, length: 0),
                characterRange: NSRange(location: 0, length: 0),
                usedRect: .zero
            )
            finalPageInfos.append(emptyPageInfo)
            
            let container = NSTextContainer(size: containerSize)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
        }
        
        // Calculate total content size
        let pageHeight = pageLayout.pageRect.height
        let totalHeight = CGFloat(finalPageInfos.count) * (pageHeight + pageSpacing) - pageSpacing
        let contentSize = CGSize(
            width: pageLayout.pageRect.width,
            height: max(totalHeight, pageHeight)
        )
        
        let calculationTime = Date().timeIntervalSince(startTime)
        
        let result = LayoutResult(
            totalPages: finalPageInfos.count,
            pageInfos: finalPageInfos,
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
