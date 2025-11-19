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
    @GestureState private var magnificationAmount: CGFloat = 1.0
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Page indicator toolbar
            pageIndicatorToolbar
            
            // Main content
            if let layoutManager = layoutManager, layoutManager.isLayoutValid {
                ZStack {
                    // Virtual page scroll view
                    if let pageSetup = project.pageSetup {
                        VirtualPageScrollView(
                            layoutManager: layoutManager,
                            pageSetup: pageSetup,
                            currentPage: $currentPage
                        )
                        .scaleEffect(zoomScale * magnificationAmount)
                        .gesture(
                            MagnificationGesture()
                                .updating($magnificationAmount) { value, state, _ in
                                    state = value.magnitude
                                }
                                .onEnded { value in
                                    // Apply the gesture's final scale to the base zoom scale
                                    let newScale = zoomScale * value.magnitude
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        zoomScale = min(max(newScale, 0.5), 2.0)
                                    }
                                }
                        )
                        .accessibilityLabel("Document pages")
                        .accessibilityHint("Pinch to zoom, scroll to navigate pages")
                        .accessibilityAddTraits(.allowsDirectInteraction)
                    } else {
                        emptyStateView
                    }
                }
            } else if isCalculatingLayout {
                ProgressView("Calculating pages...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                emptyStateView
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
        HStack {
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
                
                Spacer()
                
                // Zoom controls
                zoomControls
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .bottom) {
            Divider()
        }
        .accessibilityElement(children: .contain)
    }
    
    private var zoomControls: some View {
        HStack(spacing: 12) {
            Button {
                zoomOut()
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.caption)
            }
            .disabled(zoomScale <= 0.5)
            .accessibilityLabel("Zoom Out")
            .accessibilityHint("Decreases zoom to \(Int((zoomScale - 0.25) * 100))%")
            
            Text("\(Int(zoomScale * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 40)
                .accessibilityLabel("Zoom level: \(Int(zoomScale * 100)) percent")
            
            Button {
                zoomIn()
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.caption)
            }
            .disabled(zoomScale >= 2.0)
            .accessibilityLabel("Zoom In")
            .accessibilityHint("Increases zoom to \(Int((zoomScale + 0.25) * 100))%")
            
            Button {
                resetZoom()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.caption)
            }
            .disabled(zoomScale == 1.0)
            .accessibilityLabel("Reset Zoom")
            .accessibilityHint("Resets zoom to 100%")
        }
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
            zoomScale = min(zoomScale + 0.25, 2.0)
        }
    }
    
    private func zoomOut() {
        withAnimation(.easeInOut(duration: 0.2)) {
            zoomScale = max(zoomScale - 0.25, 0.5)
        }
    }
    
    private func resetZoom() {
        withAnimation(.easeInOut(duration: 0.2)) {
            zoomScale = 1.0
        }
    }
}
