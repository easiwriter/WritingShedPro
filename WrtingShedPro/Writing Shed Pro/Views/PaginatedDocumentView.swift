//
//  PaginatedDocumentView.swift
//  Writing Shed Pro
//
//  SwiftUI view for paginated document display
//  Integrates layout manager and virtual scrolling
//

import SwiftUI

/// Main paginated document view
struct PaginatedDocumentView: View {
    
    // MARK: - Properties
    
    let textFile: TextFile
    let project: Project
    
    @State private var layoutManager: PaginatedTextLayoutManager?
    @State private var currentPage: Int = 0
    @State private var zoomScale: CGFloat = 1.0
    @State private var isCalculatingLayout: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background color for the entire view
            Color(uiColor: .systemGray6)
                .ignoresSafeArea()
            
            // Main content layer
            if let layoutManager = layoutManager, layoutManager.isLayoutValid {
                GeometryReader { geometry in
                    ZStack {
                        // Virtual page scroll view
                        if let pageSetup = project.pageSetup {
                            VirtualPageScrollView(
                                layoutManager: layoutManager,
                                pageSetup: pageSetup,
                                zoomScale: zoomScale,
                                currentPage: $currentPage
                            )
                            .frame(
                                width: geometry.size.width,
                                height: geometry.size.height
                            )
                            .scaleEffect(zoomScale, anchor: .center)
                            .frame(
                                width: geometry.size.width,
                                height: geometry.size.height
                            )
                            .accessibilityLabel("Document pages")
                            .accessibilityHint("Use zoom controls to adjust view size, scroll to navigate pages")
                            .accessibilityAddTraits(.allowsDirectInteraction)
                        } else {
                            emptyStateView
                        }
                    }
                }
            } else if isCalculatingLayout {
                ProgressView("Calculating pages...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                emptyStateView
            }
            
            // Toolbar overlay - stays on top regardless of content scale
            VStack {
                pageIndicatorToolbar
                Spacer()
            }
        }
        .onAppear {
            setupLayoutManager()
        }
        .onChange(of: textFile.currentVersion?.content) { _, _ in
            recalculateLayout()
        }
        .onChange(of: project.pageSetup) { _, _ in
            recalculateLayout()
        }
    }
    
    // MARK: - Page Indicator Toolbar
    
    private var pageIndicatorToolbar: some View {
        HStack(spacing: 12) {
            // Page info
            if let layoutManager = layoutManager, layoutManager.isLayoutValid {
                Label {
                    Text("Page \(currentPage + 1) of \(layoutManager.pageCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                } icon: {
                    Image(systemName: "doc.text")
                        .font(.caption)
                        .imageScale(.small)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Page \(currentPage + 1) of \(layoutManager.pageCount)")
                .layoutPriority(1)
                
                Spacer(minLength: 8)
                
                // Zoom controls
                zoomControls
                    .layoutPriority(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .bottom) {
            Divider()
        }
        .accessibilityElement(children: .contain)
    }
    
    private var zoomControls: some View {
        HStack(spacing: 8) {
            Button {
                zoomOut()
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.body)
                    .imageScale(.medium)
                    .frame(width: 24, height: 24)
            }
            .disabled(zoomScale <= 0.5)
            .accessibilityLabel("Zoom Out")
            .accessibilityHint("Decreases zoom to \(Int((zoomScale - 0.1) * 100))%")
            
            Text("\(Int(zoomScale * 100))%")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .frame(minWidth: 50)
                .fixedSize()
                .accessibilityLabel("Zoom level: \(Int(zoomScale * 100)) percent")
            
            Button {
                zoomIn()
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.body)
                    .imageScale(.medium)
                    .frame(width: 24, height: 24)
            }
            .disabled(zoomScale >= 2.0)
            .accessibilityLabel("Zoom In")
            .accessibilityHint("Increases zoom to \(Int((zoomScale + 0.1) * 100))%")
            
            Button {
                resetZoom()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.body)
                    .imageScale(.medium)
                    .frame(width: 24, height: 24)
            }
            .disabled(zoomScale == 1.0)
            .accessibilityLabel("Reset Zoom")
            .accessibilityHint("Resets zoom to 100%")
        }
        .fixedSize()
        .accessibilityElement(children: .contain)
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Page Setup", systemImage: "doc.text")
        } description: {
            Text("Configure page setup in project settings to enable pagination view.")
        }
    }
    
    // MARK: - Layout Management
    
    private func setupLayoutManager() {
        guard let content = textFile.currentVersion?.content else { return }
        guard let pageSetup = project.pageSetup else { return }
        
        isCalculatingLayout = true
        
        // Create text storage from content
        let textStorage = NSTextStorage(string: content)
        
        // Create layout manager
        let manager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        // Calculate layout (async to avoid blocking UI)
        DispatchQueue.global(qos: .userInitiated).async {
            let _ = manager.calculateLayout()
            
            DispatchQueue.main.async {
                self.layoutManager = manager
                self.isCalculatingLayout = false
            }
        }
    }
    
    private func recalculateLayout() {
        guard let pageSetup = project.pageSetup else { return }
        
        if let existingManager = layoutManager {
            existingManager.updatePageSetup(pageSetup)
            
            isCalculatingLayout = true
            DispatchQueue.global(qos: .userInitiated).async {
                let _ = existingManager.calculateLayout()
                
                DispatchQueue.main.async {
                    self.isCalculatingLayout = false
                }
            }
        } else {
            setupLayoutManager()
        }
    }
    
    // MARK: - Zoom Controls
    
    private func zoomIn() {
        withAnimation(.easeInOut(duration: 0.2)) {
            zoomScale = min(zoomScale + 0.1, 2.0)
        }
    }
    
    private func zoomOut() {
        withAnimation(.easeInOut(duration: 0.2)) {
            zoomScale = max(zoomScale - 0.1, 0.5)
        }
    }
    
    private func resetZoom() {
        withAnimation(.easeInOut(duration: 0.2)) {
            zoomScale = 1.0
        }
    }
}
