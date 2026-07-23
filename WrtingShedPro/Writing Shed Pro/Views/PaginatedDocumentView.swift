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
    /// When true, show actual page numbers in headers/footers. When false (default), show "#" as placeholder.
    var showActualPageNumbers: Bool = false
    /// The page number to display for the first page (default 1). Use to offset for front matter pages.
    var startingPageNumber: Int = 1
    /// Whether to show the print button in the toolbar. Set to false when printing is handled at a higher level.
    var showPrintButton: Bool = true
    
    @Environment(\.modelContext) private var modelContext
    
    @State private var previewLayout: PreviewLayout?
    @State private var currentPage: Int = 0
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var showPrintError = false
    @State private var printErrorMessage = ""
    @State private var upgradePromptReason: UpgradePromptReason?

    private struct PreviewLayout {
        let manager: PaginatedTextLayoutManager
        let footnotes: [ManuscriptFootnote]
    }
    
    // No longer using global page setup; use per-project pageSetup
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background color for the entire view
            Color(uiColor: .systemGray6)
                .ignoresSafeArea()
            
            // Main content layer - wait for final footnote-aware layout so pages
            // are first rendered with their footnote areas in place.
            if let previewLayout, previewLayout.manager.isLayoutValid, previewLayout.manager.isLayoutComplete {
                // Use per-project page setup
                let pageSetup = project.pageSetup ?? PageSetup.createWithDefaults()
                VirtualPageScrollView(
                    layoutManager: previewLayout.manager,
                    pageSetup: pageSetup,
                    zoomScale: zoomScale,
                    footnotes: previewLayout.footnotes,
                    version: textFile.currentVersion,
                    modelContext: modelContext,
                    project: project,
                    showActualPageNumbers: showActualPageNumbers,
                    startingPageNumber: startingPageNumber,
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
            } else {
                // Show loading while the footnote-aware layout is still calculating.
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .safeAreaInset(edge: .top) {
            // Page indicator toolbar - uses safeAreaInset so content scrolls underneath properly
            pageIndicatorToolbar
        }
        .onAppear {
            #if DEBUG
            print("📱 PaginatedDocumentView appeared")
            #endif
            #if DEBUG
            print("   - currentVersionIndex: \(textFile.currentVersionIndex)")
            #endif
            
            // Register stylesheet with provider so ImageAttachment can access it
            if let styleSheet = project.styleSheet {
                StyleSheetProvider.shared.register(styleSheet: styleSheet, for: textFile.id)
            }
            
            // Always recalculate on appear in case version changed while in edit mode
            if previewLayout != nil {
                #if DEBUG
                print("   - Recalculating layout on appear")
                #endif
                recalculateLayout()
            } else {
                setupLayoutManager()
            }
        }
        .onDisappear {
            // Unregister stylesheet when leaving paginated view
            StyleSheetProvider.shared.unregister(fileID: textFile.id)
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
        .onChange(of: textFile.currentVersion?.formattedContent) { oldValue, newValue in
            #if DEBUG
            print("📝 Version formattedContent changed: \(oldValue?.count ?? 0) → \(newValue?.count ?? 0)")
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
        .upgradePrompt(reason: $upgradePromptReason)
    }
    
    // MARK: - Page Indicator Toolbar
    
    private var pageIndicatorToolbar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Page info
                if let layoutManager = previewLayout?.manager, layoutManager.isLayoutValid {
                    Label {
                        Text(String(format: NSLocalizedString("paginatedDocument.pageIndicator", comment: "Page indicator"), currentPage + 1, layoutManager.pageCount))
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
            
            // Progress bar while pages are still being calculated
            if let layoutManager = previewLayout?.manager, layoutManager.isCalculating || !layoutManager.isLayoutComplete {
                let calculated = layoutManager.layoutResult?.pageInfos.count ?? 0
                let estimated = max(layoutManager.estimatedPageCount, calculated)
                let fraction = estimated > 0 ? min(Double(calculated) / Double(estimated), 1.0) : 0
                VStack(spacing: 2) {
                    ProgressView(value: fraction)
                        .tint(.accentColor)
                    Text(String(format: NSLocalizedString("paginatedDocument.calculatingPage", comment: "Calculating pages progress"), calculated))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
                .transition(.opacity)
            }
        }
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
            
            if showPrintButton {
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
        
        // Use per-project page setup
        let pageSetup = project.pageSetup ?? PageSetup.createWithDefaults()
        // ...existing code...
        
        #if DEBUG
        print("   - content length: \(content.count)")
        #endif
        
        // Create text storage from attributed content to preserve formatting
        // On Mac Catalyst, scale down fonts to actual print size (undo 1.3x editor scaling)
        let attributedContent = textFile.currentVersion?.attributedContent ?? NSAttributedString(string: content)
        let printSizeContent = removePlatformScaling(from: attributedContent)
        let textStorage = NSTextStorage(attributedString: printSizeContent)
        
        // Update caption numbers for image attachments (Feature 016)
        ImageAttachment.updateCaptionNumbers(in: textStorage, styleSheet: project.styleSheet)
        
        // Reconcile footnote marker styles with the project stylesheet.
        // The serialized data may contain stale marker styles if the stylesheet
        // was changed after the footnote was last saved.
        FootnoteAttachment.reconcileMarkerStyles(in: textStorage, stylesheet: project.styleSheet)
        
        // Ensure numbered heading paragraphs have firstLineHeadIndent for number space
        NumberingLayoutManager.ensureNumberIndents(in: textStorage, styleSheet: project.styleSheet)
        
        // Create layout manager
        let manager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        let version = textFile.currentVersion
        let footnotes = collectPreviewFootnotes(from: textStorage, version: version)
        
        // Store manager immediately - it will set isLayoutValid=true as soon as
        // initial pages are calculated, allowing the view to display immediately
        self.previewLayout = PreviewLayout(manager: manager, footnotes: footnotes)
        
        // Calculate layout (async to avoid blocking UI)
        DispatchQueue.global(qos: .userInitiated).async {
            let _ = manager.calculateLayout(assembledFootnotes: footnotes)
            #if DEBUG
            print("   ✅ Layout calculated: \(manager.pageCount) pages")
            #endif
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
        
        // Use per-project page setup
        let pageSetup = project.pageSetup ?? PageSetup.createWithDefaults()
        // ...existing code...
        
        if let existingManager = previewLayout?.manager {
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
                
                // Update caption numbers for image attachments (Feature 016)
                ImageAttachment.updateCaptionNumbers(in: existingManager.textStorage, styleSheet: project.styleSheet)
                
                // Reconcile footnote marker styles with the project stylesheet
                FootnoteAttachment.reconcileMarkerStyles(in: existingManager.textStorage, stylesheet: project.styleSheet)
                
                NumberingLayoutManager.ensureNumberIndents(in: existingManager.textStorage, styleSheet: project.styleSheet)
            }
            
            existingManager.updatePageSetup(pageSetup)
            
            let version = textFile.currentVersion
            let footnotes = collectPreviewFootnotes(from: existingManager.textStorage, version: version)
            previewLayout = PreviewLayout(manager: existingManager, footnotes: footnotes)
            
            DispatchQueue.global(qos: .userInitiated).async {
                let _ = existingManager.calculateLayout(assembledFootnotes: footnotes)
                #if DEBUG
                print("   ✅ Recalculated: \(existingManager.pageCount) pages")
                #endif
            }
        } else {
            #if DEBUG
            print("   🆕 Creating new layout manager")
            #endif
            setupLayoutManager()
        }
    }

    private func collectPreviewFootnotes(from textStorage: NSTextStorage, version: Version?) -> [ManuscriptFootnote] {
        guard let version else { return [] }

        var markerPositions: [(attachmentID: UUID, position: Int)] = []
        textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: textStorage.length), options: []) { value, range, _ in
            if let footnoteAttachment = value as? FootnoteAttachment {
                markerPositions.append((footnoteAttachment.footnoteID, range.location))
            }
        }

        guard !markerPositions.isEmpty else { return [] }

        let footnoteContext = version.modelContext ?? modelContext
        let activeFootnotes = FootnoteManager.shared.getActiveFootnotes(forVersion: version, context: footnoteContext)
        let activeByAttachmentID = Dictionary(activeFootnotes.map { ($0.attachmentID, $0) }, uniquingKeysWith: { first, _ in first })

        var seenAttachmentIDs = Set<UUID>()
        let orderedUniqueMarkers = markerPositions.filter { marker in
            seenAttachmentIDs.insert(marker.attachmentID).inserted
        }

        return orderedUniqueMarkers.enumerated().compactMap { index, marker in

            let footnote = activeByAttachmentID[marker.attachmentID]
                ?? FootnoteManager.shared.getFootnoteByAttachment(attachmentID: marker.attachmentID, context: footnoteContext)

            guard let footnote else {
                #if DEBUG
                print("⚠️ Preview marker has no matching FootnoteModel: \(marker.attachmentID)")
                #endif
                return nil
            }

            return ManuscriptFootnote(
                attachmentID: footnote.attachmentID,
                text: footnote.text,
                number: index + 1,
                characterPosition: marker.position
            )
        }
        .sorted { $0.characterPosition < $1.characterPosition }
    }
    
    // MARK: - Font Scaling Helper
    
    /// Scale fonts for print-accurate pagination view to match across all platforms
    /// Both Mac and iOS pagination should show the same amount of text per page
    private func removePlatformScaling(from attributedString: NSAttributedString) -> NSAttributedString {
        // GOAL: Show print-accurate preview - same on Mac and iOS
        // Database stores fonts at base iOS size (17pt for Body)
        // Mac Catalyst scales 1.3x for display, so we need to undo that
        // iOS stores and displays at base size, so no scaling needed
        
        // Database stores fonts at Catalyst-scaled size (e.g. 22.1pt for 17pt Body).
        // Divide by kCatalystFontScale to get true print size on all platforms.
        let scaleFactor: CGFloat = 1.0 / kCatalystFontScale
        
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
        
        // Also scale paragraph indents proportionally so that number spacing
        // (computed from Catalyst-scaled fonts) remains correct for the descaled fonts.
        mutableString.enumerateAttribute(.paragraphStyle, in: fullRange, options: []) { value, range, _ in
            guard let ps = value as? NSParagraphStyle else { return }
            let needsScale = ps.firstLineHeadIndent != 0 || ps.headIndent != 0 || ps.tailIndent != 0
            guard needsScale else { return }
            let mps = ps.mutableCopy() as! NSMutableParagraphStyle
            if mps.firstLineHeadIndent != 0 { mps.firstLineHeadIndent *= scaleFactor }
            if mps.headIndent != 0 { mps.headIndent *= scaleFactor }
            if mps.tailIndent != 0 { mps.tailIndent *= scaleFactor }
            mutableString.addAttribute(.paragraphStyle, value: mps, range: range)
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
        
        // Check entitlement for printing
        if !EntitlementManager.shared.canPrint(projectType: project.type) {
            upgradePromptReason = .printBlocked(projectType: project.type)
            return
        }
        
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
