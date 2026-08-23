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
    
    /// Footnotes collected during manuscript assembly (used when version is nil)
    private let assembledFootnotes: [ManuscriptFootnote]
    
    /// Whether the first page is a front cover (no headers/footers)
    private let hasFrontCover: Bool
    /// Whether the last page is a back cover (no headers/footers)
    private let hasBackCover: Bool
    /// Pre-extracted cover image data for thread-safe rendering
    private let frontCoverImageData: Data?
    private let backCoverImageData: Data?
    /// Character length of front matter content (excluding cover) in the text storage.
    /// Pages whose character range falls within this length show roman numeral page numbers.
    private let frontMatterCharacterLength: Int
    
    /// Mapping of character offsets to collection/section names for {{Collection}} placeholder in manuscript mode.
    /// Sorted by offset ascending. Built from ManuscriptContent on the main thread.
    private let fileCollectionMap: [(offset: Int, collectionName: String)]
    
    // Cache for page text views to reuse rendering logic
    private var pageTextViews: [Int: UITextView] = [:]
    private var footnoteControllers: [Int: UIViewController] = [:]
    
    /// Running paragraph numbering counter state across pages
    private var pdfStyleCounters: [String: Int] = [:]
    private var pdfLastNumberForStyle: [String: Int] = [:]
    
    // MARK: - Initialization
    
    /// Initialize with our layout manager and context
    /// - Parameters:
    ///   - layoutManager: The layout manager with calculated pagination
    ///   - layoutResult: The layout result from calculateLayout (avoids async timing issue)
    ///   - pageSetup: Page setup configuration
    ///   - version: Version for footnote support
    ///   - context: Model context for footnote queries
    ///   - project: Project for stylesheet
    ///   - hasFrontCover: Whether the first page is a cover image
    ///   - hasBackCover: Whether the last page is a cover image
    init(layoutManager: PaginatedTextLayoutManager,
         layoutResult: PaginatedTextLayoutManager.LayoutResult,
         pageSetup: PageSetup,
         version: Version?,
         context: ModelContext?,
         project: Project,
         hasFrontCover: Bool = false,
         hasBackCover: Bool = false,
         frontMatterCharacterLength: Int = 0,
         assembledFootnotes: [ManuscriptFootnote] = [],
         frontCoverImageData: Data? = nil,
         backCoverImageData: Data? = nil,
         fileCollectionMap: [(offset: Int, collectionName: String)] = []) {
        self.layoutManager = layoutManager
        self.layoutResult = layoutResult
        self.pageSetup = pageSetup
        self.version = version
        self.modelContext = context
        self.project = project
        self.assembledFootnotes = assembledFootnotes
        self.hasFrontCover = hasFrontCover
        self.hasBackCover = hasBackCover
        self.frontMatterCharacterLength = frontMatterCharacterLength
        self.frontCoverImageData = frontCoverImageData
        self.backCoverImageData = backCoverImageData
        self.fileCollectionMap = fileCollectionMap
        
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
        var footnoteHeight: CGFloat = 0
        var versionFootnotes: [FootnoteModel] = []
        var manuscriptFootnotes: [ManuscriptFootnote] = []
        
        // Maximum footnote height - must match PaginatedTextLayoutManager
        let maxFootnoteHeight = contentRect.height * 0.5
        
        let pageCharRange = pageInfo.characterRange
        
        if let version = version, let modelContext = modelContext {
            versionFootnotes = layoutManager.getFootnotes(in: pageCharRange, version: version, context: modelContext)
            
            if !versionFootnotes.isEmpty {
                let rawFootnoteHeight = layoutManager.calculateFootnoteHeight(
                    for: versionFootnotes,
                    pageWidth: contentRect.width
                )
                footnoteHeight = min(rawFootnoteHeight, maxFootnoteHeight)
            }
        } else if !assembledFootnotes.isEmpty {
            manuscriptFootnotes = layoutManager.getFootnotes(in: pageCharRange, assembledFootnotes: assembledFootnotes)
            
            if !manuscriptFootnotes.isEmpty {
                let rawFootnoteHeight = layoutManager.calculateFootnoteHeight(
                    for: manuscriptFootnotes,
                    pageWidth: contentRect.width
                )
                footnoteHeight = min(rawFootnoteHeight, maxFootnoteHeight)
            }
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
        
        // Skip headers/footers on cover pages
        let isFrontCoverPage = hasFrontCover && pageIndex == 0
        let isBackCoverPage = hasBackCover && pageIndex == numberOfPages - 1
        let isCoverPage = isFrontCoverPage || isBackCoverPage
        
        if !isCoverPage {
            // Determine if this page is front matter based on character offset.
            // Front matter content starts right after the cover (if any) in the text storage.
            // The cover image is always a single page with a short placeholder string,
            // so front matter character positions come after the cover's characters.
            let isFrontMatterPage = frontMatterCharacterLength > 0
                && pageInfo.characterRange.location < frontMatterCharacterLength
            
            // Calculate page numbers for each numbering region.
            // We need to count pages sequentially within each region.
            
            let pageNumberString: String
            let displayTotalPages: Int
            
            if isFrontMatterPage {
                // Count front matter pages up to this one
                var fmPageNumber = 0
                var fmTotalPages = 0
                for i in 0..<layoutResult.pageInfos.count {
                    let pi = layoutResult.pageInfos[i]
                    let isThisFM = pi.characterRange.location < frontMatterCharacterLength
                    let isThisCover = (hasFrontCover && i == 0) || (hasBackCover && i == numberOfPages - 1)
                    if isThisFM && !isThisCover {
                        fmTotalPages += 1
                        if i == pageIndex { fmPageNumber = fmTotalPages }
                    }
                }
                pageNumberString = Self.toRomanNumeral(fmPageNumber)
                displayTotalPages = fmTotalPages
            } else {
                // Count body+back matter pages up to this one
                var bodyPageNumber = 0
                var bodyTotalPages = 0
                for i in 0..<layoutResult.pageInfos.count {
                    let pi = layoutResult.pageInfos[i]
                    let isThisFM = frontMatterCharacterLength > 0 && pi.characterRange.location < frontMatterCharacterLength
                    let isThisCover = (hasFrontCover && i == 0) || (hasBackCover && i == numberOfPages - 1)
                    if !isThisFM && !isThisCover {
                        bodyTotalPages += 1
                        if i == pageIndex { bodyPageNumber = bodyTotalPages }
                    }
                }
                pageNumberString = "\(bodyPageNumber)"
                displayTotalPages = bodyTotalPages
            }
            
            // Draw header if enabled
            if pageSetup.hasHeaders, let headerRect = pageLayout.headerRect {
                drawHeaderFooter(
                    left: pageSetup.headerLeft,
                    center: pageSetup.headerCenter,
                    right: pageSetup.headerRight,
                    rect: headerRect,
                    pageNumberString: pageNumberString,
                    totalPages: displayTotalPages,
                    pageCharOffset: pageInfo.characterRange.location,
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
                    pageNumberString: pageNumberString,
                    totalPages: displayTotalPages,
                    pageCharOffset: pageInfo.characterRange.location,
                    context: context
                )
            }
        }
        
        // Draw content — cover pages get special image drawing,
        // regular pages use the attributed string pipeline
        if isCoverPage {
            drawCoverImage(
                pageInfo: pageInfo,
                contentRect: contentRect,
                context: context,
                isFrontCover: isFrontCoverPage
            )
        } else {
            drawTextContent(
                pageIndex: pageIndex,
                characterRange: pageCharRange,
                containerHeight: containerHeight,
                topInset: topInset,
                leftInset: leftInset,
                context: context
            )
        }
        
        // Draw footnotes if present
        let hasFootnotes = !versionFootnotes.isEmpty || !manuscriptFootnotes.isEmpty
        if hasFootnotes {
            let footnoteRect = CGRect(
                x: contentRect.origin.x,
                y: pageLayout.pageRect.height - pageSetup.marginBottom - footnoteHeight,
                width: contentRect.width,
                height: footnoteHeight
            )
            
            if !versionFootnotes.isEmpty {
                drawFootnotes(
                    footnotes: versionFootnotes,
                    in: footnoteRect,
                    context: context,
                    maxHeight: footnoteHeight
                )
            } else {
                drawFootnotes(
                    footnotes: manuscriptFootnotes,
                    in: footnoteRect,
                    context: context,
                    maxHeight: footnoteHeight
                )
            }
        }
    }
    
    // MARK: - Drawing Helpers
    
    /// Resolve placeholder tokens in header/footer text
    private func resolvePlaceholders(_ text: String?, pageNumberString: String, totalPages: Int, pageCharOffset: Int = 0) -> String {
        guard let text = text, !text.isEmpty else { return "" }
        
        var result = text
        
        // {{Date}} - Current date
        if result.contains("{{Date}}") {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            result = result.replacingOccurrences(of: "{{Date}}", with: formatter.string(from: Date()))
        }
        
        // {{Page Number}} - Current page (roman numeral for front matter, arabic for body)
        if result.contains("{{Page Number}}") {
            result = result.replacingOccurrences(of: "{{Page Number}}", with: pageNumberString)
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
        
        // {{Collection}} - Collection/Section name (poetry collection or prose section)
        if result.contains("{{Collection}}") {
            let collectionName: String
            if let textFile = version?.textFile {
                // Single-file mode: get collection from the file's relationships
                collectionName = textFile.poetryCollections?.first?.name
                    ?? textFile.sections?.first?.name
                    ?? ""
            } else if !fileCollectionMap.isEmpty {
                // Manuscript mode: look up collection by page character offset
                // Find the last entry whose offset <= pageCharOffset (files are sorted by offset)
                var found = ""
                for entry in fileCollectionMap {
                    if entry.offset <= pageCharOffset {
                        found = entry.collectionName
                    } else {
                        break
                    }
                }
                collectionName = found
            } else {
                collectionName = ""
            }
            result = result.replacingOccurrences(of: "{{Collection}}", with: collectionName)
        }
        
        // {{Project Name}} - Project title
        if result.contains("{{Project Name}}") {
            let projectName = project.name ?? ""
            result = result.replacingOccurrences(of: "{{Project Name}}", with: projectName)
        }

        // {{Author}} - Project author
        if result.contains("{{Author}}") {
            let author = project.author ?? ""
            result = result.replacingOccurrences(of: "{{Author}}", with: author)
        }
        
        return result
    }
    
    /// Convert an integer to a lowercase roman numeral string
    static func toRomanNumeral(_ number: Int) -> String {
        guard number > 0 else { return "" }
        let values = [(1000, "m"), (900, "cm"), (500, "d"), (400, "cd"),
                      (100, "c"), (90, "xc"), (50, "l"), (40, "xl"),
                      (10, "x"), (9, "ix"), (5, "v"), (4, "iv"), (1, "i")]
        var result = ""
        var remaining = number
        for (value, numeral) in values {
            while remaining >= value {
                result += numeral
                remaining -= value
            }
        }
        return result
    }
    
    /// Draw header or footer text
    private func drawHeaderFooter(
        left: String?,
        center: String?,
        right: String?,
        rect: CGRect,
        pageNumberString: String,
        totalPages: Int,
        pageCharOffset: Int,
        context: CGContext
    ) {
        // Resolve placeholders
        let leftText = resolvePlaceholders(left, pageNumberString: pageNumberString, totalPages: totalPages, pageCharOffset: pageCharOffset)
        let centerText = resolvePlaceholders(center, pageNumberString: pageNumberString, totalPages: totalPages, pageCharOffset: pageCharOffset)
        let rightText = resolvePlaceholders(right, pageNumberString: pageNumberString, totalPages: totalPages, pageCharOffset: pageCharOffset)
        
        // Text attributes for header/footer
        let baseFont = UIFont.systemFont(ofSize: 12)
        let textColor = UIColor.darkGray
        
        let labelHeight: CGFloat = min(rect.height, 20)
        let verticalCenter = rect.origin.y + (rect.height - labelHeight) / 2
        let headerItems: [(text: String, alignment: NSTextAlignment, rect: CGRect)]
        let populatedCount = [leftText, centerText, rightText].filter { !$0.isEmpty }.count
        if populatedCount == 1 {
            let text = !leftText.isEmpty ? leftText : (!centerText.isEmpty ? centerText : rightText)
            let alignment: NSTextAlignment = !leftText.isEmpty ? .left : (!centerText.isEmpty ? .center : .right)
            headerItems = [(text, alignment, CGRect(x: rect.origin.x, y: verticalCenter, width: rect.width, height: labelHeight))]
        } else {
            headerItems = [
                (leftText, .left, CGRect(x: rect.origin.x, y: verticalCenter, width: rect.width / 3, height: labelHeight)),
                (centerText, .center, CGRect(x: rect.origin.x + rect.width / 3, y: verticalCenter, width: rect.width / 3, height: labelHeight)),
                (rightText, .right, CGRect(x: rect.origin.x + 2 * rect.width / 3, y: verticalCenter, width: rect.width / 3, height: labelHeight))
            ]
        }
        
        for item in headerItems where !item.text.isEmpty {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = item.alignment
            let font = Self.fittingHeaderFooterFont(for: item.text, baseFont: baseFont, maxWidth: item.rect.width)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ]
            item.text.draw(in: item.rect, withAttributes: attributes)
        }
    }

    private static func fittingHeaderFooterFont(for text: String, baseFont: UIFont, maxWidth: CGFloat) -> UIFont {
        guard !text.isEmpty, maxWidth > 0 else { return baseFont }
        var fontSize = baseFont.pointSize
        while fontSize > 7 {
            let font = baseFont.withSize(fontSize)
            let width = (text as NSString).size(withAttributes: [.font: font]).width
            if width <= maxWidth { return font }
            fontSize -= 0.5
        }
        return baseFont.withSize(7)
    }
    
    /// Draw a cover image directly into the full page area.
    /// Uses pre-extracted image data to avoid SwiftData cross-thread access crashes.
    private func drawCoverImage(pageInfo: PaginatedTextLayoutManager.PageInfo,
                                contentRect: CGRect,
                                context: CGContext,
                                isFrontCover: Bool) {
        let imageData = isFrontCover ? frontCoverImageData : backCoverImageData
        
        guard let data = imageData, let image = UIImage(data: data) else {
            #if DEBUG
            print("⚠️ [CustomPDFPageRenderer] Cover page has no pre-extracted image data (isFrontCover=\(isFrontCover))")
            #endif
            return
        }
        
        // Use the full page rect (edge-to-edge) for covers
        let paperSize = pageSetup.paperSize.dimensions
        let pageRect = CGRect(x: 0, y: 0, width: paperSize.width, height: paperSize.height)
        
        // Aspect-fit the image within the full page
        let imageSize = image.size
        let widthRatio = pageRect.width / imageSize.width
        let heightRatio = pageRect.height / imageSize.height
        let scale = min(widthRatio, heightRatio)
        
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        
        // Centre the image on the page
        let drawX = pageRect.origin.x + (pageRect.width - scaledWidth) / 2
        let drawY = pageRect.origin.y + (pageRect.height - scaledHeight) / 2
        let drawRect = CGRect(x: drawX, y: drawY, width: scaledWidth, height: scaledHeight)
        
        context.saveGState()
        image.draw(in: drawRect)
        context.restoreGState()
        
        #if DEBUG
        print("🖼️ [CustomPDFPageRenderer] Drew cover image \(Int(imageSize.width))×\(Int(imageSize.height)) → \(Int(scaledWidth))×\(Int(scaledHeight))")
        #endif
    }
    
    private func drawTextContent(pageIndex: Int,
                                 characterRange: NSRange,
                                 containerHeight: CGFloat,
                                 topInset: CGFloat,
                                 leftInset: CGFloat,
                                 context: CGContext) {
        guard characterRange.length > 0 else { return }
        let attributedString = layoutManager.textStorage.attributedSubstring(from: characterRange)
        
        // Process attachments (convert footnotes to superscript numbers, remove comments)
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        var replacements: [(range: NSRange, replacement: NSAttributedString)] = []
        
        mutableString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutableString.length), options: []) { value, range, stop in
            guard let attachment = value as? NSTextAttachment else { return }
            
            if let footnoteAttachment = attachment as? FootnoteAttachment {
                // Replace footnote marker with superscript text using the correct marker style
                // Use baselineOffset: 2 to match FootnoteAttachment.superscriptOffset for consistent line height
                let numberString = footnoteAttachment.displayString
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
        
        if drawLaidOutTextContent(
            pageIndex: pageIndex,
            attributedString: mutableString,
            drawRect: drawRect,
            context: context
        ) {
            return
        }
        
        // Save context state
        context.saveGState()
        
        // Clip to the draw rect
        context.clip(to: drawRect)
        
        // Draw the attributed string
        mutableString.draw(in: drawRect)
        
        // Draw paragraph numbers for numbered styles
        drawParagraphNumbers(in: mutableString, drawRect: drawRect)
        
        // Restore context state
        context.restoreGState()
    }
    
    private func drawLaidOutTextContent(pageIndex: Int,
                                        attributedString: NSAttributedString,
                                        drawRect: CGRect,
                                        context: CGContext) -> Bool {
        let containerSize: CGSize
        if pageIndex < layoutManager.layoutManager.textContainers.count {
            containerSize = layoutManager.layoutManager.textContainers[pageIndex].size
        } else {
            containerSize = drawRect.size
        }
        let textStorage = NSTextStorage(attributedString: attributedString)
        let nsLayoutManager = NumberingLayoutManager()
        nsLayoutManager.project = project
        nsLayoutManager.isPaginatedView = false
        nsLayoutManager.drawsTrailingEmptyParagraphNumber = false
        if let styleSheet = project.styleSheet {
            let pageStart = layoutResult.pageInfos[pageIndex].characterRange.location
            let counterState = NumberingLayoutManager.computeCounterState(
                upTo: pageStart,
                in: layoutManager.textStorage,
                styleSheet: styleSheet
            )
            nsLayoutManager.initialStyleCounters = counterState.styleCounters
            nsLayoutManager.initialLastNumberForStyle = counterState.lastNumberForStyle
        }
        let textContainer = NSTextContainer(size: containerSize)
        textContainer.lineFragmentPadding = 0
        textStorage.addLayoutManager(nsLayoutManager)
        nsLayoutManager.addTextContainer(textContainer)
        nsLayoutManager.ensureLayout(for: textContainer)
        let glyphRange = nsLayoutManager.glyphRange(for: textContainer)
        guard glyphRange.length > 0 else { return false }
        
        context.saveGState()
        context.clip(to: drawRect)
        context.translateBy(x: drawRect.origin.x, y: drawRect.origin.y)
        nsLayoutManager.drawBackground(forGlyphRange: glyphRange, at: .zero)
        nsLayoutManager.drawGlyphs(forGlyphRange: glyphRange, at: .zero)
        context.restoreGState()
        
        return true
    }
    
    /// Draw paragraph numbers for styles that have numbering enabled.
    /// Uses the running pdfStyleCounters/pdfLastNumberForStyle state so
    /// numbers increment correctly across pages.
    private func drawParagraphNumbers(in attributedString: NSMutableAttributedString, drawRect: CGRect) {
        guard let styleSheet = project.styleSheet else { return }
        PrintService.drawParagraphNumbers(
            in: attributedString,
            drawRect: drawRect,
            styleSheet: styleSheet,
            styleCounters: &pdfStyleCounters,
            lastNumberForStyle: &pdfLastNumberForStyle
        )
    }
    
    private func drawFootnotes<F: FootnoteRenderable & Identifiable>(footnotes: [F],
                              in rect: CGRect,
                              context: CGContext,
                              maxHeight: CGFloat) {
        // Draw footnotes directly via Core Graphics / NSString drawing.
        // UIHostingController-based rendering doesn't work for off-screen PDF
        // contexts (SwiftUI views won't render without a window hierarchy).
        
        let stylesheet = project.styleSheet
        let footnoteStyleName = UIFont.TextStyle.footnote.rawValue
        let footnoteStyle = stylesheet?.textStyles?.first { $0.name == footnoteStyleName }
        let markerStyle = stylesheet?.footnoteMarkerStyle ?? .numeric
        
        let fontSize: CGFloat = footnoteStyle?.fontSize ?? 10
        let isBold = footnoteStyle?.isBold ?? false
        let isItalic = footnoteStyle?.isItalic ?? false
        let textColor: UIColor = footnoteStyle?.textColor ?? .label
        
        // Build the font matching FootnoteRenderer's styling
        var fontTraits: UIFontDescriptor.SymbolicTraits = []
        if isBold { fontTraits.insert(.traitBold) }
        if isItalic { fontTraits.insert(.traitItalic) }
        let baseFont = UIFont.systemFont(ofSize: fontSize)
        let font: UIFont
        if !fontTraits.isEmpty, let desc = baseFont.fontDescriptor.withSymbolicTraits(fontTraits) {
            font = UIFont(descriptor: desc, size: fontSize)
        } else {
            font = baseFont
        }
        
        // Superscript number font (0.9× body, matching FootnoteRenderer)
        let numberFont = UIFont.systemFont(ofSize: fontSize * 0.9)
        
        // Paragraph style with 1.2pt line spacing (matches FootnoteRenderer)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 1.2
        
        // --- Draw using UIKit text drawing in the PDF context ---
        // The PDF context from UIGraphicsBeginPDFPage() is already in UIKit's
        // top-down coordinate system, so no flip is needed.
        context.saveGState()
        context.translateBy(x: rect.origin.x, y: rect.origin.y)
        
        // Push a UIGraphics context wrapping our CGContext so NSString.draw works
        UIGraphicsPushContext(context)
        
        let drawWidth = rect.width
        var yOffset: CGFloat = 0
        
        // 1) 10pt space above separator
        yOffset += 10
        
        // 2) Separator line: 108pt wide, 0.5pt thick
        context.setStrokeColor(textColor.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: 0, y: yOffset + 0.25))
        context.addLine(to: CGPoint(x: 108, y: yOffset + 0.25))
        context.strokePath()
        yOffset += 1
        
        // 3) 10pt space below separator
        yOffset += 10
        
        // 4) Draw each footnote entry
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: numberFont,
            .foregroundColor: textColor
        ]
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        
        for footnote in footnotes {
            let numberStr = markerStyle.displayString(for: footnote.number) as NSString
            let numberSize = numberStr.size(withAttributes: numberAttributes)
            
            // Draw the superscript number (baseline offset via y adjustment)
            let numberRect = CGRect(x: 0, y: yOffset - 3, width: numberSize.width, height: numberSize.height)
            numberStr.draw(in: numberRect, withAttributes: numberAttributes)
            
            // Draw the footnote text
            let textX = numberSize.width + 6
            let textWidth = drawWidth - textX
            let textStr = footnote.text as NSString
            let textBoundingRect = textStr.boundingRect(
                with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: textAttributes,
                context: nil
            )
            let textDrawRect = CGRect(x: textX, y: yOffset, width: textWidth, height: textBoundingRect.height)
            textStr.draw(with: textDrawRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: textAttributes, context: nil)
            
            yOffset += max(numberSize.height, textBoundingRect.height) + 4
        }
        
        UIGraphicsPopContext()
        context.restoreGState()
    }
    
    // MARK: - Cleanup
    
    deinit {
        pageTextViews.removeAll()
        footnoteControllers.removeAll()
    }
}
