import SwiftUI
import SwiftData

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
    @State private var pdfDataToShare: Data?
    @State private var showShareSheet = false
    
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
        .alert(NSLocalizedString("manuscript.error.exportFailed", comment: "Export Failed"), isPresented: $showExportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportErrorMessage)
        }
    }
    
    @ViewBuilder
    private var bodyContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(sections) { section in
                    sectionView(for: section)
                }
            }
            .padding()
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
    
    @ViewBuilder
    private var bodyToolbarContent: some View {
        HStack(spacing: 16) {
            // Export button
            if !sections.isEmpty {
                Button {
                    exportAsPDF()
                } label: {
                    if isExporting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(isExporting)
            }
            
            // Info menu
            Menu {
                // Info about source folder
                if let sourceFolder = assemblyService?.getBodySourceFolder(for: project) {
                    Label(
                        String(format: NSLocalizedString("manuscript.body.sourceFolder", comment: "Source: %@"), sourceFolder.name ?? ""),
                        systemImage: "folder"
                    )
                }
                
                Divider()
                
                // File count
                let fileCount = sections.reduce(0) { $0 + $1.files.count }
                Label(
                    String(format: NSLocalizedString("manuscript.body.fileCount", comment: "%d files"), fileCount),
                    systemImage: "doc.on.doc"
                )
            } label: {
                Image(systemName: "info.circle")
            }
        }
    }
    
    private func loadBodySections() {
        isLoading = true
        errorMessage = nil
        
        let service = ManuscriptAssemblyService(context: context)
        assemblyService = service
        
        // Get only body sections for this view
        sections = service.getBodySections(for: project)
        
        isLoading = false
    }
    
    private func exportAsPDF() {
        guard let service = assemblyService else { return }
        
        isExporting = true
        
        // Assemble the full content asynchronously
        Task {
            do {
                let content = try await service.assembleContent(for: project)
                
                // Generate PDF on main thread
                await MainActor.run {
                    if let pdfData = PrintService.generatePDF(from: content, project: project, context: context) {
                        pdfDataToShare = pdfData
                        
                        // Share using UIKit
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootViewController = windowScene.windows.first?.rootViewController {
                            let filename = "\(project.name ?? "Manuscript")_body"
                            PrintService.sharePDF(pdfData, filename: filename, from: rootViewController)
                        }
                    } else {
                        exportErrorMessage = NSLocalizedString("manuscript.error.exportFailed", comment: "Export failed")
                        showExportError = true
                    }
                    isExporting = false
                }
            } catch {
                await MainActor.run {
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
