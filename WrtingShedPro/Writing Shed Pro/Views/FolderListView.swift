import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct FolderListView: View {
    let project: Project
    let selectedFolder: Folder?
    
    @Environment(\.modelContext) var modelContext
    @State private var showAddFolderSheet = false
    @State private var isLoadingFolders = true
    @State private var loadedFolders: [Folder] = []
    
    // Manuscript export/preview/print state
    @State private var isExporting = false
    @State private var showExportError = false
    @State private var exportErrorMessage = ""
    @State private var showExportSaveDialog = false
    @State private var exportData: Data?
    @State private var exportFilename = ""
    @State private var exportContentType: UTType = .pdf
    @State private var showPreview = false
    @State private var previewPDFData: Data?
    @State private var showPrintError = false
    @State private var printErrorMessage = ""
    @State private var showDramaExportFormatPicker = false
    
    // Manuscript submit state
    @State private var showSubmissionNamePrompt = false
    @State private var newSubmissionName: String = ""
    @State private var showSubmissionCreated = false
    @State private var createdSubmissionName: String = ""
    @State private var showDuplicateSubmission = false
    @State private var manuscriptFilesToSubmit: [TextFile] = []
    
    // Query all trash items to check if trash folder should be shown
    @Query private var allTrashItems: [TrashItem]
    
    init(project: Project, selectedFolder: Folder? = nil) {
        self.project = project
        self.selectedFolder = selectedFolder
    }
    
    // Get all project folders in the correct order (not alphabetically!)
    var projectFolders: [Folder] {
        guard !isLoadingFolders else { return [] }
        let order = folderOrderForProjectType(project.type)
        
        // Filter to only top-level folders (no parent folder)
        var topLevelFolders = loadedFolders.filter { $0.parentFolder == nil }
        
        // Hide redundant folders based on fiction class
        if project.type == .fiction {
            switch project.fictionClass {
            case .verseNovel:
                // Verse novels use Books/Episodes, not Chapters/Scenes
                topLevelFolders = topLevelFolders.filter { ($0.name ?? "") != "Chapters" && ($0.name ?? "") != "Scenes" }
            case .shortFiction:
                // Short fiction uses Stories/Scenes, not Chapters
                topLevelFolders = topLevelFolders.filter { ($0.name ?? "") != "Chapters" }
            case .novel:
                // Novels use Chapters/Scenes, not Stories/Books/Episodes
                topLevelFolders = topLevelFolders.filter { ($0.name ?? "") != "Stories" && ($0.name ?? "") != "Books" && ($0.name ?? "") != "Episodes" }
            default:
                break
            }
        }
        
        // Sort folders by predefined order
        return topLevelFolders.sorted { folder1, folder2 in
            let name1 = folder1.name ?? ""
            let name2 = folder2.name ?? ""
            let index1 = order.firstIndex(of: name1) ?? Int.max
            let index2 = order.firstIndex(of: name2) ?? Int.max
            return index1 < index2
        }
    }
    
    // Define the display order for each project type
    // Updated: Workflow status is now on files, not folders
    private func folderOrderForProjectType(_ type: ProjectType) -> [String] {
        switch type {
        case .prose:
            return [
                // Section 1: Story Structure
                "Manuscript", "Sections", "Prose",
                // Section 2: Organization & Support
                "Submissions", "Research",
                // Section 3: Publications
                "Publishers", "Agents", "Other",
                // Section 4: System
                "Trash"
            ]
            
        case .poetry:
            // Manuscript, Collections, Poems // Submissions, Research // Magazines, Competitions, Other // Trash
            return [
                // Section 1: Primary Content
                "Manuscript", "Collections", "Poems",
                // Section 2: Organization & Support
                "Submissions", "Research",
                // Section 3: Publications
                "Magazines", "Competitions", "Other",
                // Section 4: System
                "Trash"
            ]
            
        case .fiction:
            // Novel: Manuscript, Chapters, Scenes, Characters, Locations, Plot // Collections, Submissions, Research // Publishers, Agents, Other // Trash
            // Short: Manuscript, Stories, Scenes, Characters, Locations, Plot // Collections, Submissions, Research // Magazines, Competitions, Other // Trash
            // Verse Novel: Manuscript, Books, Episodes, Characters, Locations, Plot // Collections, Submissions, Research // Publishers, Agents, Other // Trash
            return [
                // Section 1: Story Structure
                "Manuscript", "Chapters", "Stories", "Books", "Scenes", "Episodes", "Characters", "Locations", "Plot",
                // Section 2: Organization & Support
                "Submissions", "Research",
                // Section 3: Publications (all possible - some may not exist based on fiction class)
                "Publishers", "Agents", "Magazines", "Competitions", "Other",
                // Section 4: System
                "Trash"
            ]
            
        case .drama:
            // Manuscript, Acts, Scenes, Characters, Locations, Plot // Collections, Submissions, Research // Publishers, Agents, Other // Trash
            return [
                // Section 1: Story Structure
                "Manuscript", "Acts", "Scenes", "Characters", "Locations", "Plot",
                // Section 2: Organization & Support
                "Submissions", "Research",
                // Section 3: Publications
                "Publishers", "Agents", "Other",
                // Section 4: System
                "Trash"
            ]
        }
    }
    
    // Determines if spacing should be added after this folder
    private func shouldAddSpacingAfter(folder: Folder) -> Bool {
        // Don't add spacing for prose projects (they have sections like fiction)
        guard project.type != .prose else {
            let folderName = folder.name ?? ""
            // Section breaks after: Prose, Research, Other
            return folderName == "Prose" || folderName == "Research" || folderName == "Other"
        }
        
        let folderName = folder.name ?? ""
        
        // Add spacing after "Research" (separates support from publications)
        // and after "Other" (separates publications from Trash)
        // For poetry, add spacing after "Manuscript" (separates workflow from support)
        // For fiction, add spacing after "Plot" (separates entity folders from support)
        if project.type == .poetry {
            // Section breaks after: Poems, Research, Other
            return folderName == "Poems" || folderName == "Research" || folderName == "Other"
        }
        
        if project.type == .fiction {
            // Section breaks after: Plot, Research, Other
            return folderName == "Plot" || folderName == "Research" || folderName == "Other"
        }
        
        if project.type == .drama {
            // Section breaks after: Plot, Research, Other
            return folderName == "Plot" || folderName == "Research" || folderName == "Other"
        }
        
        return folderName == "Research" || folderName == "Other"
    }
    
    // MARK: - Folder Navigation Routing
    
    @ViewBuilder
    private func folderNavigationLink(for folder: Folder) -> some View {
        let folderName: String = folder.name ?? ""
        if folderName == "Trash" {
            let trashedItemsForProject = allTrashItems.filter { $0.project?.id == project.id }
            if !trashedItemsForProject.isEmpty {
                NavigationLink(destination: TrashView(project: project)) {
                    FolderRowView(folder: folder)
                }
            }
        } else if let publicationType = publicationTypeForFolder(folderName) {
            NavigationLink(destination: PublicationsListView(project: project, publicationType: publicationType)) {
                FolderRowView(folder: folder)
            }
        } else if folderName == "Submissions" {
            NavigationLink(destination: SubmissionsView(project: project)) {
                FolderRowView(folder: folder)
            }
        } else if folderName == "Characters" && (project.type == .fiction || project.type == .drama) {
            NavigationLink(destination: CharacterListView(project: project)) {
                FolderRowView(folder: folder)
            }
        } else if folderName == "Locations" && (project.type == .fiction || project.type == .drama) {
            NavigationLink(destination: LocationListView(project: project)) {
                FolderRowView(folder: folder)
            }
        } else if folderName == "Plot" && (project.type == .fiction || project.type == .drama) {
            NavigationLink(destination: PlotOutlineView(project: project)) {
                FolderRowView(folder: folder)
            }
        } else if folderName == "Acts" && project.type == .drama {
            NavigationLink(destination: ActListView(project: project)) {
                FolderRowView(folder: folder)
            }
        } else if folderName == "Chapters" && project.type == .fiction {
            NavigationLink(destination: ChapterListView(project: project)) {
                FolderRowView(folder: folder)
            }
        } else if folderName == "Stories" && project.type == .fiction && project.fictionClass == .shortFiction {
            NavigationLink(destination: ChapterListView(project: project)) {
                FolderRowView(folder: folder)
            }
        } else if folderName == "Books" && project.type == .fiction && project.fictionClass == .verseNovel {
            NavigationLink(destination: ChapterListView(project: project)) {
                FolderRowView(folder: folder)
            }
        } else if folderName == "Episodes" && project.type == .fiction && project.fictionClass == .verseNovel {
            NavigationLink(destination: SceneListView(project: project)) {
                FolderRowView(folder: folder)
            }
        } else if folderName == "Sections" && project.type == .prose {
            NavigationLink(destination: SectionListView(project: project)) {
                FolderRowView(folder: folder)
            }
        } else if folderName == "Prose" && project.type == .prose {
            NavigationLink(destination: ProseListView(project: project)) {
                FolderRowView(folder: folder)
            }
        } else if folderName == "Collections" && project.type == .poetry {
            NavigationLink(destination: PoetryCollectionsView(project: project)) {
                FolderRowView(folder: folder)
            }
        } else if folderName == "Scenes" && (project.type == .fiction || project.type == .drama) {
            NavigationLink(destination: SceneListView(project: project)) {
                FolderRowView(folder: folder)
            }
        } else if folderName == "Manuscript" {
            NavigationLink(destination: FolderListView(project: project, selectedFolder: folder)) {
                FolderRowView(folder: folder)
            }
        } else {
            capabilityBasedLink(for: folder)
        }
    }
    
    @ViewBuilder
    private func subfolderNavigationLink(for subfolder: Folder) -> some View {
        let subfolderName: String = subfolder.name ?? ""
        let isManuscriptBodyFolder: Bool = selectedFolder?.name == "Manuscript" &&
            ["Body", "Body Matter", "All Acts", "All Poems", "All Sections", "All Chapters", "All Stories", "All Books"].contains(subfolderName)
        
        if isManuscriptBodyFolder {
            NavigationLink(destination: BodyMatterView(project: project)) {
                FolderRowView(folder: subfolder)
            }
        } else {
            capabilityBasedLink(for: subfolder)
        }
    }
    
    @ViewBuilder
    private func capabilityBasedLink(for folder: Folder) -> some View {
        let canAddSubfolder: Bool = FolderCapabilityService.canAddSubfolder(to: folder)
        let canAddFile: Bool = FolderCapabilityService.canAddFile(to: folder)
        
        if canAddFile {
            NavigationLink(destination: FolderFilesView(folder: folder)) {
                FolderRowView(folder: folder)
            }
        } else if canAddSubfolder {
            NavigationLink(destination: FolderListView(project: project, selectedFolder: folder)) {
                FolderRowView(folder: folder)
            }
        } else {
            NavigationLink(destination: FolderFilesView(folder: folder)) {
                FolderRowView(folder: folder)
            }
        }
    }
    
    // Get subfolders for the selected folder
    var currentSubfolders: [Folder] {
        guard let selectedFolder = selectedFolder else { return [] }
        let subfolders = selectedFolder.folders ?? []
        
        // Special ordering for Manuscript subfolders: Front Matter, Body, Back Matter
        if selectedFolder.name == "Manuscript" {
            // All possible body folder names (project-type-specific with "All" prefix)
            let bodyFolderNames: Set<String> = ["Body", "Body Matter", "All Acts", "All Poems", "All Sections", "All Chapters", "All Stories", "All Books"]
            return subfolders.sorted { folder1, folder2 in
                let name1 = folder1.name ?? ""
                let name2 = folder2.name ?? ""
                // Front Matter = 0, any body folder = 1, Back Matter = 2, others = 3
                let order1 = name1 == "Front Matter" ? 0 : (bodyFolderNames.contains(name1) ? 1 : (name1 == "Back Matter" ? 2 : 3))
                let order2 = name2 == "Front Matter" ? 0 : (bodyFolderNames.contains(name2) ? 1 : (name2 == "Back Matter" ? 2 : 3))
                return order1 < order2
            }
        }
        
        // Default: alphabetical order
        return subfolders.sorted(by: { ($0.name ?? "") < ($1.name ?? "") })
    }
    
    var body: some View {
        Group {
            if isLoadingFolders {
                // Show loading indicator while fetching folders
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                folderListContent
            }
        }
        .navigationTitle(selectedFolder?.name ?? project.name ?? NSLocalizedString("folderList.title", comment: "Folders title"))
        .navigationBarTitleDisplayMode(selectedFolder == nil ? .large : .inline)

        .task {
            // Load folders asynchronously to avoid blocking navigation
            await loadFolders()
        }
    }
    
    @ViewBuilder
    private var folderListContent: some View {
        List {
            if selectedFolder == nil {
                // Show all project folders in a simple list
                ForEach(projectFolders) { folder in
                    folderNavigationLink(for: folder)
                    if shouldAddSpacingAfter(folder: folder) {
                        Divider()
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    }
                }
            } else {
                // Show subfolders if any exist
                if !currentSubfolders.isEmpty {
                    Section {
                        ForEach(currentSubfolders) { subfolder in
                            subfolderNavigationLink(for: subfolder)
                        }
                    } header: {
                        Text(NSLocalizedString("folderList.foldersHeader", comment: "Folders section header"))
                    }
                }
                
                // Show empty state only if no subfolders
                if currentSubfolders.isEmpty {
                    EmptyFolderView(folder: selectedFolder!)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let selectedFolder = selectedFolder {
                    let canAddFolder = FolderCapabilityService.canAddSubfolder(to: selectedFolder)
                    
                    if canAddFolder {
                        Button(action: { showAddFolderSheet = true }) {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("folderList.addFolder.accessibility")
                    }
                }
            }
            
            // Manuscript folder: preview, export, and print toolbar items
            if isManuscriptFolder {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            submitManuscript()
                        } label: {
                            Label(NSLocalizedString("fileList.addToSubmission", comment: "Add to submission"), systemImage: "tray.and.arrow.down")
                        }
                        .disabled(isExporting)
                        
                        Button {
                            generatePreview()
                        } label: {
                            Label(NSLocalizedString("manuscript.preview", comment: "Preview"), systemImage: "eye")
                        }
                        .disabled(isExporting)
                        
                        Button {
                            if project.type == .drama {
                                showDramaExportFormatPicker = true
                            } else {
                                exportManuscriptPDF()
                            }
                        } label: {
                            Label(NSLocalizedString("manuscript.export", comment: "Export"), systemImage: "square.and.arrow.up")
                        }
                        .disabled(isExporting)
                        
                        Button {
                            printManuscript()
                        } label: {
                            Label(NSLocalizedString("manuscript.print", comment: "Print"), systemImage: "printer")
                        }
                        .disabled(isExporting || !PrintService.isPrintingAvailable())
                    }
                }
            }
        }
        .alert(NSLocalizedString("manuscript.error.exportFailedTitle", comment: "Export Failed"), isPresented: $showExportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportErrorMessage)
        }
        .alert(NSLocalizedString("manuscript.error.printFailedTitle", comment: "Print Failed"), isPresented: $showPrintError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(printErrorMessage)
        }
        .confirmationDialog(
            NSLocalizedString("manuscript.export.formatTitle", comment: "Export Format"),
            isPresented: $showDramaExportFormatPicker,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("export.format.pdf", comment: "PDF Document")) {
                exportManuscriptPDF()
            }
            Button(NSLocalizedString("export.format.fountain", comment: "Fountain (Screenplay)")) {
                exportManuscriptFountain()
            }
            Button(NSLocalizedString("export.format.finalDraft", comment: "Final Draft (.fdx)")) {
                exportManuscriptFinalDraft()
            }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
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
                print("✅ [Manuscript] Exported to: \(url)")
                #endif
            case .failure(let error):
                #if DEBUG
                print("❌ [Manuscript] Export failed: \(error)")
                #endif
                exportErrorMessage = error.localizedDescription
                showExportError = true
            }
            exportData = nil
        }
        .sheet(isPresented: $showPreview) {
            ManuscriptPreviewView(
                pdfData: previewPDFData,
                title: project.name ?? NSLocalizedString("manuscript.preview.title", comment: "Manuscript Preview"),
                pdfGenerator: previewPDFData == nil ? makeManuscriptPDFGenerator() : nil
            )
        }
        .sheet(isPresented: $showAddFolderSheet) {
            AddFolderSheet(
                isPresented: $showAddFolderSheet,
                project: project,
                parentFolder: selectedFolder,
                existingFolders: selectedFolder != nil ? currentSubfolders : projectFolders
            )
        }
        .alert(NSLocalizedString("submissions.name.title", comment: "Name Submission"), isPresented: $showSubmissionNamePrompt) {
            TextField(NSLocalizedString("submissions.name.placeholder", comment: "Name"), text: $newSubmissionName)
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                newSubmissionName = ""
                manuscriptFilesToSubmit = []
            }
            Button(NSLocalizedString("button.create", comment: "Create")) {
                createSubmissionFromManuscript(name: newSubmissionName)
                newSubmissionName = ""
            }
            .disabled(newSubmissionName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text(NSLocalizedString("submissions.name.message", comment: "Enter a name"))
        }
        .alert(NSLocalizedString("submissions.created.title", comment: "Submission Created"), isPresented: $showSubmissionCreated) {
            Button(NSLocalizedString("button.ok", comment: "OK")) { }
        } message: {
            Text(String(format: NSLocalizedString("submissions.created.message", comment: "Created message"), createdSubmissionName))
        }
        .alert(NSLocalizedString("submissions.duplicate.title", comment: "Duplicate Submission"), isPresented: $showDuplicateSubmission) {
            Button(NSLocalizedString("button.ok", comment: "OK")) { }
        } message: {
            Text(String(format: NSLocalizedString("submissions.duplicate.message", comment: "Duplicate message"), createdSubmissionName))
        }
    }
    
    // MARK: - Manuscript Export/Preview Helpers
    
    /// Whether the current folder is the Manuscript folder
    private var isManuscriptFolder: Bool {
        selectedFolder?.name == "Manuscript"
    }
    
    /// Show PDF preview — the sheet appears immediately and generates the PDF in the background
    private func generatePreview() {
        previewPDFData = nil
        showPreview = true
    }
    
    /// Build the async PDF generator closure for the manuscript preview sheet
    private func makeManuscriptPDFGenerator() -> (@escaping (Double, String) -> Void) async -> Data? {
        let project = project
        let modelContext = modelContext
        return { report in
            let assemblyService = ManuscriptAssemblyService(context: modelContext)
            do {
                // Phase 0: Regenerate TOC so it includes all current headings + correct page numbers
                let tocService = TOCGenerationService(context: modelContext)
                await tocService.regenerateTOCForExport(project: project)
                
                // Phase 1: Assembly (0% → 5%) — fast for most projects
                let content = try await assemblyService.assembleContent(for: project) { current, total in
                    let frac: Double = total > 0 ? 0.05 * Double(current) / Double(total) : 0
                    let text: String = String(format: NSLocalizedString("manuscript.preview.assembling", comment: ""), current, total)
                    report(frac, text)
                }
                guard content.attributedString.length > 0 else { return nil }
                let finalContent = FolderListView.insertCoverImages(into: content, project: project)
                
                report(0.05, NSLocalizedString("manuscript.preview.layouting", comment: "Laying out pages…"))
                
                // Phase 2+3: Layout + Render (5% → 100%)
                return await PrintService.generatePDFWithProgress(
                    from: finalContent,
                    project: project,
                    pageSetup: project.pageSetup,
                    context: modelContext,
                    layoutProgress: { (pagesCalculated: Int, estimatedTotal: Int) in
                        let frac: Double = estimatedTotal > 0 ? min(Double(pagesCalculated) / Double(estimatedTotal), 1.0) : 0
                        let overallFrac: Double = 0.05 + 0.90 * frac
                        let text: String = String(format: NSLocalizedString("manuscript.preview.renderingPage", comment: ""), pagesCalculated, estimatedTotal)
                        report(overallFrac, text)
                    },
                    renderProgress: { (currentPage: Int, totalPages: Int) in
                        let renderFrac: Double = totalPages > 0 ? Double(currentPage) / Double(totalPages) : 0
                        let frac: Double = 0.95 + 0.05 * renderFrac
                        let text: String = String(format: NSLocalizedString("manuscript.preview.renderingPage", comment: ""), currentPage, totalPages)
                        report(frac, text)
                    }
                )
            } catch {
                #if DEBUG
                print("❌ [Manuscript] Preview PDF generation error: \(error)")
                #endif
                return nil
            }
        }
    }
    
    /// Submit the manuscript body matter files to a publication
    private func submitManuscript() {
        let assemblyService = ManuscriptAssemblyService(context: modelContext)
        let files = assemblyService.getBodyMatterFiles(for: project)
        guard !files.isEmpty else {
            exportErrorMessage = NSLocalizedString("manuscript.error.noBodyMatterFiles", comment: "No body matter files to submit")
            showExportError = true
            return
        }
        manuscriptFilesToSubmit = files
        showSubmissionNamePrompt = true
    }
    
    private func createSubmissionFromManuscript(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        // Check for duplicate submission name in this project
        let projectID = project.id
        var duplicateCheck = FetchDescriptor<Submission>(predicate: #Predicate<Submission> { submission in
            submission.name == trimmedName && submission.project?.id == projectID && submission.isCollection == false
        })
        duplicateCheck.fetchLimit = 1
        if let count = try? modelContext.fetchCount(duplicateCheck), count > 0 {
            createdSubmissionName = trimmedName
            showDuplicateSubmission = true
            return
        }
        
        let submission = Submission(
            project: project,
            submittedDate: Date()
        )
        submission.name = trimmedName
        submission.isCollection = false
        modelContext.insert(submission)
        
        for file in manuscriptFilesToSubmit {
            let submittedFile = SubmittedFile(
                submission: submission,
                textFile: file,
                version: file.currentVersion,
                status: .pending,
                statusDate: Date(),
                project: project
            )
            modelContext.insert(submittedFile)
        }
        
        try? modelContext.save()
        createdSubmissionName = trimmedName
        showSubmissionCreated = true
        manuscriptFilesToSubmit = []
    }
    
    /// Export the full manuscript as PDF
    private func exportManuscriptPDF() {
        isExporting = true
        let projectName = project.name ?? "Manuscript"
        
        Task {
            if let data = await generateManuscriptPDF() {
                await MainActor.run {
                    exportData = data
                    exportContentType = .pdf
                    exportFilename = "\(projectName).pdf"
                    showExportSaveDialog = true
                    isExporting = false
                }
            } else {
                await MainActor.run {
                    exportErrorMessage = NSLocalizedString("manuscript.error.exportFailedGeneric", comment: "Export failed")
                    showExportError = true
                    isExporting = false
                }
            }
        }
    }
    
    /// Export the full drama manuscript as Fountain (.fountain)
    private func exportManuscriptFountain() {
        isExporting = true
        let projectName = project.name ?? "Manuscript"
        
        Task {
            let assemblyService = ManuscriptAssemblyService(context: modelContext)
            do {
                let dml = try await assemblyService.assembleDML(for: project)
                let fountain = FountainConverter.shared.dmlToFountain(dml)
                guard let data = fountain.data(using: .utf8) else {
                    throw AssemblyError.noFilesFound
                }
                await MainActor.run {
                    exportData = data
                    exportContentType = UTType(filenameExtension: "fountain") ?? .plainText
                    exportFilename = "\(projectName).fountain"
                    showExportSaveDialog = true
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    exportErrorMessage = NSLocalizedString("manuscript.error.exportFailedGeneric", comment: "Export failed")
                    showExportError = true
                    isExporting = false
                }
            }
        }
    }
    
    /// Export the full drama manuscript as Final Draft (.fdx)
    private func exportManuscriptFinalDraft() {
        isExporting = true
        let projectName = project.name ?? "Manuscript"
        
        Task {
            let assemblyService = ManuscriptAssemblyService(context: modelContext)
            do {
                let dml = try await assemblyService.assembleDML(for: project)
                let fdxString = FinalDraftConverter.shared.dmlToFDX(dml, title: projectName)
                guard let data = fdxString.data(using: .utf8) else {
                    throw AssemblyError.noFilesFound
                }
                await MainActor.run {
                    exportData = data
                    exportContentType = UTType(filenameExtension: "fdx") ?? .xml
                    exportFilename = "\(projectName).fdx"
                    showExportSaveDialog = true
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    exportErrorMessage = NSLocalizedString("manuscript.error.exportFailedGeneric", comment: "Export failed")
                    showExportError = true
                    isExporting = false
                }
            }
        }
    }
    
    /// Print the full manuscript via the system print dialog
    private func printManuscript() {
        isExporting = true
        
        Task {
            let pdfData = await generateManuscriptPDF()
            
            await MainActor.run {
                isExporting = false
                
                guard let data = pdfData else {
                    printErrorMessage = NSLocalizedString("manuscript.error.exportFailedGeneric", comment: "Failed to generate PDF")
                    showPrintError = true
                    return
                }
                
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first,
                      let _ = window.rootViewController else {
                    printErrorMessage = NSLocalizedString("manuscript.error.printNoViewController", comment: "Unable to present print dialog")
                    showPrintError = true
                    return
                }
                
                let printController = UIPrintInteractionController.shared
                let printInfo = UIPrintInfo.printInfo()
                printInfo.jobName = project.name ?? "Manuscript"
                printInfo.outputType = .general
                printController.printInfo = printInfo
                printController.printingItem = data
                
                printController.present(animated: true) { _, completed, error in
                    if let error = error {
                        #if DEBUG
                        print("❌ [Manuscript] Print error: \(error.localizedDescription)")
                        #endif
                        printErrorMessage = error.localizedDescription
                        showPrintError = true
                    } else if completed {
                        #if DEBUG
                        print("✅ [Manuscript] Print job completed")
                        #endif
                    }
                }
            }
        }
    }
    
    /// Assemble and generate the full manuscript as PDF Data
    private func generateManuscriptPDF() async -> Data? {
        let assemblyService = ManuscriptAssemblyService(context: modelContext)
        
        do {
            // Regenerate TOC so it includes all current headings + correct page numbers
            let tocService = TOCGenerationService(context: modelContext)
            await tocService.regenerateTOCForExport(project: project)
            
            let content = try await assemblyService.assembleContent(for: project)
            
            guard content.attributedString.length > 0 else { return nil }
            
            // Insert cover images into the assembled content
            let finalContent = Self.insertCoverImages(into: content, project: project)
            
            return PrintService.generatePDF(
                from: finalContent,
                project: project,
                pageSetup: project.pageSetup,
                context: modelContext
            )
        } catch {
            #if DEBUG
            print("❌ [Manuscript] PDF generation error: \(error)")
            #endif
            return nil
        }
    }
    
    /// Insert front/back cover images into manuscript content
    static func insertCoverImages(into content: ManuscriptContent, project: Project) -> ManuscriptContent {
        let assembled = NSMutableAttributedString()
        var hasFrontCover = false
        var hasBackCover = false
        var frontCoverData: Data?
        var backCoverData: Data?
        
        // Front cover: find front cover file and prepend its image
        if let manuscriptFolder = project.folders?.first(where: { $0.name == "Manuscript" }),
           let frontMatterFolder = manuscriptFolder.folders?.first(where: { $0.name == "Front Matter" }),
           let frontCoverFile = frontMatterFolder.textFiles?.first(where: { $0.isCoverFile && $0.name == FrontMatterItem.frontCover.fileName }),
           frontCoverFile.includedInManuscript,
           let imageData = frontCoverFile.coverImageData,
           UIImage(data: imageData) != nil {
            frontCoverData = imageData
            // Insert a lightweight placeholder for the cover page.
            // The actual image is drawn directly by CustomPDFPageRenderer.drawCoverImage()
            // from the project's cover file data, bypassing the text layout system entirely.
            // Using NSTextAttachment with large images causes NSLayoutManager sizing
            // issues on smaller devices (iPhone).
            assembled.append(NSAttributedString(string: " ")) // placeholder
            assembled.append(NSAttributedString(string: "\u{0C}")) // Page break after cover
            hasFrontCover = true
        }
        
        assembled.append(content.attributedString)
        
        // Adjust frontMatterCharacterLength for the cover content prepended above.
        // The assembly-time value is relative to the original string; adding a front cover
        // shifts all character positions by the cover's length (attachment + form feed).
        let adjustedFMCharLength: Int
        if hasFrontCover {
            let coverPrefixLength = assembled.length - content.attributedString.length
            adjustedFMCharLength = content.frontMatterCharacterLength + coverPrefixLength
        } else {
            adjustedFMCharLength = content.frontMatterCharacterLength
        }
        
        // Adjust footnote positions when a front cover shifts all character positions
        let adjustedFootnotes: [ManuscriptFootnote]
        if hasFrontCover {
            let coverPrefixLength = assembled.length - content.attributedString.length
            adjustedFootnotes = content.assembledFootnotes.map { fn in
                ManuscriptFootnote(
                    attachmentID: fn.attachmentID,
                    text: fn.text,
                    number: fn.number,
                    characterPosition: fn.characterPosition + coverPrefixLength
                )
            }
        } else {
            adjustedFootnotes = content.assembledFootnotes
        }
        
        // Back cover: find back cover file and append its image
        if let manuscriptFolder = project.folders?.first(where: { $0.name == "Manuscript" }),
           let backMatterFolder = manuscriptFolder.folders?.first(where: { $0.name == "Back Matter" }),
           let backCoverFile = backMatterFolder.textFiles?.first(where: { $0.isCoverFile && $0.name == BackMatterItem.backCover.fileName }),
           backCoverFile.includedInManuscript,
           let imageData = backCoverFile.coverImageData,
           UIImage(data: imageData) != nil {
            backCoverData = imageData
            assembled.append(NSAttributedString(string: "\u{0C}")) // Page break before cover
            // Insert a lightweight placeholder for the cover page.
            // The actual image is drawn directly by CustomPDFPageRenderer.drawCoverImage()
            assembled.append(NSAttributedString(string: " ")) // placeholder
            hasBackCover = true
        }
        
        return ManuscriptContent(
            attributedString: assembled,
            sections: content.sections,
            pageMap: content.pageMap,
            fileOffsets: content.fileOffsets,
            pageCount: content.pageCount,
            hasFrontCover: hasFrontCover,
            hasBackCover: hasBackCover,
            frontMatterFileCount: content.frontMatterFileCount,
            frontMatterCharacterLength: adjustedFMCharLength,
            assembledFootnotes: adjustedFootnotes,
            frontCoverImageData: frontCoverData,
            backCoverImageData: backCoverData
        )
    }

    // Load folders asynchronously to avoid blocking UI
    private func loadFolders() async {
        // Access the folders relationship asynchronously
        loadedFolders = project.folders ?? []
        isLoadingFolders = false
    }
    
    // Helper function to map folder names to publication types
    private func publicationTypeForFolder(_ folderName: String) -> PublicationType? {
        switch folderName {
        case "Magazines":
            return .magazine
        case "Competitions":
            return .competition
        case "Commissions":
            return .commission
        case "Publishers":
            return .publisher
        case "Agents":
            return .agent
        case "Other":
            return .other
        default:
            return nil
        }
    }
}



// MARK: - Folder Row View

struct FolderRowView: View {
    let folder: Folder
    
    @Query private var allPublications: [Publication]
    @Query private var allSubmissions: [Submission]
    @Query private var allFolders: [Folder]
    @Query private var allTrashItems: [TrashItem]
    
    @State private var fileCount: Int = 0
    @State private var subfolderCount: Int = 0
    
    // Check if this is a publication folder
    private var isPublicationFolder: Bool {
        let name = folder.name ?? ""
        return ["Magazines", "Competitions", "Commissions", "Publishers", "Agents", "Other"].contains(name)
    }
    
    // Check if this is the Submissions folder
    private var isSubmissionsFolder: Bool {
        let name = folder.name ?? ""
        return name == "Submissions"
    }
    
    // Check if this is the All folder (virtual folder)
    private var isAllFolder: Bool {
        let name = folder.name ?? ""
        return name == "All"
    }
    
    // Check if this is the Trash folder
    private var isTrashFolder: Bool {
        let name = folder.name ?? ""
        return name == "Trash"
    }
    
    // Check if this is the Plot folder (fiction/drama projects)
    private var isPlotFolder: Bool {
        let name = folder.name ?? ""
        return name == "Plot" && (folder.project?.type == .fiction || folder.project?.type == .drama)
    }
    
    // Check if this is the Characters folder (fiction/drama projects)
    private var isCharactersFolder: Bool {
        let name = folder.name ?? ""
        return name == "Characters" && (folder.project?.type == .fiction || folder.project?.type == .drama)
    }
    
    // Check if this is the Locations folder (fiction/drama projects)
    private var isLocationsFolder: Bool {
        let name = folder.name ?? ""
        return name == "Locations" && (folder.project?.type == .fiction || folder.project?.type == .drama)
    }
    
    // Check if this is the Scenes/Episodes folder (fiction/drama projects)
    private var isScenesFolder: Bool {
        let name = folder.name ?? ""
        return (name == "Scenes" || name == "Episodes") && (folder.project?.type == .fiction || folder.project?.type == .drama)
    }
    
    // Check if this is the Acts folder (drama projects only)
    private var isActsFolder: Bool {
        let name = folder.name ?? ""
        return name == "Acts" && folder.project?.type == .drama
    }
    
    // Check if this is the Chapters folder (fiction/novel projects only)
    // Check if this is the Chapters, Stories, or Books folder (fiction projects)
    private var isChaptersFolder: Bool {
        let name = folder.name ?? ""
        return (name == "Chapters" || name == "Stories" || name == "Books") && folder.project?.type == .fiction
    }
    
    // Check if this is the Sections folder (prose projects only)
    private var isSectionsFolder: Bool {
        let name = folder.name ?? ""
        return name == "Sections" && folder.project?.type == .prose
    }
    
    // Check if this is the Collections folder (poetry projects only)
    private var isCollectionsFolder: Bool {
        let name = folder.name ?? ""
        return name == "Collections" && folder.project?.type == .poetry
    }
    
    // Get plot element count for Plot folder
    private var plotElementCount: Int {
        guard isPlotFolder, let project = folder.project else { return 0 }
        return project.plotElements?.count ?? 0
    }
    
    // Get character count for Characters folder
    private var characterCount: Int {
        guard isCharactersFolder, let project = folder.project else { return 0 }
        return project.characters?.count ?? 0
    }
    
    // Get location count for Locations folder
    private var locationCount: Int {
        guard isLocationsFolder, let project = folder.project else { return 0 }
        return project.locations?.count ?? 0
    }
    
    // Get scene count for Scenes folder
    private var sceneCount: Int {
        guard isScenesFolder, let project = folder.project else { return 0 }
        return project.scenes?.count ?? 0
    }
    
    // Get act count for Acts folder
    private var actCount: Int {
        guard isActsFolder, let project = folder.project else { return 0 }
        return project.acts?.count ?? 0
    }
    
    // Get chapter/story count for Chapters/Stories folder
    private var chapterCount: Int {
        guard isChaptersFolder, let project = folder.project else { return 0 }
        return project.chapters?.count ?? 0
    }
    
    // Get section count for Sections folder
    private var sectionCount: Int {
        guard isSectionsFolder, let project = folder.project else { return 0 }
        return project.sections?.count ?? 0
    }
    
    // Get collection count for Collections folder (poetry)
    private var collectionCount: Int {
        guard isCollectionsFolder, let project = folder.project else { return 0 }
        return project.poetryCollections?.count ?? 0
    }
    
    // Get submission count for Submissions folder
    private var submissionCount: Int {
        guard isSubmissionsFolder, let project = folder.project else { return 0 }
        let projectID: UUID = project.id
        return allSubmissions.filter { (submission: Submission) -> Bool in
            !submission.isCollection && submission.project?.id == projectID
        }.count
    }
    
    // Get publication count for this folder type
    private var publicationCount: Int {
        guard isPublicationFolder, let project = folder.project else { return 0 }
        let projectID: UUID = project.id
        let folderName: String = folder.name ?? ""
        let publicationType: PublicationType?
        
        switch folderName {
        case "Magazines":
            publicationType = .magazine
        case "Competitions":
            publicationType = .competition
        case "Commissions":
            publicationType = .commission
        case "Publishers":
            publicationType = .publisher
        case "Agents":
            publicationType = .agent
        case "Other":
            publicationType = .other
        default:
            return 0
        }
        
        return allPublications.filter { (pub: Publication) -> Bool in
            pub.project?.id == projectID && pub.type == publicationType
        }.count
    }
    
    // Folder display name with count in brackets
    private var folderDisplayName: String {
        let baseName = folder.name ?? NSLocalizedString("folderList.untitledFolder", comment: "Untitled folder")
        
        // Check if this is a Manuscript body folder (should not show count)
        let isManuscriptBodyFolder = folder.parentFolder?.name == "Manuscript" &&
            ["Body", "Body Matter", "All Acts", "All Poems", "All Sections", "All Chapters", "All Stories", "All Books"].contains(baseName)
        
        // Remove count for Manuscript subfolders (Body types, Front Matter, Back Matter) and Manuscript itself
        if baseName == "Manuscript" || baseName == "Front Matter" || baseName == "Back Matter" || isManuscriptBodyFolder {
            return baseName
        }
        let count: Int
        if isPublicationFolder {
            count = publicationCount
        } else if isSubmissionsFolder {
            count = submissionCount
        } else if isPlotFolder {
            count = plotElementCount
        } else if isCharactersFolder {
            count = characterCount
        } else if isLocationsFolder {
            count = locationCount
        } else if isScenesFolder {
            count = sceneCount
        } else if isActsFolder {
            count = actCount
        } else if isChaptersFolder {
            count = chapterCount
        } else if isSectionsFolder {
            count = sectionCount
        } else if isCollectionsFolder {
            count = collectionCount
        } else if isAllFolder {
            count = fileCount
        } else if isTrashFolder {
            count = fileCount
        } else if isMixedContentFolder {
            count = subfolderCount
        } else if subfolderCount > 0 && fileCount > 0 {
            count = subfolderCount + fileCount
        } else if subfolderCount > 0 {
            count = subfolderCount
        } else {
            count = fileCount
        }
        return "\(baseName) (\(count))"
    }
    
    /// Check if this folder supports mixed content (both files and subfolders)
    private var isMixedContentFolder: Bool {
        FolderCapabilityService.canAddSubfolder(to: folder) && FolderCapabilityService.canAddFile(to: folder)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: folderIcon)
                .foregroundStyle(.blue)
                .font(.title2)
                .accessibilityHidden(true)
            
            // Show folder name with count in brackets
            Text(folderDisplayName)
                .font(.body)
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .task {
            await loadFolderCounts()
        }
    }
    
    private func loadFolderCounts() async {
        if isAllFolder, let project = folder.project {
            let projectFolders: [Folder] = allFolders.filter { (f: Folder) -> Bool in f.project?.id == project.id }
            let targetFolderNames: Set<String> = ["Draft", "Ready", "Set Aside", "Published"]
            
            var totalCount: Int = 0
            for folder in projectFolders where targetFolderNames.contains(folder.name ?? "") {
                totalCount += folder.textFiles?.count ?? 0
            }
            fileCount = totalCount
            subfolderCount = 0
        } else if isTrashFolder, let project = folder.project {
            fileCount = allTrashItems.filter { (item: TrashItem) -> Bool in item.project?.id == project.id }.count
            subfolderCount = 0
        } else {
            fileCount = folder.textFiles?.count ?? 0
            subfolderCount = folder.folders?.count ?? 0
        }
    }
    
    private var folderIcon: String {
        let name = folder.name ?? ""
        
        // Root level folder icons
        if name.contains("Your") {
            return "globe"
        } else if name == "Publications" {
            return "suitcase.cart"
        } else if name == "Trash" {
            return "trash"
        }
        
        // Type-specific subfolder icons
        switch name {
        case "Files":
            return "globe"
        case "Poems":
            return "text.book.closed"
        case "Scenes":
            return "film.stack"
        case "Scripts":
            return "theatermasks"
        case "Collections":
            return "tray.2"
        case "Manuscript":
            return "doc.richtext"
        case "Front Matter":
            return "text.badge.star"
        case "Body":
            return "doc.on.doc"
        case "Body Matter":
            return "doc.on.doc"
        case "Back Matter":
            return "text.append"
        case "Research":
            return "magnifyingglass"
        case "Magazines":
            return "magazine"
        case "Competitions":
            return "medal"
        case "Commissions":
            return "person.2"
        case "Other":
            return "tray"
        // Prose-specific folders
        case "Prose":
            return "doc.text"
        case "Sections":
            return "folder"
        // Fiction-specific folders
        case "Chapters":
            return "document.on.document"
        case "Stories":
            return "books.vertical"
        case "Characters":
            return "person.circle"
        case "Locations":
            return "mountain.2"
        case "Plot":
            return "chart.line.uptrend.xyaxis"
        // Publication-specific folders
        case "Publishers":
            return "building.2"
        case "Agents":
            return "person.fill.badge.plus"
        default:
            if fileCount > 0 {
                return "folder.fill"
            } else {
                return "folder"
            }
        }
    }
    
    private var accessibilityLabel: String {
        return folderDisplayName
    }
}

// MARK: - Empty State View

struct EmptyFolderView: View {
    let folder: Folder
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text(NSLocalizedString("folderList.emptyFolder", comment: "Empty folder message"))
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Text(NSLocalizedString("folderList.tapAddContentHint", comment: "Tap + to add content hint"))
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .listRowBackground(Color.clear)
    }
}
