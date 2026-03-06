//
//  PoetryCollectionPoemsView.swift
//  Writing Shed Pro
//
//  Feature 036: Detail view for a PoetryCollection
//  Shows poems assigned to this collection, supports add/remove/reorder
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// View for displaying and managing poems within a poetry collection
struct PoetryCollectionPoemsView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Properties
    
    let project: Project
    @Bindable var collection: PoetryCollection
    
    // MARK: - State
    
    @State private var showAddPoemsSheet = false
    @State private var editMode: EditMode = .inactive
    @State private var selectedFileIDs: Set<UUID> = []
    @State private var showRemoveConfirmation = false
    @State private var showPrintError = false
    @State private var printErrorMessage = ""
    
    // Export state
    @State private var showExportMenu = false
    @State private var showExportSaveDialog = false
    @State private var exportFormat: ExportFormat = .rtf
    @State private var exportData: Data?
    @State private var exportFilename: String = ""
    @State private var showExportImageWarning = false
    @State private var pendingExportAction: (() -> Void)?
    
    // MARK: - Computed
    
    private var sortedFiles: [TextFile] {
        (collection.textFiles ?? []).sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
    }
    
    private var isEditMode: Bool {
        editMode == .active
    }
    
    private var selectedFiles: [TextFile] {
        sortedFiles.filter { selectedFileIDs.contains($0.id) }
    }
    
    private var showToolbar: Bool {
        isEditMode && !selectedFileIDs.isEmpty
    }
    
    /// Available poems: poems from Poems folder not yet in this collection
    private var availablePoems: [TextFile] {
        let poemsFolder = project.folders?.first { $0.name == "Poems" }
        let allPoems = poemsFolder?.textFiles ?? []
        let assignedIDs = Set((collection.textFiles ?? []).map { $0.id })
        return allPoems.filter { !assignedIDs.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if sortedFiles.isEmpty {
                emptyState
            } else {
                fileList
            }
        }
        .navigationTitle(collection.name ?? NSLocalizedString("poetry.collection.untitled", comment: "Untitled"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showAddPoemsSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(NSLocalizedString("poetry.collection.addPoems", comment: "Add poems"))
                .disabled(availablePoems.isEmpty || isEditMode)
                
                // Edit/Done button
                if !sortedFiles.isEmpty {
                    Button {
                        withAnimation {
                            if editMode == .active {
                                editMode = .inactive
                                selectedFileIDs.removeAll()
                            } else {
                                editMode = .active
                            }
                        }
                    } label: {
                        Text(isEditMode ? NSLocalizedString("button.done", comment: "Done") : NSLocalizedString("button.edit", comment: "Edit"))
                    }
                }
                
                // More menu (export/print)
                if !sortedFiles.isEmpty && !isEditMode {
                    Menu {
                        Button(action: { showExportMenu = true }) {
                            Label(NSLocalizedString("button.export", comment: "Export"), systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: { printCollection() }) {
                            Label(NSLocalizedString("button.print", comment: "Print"), systemImage: "printer")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            
            // Bottom toolbar for multi-select actions
            ToolbarItemGroup(placement: .bottomBar) {
                if showToolbar {
                    bottomToolbarContent
                }
            }
        }
        .sheet(isPresented: $showAddPoemsSheet) {
            addPoemsSheet
        }
        .alert(
            selectedFiles.count == 1
                ? NSLocalizedString("poetry.collection.removeConfirm.title", comment: "Remove from collection?")
                : String(format: NSLocalizedString("poetry.collection.removeMultiple.title", comment: "Remove poems?"), selectedFiles.count),
            isPresented: $showRemoveConfirmation
        ) {
            Button(NSLocalizedString("button.remove", comment: "Remove"), role: .destructive) {
                removeSelectedFiles()
            }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("poetry.collection.removeConfirm.message", comment: "Poems will be unassigned from this collection but not deleted."))
        }
        .onChange(of: editMode) { _, newValue in
            if newValue == .inactive {
                selectedFileIDs.removeAll()
            }
        }
        .confirmationDialog(
            NSLocalizedString("export.dialog.title", comment: "Export Format"),
            isPresented: $showExportMenu,
            titleVisibility: .visible
        ) {
            exportDialogButtons
        }
        .alert(NSLocalizedString("export.imageWarning.title", comment: "Images Not Included"), isPresented: $showExportImageWarning) {
            Button(NSLocalizedString("export.imageWarning.continue", comment: "Continue")) {
                pendingExportAction?()
                pendingExportAction = nil
            }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                pendingExportAction = nil
            }
        } message: {
            Text(NSLocalizedString("export.imageWarning.message", comment: "Images will not be included"))
        }
        .fileExporter(
            isPresented: $showExportSaveDialog,
            document: ExportDocument(data: exportData ?? Data(), filename: exportFilename, contentType: contentTypeForFormat(exportFormat)),
            contentType: contentTypeForFormat(exportFormat),
            defaultFilename: exportFilename
        ) { result in
            #if DEBUG
            switch result {
            case .success(let url):
                print("✅ Exported to: \(url)")
            case .failure(let error):
                print("❌ Export save failed: \(error)")
            }
            #endif
        }
        .alert(NSLocalizedString("print.error.title", comment: "Print Error"), isPresented: $showPrintError) {
            Button(NSLocalizedString("button.ok", comment: "OK")) { }
        } message: {
            Text(printErrorMessage)
        }
    }
    
    // MARK: - Bottom Toolbar
    
    @ViewBuilder
    private var bottomToolbarContent: some View {
        Spacer()
        
        // Remove button (unassign from collection)
        Button(role: .destructive) {
            showRemoveConfirmation = true
        } label: {
            Label(
                String(format: NSLocalizedString("poetry.collection.removeCount", comment: "Remove count"), selectedFiles.count),
                systemImage: "minus.circle"
            )
        }
        .disabled(selectedFiles.isEmpty)
    }
    
    // MARK: - File List
    
    private var fileList: some View {
        List(selection: $selectedFileIDs) {
            ForEach(sortedFiles) { file in
                Group {
                    if isEditMode {
                        PoemRowView(file: file)
                    } else {
                        NavigationLink {
                            FileEditView(file: file)
                        } label: {
                            PoemRowView(file: file)
                        }
                    }
                }
            }
            .onMove(perform: moveFiles)
            .onDelete(perform: deleteFiles)
        }
        .listStyle(.plain)
        .environment(\.editMode, $editMode)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("poetry.collection.empty.title", comment: "No Poems"))
                .font(.headline)
            
            Text(NSLocalizedString("poetry.collection.empty.message", comment: "Add poems with 'ready' status to this collection."))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if !availablePoems.isEmpty {
                Button {
                    showAddPoemsSheet = true
                } label: {
                    Label(NSLocalizedString("poetry.collection.addPoems", comment: "Add Poems"), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    // MARK: - Add Poems Sheet
    
    @ViewBuilder
    private var addPoemsSheet: some View {
        NavigationStack {
            List {
                ForEach(availablePoems) { file in
                    Button {
                        addPoemToCollection(file)
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.blue)
                            Text(file.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("poetry.collection.addPoems.title", comment: "Add Poems"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("button.done", comment: "Done")) {
                        showAddPoemsSheet = false
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func addPoemToCollection(_ file: TextFile) {
        file.poetryCollection = collection
        let nextOrder = (sortedFiles.map { $0.userOrder ?? 0 }.max() ?? -1) + 1
        file.userOrder = nextOrder
        collection.modifiedDate = Date()
        try? modelContext.save()
    }
    
    private func removeSelectedFiles() {
        for file in selectedFiles {
            file.poetryCollection = nil
        }
        collection.modifiedDate = Date()
        try? modelContext.save()
        selectedFileIDs.removeAll()
        editMode = .inactive
    }
    
    private func deleteFiles(at offsets: IndexSet) {
        for index in offsets {
            let file = sortedFiles[index]
            file.poetryCollection = nil
        }
        collection.modifiedDate = Date()
        try? modelContext.save()
    }
    
    // MARK: - Export
    
    @ViewBuilder
    private var exportDialogButtons: some View {
        Button(ExportFormat.pdf.localizedName) {
            exportCollectionPoems(format: .pdf)
        }
        Button(ExportFormat.rtf.localizedName) {
            pendingExportAction = { exportCollectionPoems(format: .rtf) }
            showImageWarningAfterDelay()
        }
        Button(ExportFormat.html.localizedName) {
            exportCollectionPoems(format: .html)
        }
        Button(ExportFormat.word.localizedName) {
            exportCollectionPoems(format: .word)
        }
        Button(ExportFormat.markdown.localizedName) {
            pendingExportAction = { exportCollectionPoems(format: .markdown) }
            showImageWarningAfterDelay()
        }
        Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
    }
    
    private func showImageWarningAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showExportImageWarning = true
        }
    }
    
    private func exportCollectionPoems(format: ExportFormat) {
        self.exportFormat = format
        
        let files = sortedFiles
        guard !files.isEmpty else { return }
        
        let filename = collection.name ?? "Collection"
        
        if format == .pdf {
            // Use the same assembly approach as manuscript export for proper page views
            Task {
                let assembled = NSMutableAttributedString()
                var isFirstFile = true
                
                for file in files {
                    guard let version = file.currentVersion, let content = version.attributedContent else { continue }
                    
                    if !isFirstFile {
                        // Add page break between files (same as manuscript assembly)
                        let breakString = NSAttributedString(string: "\u{000C}")
                        assembled.append(breakString)
                    }
                    isFirstFile = false
                    assembled.append(content)
                }
                
                guard assembled.length > 0 else { return }
                
                let manuscriptContent = ManuscriptContent(
                    attributedString: assembled,
                    sections: [],
                    fileOffsets: [:],
                    frontMatterFileCount: 0,
                    frontMatterCharacterLength: 0,
                    assembledFootnotes: []
                )
                
                let pdfData = PrintService.generatePDF(
                    from: manuscriptContent,
                    project: project,
                    pageSetup: project.pageSetup,
                    context: modelContext
                )
                
                await MainActor.run {
                    guard let pdfData = pdfData else { return }
                    exportData = pdfData
                    exportFilename = "\(filename).pdf"
                    showExportSaveDialog = true
                }
            }
            return
        }
        
        // Build attributed strings for other formats
        var attributedStrings: [NSAttributedString] = []
        for file in files {
            guard let version = file.currentVersion else { continue }
            let content: NSAttributedString
            if let formatted = version.attributedContent {
                content = formatted
            } else if !version.content.isEmpty {
                content = NSAttributedString(
                    string: version.content,
                    attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
                )
            } else {
                continue
            }
            attributedStrings.append(content)
        }
        
        guard !attributedStrings.isEmpty else { return }
        
        Task {
            do {
                let data: Data
                switch format {
                case .rtf:
                    data = try await Task.detached {
                        try WordDocumentService.exportMultipleToRTF(attributedStrings, filename: filename)
                    }.value
                case .html:
                    data = try await Task.detached {
                        try HTMLExportService.exportMultipleToHTMLData(attributedStrings, filename: filename)
                    }.value
                case .word:
                    data = try await Task.detached { [weak modelContext] in
                        guard let modelContext = modelContext else { throw DOCXExportError.noContent }
                        let exportService = DOCXExportService(modelContext: modelContext)
                        return try exportService.exportMultipleToDOCX(attributedStrings, filename: filename)
                    }.value
                case .markdown:
                    data = try await Task.detached {
                        try MarkdownExportService.exportMultipleToMarkdownData(attributedStrings, filename: filename)
                    }.value
                default:
                    return
                }
                
                await MainActor.run {
                    exportData = data
                    exportFilename = "\(filename).\(format.fileExtension)"
                    showExportSaveDialog = true
                }
            } catch {
                #if DEBUG
                print("❌ Export failed: \(error)")
                #endif
            }
        }
    }
    
    private func contentTypeForFormat(_ format: ExportFormat) -> UTType {
        switch format {
        case .rtf: return .rtf
        case .html: return .html
        case .epub: return UTType(filenameExtension: "epub") ?? .data
        case .word: return UTType("org.openxmlformats.wordprocessingml.document") ?? .data
        case .pdf: return .pdf
        case .plainText: return .plainText
        case .markdown: return UTType(filenameExtension: "md") ?? .plainText
        case .fountain: return UTType(filenameExtension: "fountain") ?? .plainText
        case .finalDraft: return UTType(filenameExtension: "fdx") ?? .xml
        }
    }
    
    // MARK: - Printing
    
    private func printCollection() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let viewController = window.rootViewController else {
            printErrorMessage = "Unable to present print dialog"
            showPrintError = true
            return
        }
        
        let files = sortedFiles
        guard !files.isEmpty else { return }
        
        PrintService.printFiles(files, project: project, context: modelContext, from: viewController) { success, error in
            if let error = error {
                printErrorMessage = error.localizedDescription
                showPrintError = true
            }
        }
    }
    
    private func moveFiles(from source: IndexSet, to destination: Int) {
        var files = sortedFiles
        files.move(fromOffsets: source, toOffset: destination)
        for (index, file) in files.enumerated() {
            file.userOrder = index
        }
        collection.modifiedDate = Date()
        try? modelContext.save()
    }
}

// MARK: - Poem Row View

struct PoemRowView: View {
    let file: TextFile
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.body)
                
                if let version = file.currentVersion {
                    let charCount = version.content.count
                    Text(String(format: NSLocalizedString("poetry.collection.charCount", comment: "%d characters"), charCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}
