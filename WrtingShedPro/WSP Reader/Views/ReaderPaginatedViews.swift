import SwiftUI
#if canImport(UIKit)
import UIKit

struct ReaderManuscriptSource: Identifiable {
    let file: WSPReaderFile
    let content: NSAttributedString

    var id: String { file.id }
}

struct ReaderSingleFilePaginatedView: View {
    let fileName: String
    let attributedString: NSAttributedString
    let isTOCFile: Bool
    let zoomScale: CGFloat
    @Binding var pageCount: Int
    var onLinkTap: ((URL) -> Bool)? = nil

    @State private var pages: [ReaderRenderedPage] = []

    var body: some View {
        GeometryReader { geo in
            let layout = ReaderPaginationLayout(fittingWidth: geo.size.width, zoomScale: zoomScale, hasHeaders: false, hasFooters: false)

            ReaderVirtualPageScrollView(
                pages: pages,
                layout: layout,
                onLinkTap: onLinkTap
            )
            .onAppear {
                repaginate(using: layout)
            }
            .onChange(of: geo.size.width) { _, newWidth in
                repaginate(using: ReaderPaginationLayout(fittingWidth: newWidth, zoomScale: zoomScale, hasHeaders: false, hasFooters: false))
            }
            .onChange(of: zoomScale) {
                repaginate(using: layout)
            }
            .onChange(of: attributedString) {
                repaginate(using: layout)
            }
        }
    }

    private func repaginate(using layout: ReaderPaginationLayout) {
        let normalized = ReaderTextNormalizer.normalize(attributedString, preserveParagraphStyles: isTOCFile)
        let segments = TextPaginator.paginate(attributedString: normalized, pageSize: layout.paginationTextRectSize)
        let resolved = (segments.isEmpty ? [NSAttributedString(string: "")] : segments).enumerated().map { index, segment in
            ReaderRenderedPage(
                pageNumber: index + 1,
                fileName: fileName,
                headerLeft: nil,
                headerCenter: nil,
                headerRight: nil,
                footerLeft: nil,
                footerCenter: nil,
                footerRight: nil,
                body: .text(segment)
            )
        }
        pages = resolved
        pageCount = max(resolved.count, 1)
    }
}

struct ReaderManuscriptPaginatedView: View {
    let projectName: String
    let projectAuthor: String?
    let sources: [ReaderManuscriptSource]
    let pageSetup: ReaderManuscriptPageSetup
    let zoomScale: CGFloat
    @Binding var pageCount: Int
    var onLinkTap: ((URL) -> Bool)? = nil

    @State private var pages: [ReaderRenderedPage] = []

    var body: some View {
        GeometryReader { geo in
            let layout = ReaderPaginationLayout(
                fittingWidth: geo.size.width,
                zoomScale: zoomScale,
                hasHeaders: pageSetup.hasHeaders,
                hasFooters: pageSetup.hasFooters
            )

            ReaderVirtualPageScrollView(
                pages: pages,
                layout: layout,
                onLinkTap: onLinkTap
            )
            .onAppear {
                repaginate(using: layout)
            }
            .onChange(of: geo.size.width) { _, newWidth in
                repaginate(using: ReaderPaginationLayout(
                    fittingWidth: newWidth,
                    zoomScale: zoomScale,
                    hasHeaders: pageSetup.hasHeaders,
                    hasFooters: pageSetup.hasFooters
                ))
            }
            .onChange(of: zoomScale) {
                repaginate(using: layout)
            }
            .onChange(of: sources.map(\ .id).joined(separator: "|")) {
                repaginate(using: layout)
            }
        }
    }

    private func repaginate(using layout: ReaderPaginationLayout) {
        var preflightSegments: [String: [NSAttributedString]] = [:]
        var pageCountByFileID: [String: Int] = [:]

        for source in sources {
            if source.file.isCoverFile {
                pageCountByFileID[source.file.id] = 1
                continue
            }

            let normalized = ReaderTextNormalizer.normalize(source.content, preserveParagraphStyles: source.file.isTOCFile)
            let segments = TextPaginator.paginate(attributedString: normalized, pageSize: layout.paginationTextRectSize)
            let resolved = segments.isEmpty ? [NSAttributedString(string: "")] : segments
            preflightSegments[source.file.id] = resolved
            pageCountByFileID[source.file.id] = resolved.count
        }

        let firstBodyIndex = sources.firstIndex(where: {
            !$0.file.isTOCFile && !$0.file.isCoverFile && $0.file.collectionName != nil
        }) ?? sources.firstIndex(where: { !$0.file.isTOCFile && !$0.file.isCoverFile }) ?? sources.count

        var bodyStartPageByTitle: [String: Int] = [:]
        var bodyEntriesInOrder: [(title: String, page: Int)] = []
        var bodyPageCursor = 1
        if firstBodyIndex < sources.count {
            for source in sources[firstBodyIndex...] {
                if source.file.isTOCFile || source.file.isCoverFile { continue }
                bodyStartPageByTitle[source.file.name] = bodyPageCursor
                bodyEntriesInOrder.append((title: source.file.name, page: bodyPageCursor))
                bodyPageCursor += max(pageCountByFileID[source.file.id] ?? 1, 1)
            }
        }

        var bodyStartAbsolutePage = 1
        if firstBodyIndex > 0 {
            for source in sources.prefix(firstBodyIndex) {
                bodyStartAbsolutePage += max(pageCountByFileID[source.file.id] ?? 1, 1)
            }
        }

        var nextPages: [ReaderRenderedPage] = []
        var nextPageNumber = 1
        var frontMatterPageNumber = 1
        var bodyPageNumber = 1

        for source in sources {
            if source.file.isCoverFile {
                nextPages.append(
                    ReaderRenderedPage(
                        pageNumber: nextPageNumber,
                        fileName: source.file.name,
                        headerLeft: nil,
                        headerCenter: nil,
                        headerRight: nil,
                        footerLeft: nil,
                        footerCenter: nil,
                        footerRight: nil,
                        body: .cover(imageData: source.file.coverImageData, title: source.file.name)
                    )
                )
                nextPageNumber += 1
                continue
            }

            let segments: [NSAttributedString]
            if source.file.isTOCFile {
                let formattedTOC = ReaderTOCFormatter.render(
                    source.content,
                    pageNumbersByTitle: bodyStartPageByTitle,
                    orderedBodyEntries: bodyEntriesInOrder,
                    contentWidth: layout.paginationTextRectSize.width
                )
                let normalized = ReaderTextNormalizer.normalize(formattedTOC, preserveParagraphStyles: true)
                let paginated = TextPaginator.paginate(attributedString: normalized, pageSize: layout.paginationTextRectSize)
                segments = paginated.isEmpty ? [NSAttributedString(string: "")] : paginated
            } else {
                segments = preflightSegments[source.file.id] ?? [NSAttributedString(string: "")]
            }

            for segment in segments {
                let displayPageNumber: String
                if nextPageNumber < bodyStartAbsolutePage {
                    displayPageNumber = ReaderPageNumbering.roman(frontMatterPageNumber)
                    frontMatterPageNumber += 1
                } else {
                    displayPageNumber = String(bodyPageNumber)
                    bodyPageNumber += 1
                }

                nextPages.append(
                    ReaderRenderedPage(
                        pageNumber: nextPageNumber,
                        fileName: source.file.name,
                        headerLeft: pageSetup.hasHeaders ? resolve(pageSetup.headerLeft, pageNumber: nextPageNumber, displayPageNumber: displayPageNumber, file: source.file) : nil,
                        headerCenter: pageSetup.hasHeaders ? resolve(pageSetup.headerCenter, pageNumber: nextPageNumber, displayPageNumber: displayPageNumber, file: source.file) : nil,
                        headerRight: pageSetup.hasHeaders ? resolve(pageSetup.headerRight, pageNumber: nextPageNumber, displayPageNumber: displayPageNumber, file: source.file) : nil,
                        footerLeft: pageSetup.hasFooters ? resolve(pageSetup.footerLeft, pageNumber: nextPageNumber, displayPageNumber: displayPageNumber, file: source.file) : nil,
                        footerCenter: pageSetup.hasFooters ? resolve(pageSetup.footerCenter, pageNumber: nextPageNumber, displayPageNumber: displayPageNumber, file: source.file) : nil,
                        footerRight: pageSetup.hasFooters ? resolve(pageSetup.footerRight, pageNumber: nextPageNumber, displayPageNumber: displayPageNumber, file: source.file) : nil,
                        body: .text(segment)
                    )
                )
                nextPageNumber += 1
            }
        }

        pages = nextPages
        pageCount = max(nextPages.count, 1)
    }

    private func resolve(_ template: String, pageNumber: Int, displayPageNumber: String, file: WSPReaderFile) -> String {
        let dateString = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none)
        return template
            .replacingOccurrences(of: "{{Date}}", with: dateString)
            .replacingOccurrences(of: "{{Page Number}}", with: displayPageNumber)
            .replacingOccurrences(of: "{{PageNumber}}", with: displayPageNumber)
            .replacingOccurrences(of: "{{Project Name}}", with: projectName)
            .replacingOccurrences(of: "{{ProjectTitle}}", with: projectName)
            .replacingOccurrences(of: "{{FileTitle}}", with: file.name)
            .replacingOccurrences(of: "{{Collection}}", with: file.collectionName ?? "")
            .replacingOccurrences(of: "{{Author}}", with: projectAuthor ?? "")
    }
}

struct ReaderPaginationLayout {
    let pageRect: CGRect
    let textRect: CGRect
    let headerRect: CGRect?
    let footerRect: CGRect?
    let displayScale: CGFloat

    init(fittingWidth availableWidth: CGFloat, zoomScale: CGFloat, hasHeaders: Bool, hasFooters: Bool) {
        let paper = ReaderPaperSize.defaultForRegion
        let pageRect = CGRect(origin: .zero, size: CGSize(width: paper.width, height: paper.height))
        let textRect = CGRect(x: 72, y: 72, width: pageRect.width - 144, height: pageRect.height - 144)
        let topGap = min(CGFloat(72) / 3, 18)
        let bottomGap = min(CGFloat(72) / 3, 18)

        self.pageRect = pageRect
        self.textRect = textRect
        self.headerRect = hasHeaders ? CGRect(x: textRect.minX, y: topGap, width: textRect.width, height: 36) : nil
        self.footerRect = hasFooters ? CGRect(x: textRect.minX, y: pageRect.height - 36 - bottomGap, width: textRect.width, height: 36) : nil

        let fitScale = max(0.35, (max(availableWidth - 24, 200) / pageRect.width))
        self.displayScale = min(fitScale * zoomScale, fitScale)
    }

    var displayedPageSize: CGSize {
        CGSize(width: pageRect.width * displayScale, height: pageRect.height * displayScale)
    }

    var paginationTextRectSize: CGSize {
        CGSize(width: textRect.width * displayScale, height: textRect.height * displayScale)
    }
}

private enum ReaderPaperSize {
    case letter
    case a4

    static var defaultForRegion: ReaderPaperSize {
        let regionCode = Locale.current.region?.identifier ?? "US"
        let letterRegions = ["US", "CA", "MX", "CL", "CO", "CR", "PA", "PH", "PR"]
        return letterRegions.contains(regionCode) ? .letter : .a4
    }

    var width: CGFloat {
        switch self {
        case .letter: return 612
        case .a4: return 595
        }
    }

    var height: CGFloat {
        switch self {
        case .letter: return 792
        case .a4: return 842
        }
    }
}

struct ReaderRenderedPage: Identifiable {
    let id = UUID()
    let pageNumber: Int
    let fileName: String
    let headerLeft: String?
    let headerCenter: String?
    let headerRight: String?
    let footerLeft: String?
    let footerCenter: String?
    let footerRight: String?
    let body: Body

    enum Body {
        case text(NSAttributedString)
        case cover(imageData: Data?, title: String)
    }
}

private struct ReaderRenderedPageView: View {
    let page: ReaderRenderedPage
    let layout: ReaderPaginationLayout
    var onLinkTap: ((URL) -> Bool)? = nil

    private var topMarginHeight: CGFloat { layout.textRect.minY }
    private var bottomMarginHeight: CGFloat { layout.pageRect.height - layout.textRect.maxY }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                if layout.headerRect != nil {
                    headerFooterRow(page.headerLeft, page.headerCenter, page.headerRight)
                        .frame(width: layout.textRect.width, height: 36, alignment: .center)
                        .padding(.top, min(topMarginHeight / 3, 18))
                }
            }
            .frame(height: topMarginHeight)

            Group {
                switch page.body {
                case .text(let text):
                    UIKitAttributedPageView(attributedString: text, pageInsets: .zero, onLinkTap: onLinkTap)
                        .frame(width: layout.textRect.width, height: layout.textRect.height, alignment: .topLeading)
                        .clipped()
                case .cover(let imageData, let title):
                    ReaderCoverPageView(imageData: imageData, title: title)
                        .frame(width: layout.textRect.width, height: layout.textRect.height, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            ZStack(alignment: .bottom) {
                if layout.footerRect != nil {
                    headerFooterRow(page.footerLeft, page.footerCenter, page.footerRight)
                        .frame(width: layout.textRect.width, height: 36, alignment: .center)
                        .padding(.bottom, min(bottomMarginHeight / 3, 18))
                }
            }
            .frame(height: bottomMarginHeight)
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color.black.opacity(0.12), radius: 8, y: 2)
        )
        .frame(width: layout.pageRect.width, height: layout.pageRect.height)
        .clipped()
        .scaleEffect(layout.displayScale, anchor: .top)
        .frame(width: layout.displayedPageSize.width, height: layout.displayedPageSize.height, alignment: .top)
    }

    @ViewBuilder
    private func headerFooterRow(_ left: String?, _ center: String?, _ right: String?) -> some View {
        HStack(spacing: 10) {
            Text(left ?? "")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(center ?? "")
                .frame(maxWidth: .infinity, alignment: .center)
            Text(right ?? "")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

private enum ReaderTextNormalizer {
    static func normalize(_ source: NSAttributedString, preserveParagraphStyles: Bool = false) -> NSAttributedString {
        guard source.length > 0 else { return source }

        if preserveParagraphStyles {
            return source
        }

        let mutable = NSMutableAttributedString(attributedString: source)
        let fullRange = NSRange(location: 0, length: mutable.length)

        // Imported paragraph styles can carry aggressive indents or non-wrapping modes.
        // Strip them entirely, then apply a deterministic reader style.
        mutable.removeAttribute(.paragraphStyle, range: fullRange)

        let baseParagraph = NSMutableParagraphStyle()
        baseParagraph.lineBreakMode = .byWordWrapping
        baseParagraph.firstLineHeadIndent = 0
        baseParagraph.headIndent = 0
        baseParagraph.tailIndent = 0
        baseParagraph.lineBreakStrategy = []
        mutable.addAttribute(.paragraphStyle, value: baseParagraph, range: fullRange)

        return mutable
    }
}

private enum ReaderPageNumbering {
    static func roman(_ number: Int) -> String {
        guard number > 0 else { return "" }
        let values: [(Int, String)] = [
            (1000, "m"), (900, "cm"), (500, "d"), (400, "cd"),
            (100, "c"), (90, "xc"), (50, "l"), (40, "xl"),
            (10, "x"), (9, "ix"), (5, "v"), (4, "iv"), (1, "i")
        ]
        var remainder = number
        var output = ""
        for (value, symbol) in values {
            while remainder >= value {
                output += symbol
                remainder -= value
            }
        }
        return output
    }
}

private enum ReaderTOCFormatter {
    private static let entryRegex = try? NSRegularExpression(pattern: "^(.+?)\\s+([0-9]+)$")

    static func render(
        _ source: NSAttributedString,
        pageNumbersByTitle: [String: Int],
        orderedBodyEntries: [(title: String, page: Int)],
        contentWidth: CGFloat
    ) -> NSAttributedString {
        let rawLines = source.string.components(separatedBy: .newlines)
        guard !rawLines.isEmpty else { return source }

        let normalizedPageByTitle = Dictionary(uniqueKeysWithValues: pageNumbersByTitle.map { (normalizeTitle($0.key), $0.value) })

        let output = NSMutableAttributedString()
        let headerAttributes = source.attributes(at: 0, effectiveRange: nil)
        var bodyAttributes = firstBodyLineAttributes(in: source) ?? headerAttributes
        bodyAttributes = toSingleLineAttributes(bodyAttributes)

        var didRenderTitle = false
        var entryIndex = 0
        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                output.append(NSAttributedString(string: "\n", attributes: bodyAttributes))
                continue
            }

            if !didRenderTitle {
                output.append(NSAttributedString(string: trimmed + "\n", attributes: headerAttributes))
                didRenderTitle = true
                continue
            }

            let titleAndNumber = parseEntry(trimmed)
            let title = titleAndNumber?.title ?? trimmed
            let parsedPage = titleAndNumber?.page
            let normalizedTitle = normalizeTitle(title)
            let orderedPage = entryIndex < orderedBodyEntries.count ? orderedBodyEntries[entryIndex].page : nil
            let page = orderedPage ?? pageNumbersByTitle[title] ?? normalizedPageByTitle[normalizedTitle] ?? parsedPage

            if titleAndNumber != nil {
                entryIndex += 1
            }

            if let page {
                var attrs = bodyAttributes
                let catalystFont = (attrs[.font] as? UIFont) ?? UIFont.systemFont(ofSize: 14)
                let fillChar = "."
                let padding: CGFloat = 4

                let titleWidth = (title as NSString).size(withAttributes: [.font: catalystFont]).width
                let pageText = String(page)
                let pageNumWidth = (pageText as NSString).size(withAttributes: [.font: catalystFont]).width
                let dotWidth = (fillChar as NSString).size(withAttributes: [.font: catalystFont]).width

                let tabPosition = max(120, contentWidth - 2)
                let spaceForDots = tabPosition - titleWidth - pageNumWidth - (padding * 2)
                let dotCount = dotWidth > 0 ? max(0, Int(floor(spaceForDots / dotWidth))) : 0
                let dots = String(repeating: fillChar, count: dotCount)

                let para = (attrs[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
                para.firstLineHeadIndent = 0
                para.headIndent = 0
                para.tailIndent = 0
                para.lineBreakMode = .byTruncatingTail
                para.tabStops = [NSTextTab(textAlignment: .right, location: tabPosition, options: [:])]
                para.defaultTabInterval = 1000
                attrs[.paragraphStyle] = para

                let row = "\(title) \(dots)\t\(pageText)\n"
                output.append(NSAttributedString(string: row, attributes: attrs))
            } else {
                output.append(NSAttributedString(string: title + "\n", attributes: bodyAttributes))
            }
        }

        return output
    }

    private static func parseEntry(_ line: String) -> (title: String, page: Int)? {
        guard let entryRegex else { return nil }
        let nsLine = line as NSString
        let range = NSRange(location: 0, length: nsLine.length)
        guard let match = entryRegex.firstMatch(in: line, options: [], range: range), match.numberOfRanges == 3 else {
            return nil
        }
        let title = nsLine.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        let pageString = nsLine.substring(with: match.range(at: 2))
        guard let page = Int(pageString) else { return nil }
        return (title, page)
    }

    private static func firstBodyLineAttributes(in source: NSAttributedString) -> [NSAttributedString.Key: Any]? {
        let text = source.string as NSString
        var cursor = 0
        var consumedTitle = false

        while cursor < text.length {
            let lineRange = text.lineRange(for: NSRange(location: cursor, length: 0))
            let lineText = text.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)
            if !lineText.isEmpty {
                if consumedTitle {
                    let location = min(lineRange.location, max(source.length - 1, 0))
                    return source.attributes(at: location, effectiveRange: nil)
                }
                consumedTitle = true
            }
            cursor = NSMaxRange(lineRange)
        }

        return nil
    }

    private static func toSingleLineAttributes(_ attributes: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
        var adjusted = attributes
        let paragraph = (attributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.firstLineHeadIndent = 0
        paragraph.headIndent = 0
        paragraph.tailIndent = 0
        adjusted[.paragraphStyle] = paragraph
        return adjusted
    }

    private static func normalizeTitle(_ title: String) -> String {
        let folded = title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let allowed = folded.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) || CharacterSet.whitespaces.contains(scalar) {
                return Character(scalar)
            }
            return " "
        }
        let collapsed = String(allowed).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct ReaderCoverPageView: View {
    let imageData: Data?
    let title: String

    var body: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ReaderVirtualPageScrollView: UIViewRepresentable {
    let pages: [ReaderRenderedPage]
    let layout: ReaderPaginationLayout
    var onLinkTap: ((URL) -> Bool)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onLinkTap: onLinkTap)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear

        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
        ])

        context.coordinator.scrollView = scrollView
        context.coordinator.stackView = stackView
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.onLinkTap = onLinkTap
        context.coordinator.render(pages: pages, layout: layout)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        weak var scrollView: UIScrollView?
        weak var stackView: UIStackView?
        var onLinkTap: ((URL) -> Bool)?

        init(onLinkTap: ((URL) -> Bool)?) {
            self.onLinkTap = onLinkTap
        }

        func render(pages: [ReaderRenderedPage], layout: ReaderPaginationLayout) {
            guard let stackView else { return }

            stackView.arrangedSubviews.forEach { subview in
                stackView.removeArrangedSubview(subview)
                subview.removeFromSuperview()
            }

            for page in pages {
                let pageView = makePageView(page: page, layout: layout)
                stackView.addArrangedSubview(pageView)
            }
        }

        private func makePageView(page: ReaderRenderedPage, layout: ReaderPaginationLayout) -> UIView {
            let displaySize = layout.displayedPageSize
            let scaledPageRect = CGRect(origin: .zero, size: displaySize)

            let pageView = UIView(frame: scaledPageRect)
            pageView.translatesAutoresizingMaskIntoConstraints = false
            pageView.backgroundColor = .systemBackground
            pageView.layer.cornerRadius = 8
            pageView.layer.shadowColor = UIColor.black.cgColor
            pageView.layer.shadowOpacity = 0.12
            pageView.layer.shadowRadius = 8
            pageView.layer.shadowOffset = CGSize(width: 0, height: 2)

            NSLayoutConstraint.activate([
                pageView.widthAnchor.constraint(equalToConstant: displaySize.width),
                pageView.heightAnchor.constraint(equalToConstant: displaySize.height),
            ])

            let scale = layout.displayScale
            let toDisplay: (CGFloat) -> CGFloat = { $0 * scale }

            if let _ = layout.headerRect {
                let header = makeHeaderFooterView(
                    left: page.headerLeft,
                    center: page.headerCenter,
                    right: page.headerRight,
                    width: toDisplay(layout.textRect.width),
                    height: toDisplay(36)
                )
                header.frame.origin = CGPoint(
                    x: toDisplay(layout.textRect.minX),
                    y: toDisplay(min(layout.textRect.minY / 3, 18))
                )
                pageView.addSubview(header)
            }

            switch page.body {
            case .text(let text):
                let textView = UITextView(frame: CGRect(
                    x: toDisplay(layout.textRect.minX),
                    y: toDisplay(layout.textRect.minY),
                    width: toDisplay(layout.textRect.width),
                    height: toDisplay(layout.textRect.height)
                ))
                textView.isEditable = false
                textView.isSelectable = true
                textView.isScrollEnabled = false
                textView.backgroundColor = .clear
                textView.textContainerInset = .zero
                textView.textContainer.lineFragmentPadding = 0
                textView.textContainer.lineBreakMode = .byWordWrapping
                textView.textContainer.maximumNumberOfLines = 0
                textView.textContainer.widthTracksTextView = false
                textView.textContainer.heightTracksTextView = false
                textView.textContainer.size = textView.bounds.size
                textView.delegate = self
                textView.attributedText = text
                textView.linkTextAttributes = [
                    .foregroundColor: UIColor.systemBrown,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                ]
                pageView.addSubview(textView)
            case .cover(let imageData, let title):
                let coverContainer = UIView(frame: CGRect(
                    x: toDisplay(layout.textRect.minX),
                    y: toDisplay(layout.textRect.minY),
                    width: toDisplay(layout.textRect.width),
                    height: toDisplay(layout.textRect.height)
                ))

                if let imageData, let image = UIImage(data: imageData) {
                    let imageView = UIImageView(image: image)
                    imageView.contentMode = .scaleAspectFit
                    imageView.frame = coverContainer.bounds
                    imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    coverContainer.addSubview(imageView)
                } else {
                    let label = UILabel(frame: coverContainer.bounds)
                    label.text = title
                    label.textAlignment = .center
                    label.numberOfLines = 0
                    label.font = .preferredFont(forTextStyle: .headline)
                    label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    coverContainer.addSubview(label)
                }
                pageView.addSubview(coverContainer)
            }

            if let _ = layout.footerRect {
                let footer = makeHeaderFooterView(
                    left: page.footerLeft,
                    center: page.footerCenter,
                    right: page.footerRight,
                    width: toDisplay(layout.textRect.width),
                    height: toDisplay(36)
                )
                footer.frame.origin = CGPoint(
                    x: toDisplay(layout.textRect.minX),
                    y: toDisplay(layout.pageRect.height - 36 - min((layout.pageRect.height - layout.textRect.maxY) / 3, 18))
                )
                pageView.addSubview(footer)
            }

            return pageView
        }

        private func makeHeaderFooterView(left: String?, center: String?, right: String?, width: CGFloat, height: CGFloat) -> UIView {
            let container = UIView(frame: CGRect(x: 0, y: 0, width: width, height: height))

            let leftLabel = UILabel(frame: CGRect(x: 0, y: 0, width: width / 3, height: height))
            leftLabel.text = left ?? ""
            leftLabel.textAlignment = .left
            leftLabel.font = .systemFont(ofSize: max(10, 12 * (width / max(width, 1))))
            leftLabel.textColor = .secondaryLabel
            leftLabel.lineBreakMode = .byTruncatingTail

            let centerLabel = UILabel(frame: CGRect(x: width / 3, y: 0, width: width / 3, height: height))
            centerLabel.text = center ?? ""
            centerLabel.textAlignment = .center
            centerLabel.font = leftLabel.font
            centerLabel.textColor = .secondaryLabel
            centerLabel.lineBreakMode = .byTruncatingTail

            let rightLabel = UILabel(frame: CGRect(x: 2 * width / 3, y: 0, width: width / 3, height: height))
            rightLabel.text = right ?? ""
            rightLabel.textAlignment = .right
            rightLabel.font = leftLabel.font
            rightLabel.textColor = .secondaryLabel
            rightLabel.lineBreakMode = .byTruncatingTail

            container.addSubview(leftLabel)
            container.addSubview(centerLabel)
            container.addSubview(rightLabel)
            return container
        }

        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
            if let handler = onLinkTap {
                return !handler(URL)
            }
            return true
        }
    }
}
#endif