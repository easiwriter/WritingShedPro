//
//  BackMatterGeneratedContentView.swift
//  Writing Shed Pro
//
//  Feature 029: Back Matter - Display auto-generated back matter content
//  This view shows compiled content for back matter files (Endnotes, Notes, Glossary, References, Index)
//

import SwiftUI
import SwiftData

/// View that displays auto-generated back matter content based on the file name
struct BackMatterGeneratedContentView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let file: TextFile
    let project: Project
    
    // MARK: - State
    
    @State private var entries: [Any] = []
    @State private var showDeletedAlert = false
    @State private var deletedItemName: String = ""
    @State private var previousEndnoteCount: Int = 0
    @State private var previousGlossaryCount: Int = 0
    @State private var previousReferencesCount: Int = 0
    @State private var previousIndexCount: Int = 0
    @State private var previousContributorsCount: Int = 0
    @State private var refreshTrigger = UUID()
    @State private var showAddContributorSheet = false
    @State private var contributorToEdit: ContributorEntry?
    @State private var editMode: EditMode = .inactive
    @State private var selectedContributorIDs: Set<UUID> = []
    @State private var contributorToDelete: ContributorEntry?
    @State private var showDeleteConfirmation = false
    @State private var contributorsToDelete: [ContributorEntry] = []
    
    // Index management state
    @State private var indexEntryToEdit: IndexEntry?
    @State private var indexEntryToDelete: IndexEntry?
    @State private var showIndexDeleteConfirmation = false
    @State private var indexPageMap: [UUID: [IndexPageReference]] = [:]
    @State private var isCalculatingPageNumbers = false
    @State private var pageCalcTrigger = UUID()
    @State private var indexEntryToFindOccurrences: IndexEntry?
    
    // Table of Figures state
    @State private var figureEntries: [FigureEntry] = []
    @State private var previousFiguresCount: Int = 0
    @State private var isCalculatingFigurePageNumbers = false
    @State private var figurePageCalcTrigger = UUID()
    @State private var showTableOfFiguresSettings = false
    
    // Section title editing state
    @State private var showTitleEditor = false
    
    // MARK: - Computed Properties
    
    /// Determine the back matter type based on file name
    private var backMatterType: BackMatterItem? {
        let fileName = file.name.lowercased()
        
        for item in BackMatterItem.allCases {
            if fileName.contains(item.rawValue.lowercased()) {
                return item
            }
        }
        return nil
    }
    
    /// Body-category text styles from the project's stylesheet, sorted by display order
    private var availableBodyStyles: [TextStyleModel] {
        guard let stylesheet = project.styleSheet,
              let textStyles = stylesheet.textStyles else {
            return []
        }
        return textStyles
            .filter { $0.styleCategory == .text }
            .sorted { $0.displayOrder < $1.displayOrder }
    }
    
    /// The resolved SwiftUI Font for contributor entries, based on the project's chosen body style
    private var contributorFont: Font {
        if let stylesheet = project.styleSheet,
           let style = stylesheet.style(named: project.contributorBodyStyleName) {
            return Font(style.generateFont())
        }
        return .body
    }
    
    /// The resolved SwiftUI Font for matter headings, based on the project's matter heading style
    private var matterHeadingFont: Font {
        if let stylesheet = StyleSheetService.getStyleSheet(for: project, context: modelContext),
           let style = stylesheet.style(named: project.matterHeadingStyleName) {
            return Font(style.generateFont())
        }
        return .title
    }
    
    // MARK: - Body
    
    var body: some View {
        contentWithNavigationChrome
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Refresh when app returns to foreground (handles changes from other views)
                refreshTrigger = UUID()
            }
            .task(id: pageCalcTrigger) {
                #if DEBUG
                print("📑 BackMatter .task fired: backMatterType=\(String(describing: backMatterType)), fileName='\(file.name)'")
                #endif
                if backMatterType == .index {
                    await calculateIndexPageNumbers()
                }
            }
            .task(id: figurePageCalcTrigger) {
                #if DEBUG
                print("📑 BackMatter .task (figures) fired: backMatterType=\(String(describing: backMatterType)), fileName='\(file.name)'")
                #endif
                if backMatterType == .tableOfFigures {
                    await loadAndCalculateFigureEntries()
                }
            }
            .onChange(of: refreshTrigger) { _, _ in
                // When data changes (edit/delete), recalculate page numbers or regenerate content
                if backMatterType == .index {
                    pageCalcTrigger = UUID()
                } else if backMatterType == .tableOfFigures {
                    figurePageCalcTrigger = UUID()
                } else if backMatterType == .contributors {
                    regenerateFileContent()
                }
            }
            .onAppear {
                #if DEBUG
                print("📑 BackMatter .onAppear: backMatterType=\(String(describing: backMatterType)), fileName='\(file.name)'")
                #endif
                // Regenerate contributors file content on appear so PDF preview is up to date
                if backMatterType == .contributors {
                    regenerateFileContent()
                }
            }
    }

    private var contentWithNavigationChrome: some View {
        bodyWithSheetsAndAlerts
            .id(refreshTrigger) // Refresh content only, not sheets
            .navigationTitle(file.name)
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, $editMode)
            .toolbar { toolbarContent }
    }
    
    // MARK: - Extracted Body Content
    
    @ViewBuilder
    private var bodyContent: some View {
        if backMatterType == .contributors {
            contributorsListContent
        } else {
            nonContributorBodyContent
        }
    }

    private var nonContributorBodyContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                nonContributorContentSwitch
            }
            .padding()
        }
    }

    @ViewBuilder
    private var nonContributorContentSwitch: some View {
        switch backMatterType {
        case .endnotes:
            endnotesContent
        case .glossary:
            glossaryContent
        case .references:
            referencesContent
        case .tableOfFigures:
            tableOfFiguresContent
        case .index:
            indexContent
        case .contributors:
            EmptyView()
        case .backCover:
            EmptyView()
        case nil:
            emptyContent
        }
    }
    
    // MARK: - Sheets and Alerts
    
    private var bodyWithSheetsAndAlerts: some View {
        bodyContent
            .sheet(isPresented: $showTableOfFiguresSettings) {
                TableOfFiguresSettingsView(file: file, isPresented: $showTableOfFiguresSettings) {
                    // Refresh content when settings change
                    figurePageCalcTrigger = UUID()
                }
            }
            .sheet(isPresented: $showTitleEditor) {
                if let type = backMatterType {
                    BackMatterTitleEditorSheet(
                        item: type,
                        folder: file.parentFolder,
                        isPresented: $showTitleEditor,
                        onSave: { regenerateFileContent() }
                    )
                }
            }
            .sheet(isPresented: $showAddContributorSheet) {
                ContributorEditorSheet(
                    project: project,
                    existingContributor: nil,
                    onSave: { refreshTrigger = UUID() },
                    onDismiss: { showAddContributorSheet = false }
                )
                .id("addContributor") // Stable identity prevents sheet flicker on desktop switch
            }
            .sheet(item: $contributorToEdit) { contributor in
                ContributorEditorSheet(
                    project: project,
                    existingContributor: contributor,
                    onSave: { refreshTrigger = UUID() },
                    onDismiss: { contributorToEdit = nil }
                )
                .id(contributor.id) // Stable identity prevents sheet flicker on desktop switch
            }
            // Index entry edit sheet
            .sheet(item: $indexEntryToEdit) { (entry: IndexEntry) in
                IndexEditorSheet(
                    project: project,
                    existingEntry: entry,
                    onSave: { _, _ in
                        refreshTrigger = UUID()
                    }
                )
            }
            // Index occurrence finder sheet
            .sheet(item: $indexEntryToFindOccurrences) { (entry: IndexEntry) in
                IndexOccurrenceFinderSheet(
                    entry: entry,
                    project: project,
                    onMarkersAdded: {
                        refreshTrigger = UUID()
                    }
                )
            }
            // Index entry delete confirmation
            .confirmationDialog(
                NSLocalizedString("indexList.confirmDelete.title", comment: "Delete Index Entry?"),
                isPresented: $showIndexDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("button.delete", comment: "Delete"), role: .destructive) {
                    if let entry = indexEntryToDelete {
                        deleteIndexEntry(entry)
                    }
                    showIndexDeleteConfirmation = false
                }
                Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                    indexEntryToDelete = nil
                    showIndexDeleteConfirmation = false
                }
            } message: {
                if let entry = indexEntryToDelete {
                    if entry.referenceCount > 0 {
                        Text(String(format: NSLocalizedString("indexList.confirmDelete.messageWithRefs", comment: ""), entry.referenceCount))
                    } else {
                        Text(NSLocalizedString("indexList.confirmDelete.message", comment: "This entry will be permanently deleted."))
                    }
                }
            }
            .alert(
                deleteAlertTitle,
                isPresented: $showDeleteConfirmation
            ) {
                Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                    contributorToDelete = nil
                    contributorsToDelete = []
                }
                Button(NSLocalizedString("button.delete", comment: "Delete"), role: .destructive) {
                    performDeleteContributors()
                }
            } message: {
                Text(deleteAlertMessage)
            }
    }
    
    // MARK: - Extracted Toolbar Content
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Section title edit button (not for covers or Table of Figures which has its own settings)
        if let type = backMatterType, type != .backCover && type != .tableOfFigures {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showTitleEditor = true
                } label: {
                    Image(systemName: "textformat")
                }
                .accessibilityLabel(NSLocalizedString("backMatter.titleEditor.button", comment: "Edit Section Title"))
            }
        }
        
        // Settings button for Table of Figures
        if backMatterType == .tableOfFigures {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showTableOfFiguresSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(NSLocalizedString("tof.settings.button.accessibility", comment: "Table of Figures Settings"))
            }
        }
        
        // Edit and Add buttons for contributors
        if backMatterType == .contributors {
            ToolbarItem(placement: .navigationBarTrailing) {
                contributorsToolbarContent
            }
        }
    }
    
    // MARK: - Toolbar Content
    
    @ViewBuilder
    private var contributorsToolbarContent: some View {
        HStack {
            // Body style picker — shows text-category styles from the project's stylesheet
            Menu {
                ForEach(availableBodyStyles, id: \.id) { style in
                    Button {
                        project.contributorBodyStyleName = style.name
                        project.modifiedDate = Date()
                        WriteCoalescer.shared?.requestSave(reason: "back-matter-contributor-body-style")
                        WriteCoalescer.shared?.flush()
                        refreshTrigger = UUID()
                    } label: {
                        HStack {
                            Text(style.displayName)
                            if project.contributorBodyStyleName == style.name {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "textformat.size")
            }
            .accessibilityLabel(NSLocalizedString("contributor.bodyStyle", comment: "Body Style"))
            
            // Run together / separate rows toggle
            Button {
                withAnimation {
                    project.contributorDisplayRunTogether.toggle()
                    project.modifiedDate = Date()
                    WriteCoalescer.shared?.requestSave(reason: "back-matter-contributor-display-mode")
                    WriteCoalescer.shared?.flush()
                    refreshTrigger = UUID()
                }
            } label: {
                Image(systemName: project.contributorDisplayRunTogether ? "list.bullet" : "text.justify.leading")
            }
            .accessibilityLabel(project.contributorDisplayRunTogether
                ? NSLocalizedString("contributor.showSeparateRows", comment: "Show as Separate Rows")
                : NSLocalizedString("contributor.showRunTogether", comment: "Show as Continuous Text"))
            
            // Display order toggle
            Button {
                withAnimation {
                    project.contributorDisplaySurnameFirst.toggle()
                    project.modifiedDate = Date()
                    WriteCoalescer.shared?.requestSave(reason: "back-matter-contributor-sort-display")
                    WriteCoalescer.shared?.flush()
                    refreshTrigger = UUID()
                }
            } label: {
                Image(systemName: project.contributorDisplaySurnameFirst ? "arrow.left.arrow.right" : "arrow.right.arrow.left")
            }
            .accessibilityLabel(project.contributorDisplaySurnameFirst
                ? NSLocalizedString("contributor.showForenameFirst", comment: "Show as Forename Surname")
                : NSLocalizedString("contributor.showSurnameFirst", comment: "Show as Surname, Forename"))
            
            // Edit/Done button
            if !(project.contributorEntries ?? []).isEmpty {
                Button {
                    withAnimation {
                        if editMode == .active {
                            editMode = .inactive
                            selectedContributorIDs.removeAll()
                        } else {
                            editMode = .active
                        }
                    }
                } label: {
                    Text(editMode == .active ? NSLocalizedString("button.done", comment: "Done") : NSLocalizedString("button.edit", comment: "Edit"))
                }
            }
            
            // Add button (only when not in edit mode)
            if editMode != .active {
                Button {
                    showAddContributorSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(NSLocalizedString("contributor.add.button", comment: "Add Contributor"))
            }
        }
    }
    
    // MARK: - Index Entry Actions
    
    private func deleteIndexEntry(_ entry: IndexEntry) {
        modelContext.delete(entry)
        project.modifiedDate = Date()
        WriteCoalescer.shared?.requestSave(reason: "back-matter-index-entry-delete")
        WriteCoalescer.shared?.flush()
        refreshTrigger = UUID()
        indexEntryToDelete = nil
    }
    
    // MARK: - Index Page Number Calculation
    
    /// Calculate page numbers for index entries using the same pagination engine as TOC
    @MainActor
    private func calculateIndexPageNumbers() async {
        guard !isCalculatingPageNumbers else { return }
        isCalculatingPageNumbers = true
        defer { isCalculatingPageNumbers = false }
        
        // Step 1: Gather all data on the main thread (SwiftData models aren't thread-safe)
        let assemblyService = ManuscriptAssemblyService(context: modelContext)
        let sections = assemblyService.getSections(for: project)
        let pageSetup = project.pageSetup ?? PageSetup()
        let usePageBreaks = pageSetup.hasPageBreakBetweenFiles
        
        // Assemble manuscript and collect file contents (all on main thread)
        let assembledContent = NSMutableAttributedString()
        var fileContents: [(fileID: UUID, offset: Int, content: NSAttributedString)] = []
        var isFirstFile = true
        let pageBreak = NSAttributedString(string: "\u{0C}")
        
        for section in sections {
            // Skip back matter files
            if section.sectionType == .backMatter {
                continue
            }
            
            for file in section.files {
                if !isFirstFile {
                    if usePageBreaks {
                        assembledContent.append(pageBreak)
                    } else {
                        assembledContent.append(NSAttributedString(string: "\n\n"))
                    }
                }
                
                let offset = assembledContent.length
                
                if let version = file.currentVersion, let content = version.attributedContent {
                    #if DEBUG
                    if isFirstFile && content.length > 0 {
                        let firstChar = (content.string as NSString).substring(with: NSRange(location: 0, length: min(1, content.length)))
                        let charCode = firstChar.unicodeScalars.first?.value ?? 0
                        print("📑 First file '\(file.name)' first char: '\\u{\(String(format: "%04X", charCode))}' (length: \(content.length))")
                    }
                    #endif
                    assembledContent.append(content)
                    fileContents.append((fileID: file.id, offset: offset, content: content))
                }
                isFirstFile = false
            }
        }
        
        guard assembledContent.length > 0 else {
            #if DEBUG
            print("📑 Index page calc: No assembled content")
            #endif
            return
        }
        
        #if DEBUG
        print("📑 Index page calc: Assembled \(assembledContent.length) chars from \(fileContents.count) files")
        #endif
        
        // Step 2: Paginate (this is the heavy work, but TextKit 1 requires main thread)
        let textStorage = NSTextStorage(attributedString: assembledContent)
        let layoutManager = PaginatedTextLayoutManager(textStorage: textStorage, pageSetup: pageSetup)
        let layoutResult = layoutManager.calculateLayout()
        
        #if DEBUG
        print("📑 Index page calc: Paginated into \(layoutResult.totalPages) pages")
        #endif
        
        // Step 3: Scan for index markers in each file's content
        var result: [UUID: [IndexPageReference]] = [:]
        
        #if DEBUG
        var totalAttachments = 0
        var indexAttachments = 0
        var otherAttachments = 0
        #endif
        
        for (fileID, offset, content) in fileContents {
            #if DEBUG
            var fileAttachmentCount = 0
            #endif
            content.enumerateAttribute(.attachment, in: NSRange(location: 0, length: content.length)) { value, range, _ in
                if let refAttachment = value as? ReferenceAttachment {
                    #if DEBUG
                    totalAttachments += 1
                    fileAttachmentCount += 1
                    #endif
                    guard refAttachment.referenceType == .index else {
                        #if DEBUG
                        otherAttachments += 1
                        #endif
                        return
                    }
                    #if DEBUG
                    indexAttachments += 1
                    #endif
                    
                    let globalPosition = offset + range.location
                    
                    // Find which page this position falls on
                    var pageNumber = 1
                    for pageInfo in layoutResult.pageInfos {
                        if globalPosition >= pageInfo.characterRange.location &&
                           globalPosition < pageInfo.characterRange.location + pageInfo.characterRange.length {
                            pageNumber = pageInfo.pageIndex + 1
                            break
                        }
                    }
                    // If past the last page range, use last page
                    if let lastPage = layoutResult.pageInfos.last,
                       globalPosition >= lastPage.characterRange.location + lastPage.characterRange.length {
                        pageNumber = lastPage.pageIndex + 1
                    }
                    
                    let ref = IndexPageReference(
                        pageNumber: pageNumber,
                        isPrimary: refAttachment.isPrimaryReference
                    )
                    
                    if result[refAttachment.entryID] == nil {
                        result[refAttachment.entryID] = []
                    }
                    // Avoid duplicate page numbers
                    if !result[refAttachment.entryID]!.contains(ref) {
                        result[refAttachment.entryID]!.append(ref)
                    }
                }
            }
            #if DEBUG
            if fileAttachmentCount > 0 {
                print("📑 File \(fileID.uuidString.prefix(8)): \(fileAttachmentCount) reference attachments found")
            }
            #endif
        }
        
        #if DEBUG
        print("📑 Attachment scan: \(totalAttachments) total, \(indexAttachments) index, \(otherAttachments) other types")
        #endif
        
        #if DEBUG
        print("📑 Index page map calculated: \(result.count) entries with page numbers")
        for (id, pages) in result {
            print("   \(id.uuidString.prefix(8)): pages \(pages.map { "\($0.pageNumber)\($0.isPrimary ? "*" : "")" })")
        }
        if result.isEmpty {
            print("📑 ⚠️ No index markers found in any files! Check that markers are persisted correctly.")
        }
        #endif
        
        indexPageMap = result
    }
    
    // MARK: - Table of Figures Page Number Calculation
    
    /// Load figure entries and calculate their page numbers
    @MainActor
    private func loadAndCalculateFigureEntries() async {
        guard !isCalculatingFigurePageNumbers else { return }
        isCalculatingFigurePageNumbers = true
        defer { isCalculatingFigurePageNumbers = false }
        
        #if DEBUG
        print("📷 Starting figure entries calculation...")
        #endif
        
        // Use the TableOfFiguresGenerationService
        let service = TableOfFiguresGenerationService(context: modelContext)
        
        // Generate entries (scans manuscript for images)
        var entries = service.generateEntries(for: project, tofFile: file)
        
        #if DEBUG
        print("📷 Found \(entries.count) figures in manuscript")
        #endif
        
        // Calculate page numbers
        if !entries.isEmpty {
            entries = await service.calculatePageNumbers(for: entries, project: project, tofFile: file)
        }
        
        // Update state
        figureEntries = entries
        previousFiguresCount = entries.count
        
        #if DEBUG
        print("📷 Figure calculation complete: \(entries.count) entries")
        for entry in entries {
            print("   Figure \(entry.figureNumber): '\(entry.captionText ?? "no caption")' -> page \(entry.pageNumber)")
        }
        #endif
    }
    
    /// Format page references for display, collapsing consecutive pages into ranges
    /// Primary references are shown in bold
    private func formatIndexPageNumbers(_ pages: [IndexPageReference]) -> String {
        let sorted = pages.sorted { $0.pageNumber < $1.pageNumber }
        var result: [String] = []
        var i = 0
        
        while i < sorted.count {
            let start = sorted[i].pageNumber
            var end = start
            
            // Find consecutive range
            while i + 1 < sorted.count && sorted[i + 1].pageNumber == end + 1 {
                i += 1
                end = sorted[i].pageNumber
            }
            
            if start == end {
                result.append("\(start)")
            } else {
                result.append("\(start)–\(end)")
            }
            i += 1
        }
        
        return result.joined(separator: ", ")
    }
    
    // MARK: - Delete Alert Helpers
    
    private var deleteAlertTitle: String {
        if contributorsToDelete.count > 1 {
            return String(format: NSLocalizedString("contributor.deleteMultiple.title", comment: "Delete Contributors"), contributorsToDelete.count)
        } else {
            return NSLocalizedString("contributor.delete.title", comment: "Delete Contributor")
        }
    }
    
    private var deleteAlertMessage: String {
        if contributorsToDelete.count > 1 {
            return String(format: NSLocalizedString("contributor.deleteMultiple.message", comment: "Are you sure?"), contributorsToDelete.count)
        } else if let contributor = contributorToDelete {
            return String(format: NSLocalizedString("contributor.delete.message", comment: "Are you sure you want to delete %@?"), contributor.displayName)
        } else if let first = contributorsToDelete.first {
            return String(format: NSLocalizedString("contributor.delete.message", comment: "Are you sure you want to delete %@?"), first.displayName)
        }
        return ""
    }
    
    /// Actually perform the deletion after confirmation
    private func performDeleteContributors() {
        withAnimation {
            // Handle batch delete
            if !contributorsToDelete.isEmpty {
                for contributor in contributorsToDelete {
                    modelContext.delete(contributor)
                }
                contributorsToDelete = []
                selectedContributorIDs.removeAll()
                editMode = .inactive
            }
            // Handle single delete
            else if let contributor = contributorToDelete {
                modelContext.delete(contributor)
                contributorToDelete = nil
            }
            refreshTrigger = UUID()
        }
    }
    
    // MARK: - Endnotes Content
    
    @ViewBuilder
    private var endnotesContent: some View {
        let endnotes = (project.noteEntries ?? [])
            .filter { $0.isEndnote }
            .sorted { $0.displayNumber < $1.displayNumber }
        
        if endnotes.isEmpty {
            // Check if we just deleted all endnotes (transition from non-empty to empty)
            if previousEndnoteCount > 0 {
                // Trigger alert
                VStack {}
                    .onAppear {
                        showDeletedAlert = true
                        deletedItemName = NSLocalizedString("backMatter.endnotes", comment: "Endnotes")
                    }
            } else {
                // First time viewing - show empty state
                emptyStateView(
                    title: NSLocalizedString("backMatter.endnotes.empty.title", comment: "No Endnotes"),
                    description: NSLocalizedString("backMatter.endnotes.empty.description", comment: "Endnotes added to your manuscript will appear here."),
                    systemImage: "number.circle"
                )
            }
        } else {
            sectionTitleHeader(for: .endnotes)
            
            ForEach(endnotes) { note in
                endnoteRow(note)
            }
            .onAppear {
                previousEndnoteCount = endnotes.count
            }
            .onChange(of: endnotes.count) { _, newCount in
                previousEndnoteCount = newCount
            }
        }
    }
    
    private func endnoteRow(_ note: NoteEntry) -> some View {
        HStack(alignment: .top, spacing: 4) {
            // Show tag if available, otherwise show number
            if let tag = note.tag, !tag.isEmpty {
                Text("\(tag): ")
                    .font(.body)
                    .fontWeight(.bold)
            } else {
                Text("\(note.displayNumber): ")
                    .font(.body)
                    .fontWeight(.bold)
            }
            
            Text(note.content)
                .font(.body)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Notes Content
    
    @ViewBuilder
    private var notesContent: some View {
        let notes = (project.noteEntries ?? [])
            .filter { !$0.isEndnote }
            .sorted { $0.displayNumber < $1.displayNumber }
        
        if notes.isEmpty {
            emptyStateView(
                title: NSLocalizedString("backMatter.notes.empty.title", comment: "No Notes"),
                description: NSLocalizedString("backMatter.notes.empty.description", comment: "Notes added to your manuscript will appear here."),
                systemImage: "note.text"
            )
        } else {
            sectionTitleHeader(for: .endnotes)
            
            ForEach(notes) { note in
                noteRow(note)
            }
        }
    }
    
    private func noteRow(_ note: NoteEntry) -> some View {
        HStack(alignment: .top, spacing: 4) {
            // Show tag if available, otherwise show number
            if let tag = note.tag, !tag.isEmpty {
                Text("\(tag): ")
                    .font(.body)
                    .fontWeight(.bold)
            } else {
                Text("Note \(note.displayNumber): ")
                    .font(.body)
                    .fontWeight(.bold)
            }
            
            Text(note.content)
                .font(.body)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Glossary Content
    
    @ViewBuilder
    private var glossaryContent: some View {
        let terms = (project.glossaryEntries ?? [])
            .sorted { $0.term.lowercased() < $1.term.lowercased() }
        
        if terms.isEmpty {
            emptyStateView(
                title: NSLocalizedString("backMatter.glossary.empty.title", comment: "No Glossary Terms"),
                description: NSLocalizedString("backMatter.glossary.empty.description", comment: "Glossary terms added to your manuscript will appear here."),
                systemImage: "text.book.closed"
            )
        } else {
            sectionTitleHeader(for: .glossary)
            
            ForEach(terms) { term in
                glossaryRow(term)
            }
        }
    }
    
    private func glossaryRow(_ term: GlossaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(term.term)
                .font(.headline)
            Text(term.definition)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - References Content
    
    @ViewBuilder
    private var referencesContent: some View {
        let references = (project.referenceEntries ?? [])
            .sorted { $0.author.lowercased() < $1.author.lowercased() }
        
        if references.isEmpty {
            emptyStateView(
                title: NSLocalizedString("backMatter.references.empty.title", comment: "No References"),
                description: NSLocalizedString("backMatter.references.empty.description", comment: "References added to your manuscript will appear here."),
                systemImage: "books.vertical"
            )
        } else {
            sectionTitleHeader(for: .references)
            
            ForEach(references) { reference in
                referenceRow(reference)
            }
        }
    }
    
    private func referenceRow(_ reference: ReferenceEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formatReference(reference))
                .font(.body)
        }
        .padding(.vertical, 4)
    }
    
    /// Format a reference entry for display
    private func formatReference(_ reference: ReferenceEntry) -> String {
        var parts: [String] = []
        
        // Author
        if !reference.author.isEmpty {
            parts.append(reference.author)
        }
        
        // Publication Date
        if !reference.publicationDate.isEmpty {
            parts.append("(\(reference.publicationDate))")
        }
        
        // Details (journal, publisher, URL, etc.)
        if !reference.details.isEmpty {
            parts.append(reference.details)
        }
        
        return parts.joined(separator: ". ") + "."
    }
    
    // MARK: - Table of Figures Content
    
    /// Entries to show in the Table of Figures (filtered based on settings)
    private var figuresToShow: [FigureEntry] {
        let settings = file.tableOfFiguresSettings
        if settings.showMissingCaption {
            return figureEntries
        } else {
            return figureEntries.filter { $0.hasCaption }
        }
    }
    
    @ViewBuilder
    private var tableOfFiguresContent: some View {
        if figureEntries.isEmpty {
            emptyStateView(
                title: NSLocalizedString("backMatter.tableOfFigures.empty.title", comment: "No Images"),
                description: NSLocalizedString("backMatter.tableOfFigures.empty.description", comment: "Images in your manuscript will appear here."),
                systemImage: "photo.stack"
            )
        } else {
            VStack(alignment: .leading, spacing: 12) {
                // Header with page calculation status
                HStack {
                    Text(file.tableOfFiguresSettings.title)
                        .font(matterHeadingFont)
                    
                    if isCalculatingFigurePageNumbers {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                
                // Display entries
                ForEach(figuresToShow) { entry in
                    figureEntryRow(entry, settings: file.tableOfFiguresSettings)
                }
                
            }
        }
    }
    
    /// Renders a single figure entry row
    private func figureEntryRow(_ entry: FigureEntry, settings: TableOfFiguresSettings) -> some View {
        HStack(spacing: 0) {
            // Build entry text
            if let prefix = settings.captionPrefix {
                Text("\(prefix) \(entry.figureNumber): ")
                    .fontWeight(.medium)
            }
            
            if let caption = entry.captionText, !caption.isEmpty {
                Text(caption)
                    .layoutPriority(1)
            } else {
                Text(NSLocalizedString("tof.missingCaption", comment: "Missing caption"))
                    .italic()
                    .foregroundStyle(.secondary)
                    .layoutPriority(1)
            }
            
            // Dot leaders and page number
            if settings.showPageNumbers {
                Text(" " + String(repeating: ". ", count: 80))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(-1)
                Text(" \(entry.pageNumber)")
                    .foregroundStyle(.secondary)
                    .layoutPriority(1)
            }
        }
        .font(.body)
        .padding(.vertical, 2)
    }
    
    // MARK: - Index Content
    
    @ViewBuilder
    private var indexContent: some View {
        let allEntries = (project.indexEntries ?? [])
        // Only show top-level entries; children are displayed nested under their parent
        let topLevelEntries = allEntries
            .filter { $0.isTopLevel }
            .sorted { $0.keyword.lowercased() < $1.keyword.lowercased() }
        
        if allEntries.isEmpty {
            emptyStateView(
                title: NSLocalizedString("backMatter.index.empty.title", comment: "No Index Entries"),
                description: NSLocalizedString("backMatter.index.empty.description", comment: "Index entries added to your manuscript will appear here."),
                systemImage: "list.bullet.indent"
            )
        } else {
            HStack {
                sectionTitleHeader(for: .index)
                
                if isCalculatingPageNumbers {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            
            // Group top-level entries by first letter
            let grouped = Dictionary(grouping: topLevelEntries) { entry -> String in
                let firstChar = entry.keyword.first?.uppercased() ?? "#"
                return firstChar.first?.isLetter == true ? firstChar : "#"
            }
            
            ForEach(grouped.keys.sorted(), id: \.self) { letter in
                indexSection(letter: letter, entries: grouped[letter] ?? [], allEntries: allEntries)
            }
        }
    }
    
    private func indexSection(letter: String, entries: [IndexEntry], allEntries: [IndexEntry]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(letter)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.accentColor)
            
            ForEach(entries) { entry in
                indexEntryView(entry, allEntries: allEntries, indentLevel: 0)
            }
        }
        .padding(.vertical, 8)
    }
    
    /// Renders a single index entry with its cross-references and children
    private func indexEntryView(_ entry: IndexEntry, allEntries: [IndexEntry], indentLevel: Int) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 2) {
                // Main entry row with keyword + actions
                HStack {
                    HStack(spacing: 4) {
                        if indentLevel > 0 {
                            Text(String(repeating: "    ", count: indentLevel))
                                .fixedSize()
                        }
                        
                        Text(entry.keyword)
                            .font(indentLevel == 0 ? .body : .callout)
                            .fontWeight(indentLevel == 0 ? .regular : .regular)
                            .foregroundStyle(indentLevel == 0 ? .primary : .secondary)
                    }
                    
                    // Show "see" cross-reference inline
                    if let seeEntryID = entry.seeEntryID,
                       let seeEntry = allEntries.first(where: { $0.id == seeEntryID }) {
                        Text(NSLocalizedString("indexList.see", comment: "see"))
                            .italic()
                            .font(.callout)
                            .foregroundStyle(.purple)
                        Text(seeEntry.keyword)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(.purple)
                    }
                    
                    // Show page numbers if calculated, otherwise show reference count
                    if let pages = indexPageMap[entry.id], !pages.isEmpty {
                        Text(formatIndexPageNumbers(pages))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else if entry.referenceCount > 0 {
                        Label("\(entry.referenceCount)", systemImage: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Actions menu
                    Menu {
                        Button {
                            indexEntryToEdit = entry
                        } label: {
                            Label(NSLocalizedString("indexList.edit", comment: "Edit"), systemImage: "pencil.circle")
                        }
                        
                        Button {
                            indexEntryToFindOccurrences = entry
                        } label: {
                            Label(NSLocalizedString("indexList.findOccurrences", comment: "Find Occurrences"), systemImage: "doc.text.magnifyingglass")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            indexEntryToDelete = entry
                            showIndexDeleteConfirmation = true
                        } label: {
                            Label(NSLocalizedString("indexList.delete", comment: "Delete"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .imageScale(.large)
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.vertical, 2)
                
                // Show "see also" cross-references
                if !entry.seeAlsoEntryIDs.isEmpty {
                    let seeAlsoKeywords = entry.seeAlsoEntryIDs.compactMap { id in
                        allEntries.first(where: { $0.id == id })?.keyword
                    }
                    if !seeAlsoKeywords.isEmpty {
                        HStack(spacing: 4) {
                            if indentLevel > 0 {
                                Text(String(repeating: "    ", count: indentLevel))
                                    .fixedSize()
                            }
                            Text("    ")
                            Text(NSLocalizedString("indexList.seeAlso", comment: "See also"))
                                .italic()
                            Text(seeAlsoKeywords.joined(separator: ", "))
                        }
                        .font(.caption)
                        .foregroundStyle(.purple)
                        .padding(.leading, indentLevel > 0 ? 4 : 0)
                    }
                }
                
                // Show child entries (sub-entries) indented
                let children = (entry.childEntries ?? [])
                    .sorted { $0.keyword.lowercased() < $1.keyword.lowercased() }
                if !children.isEmpty {
                    ForEach(children) { child in
                        indexEntryView(child, allEntries: allEntries, indentLevel: indentLevel + 1)
                    }
                }
            }
        )
    }
    
    // MARK: - Contributors Content
    
    /// List-based view for contributors with swipe-to-delete and edit mode support
    @ViewBuilder
    private var contributorsListContent: some View {
        let contributors = (project.contributorEntries ?? []).sorted()
        
        if contributors.isEmpty {
            // Check if we just deleted all contributors
            if previousContributorsCount > 0 {
                VStack {}
                    .onAppear {
                        showDeletedAlert = true
                        deletedItemName = NSLocalizedString("backMatter.contributors", comment: "Contributors")
                    }
            } else {
                emptyStateView(
                    title: NSLocalizedString("backMatter.contributors.empty.title", comment: "No Contributors"),
                    description: NSLocalizedString("backMatter.contributors.empty.description", comment: "Tap + to add contributors to your publication."),
                    systemImage: "person.2"
                )
            }
        } else if project.contributorDisplayRunTogether {
            // Run-together mode: continuous paragraph
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    contributorsRunTogetherView(contributors)
                }
                .padding()
            }
            .onAppear {
                previousContributorsCount = contributors.count
            }
        } else {
            List(selection: $selectedContributorIDs) {
                ForEach(contributors) { contributor in
                    contributorRow(contributor)
                        .tag(contributor.id)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, $editMode)
            .onAppear {
                previousContributorsCount = contributors.count
            }
            // Bottom toolbar when in edit mode with selections
            .safeAreaInset(edge: .bottom) {
                if editMode == .active && !selectedContributorIDs.isEmpty {
                    HStack {
                        Spacer()
                        
                        // Trash button
                        Button(role: .destructive) {
                            let selected = contributors.filter { selectedContributorIDs.contains($0.id) }
                            contributorsToDelete = selected
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel(String(format: NSLocalizedString("contributor.deleteCount", comment: "Delete count"), selectedContributorIDs.count))
                    }
                    .padding()
                    .background(.regularMaterial)
                }
            }
        }
    }
    
    private func contributorRow(_ contributor: ContributorEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Name — respects project display order preference
            Text(contributor.displayName(surnameFirst: project.contributorDisplaySurnameFirst))
                .font(contributorFont)
                .bold()
            
            // Biography
            if !contributor.biography.isEmpty {
                Text(contributor.biography)
                    .font(contributorFont)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            contributorToEdit = contributor
        }
        .contextMenu {
            Button {
                contributorToEdit = contributor
            } label: {
                Label(NSLocalizedString("button.edit", comment: "Edit"), systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                contributorToDelete = contributor
                showDeleteConfirmation = true
            } label: {
                Label(NSLocalizedString("button.delete", comment: "Delete"), systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                contributorToDelete = contributor
                showDeleteConfirmation = true
            } label: {
                Label(NSLocalizedString("button.delete", comment: "Delete"), systemImage: "trash")
            }
        }
    }
    
    /// Run-together view: displays all contributors as a continuous flowing paragraph.
    /// Each entry is: **Name** biography text. Entries separated by a bullet.
    @ViewBuilder
    private func contributorsRunTogetherView(_ contributors: [ContributorEntry]) -> some View {
        // Build a single attributed paragraph with all contributors
        let parts: [Text] = contributors.enumerated().map { index, contributor in
            let name = contributor.displayName(surnameFirst: project.contributorDisplaySurnameFirst)
            let nameText = Text(name).bold()
            let separator = index < contributors.count - 1 ? " \u{2022} " : ""
            
            if !contributor.biography.isEmpty {
                return nameText + Text(" " + contributor.biography + separator)
            } else {
                return nameText + Text(separator)
            }
        }
        
        // Combine all parts into a single Text
        let combined = parts.reduce(Text("")) { $0 + $1 }
        
        combined
            .font(contributorFont)
            .contextMenu {
                Button {
                    editMode = .inactive
                } label: {
                    Label(NSLocalizedString("contributor.tapToEdit", comment: "Switch to list view to edit"), systemImage: "list.bullet")
                }
            }
    }
    
    // MARK: - Empty Content
    
    @ViewBuilder
    private var emptyContent: some View {
        ContentUnavailableView {
            Label(
                NSLocalizedString("backMatter.unknown.title", comment: "Unknown Content Type"),
                systemImage: "questionmark.circle"
            )
        } description: {
            Text(NSLocalizedString("backMatter.unknown.description", comment: "This file doesn't match a known back matter type."))
        }
    }
    
    // MARK: - Section Title Header
    
    /// Configurable section title header with heading style from settings.
    /// Tap to edit the title text and heading style.
    @ViewBuilder
    private func sectionTitleHeader(for item: BackMatterItem) -> some View {
        let settings = file.parentFolder?.backMatterSettings ?? BackMatterSettings()
        let title = settings.displayTitle(for: item)
        
        Text(title)
            .font(settings.itemTitles[item.rawValue].map { matterHeadingFont(for: $0.headingStyle) } ?? matterHeadingFont)
            .padding(.bottom, matterHeadingSpacingAfter)
    }

    private func matterHeadingFont(for headingStyle: BackMatterHeadingStyle) -> Font {
        if let stylesheet = StyleSheetService.getStyleSheet(for: project, context: modelContext),
           let style = stylesheet.style(named: headingStyle.textStyle.rawValue) {
            return Font(style.generateFont())
        }
        return Font(UIFont.preferredFont(forTextStyle: headingStyle.textStyle))
    }
    
    /// The resolved spacing after the matter heading style (e.g. 18pt for Large Title)
    private var matterHeadingSpacingAfter: CGFloat {
        if let stylesheet = StyleSheetService.getStyleSheet(for: project, context: modelContext),
           let style = stylesheet.style(named: project.matterHeadingStyleName) {
            return max(style.paragraphSpacingAfter, 12)
        }
        return 12
    }
    
    // MARK: - File Content Regeneration
    
    /// Regenerate the stored file content after title or heading style changes.
    /// This ensures the TOC scanner can find the heading with the correct .textStyle attribute.
    private func regenerateFileContent() {
        guard let type = backMatterType else { return }
        
        let generator = BackMatterGenerator(
            context: modelContext,
            project: project,
            sourceFolder: file.parentFolder
        )
        
        let generatedContent: NSAttributedString?
        switch type {
        case .endnotes:
            generatedContent = generator.generateNotesSection()
        case .glossary:
            generatedContent = generator.generateGlossarySection()
        case .references:
            generatedContent = generator.generateReferencesSection()
        case .index:
            generatedContent = generator.generateIndexSection(pageMap: indexPageMap)
        case .contributors:
            generatedContent = generator.generateContributorsSection()
        case .tableOfFigures, .backCover:
            return
        }
        
        guard let content = generatedContent else { return }
        
        if file.currentVersion == nil {
            let newVersion = Version(versionNumber: 1)
            newVersion.textFile = file
            newVersion.attributedContent = content
            modelContext.insert(newVersion)
            file.currentVersionIndex = 0
        } else {
            file.currentVersion?.attributedContent = content
        }
        
        file.modifiedDate = Date()
        WriteCoalescer.shared?.requestSave(reason: "back-matter-store-generated-content")
        WriteCoalescer.shared?.flush()
    }
    
    // MARK: - Helper Views
    
    private func emptyStateView(title: String, description: String, systemImage: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Helper Extension

extension BackMatterGeneratedContentView {
    /// Check if a file is a generated back matter file
    static func isGeneratedBackMatterFile(_ file: TextFile) -> Bool {
        guard let folder = file.parentFolder,
              folder.isBackMatterFolder else {
            return false
        }
        
        // Cover files are handled by CoverImageEditorView, not generated content
        if file.isCoverFile { return false }
        
        let fileName = file.name.lowercased()
        
        // Check if file name matches any back matter item
        for item in BackMatterItem.allCases {
            if fileName.contains(item.rawValue.lowercased()) {
                return true
            }
        }
        return false
    }
}
