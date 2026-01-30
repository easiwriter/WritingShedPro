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
    private let layoutResult: PaginatedTextLayoutManager.LayoutResult
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
    ///   - layoutResult: The layout result from calculateLayout (avoids async timing issue)
    ///   - pageSetup: Page setup configuration
    ///   - version: Version for footnote support
    ///   - context: Model context for footnote queries
    ///   - project: Project for stylesheet
    init(layoutManager: PaginatedTextLayoutManager,
         layoutResult: PaginatedTextLayoutManager.LayoutResult,
         pageSetup: PageSetup,
         version: Version?,
         context: ModelContext?,
         project: Project) {
        self.layoutManager = layoutManager
        self.layoutResult = layoutResult
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
        return layoutResult.totalPages
    }
    
    override func drawPage(at pageIndex: Int, in printableRect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            #if DEBUG
            print("❌ [CustomPDFPageRenderer] No graphics context")
            #endif
            return
        }
        
        #if DEBUG
        print("📄 [CustomPDFPageRenderer] Drawing page \(pageIndex + 1)/\(numberOfPages)")
        #endif
        
        // Get page info from layout result directly (not layoutManager property which is async)
        guard pageIndex >= 0, pageIndex < layoutResult.pageInfos.count else {
            #if DEBUG
            print("❌ [CustomPDFPageRenderer] No page info for page \(pageIndex)")
            #endif
            return
        }
        let pageInfo = layoutResult.pageInfos[pageIndex]
        
        // Calculate page layout
        let pageLayout = PageLayoutCalculator.calculateLayout(from: pageSetup)
        let contentRect = pageLayout.contentRect
        
        // Get footnotes for this page
        let footnotes: [FootnoteModel]
        var footnoteHeight: CGFloat
        
        // Maximum footnote height - must match PaginatedTextLayoutManager
        let maxFootnoteHeight = contentRect.height * 0.5
        
        if let version = version, let modelContext = modelContext {
            footnotes = layoutManager.getFootnotesForPage(pageIndex, version: version, context: modelContext)
            
            if !footnotes.isEmpty {
                let rawFootnoteHeight = layoutManager.calculateFootnoteHeight(
                    for: footnotes,
                    pageWidth: contentRect.width
                )
                // Cap footnote height to ensure minimum text space
                footnoteHeight = min(rawFootnoteHeight, maxFootnoteHeight)
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
        
        // Calculate insets - headers/footers are in margin areas, so just use margins
        let topInset = pageSetup.marginTop
        let leftInset = pageSetup.marginLeft
        
        // Draw header if enabled
        if pageSetup.hasHeaders, let headerRect = pageLayout.headerRect {
            drawHeaderFooter(
                left: pageSetup.headerLeft,
                center: pageSetup.headerCenter,
                right: pageSetup.headerRight,
                rect: headerRect,
                pageNumber: pageIndex + 1,
                totalPages: numberOfPages,
                context: context
            )
        }
        
        // Draw footer if enabled
        if pageSetup.hasFooters, let footerRect = pageLayout.footerRect {
            drawHeaderFooter(
                left: pageSetup.footerLeft,
                center: pageSetup.footerCenter,
                right: pageSetup.footerRight,
                rect: footerRect,
                pageNumber: pageIndex + 1,
                totalPages: numberOfPages,
                context: context
            )
        }
        
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
                context: context,
                maxHeight: footnoteHeight
            )
        }
    }
    
    // MARK: - Drawing Helpers
    
    /// Resolve placeholder tokens in header/footer text
    private func resolvePlaceholders(_ text: String?, pageNumber: Int, totalPages: Int) -> String {
        guard let text = text, !text.isEmpty else { return "" }
        
        var result = text
        
        // {{Date}} - Current date
        if result.contains("{{Date}}") {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            result = result.replacingOccurrences(of: "{{Date}}", with: formatter.string(from: Date()))
        }
        
        // {{Page Number}} - Current page (always actual numbers for printing)
        if result.contains("{{Page Number}}") {
            result = result.replacingOccurrences(of: "{{Page Number}}", with: "\(pageNumber)")
        }
        
        // {{Folder}} - Source folder name
        if result.contains("{{Folder}}") {
            let folderName: String
            switch project.type {
            case .poetry:
                folderName = NSLocalizedString("folder.poems", comment: "Poems")
            case .fiction:
                folderName = NSLocalizedString("folder.scenes", comment: "Scenes")
            case .drama:
                folderName = NSLocalizedString("folder.scripts", comment: "Scripts")
            default:
                folderName = NSLocalizedString("folder.sections", comment: "Sections")
            }
            result = result.replacingOccurrences(of: "{{Folder}}", with: folderName)
        }
        
        // {{Project Name}} - Project title
        if result.contains("{{Project Name}}") {
            let projectName = project.name ?? ""
            result = result.replacingOccurrences(of: "{{Project Name}}", with: projectName)
        }
        
        return result
    }
    
    /// Draw header or footer text
    private func drawHeaderFooter(
        left: String?,
        center: String?,
        right: String?,
        rect: CGRect,
        pageNumber: Int,
        totalPages: Int,
        context: CGContext
    ) {
        // Resolve placeholders
        let leftText = resolvePlaceholders(left, pageNumber: pageNumber, totalPages: totalPages)
        let centerText = resolvePlaceholders(center, pageNumber: pageNumber, totalPages: totalPages)
        let rightText = resolvePlaceholders(right, pageNumber: pageNumber, totalPages: totalPages)
        
        // Text attributes for header/footer
        let font = UIFont.systemFont(ofSize: 12)
        let textColor = UIColor.darkGray
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        
        let paragraphStyle = NSMutableParagraphStyle()
        let labelHeight: CGFloat = min(rect.height, 20)
        let verticalCenter = rect.origin.y + (rect.height - labelHeight) / 2
        
        // Draw left text
        if !leftText.isEmpty {
            paragraphStyle.alignment = .left
            let leftAttributes = attributes.merging([.paragraphStyle: paragraphStyle]) { _, new in new }
            let leftRect = CGRect(x: rect.origin.x, y: verticalCenter, width: rect.width / 3, height: labelHeight)
            leftText.draw(in: leftRect, withAttributes: leftAttributes)
        }
        
        // Draw center text
        if !centerText.isEmpty {
            paragraphStyle.alignment = .center
            let centerAttributes = attributes.merging([.paragraphStyle: paragraphStyle]) { _, new in new }
            let centerRect = CGRect(x: rect.origin.x + rect.width / 3, y: verticalCenter, width: rect.width / 3, height: labelHeight)
            centerText.draw(in: centerRect, withAttributes: centerAttributes)
        }
        
        // Draw right text
        if !rightText.isEmpty {
            paragraphStyle.alignment = .right
            let rightAttributes = attributes.merging([.paragraphStyle: paragraphStyle]) { _, new in new }
            let rightRect = CGRect(x: rect.origin.x + 2 * rect.width / 3, y: verticalCenter, width: rect.width / 3, height: labelHeight)
            rightText.draw(in: rightRect, withAttributes: rightAttributes)
        }
    }
    
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
                // Use baselineOffset: 2 to match FootnoteAttachment.superscriptOffset for consistent line height
                let numberString = "\(footnoteAttachment.number)"
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                    .foregroundColor: UIColor.systemBlue,
                    .baselineOffset: 2
                ]
                replacements.append((range: range, replacement: NSAttributedString(string: numberString, attributes: attributes)))
            } else if attachment is CommentAttachment {
                replacements.append((range: range, replacement: NSAttributedString(string: "")))
            }
        }
        
        for (range, replacement) in replacements.reversed() {
            mutableString.replaceCharacters(in: range, with: replacement)
        }
        
        // Remove section type background colors for clean PDF output
        // The subtle tints are for on-screen editing only
        mutableString.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: mutableString.length))
        
        // CRITICAL: Convert dynamic colors to fixed colors for PDF rendering
        // Dynamic colors (like .label, .systemBackground) don't resolve correctly in PDF context
        mutableString.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: mutableString.length), options: []) { value, range, stop in
            if let color = value as? UIColor {
                // Check if this is a dynamic color by trying to resolve it
                // Dynamic colors will have different values in light/dark mode
                // For PDFs, we always want light mode (black text on white)
                let resolvedColor = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
                if resolvedColor != color {
                    // This was a dynamic color, replace it with the light mode version
                    mutableString.addAttribute(.foregroundColor, value: resolvedColor, range: range)
                }
            }
        }
        
        // Also ensure any text without an explicit foreground color gets black
        // (default in PDF context should be black, but let's be explicit)
        mutableString.enumerateAttributes(in: NSRange(location: 0, length: mutableString.length), options: []) { attributes, range, stop in
            if attributes[.foregroundColor] == nil {
                mutableString.addAttribute(.foregroundColor, value: UIColor.black, range: range)
            }
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
                              context: CGContext,
                              maxHeight: CGFloat) {
        // Get stylesheet from project
        let stylesheet = project.styleSheet
        
        // Create footnote renderer view with max height for clipping
        let footnoteView = FootnoteRenderer(
            footnotes: footnotes,
            pageWidth: rect.width,
            stylesheet: stylesheet,
            maxHeight: maxHeight
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
