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

    private struct FootnoteInfo {
        let footnote: FootnoteModel
        let actualPosition: Int
    }

    private struct AssembledFootnoteInfo {
        let footnote: ManuscriptFootnote
        let actualPosition: Int
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
    
    /// Whether the current layout is valid (at least some pages calculated)
    private(set) var isLayoutValid: Bool = false
    
    /// Whether layout calculation is complete (all pages calculated)
    private(set) var isLayoutComplete: Bool = false
    
    /// Whether layout calculation is currently in progress
    private(set) var isCalculating: Bool = false
    
    /// Page spacing between pages in scroll view
    let pageSpacing: CGFloat = 20.0
    
    /// Estimated total page count (used before calculation completes)
    var estimatedPageCount: Int {
        guard textStorage.length > 0 else { return 1 }
        let pageLayout = PageLayoutCalculator.calculateLayout(from: pageSetup)
        let charsPerPage = estimateCharactersPerPage(containerSize: pageLayout.contentRect.size)
        return max(1, Int(ceil(Double(textStorage.length) / Double(charsPerPage))))
    }
    
    /// Estimate characters per page based on container size and average character width
    private func estimateCharactersPerPage(containerSize: CGSize) -> Int {
        // Rough estimate: average 60 chars per line, lines based on 14pt line height
        let avgCharsPerLine = 60
        let lineHeight: CGFloat = 20  // Approximate line height
        let linesPerPage = Int(containerSize.height / lineHeight)
        return max(100, avgCharsPerLine * linesPerPage)
    }
    
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
    func calculateLayout(version: Version? = nil, context: ModelContext? = nil, layoutProgress: ((Int, Int) -> Void)? = nil) -> LayoutResult {
        let startTime = Date()
        
        // Get page layout from calculator
        let pageLayout = PageLayoutCalculator.calculateLayout(from: pageSetup)
        let baseContainerSize = pageLayout.contentRect.size
        
        // If no version/context provided, use simple layout (no footnote adjustment)
        if version == nil || context == nil {
            #if DEBUG
            print("🔧 Using SIMPLE layout (no version/context)")
            #endif
            return calculateSimpleLayout(containerSize: baseContainerSize, pageLayout: pageLayout, startTime: startTime, layoutProgress: layoutProgress)
        }
        
        #if DEBUG
        print("🔧 Using FOOTNOTE-AWARE layout with version: \(version!.id.uuidString.prefix(8))")
        #if DEBUG
        print("   📏 Base container size: \(baseContainerSize.width) x \(baseContainerSize.height)")
        #endif
        #endif
        
        // Footnote-aware layout: iteratively adjust for footnote space
        return calculateFootnoteAwareLayout(
            containerSize: baseContainerSize,
            pageLayout: pageLayout,
            version: version!,
            context: context!,
            startTime: startTime,
            layoutProgress: layoutProgress
        )
    }
    
    /// Calculate layout with manuscript assembled footnotes (no Version needed)
    func calculateLayout(assembledFootnotes: [ManuscriptFootnote], layoutProgress: ((Int, Int) -> Void)? = nil) -> LayoutResult {
        let startTime = Date()
        let pageLayout = PageLayoutCalculator.calculateLayout(from: pageSetup)
        let baseContainerSize = pageLayout.contentRect.size
        
        if assembledFootnotes.isEmpty {
            #if DEBUG
            print("🔧 Using SIMPLE layout (no assembled footnotes)")
            #endif
            return calculateSimpleLayout(containerSize: baseContainerSize, pageLayout: pageLayout, startTime: startTime, layoutProgress: layoutProgress)
        }
        
        #if DEBUG
        print("🔧 Using FOOTNOTE-AWARE layout with \(assembledFootnotes.count) assembled footnotes")
        #endif
        
        return calculateAssembledFootnoteLayout(
            containerSize: baseContainerSize,
            pageLayout: pageLayout,
            assembledFootnotes: assembledFootnotes,
            startTime: startTime,
            layoutProgress: layoutProgress
        )
    }
    
    /// Footnote-aware layout using assembled manuscript footnotes instead of Version/Context
    private func calculateAssembledFootnoteLayout(
        containerSize: CGSize,
        pageLayout: PageLayoutCalculator.PageLayout,
        assembledFootnotes: [ManuscriptFootnote],
        startTime: Date,
        layoutProgress: ((Int, Int) -> Void)? = nil
    ) -> LayoutResult {
        let estimatedPages = estimatedPageCount
        let pageHeight = pageLayout.pageRect.height
        updateInitialEstimatedLayout(estimatedPages: estimatedPages, pageLayout: pageLayout, pageHeight: pageHeight)
        
        let maxFootnoteSpace = containerSize.height * 0.5
        let totalCharacters = textStorage.length
        let maxIterations = 5
        let footnotesWithPositions = buildAssembledFootnoteInfos(from: assembledFootnotes)
        
        #if DEBUG
        print("📐 Starting manuscript footnote-aware pagination for \(totalCharacters) chars, \(footnotesWithPositions.count) footnotes")
        #endif
        
        while !layoutManager.textContainers.isEmpty {
            layoutManager.removeTextContainer(at: 0)
        }
        
        var pageInfos: [PageInfo] = []
        var pageIndex = 0
        
        while pageIndex < 1000 {
            guard let pageInfo = assembledPageInfo(
                pageIndex: pageIndex,
                containerSize: containerSize,
                footnotesWithPositions: footnotesWithPositions,
                maxFootnoteSpace: maxFootnoteSpace,
                maxIterations: maxIterations
            ) else {
                break
            }

            pageInfos.append(pageInfo)
            
            if let progress = layoutProgress, pageInfos.count % 5 == 0 {
                let charsProcessed = pageInfos.last.map { NSMaxRange($0.characterRange) } ?? 0
                let runningEstimate = runningPageEstimate(
                    pageCount: pageInfos.count,
                    charsProcessed: charsProcessed,
                    totalCharacters: totalCharacters,
                    estimatedPages: estimatedPages
                )
                progress(pageInfos.count, runningEstimate)
            }
            
            if let lastPageInfo = pageInfos.last, NSMaxRange(lastPageInfo.characterRange) >= totalCharacters {
                break
            }
            if pageInfos.count <= pageIndex { break }
            pageIndex += 1
        }
        
        if pageInfos.isEmpty {
            pageInfos.append(PageInfo(
                pageIndex: 0,
                glyphRange: NSRange(location: 0, length: 0),
                characterRange: NSRange(location: 0, length: 0),
                usedRect: .zero
            ))
            let container = NSTextContainer(size: containerSize)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
        }
        
        let currentPageInfos = pageInfos
        
        while !layoutManager.textContainers.isEmpty {
            layoutManager.removeTextContainer(at: 0)
        }
        
        var finalPageInfos: [PageInfo] = []
        
        for pageInfo in currentPageInfos {
            let footnoteHeight = assembledFootnoteHeight(
                for: pageInfo.characterRange,
                footnotesWithPositions: footnotesWithPositions,
                pageWidth: containerSize.width,
                maxFootnoteSpace: maxFootnoteSpace
            )
            
            let pageContainerSize = footnoteHeight > 0
                ? CGSize(width: containerSize.width, height: containerSize.height - footnoteHeight)
                : containerSize
            
            let container = NSTextContainer(size: pageContainerSize)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            
            finalPageInfos.append(pageInfo)
        }
        
        if finalPageInfos.isEmpty {
            finalPageInfos.append(PageInfo(
                pageIndex: 0,
                glyphRange: NSRange(location: 0, length: 0),
                characterRange: NSRange(location: 0, length: 0),
                usedRect: .zero
            ))
            let container = NSTextContainer(size: containerSize)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
        }
        
        let contentSize = finalContentSize(pageCount: finalPageInfos.count, pageLayout: pageLayout, pageHeight: pageHeight)
        
        let calculationTime = Date().timeIntervalSince(startTime)
        let result = LayoutResult(
            totalPages: finalPageInfos.count,
            pageInfos: finalPageInfos,
            contentSize: contentSize,
            calculationTime: calculationTime
        )
        
        DispatchQueue.main.async {
            self.layoutResult = result
            self.isLayoutValid = true
            self.isLayoutComplete = true
            self.isCalculating = false
        }
        
        return result
    }

    private func buildAssembledFootnoteInfos(from assembledFootnotes: [ManuscriptFootnote]) -> [AssembledFootnoteInfo] {
        let actualPositions = actualFootnoteAttachmentPositions()
        return assembledFootnotes.compactMap { footnote in
            if let actualPos = actualPositions[footnote.attachmentID] {
                return AssembledFootnoteInfo(footnote: footnote, actualPosition: actualPos)
            }
            return AssembledFootnoteInfo(footnote: footnote, actualPosition: footnote.characterPosition)
        }
        .sorted { $0.actualPosition < $1.actualPosition }
    }

    private func assembledPageInfo(
        pageIndex: Int,
        containerSize: CGSize,
        footnotesWithPositions: [AssembledFootnoteInfo],
        maxFootnoteSpace: CGFloat,
        maxIterations: Int
    ) -> PageInfo? {
        var reservedFootnoteSpace: CGFloat = 0
        var previousFootnoteCount = -1

        for _ in 0..<maxIterations {
            let textHeight = containerSize.height - reservedFootnoteSpace
            if textHeight < 50 { break }

            while layoutManager.textContainers.count > pageIndex {
                layoutManager.removeTextContainer(at: pageIndex)
            }

            let pageContainerSize = CGSize(width: containerSize.width, height: textHeight)
            let container = NSTextContainer(size: pageContainerSize)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            layoutManager.ensureLayout(for: container)

            let glyphRange = layoutManager.glyphRange(for: container)
            if glyphRange.length == 0 {
                layoutManager.removeTextContainer(at: pageIndex)
                return nil
            }

            let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let footnoteHeight = assembledFootnoteHeight(
                for: charRange,
                footnotesWithPositions: footnotesWithPositions,
                pageWidth: containerSize.width,
                maxFootnoteSpace: maxFootnoteSpace
            )

            let footnoteCount = footnotesWithPositions.filter { fnInfo in
                NSLocationInRange(fnInfo.actualPosition, charRange)
            }.count

            if footnoteCount == previousFootnoteCount && abs(footnoteHeight - reservedFootnoteSpace) < 1 {
                let usedRect = layoutManager.usedRect(for: container)
                return PageInfo(
                    pageIndex: pageIndex,
                    glyphRange: glyphRange,
                    characterRange: charRange,
                    usedRect: usedRect
                )
            }

            previousFootnoteCount = footnoteCount
            reservedFootnoteSpace = footnoteHeight
        }

        if layoutManager.textContainers.count > pageIndex {
            let container = layoutManager.textContainers[pageIndex]
            let glyphRange = layoutManager.glyphRange(for: container)
            let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let usedRect = layoutManager.usedRect(for: container)
            if glyphRange.length > 0 {
                return PageInfo(
                    pageIndex: pageIndex,
                    glyphRange: glyphRange,
                    characterRange: charRange,
                    usedRect: usedRect
                )
            }
        }

        return nil
    }

    private func assembledFootnoteHeight(
        for charRange: NSRange,
        footnotesWithPositions: [AssembledFootnoteInfo],
        pageWidth: CGFloat,
        maxFootnoteSpace: CGFloat
    ) -> CGFloat {
        let footnotesOnPage = footnotesWithPositions.filter { fnInfo in
            NSLocationInRange(fnInfo.actualPosition, charRange)
        }

        guard !footnotesOnPage.isEmpty else { return 0 }
        let models = footnotesOnPage.map { $0.footnote }
        let rawHeight = calculateFootnoteHeight(for: models, pageWidth: pageWidth)
        return min(rawHeight, maxFootnoteSpace)
    }
    
    /// Simple layout calculation without footnote adjustment
    private func calculateSimpleLayout(containerSize: CGSize, pageLayout: PageLayoutCalculator.PageLayout, startTime: Date, layoutProgress: ((Int, Int) -> Void)? = nil) -> LayoutResult {
        #if DEBUG
        print("📄 Pagination Layout Setup:")
        print("   - Container size: \(containerSize.width) x \(containerSize.height)")
        print("   - lineFragmentPadding: 0")
        #endif
        
        // Mark as calculating and create initial estimated layout
        let estimatedPages = self.estimatedPageCount
        let pageHeight = pageLayout.pageRect.height
        let estimatedHeight = CGFloat(estimatedPages) * (pageHeight + pageSpacing) - pageSpacing
        let estimatedContentSize = CGSize(width: pageLayout.pageRect.width, height: max(estimatedHeight, pageHeight))
        
        DispatchQueue.main.async {
            self.isCalculating = true
            self.isLayoutComplete = false
            // Create initial layout so view can display immediately
            self.layoutResult = LayoutResult(
                totalPages: estimatedPages,
                pageInfos: [],
                contentSize: estimatedContentSize,
                calculationTime: 0
            )
            self.isLayoutValid = true
        }
        
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
            var glyphRange = layoutManager.glyphRange(for: container)
            
            // Convert to character range
            var characterRange = layoutManager.characterRange(
                forGlyphRange: glyphRange,
                actualGlyphRange: nil
            )
            
            // Check for form feed character (\u{000C}) in this range
            // If found, truncate the page at that point and start next page after it
            let pageText = (textStorage.string as NSString).substring(with: characterRange)
            var foundFormFeed = false
            if let formFeedIndex = pageText.firstIndex(of: "\u{000C}") {
                foundFormFeed = true
                let offsetInPage = pageText.distance(from: pageText.startIndex, to: formFeedIndex)
                let formFeedLocation = characterRange.location + offsetInPage
                
                // Truncate character range to end at the form feed
                characterRange = NSRange(location: characterRange.location, length: offsetInPage)
                
                // Convert back to glyph range
                glyphRange = layoutManager.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
                
                // Set characterIndex to skip past the form feed for next iteration
                characterIndex = formFeedLocation + 1
                
                #if DEBUG
                print("   📄 Page break found at character \(formFeedLocation), ending page \(pageIndex)")
                #endif
            }
            
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
            
            // Report layout progress every 5 pages (throttle to avoid flooding main actor).
            // Uses a running estimate based on characters processed — the initial estimate
            // assumes prose, but poetry with page breaks produces far more pages.
            if let progress = layoutProgress, pageInfos.count % 5 == 0 {
                let charsProcessed = max(characterIndex, NSMaxRange(characterRange))
                let runningEstimate: Int
                if charsProcessed > 0 && charsProcessed < totalCharacters {
                    runningEstimate = max(estimatedPages, Int(ceil(Double(pageInfos.count) * Double(totalCharacters) / Double(charsProcessed))))
                } else {
                    runningEstimate = max(estimatedPages, pageInfos.count)
                }
                progress(pageInfos.count, runningEstimate)
            }
            
            // Periodically update layoutResult so pages can be displayed incrementally
            // Update after first page, every 5 pages initially, then every 10 pages
            // Do this BEFORE break checks so first page is always published
            if pageInfos.count == 1 || pageInfos.count <= 5 || pageInfos.count % 10 == 0 {
                let currentHeight = CGFloat(pageInfos.count) * (pageLayout.pageRect.height + pageSpacing) - pageSpacing
                let currentContentSize = CGSize(
                    width: pageLayout.pageRect.width,
                    height: max(currentHeight, estimatedHeight)
                )
                let intermediateResult = LayoutResult(
                    totalPages: max(pageInfos.count, estimatedPages),
                    pageInfos: pageInfos,
                    contentSize: currentContentSize,
                    calculationTime: Date().timeIntervalSince(startTime)
                )
                DispatchQueue.main.async {
                    self.layoutResult = intermediateResult
                }
            }
            
            // Move to next page
            // If we found a form feed, characterIndex was already set to skip past it
            if !foundFormFeed {
                if characterRange.length > 0 {
                    let nextChar = NSMaxRange(characterRange)
                    if nextChar < totalCharacters {
                        let nextCharString = (textStorage.string as NSString).substring(with: NSRange(location: nextChar, length: 1))
                        if nextCharString == "\u{000C}" {
                            characterIndex = nextChar + 1  // Skip the form feed character
                            #if DEBUG
                            print("   ⏭️  Skipping form feed character at \(nextChar)")
                            #endif
                        } else {
                            characterIndex = nextChar
                        }
                    } else {
                        characterIndex = nextChar
                    }
                } else {
                    characterIndex = NSMaxRange(characterRange)
                }
            }
            
            // If we've processed all text, we're done
            if characterIndex >= totalCharacters {
                break
            }
            
            // Safety check: if no characters were processed AND we didn't skip a form feed, break to avoid infinite loop
            if characterRange.length == 0 && !foundFormFeed {
                #if DEBUG
                print("   ⚠️ Zero-length page with no form feed detected, breaking to avoid infinite loop")
                #endif
                break
            }
        }
        
        // Remove the temporary containers (we only needed them for calculation)
        let containers = layoutManager.textContainers
        for _ in containers {
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
        
        // Update on main thread to ensure UI sees the final result
        DispatchQueue.main.async {
            self.layoutResult = result
            self.isLayoutValid = true
            self.isLayoutComplete = true
            self.isCalculating = false
        }
        
        return result
    }
    
    /// Footnote-aware layout calculation with iterative convergence
    /// Iterates until page breaks stabilize with footnote space reservation
    private func calculateFootnoteAwareLayout(
        containerSize: CGSize,
        pageLayout: PageLayoutCalculator.PageLayout,
        version: Version,
        context: ModelContext,
        startTime: Date,
        layoutProgress: ((Int, Int) -> Void)? = nil
    ) -> LayoutResult {
        let estimatedPages = estimatedPageCount
        let pageHeight = pageLayout.pageRect.height
        updateInitialEstimatedLayout(estimatedPages: estimatedPages, pageLayout: pageLayout, pageHeight: pageHeight)
        
        // Get footnotes anchored in the text. Relationship-based lookups can lag behind
        // newly inserted markers, so fall back to attachmentID for markers in textStorage.
        let allFootnotes = getAnchoredFootnotes(forVersion: version, context: context)
        let maxFootnoteSpace = containerSize.height * 0.5  // Max half page for footnotes
        let totalCharacters = textStorage.length
        let maxPagesPerFootnoteIteration = 5  // Max iterations per page for footnote space
        
        let footnotesWithActualPositions = buildFootnotesWithActualPositions(from: allFootnotes)
        
        // TeX-like algorithm: Build pages SEQUENTIALLY in a single layout pass
        // Each page's container stays in the layout manager as we build the next
        // This ensures text flows correctly from page to page
        
        #if DEBUG
        print("📐 Starting TeX-like sequential pagination for \(totalCharacters) characters")
        print("   Container size: \(containerSize.width) x \(containerSize.height)")
        print("   Total footnotes: \(allFootnotes.count)")
        for fnInfo in footnotesWithActualPositions {
            let storedPos = fnInfo.footnote.characterPosition
            let actualPos = fnInfo.actualPosition
            if storedPos != actualPos {
                print("   📝 Footnote #\(fnInfo.footnote.number) at ACTUAL position \(actualPos) (stored: \(storedPos) - MISMATCH!)")
            } else {
                print("   📝 Footnote #\(fnInfo.footnote.number) at char position \(actualPos)")
            }
        }
        #endif
        
        // Clear any existing containers
        while !layoutManager.textContainers.isEmpty {
            layoutManager.removeTextContainer(at: 0)
        }
        
        var pageInfos: [PageInfo] = []
        var pageIndex = 0
        
        while pageIndex < 1000 {
            // Calculate footnote space needed for THIS page
            // We need to iterate because footnote space affects which text fits,
            // which affects which footnotes appear
            
            var reservedFootnoteSpace: CGFloat = 0
            var converged = false
            var previousFootnoteCount = -1
            var oscillationDetected = false
            var oscillatingFootnotePosition: Int = Int.max  // Position of the footnote that gets pushed in/out
            
            for fnIteration in 0..<maxPagesPerFootnoteIteration {
                // Calculate available text height
                let textHeight = containerSize.height - reservedFootnoteSpace
                if textHeight < 50 {
                    // Not enough space for meaningful text
                    #if DEBUG
                    print("   ⚠️ Page \(pageIndex): Not enough text space (\(textHeight)pt)")
                    #endif
                    break
                }
                
                // Remove previous test container for this page if exists
                while layoutManager.textContainers.count > pageIndex {
                    layoutManager.removeTextContainer(at: pageIndex)
                }
                
                // Add container for this page with current reserved space
                let pageContainerSize = CGSize(width: containerSize.width, height: textHeight)
                let container = NSTextContainer(size: pageContainerSize)
                container.lineFragmentPadding = 0
                layoutManager.addTextContainer(container)
                layoutManager.ensureLayout(for: container)
                
                let glyphRange = layoutManager.glyphRange(for: container)
                if glyphRange.length == 0 {
                    // No more text
                    layoutManager.removeTextContainer(at: pageIndex)
                    converged = true
                    break
                }
                
                let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
                
                // Find footnotes in this character range using ACTUAL positions from text
                let footnotesOnPage = footnotesWithActualPositions.filter { fnInfo in
                    NSLocationInRange(fnInfo.actualPosition, charRange)
                }
                
                // Calculate actual footnote space needed
                var neededSpace: CGFloat = 0
                if !footnotesOnPage.isEmpty {
                    let footnoteModels = footnotesOnPage.map { $0.footnote }
                    neededSpace = calculateFootnoteHeight(for: footnoteModels, pageWidth: containerSize.width)
                    neededSpace = min(neededSpace, maxFootnoteSpace)
                }
                
                #if DEBUG
                if fnIteration > 0 || neededSpace > 0 {
                    print("     Page \(pageIndex) fn-iteration \(fnIteration + 1): chars \(charRange.location)-\(NSMaxRange(charRange)), \(footnotesOnPage.count) footnotes, reserved \(Int(reservedFootnoteSpace))pt, need \(Int(neededSpace))pt")
                }
                #endif
                
                // OSCILLATION DETECTION: If we had more footnotes in a previous iteration
                // but now have fewer (because reserving space pushed some out), record
                // the position of the footnote that got pushed out.
                if previousFootnoteCount >= 0 && footnotesOnPage.count < previousFootnoteCount {
                    oscillationDetected = true
                    
                    // Find the footnote(s) that got pushed out - they're in the full set but not on this page
                    let footnotesNotOnPage = footnotesWithActualPositions.filter { fnInfo in
                        !NSLocationInRange(fnInfo.actualPosition, charRange) && fnInfo.actualPosition > charRange.location
                    }
                    if let firstPushedOut = footnotesNotOnPage.first {
                        oscillatingFootnotePosition = firstPushedOut.actualPosition
                    }
                    
                    #if DEBUG
                    print("     🔄 Oscillation detected: \(previousFootnoteCount) → \(footnotesOnPage.count) footnotes, footnote pushed out at position \(oscillatingFootnotePosition)")
                    #endif
                }
                
                previousFootnoteCount = footnotesOnPage.count
                
                // Check if converged
                if abs(neededSpace - reservedFootnoteSpace) < 1 {
                    converged = true
                    
                    // Store final page info
                    let usedRect = layoutManager.usedRect(for: container)
                    let pageInfo = PageInfo(
                        pageIndex: pageIndex,
                        glyphRange: glyphRange,
                        characterRange: charRange,
                        usedRect: usedRect
                    )
                    pageInfos.append(pageInfo)
                    
                    #if DEBUG
                    print("   📄 Page \(pageIndex): chars \(charRange.location)-\(NSMaxRange(charRange)), \(footnotesOnPage.count) footnotes, text \(Int(usedRect.height))pt + fn \(Int(reservedFootnoteSpace))pt")
                    #endif
                    
                    break
                }
                
                // If oscillation was detected and we're about to go back up in footnotes,
                // force convergence: limit text to exclude the oscillating footnote
                if oscillationDetected && footnotesOnPage.count > previousFootnoteCount - 1 {
                    // We know a footnote at 'oscillatingFootnotePosition' needs to be pushed out
                    // Find the footnotes that should be on this page (positions before the oscillating one)
                    let stableFootnotes = footnotesWithActualPositions.filter { fnInfo in
                        fnInfo.actualPosition < oscillatingFootnotePosition
                    }
                    
                    // Calculate space needed for stable footnotes only
                    let stableNeededSpace: CGFloat
                    if !stableFootnotes.isEmpty {
                        let footnoteModels = stableFootnotes.map { $0.footnote }
                        stableNeededSpace = min(calculateFootnoteHeight(for: footnoteModels, pageWidth: containerSize.width), maxFootnoteSpace)
                    } else {
                        stableNeededSpace = 0
                    }
                    
                    // Re-layout with the stable footnote space
                    while layoutManager.textContainers.count > pageIndex {
                        layoutManager.removeTextContainer(at: pageIndex)
                    }
                    let stableTextHeight = containerSize.height - stableNeededSpace
                    let stableContainer = NSTextContainer(size: CGSize(width: containerSize.width, height: stableTextHeight))
                    stableContainer.lineFragmentPadding = 0
                    layoutManager.addTextContainer(stableContainer)
                    layoutManager.ensureLayout(for: stableContainer)
                    
                    var finalGlyphRange = layoutManager.glyphRange(for: stableContainer)
                    var finalCharRange = layoutManager.characterRange(forGlyphRange: finalGlyphRange, actualGlyphRange: nil)
                    var usedRect = layoutManager.usedRect(for: stableContainer)
                    
                    // CRITICAL: If this range would include the oscillating footnote, we need to
                    // limit what's on this page. We'll shrink the container until the footnote is excluded.
                    if NSMaxRange(finalCharRange) > oscillatingFootnotePosition {
                        // The oscillating footnote is within reach - we need a tighter container
                        // Binary search for the right container height that excludes the footnote
                        var minHeight: CGFloat = 50
                        var maxHeight = stableTextHeight
                        var bestRange = finalCharRange
                        var bestGlyphRange = finalGlyphRange
                        var bestUsedRect = usedRect
                        
                        for _ in 0..<10 {  // Max 10 iterations of binary search
                            let midHeight = (minHeight + maxHeight) / 2
                            
                            while layoutManager.textContainers.count > pageIndex {
                                layoutManager.removeTextContainer(at: pageIndex)
                            }
                            let testContainer = NSTextContainer(size: CGSize(width: containerSize.width, height: midHeight))
                            testContainer.lineFragmentPadding = 0
                            layoutManager.addTextContainer(testContainer)
                            layoutManager.ensureLayout(for: testContainer)
                            
                            let testGlyphRange = layoutManager.glyphRange(for: testContainer)
                            let testCharRange = layoutManager.characterRange(forGlyphRange: testGlyphRange, actualGlyphRange: nil)
                            
                            if NSMaxRange(testCharRange) >= oscillatingFootnotePosition {
                                // Still includes the footnote, need smaller container
                                maxHeight = midHeight
                            } else {
                                // Doesn't include footnote, this is valid - try for larger
                                minHeight = midHeight
                                bestRange = testCharRange
                                bestGlyphRange = testGlyphRange
                                bestUsedRect = layoutManager.usedRect(for: testContainer)
                            }
                            
                            // Close enough?
                            if maxHeight - minHeight < 5 {
                                break
                            }
                        }
                        
                        finalCharRange = bestRange
                        finalGlyphRange = bestGlyphRange
                        usedRect = bestUsedRect
                        
                        // Final container with the right size
                        while layoutManager.textContainers.count > pageIndex {
                            layoutManager.removeTextContainer(at: pageIndex)
                        }
                        let finalContainer = NSTextContainer(size: CGSize(width: containerSize.width, height: minHeight))
                        finalContainer.lineFragmentPadding = 0
                        layoutManager.addTextContainer(finalContainer)
                        layoutManager.ensureLayout(for: finalContainer)
                    }
                    
                    let pageInfo = PageInfo(
                        pageIndex: pageIndex,
                        glyphRange: finalGlyphRange,
                        characterRange: finalCharRange,
                        usedRect: usedRect
                    )
                    pageInfos.append(pageInfo)
                    
                    #if DEBUG
                    print("   📄 Page \(pageIndex) (oscillation resolved): chars \(finalCharRange.location)-\(NSMaxRange(finalCharRange)), \(stableFootnotes.count) footnotes, text \(Int(usedRect.height))pt + fn \(Int(stableNeededSpace))pt")
                    #endif
                    
                    converged = true
                    break
                }
                
                // Update reservation for next iteration
                reservedFootnoteSpace = neededSpace
            }
            
            if !converged {
                // Didn't converge after max iterations - use current state
                #if DEBUG
                print("   ⚠️ Page \(pageIndex) didn't converge, using current state")
                #endif
                
                if layoutManager.textContainers.count > pageIndex {
                    let container = layoutManager.textContainers[pageIndex]
                    let glyphRange = layoutManager.glyphRange(for: container)
                    let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
                    let usedRect = layoutManager.usedRect(for: container)
                    
                    if glyphRange.length > 0 {
                        let pageInfo = PageInfo(
                            pageIndex: pageIndex,
                            glyphRange: glyphRange,
                            characterRange: charRange,
                            usedRect: usedRect
                        )
                        pageInfos.append(pageInfo)
                    }
                }
            }
            
            // Report layout progress every 5 pages (throttle to avoid flooding main actor)
            if let progress = layoutProgress, pageInfos.count % 5 == 0 {
                let charsProcessed = pageInfos.last.map { NSMaxRange($0.characterRange) } ?? 0
                let runningEstimate = runningPageEstimate(
                    pageCount: pageInfos.count,
                    charsProcessed: charsProcessed,
                    totalCharacters: totalCharacters,
                    estimatedPages: estimatedPages
                )
                progress(pageInfos.count, runningEstimate)
            }
            
            // Check if all text has been placed
            if let lastPageInfo = pageInfos.last {
                if NSMaxRange(lastPageInfo.characterRange) >= totalCharacters {
                    break
                }
            }
            
            // Check if we added a page
            if pageInfos.count <= pageIndex {
                // No page was added - we're done or stuck
                break
            }
            
            pageIndex += 1
        }
        
        // Ensure at least one page
        if pageInfos.isEmpty {
            let emptyRange = NSRange(location: 0, length: 0)
            pageInfos.append(PageInfo(
                pageIndex: 0,
                glyphRange: emptyRange,
                characterRange: emptyRange,
                usedRect: .zero
            ))
            
            // Add empty container
            let container = NSTextContainer(size: containerSize)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
        }
        
        #if DEBUG
        print("✅ Pagination complete: \(pageInfos.count) pages")
        #endif
        
        let currentPageInfos = pageInfos
        
        // Remove any temporary containers before creating final ones
        while !layoutManager.textContainers.isEmpty {
            layoutManager.removeTextContainer(at: 0)
        }
        
        // Add final containers based on calculated page ranges with actual footnote heights
        var finalPageInfos: [PageInfo] = []
        
        for (_, pageInfo) in currentPageInfos.enumerated() {
            // Check if THIS page has footnotes in the calculated layout using ACTUAL positions
            let footnotesOnPage = footnotesWithActualPositions.filter { fnInfo in
                NSLocationInRange(fnInfo.actualPosition, pageInfo.characterRange)
            }
            
            // Calculate footnote height - capped to max
            let footnoteHeight: CGFloat
            if !footnotesOnPage.isEmpty {
                let footnoteModels = footnotesOnPage.map { $0.footnote }
                let rawHeight = calculateFootnoteHeight(for: footnoteModels, pageWidth: containerSize.width)
                footnoteHeight = min(rawHeight, maxFootnoteSpace)
            } else {
                footnoteHeight = 0
            }
            
            let pageContainerSize: CGSize
            if footnoteHeight > 0 {
                pageContainerSize = CGSize(
                    width: containerSize.width,
                    height: containerSize.height - footnoteHeight
                )
            } else {
                pageContainerSize = containerSize
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
        
        let contentSize = finalContentSize(pageCount: finalPageInfos.count, pageLayout: pageLayout, pageHeight: pageHeight)
        
        let calculationTime = Date().timeIntervalSince(startTime)
        
        let result = LayoutResult(
            totalPages: finalPageInfos.count,
            pageInfos: finalPageInfos,
            contentSize: contentSize,
            calculationTime: calculationTime
        )
        
        // Update on main thread to ensure UI sees the final result
        DispatchQueue.main.async {
            self.layoutResult = result
            self.isLayoutValid = true
            self.isLayoutComplete = true
            self.isCalculating = false
        }
        
        return result
    }

    private func updateInitialEstimatedLayout(estimatedPages: Int, pageLayout: PageLayoutCalculator.PageLayout, pageHeight: CGFloat) {
        let estimatedHeight = CGFloat(estimatedPages) * (pageHeight + pageSpacing) - pageSpacing
        let estimatedContentSize = CGSize(width: pageLayout.pageRect.width, height: max(estimatedHeight, pageHeight))

        DispatchQueue.main.async {
            self.isCalculating = true
            self.isLayoutComplete = false
            self.layoutResult = LayoutResult(
                totalPages: estimatedPages,
                pageInfos: [],
                contentSize: estimatedContentSize,
                calculationTime: 0
            )
            self.isLayoutValid = true
        }
    }

    private func actualFootnoteAttachmentPositions() -> [UUID: Int] {
        var actualPositions: [UUID: Int] = [:]
        textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: textStorage.length), options: []) { value, range, _ in
            if let footnoteAttachment = value as? FootnoteAttachment {
                actualPositions[footnoteAttachment.footnoteID] = range.location
            }
        }
        return actualPositions
    }

    private func getAnchoredFootnotes(forVersion version: Version, context: ModelContext) -> [FootnoteModel] {
        let actualPositions = actualFootnoteAttachmentPositions()
        let activeFootnotes = FootnoteManager.shared.getActiveFootnotes(forVersion: version, context: context)
        let activeByAttachmentID = Dictionary(activeFootnotes.map { ($0.attachmentID, $0) }, uniquingKeysWith: { first, _ in first })

        return actualPositions.compactMap { attachmentID, _ in
            activeByAttachmentID[attachmentID]
                ?? fetchFootnoteByAttachment(attachmentID: attachmentID, context: context)
        }
        .sorted { lhs, rhs in
            (actualPositions[lhs.attachmentID] ?? lhs.characterPosition) < (actualPositions[rhs.attachmentID] ?? rhs.characterPosition)
        }
    }

    private func fetchFootnoteByAttachment(attachmentID: UUID, context: ModelContext) -> FootnoteModel? {
        let descriptor = FetchDescriptor<FootnoteModel>(
            predicate: #Predicate { footnote in
                footnote.attachmentID == attachmentID
            }
        )

        return try? context.fetch(descriptor).first
    }

    private func buildFootnotesWithActualPositions(from allFootnotes: [FootnoteModel]) -> [FootnoteInfo] {
        let actualPositions = actualFootnoteAttachmentPositions()
        return allFootnotes.compactMap { footnote in
            if let actualPos = actualPositions[footnote.attachmentID] {
                return FootnoteInfo(footnote: footnote, actualPosition: actualPos)
            }

            #if DEBUG
            print("   ⚠️ Footnote #\(footnote.number) not found in text, skipping orphaned model")
            #endif
            return nil
        }
        .sorted { $0.actualPosition < $1.actualPosition }
    }

    private func runningPageEstimate(pageCount: Int, charsProcessed: Int, totalCharacters: Int, estimatedPages: Int) -> Int {
        if charsProcessed > 0 && charsProcessed < totalCharacters {
            let projectedPages = Int(ceil(Double(pageCount) * Double(totalCharacters) / Double(charsProcessed)))
            return max(estimatedPages, projectedPages)
        }
        return max(estimatedPages, pageCount)
    }

    private func finalContentSize(pageCount: Int, pageLayout: PageLayoutCalculator.PageLayout, pageHeight: CGFloat) -> CGSize {
        let totalHeight = CGFloat(pageCount) * (pageHeight + pageSpacing) - pageSpacing
        return CGSize(
            width: pageLayout.pageRect.width,
            height: max(totalHeight, pageHeight)
        )
    }
    
    /// Invalidate the current layout (call when text or page setup changes)
    func invalidateLayout() {
        isLayoutValid = false
        isLayoutComplete = false
        isCalculating = false
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
        return getFootnotes(in: textRange, version: version, context: context)
    }
    
    /// Get footnotes for an explicit character range (use when layoutResult may not be set yet,
    /// e.g. PDF rendering on a background thread).
    func getFootnotes(in textRange: NSRange, version: Version, context: ModelContext) -> [FootnoteModel] {
        let allFootnotes = getAnchoredFootnotes(forVersion: version, context: context)
        let actualPositions = actualFootnoteAttachmentPositions()
        
        // Filter to footnotes within this page's text range using ACTUAL positions
        return allFootnotes.filter { footnote in
            guard let actualPosition = actualPositions[footnote.attachmentID] else {
                return false
            }
            return NSLocationInRange(actualPosition, textRange)
        }
    }
    
    /// Get assembled footnotes that appear on a specific page (for manuscript PDF export).
    /// Uses pre-collected ManuscriptFootnote data instead of querying SwiftData.
    /// - Parameters:
    ///   - pageNumber: Zero-based page index
    ///   - assembledFootnotes: All footnotes in the assembled manuscript
    /// - Returns: Array of footnotes appearing on this page, sorted by position
    func getFootnotesForPage(_ pageNumber: Int, assembledFootnotes: [ManuscriptFootnote]) -> [ManuscriptFootnote] {
        guard let textRange = characterRange(forPage: pageNumber) else {
            return []
        }
        return getFootnotes(in: textRange, assembledFootnotes: assembledFootnotes)
    }
    
    /// Get assembled footnotes for an explicit character range (use when layoutResult may not
    /// be set yet, e.g. PDF rendering on a background thread).
    func getFootnotes(in textRange: NSRange, assembledFootnotes: [ManuscriptFootnote]) -> [ManuscriptFootnote] {
        // Build a map of actual attachment positions from the text storage
        var actualPositions: [UUID: Int] = [:]
        textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: textStorage.length), options: []) { value, range, _ in
            if let footnoteAttachment = value as? FootnoteAttachment {
                actualPositions[footnoteAttachment.footnoteID] = range.location
            }
        }
        
        let uniqueFootnotes = Dictionary(grouping: assembledFootnotes, by: \.attachmentID)
            .compactMap { $0.value.first }
            .sorted { $0.characterPosition < $1.characterPosition }

        return uniqueFootnotes.filter { fn in
            guard let actualPosition = actualPositions[fn.attachmentID] else {
                return false
            }
            return NSLocationInRange(actualPosition, textRange)
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
    
    /// Calculate the height needed to display assembled footnotes (manuscript export variant)
    func calculateFootnoteHeight(for footnotes: [ManuscriptFootnote], pageWidth: CGFloat) -> CGFloat {
        guard !footnotes.isEmpty else { return 0 }
        let separatorHeight: CGFloat = 30
        let footnoteTextHeight = footnotes.reduce(0) { total, footnote in
            let textHeight = estimateTextHeight(footnote.text, width: pageWidth - 20)
            return total + textHeight + 4
        }
        return separatorHeight + footnoteTextHeight
    }
    
    /// Estimate the height needed to render text at a given width
    /// - Parameters:
    ///   - text: The text to measure
    ///   - width: Available width
    /// - Returns: Estimated height in points
    private func estimateTextHeight(_ text: String, width: CGFloat) -> CGFloat {
        // Match the font used by FootnoteRenderer (10pt system)
        let font = UIFont.systemFont(ofSize: 10)
        
        // Create paragraph style that matches FootnoteRenderer's .lineSpacing(1.2)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 1.2
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let boundingRect = attributedText.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        
        // Add a small buffer (4pt) because SwiftUI Text rendering can use slightly
        // more vertical space than the CoreText bounding rect calculation
        return ceil(boundingRect.height) + 4
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
