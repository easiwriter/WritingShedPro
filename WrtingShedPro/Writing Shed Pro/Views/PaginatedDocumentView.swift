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
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var isCalculatingLayout: Bool = false
    @State private var showPrintError = false
    @State private var printErrorMessage = ""
    
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
                // Virtual page scroll view using global page setup
                let pageSetup = pageSetupPrefs.createPageSetup()
                VirtualPageScrollView(
                    layoutManager: layoutManager,
                    pageSetup: pageSetup,
                    zoomScale: zoomScale,
                    version: textFile.currentVersion,
                    modelContext: modelContext,
                    project: project,
                    currentPage: $currentPage,
                    onZoomChange: { newZoom in
                        DispatchQueue.main.async {
                            zoomScale = newZoom
                        }
                    }
                )
                .accessibilityLabel("paginatedDocument.pages.accessibility")
                .accessibilityHint("paginatedDocument.pages.hint")
                .accessibilityAddTraits(.allowsDirectInteraction)
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
            #if DEBUG
            print("📱 PaginatedDocumentView appeared")
            #endif
            #if DEBUG
            print("   - currentVersionIndex: \(textFile.currentVersionIndex)")
            #endif
            // Always recalculate on appear in case version changed while in edit mode
            if layoutManager != nil {
                #if DEBUG
                print("   - Recalculating layout on appear")
                #endif
                recalculateLayout()
            } else {
                setupLayoutManager()
            }
        }
        .onChange(of: textFile.currentVersionIndex) { oldValue, newValue in
            #if DEBUG
            print("🔀 Version index changed: \(oldValue) → \(newValue)")
            #endif
            // Version changed - recalculate layout with new content
            recalculateLayout()
        }
        .onChange(of: textFile.currentVersion?.content) { oldValue, newValue in
            #if DEBUG
            print("📝 Version content changed: \(oldValue?.count ?? 0) → \(newValue?.count ?? 0)")
            #endif
            recalculateLayout()
        }
        // Note: Page setup is now global (UserDefaults), changes require app restart
        .onChange(of: project.styleSheet?.modifiedDate) { _, _ in
            #if DEBUG
            print("🎨 Stylesheet modified")
            #endif
            // Stylesheet changed - need to re-render pages with new styles
            // This affects footnote rendering in pagination view
            recalculateLayout()
        }
        .alert("Print Error", isPresented: $showPrintError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(printErrorMessage)
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
            
            Divider()
                .frame(height: 24)
            
            // Print button
            Button {
                printDocument()
            } label: {
                Image(systemName: "printer")
                    .font(.body)
                    .imageScale(.medium)
                    .frame(width: 24, height: 24)
            }
            .disabled(!PrintService.isPrintingAvailable())
            .accessibilityLabel("paginatedDocument.print.accessibility")
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
        #if DEBUG
        print("🔧 setupLayoutManager called")
        #endif
        #if DEBUG
        print("   - currentVersionIndex: \(textFile.currentVersionIndex)")
        #endif
        #if DEBUG
        print("   - currentVersion: \(textFile.currentVersion?.id.uuidString.prefix(8) ?? "nil")")
        #endif
        
        guard let content = textFile.currentVersion?.content else {
            #if DEBUG
            print("   ❌ No currentVersion content")
            #endif
            return
        }
        
        // Use global page setup from UserDefaults
        let pageSetup = pageSetupPrefs.createPageSetup()
        
        #if DEBUG
        print("   - content length: \(content.count)")
        #endif
        
        isCalculatingLayout = true
        
        // Create text storage from attributed content to preserve formatting
        // On Mac Catalyst, scale down fonts to actual print size (undo 1.3x editor scaling)
        let attributedContent = textFile.currentVersion?.attributedContent ?? NSAttributedString(string: content)
        let printSizeContent = removePlatformScaling(from: attributedContent)
        let textStorage = NSTextStorage(attributedString: printSizeContent)
        
        // Create layout manager
        let manager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        // Calculate layout (async to avoid blocking UI)
        // Pass version and context for footnote-aware pagination
        let version = textFile.currentVersion
        let context = modelContext
        
        DispatchQueue.global(qos: .userInitiated).async {
            let _ = manager.calculateLayout(version: version, context: context)
            #if DEBUG
            print("   ✅ Layout calculated: \(manager.pageCount) pages")
            #endif
            
            DispatchQueue.main.async {
                self.layoutManager = manager
                self.isCalculatingLayout = false
                #if DEBUG
                print("   ✅ Layout manager assigned")
                #endif
            }
        }
    }
    
    private func recalculateLayout() {
        #if DEBUG
        print("🔄 recalculateLayout called")
        #endif
        #if DEBUG
        print("   - currentVersionIndex: \(textFile.currentVersionIndex)")
        #endif
        #if DEBUG
        print("   - currentVersion: \(textFile.currentVersion?.id.uuidString.prefix(8) ?? "nil")")
        #endif
        #if DEBUG
        print("   - content length: \(textFile.currentVersion?.content.count ?? 0)")
        #endif
        
        // Use global page setup from UserDefaults
        let pageSetup = pageSetupPrefs.createPageSetup()
        
        if let existingManager = layoutManager {
            #if DEBUG
            print("   ♻️ Updating existing manager")
            #endif
            
            // Update text content from current version (preserve formatting)
            if let content = textFile.currentVersion?.content {
                #if DEBUG
                print("   📝 Updating textStorage with new content")
                #endif
                let attributedContent = textFile.currentVersion?.attributedContent ?? NSAttributedString(string: content)
                let printSizeContent = removePlatformScaling(from: attributedContent)
                existingManager.textStorage.replaceCharacters(
                    in: NSRange(location: 0, length: existingManager.textStorage.length),
                    with: printSizeContent
                )
            }
            
            existingManager.updatePageSetup(pageSetup)
            
            // Pass version and context for footnote-aware pagination
            let version = textFile.currentVersion
            let context = modelContext
            
            isCalculatingLayout = true
            DispatchQueue.global(qos: .userInitiated).async {
                let _ = existingManager.calculateLayout(version: version, context: context)
                #if DEBUG
                print("   ✅ Recalculated: \(existingManager.pageCount) pages")
                #endif
                
                DispatchQueue.main.async {
                    self.isCalculatingLayout = false
                    #if DEBUG
                    print("   ✅ Recalculation complete")
                    #endif
                }
            }
        } else {
            #if DEBUG
            print("   🆕 Creating new layout manager")
            #endif
            setupLayoutManager()
        }
    }
    
    // MARK: - Font Scaling Helper
    
    /// Scale fonts for print-accurate pagination view to match across all platforms
    /// Both Mac and iOS pagination should show the same amount of text per page
    private func removePlatformScaling(from attributedString: NSAttributedString) -> NSAttributedString {
        // GOAL: Show print-accurate preview - same on Mac and iOS
        // Database stores fonts at base iOS size (17pt for Body)
        // Mac Catalyst scales 1.3x for display, so we need to undo that
        // iOS stores and displays at base size, so no scaling needed
        
        #if targetEnvironment(macCatalyst)
        // On Mac Catalyst, edit view applies 1.3x scaling at render time
        // Divide by 1.3 to show print-accurate size
        // 22.1pt (Mac display) → 17pt (pagination/print preview)
        let scaleFactor: CGFloat = 1.0 / 1.3
        #else
        // On iOS/iPad, database contains Mac-rendered fonts (22.1pt from generateFont())
        // Divide by 1.3 to get actual print size, same as Mac
        // 22.1pt (database) → 17pt (pagination/print preview)
        let scaleFactor: CGFloat = 1.0 / 1.3
        #endif
        
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: mutableString.length)
        
        var fontSizesFound: Set<CGFloat> = []
        var scaledFontSizes: Set<CGFloat> = []
        
        mutableString.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            guard let font = value as? UIFont else { return }
            fontSizesFound.insert(font.pointSize)
            let newSize = font.pointSize * scaleFactor
            scaledFontSizes.insert(newSize)
            let newFont = font.withSize(newSize)
            mutableString.addAttribute(.font, value: newFont, range: range)
        }
        
        #if DEBUG
        print("📐 [Pagination] Scaling fonts:")
        #endif
        #if DEBUG
        print("   - Scale factor: \(scaleFactor)")
        #endif
        #if DEBUG
        print("   - Original font sizes: \(fontSizesFound.sorted())")
        #endif
        #if DEBUG
        print("   - Scaled font sizes: \(scaledFontSizes.sorted())")
        #endif
        
        return mutableString
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
    
    // MARK: - Printing
    
    private func printDocument() {
        #if DEBUG
        print("🖨️ Print button tapped from pagination view")
        #endif
        
        // Get the view controller to present from
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let viewController = window.rootViewController else {
            #if DEBUG
            print("❌ Could not find view controller for print dialog")
            #endif
            printErrorMessage = "Unable to present print dialog"
            showPrintError = true
            return
        }
        
        // Call print service with project and context
        PrintService.printFile(
            textFile,
            project: project,
            context: modelContext,
            from: viewController
        ) { success, error in
            if let error = error {
                #if DEBUG
                print("❌ Print failed: \(error.localizedDescription)")
                #endif
                printErrorMessage = error.localizedDescription
                showPrintError = true
            } else if success {
                #if DEBUG
                print("✅ Print completed successfully")
                #endif
            } else {
                #if DEBUG
                print("⚠️ Print was cancelled")
                #endif
            }
        }
    }
}
