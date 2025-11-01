import SwiftUI
import SwiftData
import ToolbarSUI

struct FileEditView: View {
    let file: File
    
    @State private var attributedContent: NSAttributedString
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var previousContent: String = ""
    @State private var presentDeleteAlert = false
    @State private var isPerformingUndoRedo = false
    @State private var refreshTrigger = UUID()
    @State private var forceRefresh = false
    @State private var showStylePicker = false
    @State private var currentParagraphStyle: UIFont.TextStyle? = .body
    @StateObject private var undoManager: TextFileUndoManager
    @StateObject private var textViewCoordinator = TextViewCoordinator()
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    enum VersionAction: Int {
        case previous
        case next
        case add
        case delete
    }
    
    init(file: File) {
        self.file = file
        
        // Initialize attributed content (the single source of truth)
        let initialAttributed = file.currentVersion?.attributedContent ?? NSAttributedString(
            string: "",
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )
        _attributedContent = State(initialValue: initialAttributed)
        _previousContent = State(initialValue: initialAttributed.string)
        
        // Position cursor at end of text (where user likely wants to continue writing)
        let textLength = initialAttributed.length
        _selectedRange = State(initialValue: NSRange(location: textLength, length: 0))
        
        // Try to restore undo manager or create new one
        if let restoredManager = file.restoreUndoState() {
            _undoManager = StateObject(wrappedValue: restoredManager)
        } else {
            let newManager = TextFileUndoManager(file: file)
            _undoManager = StateObject(wrappedValue: newManager)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Version Navigator at top
            ToolbarView(
                label: file.versionLabel(),
                items: [
                    SUIToolbarItem(
                        icon: "chevron.left.circle",
                        title: "Show previous version",
                        disabled: file.atFirstVersion()
                    ),
                    SUIToolbarItem(
                        icon: "chevron.right.circle",
                        title: "Show next version",
                        disabled: file.atLastVersion()
                    ),
                    SUIToolbarItem(
                        icon: "plus.circle",
                        title: "Duplicate this version",
                        disabled: false
                    ),
                    SUIToolbarItem(
                        icon: "trash.circle",
                        title: "Delete this version",
                        disabled: (file.versions?.count ?? 0) <= 1
                    )
                ]
            ) { action in
                handleVersionAction(VersionAction(rawValue: action) ?? .next)
            }
            .alert(isPresented: $presentDeleteAlert) {
                Alert(
                    title: Text(NSLocalizedString("fileEdit.deleteVersionTitle", comment: "Delete Version?")),
                    message: Text(NSLocalizedString("fileEdit.deleteVersionMessage", comment: "Please confirm that you want to delete this version")),
                    primaryButton: .destructive(Text(NSLocalizedString("contentView.delete", comment: "Delete"))) {
                        file.deleteVersion()
                        loadCurrentVersion()
                        saveChanges()
                    },
                    secondaryButton: .cancel()
                )
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 8)
            
            // Text Editor
            if forceRefresh {
                FormattedTextEditor(
                    attributedText: $attributedContent,
                    selectedRange: $selectedRange,
                    textViewCoordinator: textViewCoordinator,
                    onTextChange: { newText in
                        handleAttributedTextChange(newText)
                    }
                )
                .id(refreshTrigger)
            } else {
                FormattedTextEditor(
                    attributedText: $attributedContent,
                    selectedRange: $selectedRange,
                    textViewCoordinator: textViewCoordinator,
                    onTextChange: { newText in
                        handleAttributedTextChange(newText)
                    }
                )
                .id(refreshTrigger)
            }
            
            // Formatting Toolbar at bottom - near keyboard (Pages style)
            // Using UIKit toolbar to preserve keyboard focus
            if let textView = textViewCoordinator.textView {
                FormattingToolbarView(textView: textView) { action in
                    switch action {
                    case .paragraphStyle:
                        showStylePicker = true
                    case .bold:
                        applyFormatting(.bold)
                    case .italic:
                        applyFormatting(.italic)
                    case .underline:
                        applyFormatting(.underline)
                    case .strikethrough:
                        applyFormatting(.strikethrough)
                    case .insert:
                        print("Insert button tapped")
                    }
                }
                .frame(height: 44)
                #if targetEnvironment(macCatalyst)
                .padding(.vertical, 2)
                #endif
                .background(
                    Color(UIColor.secondarySystemBackground)
                        .ignoresSafeArea(edges: .horizontal)
                )
                .overlay(
                    VStack(spacing: 0) {
                        Divider()
                            .ignoresSafeArea(edges: .horizontal)
                        Spacer()
                        Divider()
                            .ignoresSafeArea(edges: .horizontal)
                    }
                )
            } else {
                // Fallback while textView is being created
                Color(UIColor.secondarySystemBackground)
                    .frame(height: 44)
                    .ignoresSafeArea(edges: .horizontal)
            }
        }
        .navigationTitle(file.name ?? NSLocalizedString("fileEdit.untitledFile", comment: "Untitled file"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Undo button
                    Button(action: {
                        performUndo()
                        restoreKeyboardFocus()
                    }) {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!undoManager.canUndo || isPerformingUndoRedo)
                    .accessibilityLabel("Undo")
                    
                    // Redo button
                    Button(action: {
                        performRedo()
                        restoreKeyboardFocus()
                    }) {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(!undoManager.canRedo || isPerformingUndoRedo)
                    .accessibilityLabel("Redo")
                    
                    // Done button
                    Button(NSLocalizedString("fileEdit.done", comment: "Done button")) {
                        saveChanges()
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            saveUndoState()
        }
        .onAppear {
            // Show keyboard/cursor when opening file
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.textViewCoordinator.textView?.becomeFirstResponder()
            }
            
            // Update current style from content
            updateCurrentParagraphStyle()
            
            // Set typing attributes from current content or stylesheet
            if let project = file.project {
                if attributedContent.length > 0 {
                    // Reapply all styles to pick up any style definition changes
                    // This ensures the document reflects the latest style settings
                    print("📝 onAppear: Reapplying styles to pick up any changes")
                    reapplyAllStyles()
                    
                    // Use attributes from existing content
                    let attrs = attributedContent.attributes(at: 0, effectiveRange: nil)
                    textViewCoordinator.modifyTypingAttributes { textView in
                        textView.typingAttributes = attrs
                    }
                } else {
                    // Empty document - set typing attributes from stylesheet
                    let bodyAttrs = TextFormatter.getTypingAttributes(
                        forStyleNamed: UIFont.TextStyle.body.rawValue,
                        project: project,
                        context: modelContext
                    )
                    textViewCoordinator.modifyTypingAttributes { textView in
                        textView.typingAttributes = bodyAttrs
                    }
                    print("📝 onAppear: Set typing attributes for empty document from stylesheet")
                }
            }
        }
        .onChange(of: selectedRange) { oldValue, newValue in
            // Update style when selection changes
            updateCurrentParagraphStyle()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProjectStyleSheetChanged"))) { notification in
            print("📋 ========== ProjectStyleSheetChanged NOTIFICATION ==========")
            print("📋 Notification userInfo: \(notification.userInfo ?? [:])")
            
            // When a project's stylesheet changes, check if it's our project and reapply styles
            guard let notifiedProjectID = notification.userInfo?["projectID"] as? UUID else {
                print("⚠️ No projectID in notification")
                print("📋 ========== END ==========")
                return
            }
            
            guard let ourProjectID = file.project?.id else {
                print("⚠️ Our file has no project")
                print("📋 ========== END ==========")
                return
            }
            
            print("📋 Notified project ID: \(notifiedProjectID.uuidString)")
            print("📋 Our project ID: \(ourProjectID.uuidString)")
            print("📋 Match: \(notifiedProjectID == ourProjectID)")
            
            guard notifiedProjectID == ourProjectID else {
                print("📋 Not for us - ignoring")
                print("📋 ========== END ==========")
                return
            }
            
            print("📋 Received ProjectStyleSheetChanged notification for our project")
            
            // Reapply all styles with the new stylesheet
            if attributedContent.length > 0 {
                print("📋 Reapplying all styles due to stylesheet change")
                reapplyAllStyles()
            } else {
                print("📋 Document is empty, skipping reapply")
            }
            print("📋 ========== END ==========")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StyleSheetModified"))) { notification in
            print("📋 ========== StyleSheetModified NOTIFICATION ==========")
            print("📋 Notification userInfo: \(notification.userInfo ?? [:])")
            
            // When a stylesheet is modified, check if it's our project's stylesheet and reapply styles
            guard let modifiedStylesheetID = notification.userInfo?["stylesheetID"] as? UUID else {
                print("⚠️ No stylesheetID in notification")
                print("📋 ========== END ==========")
                return
            }
            
            guard let ourStylesheetID = file.project?.styleSheet?.id else {
                print("⚠️ Our project has no stylesheet")
                print("📋 ========== END ==========")
                return
            }
            
            print("📋 Modified stylesheet ID: \(modifiedStylesheetID.uuidString)")
            print("📋 Our stylesheet ID: \(ourStylesheetID.uuidString)")
            print("📋 Match: \(modifiedStylesheetID == ourStylesheetID)")
            
            guard modifiedStylesheetID == ourStylesheetID else {
                print("📋 Not for us - ignoring")
                print("📋 ========== END ==========")
                return
            }
            
            print("📋 Received StyleSheetModified notification for our project's stylesheet")
            
            // Reapply all styles with the updated style definitions
            if attributedContent.length > 0 {
                print("📋 Reapplying all styles due to style modification")
                reapplyAllStyles()
            } else {
                print("📋 Document is empty, skipping reapply")
            }
            print("📋 ========== END ==========")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UndoRedoContentRestored"))) { notification in
            // Handle formatting undo/redo - restore attributed content
            guard let restoredContent = notification.userInfo?["content"] as? NSAttributedString else { return }
            
            #if DEBUG
            print("🔄 Received UndoRedoContentRestored notification")
            #endif
            
            // Update local state with restored content
            attributedContent = restoredContent
            
            // Force UI refresh
            forceRefresh.toggle()
            refreshTrigger = UUID()
        }
        .sheet(isPresented: $showStylePicker) {
            StylePickerSheet(
                currentStyle: $currentParagraphStyle,
                onStyleSelected: { style in
                    applyParagraphStyle(style)
                },
                project: file.project,
                onReapplyStyles: {
                    reapplyAllStyles()
                }
            )
        }
    }
    
    // MARK: - Attributed Text Handling
    
    private func handleAttributedTextChange(_ newAttributedText: NSAttributedString) {
        #if DEBUG
        print("🔄 handleAttributedTextChange called")
        print("🔄 isPerformingUndoRedo: \(isPerformingUndoRedo)")
        #endif
        
        guard !isPerformingUndoRedo else {
            print("🔄 Skipping - performing undo/redo")
            return
        }
        
        let newContent = newAttributedText.string
        
        #if DEBUG
        print("🔄 Previous: '\(previousContent)'")
        print("🔄 New: '\(newContent)'")
        #endif
        
        // Only register change if content actually changed
        guard newContent != previousContent else {
            print("🔄 Content unchanged - skipping")
            return
        }
        
        print("🔄 Content changed - registering with undo manager")
        
        // Create and execute undo command
        if let change = TextDiffService.diff(from: previousContent, to: newContent) {
            let command = TextDiffService.createCommand(from: change, file: file)
            undoManager.execute(command)
        }
        
        // Update previous content for next comparison
        previousContent = newContent
        
        // Save to model (attributedContent setter automatically syncs plain text)
        file.currentVersion?.attributedContent = newAttributedText
        file.modifiedDate = Date()
        
        // Save context
        do {
            try modelContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
    
    // MARK: - Undo/Redo
    
    private func performUndo() {
        print("🔄 performUndo called - canUndo: \(undoManager.canUndo)")
        guard undoManager.canUndo else { return }
        
        isPerformingUndoRedo = true
        
        undoManager.undo()
        
        // Reload from model (attributedContent getter handles plain text fallback)
        let newAttributedContent = file.currentVersion?.attributedContent ?? NSAttributedString(
            string: "",
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )
        
        print("🔄 After undo - new content: '\(newAttributedContent.string)' (length: \(newAttributedContent.string.count))")
        
        // Update all state
        attributedContent = newAttributedContent
        previousContent = newAttributedContent.string
        
        // FIX: Position cursor at end of new content
        selectedRange = NSRange(location: newAttributedContent.string.count, length: 0)
        print("🔄 Set selectedRange to end: \(selectedRange)")
        
        // Force refresh
        forceRefresh.toggle()
        refreshTrigger = UUID()
        
        // Reset flag after UI has updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isPerformingUndoRedo = false
            print("🔄 Reset isPerformingUndoRedo flag")
        }
    }
    
    private func performRedo() {
        print("� performRedo called - canRedo: \(undoManager.canRedo)")
        guard undoManager.canRedo else { return }
        
        isPerformingUndoRedo = true
        
        undoManager.redo()
        
        // Reload from model (attributedContent getter handles plain text fallback)
        let newAttributedContent = file.currentVersion?.attributedContent ?? NSAttributedString(
            string: "",
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )
        
        print("🔄 After redo - new content: '\(newAttributedContent.string)' (length: \(newAttributedContent.string.count))")
        
        // Update all state
        attributedContent = newAttributedContent
        previousContent = newAttributedContent.string
        
        // FIX: Position cursor at end of new content
        selectedRange = NSRange(location: newAttributedContent.string.count, length: 0)
        print("🔄 Set selectedRange to end: \(selectedRange)")
        
        // Force refresh
        forceRefresh.toggle()
        refreshTrigger = UUID()
        
        // Reset flag after UI has updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isPerformingUndoRedo = false
            print("🔄 Reset isPerformingUndoRedo flag")
        }
    }
    
    // MARK: - Formatting
    
    /// Format types that can be applied
    private enum FormatType {
        case bold
        case italic
        case underline
        case strikethrough
    }
    
    /// Apply formatting to the current selection
    private func applyFormatting(_ formatType: FormatType) {
        #if DEBUG
        print("🎨 applyFormatting(\(formatType)) called")
        print("🎨 selectedRange: {\(selectedRange.location), \(selectedRange.length)}")
        #endif
        
        // Ensure we have a valid selection
        guard selectedRange.location != NSNotFound else {
            print("⚠️ selectedRange.location is NSNotFound")
            return
        }
        
        // If no text is selected (cursor only), modify typing attributes
        if selectedRange.length == 0 {
            print("🎨 Modifying typing attributes for \(formatType)")
            modifyTypingAttributes(formatType)
            return
        }
        
        print("🎨 Applying \(formatType) to range {\(selectedRange.location), \(selectedRange.length)}")
        
        // Store before state for undo
        let beforeContent = attributedContent
        
        // Apply the appropriate formatting
        let newAttributedContent: NSAttributedString
        let actionDescription: String
        switch formatType {
        case .bold:
            newAttributedContent = TextFormatter.toggleBold(in: attributedContent, range: selectedRange)
            actionDescription = "Bold"
        case .italic:
            newAttributedContent = TextFormatter.toggleItalic(in: attributedContent, range: selectedRange)
            actionDescription = "Italic"
        case .underline:
            newAttributedContent = TextFormatter.toggleUnderline(in: attributedContent, range: selectedRange)
            actionDescription = "Underline"
        case .strikethrough:
            newAttributedContent = TextFormatter.toggleStrikethrough(in: attributedContent, range: selectedRange)
            actionDescription = "Strikethrough"
        }
        
        print("🎨 Format applied successfully")
        
        // Update local state immediately for instant UI feedback
        attributedContent = newAttributedContent
        
        print("🎨 Updated local state with formatted content")
        
        // Create formatting command for undo/redo
        let command = FormatApplyCommand(
            description: actionDescription,
            range: selectedRange,
            beforeContent: beforeContent,
            afterContent: newAttributedContent,
            targetFile: file
        )
        
        // Execute command through undo manager
        undoManager.execute(command)
        
        print("🎨 Formatting command added to undo stack")
    }
    
    /// Modify typing attributes at cursor position
    private func modifyTypingAttributes(_ formatType: FormatType) {
        // Use coordinator to modify typing attributes without triggering view updates
        textViewCoordinator.modifyTypingAttributes { textView in
            // Get current typing attributes
            var typingAttributes = textView.typingAttributes
            
            // Get or create font attribute
            let currentFont = typingAttributes[.font] as? UIFont ?? UIFont.preferredFont(forTextStyle: .body)
            
            // Modify based on format type
            switch formatType {
            case .bold:
                let traits = currentFont.fontDescriptor.symbolicTraits
                let newTraits = traits.contains(.traitBold) ?
                    traits.subtracting(.traitBold) :
                    traits.union(.traitBold)
                
                if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(newTraits) {
                    typingAttributes[.font] = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                }
                
            case .italic:
                let traits = currentFont.fontDescriptor.symbolicTraits
                let newTraits = traits.contains(.traitItalic) ?
                    traits.subtracting(.traitItalic) :
                    traits.union(.traitItalic)
                
                if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(newTraits) {
                    typingAttributes[.font] = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                }
                
            case .underline:
                if let currentStyle = typingAttributes[.underlineStyle] as? Int, currentStyle != 0 {
                    typingAttributes[.underlineStyle] = 0
                } else {
                    typingAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
                }
                
            case .strikethrough:
                if let currentStyle = typingAttributes[.strikethroughStyle] as? Int, currentStyle != 0 {
                    typingAttributes[.strikethroughStyle] = 0
                } else {
                    typingAttributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                }
            }
            
            // Apply the modified typing attributes
            textView.typingAttributes = typingAttributes
            
            print("🎨 Modified typing attributes for \(formatType)")
            print("🎨 New typing attributes: \(typingAttributes)")
        }
        
        // DON'T trigger refresh - it dismisses the keyboard
        // The toolbar will check typing attributes directly when selection changes
    }
    
    /// Update the current paragraph style state by checking the attributed content
    private func updateCurrentParagraphStyle() {
        // Try model-based lookup if we have a project
        if let project = file.project,
           let styleName = TextFormatter.getCurrentStyleName(
               in: attributedContent,
               at: selectedRange,
               project: project,
               context: modelContext
           ) {
            currentParagraphStyle = UIFont.TextStyle(rawValue: styleName)
            return
        }
        
        // Fallback to direct UIFont.TextStyle lookup
        if let style = TextFormatter.getCurrentStyle(in: attributedContent, at: selectedRange) {
            currentParagraphStyle = style
        }
    }
    
    /// Reapply all text styles in the document with updated definitions from the database
    /// This is called when the user chooses "Apply Now" after editing styles
    private func reapplyAllStyles() {
        print("🔄 ========== REAPPLY ALL STYLES START ==========")
        print("🔄 Document length: \(attributedContent.length)")
        
        // Need a project to resolve styles
        guard let project = file.project else {
            print("⚠️ No project - cannot reapply styles")
            print("🔄 ========== REAPPLY ALL STYLES END (NO PROJECT) ==========")
            return
        }
        
        print("🔄 Project: \(project.name ?? "unnamed")")
        print("🔄 Stylesheet: \(project.styleSheet?.name ?? "none")")
        print("🔄 Stylesheet ID: \(project.styleSheet?.id.uuidString ?? "none")")
        
        // If document is empty, nothing to reapply
        guard attributedContent.length > 0 else {
            print("📝 Document is empty - nothing to reapply")
            print("🔄 ========== REAPPLY ALL STYLES END (EMPTY) ==========")
            return
        }
        
        let mutableText = NSMutableAttributedString(attributedString: attributedContent)
        var hasChanges = false
        var stylesFound = 0
        
        // Walk through entire document and reapply all text styles
        mutableText.enumerateAttribute(
            .textStyle,  // Use the defined constant, not a raw string
            in: NSRange(location: 0, length: mutableText.length),
            options: []
        ) { value, range, _ in
            guard let styleName = value as? String else { 
                print("⚠️ Found TextStyle attribute but value is not a string: \(String(describing: value))")
                return 
            }
            
            stylesFound += 1
            print("🔄 [\(stylesFound)] Found style '\(styleName)' at range {\(range.location), \(range.length)}")
            
            // Re-fetch the style from database to get latest changes
            guard let updatedStyle = StyleSheetService.resolveStyle(
                named: styleName,
                for: project,
                context: modelContext
            ) else {
                print("⚠️ Could not resolve style '\(styleName)' for project '\(project.name ?? "unnamed")'")
                return
            }
            
            print("✅ Resolved style '\(styleName)': fontSize=\(updatedStyle.fontSize), bold=\(updatedStyle.isBold), italic=\(updatedStyle.isItalic)")
            
            // Get updated attributes from the style
            let newAttributes = updatedStyle.generateAttributes()
            guard let newFont = newAttributes[NSAttributedString.Key.font] as? UIFont else {
                print("⚠️ Style '\(styleName)' has no font in generated attributes")
                return
            }
            
            print("📝 New font: \(newFont.fontName) \(newFont.pointSize)pt, bold=\(updatedStyle.isBold), italic=\(updatedStyle.isItalic)")
            if let color = newAttributes[.foregroundColor] as? UIColor {
                print("📝 New color: \(color)")
            }
            
            // Completely replace attributes with fresh stylesheet values
            // This ensures stylesheet changes fully propagate to documents
            print("✅ Applying new attributes to range {\(range.location), \(range.length)}")
            mutableText.setAttributes(newAttributes, range: range)
            hasChanges = true
        }
        
        print("🔄 Total styles found and processed: \(stylesFound)")
        print("🔄 Has changes: \(hasChanges)")
        
        // Update document if any changes were made
        if hasChanges {
            let beforeContent = attributedContent
            attributedContent = mutableText
            
            print("✅ Updated attributedContent with new styles")
            print("✅ Reapplied all styles successfully")
            
            // Create undo command
            let command = FormatApplyCommand(
                description: "Reapply All Styles",
                range: NSRange(location: 0, length: mutableText.length),
                beforeContent: beforeContent,
                afterContent: mutableText,
                targetFile: file
            )
            
            undoManager.execute(command)
            print("✅ Added undo command")
            
            // Update typing attributes for current position
            if selectedRange.location != NSNotFound,
               selectedRange.location <= attributedContent.length {
                // Get the style name at current position
                if let styleName = TextFormatter.getCurrentStyleName(
                    in: attributedContent,
                    at: selectedRange,
                    project: project,
                    context: modelContext
                ) {
                    let typingAttrs = TextFormatter.getTypingAttributes(
                        forStyleNamed: styleName,
                        project: project,
                        context: modelContext
                    )
                    textViewCoordinator.modifyTypingAttributes { textView in
                        textView.typingAttributes = typingAttrs
                    }
                    print("✅ Updated typing attributes")
                }
            }
            
            restoreKeyboardFocus()
            print("✅ Restored keyboard focus")
        } else {
            print("📝 No styles found to reapply - hasChanges is false")
        }
        
        print("🔄 ========== REAPPLY ALL STYLES END ==========")
    }
    
    /// Apply a paragraph style to the current selection
    private func applyParagraphStyle(_ style: UIFont.TextStyle) {
        #if DEBUG
        print("📝 ========== APPLY PARAGRAPH STYLE START ==========")
        print("📝 Style: \(style.rawValue)")
        print("📝 selectedRange: {\(selectedRange.location), \(selectedRange.length)}")
        print("📝 Document length: \(attributedContent.length)")
        
        // Log current attributes at selection
        if attributedContent.length > 0 && selectedRange.location < attributedContent.length {
            let attrs = attributedContent.attributes(at: selectedRange.location, effectiveRange: nil)
            print("📝 Current attributes at selection:")
            if let color = attrs[.foregroundColor] as? UIColor {
                print("   Color: \(color.toHex() ?? "unknown")")
            }
            if let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle {
                print("   Alignment: \(paragraphStyle.alignment.rawValue)")
            }
            if let textStyle = attrs[.textStyle] as? String {
                print("   TextStyle attribute: \(textStyle)")
            }
        }
        #endif
        
        // Ensure we have a valid location
        guard selectedRange.location != NSNotFound else {
            print("⚠️ selectedRange.location is NSNotFound")
            print("📝 ========== END ==========")
            return
        }
        
        // Try to use model-based formatting if we have a project
        let newAttributedContent: NSAttributedString
        if let project = file.project {
            // Special handling for empty text (model-based)
            if attributedContent.length == 0 {
                print("📝 Text is empty - creating attributed string with style: \(style)")
                
                let typingAttrs = TextFormatter.getTypingAttributes(
                    forStyleNamed: style.rawValue,
                    project: project,
                    context: modelContext
                )
                let styledEmptyString = NSAttributedString(string: "", attributes: typingAttrs)
                
                attributedContent = styledEmptyString
                currentParagraphStyle = style
                
                textViewCoordinator.modifyTypingAttributes { textView in
                    textView.typingAttributes = typingAttrs
                }
                
                print("📝 Empty text styled with model - picker should update")
                return
            }
            
            // Store before state for undo
            let beforeContent = attributedContent
            
            // Apply the style using model-based TextFormatter
            newAttributedContent = TextFormatter.applyStyle(
                named: style.rawValue,
                to: attributedContent,
                range: selectedRange,
                project: project,
                context: modelContext
            )
            
            print("📝 Paragraph style applied successfully (model-based)")
            
            // Log what we got back
            #if DEBUG
            if newAttributedContent.length > 0 && selectedRange.location < newAttributedContent.length {
                let attrs = newAttributedContent.attributes(at: selectedRange.location, effectiveRange: nil)
                print("📝 New attributes at selection after applying style:")
                if let color = attrs[.foregroundColor] as? UIColor {
                    print("   Color: \(color.toHex() ?? "unknown")")
                }
                if let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle {
                    print("   Alignment: \(paragraphStyle.alignment.rawValue)")
                }
                if let textStyle = attrs[.textStyle] as? String {
                    print("   TextStyle attribute: \(textStyle)")
                }
            }
            #endif
            
            // Update local state immediately for instant UI feedback
            attributedContent = newAttributedContent
            currentParagraphStyle = style
            
            // Update typing attributes
            let typingAttrs = TextFormatter.getTypingAttributes(
                forStyleNamed: style.rawValue,
                project: project,
                context: modelContext
            )
            textViewCoordinator.modifyTypingAttributes { textView in
                textView.typingAttributes = typingAttrs
            }
            
            print("📝 Updated local state with styled content (model-based)")
            
            // Create formatting command for undo/redo
            let command = FormatApplyCommand(
                description: "Paragraph Style",
                range: selectedRange,
                beforeContent: beforeContent,
                afterContent: newAttributedContent,
                targetFile: file
            )
            
            undoManager.execute(command)
            print("📝 Paragraph style command added to undo stack")
            print("📝 ========== APPLY PARAGRAPH STYLE END ==========")
            restoreKeyboardFocus()
            return
        }
        
        // Fallback to direct UIFont.TextStyle (for files not in a project)
        // Special handling for empty text
        if attributedContent.length == 0 {
            print("📝 Text is empty - creating attributed string with style: \(style)")
            
            // Create an empty attributed string with the style attributes
            // This allows the style picker to detect the current style
            let typingAttrs = TextFormatter.getTypingAttributes(for: style)
            let styledEmptyString = NSAttributedString(string: "", attributes: typingAttrs)
            
            // Update the attributed content
            attributedContent = styledEmptyString
            
            // Update the current style state
            currentParagraphStyle = style
            
            // Also set typing attributes for when user starts typing
            textViewCoordinator.modifyTypingAttributes { textView in
                textView.typingAttributes = typingAttrs
            }
            
            print("📝 Empty text styled - picker should update")
            return
        }
        
        // Store before state for undo
        let beforeContent = attributedContent
        
        // Apply the style using TextFormatter
        newAttributedContent = TextFormatter.applyStyle(style, to: attributedContent, range: selectedRange)
        
        print("📝 Paragraph style applied successfully")
        
        // Update local state immediately for instant UI feedback
        attributedContent = newAttributedContent
        
        // Update the current style state
        currentParagraphStyle = style
        
        // Also update typing attributes so new text in this paragraph uses the style
        // This is especially important for empty paragraphs or when cursor is at paragraph end
        textViewCoordinator.modifyTypingAttributes { textView in
            textView.typingAttributes = TextFormatter.getTypingAttributes(for: style)
        }
        
        print("📝 Updated local state with styled content")
        
        // Create formatting command for undo/redo
        let command = FormatApplyCommand(
            description: "Paragraph Style",
            range: selectedRange,
            beforeContent: beforeContent,
            afterContent: newAttributedContent,
            targetFile: file
        )
        
        // Execute command through undo manager
        undoManager.execute(command)
        
        print("📝 Paragraph style command added to undo stack")
        
        // Restore keyboard focus after applying style
        restoreKeyboardFocus()
    }
    
    // MARK: - Version Management

    
    private func handleVersionAction(_ action: VersionAction) {
        switch action {
        case .previous:
            file.changeVersion(by: -1)
            loadCurrentVersion()
        case .next:
            file.changeVersion(by: 1)
            loadCurrentVersion()
        case .add:
            file.addVersion()
            loadCurrentVersion()
            saveChanges()
        case .delete:
            presentDeleteAlert = true
        }
    }
    
    private func loadCurrentVersion() {
        var newAttributedContent: NSAttributedString
        
        if let versionContent = file.currentVersion?.attributedContent {
            // Version has saved content - use it
            newAttributedContent = versionContent
            print("📝 loadCurrentVersion: Loaded existing content, length: \(versionContent.length)")
        } else {
            // New/empty version - initialize with Body style from project stylesheet
            if let project = file.project {
                let bodyAttrs = TextFormatter.getTypingAttributes(
                    forStyleNamed: UIFont.TextStyle.body.rawValue,
                    project: project,
                    context: modelContext
                )
                
                // Debug: Log what we're initializing with
                print("📝 loadCurrentVersion: Initializing with Body style from stylesheet '\(project.styleSheet?.name ?? "none")'")
                for (key, value) in bodyAttrs {
                    if key == .font {
                        let font = value as? UIFont
                        print("  - font: \(font?.fontName ?? "nil") \(font?.pointSize ?? 0)pt")
                    } else if key == .foregroundColor {
                        let color = value as? UIColor
                        print("  - foregroundColor: \(color?.toHex() ?? "nil")")
                    } else if key == .textStyle {
                        print("  - textStyle: \(value)")
                    }
                }
                
                newAttributedContent = NSAttributedString(string: "", attributes: bodyAttrs)
                print("📝 loadCurrentVersion: Created empty attributed string with Body style")
            } else {
                // Fallback if no project (shouldn't happen)
                newAttributedContent = NSAttributedString(
                    string: "",
                    attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
                )
                print("⚠️ loadCurrentVersion: No project found, using system body font")
            }
        }
        
        attributedContent = newAttributedContent
        previousContent = newAttributedContent.string
        selectedRange = NSRange(location: newAttributedContent.string.count, length: 0)
        
        forceRefresh.toggle()
        refreshTrigger = UUID()
    }
    
    // MARK: - Persistence
    
    private func saveUndoState() {
        undoManager.flushTypingBuffer()
        file.saveUndoState(undoManager)
        saveChanges()
    }
    
    private func saveChanges() {
        // Save the current attributed content to the model
        // The attributedContent setter automatically syncs plain text content
        file.currentVersion?.attributedContent = attributedContent
        file.modifiedDate = Date()
        
        do {
            try modelContext.save()
            print("💾 Saved attributed content on file close")
        } catch {
            print("Error saving context: \(error)")
        }
    }
    
    // MARK: - Keyboard Management
    
    /// Restore keyboard focus after undo/redo button taps
    /// SwiftUI buttons dismiss keyboard, so we restore it with a brief flicker
    private func restoreKeyboardFocus() {
        DispatchQueue.main.async {
            self.textViewCoordinator.textView?.becomeFirstResponder()
        }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Project.self, File.self, configurations: config)
        let context = container.mainContext
        
        let project = Project(name: "Sample Project", type: .novel)
        context.insert(project)
        
        let file = File(name: "Chapter 1", content: "Once upon a time...")
        context.insert(file)
        
        return NavigationStack {
            FileEditView(file: file)
                .modelContainer(container)
        }
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
