//
//  PageLayoutCalculator.swift
//  Writing Shed Pro
//
//  Utility for calculating page layout dimensions from PageSetup models
//  Provides the foundation for paginated document view
//

import Foundation
import CoreGraphics

/// Calculates page layout dimensions, text areas, and content areas from PageSetup configuration
/// This is the core utility that bridges PageSetup models to the pagination rendering engine
struct PageLayoutCalculator {
    
    // MARK: - Types
    
    /// Result of page layout calculation
    struct PageLayout {
        /// Full page rectangle (paper size)
        let pageRect: CGRect
        
        /// Text area (page minus margins)
        let textRect: CGRect
        
        /// Content area (text area minus header/footer space)
        let contentRect: CGRect
        
        /// Header area (if headers enabled)
        let headerRect: CGRect?
        
        /// Footer area (if footers enabled)
        let footerRect: CGRect?
        
        /// Paper size used
        let paperSize: PaperSizes
        
        /// Orientation used
        let orientation: Orientation
    }
    
    // MARK: - Public Methods
    
    /// Calculate complete page layout from PageSetup model
    /// - Parameter pageSetup: The page setup configuration
    /// - Returns: Complete page layout with all dimensions calculated
    static func calculateLayout(from pageSetup: PageSetup) -> PageLayout {
        let paperSize = pageSetup.paperSize
        let orientation = pageSetup.orientationEnum
        let pageRect = calculatePageRect(paperSize: paperSize, orientation: orientation)
        let textRect = calculateTextRect(pageRect: pageRect, pageSetup: pageSetup)
        let contentRect = calculateContentRect(textRect: textRect, pageSetup: pageSetup)
        
        let headerRect = pageSetup.hasHeaders ? calculateHeaderRect(textRect: textRect, pageSetup: pageSetup) : nil
        let footerRect = pageSetup.hasFooters ? calculateFooterRect(textRect: textRect, pageSetup: pageSetup) : nil
        
        return PageLayout(
            pageRect: pageRect,
            textRect: textRect,
            contentRect: contentRect,
            headerRect: headerRect,
            footerRect: footerRect,
            paperSize: paperSize,
            orientation: orientation
        )
    }
    
    /// Calculate the full page rectangle based on paper size and orientation
    /// - Parameters:
    ///   - paperSize: The paper size to use
    ///   - orientation: Portrait or landscape
    /// - Returns: Rectangle representing the full page dimensions
    static func calculatePageRect(paperSize: PaperSizes, orientation: Orientation) -> CGRect {
        var dimensions = paperSize.dimensions
        
        // Swap dimensions for landscape
        if orientation == .landscape {
            dimensions = (width: dimensions.height, height: dimensions.width)
        }
        
        return CGRect(
            x: 0,
            y: 0,
            width: dimensions.width,
            height: dimensions.height
        )
    }
    
    /// Calculate the text area (page minus margins)
    /// - Parameters:
    ///   - pageRect: The full page rectangle
    ///   - pageSetup: Page setup with margin configuration
    /// - Returns: Rectangle representing the text area
    static func calculateTextRect(pageRect: CGRect, pageSetup: PageSetup) -> CGRect {
        return CGRect(
            x: pageRect.origin.x + pageSetup.marginLeft,
            y: pageRect.origin.y + pageSetup.marginTop,
            width: pageRect.width - pageSetup.marginLeft - pageSetup.marginRight,
            height: pageRect.height - pageSetup.marginTop - pageSetup.marginBottom
        )
    }
    
    /// Calculate the content area (text area minus header/footer space)
    /// - Parameters:
    ///   - textRect: The text area rectangle
    ///   - pageSetup: Page setup with header/footer configuration
    /// - Returns: Rectangle representing the actual content area
    static func calculateContentRect(textRect: CGRect, pageSetup: PageSetup) -> CGRect {
        var contentRect = textRect
        
        // Reduce height for header if enabled
        if pageSetup.hasHeaders {
            contentRect.origin.y += pageSetup.headerDepth
            contentRect.size.height -= pageSetup.headerDepth
        }
        
        // Reduce height for footer if enabled
        if pageSetup.hasFooters {
            contentRect.size.height -= pageSetup.footerDepth
        }
        
        return contentRect
    }
    
    /// Calculate the header area
    /// - Parameters:
    ///   - textRect: The text area rectangle
    ///   - pageSetup: Page setup with header configuration
    /// - Returns: Rectangle representing the header area
    static func calculateHeaderRect(textRect: CGRect, pageSetup: PageSetup) -> CGRect {
        return CGRect(
            x: textRect.origin.x,
            y: textRect.origin.y,
            width: textRect.width,
            height: pageSetup.headerDepth
        )
    }
    
    /// Calculate the footer area
    /// - Parameters:
    ///   - textRect: The text area rectangle
    ///   - pageSetup: Page setup with footer configuration
    /// - Returns: Rectangle representing the footer area
    static func calculateFooterRect(textRect: CGRect, pageSetup: PageSetup) -> CGRect {
        return CGRect(
            x: textRect.origin.x,
            y: textRect.maxY - pageSetup.footerDepth,
            width: textRect.width,
            height: pageSetup.footerDepth
        )
    }
    
    // MARK: - Convenience Methods
    
    /// Get the usable width for text content
    /// - Parameter pageSetup: The page setup configuration
    /// - Returns: Width in points available for text
    static func contentWidth(from pageSetup: PageSetup) -> CGFloat {
        let layout = calculateLayout(from: pageSetup)
        return layout.contentRect.width
    }
    
    /// Get the usable height for text content
    /// - Parameter pageSetup: The page setup configuration
    /// - Returns: Height in points available for text
    static func contentHeight(from pageSetup: PageSetup) -> CGFloat {
        let layout = calculateLayout(from: pageSetup)
        return layout.contentRect.height
    }
    
    /// Get the content size (width and height)
    /// - Parameter pageSetup: The page setup configuration
    /// - Returns: Size in points available for text content
    static func contentSize(from pageSetup: PageSetup) -> CGSize {
        let layout = calculateLayout(from: pageSetup)
        return layout.contentRect.size
    }
    
    /// Calculate how many pages would be needed for given text height
    /// Note: This is a rough estimate. Actual page count requires text layout calculation
    /// - Parameters:
    ///   - textHeight: Total height of laid out text
    ///   - pageSetup: Page setup configuration
    /// - Returns: Estimated number of pages
    static func estimatePageCount(textHeight: CGFloat, pageSetup: PageSetup) -> Int {
        let contentHeight = self.contentHeight(from: pageSetup)
        guard contentHeight > 0 else { return 1 }
        
        let pages = ceil(textHeight / contentHeight)
        return max(1, Int(pages))  // Always at least 1 page
    }
    
    /// Calculate the vertical position of a page in a scroll view
    /// - Parameters:
    ///   - pageIndex: Zero-based page index
    ///   - pageSetup: Page setup configuration
    ///   - pageSpacing: Space between pages (default 20 points)
    /// - Returns: Y coordinate for the page origin
    static func yPosition(
        forPage pageIndex: Int,
        pageSetup: PageSetup,
        pageSpacing: CGFloat = 20
    ) -> CGFloat {
        let layout = calculateLayout(from: pageSetup)
        let pageHeight = layout.pageRect.height
        
        return CGFloat(pageIndex) * (pageHeight + pageSpacing)
    }
    
    /// Calculate which page a given Y coordinate falls on
    /// - Parameters:
    ///   - yPosition: Y coordinate in scroll view
    ///   - pageSetup: Page setup configuration
    ///   - pageSpacing: Space between pages (default 20 points)
    /// - Returns: Zero-based page index
    static func pageIndex(
        at yPosition: CGFloat,
        pageSetup: PageSetup,
        pageSpacing: CGFloat = 20
    ) -> Int {
        let layout = calculateLayout(from: pageSetup)
        let pageHeight = layout.pageRect.height
        let totalHeight = pageHeight + pageSpacing
        
        let index = Int(floor(yPosition / totalHeight))
        return max(0, index)
    }
}

// MARK: - Extension for Testing

extension PageLayoutCalculator.PageLayout {
    /// Debug description of the layout
    var debugDescription: String {
        """
        PageLayout:
        - Paper: \(paperSize.rawValue) (\(orientation == .portrait ? "Portrait" : "Landscape"))
        - Page: \(pageRect.size.width) x \(pageRect.size.height) pts
        - Text Area: \(textRect.size.width) x \(textRect.size.height) pts
        - Content Area: \(contentRect.size.width) x \(contentRect.size.height) pts
        - Header: \(headerRect?.size.height ?? 0) pts
        - Footer: \(footerRect?.size.height ?? 0) pts
        """
    }
}
