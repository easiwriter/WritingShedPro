import SwiftUI
import SwiftData
import UniformTypeIdentifiers


/// View displaying the assembled manuscript body content (Feature 029)
/// This shows a virtual view of content assembled from source folders (Poems, Scenes, Scripts, Sections)
struct ManuscriptBodyView: View {
    let project: Project
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var assemblyService: ManuscriptAssemblyService?
    @State private var sections: [ManuscriptSection] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isExporting = false
    @State private var showExportError = false
    @State private var exportErrorMessage = ""
    @State private var showExportSaveDialog = false
    @State private var exportData: Data?
    @State private var exportFilename = ""
    @State private var exportContentType: UTType = .pdf
    @State private var frontMatterPageCount: Int = 0
    
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
        .navigationBarBackButtonHidden(true)
        .onPopToRoot {
            dismiss()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                PopToRootBackButton()
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                bodyToolbarContent
            }
        }
        .onAppear {
            loadBodySections()
        }
        .alert(NSLocalizedString("manuscript.error.exportFailedTitle", comment: "Export Failed"), isPresented: $showExportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportErrorMessage)
        }
        .fileExporter(
            isPresented: $showExportSaveDialog,
            document: ExportDocument(
                data: exportData ?? Data(),
                filename: exportFilename,
                contentType: exportContentType
            ),
            contentType: exportContentType,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success(let url):
                #if DEBUG
                print("✅ [ManuscriptBodyView] Exported to: \(url)")
                #endif
            case .failure(let error):
                #if DEBUG
                print("❌ [ManuscriptBodyView] Export failed: \(error)")
                #endif
                exportErrorMessage = error.localizedDescription
                showExportError = true
            }
            exportData = nil
        }
    }
    
    @ViewBuilder
    private var bodyContent: some View {
        // Flatten all files from all sections in order
        let allFiles: [TextFile] = sections.flatMap { $0.files }
        if !allFiles.isEmpty {
            let assembledTextFile = makeAssembledTextFileWithPageBreaks(from: allFiles, name: project.name ?? "Manuscript")
            PaginatedDocumentView(
                textFile: assembledTextFile,
                project: project,
                showActualPageNumbers: true,
                startingPageNumber: frontMatterPageCount + 1
            )
        } else {
            ContentUnavailableView {
                Label("manuscript.body.empty", systemImage: "doc.on.doc")
            } description: {
                Text("manuscript.body.emptyDescription")
            }
        }
    }

    private func loadBodySections() {
        errorMessage = nil
        let service = ManuscriptAssemblyService(context: context)
        assemblyService = service
        // Get only body sections for this view
        sections = service.getBodySections(for: project)
        
        // Calculate how many pages front matter occupies so footer page numbers
        // start at the correct number (e.g. 4 if front matter fills pages 1–3)
        frontMatterPageCount = calculateFrontMatterPageCount(using: service)
        
        #if DEBUG
        print("📄 [ManuscriptBodyView] loadBodySections completed")
        print("📄 [ManuscriptBodyView] Sections count: \(sections.count)")
        for section in sections {
            print("  Section: \(section.title) - \(section.files.count) files")
        }
        print("📄 [ManuscriptBodyView] allFiles count: \(allFiles.count)")
        print("📄 [ManuscriptBodyView] frontMatterPageCount: \(frontMatterPageCount)")
        #endif
        
        isLoading = false
    }

    /// Calculate how many pages front matter occupies by assembling and paginating it
    private func calculateFrontMatterPageCount(using service: ManuscriptAssemblyService) -> Int {
        let allSections = service.getSections(for: project)
        let frontMatterFiles = allSections
            .filter { $0.sectionType == .frontMatter }
            .flatMap { $0.files }
        
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
    
    @ViewBuilder
    private var bodyToolbarContent: some View {
        HStack(spacing: 16) {
            Menu {
                Button(action: exportAsPDF) {
                    Label("Export as PDF", systemImage: "doc.richtext")
                }
                Button(action: exportAsHTML) {
                    Label("Export as HTML", systemImage: "globe")
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(isExporting || allFiles.isEmpty)
        }
    }
    
    private func exportAsPDF() {
        isExporting = true
        
        // Capture values needed off main thread
        let allExportFiles = sections.flatMap { $0.files }
        let isDrama = project.type == .drama
        let scriptType: DramaScriptType = {
            if let raw = project.dramaScriptTypeRaw, let t = DramaScriptType(rawValue: raw) { return t }
            return .stage
        }()
        let styleSheet = project.styleSheet
        let settings = project.manuscriptSettings
        let projectName = project.name ?? "Manuscript"
        
        // Collect file data on main thread (SwiftData objects aren't sendable)
        struct FileExportData {
            let content: String
            let attributedContent: NSAttributedString?
            let isMarkdown: Bool
            let isDrama: Bool
        }
        
        var fileDataList: [FileExportData] = []
        for file in allExportFiles {
            guard let version = file.currentVersion else { continue }
            fileDataList.append(FileExportData(
                content: version.content,
                attributedContent: isDrama || file.isMarkdown ? nil : version.attributedContent,
                isMarkdown: file.isMarkdown,
                isDrama: isDrama
            ))
        }
        
        // Do heavy assembly work off main thread
        Task.detached {
            do {
                let assembled = NSMutableAttributedString()
                
                for (idx, fileData) in fileDataList.enumerated() {
                    if fileData.isDrama {
                        let document = DramaMarkupParser.shared.parse(fileData.content)
                        let rendered = DramaMarkupRenderer.shared.render(
                            document, scriptType: scriptType, viewMode: .formatted, showNotes: false
                        )
                        assembled.append(rendered)
                    } else if fileData.isMarkdown {
                        let rendered = try MarkdownImportService.importMarkdown(
                            from: fileData.content, styleSheet: styleSheet
                        )
                        assembled.append(rendered)
                    } else if let rtfContent = fileData.attributedContent {
                        assembled.append(rtfContent)
                    } else {
                        assembled.append(NSAttributedString(
                            string: fileData.content,
                            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
                        ))
                    }
                    
                    if idx < fileDataList.count - 1 {
                        let breakStr: String
                        switch settings.sectionBreakStyle {
                        case .pageBreak: breakStr = "\u{0C}"
                        case .sectionMark: breakStr = "\n\n§\n\n\n"
                        case .doubleSpace: breakStr = "\n\n\n"
                        case .none: breakStr = "\n\n\n"
                        }
                        assembled.append(NSAttributedString(string: breakStr))
                    }
                }
                
                #if DEBUG
                print("📄 [ManuscriptBodyView] Assembled rich text length: \(assembled.length)")
                print("📄 [ManuscriptBodyView] Files: \(fileDataList.count)")
                #endif
                
                // Only hop to main thread for PDF rendering (UIKit drawing) and UI updates
                await MainActor.run { [assembled] in
                    let content = ManuscriptContent(
                        attributedString: assembled,
                        sections: sections,
                        fileOffsets: [:]
                    )
                    
                    if let pdfData = PrintService.generatePDF(from: content, project: project, context: context) {
                        let filename = "\(projectName)_body"
                        exportData = pdfData
                        exportFilename = "\(filename).pdf"
                        exportContentType = .pdf
                        showExportSaveDialog = true
                    } else {
                        #if DEBUG
                        print("❌ [ManuscriptBodyView] PrintService.generatePDF returned nil")
                        #endif
                        exportErrorMessage = NSLocalizedString("manuscript.error.exportFailedGeneric", comment: "Export failed")
                        showExportError = true
                    }
                    isExporting = false
                }
            } catch {
                #if DEBUG
                print("❌ [ManuscriptBodyView] PDF export error: \(error)")
                #endif
                await MainActor.run {
                    exportErrorMessage = error.localizedDescription
                    showExportError = true
                    isExporting = false
                }
            }
        }
    }
    
    private func exportAsHTML() {
        isExporting = true
        
        Task {
            // Collect all Markdown content from the files with file-based anchors
            var allMarkdown: [String] = []
            
            for section in sections {
                for file in section.files {
                    if let version = file.currentVersion {
                        // Get the plain text content (which is Markdown)
                        let content = version.content
                        if !content.isEmpty {
                            // Create anchor ID from filename (without extension)
                            let filename = file.name
                            let anchorId = filename
                                .replacingOccurrences(of: ".md", with: "")
                                .lowercased()
                                .replacingOccurrences(of: " ", with: "-")
                                .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
                            
                            // Add anchor marker before content (will be converted to <a id="...">)
                            let contentWithAnchor = "%%FILEANCHOR:\(anchorId)%%\n\n\(content)"
                            allMarkdown.append(contentWithAnchor)
                        }
                    }
                }
            }
            
            // Files already end with --- so just join with newlines
            let combinedMarkdown = allMarkdown.joined(separator: "\n\n")
            
            #if DEBUG
            print("🌐 [ManuscriptBodyView] Exporting HTML from Markdown, total length: \(combinedMarkdown.count)")
            #endif
            
            await MainActor.run {
                do {
                    let filename = project.name ?? "Manuscript"
                    let htmlData = try HTMLExportService.exportMarkdownToHTMLData(
                        combinedMarkdown,
                        filename: filename
                    )
                    
                    // Set up file exporter
                    exportData = htmlData
                    exportFilename = "\(filename).html"
                    exportContentType = .html
                    showExportSaveDialog = true
                    isExporting = false
                } catch {
                    #if DEBUG
                    print("❌ [ManuscriptBodyView] HTML export error: \(error)")
                    #endif
                    exportErrorMessage = error.localizedDescription
                    showExportError = true
                    isExporting = false
                }
            }
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
