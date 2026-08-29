//
//  DramaSceneEditorView.swift
//  Writing Shed Pro
//
//  Feature 023: Smart Drama Creation
//  Editor view for drama scene content with source/formatted toggle
//

import SwiftUI
import SwiftData
import ToolbarSUI

/// Editor view for drama scene content with DML support
/// Provides Source, Formatted, and Print Preview modes
struct DramaSceneEditorView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ContentViewState.self) private var contentViewState
    
    // MARK: - Properties
    
    @Bindable var file: TextFile
    let project: Project
    let initialCharacterPosition: Int?
    let initialHeadingText: String?

    #if DEBUG
    private func logVersionDiagnostics(_ context: String) {
        let rawVersions = file.versions ?? []
        let sortedVersions = rawVersions.sorted { $0.versionNumber < $1.versionNumber }
        let rawLabels = rawVersions.map { "v\($0.versionNumber):\($0.id.uuidString.prefix(8))" }
        let sortedLabels = sortedVersions.map { "v\($0.versionNumber):\($0.id.uuidString.prefix(8))" }
        let current = file.currentVersion
        let sortedIndex = sortedVersions.firstIndex(where: { $0.id == current?.id })
        print("🧪 [DramaVersionDelete] \(context)")
        print("   file: \(file.name)")
        print("   file.currentVersionIndex: \(file.currentVersionIndex)")
        print("   raw count: \(rawVersions.count) raw: \(rawLabels)")
        print("   sorted count: \(sortedVersions.count) sorted: \(sortedLabels)")
        print("   current version: \(current?.versionNumber ?? -1) id: \(current?.id.uuidString.prefix(8) ?? "nil")")
        print("   current sorted index: \(sortedIndex.map(String.init) ?? "nil")")
    }
    #endif
    
    // MARK: - State
    
    /// The current view mode
    @State private var viewMode: DramaViewMode = .source
    
    /// The script type (Film or Stage)
    @State private var scriptType: DramaScriptType
    
    /// The raw DML source text
    @State private var sourceText: String = ""
    
    /// The rendered attributed string (for formatted mode)
    @State private var renderedContent: NSAttributedString = NSAttributedString()

    /// Paginated rendered content for print preview
    @State private var printPreviewPages: [NSAttributedString] = []
    
    /// Parsed document (for analysis)
    @State private var parsedDocument: DMLDocument?
    
    /// Validation errors
    @State private var validationErrors: [DMLValidationError] = []
    
    /// Show validation errors sheet
    @State private var showValidationErrors = false
    
    /// Show character list from parsed document
    @State private var showCharacterList = false
    
    /// Show script type picker
    @State private var showScriptTypePicker = false
    
    /// Debounce timer for re-parsing
    @State private var parseDebounceTimer: Timer?

    /// Debounce timer for persisting source edits
    @State private var saveDebounceTimer: Timer?
    
    /// Show version delete confirmation
    @State private var showDeleteVersionAlert = false
    
    /// Current selection/cursor position in the text editor
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    
    /// The actual undo manager from the UITextView
    @State private var textViewUndoManager: UndoManager?
    
    /// Reference to the UITextView for search
    @State private var textView: UITextView?
    
    /// Search manager for find/replace
    @State private var searchManager = InEditorSearchManager()
    
    /// Whether the search bar is visible
    @State private var showSearchBar = false
    
    /// Print error message
    @State private var printErrorMessage: String?
    
    /// Upgrade prompt reason
    @State private var upgradePromptReason: UpgradePromptReason?
    
    /// Show print error alert
    @State private var showPrintError = false
    
    /// Show project characters list
    @State private var showProjectCharacters = false
    
    /// Show project locations list
    @State private var showProjectLocations = false
    
    /// Show project plot outline
    @State private var showProjectPlot = false

    /// Selected source for raw drama analysis
    @State private var rawDramaAnalysisRequest: RawDramaAnalysisRequest?
    
    /// Selected plot element to show in detail sheet
    @State private var selectedPlotElement: PlotElement?
    
    /// Selected character to show in quick view
    @State private var selectedCharacter: Character?
    
    /// Selected location to show in quick view
    @State private var selectedLocation: Location?
    
    // MARK: - Initialization
    
    init(file: TextFile, project: Project, initialCharacterPosition: Int? = nil, initialHeadingText: String? = nil) {
        self.file = file
        self.project = project
        self.initialCharacterPosition = initialCharacterPosition
        self.initialHeadingText = initialHeadingText
        
        // Default to project's script type or film
        _scriptType = State(initialValue: project.dramaScriptType ?? .film)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Version toolbar
            versionToolbar
            
            // Toolbar with view mode toggle
            editorToolbar
            
            Divider()
            
            // Editor content based on mode
            editorContent
        }
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(initialCharacterPosition != nil)
        .toolbar {
            navigationToolbarContent
        }
        .onAppear {
            loadContent()
            scrollToInitialCharacterPosition()
        }
        .onChange(of: sourceText) { _, newValue in
            debounceParse(newValue)
            debounceSave(newValue)
        }
        .onDisappear {
            commitPendingSourceSave()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            commitPendingSourceSave()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            commitPendingSourceSave()
        }
        .onChange(of: scriptType) { _, _ in
            renderContent()
            // Save script type preference to project
            project.dramaScriptType = scriptType
            project.modifiedDate = Date()
            WriteCoalescer.shared?.requestSave(reason: "drama-scene-script-type")
            WriteCoalescer.shared?.flush()
        }
        .onChange(of: viewMode) { _, _ in
            renderContent()
        }
        .sheet(isPresented: $showValidationErrors) {
            validationErrorsSheet
        }
        .sheet(isPresented: $showCharacterList) {
            characterListSheet
        }
        .sheet(isPresented: $showProjectCharacters) {
            NavigationStack {
                CharacterListView(project: project)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(NSLocalizedString("button.done", comment: "Done")) {
                                showProjectCharacters = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showProjectLocations) {
            NavigationStack {
                LocationListView(project: project)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(NSLocalizedString("button.done", comment: "Done")) {
                                showProjectLocations = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showProjectPlot) {
            NavigationStack {
                PlotOutlineView(project: project)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(NSLocalizedString("button.done", comment: "Done")) {
                                showProjectPlot = false
                            }
                        }
                    }
            }
        }
        .sheet(item: $selectedPlotElement) { plotElement in
            PlotElementQuickView(plotElement: plotElement)
        }
        .sheet(item: $selectedCharacter) { character in
            CharacterQuickView(character: character)
        }
        .sheet(item: $selectedLocation) { location in
            LocationQuickView(location: location)
        }
        .sheet(item: $rawDramaAnalysisRequest) { request in
            RawDramaAnalystActionSheet(project: project, content: request.content, fileName: request.fileName)
        }
        .alert(
            NSLocalizedString("fileEdit.deleteVersionTitle", comment: "Delete Version?"),
            isPresented: $showDeleteVersionAlert
        ) {
            Button(NSLocalizedString("contentView.delete", comment: "Delete"), role: .destructive) {
                #if DEBUG
                logVersionDiagnostics("before file.deleteVersion()")
                #endif
                file.deleteVersion()
                #if DEBUG
                logVersionDiagnostics("after file.deleteVersion() before loadContent()")
                #endif
                loadContent()
                #if DEBUG
                logVersionDiagnostics("after loadContent()")
                #endif
            }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("fileEdit.deleteVersionMessage", comment: "Please confirm"))
        }
        .alert(
            NSLocalizedString("print.error.title", comment: "Print Error"),
            isPresented: $showPrintError
        ) {
            Button(NSLocalizedString("button.ok", comment: "OK"), role: .cancel) { }
        } message: {
            Text(printErrorMessage ?? NSLocalizedString("print.error.unknown", comment: "Unknown error"))
        }
        .upgradePrompt(reason: $upgradePromptReason)
    }
    
    // MARK: - Navigation Toolbar Content
    
    @ToolbarContentBuilder
    private var navigationToolbarContent: some ToolbarContent {
        if initialCharacterPosition != nil {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    commitPendingSourceSave()
                    contentViewState.showProjectContent(project)
                } label: {
                    Label(
                        NSLocalizedString("navigation.back", comment: "Back"),
                        systemImage: "chevron.left"
                    )
                }
            }
        }

        // Search button (only in source mode)
        if viewMode == .source {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSearchBar.toggle()
                        if showSearchBar, let tv = textView {
                            searchManager.connect(to: tv)
                        } else if !showSearchBar {
                            searchManager.disconnect()
                        }
                    }
                } label: {
                    Image(systemName: showSearchBar ? "magnifyingglass.circle.fill" : "magnifyingglass")
                }
                .accessibilityLabel(NSLocalizedString("fileEdit.findReplace.accessibility", comment: "Find and Replace"))
            }
        }
        
        // Character/Location insert menu (only in source mode)
        if viewMode == .source {
            ToolbarItem(placement: .topBarTrailing) {
                characterLocationInsertMenu
            }
        }
        
        // Undo/Redo buttons (only in source mode)
        if viewMode == .source {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    textViewUndoManager?.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!(textViewUndoManager?.canUndo ?? false))
                .accessibilityLabel(NSLocalizedString("fileEdit.undo.accessibility", comment: "Undo"))
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    textViewUndoManager?.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!(textViewUndoManager?.canRedo ?? false))
                .accessibilityLabel(NSLocalizedString("fileEdit.redo.accessibility", comment: "Redo"))
            }
        }
    }
    
    // MARK: - Version Toolbar
    
    private var versionToolbar: some View {
        let versionItems: [SUIToolbarItem] = [
            SUIToolbarItem(
                icon: "chevron.left.circle",
                title: NSLocalizedString("version.previous", comment: "Previous version"),
                disabled: file.atFirstVersion()
            ),
            SUIToolbarItem(
                icon: "chevron.right.circle",
                title: NSLocalizedString("version.next", comment: "Next version"),
                disabled: file.atLastVersion()
            ),
            SUIToolbarItem(
                icon: "plus.circle",
                title: NSLocalizedString("version.duplicate", comment: "Duplicate version"),
                disabled: false
            ),
            SUIToolbarItem(
                icon: "trash.circle",
                title: NSLocalizedString("version.delete", comment: "Delete version"),
                disabled: (file.versions?.count ?? 0) <= 1
            )
        ]
        
        return ToolbarView(
            label: file.versionLabel(),
            items: versionItems
        ) { action in
            #if DEBUG
            logVersionDiagnostics("toolbar action=\(action)")
            #endif
            handleVersionAction(action)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
    
    private func handleVersionAction(_ action: Int) {
        switch action {
        case 0: // Previous
            file.changeVersion(by: -1)
            loadContent()
        case 1: // Next
            file.changeVersion(by: 1)
            loadContent()
        case 2: // Duplicate
            file.addVersion()
            loadContent()
            WriteCoalescer.shared?.requestSave(reason: "drama-scene-duplicate-version")
            WriteCoalescer.shared?.flush()
        case 3: // Delete
            #if DEBUG
            logVersionDiagnostics("about to present delete alert")
            #endif
            showDeleteVersionAlert = true
        default:
            break
        }
    }
    
    // MARK: - Editor Toolbar
    
    private var editorToolbar: some View {
        HStack {
            // View mode picker
            Picker(NSLocalizedString("drama.viewMode", comment: "View Mode"), selection: $viewMode) {
                ForEach(DramaViewMode.allCases, id: \.self) { mode in
                    Label(mode.localizedName, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)
            
            Spacer()
            
            // Script type picker
            Picker(NSLocalizedString("drama.scriptType", comment: "Script Type"), selection: $scriptType) {
                ForEach(DramaScriptType.allCases, id: \.self) { type in
                    Text(type.localizedName).tag(type)
                }
            }
            .pickerStyle(.menu)
            
            // Validate button
            Button {
                validateAndShowErrors()
            } label: {
                Image(systemName: validationErrors.isEmpty ? "checkmark.circle" : "exclamationmark.triangle.fill")
                    .foregroundColor(validationErrors.isEmpty ? .secondary : .yellow)
            }
            .accessibilityLabel(NSLocalizedString("drama.validate", comment: "Validate Script"))

            Button {
                rawDramaAnalysisRequest = RawDramaAnalysisRequest(
                    content: sourceText,
                    fileName: file.name
                )
            } label: {
                Image(systemName: "text.magnifyingglass")
            }
            .accessibilityLabel("Analyze with Manuscript Analyst")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    // MARK: - Editor Content
    
    @ViewBuilder
    private var editorContent: some View {
        VStack(spacing: 0) {
            // Search bar (only shown in source mode when active)
            if viewMode == .source {
                InEditorSearchBar(
                    manager: searchManager,
                    isVisible: $showSearchBar
                )
            }
            
            switch viewMode {
            case .source:
                sourceEditor
            case .formatted:
                formattedPreview
            case .print:
                printPreview
            }
        }
    }
    
    /// Source mode: plain text editor for DML
    private var sourceEditor: some View {
        DMLTextEditor(
            project: project,
            text: $sourceText,
            selectedRange: $selectedRange,
            onUndoManagerReady: { undoManager in
                textViewUndoManager = undoManager
            },
            onTextViewReady: { tv in
                textView = tv
            }
        )
        .background(colorScheme == .dark ? Color(UIColor.systemBackground) : Color.white)
    }
    
    // MARK: - Character/Location Insert Menu
    
    /// Menu for inserting character or location names
    private var characterLocationInsertMenu: some View {
        Menu {
            characterInsertSection
            locationInsertSection
            scenePlotElementsSection
        } label: {
            Image(systemName: "person.text.rectangle")
        }
        .accessibilityLabel(NSLocalizedString("drama.insertCharacterLocation", comment: "Insert Character or Location"))
    }
    
    @ViewBuilder
    private var characterInsertSection: some View {
        let characters = computedCharactersForInsertMenu
        if !characters.isEmpty {
            Section(NSLocalizedString("autocomplete.characters", comment: "Characters")) {
                ForEach(characters, id: \.id) { character in
                    Button {
                        selectedCharacter = character
                    } label: {
                        Label(character.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"), systemImage: "person.fill")
                    }
                }
            }
        }
    }

    private var computedCharactersForInsertMenu: [Character] {
        if let scene = file.scene {
            var seen = Set<PersistentIdentifier>()
            var result: [Character] = []
            for c in scene.characters ?? [] {
                if seen.insert(c.persistentModelID).inserted { result.append(c) }
            }
            for element in scene.plotElements ?? [] {
                for c in (element.characterLinks ?? []).compactMap(\.character) {
                    if seen.insert(c.persistentModelID).inserted { result.append(c) }
                }
            }
            return result.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }
        } else {
            return (project.characters ?? []).sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }
        }
    }
    
    @ViewBuilder
    private var locationInsertSection: some View {
        let locations = computedLocationsForInsertMenu
        if !locations.isEmpty {
            Section(NSLocalizedString("autocomplete.locations", comment: "Locations")) {
                ForEach(locations, id: \.id) { location in
                    Button {
                        selectedLocation = location
                    } label: {
                        Label(location.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"), systemImage: "mappin.circle.fill")
                    }
                }
            }
        }
    }

    private var computedLocationsForInsertMenu: [Location] {
        if let scene = file.scene {
            var seen = Set<PersistentIdentifier>()
            var result: [Location] = []
            for loc in scene.locations ?? [] {
                if seen.insert(loc.persistentModelID).inserted { result.append(loc) }
            }
            for element in scene.plotElements ?? [] {
                for loc in (element.locationLinks ?? []).compactMap(\.location) {
                    if seen.insert(loc.persistentModelID).inserted { result.append(loc) }
                }
            }
            return result.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }
        } else {
            return (project.locations ?? []).sorted { ($0.name ?? "") < ($1.name ?? "") }
        }
    }
    
    @ViewBuilder
    private var scenePlotElementsSection: some View {
        let elements = file.scene?.plotElements ?? []
        if !elements.isEmpty {
            Section(NSLocalizedString("editor.scenePlotElements", comment: "Scene Plot Elements")) {
                ForEach(elements.sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }, id: \.id) { element in
                    Button {
                        selectedPlotElement = element
                    } label: {
                        Label(element.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"), systemImage: "bookmark")
                    }
                }
            }
        }
    }
    
    // MARK: - Print
    
    /// Print the script
    private func printScript() {
        // Check entitlement for printing
        if !EntitlementManager.shared.canPrint(projectType: project.type) {
            upgradePromptReason = .printBlocked(projectType: project.type)
            return
        }
        
        // Check if printing is available
        guard UIPrintInteractionController.isPrintingAvailable else {
            printErrorMessage = NSLocalizedString("print.error.notAvailable", comment: "Printing is not available on this device")
            showPrintError = true
            return
        }
        
        // Use the rendered content for printing
        renderContent()
        
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = file.name
        printInfo.outputType = .general
        
        let printController = UIPrintInteractionController.shared
        printController.printInfo = printInfo
        
        // Create a simple print formatter from the rendered content
        let formatter = UISimpleTextPrintFormatter(attributedText: renderedContent)
        formatter.perPageContentInsets = UIEdgeInsets(top: 72, left: 72, bottom: 72, right: 72)
        printController.printFormatter = formatter
        
        printController.present(animated: true)
    }
    
    /// Formatted preview: read-only rendered content
    private var formattedPreview: some View {
        ScrollView {
            AttributedTextView(attributedText: renderedContent)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(UIColor.systemBackground))
    }
    
    /// Print preview: paginated layout
    private var printPreview: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 20) {
                ForEach(Array(printPreviewPages.enumerated()), id: \.offset) { index, pageContent in
                    printPreviewPage(pageContent, pageNumber: index + 1)
                }
            }
            .padding()
        }
        .background(Color.gray.opacity(0.3))
    }

    private func printPreviewPage(_ pageContent: NSAttributedString, pageNumber: Int) -> some View {
        VStack(alignment: .leading) {
            AttributedTextView(attributedText: pageContent)
                .padding(72)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 612, height: 792)
        .background(Color.white)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        .overlay(alignment: .bottomTrailing) {
            Text("\(pageNumber)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.trailing, 20)
                .padding(.bottom, 14)
        }
    }
    
    // MARK: - Validation Errors Sheet
    
    private var validationErrorsSheet: some View {
        NavigationStack {
            Group {
                if validationErrors.isEmpty {
                    // No errors - show success message
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text(NSLocalizedString("drama.validation.noIssues", comment: "No Issues Found"))
                            .font(.headline)
                        Text(NSLocalizedString("drama.validation.scriptValid", comment: "Your script is valid."))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(validationErrors) { error in
                            HStack {
                                Image(systemName: error.severity == .error ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(error.severity == .error ? .red : .yellow)
                                
                                VStack(alignment: .leading) {
                                    Text(NSLocalizedString("drama.validation.line", comment: "Line") + " \(error.lineNumber)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(error.message)
                                        .font(.body)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("drama.validation.title", comment: "Validation Issues"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.done", comment: "Done")) {
                        showValidationErrors = false
                    }
                }
            }
        }
    }
    
    // MARK: - Character List Sheet
    
    private var characterListSheet: some View {
        NavigationStack {
            List {
                if let doc = parsedDocument {
                    ForEach(doc.characters, id: \.self) { character in
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(.secondary)
                            Text(character)
                                .font(.headline)
                            Spacer()
                            // Count dialogue blocks for this character
                            let count = doc.dialogueBlocks.filter { $0.character == character }.count
                            Text("\(count) \(count == 1 ? "line" : "lines")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("drama.characters.title", comment: "Characters in Scene"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.done", comment: "Done")) {
                        showCharacterList = false
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadContent() {
        // Load from current version's plain text content
        // DML is stored as plain text, not attributed string
        if let version = file.currentVersion {
            sourceText = version.content
            #if DEBUG
            print("🎭 DramaSceneEditorView.loadContent: content length = \(version.content.count)")
            print("🎭 First 100 chars: \(String(version.content.prefix(100)))")
            #endif
            parseAndRender(sourceText)
        } else {
            #if DEBUG
            print("🎭 DramaSceneEditorView.loadContent: no current version!")
            #endif
        }
    }

    private func scrollToInitialCharacterPosition() {
        guard let initialCharacterPosition else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard let textView else { return }
            let position = textView.resolvedNavigationPosition(
                initialCharacterPosition,
                headingText: initialHeadingText
            )
            let range = NSRange(location: position, length: 0)
            selectedRange = range
            textView.selectedRange = range
            #if targetEnvironment(macCatalyst)
            textView.scrollCharacterToTop(position, animated: true)
            #else
            textView.scrollCharacterToTop(position)
            #endif
            textView.resignFirstResponder()
        }
    }
    
    private func debounceSave(_ text: String) {
        saveDebounceTimer?.invalidate()
        saveDebounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            commitPendingSourceSave(text)
        }
    }

    private func commitPendingSourceSave(_ text: String? = nil) {
        saveDebounceTimer?.invalidate()
        saveDebounceTimer = nil
        let content = text ?? textView?.text ?? sourceText
        guard file.currentVersion?.content != content else { return }
        file.currentVersion?.content = content
        file.modifiedDate = Date()
        WriteCoalescer.shared?.requestSave(reason: "drama-scene-save-content")
        WriteCoalescer.shared?.flush()
    }
    
    private func debounceParse(_ text: String) {
        parseDebounceTimer?.invalidate()
        parseDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            parseAndRender(text)
        }
    }
    
    private func parseAndRender(_ text: String) {
        // Parse the DML
        parsedDocument = DramaMarkupParser.shared.parse(text)
        
        #if DEBUG
        print("🎭 parseAndRender: parsed \(parsedDocument?.elements.count ?? 0) elements")
        if let doc = parsedDocument {
            for element in doc.elements.prefix(5) {
                print("🎭   - \(element.type): '\(element.content.prefix(30))'")
            }
        }
        #endif
        
        // Validate
        validationErrors = DramaMarkupParser.shared.validate(text)
        
        // Render if in formatted mode
        renderContent()
    }
    
    private func renderContent() {
        guard let doc = parsedDocument else { 
            #if DEBUG
            print("🎭 renderContent: parsedDocument is nil!")
            #endif
            return 
        }
        
        #if DEBUG
        print("🎭 renderContent: viewMode=\(viewMode), scriptType=\(scriptType)")
        #endif
        
        renderedContent = DramaMarkupRenderer.shared.render(
            doc,
            scriptType: scriptType,
            viewMode: viewMode,
            showNotes: viewMode == .source
        )

        paginateForPrintPreview()
        
        #if DEBUG
        print("🎭 renderContent: rendered length = \(renderedContent.length)")
        if renderedContent.length > 0 {
            print("🎭 First 100 chars: \(renderedContent.string.prefix(100))")
        }
        #endif
    }

    private func paginateForPrintPreview() {
        guard renderedContent.length > 0 else {
            printPreviewPages = []
            return
        }

        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 72
        let contentSize = CGSize(
            width: pageWidth - (margin * 2),
            height: pageHeight - (margin * 2)
        )

        let textStorage = NSTextStorage(attributedString: renderedContent)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        var pages: [NSAttributedString] = []
        var previousEndLocation = 0

        while previousEndLocation < renderedContent.length {
            let textContainer = NSTextContainer(size: contentSize)
            textContainer.lineFragmentPadding = 0
            textContainer.maximumNumberOfLines = 0
            layoutManager.addTextContainer(textContainer)

            // Ensure NSLayoutManager has performed layout for this container before
            // querying glyph ranges — without this, containers after the first return
            // empty ranges causing early loop exit and single-page display.
            layoutManager.ensureLayout(for: textContainer)

            let glyphRange = layoutManager.glyphRange(for: textContainer)
            let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

            if characterRange.length == 0 || NSMaxRange(characterRange) <= previousEndLocation {
                break
            }

            pages.append(renderedContent.attributedSubstring(from: characterRange))
            previousEndLocation = NSMaxRange(characterRange)
        }

        if pages.isEmpty {
            pages = [renderedContent]
        }

        printPreviewPages = pages
    }
    
    private func validateAndShowErrors() {
        validationErrors = DramaMarkupParser.shared.validate(sourceText)
        #if DEBUG
        print("🎭 validateAndShowErrors: found \(validationErrors.count) errors")
        for error in validationErrors {
            print("🎭   - Line \(error.lineNumber): \(error.message)")
        }
        #endif
        showValidationErrors = true
    }
}

// MARK: - Attributed Text View (UIKit bridge)

/// A simple UIViewRepresentable for displaying attributed text
struct AttributedTextView: UIViewRepresentable {
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
        // Force layout update
        uiView.invalidateIntrinsicContentSize()
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }
}

// MARK: - Project Extension for Drama

extension Project {
    /// The script type for drama projects
    var dramaScriptType: DramaScriptType? {
        get {
            guard let raw = dramaScriptTypeRaw else { return nil }
            return DramaScriptType(rawValue: raw)
        }
        set {
            dramaScriptTypeRaw = newValue?.rawValue
        }
    }
}
