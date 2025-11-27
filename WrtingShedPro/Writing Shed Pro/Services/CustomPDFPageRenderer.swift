//
//  CustomPDFPageRenderer.swift
//  Writing Shed Pro
//
//  Custom UIPrintPageRenderer that uses PaginatedTextLayoutManager
//  for accurate layout calculation including footnotes
//

import UIKit
import SwiftUI
import SwiftData

/// Custom page renderer that uses our pagination system for PDF generation
/// This ensures PDFs render exactly like the paginated view with proper footnote support
class CustomPDFPageRenderer: UIPrintPageRenderer {
    
    // MARK: - Properties
    
    private let layoutManager: PaginatedTextLayoutManager
    private let pageSetup: PageSetup
    private let version: Version?
    private let modelContext: ModelContext?
    private let project: Project
    
    // Cache for page text views to reuse rendering logic
    private var pageTextViews: [Int: UITextView] = [:]
    private var footnoteControllers: [Int: UIHostingController<FootnoteRenderer>] = [:]
    
    // MARK: - Initialization
    
    /// Initialize with our layout manager and context
    /// - Parameters:
    ///   - layoutManager: The layout manager with calculated pagination
    ///   - pageSetup: Page setup configuration
    ///   - version: Version for footnote support
    ///   - context: Model context for footnote queries
    ///   - project: Project for stylesheet
    init(layoutManager: PaginatedTextLayoutManager, 
         pageSetup: PageSetup,
         version: Version?,
         context: ModelContext?,
         project: Project) {
        self.layoutManager = layoutManager
        self.pageSetup = pageSetup
        self.version = version
        self.modelContext = context
        self.project = project
        
        super.init()
        
        // Set up page rects
        let paperSize = pageSetup.paperSize.dimensions
        let paperRect = CGRect(x: 0, y: 0, width: paperSize.width, height: paperSize.height)
        
        let printableRect = CGRect(
            x: pageSetup.marginLeft,
            y: pageSetup.marginTop,
            width: paperSize.width - pageSetup.marginLeft - pageSetup.marginRight,
            height: paperSize.height - pageSetup.marginTop - pageSetup.marginBottom
        )
        
        self.setValue(paperRect, forKey: "paperRect")
        self.setValue(printableRect, forKey: "printableRect")
    }
    
    // MARK: - UIPrintPageRenderer Overrides
    
    override var numberOfPages: Int {
        return layoutManager.pageCount
    }
    
    override func drawPage(at pageIndex: Int, in printableRect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            print("❌ [CustomPDFPageRenderer] No graphics context")
            return
        }
        
        #if DEBUG
        print("📄 [CustomPDFPageRenderer] Drawing page \(pageIndex + 1)/\(numberOfPages)")
        #endif
        
        // Get page info from layout manager
        guard let pageInfo = layoutManager.pageInfo(forPage: pageIndex) else {
            print("❌ [CustomPDFPageRenderer] No page info for page \(pageIndex)")
            return
        }
        
        // Calculate page layout
        let pageLayout = PageLayoutCalculator.calculateLayout(from: pageSetup)
        let contentRect = pageLayout.contentRect
        
        // Get footnotes for this page
        let footnotes: [FootnoteModel]
        let footnoteHeight: CGFloat
        
        if let version = version, let modelContext = modelContext {
            footnotes = layoutManager.getFootnotesForPage(pageIndex, version: version, context: modelContext)
            
            if !footnotes.isEmpty {
                footnoteHeight = layoutManager.calculateFootnoteHeight(
                    for: footnotes,
                    pageWidth: contentRect.width
                )
            } else {
                footnoteHeight = 0
            }
        } else {
            footnotes = []
            footnoteHeight = 0
        }
        
        // Get the actual container height used during layout
        let containerHeight: CGFloat
        if pageIndex < layoutManager.layoutManager.textContainers.count {
            let calculatedContainer = layoutManager.layoutManager.textContainers[pageIndex]
            containerHeight = calculatedContainer.size.height
        } else {
            containerHeight = contentRect.height
        }
        
        // Calculate insets
        let topInset = pageSetup.marginTop + (pageSetup.hasHeaders ? pageSetup.headerDepth : 0)
        let leftInset = pageSetup.marginLeft
        let rightInset = pageSetup.marginRight
        
        // Draw text content
        drawTextContent(
            pageInfo: pageInfo,
            containerHeight: containerHeight,
            topInset: topInset,
            leftInset: leftInset,
            context: context
        )
        
        // Draw footnotes if present
        if !footnotes.isEmpty {
            let footnoteRect = CGRect(
                x: contentRect.origin.x,
                y: pageLayout.pageRect.height - pageSetup.marginBottom - footnoteHeight,
                width: contentRect.width,
                height: footnoteHeight
            )
            
            drawFootnotes(
                footnotes: footnotes,
                in: footnoteRect,
                context: context
            )
        }
    }
    
    // MARK: - Drawing Helpers
    
    private func drawTextContent(pageInfo: PaginatedTextLayoutManager.PageInfo,
                                 containerHeight: CGFloat,
                                 topInset: CGFloat,
                                 leftInset: CGFloat,
                                 context: CGContext) {
        // Extract text for this page
        let characterRange = pageInfo.characterRange
        let attributedString = layoutManager.textStorage.attributedSubstring(from: characterRange)
        
        // Process attachments (convert footnotes to superscript numbers, remove comments)
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        var replacements: [(range: NSRange, replacement: NSAttributedString)] = []
        
        mutableString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutableString.length), options: []) { value, range, stop in
            guard let attachment = value as? NSTextAttachment else { return }
            
            if let footnoteAttachment = attachment as? FootnoteAttachment {
                // Replace footnote marker with superscript number
                let numberString = "\(footnoteAttachment.number)"
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                    .foregroundColor: UIColor.systemBlue,
                    .baselineOffset: 8
                ]
                replacements.append((range: range, replacement: NSAttributedString(string: numberString, attributes: attributes)))
            } else if attachment is CommentAttachment {
                replacements.append((range: range, replacement: NSAttributedString(string: "")))
            }
        }
        
        for (range, replacement) in replacements.reversed() {
            mutableString.replaceCharacters(in: range, with: replacement)
        }
        
        // Calculate draw rect (accounting for insets)
        let pageLayout = PageLayoutCalculator.calculateLayout(from: pageSetup)
        let drawRect = CGRect(
            x: leftInset,
            y: topInset,
            width: pageLayout.contentRect.width,
            height: containerHeight
        )
        
        // Save context state
        context.saveGState()
        
        // Clip to the draw rect
        context.clip(to: drawRect)
        
        // Draw the attributed string
        mutableString.draw(in: drawRect)
        
        // Restore context state
        context.restoreGState()
    }
    
    private func drawFootnotes(footnotes: [FootnoteModel],
                              in rect: CGRect,
                              context: CGContext) {
        // Get stylesheet from project
        let stylesheet = project.styleSheet
        
        // Create footnote renderer view
        let footnoteView = FootnoteRenderer(
            footnotes: footnotes,
            pageWidth: rect.width,
            stylesheet: stylesheet
        )
        
        // Wrap in hosting controller for rendering
        let hostingController = UIHostingController(rootView: footnoteView)
        hostingController.view.frame = rect
        hostingController.view.backgroundColor = UIColor.clear
        
        // Render the view
        context.saveGState()
        context.translateBy(x: rect.origin.x, y: rect.origin.y)
        
        // Render the layer (layer is always present on UIView)
        hostingController.view.layer.render(in: context)
        
        context.restoreGState()
    }
    
    // MARK: - Cleanup
    
    deinit {
        pageTextViews.removeAll()
        footnoteControllers.removeAll()
    }
}
