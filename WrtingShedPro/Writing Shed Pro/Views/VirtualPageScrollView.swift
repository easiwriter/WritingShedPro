//
//  VirtualPageScrollView.swift
//  Writing Shed Pro
//
//  Virtual scrolling view for paginated documents
//  Only renders visible pages for memory efficiency
//

import SwiftUI
import UIKit

/// SwiftUI wrapper for virtual page scrolling
struct VirtualPageScrollView: UIViewRepresentable {
    
    // MARK: - Properties
    
    let layoutManager: PaginatedTextLayoutManager
    let pageSetup: PageSetup
    @Binding var currentPage: Int
    var onPageChange: ((Int) -> Void)?
    
    // MARK: - UIViewRepresentable
    
    func makeUIView(context: Context) -> VirtualPageScrollViewImpl {
        let scrollView = VirtualPageScrollViewImpl(
            layoutManager: layoutManager,
            pageSetup: pageSetup
        )
        scrollView.pageChangeHandler = { page in
            currentPage = page
            onPageChange?(page)
        }
        return scrollView
    }
    
    func updateUIView(_ uiView: VirtualPageScrollViewImpl, context: Context) {
        // Update if layout manager or page setup changed
        uiView.updateLayout(layoutManager: layoutManager, pageSetup: pageSetup)
    }
}

// MARK: - UIScrollView Implementation

/// UIScrollView subclass that implements virtual page scrolling
class VirtualPageScrollViewImpl: UIScrollView, UIScrollViewDelegate {
    
    // MARK: - Types
    
    private struct PageViewInfo {
        let pageIndex: Int
        let textView: UITextView
        let frame: CGRect
    }
    
    // MARK: - Properties
    
    private var layoutManager: PaginatedTextLayoutManager
    private var pageSetup: PageSetup
    private var pageLayout: PageLayoutCalculator.PageLayout
    
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
    
    // MARK: - Initialization
    
    init(layoutManager: PaginatedTextLayoutManager, pageSetup: PageSetup) {
        self.layoutManager = layoutManager
        self.pageSetup = pageSetup
        self.pageLayout = PageLayoutCalculator.calculateLayout(from: pageSetup)
        
        super.init(frame: .zero)
        
        self.delegate = self
        self.backgroundColor = .systemGray6
        self.showsVerticalScrollIndicator = true
        self.showsHorizontalScrollIndicator = false
        
        setupScrollView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupScrollView() {
        // Calculate layout if needed
        if !layoutManager.isLayoutValid {
            layoutManager.calculateLayout()
        }
        
        guard let result = layoutManager.layoutResult else { return }
        
        // Set content size
        contentSize = result.contentSize
        
        // Render initial pages
        updateVisiblePages()
    }
    
    // MARK: - Layout Updates
    
    func updateLayout(layoutManager: PaginatedTextLayoutManager, pageSetup: PageSetup) {
        let needsUpdate = self.layoutManager !== layoutManager || 
                         self.pageSetup !== pageSetup ||
                         !layoutManager.isLayoutValid
        
        guard needsUpdate else { return }
        
        self.layoutManager = layoutManager
        self.pageSetup = pageSetup
        self.pageLayout = PageLayoutCalculator.calculateLayout(from: pageSetup)
        
        // Clear all rendered pages
        clearAllPages()
        
        // Recalculate layout
        if !layoutManager.isLayoutValid {
            layoutManager.calculateLayout()
        }
        
        // Update scroll view
        if let result = layoutManager.layoutResult {
            contentSize = result.contentSize
        }
        
        // Re-render visible pages
        updateVisiblePages()
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
        
        // Get or create text view
        let textView = dequeueReusableTextView() ?? createNewTextView()
        textView.frame = pageFrame
        
        // Configure text view with page content
        configureTextView(textView, for: pageInfo)
        
        // Add to scroll view
        addSubview(textView)
        
        // Store page info
        let pageViewInfo = PageViewInfo(
            pageIndex: pageIndex,
            textView: textView,
            frame: pageFrame
        )
        renderedPages[pageIndex] = pageViewInfo
    }
    
    private func removePage(at pageIndex: Int) {
        guard let pageViewInfo = renderedPages[pageIndex] else { return }
        
        // Remove from view hierarchy
        pageViewInfo.textView.removeFromSuperview()
        
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
    
    // MARK: - Page View Creation
    
    private func createNewTextView() -> UITextView {
        let textView = UITextView(frame: .zero)
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .white
        textView.textContainerInset = UIEdgeInsets(
            top: pageLayout.contentRect.origin.y,
            left: pageLayout.contentRect.origin.x,
            bottom: pageLayout.pageRect.height - pageLayout.contentRect.maxY,
            right: pageLayout.pageRect.width - pageLayout.contentRect.maxX
        )
        
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
        // Get the text for this page
        let characterRange = pageInfo.characterRange
        let attributedString = layoutManager.textStorage.attributedSubstring(from: characterRange)
        
        // Set the text
        textView.attributedText = attributedString
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
        
        return CGRect(
            x: (bounds.width - pageLayout.pageRect.width) / 2,
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
