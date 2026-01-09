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
    
    // MARK: - Properties
    
    @Bindable var file: TextFile
    let project: Project
    
    // MARK: - State
    
    /// The current view mode
    @State private var viewMode: DramaViewMode = .source
    
    /// The script type (Film or Stage)
    @State private var scriptType: DramaScriptType
    
    /// The raw DML source text
    @State private var sourceText: String = ""
    
    /// The rendered attributed string (for formatted mode)
    @State private var renderedContent: NSAttributedString = NSAttributedString()
    
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
    
    /// Show print error alert
    @State private var showPrintError = false
    
    /// Show project characters list
    @State private var showProjectCharacters = false
    
    /// Show project locations list
    @State private var showProjectLocations = false
    
    /// Show project plot outline
    @State private var showProjectPlot = false
    
    /// Selected plot element to show in detail sheet
    @State private var selectedPlotElement: PlotElement?
    
    // MARK: - Computed Properties
    
    /// Characters from project for insert menu
    private var projectCharacters: [String] {
        (project.characters ?? [])
            .compactMap { $0.name }
            .sorted()
    }
    
    /// Locations from project for insert menu
    private var projectLocations: [String] {
        (project.locations ?? [])
            .compactMap { $0.name }
            .sorted()
    }
    
    // MARK: - Initialization
    
    init(file: TextFile, project: Project) {
        self.file = file
        self.project = project
        
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
        .toolbar {
            navigationToolbarContent
        }
        .onAppear {
            loadContent()
        }
        .onChange(of: sourceText) { _, newValue in
            debounceParse(newValue)
        }
        .onChange(of: scriptType) { _, _ in
            renderContent()
            // Save script type preference to project
            project.dramaScriptType = scriptType
            try? modelContext.save()
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
            NavigationStack {
                PlotElementDetailView(plotElement: plotElement, project: project)
            }
        }
        .alert(
            NSLocalizedString("fileEdit.deleteVersionTitle", comment: "Delete Version?"),
            isPresented: $showDeleteVersionAlert
        ) {
            Button(NSLocalizedString("contentView.delete", comment: "Delete"), role: .destructive) {
                file.deleteVersion()
                loadContent()
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
    }
    
    // MARK: - Navigation Toolbar Content
    
    @ToolbarContentBuilder
    private var navigationToolbarContent: some ToolbarContent {
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
        
        // Print button
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                printScript()
            } label: {
                Image(systemName: "printer")
            }
            .accessibilityLabel(NSLocalizedString("fileEdit.print.accessibility", comment: "Print"))
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
            try? modelContext.save()
        case 3: // Delete
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
        .onChange(of: sourceText) { _, newValue in
            saveContent(newValue)
        }
    }
    
    // MARK: - Character/Location Insert Menu
    
    /// Menu for inserting character or location names and viewing project details
    private var characterLocationInsertMenu: some View {
        Menu {
            // Insert character names section
            if !projectCharacters.isEmpty {
                Section(NSLocalizedString("autocomplete.characters", comment: "Characters")) {
                    ForEach(projectCharacters, id: \.self) { name in
                        Button {
                            insertCharacterName(name)
                        } label: {
                            Label(name, systemImage: "person.fill")
                        }
                    }
                }
            }
            
            // Insert location names section
            if !projectLocations.isEmpty {
                Section(NSLocalizedString("autocomplete.locations", comment: "Locations")) {
                    ForEach(projectLocations, id: \.self) { name in
                        Button {
                            insertLocationName(name)
                        } label: {
                            Label(name, systemImage: "mappin.circle.fill")
                        }
                    }
                }
            }
            
            Divider()
            
            // View project details section
            Section(NSLocalizedString("editor.viewProject", comment: "View Project")) {
                Button {
                    showProjectCharacters = true
                } label: {
                    Label(NSLocalizedString("fiction.characters", comment: "Characters"), systemImage: "person.2")
                }
                
                Button {
                    showProjectLocations = true
                } label: {
                    Label(NSLocalizedString("fiction.locations", comment: "Locations"), systemImage: "mappin.and.ellipse")
                }
                
                // Plot: Show linked plot elements if scene has any
                plotMenuItems
            }
        } label: {
            Image(systemName: "person.text.rectangle")
        }
        .accessibilityLabel(NSLocalizedString("drama.insertCharacterLocation", comment: "Insert Character or Location"))
    }
    
    /// Plot menu items - shows linked plot elements if scene has any
    @ViewBuilder
    private var plotMenuItems: some View {
        // Get plot elements linked to this scene
        let linkedPlotElements = file.scene?.plotElements ?? []
        
        if linkedPlotElements.isEmpty {
            // No linked plot elements - just show view all
            Button {
                showProjectPlot = true
            } label: {
                Label(NSLocalizedString("fiction.plot", comment: "Plot"), systemImage: "list.bullet.clipboard")
            }
        } else if linkedPlotElements.count == 1 {
            // Single linked plot element - show it directly
            let element = linkedPlotElements[0]
            Button {
                selectedPlotElement = element
            } label: {
                Label(element.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"), systemImage: "list.bullet.clipboard")
            }
            
            // Also allow viewing all plots
            Button {
                showProjectPlot = true
            } label: {
                Label(NSLocalizedString("fiction.plot.viewAll", comment: "View All Plots"), systemImage: "list.bullet.clipboard.fill")
            }
        } else {
            // Multiple linked plot elements - show as submenu
            Menu {
                ForEach(linkedPlotElements.sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }, id: \.id) { element in
                    Button {
                        selectedPlotElement = element
                    } label: {
                        if let stage = element.monomythStage {
                            Label("\(stage.order). \(element.name ?? stage.localizedName)", systemImage: "bookmark")
                        } else {
                            Label(element.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"), systemImage: "bookmark")
                        }
                    }
                }
                
                Divider()
                
                Button {
                    showProjectPlot = true
                } label: {
                    Label(NSLocalizedString("fiction.plot.viewAll", comment: "View All Plots"), systemImage: "list.bullet.clipboard.fill")
                }
            } label: {
                Label(NSLocalizedString("fiction.plot", comment: "Plot"), systemImage: "list.bullet.clipboard")
            }
        }
    }
    
    /// Insert text at the current cursor position
    private func insertTextAtCursor(_ text: String) {
        let insertionPoint = min(selectedRange.location, sourceText.count)
        let index = sourceText.index(sourceText.startIndex, offsetBy: insertionPoint)
        sourceText.insert(contentsOf: text, at: index)
        
        // Move cursor to end of inserted text
        selectedRange = NSRange(location: insertionPoint + text.count, length: 0)
    }
    
    /// Insert a character name at cursor position
    private func insertCharacterName(_ name: String) {
        // For drama, character names are uppercase
        let uppercaseName = name.uppercased()
        insertTextAtCursor(uppercaseName)
    }
    
    /// Insert a location name formatted as DML scene heading
    private func insertLocationName(_ name: String) {
        // Insert as a scene heading
        let heading = "@ LOCATION: " + name
        insertTextAtCursor(heading)
    }
    
    // MARK: - Print
    
    /// Print the script
    private func printScript() {
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
        ScrollView {
            VStack(spacing: 20) {
                // Simulated page
                VStack(alignment: .leading) {
                    AttributedTextView(attributedText: renderedContent)
                        .padding(72)  // Standard 1" margins
                }
                .frame(width: 612, height: 792)  // US Letter size in points
                .background(Color.white)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .padding()
        }
        .background(Color.gray.opacity(0.3))
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
    
    private func saveContent(_ text: String) {
        // Save DML source as plain text
        file.currentVersion?.content = text
        file.modifiedDate = Date()
        try? modelContext.save()
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
        
        #if DEBUG
        print("🎭 renderContent: rendered length = \(renderedContent.length)")
        if renderedContent.length > 0 {
            print("🎭 First 100 chars: \(renderedContent.string.prefix(100))")
        }
        #endif
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
