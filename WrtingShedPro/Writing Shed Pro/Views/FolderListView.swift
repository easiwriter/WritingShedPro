import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct FolderListView: View {
    let project: Project
    let selectedFolder: Folder?
    
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) private var dismiss
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
    @State private var showPreview = false
    @State private var previewPDFData: Data?
    @State private var showPrintError = false
    @State private var printErrorMessage = ""
    
    // Manuscript submit state
    @State private var showSubmitManuscript = false
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
        // Use native iOS back button - immune to SwiftUI render blocking
        .navigationBarBackButtonHidden(false)
        .onPopToRoot {
            // Dismiss this view when pop-to-root is triggered
            dismiss()
        }
        .toolbar {
            // Trailing toolbar items only - no custom back button needed
        }
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
                    // Special handling for Trash folder: only show if not empty
                    if folder.name == "Trash" {
                        let trashedItemsForProject = allTrashItems.filter { $0.project?.id == project.id }
                        if !trashedItemsForProject.isEmpty {
                            NavigationLink(destination: TrashView(project: project)) {
                                FolderRowView(folder: folder)
                            }
                        }
                    } else {
                        // Check if this is a publication folder (Magazines, Competitions, Commissions, Other)
                        let folderName = folder.name ?? ""
                        if let publicationType = publicationTypeForFolder(folderName) {
                            // Navigate to publications list filtered by type
                            NavigationLink(destination: PublicationsListView(project: project, publicationType: publicationType)) {
                                FolderRowView(folder: folder)
                            }
                        } else if folderName == "Submissions" {
                            // Special handling for Submissions folder - show publication submissions
                            NavigationLink(destination: SubmissionsView(project: project)) {
                                FolderRowView(folder: folder)
                            }
                        } else if folderName == "Characters" && project.type == .fiction {
                            // Fiction: Characters folder navigates to CharacterListView
                            NavigationLink(destination: CharacterListView(project: project)) {
                                FolderRowView(folder: folder)
                            }
                        } else if folderName == "Characters" && project.type == .drama {
                            // Drama: Characters folder navigates to CharacterListView
                            NavigationLink(destination: CharacterListView(project: project)) {
                                FolderRowView(folder: folder)
                            }
                        } else if folderName == "Locations" && project.type == .fiction {
                            // Fiction: Locations folder navigates to LocationListView
                            NavigationLink(destination: LocationListView(project: project)) {
                                FolderRowView(folder: folder)
                            }
                        } else if folderName == "Locations" && project.type == .drama {
                            // Drama: Locations folder navigates to LocationListView
                            NavigationLink(destination: LocationListView(project: project)) {
                                FolderRowView(folder: folder)
                            }
                        } else if folderName == "Plot" && project.type == .fiction {
                            // Fiction: Plot folder navigates to PlotOutlineView
                            NavigationLink(destination: PlotOutlineView(project: project)) {
                                FolderRowView(folder: folder)
                            }
                        } else if folderName == "Plot" && project.type == .drama {
                            // Drama: Plot folder navigates to PlotOutlineView
                            NavigationLink(destination: PlotOutlineView(project: project)) {
                                FolderRowView(folder: folder)
                            }
                        } else if folderName == "Acts" && project.type == .drama {
                            // Drama: Acts folder navigates to ActListView
                            NavigationLink(destination: ActListView(project: project)) {
                                FolderRowView(folder: folder)
                            }
                        } else if folderName == "Chapters" && project.type == .fiction {
                            // Fiction (Novel): Chapters folder navigates to ChapterListView
                            NavigationLink(destination: ChapterListView(project: project)) {
                                FolderRowView(folder: folder)
                            }
                        } else if folderName == "Stories" && project.type == .fiction && project.fictionClass == .shortFiction {
                            // Fiction (Short Fiction): Stories folder navigates to ChapterListView (reuses same view)
                            NavigationLink(destination: ChapterListView(project: project)) {
                                FolderRowView(folder: folder)
                            }
                        } else if folderName == "Books" && project.type == .fiction && project.fictionClass == .verseNovel {
                            // Verse Novel: Books folder navigates to ChapterListView
                            NavigationLink(destination: ChapterListView(project: project)) {
                                FolderRowView(folder: folder)
                            }
                        } else if folderName == "Episodes" && project.type == .fiction && project.fictionClass == .verseNovel {
                            // Verse Novel: Episodes folder navigates to SceneListView
                            NavigationLink(destination: SceneListView(project: project)) {
                                FolderRowView(folder: folder)
                            }
                        } else if folderName == "Sections" && project.type == .prose {
                            // Prose: Sections folder navigates to SectionListView
                            NavigationLink(destination: SectionListView(project: project)) {
                                FolderRowView(folder: folder)
                            }
                        } else if folderName == "Prose" && project.type == .prose {
                            // Prose: Prose folder navigates to ProseListView
                            NavigationLink(destination: ProseListView(project: project)) {
                                FolderRowView(folder: folder)
                            }
                        } else if folderName == "Collections" && project.type == .poetry {
                            // Poetry: Collections folder navigates to PoetryCollectionsView
                            NavigationLink(destination: PoetryCollectionsView(project: project)) {
                                FolderRowView(folder: folder)
                            }
                        } else if folderName == "Scenes" && project.type == .fiction {
                            // Fiction (Short Fiction): Scenes folder navigates to SceneListView
                            NavigationLink(destination: SceneListView(project: project)) {
                                FolderRowView(folder: folder)
                            }
                        } else if folderName == "Scenes" && project.type == .drama {
                            // Drama: Scenes folder navigates to SceneListView
                            NavigationLink(destination: SceneListView(project: project)) {
                                FolderRowView(folder: folder)
                            }
                        } else if folderName == "Manuscript" {
                            // Manuscript folder (Feature 029): Navigate to show subfolders (Front Matter, Body, Back Matter)
                            NavigationLink(destination: FolderListView(project: project, selectedFolder: folder)) {
                                FolderRowView(folder: folder)
                            }
                        } else {
                            // Navigate based on folder capabilities
                            let canAddSubfolder = FolderCapabilityService.canAddSubfolder(to: folder)
                            let canAddFile = FolderCapabilityService.canAddFile(to: folder)
                            
                            if canAddFile {
                                // Mixed content or file-only folders - navigate to FolderFilesView
                                // FolderFilesView handles both files and subfolders for mixed-content folders
                                NavigationLink(destination: FolderFilesView(folder: folder)) {
                                    FolderRowView(folder: folder)
                                }
                            } else if canAddSubfolder {
                                // Subfolder-only folders (Chapters, Acts, etc.) - navigate to FolderListView
                                NavigationLink(destination: FolderListView(project: project, selectedFolder: folder)) {
                                    FolderRowView(folder: folder)
                                }
                            } else {
                                // Read-only folders - navigate to FolderFilesView (view-only)
                                NavigationLink(destination: FolderFilesView(folder: folder)) {
                                    FolderRowView(folder: folder)
                                }
                            }
                        }
                    }
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
                            let subfolderName = subfolder.name ?? ""
                            
                            // Special handling for Manuscript Body subfolder (Feature 029)
                            // Body folder is named "Body Matter" (new) or with "All" prefix (legacy)
                            let isManuscriptBodyFolder = selectedFolder?.name == "Manuscript" && 
                                ["Body", "Body Matter", "All Acts", "All Poems", "All Sections", "All Chapters", "All Stories", "All Books"].contains(subfolderName)
                            
                            if isManuscriptBodyFolder {
                                NavigationLink(destination: BodyMatterView(project: project)) {
                                    FolderRowView(folder: subfolder)
                                }
                            } else {
                                // Navigate based on folder capabilities
                                let canAddSubfolder = FolderCapabilityService.canAddSubfolder(to: subfolder)
                                let canAddFile = FolderCapabilityService.canAddFile(to: subfolder)
                                
                                if canAddFile {
                                    // Mixed content or file-only folders - navigate to FolderFilesView
                                    NavigationLink(destination: FolderFilesView(folder: subfolder)) {
                                        FolderRowView(folder: subfolder)
                                    }
                                } else if canAddSubfolder {
                                    // Subfolder-only folders - navigate to FolderListView
                                    NavigationLink(destination: FolderListView(project: project, selectedFolder: subfolder)) {
                                        FolderRowView(folder: subfolder)
                                    }
                                } else {
                                    // Read-only folders - navigate to FolderFilesView
                                    NavigationLink(destination: FolderFilesView(folder: subfolder)) {
                                        FolderRowView(folder: subfolder)
                                    }
                                }
                            }
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
                            Label(NSLocalizedString("manuscript.submit", comment: "Submit"), systemImage: "paperplane")
                        }
                        .disabled(isExporting)
                        
                        Button {
                            generatePreview()
                        } label: {
                            Label(NSLocalizedString("manuscript.preview", comment: "Preview"), systemImage: "eye")
                        }
                        .disabled(isExporting)
                        
                        Button {
                            exportManuscriptPDF()
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
        .fileExporter(
            isPresented: $showExportSaveDialog,
            document: ExportDocument(
                data: exportData ?? Data(),
                filename: exportFilename,
                contentType: .pdf
            ),
            contentType: .pdf,
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
                pdfGenerator: previewPDFData == nil ? { [project, modelContext] report in
                    let assemblyService = ManuscriptAssemblyService(context: modelContext)
                    do {
                        // Phase 0: Regenerate TOC so it includes all current headings + correct page numbers
                        let tocService = TOCGenerationService(context: modelContext)
                        await tocService.regenerateTOCForExport(project: project)
                        
                        // Phase 1: Assembly (0% → 5%) — fast for most projects
                        let content = try await assemblyService.assembleContent(for: project) { current, total in
                            let frac = total > 0 ? 0.05 * Double(current) / Double(total) : 0
                            let text = String(format: NSLocalizedString("manuscript.preview.assembling", comment: ""), current, total)
                            report(frac, text)
                        }
                        guard content.attributedString.length > 0 else { return nil }
                        let finalContent = FolderListView.insertCoverImages(into: content, project: project)
                        
                        report(0.05, NSLocalizedString("manuscript.preview.layouting", comment: "Laying out pages…"))
                        
                        // Phase 2+3: Layout + Render (5% → 100%)
                        // For documents with form-feed page breaks and no footnotes,
                        // the fast path combines layout+render into one linear pass.
                        return await PrintService.generatePDFWithProgress(
                            from: finalContent,
                            project: project,
                            pageSetup: project.pageSetup,
                            context: modelContext,
                            layoutProgress: { pagesCalculated, estimatedTotal in
                                let frac = estimatedTotal > 0 ? min(Double(pagesCalculated) / Double(estimatedTotal), 1.0) : 0
                                let overallFrac = 0.05 + 0.90 * frac
                                let text = String(format: NSLocalizedString("manuscript.preview.renderingPage", comment: ""), pagesCalculated, estimatedTotal)
                                report(overallFrac, text)
                            },
                            renderProgress: { currentPage, totalPages in
                                let renderFrac = totalPages > 0 ? Double(currentPage) / Double(totalPages) : 0
                                let frac = 0.95 + 0.05 * renderFrac
                                let text = String(format: NSLocalizedString("manuscript.preview.renderingPage", comment: ""), currentPage, totalPages)
                                report(frac, text)
                            }
                        )
                    } catch {
                        #if DEBUG
                        print("❌ [Manuscript] Preview PDF generation error: \(error)")
                        #endif
                        return nil
                    }
                } : nil
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
        .sheet(isPresented: $showSubmitManuscript) {
            NavigationStack {
                SubmissionPickerView(
                    project: project,
                    filesToSubmit: manuscriptFilesToSubmit,
                    collectionToSubmit: nil,
                    onPublicationSelected: { publication, name, expectedDate, reminderDate in
                        createManuscriptSubmission(for: publication, name: name, expectedResponseDate: expectedDate, reminderDate: reminderDate)
                        showSubmitManuscript = false
                    },
                    onCancel: {
                        showSubmitManuscript = false
                    }
                )
            }
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
        showSubmitManuscript = true
    }
    
    /// Create a Submission for manuscript body matter files
    private func createManuscriptSubmission(for publication: Publication, name: String, expectedResponseDate: Date? = nil, reminderDate: Date? = nil) {
        let submission = Submission(
            publication: publication,
            project: project,
            submittedDate: Date(),
            notes: nil
        )
        submission.name = name
        submission.isCollection = false
        submission.returnExpectedBy = expectedResponseDate
        
        // Schedule reminder notification if requested
        if let reminderDate = reminderDate {
            submission.reminderDate = reminderDate
            let pubName = publication.name
            let subName = name
            Task {
                let notifId = await NotificationReminderService.shared.scheduleSubmissionReminder(
                    submissionId: UUID().uuidString,
                    publicationName: pubName,
                    submissionName: subName,
                    reminderDate: reminderDate
                )
                if let notifId = notifId {
                    await MainActor.run {
                        submission.reminderNotificationId = notifId
                    }
                }
            }
        }
        
        modelContext.insert(submission)
        
        for file in manuscriptFilesToSubmit {
            if let currentVersion = file.currentVersion {
                let submittedFile = SubmittedFile(
                    submission: submission,
                    textFile: file,
                    version: currentVersion,
                    status: .pending,
                    statusDate: Date(),
                    project: project
                )
                modelContext.insert(submittedFile)
            }
        }
        
        manuscriptFilesToSubmit = []
        #if DEBUG
        print("✅ [Manuscript] Created submission '\(name)' with \(submission.submittedFiles?.count ?? 0) files for publication '\(publication.name)'")
        #endif
    }
    
    /// Export the full manuscript as PDF
    private func exportManuscriptPDF() {
        isExporting = true
        let projectName = project.name ?? "Manuscript"
        
        Task {
            if let data = await generateManuscriptPDF() {
                await MainActor.run {
                    exportData = data
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
        
        return allSubmissions.filter { submission in
            !submission.isCollection && submission.project?.id == project.id
        }.count
    }
    
    // Get publication count for this folder type
    private var publicationCount: Int {
        guard isPublicationFolder, let project = folder.project else { return 0 }
        
        let folderName = folder.name ?? ""
        var publicationType: PublicationType?
        
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
        
        return allPublications.filter { pub in
            pub.project?.id == project.id && pub.type == publicationType
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
            if isAllFolder, let project = folder.project {
                // For "All" folder, compute total files from target folders
                let projectFolders = allFolders.filter { $0.project?.id == project.id }
                let targetFolderNames = ["Draft", "Ready", "Set Aside", "Published"]
                
                var totalCount = 0
                for folder in projectFolders where targetFolderNames.contains(folder.name ?? "") {
                    totalCount += folder.textFiles?.count ?? 0
                }
                fileCount = totalCount
                subfolderCount = 0
            } else if isTrashFolder, let project = folder.project {
                // For "Trash" folder, count TrashItem objects (not files in folder)
                fileCount = allTrashItems.filter { $0.project?.id == project.id }.count
                subfolderCount = 0
            } else {
                fileCount = folder.textFiles?.count ?? 0
                subfolderCount = folder.folders?.count ?? 0
            }
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
