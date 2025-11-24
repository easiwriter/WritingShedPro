//
//  PaginatedDocumentView.swift
//  Writing Shed Pro
//
//  SwiftUI view for paginated document display
//  Integrates layout manager and virtual scrolling
//

import SwiftUI
import SwiftData

/// Main paginated document view
struct PaginatedDocumentView: View {
    
    // MARK: - Properties
    
    let textFile: TextFile
    let project: Project
    
    @Environment(\.modelContext) private var modelContext
    
    @State private var layoutManager: PaginatedTextLayoutManager?
    @State private var currentPage: Int = 0
    @State private var zoomScale: CGFloat = 1.0
    @State private var isCalculatingLayout: Bool = false
    
    // Global page setup (from UserDefaults)
    private let pageSetupPrefs = PageSetupPreferences.shared
    
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
                        // Virtual page scroll view using global page setup
                        let pageSetup = pageSetupPrefs.createPageSetup()
                        VirtualPageScrollView(
                            layoutManager: layoutManager,
                            pageSetup: pageSetup,
                            zoomScale: 1.0, // Always render at 100%
                            version: textFile.currentVersion,
                            modelContext: modelContext,
                            project: project,
                            currentPage: $currentPage
                        )
                        .frame(
                            width: geometry.size.width / zoomScale,
                            height: geometry.size.height / zoomScale
                        )
                        .scaleEffect(zoomScale, anchor: .center)
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height
                        )
                        .clipped()
                        .accessibilityLabel("paginatedDocument.pages.accessibility")
                        .accessibilityHint("paginatedDocument.pages.hint")
                        .accessibilityAddTraits(.allowsDirectInteraction)
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
            print("📱 PaginatedDocumentView appeared")
            print("   - currentVersionIndex: \(textFile.currentVersionIndex)")
            // Always recalculate on appear in case version changed while in edit mode
            if layoutManager != nil {
                print("   - Recalculating layout on appear")
                recalculateLayout()
            } else {
                setupLayoutManager()
            }
        }
        .onChange(of: textFile.currentVersionIndex) { oldValue, newValue in
            print("🔀 Version index changed: \(oldValue) → \(newValue)")
            // Version changed - recalculate layout with new content
            recalculateLayout()
        }
        .onChange(of: textFile.currentVersion?.content) { oldValue, newValue in
            print("📝 Version content changed: \(oldValue?.count ?? 0) → \(newValue?.count ?? 0)")
            recalculateLayout()
        }
        // Note: Page setup is now global (UserDefaults), changes require app restart
        .onChange(of: project.styleSheet?.modifiedDate) { _, _ in
            print("🎨 Stylesheet modified")
            // Stylesheet changed - need to re-render pages with new styles
            // This affects footnote rendering in pagination view
            recalculateLayout()
        }
    }
    
    // MARK: - Page Indicator Toolbar
    
    private var pageIndicatorToolbar: some View {
        HStack(spacing: 12) {
            // Page info
            if let layoutManager = layoutManager, layoutManager.isLayoutValid {
                Label {
                    Text("paginatedDocument.pageIndicator \(currentPage + 1) \(layoutManager.pageCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                } icon: {
                    Image(systemName: "doc.text")
                        .font(.caption)
                        .imageScale(.small)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(format: NSLocalizedString("paginatedDocument.pageIndicator.accessibility", comment: "Page indicator"), currentPage + 1, layoutManager.pageCount))
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
            .accessibilityLabel("paginatedDocument.zoomOut.accessibility")
            .accessibilityHint(String(format: NSLocalizedString("paginatedDocument.zoomOut.hint", comment: "Zoom out hint"), Int((zoomScale - 0.1) * 100)))
            
            Text("\(Int(zoomScale * 100))%")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .frame(minWidth: 50)
                .fixedSize()
                .accessibilityLabel(String(format: NSLocalizedString("paginatedDocument.zoomLevel.accessibility", comment: "Zoom level"), Int(zoomScale * 100)))
            
            Button {
                zoomIn()
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.body)
                    .imageScale(.medium)
                    .frame(width: 24, height: 24)
            }
            .disabled(zoomScale >= 2.0)
            .accessibilityLabel("paginatedDocument.zoomIn.accessibility")
            .accessibilityHint(String(format: NSLocalizedString("paginatedDocument.zoomIn.hint", comment: "Zoom in hint"), Int((zoomScale + 0.1) * 100)))
            
            Button {
                resetZoom()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.body)
                    .imageScale(.medium)
                    .frame(width: 24, height: 24)
            }
            .disabled(zoomScale == 1.0)
            .accessibilityLabel("paginatedDocument.resetZoom.accessibility")
            .accessibilityHint("paginatedDocument.resetZoom.hint")
        }
        .fixedSize()
        .accessibilityElement(children: .contain)
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("paginatedDocument.noPageSetup.title", systemImage: "doc.text")
        } description: {
            Text("paginatedDocument.noPageSetup.description")
        }
    }
    
    // MARK: - Layout Management
    
    private func setupLayoutManager() {
        print("🔧 setupLayoutManager called")
        print("   - currentVersionIndex: \(textFile.currentVersionIndex)")
        print("   - currentVersion: \(textFile.currentVersion?.id.uuidString.prefix(8) ?? "nil")")
        
        guard let content = textFile.currentVersion?.content else {
            print("   ❌ No currentVersion content")
            return
        }
        
        // Use global page setup from UserDefaults
        let pageSetup = pageSetupPrefs.createPageSetup()
        
        print("   - content length: \(content.count)")
        
        isCalculatingLayout = true
        
        // Create text storage from attributed content to preserve formatting
        let attributedContent = textFile.currentVersion?.attributedContent ?? NSAttributedString(string: content)
        let textStorage = NSTextStorage(attributedString: attributedContent)
        
        // Create layout manager
        let manager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        // Calculate layout (async to avoid blocking UI)
        DispatchQueue.global(qos: .userInitiated).async {
            let _ = manager.calculateLayout()
            print("   ✅ Layout calculated: \(manager.pageCount) pages")
            
            DispatchQueue.main.async {
                self.layoutManager = manager
                self.isCalculatingLayout = false
                print("   ✅ Layout manager assigned")
            }
        }
    }
    
    private func recalculateLayout() {
        print("🔄 recalculateLayout called")
        print("   - currentVersionIndex: \(textFile.currentVersionIndex)")
        print("   - currentVersion: \(textFile.currentVersion?.id.uuidString.prefix(8) ?? "nil")")
        print("   - content length: \(textFile.currentVersion?.content.count ?? 0)")
        
        // Use global page setup from UserDefaults
        let pageSetup = pageSetupPrefs.createPageSetup()
        
        if let existingManager = layoutManager {
            print("   ♻️ Updating existing manager")
            
            // Update text content from current version (preserve formatting)
            if let content = textFile.currentVersion?.content {
                print("   📝 Updating textStorage with new content")
                let attributedContent = textFile.currentVersion?.attributedContent ?? NSAttributedString(string: content)
                existingManager.textStorage.replaceCharacters(
                    in: NSRange(location: 0, length: existingManager.textStorage.length),
                    with: attributedContent
                )
            }
            
            existingManager.updatePageSetup(pageSetup)
            
            isCalculatingLayout = true
            DispatchQueue.global(qos: .userInitiated).async {
                let _ = existingManager.calculateLayout()
                print("   ✅ Recalculated: \(existingManager.pageCount) pages")
                
                DispatchQueue.main.async {
                    self.isCalculatingLayout = false
                    print("   ✅ Recalculation complete")
                }
            }
        } else {
            print("   🆕 Creating new layout manager")
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
