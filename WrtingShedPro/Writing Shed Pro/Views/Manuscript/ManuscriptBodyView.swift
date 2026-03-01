import SwiftUI
import SwiftData
import UniformTypeIdentifiers


/// View displaying the assembled manuscript body content (Feature 029)
/// This shows a virtual view of content assembled from source folders (Poems, Scenes, Scripts, Sections)
struct ManuscriptBodyView: View {
    let project: Project
    @Environment(\.modelContext) private var context
    
    @State private var assemblyService: ManuscriptAssemblyService?
    @State private var sections: [ManuscriptSection] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var frontMatterPageCount: Int = 0
    /// Pre-assembled text file — built off the main thread so the view appears instantly
    @State private var assembledTextFile: TextFile?
    
    var allFiles: [TextFile] {
        sections.flatMap { $0.files }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView(NSLocalizedString("manuscript.progress.assembling", comment: "Assembling..."))
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("manuscript.error.assemblyFailed", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else if sections.isEmpty {
                ContentUnavailableView {
                    Label("manuscript.body.empty", systemImage: "doc.on.doc")
                } description: {
                    Text("manuscript.body.emptyDescription")
                }
            } else {
                bodyContent
            }
        }
        .navigationTitle(NSLocalizedString("folder.body", comment: "Body"))

        .task {
            await loadBodySections()
        }
    }
    
    @ViewBuilder
    private var bodyContent: some View {
        if let textFile = assembledTextFile {
            PaginatedDocumentView(
                textFile: textFile,
                project: project,
                showActualPageNumbers: true,
                startingPageNumber: frontMatterPageCount + 1,
                showPrintButton: false
            )
        } else {
            ContentUnavailableView {
                Label("manuscript.body.empty", systemImage: "doc.on.doc")
            } description: {
                Text("manuscript.body.emptyDescription")
            }
        }
    }

    private func loadBodySections() async {
        errorMessage = nil
        let service = ManuscriptAssemblyService(context: context)
        assemblyService = service
        // Get only body sections for this view
        sections = service.getBodySections(for: project)
        
        let files = allFiles
        
        #if DEBUG
        print("📄 [ManuscriptBodyView] loadBodySections: \(sections.count) sections, \(files.count) files")
        #endif
        
        guard !files.isEmpty else {
            isLoading = false
            return
        }
        
        // Yield so SwiftUI can display the loading indicator before heavy work begins
        await Task.yield()
        
        // Calculate front matter page count
        frontMatterPageCount = calculateFrontMatterPageCount(using: service)
        
        // Assemble all files into a single TextFile with page breaks
        assembledTextFile = makeAssembledTextFileWithPageBreaks(from: files, name: project.name ?? "Manuscript")
        
        #if DEBUG
        print("📄 [ManuscriptBodyView] Assembly complete. frontMatterPageCount: \(frontMatterPageCount), assembled: \(assembledTextFile != nil)")
        #endif
        
        isLoading = false
    }

    /// Calculate how many pages front matter occupies by assembling and paginating it
    private func calculateFrontMatterPageCount(using service: ManuscriptAssemblyService) -> Int {
        let allSections = service.getSections(for: project)
        let frontMatterFiles = allSections
            .filter { $0.sectionType == .frontMatter }
            .flatMap { $0.files }
            .filter { !$0.isCoverFile }  // Cover files don't contribute to page count
        
        guard !frontMatterFiles.isEmpty else { return 0 }
        
        let pageSetup = project.pageSetup ?? PageSetup.createWithDefaults()
        
        // Paginate each front matter file individually — no form feeds needed for counting.
        // Each front matter file starts on its own page and occupies at least 1 page.
        var totalPages = 0
        
        for file in frontMatterFiles {
            if let version = file.currentVersion, let content = version.attributedContent, content.length > 0 {
                // Strip trailing form feed characters (artifacts from previous assembly)
                // and remove Catalyst font scaling for print-accurate page counting
                let mutable = NSMutableAttributedString(attributedString: content)
                while mutable.length > 0 && mutable.string.hasSuffix("\u{000C}") {
                    mutable.deleteCharacters(in: NSRange(location: mutable.length - 1, length: 1))
                }
                guard mutable.length > 0 else {
                    totalPages += 1
                    continue
                }
                let prepared = PrintFormatter.removePlatformScaling(from: mutable)
                let textStorage = NSTextStorage(attributedString: prepared)
                let layoutManager = PaginatedTextLayoutManager(textStorage: textStorage, pageSetup: pageSetup)
                let result = layoutManager.calculateLayout()
                totalPages += max(result.totalPages, 1)
            } else {
                totalPages += 1  // Empty front matter file still occupies 1 page
            }
        }
        
        #if DEBUG
        print("📄 [ManuscriptBodyView] Front matter: \(frontMatterFiles.count) files → \(totalPages) pages")
        #endif
        
        return totalPages
    }

    private func makeAssembledTextFileWithPageBreaks(from files: [TextFile], name: String) -> TextFile {
        let attributed = NSMutableAttributedString()
        let isDrama = project.type == .drama
        let scriptType: DramaScriptType = {
            if let raw = project.dramaScriptTypeRaw, let t = DramaScriptType(rawValue: raw) { return t }
            return .stage
        }()
        let usePageBreak = project.pageSetup?.hasPageBreakBetweenFiles ?? true
    #if DEBUG
        print("[ManuscriptBodyView] makeAssembledTextFileWithPageBreaks: usePageBreak=", usePageBreak)
    #endif
        let breakStyle = project.manuscriptSettings.sectionBreakStyle
        for (idx, file) in files.enumerated() {
            if isDrama, let plain = file.currentVersion?.content {
                // Render DML source using DramaMarkupRenderer
                let document = DramaMarkupParser.shared.parse(plain)
                let rendered = DramaMarkupRenderer.shared.render(
                    document,
                    scriptType: scriptType,
                    viewMode: .formatted,
                    showNotes: false
                )
                attributed.append(rendered)
            } else if let attr = file.currentVersion?.attributedContent {
                attributed.append(attr)
            } else if let plain = file.currentVersion?.content {
                attributed.append(NSAttributedString(string: plain))
            }
            // Insert break between files according to user setting
            if idx < files.count - 1 {
                if usePageBreak {
                    // Only insert page break if content doesn't already end with one
                    if !attributed.string.hasSuffix("\u{000C}") {
                        attributed.append(NSAttributedString(string: "\u{000C}")) // Unicode FORM FEED (page break)
                    }
                } else {
                    // Always add at least two blank lines between files for clarity
                    switch breakStyle {
                    case .sectionMark:
                        attributed.append(NSAttributedString(string: "\n\n\u{00A7}\n\n\n"))
                    case .doubleSpace:
                        attributed.append(NSAttributedString(string: "\n\n\n"))
                    case .pageBreak, .none:
                        attributed.append(NSAttributedString(string: "\n\n\n"))
                    }
                }
            }
        }
        let tf = TextFile(name: name)
        if let version = tf.versions?.first {
            version.attributedContent = attributed
        }
        return tf
    }
    
    @ViewBuilder
    private func sectionView(for section: ManuscriptSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header (for chapters, etc.)
            if section.level > 0 {
                Text(section.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
            }
            
            // Files in this section
            ForEach(section.files) { file in
                fileContentView(for: file)
            }
        }
    }
    
    @ViewBuilder
    private func fileContentView(for file: TextFile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // File title
            HStack {
                Text(file.name)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Navigate to edit button
                NavigationLink {
                    FileEditView(file: file)
                } label: {
                    Image(systemName: "pencil.circle")
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
            
            // File content
            if let content = file.currentVersion?.attributedContent {
                AttributedTextDisplayView(attributedText: content)
            } else {
                Text(file.currentVersion?.content ?? "")
                    .font(.body)
            }
            
            Divider()
                .padding(.vertical, 8)
        }
    }
}



// MARK: - Attributed Text Display View

/// A read-only view for displaying attributed text content
struct AttributedTextDisplayView: UIViewRepresentable {
    let attributedText: NSAttributedString
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false  // Let SwiftUI ScrollView handle scrolling
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = attributedText
        uiView.invalidateIntrinsicContentSize()
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }
}
