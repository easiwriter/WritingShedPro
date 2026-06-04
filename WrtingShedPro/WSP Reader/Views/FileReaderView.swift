//
//  FileReaderView.swift
//  WSP Reader
//
//  Displays the content of a single file with formatting.
//  Feature 026: WSP Reader App
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct FileReaderView: View {
    let file: WSPReaderFile
    let projectType: String
    let dramaScriptType: String?
    let fontSize: CGFloat
    var onNavigateToFile: ((String) -> Void)? = nil
    var onNavigatePrev: (() -> Void)? = nil
    var onNavigateNext: (() -> Void)? = nil

    @Environment(ReaderAppState.self) private var appState
    @State private var showComments: Bool = false
    /// Index of the version currently being read. Starts at the file's current version.
    @State private var selectedVersionIndex: Int
    /// Cached scaled attributed string — rebuilt only when file or fontSize changes.
    @State private var displayContent: NSAttributedString = NSAttributedString()
    /// Visual zoom scale driven by pinch and the ±/reset buttons.
    @State private var contentScale: CGFloat = 1.0
    /// Baseline scale accumulated across successive pinch gestures.
    @State private var lastScale: CGFloat = 1.0
    /// Current visible page in paginated reader mode.
    @State private var currentPageIndex: Int = 0
    /// Total page count for current content/layout.
    @State private var totalPageCount: Int = 1

    init(
        file: WSPReaderFile,
        projectType: String,
        dramaScriptType: String? = nil,
        fontSize: CGFloat,
        onNavigateToFile: ((String) -> Void)? = nil,
        onNavigatePrev: (() -> Void)? = nil,
        onNavigateNext: (() -> Void)? = nil
    ) {
        self.file = file
        self.projectType = projectType
        self.dramaScriptType = dramaScriptType
        self.fontSize = fontSize
        self.onNavigateToFile = onNavigateToFile
        self.onNavigatePrev = onNavigatePrev
        self.onNavigateNext = onNavigateNext
        _selectedVersionIndex = State(initialValue: file.currentVersionIndex)
    }

    var body: some View {
        Group {
            #if canImport(UIKit)
            VStack(alignment: .leading, spacing: 12) {
#if DEBUG
                Text("Reader pagination path: v3")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
#endif
                fileHeader
                Divider()
                ReaderSingleFilePaginatedView(
                    fileName: file.name,
                    attributedString: displayContent,
                    isTOCFile: file.isTOCFile,
                    zoomScale: contentScale,
                    pageCount: $totalPageCount,
                    onLinkTap: handleLinkTap
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                HStack {
                    Text("\(max(totalPageCount, 1)) pages")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Spacer()
                }
                .padding(.horizontal, 2)
            }
            .padding()
            .background(readerBackground)
            .navigationTitle(file.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .secondaryAction) {
                    if !comments.isEmpty {
                        Button {
                            showComments.toggle()
                        } label: {
                            Label("Comments", systemImage: "text.bubble")
                        }
                    }

                }
            }
            #else
            ScrollView {
                scrollContent
                    .frame(maxWidth: 700, alignment: .leading)
            }
            .background(readerBackground)
            .navigationTitle(file.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .secondaryAction) {
                    if !comments.isEmpty {
                        Button {
                            showComments.toggle()
                        } label: {
                            Label("Comments", systemImage: "text.bubble")
                        }
                    }

                }
            }
            #endif
        }
        .sheet(isPresented: $showComments) {
            CommentsSheet(comments: comments)
        }
        .onAppear {
            #if targetEnvironment(macCatalyst)
            contentScale = 1.0
            appState.readerContentScale = 1.0
            #else
            contentScale = appState.readerContentScale
            #endif
            lastScale = contentScale
            displayContent = buildScaledContent()
        }
        .onChange(of: file.id) {
            selectedVersionIndex = file.currentVersionIndex
            #if targetEnvironment(macCatalyst)
            contentScale = 1.0
            appState.readerContentScale = 1.0
            #else
            contentScale = appState.readerContentScale
            #endif
            lastScale = contentScale
            displayContent = buildScaledContent()
        }
        .onChange(of: fontSize) { displayContent = buildScaledContent() }
        .onChange(of: selectedVersionIndex) {
            #if targetEnvironment(macCatalyst)
            contentScale = 1.0
            appState.readerContentScale = 1.0
            #else
            contentScale = appState.readerContentScale
            #endif
            lastScale = contentScale
            displayContent = buildScaledContent()
        }
    }

    @ViewBuilder
    private var scrollContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            fileHeader
            Divider()
            AttributedTextView(
                attributedString: displayContent,
                fontSize: fontSize,
                onLinkTap: handleLinkTap
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            if !footnotes.isEmpty {
                footnotesSection
            }
            Spacer(minLength: 40)
        }
        .padding()
    }

    // MARK: - Gestures (iOS only)

    #if os(iOS) && !targetEnvironment(macCatalyst)
    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                contentScale = min(4.0, max(0.5, lastScale * value))
                appState.readerContentScale = contentScale
            }
            .onEnded { _ in
                lastScale = contentScale
                appState.readerContentScale = contentScale
            }
    }
    #endif
    
    @ViewBuilder
    private var fileHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(file.name)
                .font(.title)
                .fontWeight(.bold)

            HStack(alignment: .center, spacing: 16) {
                HStack(spacing: 16) {
                    Label("\(file.wordCount) words", systemImage: "text.word.spacing")

                    if let form = file.poetryFormName {
                        Label(form, systemImage: "text.quote")
                    }

                    if let status = file.workflowStatus {
                        Label(status.capitalized, systemImage: "checkmark.circle")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                #if !targetEnvironment(macCatalyst)
                HStack(spacing: 4) {
                    Button {
                        contentScale = max(0.5, contentScale - 0.05)
                        lastScale = contentScale
                        appState.readerContentScale = contentScale
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }

                    Text("\(fontSizePercent)%")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 40, alignment: .center)

                    Button {
                        contentScale = min(4.0, contentScale + 0.05)
                        lastScale = contentScale
                        appState.readerContentScale = contentScale
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }

                    Button {
                        contentScale = 1.0
                        lastScale = 1.0
                        appState.readerContentScale = contentScale
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                #endif
            }

            Text("Modified \(formattedDate(file.modifiedDate))")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            if file.versions.count > 1 {
                versionNavigator
            }
        }
    }

    @ViewBuilder
    private var versionNavigator: some View {
        HStack(spacing: 0) {
            Button {
                selectedVersionIndex = max(0, selectedVersionIndex - 1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 36, height: 32)
            }
            .disabled(selectedVersionIndex == 0)

            Spacer()

            VStack(spacing: 2) {
                Text("Version \(selectedVersion?.versionNumber ?? 1) of \(file.versions.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                if let comment = selectedVersion?.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .italic()
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                selectedVersionIndex = min(file.versions.count - 1, selectedVersionIndex + 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 36, height: 32)
            }
            .disabled(selectedVersionIndex == file.versions.count - 1)
        }
        .foregroundStyle(.secondary)
        .buttonStyle(.borderless)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(8)
    }
    
    // MARK: - Footnotes Section
    
    @ViewBuilder
    private var footnotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            Text("Footnotes")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            ForEach(footnotes) { footnote in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(footnote.number).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .trailing)
                    
                    Text(footnote.text)
                        .font(.footnote)
                }
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - Helpers
    
    private var scaledContent: NSAttributedString {
        buildScaledContent()
    }

    private var selectedVersion: WSPReaderVersion? {
        file.versions.indices.contains(selectedVersionIndex) ? file.versions[selectedVersionIndex] : file.currentVersion
    }

    private func buildScaledContent() -> NSAttributedString {
        let original: NSAttributedString
        if projectType.lowercased() == "drama" {
            original = WSPDramaRenderer.shared.render(source: selectedVersion?.content ?? file.plainContent, scriptTypeRaw: dramaScriptType)
        } else {
            original = selectedVersion?.attributedContent ?? NSAttributedString()
        }
        let mutable = NSMutableAttributedString(attributedString: original)
        
        // Scale fonts to match user preference
        mutable.enumerateAttribute(.font, in: NSRange(location: 0, length: mutable.length)) { value, range, _ in
            #if canImport(UIKit)
            if let font = value as? UIFont {
                let scaleFactor = fontSize / 16.0
                let newSize = font.pointSize * scaleFactor
                let newFont = font.withSize(newSize)
                mutable.addAttribute(.font, value: newFont, range: range)
            }
            #elseif canImport(AppKit)
            if let font = value as? NSFont {
                let scaleFactor = fontSize / 16.0
                let newSize = font.pointSize * scaleFactor
                let newFont = NSFont(descriptor: font.fontDescriptor, size: newSize) ?? NSFont.systemFont(ofSize: newSize)
                mutable.addAttribute(.font, value: newFont, range: range)
            }
            #endif
        }

        // Some imported heading styles carry paragraph indents that shift text right.
        // Normalize indents so headings and body start at the same left edge, like WSP.
        mutable.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: mutable.length)) { value, range, _ in
            guard let paragraph = value as? NSParagraphStyle else { return }
            let needsNormalization = paragraph.firstLineHeadIndent != 0
                || paragraph.headIndent != 0
                || paragraph.tailIndent != 0
                || paragraph.lineBreakMode != .byWordWrapping
            if needsNormalization {
                let normalized = paragraph.mutableCopy() as! NSMutableParagraphStyle
                normalized.firstLineHeadIndent = 0
                normalized.headIndent = 0
                normalized.tailIndent = 0
                normalized.lineBreakMode = .byWordWrapping
                mutable.addAttribute(.paragraphStyle, value: normalized, range: range)
            }
        }
        
        return mutable
    }

    private var readerBackground: Color {
        #if canImport(UIKit)
        return Color(uiColor: .systemBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .textBackgroundColor)
        #else
        return Color.background
        #endif
    }
    
    private var footnotes: [WSPReaderFootnote] {
        selectedVersion?.footnotes ?? []
    }

    private var fontSizePercent: Int {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        Int(round(contentScale * 100))
        #else
        Int(round((appState.fontSize / 16.0) * 100))
        #endif
    }

    private var comments: [WSPReaderComment] {
        selectedVersion?.comments ?? []
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private func formattedDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    // MARK: - Link Handling
    
    private func handleLinkTap(_ url: URL) -> Bool {
        // Check for internal wsp:// links
        if url.scheme == "wsp" {
            // Parse wsp://file/{fileId} format
            let fileId = url.lastPathComponent
            onNavigateToFile?(fileId)
            return true
        }
        
        // Check for file-reference links (from References feature)
        if url.absoluteString.contains("file-reference:") {
            let fileId = url.absoluteString.replacingOccurrences(of: "file-reference:", with: "")
            onNavigateToFile?(fileId)
            return true
        }
        
        // External links - let system handle
        return false
    }
}

// MARK: - Attributed Text View

struct AttributedTextView: View {
    let attributedString: NSAttributedString
    let fontSize: CGFloat
    var onLinkTap: ((URL) -> Bool)? = nil

    var body: some View {
        #if canImport(UIKit)
        UIKitAttributedTextView(attributedString: attributedString, onLinkTap: onLinkTap)
            .frame(maxWidth: .infinity, alignment: .leading)
        #else
        Text(attributedString.string)
            .font(.system(size: fontSize))
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        #endif
    }
}

#if canImport(UIKit)
private struct UIKitAttributedTextView: UIViewRepresentable {
    let attributedString: NSAttributedString
    var onLinkTap: ((URL) -> Bool)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onLinkTap: onLinkTap)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.dataDetectorTypes = [.link]
        textView.delegate = context.coordinator
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.systemBrown,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.attributedText = attributedString
        context.coordinator.onLinkTap = onLinkTap
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let proposedWidth = proposal.width, proposedWidth > 0 else {
            return nil
        }

        let targetSize = CGSize(width: proposedWidth, height: .greatestFiniteMagnitude)
        let measuredSize = uiView.sizeThatFits(targetSize)
        return CGSize(width: proposedWidth, height: ceil(measuredSize.height))
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var onLinkTap: ((URL) -> Bool)?

        init(onLinkTap: ((URL) -> Bool)?) {
            self.onLinkTap = onLinkTap
        }

        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
            if let handler = onLinkTap {
                return !handler(URL)
            }
            return true
        }
    }
}

private struct PaginatedAttributedTextReader: View {
    private static let pageInsets = UIEdgeInsets(top: 20, left: 22, bottom: 20, right: 22)

    let attributedString: NSAttributedString
    @Binding var pageIndex: Int
    @Binding var pageCount: Int
    var onLinkTap: ((URL) -> Bool)? = nil

    @State private var pages: [NSAttributedString] = []

    var body: some View {
        GeometryReader { geo in
            let pageWidth = max(1, geo.size.width)
            let pageHeight = max(1, geo.size.height)

            Group {
                if pages.isEmpty {
                    ContentUnavailableView("No Content", systemImage: "doc.text")
                } else {
                    TabView(selection: $pageIndex) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                            UIKitAttributedPageView(
                                attributedString: page,
                                pageInsets: Self.pageInsets,
                                onLinkTap: onLinkTap
                            )
                            .padding(12)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                }
            }
            .onAppear {
                repaginate(width: pageWidth, height: pageHeight)
            }
            .onChange(of: attributedString) {
                repaginate(width: pageWidth, height: pageHeight)
            }
            .onChange(of: pageWidth) { _, newWidth in
                repaginate(width: newWidth, height: pageHeight)
            }
            .onChange(of: pageHeight) { _, newHeight in
                repaginate(width: pageWidth, height: newHeight)
            }
        }
    }

    private func repaginate(width: CGFloat, height: CGFloat) {
        let contentWidth = max(1, width - 24 - Self.pageInsets.left - Self.pageInsets.right)
        let contentHeight = max(1, height - 24 - Self.pageInsets.top - Self.pageInsets.bottom)
        let nextPages = TextPaginator.paginate(
            attributedString: attributedString,
            pageSize: CGSize(width: contentWidth, height: contentHeight)
        )
        pages = nextPages.isEmpty ? [NSAttributedString(string: "")] : nextPages
        pageCount = max(pages.count, 1)
        pageIndex = min(max(0, pageIndex), max(0, pageCount - 1))
    }
}

final class ReaderPaginatedTextLayoutManager {
    private let textStorage: NSTextStorage
    private let layoutManager: NSLayoutManager

    init(attributedString: NSAttributedString) {
        self.textStorage = NSTextStorage(attributedString: attributedString)
        self.layoutManager = NSLayoutManager()
        self.layoutManager.allowsNonContiguousLayout = true
        textStorage.addLayoutManager(layoutManager)
    }

    func calculatePageRanges(containerSize: CGSize, respectFormFeed: Bool = false) -> [NSRange] {
        var pageRanges: [NSRange] = []
        var characterIndex = 0
        let totalCharacters = textStorage.length
        var lastProgress = -1

        while characterIndex < totalCharacters || pageRanges.isEmpty {
            if pageRanges.count > 5000 { break }

            let container = NSTextContainer(size: containerSize)
            container.lineFragmentPadding = 0
            container.maximumNumberOfLines = 0
            container.lineBreakMode = .byWordWrapping
            layoutManager.addTextContainer(container)
            layoutManager.ensureLayout(for: container)

            var glyphRange = layoutManager.glyphRange(for: container)
            var characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            var foundFormFeed = false

            if respectFormFeed && characterRange.length > 0 {
                let pageText = (textStorage.string as NSString).substring(with: characterRange)
                if let formFeedIndex = pageText.firstIndex(of: "\u{000C}") {
                    foundFormFeed = true
                    let offsetInPage = pageText.distance(from: pageText.startIndex, to: formFeedIndex)
                    let formFeedLocation = characterRange.location + offsetInPage
                    characterRange = NSRange(location: characterRange.location, length: offsetInPage)
                    glyphRange = layoutManager.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
                    _ = glyphRange
                    characterIndex = formFeedLocation + 1
                }
            }

            if characterRange.length == 0 && !foundFormFeed {
                break
            }

            pageRanges.append(characterRange)

            if !foundFormFeed {
                let nextChar = NSMaxRange(characterRange)
                characterIndex = nextChar
            }

            if characterIndex <= lastProgress && !foundFormFeed {
                break
            }
            lastProgress = characterIndex

            if characterIndex >= totalCharacters {
                break
            }
        }

        return pageRanges
    }
}

enum TextPaginator {
    static func paginate(attributedString: NSAttributedString, pageSize: CGSize) -> [NSAttributedString] {
        guard attributedString.length > 0 else { return [] }

        let manager = ReaderPaginatedTextLayoutManager(attributedString: attributedString)
        let ranges = manager.calculatePageRanges(containerSize: pageSize, respectFormFeed: false)

        if ranges.isEmpty {
            return [attributedString]
        }

        return ranges.map { attributedString.attributedSubstring(from: $0) }
    }
}

struct UIKitAttributedPageView: UIViewRepresentable {
    let attributedString: NSAttributedString
    let pageInsets: UIEdgeInsets
    var onLinkTap: ((URL) -> Bool)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onLinkTap: onLinkTap)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = ReaderPageTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = pageInsets
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.maximumNumberOfLines = 0
        textView.textContainer.widthTracksTextView = false
        textView.textContainer.heightTracksTextView = false
        textView.dataDetectorTypes = [.link]
        textView.delegate = context.coordinator
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.systemBrown,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.attributedText = attributedString
        textView.textContainerInset = pageInsets
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.contentOffset = .zero
        context.coordinator.onLinkTap = onLinkTap
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var onLinkTap: ((URL) -> Bool)?

        init(onLinkTap: ((URL) -> Bool)?) {
            self.onLinkTap = onLinkTap
        }

        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
            if let handler = onLinkTap {
                return !handler(URL)
            }
            return true
        }
    }
}

final class ReaderPageTextView: UITextView {
    override func layoutSubviews() {
        super.layoutSubviews()

        let contentWidth = max(1, bounds.width - textContainerInset.left - textContainerInset.right)
        let contentHeight = max(1, bounds.height - textContainerInset.top - textContainerInset.bottom)
        let targetSize = CGSize(width: contentWidth, height: contentHeight)
        if textContainer.size != targetSize {
            textContainer.size = targetSize
        }
    }
}

#endif

// MARK: - Footnotes Sheet

struct FootnotesSheet: View {
    let footnotes: [WSPReaderFootnote]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(footnotes) { footnote in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(footnote.number)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .trailing)
                    
                    Text(footnote.text)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Footnotes")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Comments Sheet

struct CommentsSheet: View {
    let comments: [WSPReaderComment]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(comments) { comment in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(comment.author)
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text(formattedDate(comment.createdAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(comment.text)
                        .font(.body)
                    
                    if comment.isResolved {
                        Label("Resolved", systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Comments")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}


