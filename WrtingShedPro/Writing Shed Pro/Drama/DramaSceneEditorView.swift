//
//  DramaSceneEditorView.swift
//  Writing Shed Pro
//
//  Feature 023: Smart Drama Creation
//  Editor view for drama scene content with source/formatted toggle
//

import SwiftUI
import SwiftData

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
            // Toolbar with view mode toggle
            editorToolbar
            
            Divider()
            
            // Editor content based on mode
            editorContent
        }
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    // Script type selection
                    Section {
                        Picker(NSLocalizedString("drama.scriptType", comment: "Script Type"), selection: $scriptType) {
                            ForEach(DramaScriptType.allCases, id: \.self) { type in
                                Text(type.localizedName).tag(type)
                            }
                        }
                    }
                    
                    // Validation
                    Button {
                        validateAndShowErrors()
                    } label: {
                        Label(NSLocalizedString("drama.validate", comment: "Validate Script"), 
                              systemImage: "checkmark.circle")
                    }
                    
                    // Character list
                    if let doc = parsedDocument, !doc.characters.isEmpty {
                        Button {
                            showCharacterList = true
                        } label: {
                            Label(String(format: NSLocalizedString("drama.characters.count", comment: "Characters (%d)"), doc.characters.count), 
                                  systemImage: "person.2")
                        }
                    }
                    
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
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
            
            // Script type indicator
            Text(scriptType.localizedName)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
            
            // Validation status indicator
            if !validationErrors.isEmpty {
                Button {
                    showValidationErrors = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("\(validationErrors.count)")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    // MARK: - Editor Content
    
    @ViewBuilder
    private var editorContent: some View {
        switch viewMode {
        case .source:
            sourceEditor
        case .formatted:
            formattedPreview
        case .print:
            printPreview
        }
    }
    
    /// Source mode: editable text with syntax highlighting
    private var sourceEditor: some View {
        TextEditor(text: $sourceText)
            .font(.custom("Courier", size: 14))
            .scrollContentBackground(.hidden)
            .background(colorScheme == .dark ? Color(UIColor.systemBackground) : Color.white)
            .onChange(of: sourceText) { _, newValue in
                saveContent(newValue)
            }
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
