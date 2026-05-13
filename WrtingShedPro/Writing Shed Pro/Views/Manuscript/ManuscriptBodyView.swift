import SwiftUI
import SwiftData
import UniformTypeIdentifiers


/// View displaying assembled manuscript content.
/// Uses the shared manuscript assembly pipeline (front + body + back matter).
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
        .navigationTitle("Manuscript")

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
        do {
            // Use the same assembly path as manuscript export/preview for consistent behavior.
            let content = try await service.assembleContent(for: project)
            sections = content.sections

            guard content.attributedString.length > 0 else {
                isLoading = false
                return
            }

            let tf = TextFile(name: project.name ?? "Manuscript")
            if let version = tf.versions?.first {
                version.attributedContent = content.attributedString
            }
            assembledTextFile = tf

            // Full manuscript now starts at page 1.
            frontMatterPageCount = 0

            #if DEBUG
            print("📄 [ManuscriptBodyView] Full assembly complete. sections: \(sections.count), length: \(content.attributedString.length)")
            #endif
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
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

    private var previewText: NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributedText)
        mutable.enumerateAttribute(.poemSectionType, in: NSRange(location: 0, length: mutable.length), options: []) { value, range, _ in
            guard let raw = value as? String,
                  let sectionType = PoemSectionType(rawValue: raw),
                  !sectionType.isAnalyzed else {
                return
            }
            mutable.removeAttribute(.foregroundColor, range: range)
            mutable.removeAttribute(.backgroundColor, range: range)
        }
        return mutable
    }
    
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
        uiView.attributedText = previewText
        uiView.invalidateIntrinsicContentSize()
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }
}
