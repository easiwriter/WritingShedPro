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
    /// When true, show actual page numbers in headers/footers. When false (default), show "#" as placeholder.
    var showActualPageNumbers: Bool = false
    @Binding var currentPage: Int
    var onPageChange: ((Int) -> Void)?
    var onZoomChange: ((CGFloat) -> Void)?
    
    /// Read from layoutResult to trigger SwiftUI updates when pages are calculated
    private var calculatedPageCount: Int {
        layoutManager.layoutResult?.pageInfos.count ?? 0
    }
    
    // MARK: - UIViewRepresentable
    
    func makeUIView(context: Context) -> VirtualPageScrollViewImpl {
        let scrollView = VirtualPageScrollViewImpl(
            layoutManager: layoutManager,
            pageSetup: pageSetup,
            version: version,
            modelContext: modelContext,
            project: project,
            showActualPageNumbers: showActualPageNumbers
        )
        scrollView.pageChangeHandler = { page in
            DispatchQueue.main.async {
                currentPage = page
            }
            onPageChange?(page)
        }
        scrollView.zoomChangeHandler = { zoom in
            onZoomChange?(zoom)
        }
        scrollView.updateZoomScale(zoomScale)
        return scrollView
    }
    
    func updateUIView(_ uiView: VirtualPageScrollViewImpl, context: Context) {
        // Access calculatedPageCount to ensure SwiftUI observes layoutResult changes
        _ = calculatedPageCount
        
        // Update if layout manager or page setup changed
        uiView.updateLayout(layoutManager: layoutManager, pageSetup: pageSetup, version: version, modelContext: modelContext, project: project, showActualPageNumbers: showActualPageNumbers)
        // Update zoom scale to adjust content insets
        uiView.updateZoomScale(zoomScale)
    }
}

// MARK: - UIScrollView Implementation

/// UIScrollView subclass that implements virtual page scrolling
class VirtualPageScrollViewImpl: UIScrollView, UIScrollViewDelegate {
    
    // MARK: - Header/Footer Rendering
    
    /// Resolve placeholder tokens in header/footer text
    /// Supported placeholders: {{Date}}, {{Page Number}}, {{Folder}}, {{Project Name}}, {{Author}}
    private func resolvePlaceholders(_ text: String?, pageNumber: Int, totalPages: Int, showActualPageNumbers: Bool) -> String {
        guard let text = text, !text.isEmpty else { return "" }
        
        var result = text
        
        // {{Date}} - Current date
        if result.contains("{{Date}}") {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            result = result.replacingOccurrences(of: "{{Date}}", with: formatter.string(from: Date()))
        }
        
        // {{Page Number}} - Current page (or "#" placeholder if not showing actual numbers)
        if result.contains("{{Page Number}}") {
            let pageDisplay = showActualPageNumbers ? "\(pageNumber)" : "#"
            result = result.replacingOccurrences(of: "{{Page Number}}", with: pageDisplay)
        }
        
        // {{Folder}} - Source folder name (use project type folder name)
        if result.contains("{{Folder}}") {
            let folderName: String
            switch project?.type {
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
            let projectName = project?.name ?? ""
            result = result.replacingOccurrences(of: "{{Project Name}}", with: projectName)
        }
        
        return result
    }
    
    /// Create header or footer view using proper layout rect and resolved placeholders
    private func makeHeaderFooterView(
        left: String?,
        center: String?,
        right: String?,
        rect: CGRect,
        pageNumber: Int,
        totalPages: Int,
        showActualPageNumbers: Bool
    ) -> UIView {
        let container = UIView(frame: rect)
        container.backgroundColor = .clear
        
        // Resolve placeholders in each field
        let leftText = resolvePlaceholders(left, pageNumber: pageNumber, totalPages: totalPages, showActualPageNumbers: showActualPageNumbers)
        let centerText = resolvePlaceholders(center, pageNumber: pageNumber, totalPages: totalPages, showActualPageNumbers: showActualPageNumbers)
        let rightText = resolvePlaceholders(right, pageNumber: pageNumber, totalPages: totalPages, showActualPageNumbers: showActualPageNumbers)
        
        let labelHeight: CGFloat = min(rect.height, 24)
        let verticalCenter = (rect.height - labelHeight) / 2
        
        let leftLabel = UILabel()
        leftLabel.text = leftText
        leftLabel.font = UIFont.systemFont(ofSize: 12)
        leftLabel.textColor = .secondaryLabel
        leftLabel.textAlignment = .left
        leftLabel.frame = CGRect(x: 0, y: verticalCenter, width: rect.width / 3, height: labelHeight)
        
        let centerLabel = UILabel()
        centerLabel.text = centerText
        centerLabel.font = UIFont.systemFont(ofSize: 12)
        centerLabel.textColor = .secondaryLabel
        centerLabel.textAlignment = .center
        centerLabel.frame = CGRect(x: rect.width / 3, y: verticalCenter, width: rect.width / 3, height: labelHeight)
        
        let rightLabel = UILabel()
        rightLabel.text = rightText
        rightLabel.font = UIFont.systemFont(ofSize: 12)
        rightLabel.textColor = .secondaryLabel
        rightLabel.textAlignment = .right
        rightLabel.frame = CGRect(x: 2 * rect.width / 3, y: verticalCenter, width: rect.width / 3, height: labelHeight)
        
        container.addSubview(leftLabel)
        container.addSubview(centerLabel)
        container.addSubview(rightLabel)
        return container
    }
    
    // MARK: - Types
    
    private struct PageViewInfo {
        let pageIndex: Int
        let textView: UITextView
        let footnoteHostingController: UIHostingController<FootnoteRenderer>?
        let headerView: UIView?
        let footerView: UIView?
        let pageBackgroundView: UIView
        let frame: CGRect
        let isLoadingPlaceholder: Bool
        
        init(pageIndex: Int, textView: UITextView, footnoteHostingController: UIHostingController<FootnoteRenderer>?, headerView: UIView?, footerView: UIView?, pageBackgroundView: UIView, frame: CGRect, isLoadingPlaceholder: Bool = false) {
            self.pageIndex = pageIndex
            self.textView = textView
            self.footnoteHostingController = footnoteHostingController
            self.headerView = headerView
            self.footerView = footerView
            self.pageBackgroundView = pageBackgroundView
            self.frame = frame
            self.isLoadingPlaceholder = isLoadingPlaceholder
        }
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
    
    /// Loading placeholder views (pageIndex -> view)
    private var loadingPlaceholders: [Int: UIView] = [:]
    
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

    /// Whether to show actual page numbers (true) or "#" placeholder (false)
    private var showActualPageNumbers: Bool = false
    
    // MARK: - Initialization
    
    init(layoutManager: PaginatedTextLayoutManager, pageSetup: PageSetup, version: Version?, modelContext: ModelContext, project: Project?, showActualPageNumbers: Bool = false) {
        self.layoutManager = layoutManager
        self.pageSetup = pageSetup
        self.pageLayout = PageLayoutCalculator.calculateLayout(from: pageSetup)
        self.version = version
        self.modelContext = modelContext
        self.project = project
        self.showActualPageNumbers = showActualPageNumbers
        
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
        #if DEBUG
        print("   contentSize: \(contentSize)")
        #endif
        #if DEBUG
        print("   contentOffset: \(contentOffset)")
        #endif
        #if DEBUG
        print("   contentInset: \(contentInset)")
        #endif
        #if DEBUG
        print("   zoomContainerView.frame: \(zoomContainerView.frame)")
        #endif
        #if DEBUG
        print("   bounds: \(bounds)")
        #endif
        #endif
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        #if DEBUG
        print("📐 layoutSubviews called")
        #if DEBUG
        print("   bounds: \(bounds)")
        #endif
        #if DEBUG
        print("   contentSize: \(contentSize)")
        #endif
        #if DEBUG
        print("   contentOffset: \(contentOffset)")
        #endif
        #if DEBUG
        print("   contentInset: \(contentInset)")
        #endif
        #if DEBUG
        print("   zoomContainerView.frame: \(zoomContainerView.frame)")
        #endif
        #endif
        
        // Force scroll position to top-left if content is wider than viewport
        if zoomContainerView.frame.width >= bounds.width && contentOffset.x != 0 {
            #if DEBUG
            print("⚠️ Correcting contentOffset.x from \(contentOffset.x) to 0")
            #endif
            contentOffset.x = 0
        }
        
        // Center content after bounds are established
        centerContentIfNeeded()
        
        // Update visible pages based on new bounds
        updateVisiblePages()
    }
    
    // MARK: - Layout Updates
    
    /// Track the last seen page count to detect when more pages become available
    private var lastSeenPageCount: Int = 0
    
    func updateLayout(layoutManager: PaginatedTextLayoutManager, pageSetup: PageSetup, version: Version?, modelContext: ModelContext, project: Project?, showActualPageNumbers: Bool = false) {
        let isNewLayoutManager = self.layoutManager !== layoutManager
        let pageSetupChanged = self.pageSetup != pageSetup
        
        // Update references
        self.layoutManager = layoutManager
        self.pageSetup = pageSetup
        self.pageLayout = PageLayoutCalculator.calculateLayout(from: pageSetup)
        self.version = version
        self.modelContext = modelContext
        self.project = project
        self.showActualPageNumbers = showActualPageNumbers
        
        // If layout manager or page setup changed, clear all pages and recalculate
        if isNewLayoutManager || pageSetupChanged {
            clearAllPages()
            
            // Recalculate layout with new page setup (pass version and context for footnote-aware layout)
            if !layoutManager.isLayoutValid {
                layoutManager.calculateLayout(version: version, context: modelContext)
            }
        }
        
        // Update scroll view content size
        if let result = layoutManager.layoutResult {
            // Check if content size changed (more pages calculated)
            if result.contentSize != baseContentSize {
                baseContentSize = result.contentSize
                // Update content size with current zoom
                zoomContainerView.frame = CGRect(origin: .zero, size: baseContentSize)
                contentSize = CGSize(
                    width: baseContentSize.width * currentZoomScale,
                    height: baseContentSize.height * currentZoomScale
                )
            }
            
            // Check if more pages are now available
            let currentPageCount = result.pageInfos.count
            if currentPageCount > lastSeenPageCount {
                lastSeenPageCount = currentPageCount
            }
        }
        
        // Update visible pages (this will replace loading placeholders with real content)
        updateVisiblePages()
    }
    
    func updateZoomScale(_ scale: CGFloat) {
        currentZoomScale = scale
        if zoomScale != scale {
            setZoomScale(scale, animated: false)
        }
        // Always center content (needed for initial display and after layout updates)
        centerContentIfNeeded()
    }
    
    /// Center content horizontally/vertically when smaller than viewport
    private func centerContentIfNeeded() {
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
        
        contentInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
    }
    
    // MARK: - UIScrollViewDelegate (Zoom)
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return zoomContainerView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        currentZoomScale = scrollView.zoomScale
        zoomChangeHandler?(scrollView.zoomScale)
        
        // Center content using shared method
        centerContentIfNeeded()
        
        #if DEBUG
        print("🔍 Zoom changed to \(String(format: "%.0f%%", scrollView.zoomScale * 100))")
        #if DEBUG
        print("   contentSize: \(zoomContainerView.frame.size)")
        #endif
        #if DEBUG
        print("   boundsSize: \(bounds.size)")
        #endif
        #if DEBUG
        print("   contentInset: \(scrollView.contentInset)")
        #endif
        #if DEBUG
        print("   contentOffset: \(scrollView.contentOffset)")
        #endif
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
        
        // Remove pages outside new range
        let pagesToRemove = Set(renderedPages.keys).subtracting(Set(newRange))
        for pageIndex in pagesToRemove {
            removePage(at: pageIndex)
        }
        
        // Also remove loading placeholders outside new range
        let placeholdersToRemove = Set(loadingPlaceholders.keys).subtracting(Set(newRange))
        for pageIndex in placeholdersToRemove {
            removeLoadingPlaceholder(at: pageIndex)
        }
        
        // Check if any loading placeholders can now be replaced with actual content
        for pageIndex in loadingPlaceholders.keys {
            if layoutManager.pageInfo(forPage: pageIndex) != nil {
                // Page is now available - remove placeholder and create real page
                removeLoadingPlaceholder(at: pageIndex)
                createPage(at: pageIndex)
            }
        }
        
        // Add pages in new range (either real content or loading placeholder)
        for pageIndex in newRange where renderedPages[pageIndex] == nil && loadingPlaceholders[pageIndex] == nil {
            createPage(at: pageIndex)
        }
        
        visiblePageRange = newRange
    }
    
    private func createPage(at pageIndex: Int) {
        // Get page frame for this page index
        let pageFrame = frameForPage(pageIndex)
        
        // Check if this page has been calculated yet
        guard let pageInfo = layoutManager.pageInfo(forPage: pageIndex) else {
            // Page not calculated yet - show a loading placeholder
            createLoadingPlaceholder(at: pageIndex, frame: pageFrame)
            return
        }
        
        let totalPages = layoutManager.pageCount
        // Display page number is 1-based
        let displayPageNumber = pageIndex + 1
        
        #if DEBUG
        if pageIndex == 0 {
            print("📄 Header/Footer Debug:")
            print("   hasHeaders: \(pageSetup.hasHeaders), hasFooters: \(pageSetup.hasFooters)")
            print("   headerLeft: '\(pageSetup.headerLeft ?? "nil")', headerCenter: '\(pageSetup.headerCenter ?? "nil")', headerRight: '\(pageSetup.headerRight ?? "nil")'")
            print("   footerLeft: '\(pageSetup.footerLeft ?? "nil")', footerCenter: '\(pageSetup.footerCenter ?? "nil")', footerRight: '\(pageSetup.footerRight ?? "nil")'")
            print("   project name: '\(project?.name ?? "nil")'")
            print("   showActualPageNumbers: \(showActualPageNumbers)")
        }
        #endif
        
        // Create page background view to cover full page (white paper appearance)
        let pageBackgroundView = UIView(frame: pageFrame)
        pageBackgroundView.backgroundColor = .systemBackground
        pageBackgroundView.layer.shadowColor = UIColor.black.cgColor
        pageBackgroundView.layer.shadowOffset = CGSize(width: 0, height: 2)
        pageBackgroundView.layer.shadowOpacity = 0.1
        pageBackgroundView.layer.shadowRadius = 4
        zoomContainerView.addSubview(pageBackgroundView)
        
        // Track header/footer views for cleanup
        var headerView: UIView? = nil
        var footerView: UIView? = nil
        
        // Render header view if enabled, using proper layout rect
        if pageSetup.hasHeaders, let headerRect = pageLayout.headerRect {
            // Offset headerRect to page position
            let adjustedHeaderRect = CGRect(
                x: pageFrame.origin.x + headerRect.origin.x,
                y: pageFrame.origin.y + headerRect.origin.y,
                width: headerRect.width,
                height: headerRect.height
            )
            headerView = makeHeaderFooterView(
                left: pageSetup.headerLeft,
                center: pageSetup.headerCenter,
                right: pageSetup.headerRight,
                rect: adjustedHeaderRect,
                pageNumber: displayPageNumber,
                totalPages: totalPages,
                showActualPageNumbers: showActualPageNumbers
            )
            zoomContainerView.addSubview(headerView!)
        }
        
        // Render footer view if enabled, using proper layout rect
        if pageSetup.hasFooters, let footerRect = pageLayout.footerRect {
            // Offset footerRect to page position
            let adjustedFooterRect = CGRect(
                x: pageFrame.origin.x + footerRect.origin.x,
                y: pageFrame.origin.y + footerRect.origin.y,
                width: footerRect.width,
                height: footerRect.height
            )
            footerView = makeHeaderFooterView(
                left: pageSetup.footerLeft,
                center: pageSetup.footerCenter,
                right: pageSetup.footerRight,
                rect: adjustedFooterRect,
                pageNumber: displayPageNumber,
                totalPages: totalPages,
                showActualPageNumbers: showActualPageNumbers
            )
            zoomContainerView.addSubview(footerView!)
        }
        
        // Query footnotes for this page FIRST (needed to calculate text area)
        var footnoteController: UIHostingController<FootnoteRenderer>? = nil
        var footnoteHeight: CGFloat = 0
        
        if let version = version {
            let footnotes = layoutManager.getFootnotesForPage(pageIndex, version: version, context: modelContext)
            
            #if DEBUG
            if !footnotes.isEmpty {
                #if DEBUG
                print("📄 Page \(pageIndex): Found \(footnotes.count) footnotes")
                #endif
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
        // Headers/footers are rendered in the margin areas, so we only use page margins for insets
        let topInset = pageSetup.marginTop
        let leftInset = pageSetup.marginLeft
        let rightInset = pageSetup.marginRight
        let bottomInset = pageSetup.marginBottom
        
        // Text view covers from top of page to bottom margin
        let textViewHeight = pageFrame.height - bottomInset
        
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
            #if DEBUG
            print("   📐 Footnote space reserved: \(footnoteHeight)pt")
            #endif
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
            #if DEBUG
            print("📏 Page frame: \(pageFrame), leftMargin: \(leftMargin), bottomMargin: \(bottomMargin)")
            #endif
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
            headerView: headerView,
            footerView: footerView,
            pageBackgroundView: pageBackgroundView,
            frame: pageFrame
        )
        renderedPages[pageIndex] = pageViewInfo
    }
    
    /// Create a loading placeholder for a page that hasn't been calculated yet
    private func createLoadingPlaceholder(at pageIndex: Int, frame: CGRect) {
        // Don't create duplicate placeholders
        guard loadingPlaceholders[pageIndex] == nil else { return }
        
        // Create page background with loading indicator
        let placeholderView = UIView(frame: frame)
        placeholderView.backgroundColor = .systemBackground
        placeholderView.layer.shadowColor = UIColor.black.cgColor
        placeholderView.layer.shadowOffset = CGSize(width: 0, height: 2)
        placeholderView.layer.shadowOpacity = 0.1
        placeholderView.layer.shadowRadius = 4
        
        // Add activity indicator centered on the page
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.center = CGPoint(x: frame.width / 2, y: frame.height / 2)
        activityIndicator.startAnimating()
        placeholderView.addSubview(activityIndicator)
        
        zoomContainerView.addSubview(placeholderView)
        loadingPlaceholders[pageIndex] = placeholderView
    }
    
    /// Remove a loading placeholder and replace with actual content if available
    private func removeLoadingPlaceholder(at pageIndex: Int) {
        if let placeholder = loadingPlaceholders[pageIndex] {
            placeholder.removeFromSuperview()
            loadingPlaceholders.removeValue(forKey: pageIndex)
        }
    }
    
    private func removePage(at pageIndex: Int) {
        // Remove loading placeholder if it exists
        removeLoadingPlaceholder(at: pageIndex)
        
        guard let pageViewInfo = renderedPages[pageIndex] else { return }
        
        // Remove page background from view hierarchy
        pageViewInfo.pageBackgroundView.removeFromSuperview()
        
        // Remove text view from view hierarchy
        pageViewInfo.textView.removeFromSuperview()
        
        // Clean up footnote hosting controller if present
        if let footnoteController = pageViewInfo.footnoteHostingController {
            footnoteController.view.removeFromSuperview()
        }
        
        // Clean up header view if present
        if let headerView = pageViewInfo.headerView {
            headerView.removeFromSuperview()
        }
        
        // Clean up footer view if present
        if let footerView = pageViewInfo.footerView {
            footerView.removeFromSuperview()
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
        // Also clear any loading placeholders
        for pageIndex in loadingPlaceholders.keys {
            removeLoadingPlaceholder(at: pageIndex)
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
            
            // Reposition page background view
            pageViewInfo.pageBackgroundView.frame = newFrame
            
            // Reposition header view if present
            if let headerView = pageViewInfo.headerView, let headerRect = pageLayout.headerRect {
                headerView.frame = CGRect(
                    x: newFrame.origin.x + headerRect.origin.x,
                    y: newFrame.origin.y + headerRect.origin.y,
                    width: headerRect.width,
                    height: headerRect.height
                )
            }
            
            // Reposition footer view if present
            if let footerView = pageViewInfo.footerView, let footerRect = pageLayout.footerRect {
                footerView.frame = CGRect(
                    x: newFrame.origin.x + footerRect.origin.x,
                    y: newFrame.origin.y + footerRect.origin.y,
                    width: footerRect.width,
                    height: footerRect.height
                )
            }
            
            // Update stored frame
            renderedPages[pageIndex] = PageViewInfo(
                pageIndex: pageIndex,
                textView: pageViewInfo.textView,
                footnoteHostingController: pageViewInfo.footnoteHostingController,
                headerView: pageViewInfo.headerView,
                footerView: pageViewInfo.footerView,
                pageBackgroundView: pageViewInfo.pageBackgroundView,
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
        // Disable poetry line numbers in paginated manuscript view
        numberingLayoutManager.isPaginatedView = false
        
        textStorage.addLayoutManager(numberingLayoutManager)
        numberingLayoutManager.addTextContainer(textContainer)
        
        // Create text view with custom layout manager
        let textView = UITextView(frame: .zero, textContainer: textContainer)
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear  // Page background is now a separate view
        
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
        
        // No border - clean page appearance
        textView.layer.borderWidth = 0
        
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
            } else if let referenceAttachment = attachment as? ReferenceAttachment {
                // Mark reference attachments for page view rendering (black color, not blue)
                referenceAttachment.isForPageView = true
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
        
        // Set starting line number for poetry projects (for continuous numbering across pages)
        if let numberingLayoutManager = textView.layoutManager as? NumberingLayoutManager,
           project?.type == .poetry {
            let startingLineNumber = calculatePoetryStartingLineNumber(forPage: pageIndex)
            numberingLayoutManager.poetryStartingLineNumber = startingLineNumber
        }
        
        #if DEBUG
        let preview = String(mutableString.string.prefix(50))
        #if DEBUG
        print("   📝 Set text for page \(pageInfo.pageIndex): '\(preview)...' (\(mutableString.length) chars)")
        #endif
        #endif
    }
    
    /// Calculate the starting poetry line number for a given page
    /// by counting numbered lines in all preceding pages
    private func calculatePoetryStartingLineNumber(forPage pageIndex: Int) -> Int {
        guard pageIndex > 0 else { return 1 }
        
        var lineCount = 0
        let fullText = layoutManager.textStorage.string as NSString
        
        // Count numbered lines in all pages before this one
        for prevPage in 0..<pageIndex {
            guard let prevPageInfo = layoutManager.pageInfo(forPage: prevPage) else { continue }
            
            let pageText = fullText.substring(with: prevPageInfo.characterRange) as NSString
            let pageRange = NSRange(location: 0, length: pageText.length)
            
            pageText.enumerateSubstrings(in: pageRange, options: .byParagraphs) { substring, paragraphRange, _, _ in
                // Skip blank lines
                let lineText = substring ?? ""
                if lineText.trimmingCharacters(in: .whitespaces).isEmpty {
                    return
                }
                
                // Check if this line is marked as excluded
                // We need to check the original attributed string for the poemSectionType attribute
                let originalLocation = prevPageInfo.characterRange.location + paragraphRange.location
                if originalLocation < self.layoutManager.textStorage.length {
                    if let sectionType = self.layoutManager.textStorage.attribute(.poemSectionType, at: originalLocation, effectiveRange: nil) as? String,
                       sectionType != PoemSectionType.poem.rawValue {
                        // This line is excluded - don't count it
                        return
                    }
                }
                
                lineCount += 1
            }
        }
        
        return lineCount + 1
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
