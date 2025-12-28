//
//  VirtualPageScrollView.swift
//  Writing Shed Pro
//
//  Virtual scrolling view for paginated documents
//  Only renders visible pages for memory efficiency
//

import SwiftUI
import UIKit
import SwiftData

/// SwiftUI wrapper for virtual page scrolling
struct VirtualPageScrollView: UIViewRepresentable {
    
    // MARK: - Properties
    
    let layoutManager: PaginatedTextLayoutManager
    let pageSetup: PageSetup
    let zoomScale: CGFloat
    let version: Version?
    let modelContext: ModelContext
    let project: Project?
    @Binding var currentPage: Int
    var onPageChange: ((Int) -> Void)?
    var onZoomChange: ((CGFloat) -> Void)?
    
    // MARK: - UIViewRepresentable
    
    func makeUIView(context: Context) -> VirtualPageScrollViewImpl {
        let scrollView = VirtualPageScrollViewImpl(
            layoutManager: layoutManager,
            pageSetup: pageSetup,
            version: version,
            modelContext: modelContext,
            project: project
        )
        scrollView.pageChangeHandler = { page in
            currentPage = page
            onPageChange?(page)
        }
        scrollView.zoomChangeHandler = { zoom in
            onZoomChange?(zoom)
        }
        scrollView.updateZoomScale(zoomScale)
        return scrollView
    }
    
    func updateUIView(_ uiView: VirtualPageScrollViewImpl, context: Context) {
        // Update if layout manager or page setup changed
        uiView.updateLayout(layoutManager: layoutManager, pageSetup: pageSetup, version: version, modelContext: modelContext, project: project)
        // Update zoom scale to adjust content insets
        uiView.updateZoomScale(zoomScale)
    }
}

// MARK: - UIScrollView Implementation

/// UIScrollView subclass that implements virtual page scrolling
class VirtualPageScrollViewImpl: UIScrollView, UIScrollViewDelegate {
    
    // MARK: - Types
    
    private struct PageViewInfo {
        let pageIndex: Int
        let textView: UITextView
        let footnoteHostingController: UIHostingController<FootnoteRenderer>?
        let frame: CGRect
    }
    
    // MARK: - Properties
    
    private var layoutManager: PaginatedTextLayoutManager
    private var pageSetup: PageSetup
    private var pageLayout: PageLayoutCalculator.PageLayout
    private var version: Version?
    private var modelContext: ModelContext
    private var project: Project?
    
    /// Currently rendered page views (pageIndex -> PageViewInfo)
    private var renderedPages: [Int: PageViewInfo] = [:]
    
    /// Current visible page range
    private var visiblePageRange: Range<Int> = 0..<0
    
    /// Buffer: number of pages to render above/below visible area
    private let bufferPages: Int = 2
    
    /// Page change callback
    var pageChangeHandler: ((Int) -> Void)?
    
    /// Current page being viewed
    private var currentPageIndex: Int = 0 {
        didSet {
            if currentPageIndex != oldValue {
                pageChangeHandler?(currentPageIndex)
            }
        }
    }
    
    /// Page view cache for recycling
    private var pageViewCache: [UITextView] = []
    private let maxCacheSize: Int = 10
    
    /// Current zoom scale for content inset adjustment
    private var currentZoomScale: CGFloat = 1.0
    
    /// Base content size (at 100% zoom)
    private var baseContentSize: CGSize = .zero
    
    /// Container view for zooming (required by UIScrollView zoom)
    private var zoomContainerView: UIView!
    
    /// Zoom change callback
    var zoomChangeHandler: ((CGFloat) -> Void)?
    
    // MARK: - Initialization
    
    init(layoutManager: PaginatedTextLayoutManager, pageSetup: PageSetup, version: Version?, modelContext: ModelContext, project: Project?) {
        self.layoutManager = layoutManager
        self.pageSetup = pageSetup
        self.pageLayout = PageLayoutCalculator.calculateLayout(from: pageSetup)
        self.version = version
        self.modelContext = modelContext
        self.project = project
        
        super.init(frame: .zero)
        
        self.delegate = self
        self.backgroundColor = .systemGray6
        self.showsVerticalScrollIndicator = true
        self.showsHorizontalScrollIndicator = true
        self.bounces = true
        self.alwaysBounceHorizontal = false
        self.alwaysBounceVertical = true
        
        // Disable automatic content inset adjustments
        if #available(iOS 11.0, *) {
            self.contentInsetAdjustmentBehavior = .never
        }
        
        // Enable pinch-to-zoom
        self.minimumZoomScale = 0.5
        self.maximumZoomScale = 2.0
        self.bouncesZoom = true
        
        // Create zoom container view
        zoomContainerView = UIView()
        zoomContainerView.backgroundColor = .clear
        addSubview(zoomContainerView)
        
        setupScrollView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupScrollView() {
        // Calculate layout if needed (pass version and context for footnote-aware layout)
        if !layoutManager.isLayoutValid {
            layoutManager.calculateLayout(version: version, context: modelContext)
        }
        
        guard let result = layoutManager.layoutResult else { return }
        
        // Store base content size
        baseContentSize = result.contentSize
        
        // Set zoom container size to match content - always at origin .zero
        zoomContainerView.frame = CGRect(origin: .zero, size: baseContentSize)
        
        // Set content size
        contentSize = baseContentSize
        
        // Ensure no content inset initially
        contentInset = .zero
        
        // Render initial pages
        updateVisiblePages()
        
        #if DEBUG
        print("📍 Initial scroll view state:")
        print("   contentSize: \(contentSize)")
        print("   contentOffset: \(contentOffset)")
        print("   contentInset: \(contentInset)")
        print("   zoomContainerView.frame: \(zoomContainerView.frame)")
        print("   bounds: \(bounds)")
        #endif
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        #if DEBUG
        print("📐 layoutSubviews called")
        print("   bounds: \(bounds)")
        print("   contentSize: \(contentSize)")
        print("   contentOffset: \(contentOffset)")
        print("   contentInset: \(contentInset)")
        print("   zoomContainerView.frame: \(zoomContainerView.frame)")
        #endif
        
        // Force scroll position to top-left if content is wider than viewport
        if zoomContainerView.frame.width >= bounds.width && contentOffset.x != 0 {
            #if DEBUG
            print("⚠️ Correcting contentOffset.x from \(contentOffset.x) to 0")
            #endif
            contentOffset.x = 0
        }
        
        // Update visible pages based on new bounds
        updateVisiblePages()
    }
    
    // MARK: - Layout Updates
    
    func updateLayout(layoutManager: PaginatedTextLayoutManager, pageSetup: PageSetup, version: Version?, modelContext: ModelContext, project: Project?) {
        // Always update - PageSetup properties may have changed even if same object
        self.layoutManager = layoutManager
        self.pageSetup = pageSetup
        self.pageLayout = PageLayoutCalculator.calculateLayout(from: pageSetup)
        self.version = version
        self.modelContext = modelContext
        self.project = project
        
        // Clear all rendered pages (they have old dimensions/positions)
        clearAllPages()
        
        // Recalculate layout with new page setup (pass version and context for footnote-aware layout)
        if !layoutManager.isLayoutValid {
            layoutManager.calculateLayout(version: version, context: modelContext)
        }
        
        // Update scroll view content size
        if let result = layoutManager.layoutResult {
            baseContentSize = result.contentSize
            // Update content size with current zoom
            updateZoomScale(currentZoomScale)
        }
        
        // Re-render visible pages with new layout
        updateVisiblePages()
    }
    
    func updateZoomScale(_ scale: CGFloat) {
        currentZoomScale = scale
        if zoomScale != scale {
            setZoomScale(scale, animated: false)
        }
    }
    
    // MARK: - UIScrollViewDelegate (Zoom)
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return zoomContainerView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        currentZoomScale = scrollView.zoomScale
        zoomChangeHandler?(scrollView.zoomScale)
        
        // Center content using insets instead of frame positioning
        let boundsSize = bounds.size
        let contentSize = zoomContainerView.frame.size
        
        var horizontalInset: CGFloat = 0
        var verticalInset: CGFloat = 0
        
        if contentSize.width < boundsSize.width {
            horizontalInset = (boundsSize.width - contentSize.width) / 2
        }
        
        if contentSize.height < boundsSize.height {
            verticalInset = (boundsSize.height - contentSize.height) / 2
        }
        
        scrollView.contentInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
        
        #if DEBUG
        print("🔍 Zoom changed to \(String(format: "%.0f%%", scrollView.zoomScale * 100))")
        print("   contentSize: \(contentSize)")
        print("   boundsSize: \(boundsSize)")
        print("   contentInset: \(scrollView.contentInset)")
        print("   contentOffset: \(scrollView.contentOffset)")
        #endif
    }
    
    // MARK: - Virtual Scrolling
    
    private func updateVisiblePages() {
        guard let result = layoutManager.layoutResult else { return }
        guard result.totalPages > 0 else { return }
        
        let visibleRect = bounds
        
        // Calculate which pages are visible
        let firstVisiblePage = pageIndex(at: visibleRect.minY)
        let lastVisiblePage = pageIndex(at: visibleRect.maxY)
        
        // Add buffer
        let bufferFirst = max(0, firstVisiblePage - bufferPages)
        let bufferLast = min(result.totalPages - 1, lastVisiblePage + bufferPages)
        let newRange = bufferFirst..<(bufferLast + 1)
        
        // Update current page
        let midY = visibleRect.midY
        currentPageIndex = pageIndex(at: midY)
        
        // Check if range changed
        guard newRange != visiblePageRange else { return }
        
        // Remove pages outside new range
        let pagesToRemove = Set(renderedPages.keys).subtracting(Set(newRange))
        for pageIndex in pagesToRemove {
            removePage(at: pageIndex)
        }
        
        // Add pages in new range
        for pageIndex in newRange where renderedPages[pageIndex] == nil {
            createPage(at: pageIndex)
        }
        
        visiblePageRange = newRange
    }
    
    private func createPage(at pageIndex: Int) {
        guard let pageInfo = layoutManager.pageInfo(forPage: pageIndex) else { return }
        
        // Get page frame
        let pageFrame = frameForPage(pageIndex)
        
        // Query footnotes for this page FIRST (needed to calculate text area)
        var footnoteController: UIHostingController<FootnoteRenderer>? = nil
        var footnoteHeight: CGFloat = 0
        
        if let version = version {
            let footnotes = layoutManager.getFootnotesForPage(pageIndex, version: version, context: modelContext)
            
            #if DEBUG
            if !footnotes.isEmpty {
                print("📄 Page \(pageIndex): Found \(footnotes.count) footnotes")
            }
            #endif
            
            // Create footnote renderer if footnotes exist
            if !footnotes.isEmpty {
                // Use contentRect width for footnotes (respects page margins)
                let contentWidth = pageLayout.contentRect.width
                let renderer = FootnoteRenderer(
                    footnotes: footnotes,
                    pageWidth: contentWidth,
                    stylesheet: project?.styleSheet
                )
                footnoteController = UIHostingController(rootView: renderer)
                
                // Calculate footnote height for text area adjustment
                footnoteHeight = layoutManager.calculateFootnoteHeight(for: footnotes, pageWidth: contentWidth)
                
                #if DEBUG
                print("📏 Footnote height for page \(pageIndex): \(footnoteHeight)pt")
                #endif
            }
        }
        
        // Get or create text view
        let textView = dequeueReusableTextView() ?? createNewTextView()
        
        // CRITICAL FIX: Calculate the actual text area height for this page
        // This determines how much vertical space text can use before hitting the footnote
        let pageIndex = pageInfo.pageIndex
        let contentHeight: CGFloat
        
        if pageIndex < layoutManager.layoutManager.textContainers.count {
            let calculatedContainer = layoutManager.layoutManager.textContainers[pageIndex]
            contentHeight = calculatedContainer.size.height
            
            #if DEBUG
            print("   📦 Page \(pageIndex) calculated content height: \(contentHeight)pt")
            #endif
        } else {
            contentHeight = pageLayout.contentRect.height
        }
        
        // Calculate frame and insets
        let topInset = pageSetup.marginTop + (pageSetup.hasHeaders ? pageSetup.headerDepth : 0)
        let leftInset = pageSetup.marginLeft
        let rightInset = pageSetup.marginRight
        
        // For pages with footnotes, we need to limit the text view's visible height
        // The text view frame should only cover the content area, not the footnote area
        let textViewHeight = topInset + contentHeight
        
        textView.frame = CGRect(
            x: pageFrame.origin.x,
            y: pageFrame.origin.y,
            width: pageFrame.width,
            height: textViewHeight
        )
        
        // CRITICAL: Enable clipping so any text beyond frame boundary is hidden
        textView.clipsToBounds = true
        
        textView.textContainerInset = UIEdgeInsets(
            top: topInset,
            left: leftInset,
            bottom: 0, // No bottom inset - frame height controls clipping
            right: rightInset
        )
        
        // Set container size to match calculation
        textView.textContainer.size = CGSize(
            width: pageLayout.contentRect.width,
            height: contentHeight
        )
        textView.textContainer.lineFragmentPadding = 0
        
        #if DEBUG
        print("   � Text view frame: height=\(textViewHeight)pt (topInset: \(topInset)pt + content: \(contentHeight)pt)")
        if footnoteHeight > 0 {
            print("   📐 Footnote space reserved: \(footnoteHeight)pt")
        }
        #endif
        
        // Configure text view with page content
        configureTextView(textView, for: pageInfo)
        
        // Add to zoom container view instead of directly to scroll view
        zoomContainerView.addSubview(textView)
        
        // Position footnote view if it exists
        if let footnoteController = footnoteController {
            // Position footnote view at bottom of content area (inside margins)
            // Account for margins: left margin and bottom margin
            let leftMargin = pageSetup.marginLeft
            let bottomMargin = pageSetup.marginBottom
            
            let footnoteFrame = CGRect(
                x: pageFrame.origin.x + leftMargin,
                y: pageFrame.origin.y + pageFrame.height - bottomMargin - footnoteHeight,
                width: pageLayout.contentRect.width,
                height: footnoteHeight
            )
            
            #if DEBUG
            print("📍 Footnote frame: \(footnoteFrame)")
            print("📏 Page frame: \(pageFrame), leftMargin: \(leftMargin), bottomMargin: \(bottomMargin)")
            #endif
            
            footnoteController.view.frame = footnoteFrame
            footnoteController.view.backgroundColor = .clear // Transparent background
            zoomContainerView.addSubview(footnoteController.view)
        }
        
        // Store page info
        let pageViewInfo = PageViewInfo(
            pageIndex: pageIndex,
            textView: textView,
            footnoteHostingController: footnoteController,
            frame: pageFrame
        )
        renderedPages[pageIndex] = pageViewInfo
    }
    
    private func removePage(at pageIndex: Int) {
        guard let pageViewInfo = renderedPages[pageIndex] else { return }
        
        // Remove from view hierarchy
        pageViewInfo.textView.removeFromSuperview()
        
        // Clean up footnote hosting controller if present
        if let footnoteController = pageViewInfo.footnoteHostingController {
            footnoteController.view.removeFromSuperview()
        }
        
        // Return to cache
        enqueueTextView(pageViewInfo.textView)
        
        // Remove from rendered pages
        renderedPages.removeValue(forKey: pageIndex)
    }
    
    private func clearAllPages() {
        for pageIndex in renderedPages.keys {
            removePage(at: pageIndex)
        }
        visiblePageRange = 0..<0
    }
    
    private func repositionAllPages() {
        // Reposition all currently rendered pages (e.g., after bounds change)
        for (pageIndex, pageViewInfo) in renderedPages {
            let newFrame = frameForPage(pageIndex)
            
            // Text view frame stays as full page
            pageViewInfo.textView.frame = newFrame
            
            // Recalculate and reposition footnote view if present
            var footnoteHeight: CGFloat = 0
            if let footnoteController = pageViewInfo.footnoteHostingController,
               let version = version {
                let footnotes = layoutManager.getFootnotesForPage(pageIndex, version: version, context: modelContext)
                
                // Use contentRect width for footnotes (respects page margins)
                let contentWidth = pageLayout.contentRect.width
                footnoteHeight = layoutManager.calculateFootnoteHeight(for: footnotes, pageWidth: contentWidth)
                
                // Position footnote view at bottom of content area (inside margins)
                let leftMargin = pageSetup.marginLeft
                let bottomMargin = pageSetup.marginBottom
                
                let footnoteFrame = CGRect(
                    x: newFrame.origin.x + leftMargin,
                    y: newFrame.origin.y + newFrame.height - bottomMargin - footnoteHeight,
                    width: contentWidth,
                    height: footnoteHeight
                )
                footnoteController.view.frame = footnoteFrame
            }
            
            // Update text view insets to account for footnotes
            let topInset = pageSetup.marginTop + (pageSetup.hasHeaders ? pageSetup.headerDepth : 0)
            let baseBottomInset = pageSetup.marginBottom + (pageSetup.hasFooters ? pageSetup.footerDepth : 0)
            let adjustedBottomInset = baseBottomInset + footnoteHeight
            
            pageViewInfo.textView.textContainerInset = UIEdgeInsets(
                top: topInset,
                left: pageSetup.marginLeft,
                bottom: adjustedBottomInset,
                right: pageSetup.marginRight
            )
            
            // Update stored frame
            renderedPages[pageIndex] = PageViewInfo(
                pageIndex: pageIndex,
                textView: pageViewInfo.textView,
                footnoteHostingController: pageViewInfo.footnoteHostingController,
                frame: newFrame
            )
        }
    }
    
    // MARK: - Page View Creation
    
    private func createNewTextView() -> UITextView {
        // Create text storage, layout manager, and text container for paragraph numbering
        let textStorage = NSTextStorage()
        let numberingLayoutManager = NumberingLayoutManager()
        let textContainer = NSTextContainer()
        
        // Pass project reference to layout manager for paragraph numbering
        numberingLayoutManager.project = project
        
        textStorage.addLayoutManager(numberingLayoutManager)
        numberingLayoutManager.addTextContainer(textContainer)
        
        // Create text view with custom layout manager
        let textView = UITextView(frame: .zero, textContainer: textContainer)
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .systemBackground
        
        // Remove default text container padding (5pt on each side)
        textView.textContainer.lineFragmentPadding = 0
        
        // CRITICAL: Prevent container from auto-resizing - we control the size explicitly
        textView.textContainer.widthTracksTextView = false
        textView.textContainer.heightTracksTextView = false
        
        // Calculate insets from page margins (at original 100% size)
        // The text view frame is the full page, so insets represent margins
        let topInset = pageSetup.marginTop + (pageSetup.hasHeaders ? pageSetup.headerDepth : 0)
        let bottomInset = pageSetup.marginBottom + (pageSetup.hasFooters ? pageSetup.footerDepth : 0)
        
        textView.textContainerInset = UIEdgeInsets(
            top: topInset,
            left: pageSetup.marginLeft,
            bottom: bottomInset,
            right: pageSetup.marginRight
        )
        
        // Apply transform to scale the entire text view (including text rendering)
        textView.transform = CGAffineTransform(scaleX: currentZoomScale, y: currentZoomScale)
        
        // Add subtle shadow for depth
        textView.layer.shadowColor = UIColor.black.cgColor
        textView.layer.shadowOpacity = 0.15
        textView.layer.shadowOffset = CGSize(width: 0, height: 3)
        textView.layer.shadowRadius = 6
        textView.layer.masksToBounds = false
        
        // Add subtle border for page definition
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.layer.borderWidth = 0.5
        
        return textView
    }
    
    private func configureTextView(_ textView: UITextView, for pageInfo: PaginatedTextLayoutManager.PageInfo) {
        // Extract ONLY the text for this specific page (substring approach)
        let characterRange = pageInfo.characterRange
        let attributedString = layoutManager.textStorage.attributedSubstring(from: characterRange)
        
        // Process attachments
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
        
        // CRITICAL FIX: Use the SAME container size that was calculated during layout
        // Get the actual container size from the layout manager
        let pageIndex = pageInfo.pageIndex
        if pageIndex < layoutManager.layoutManager.textContainers.count {
            let calculatedContainer = layoutManager.layoutManager.textContainers[pageIndex]
            let containerSize = calculatedContainer.size
            
            // Set the text view's container to match EXACTLY
            textView.textContainer.size = containerSize
            
            #if DEBUG
            print("   📐 Forcing container size: \(containerSize.width) x \(containerSize.height)")
            #endif
        }
        
        // Set ONLY this page's text
        textView.attributedText = mutableString
        
        #if DEBUG
        let preview = String(mutableString.string.prefix(50))
        print("   📝 Set text for page \(pageInfo.pageIndex): '\(preview)...' (\(mutableString.length) chars)")
        #endif
    }
    
    // MARK: - Page View Recycling
    
    private func dequeueReusableTextView() -> UITextView? {
        return pageViewCache.popLast()
    }
    
    private func enqueueTextView(_ textView: UITextView) {
        guard pageViewCache.count < maxCacheSize else { return }
        
        // Clear the text view
        textView.attributedText = nil
        textView.text = ""
        
        // Add to cache
        pageViewCache.append(textView)
    }
    
    // MARK: - Page Positioning
    
    private func frameForPage(_ pageIndex: Int) -> CGRect {
        let yPosition = PageLayoutCalculator.yPosition(
            forPage: pageIndex,
            pageSetup: pageSetup,
            pageSpacing: layoutManager.pageSpacing
        )
        
        // Position pages at x=0 (left edge)
        // UIScrollView zoom handles centering via contentInset when content is smaller than viewport
        return CGRect(
            x: 0,
            y: yPosition,
            width: pageLayout.pageRect.width,
            height: pageLayout.pageRect.height
        )
    }
    
    private func pageIndex(at yPosition: CGFloat) -> Int {
        let index = PageLayoutCalculator.pageIndex(
            at: yPosition,
            pageSetup: pageSetup,
            pageSpacing: layoutManager.pageSpacing
        )
        
        guard let result = layoutManager.layoutResult else { return 0 }
        return min(max(0, index), result.totalPages - 1)
    }
    
    // MARK: - UIScrollViewDelegate
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateVisiblePages()
    }
    
    // MARK: - Debug
    
    var debugInfo: String {
        """
        VirtualPageScrollView:
        - Total Pages: \(layoutManager.pageCount)
        - Visible Range: \(visiblePageRange)
        - Rendered Pages: \(renderedPages.count)
        - Current Page: \(currentPageIndex + 1) of \(layoutManager.pageCount)
        - Cache Size: \(pageViewCache.count)
        - Content Size: \(contentSize.width) x \(contentSize.height)
        """
    }
}
