import SwiftUI
import SwiftData
import ToolbarSUI
import UniformTypeIdentifiers
import PhotosUI

struct FileEditView: View {
    let file: TextFile
    
    @State private var attributedContent: NSAttributedString
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var previousContent: String = ""
    @State private var presentDeleteAlert = false
    @State private var isPerformingUndoRedo = false
    @State private var refreshTrigger = UUID()
    @State private var forceRefresh = false
    @State private var showStylePicker = false
    @State private var showImageEditor = false
    @State private var showLockedVersionWarning = false
    @State private var attemptedEdit = false
    @State private var imageToEdit: ImageAttachment?
    @State private var lastImageInsertTime: Date?
    @State private var selectedImage: ImageAttachment?
    @State private var selectedImageFrame: CGRect = .zero
    @State private var selectedImagePosition: Int = -1
    @State private var textViewInitialized = false
    @State private var currentParagraphStyle: UIFont.TextStyle? = .body
    @State private var documentPicker: UIDocumentPickerViewController? // Strong reference for Mac Catalyst
    @State private var showFileImporter = false // For SwiftUI file importer
    @State private var showDocumentPicker = false // For UIViewControllerRepresentable picker
    @State private var showImageSourcePicker = false // Show Photos vs Files chooser
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
    
    init(file: TextFile) {
        self.file = file
        
        // Initialize with empty content - will load in onAppear to avoid repeated init calls
        let emptyAttributed = NSAttributedString(
            string: "",
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )
        
        _attributedContent = State(initialValue: emptyAttributed)
        _previousContent = State(initialValue: "")
        _selectedRange = State(initialValue: NSRange(location: 0, length: 0))
        
        // Try to restore undo manager or create new one
        if let restoredManager = file.restoreUndoState() {
            _undoManager = StateObject(wrappedValue: restoredManager)
        } else {
            let newManager = TextFileUndoManager(file: file)
            _undoManager = StateObject(wrappedValue: newManager)
        }
    }
    
    // MARK: - Body Components
    
    private func versionToolbar() -> some View {
        let versionItems: [SUIToolbarItem] = [
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
        
        return ToolbarView(
            label: file.versionLabel(),
            items: versionItems
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
    }
    
    private func textEditorSection() -> some View {
        ZStack(alignment: .topLeading) {
            if forceRefresh {
                FormattedTextEditor(
                    attributedText: $attributedContent,
                    selectedRange: $selectedRange,
                    textViewCoordinator: textViewCoordinator,
                    onTextChange: { newText in
                        handleAttributedTextChange(newText)
                    },
                    onImageTapped: { attachment, frame, position in
                        handleImageTap(attachment: attachment, frame: frame, position: position)
                    },
                    onClearImageSelection: {
                        selectedImage = nil
                        selectedImageFrame = .zero
                        selectedImagePosition = -1
                    }
                )
                .id(refreshTrigger)
                .onAppear {
                    textViewInitialized = true
                }
            } else {
                FormattedTextEditor(
                    attributedText: $attributedContent,
                    selectedRange: $selectedRange,
                    textViewCoordinator: textViewCoordinator,
                    onTextChange: { newText in
                        handleAttributedTextChange(newText)
                    },
                    onImageTapped: { attachment, frame, position in
                        handleImageTap(attachment: attachment, frame: frame, position: position)
                    },
                    onClearImageSelection: {
                        selectedImage = nil
                        selectedImageFrame = .zero
                        selectedImagePosition = -1
                    }
                )
                .id(refreshTrigger)
                .onAppear {
                    textViewInitialized = true
                }
            }
        }
    }
    
    @ViewBuilder
    private func formattingToolbar() -> some View {
        // Show toolbar once text view has been initialized
        // Don't make it conditional on textView being non-nil because that can
        // cause it to flicker during view updates
        if textViewInitialized, let textView = textViewCoordinator.textView {
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
                case .imageStyle:
                    // Show image style editor for selected image
                    if let image = selectedImage {
                        print("🖼️ imageStyle: selectedImage.imageData = \(image.imageData?.count ?? 0) bytes")
                        print("🖼️ imageStyle: selectedImage.image = \(image.image != nil)")
                        if let imgData = image.imageData {
                            print("🖼️ imageStyle: Can create UIImage from imageData: \(UIImage(data: imgData) != nil)")
                        }
                        imageToEdit = image
                    }
                case .insert:
                    showImagePicker()
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
            Color(UIColor.secondarySystemBackground)
                .frame(height: 44)
                .ignoresSafeArea(edges: .horizontal)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            versionToolbar()
            textEditorSection()
            formattingToolbar()
        }
        .navigationTitle(file.name)
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
                }
            }
        }
        .confirmationDialog(
            "version.locked.warning.title",
            isPresented: $showLockedVersionWarning,
            titleVisibility: .visible
        ) {
            Button("version.locked.edit.anyway") {
                attemptedEdit = true
                showLockedVersionWarning = false
                // Show keyboard after user confirms
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.textViewCoordinator.textView?.becomeFirstResponder()
                }
            }
            Button("button.cancel", role: .cancel) {
                showLockedVersionWarning = false
                // User cancelled - go back
                DispatchQueue.main.async {
                    dismiss()
                }
            }
        } message: {
            if let lockReason = file.currentVersion?.lockReason {
                Text(lockReason)
            } else {
                Text("version.locked.warning.message")
            }
        }
        .confirmationDialog(
            "Choose Image Source",
            isPresented: $showImageSourcePicker,
            titleVisibility: .visible
        ) {
            Button("Photos") {
                showPhotosPickerFromCoordinator()
            }
            Button("Files") {
                showDocumentPicker = true
            }
            Button("button.cancel", role: .cancel) {
                showImageSourcePicker = false
            }
        } message: {
            Text("Select where to choose your image from")
        }
        .onDisappear {
            // Auto-save when leaving the editor (back button, etc.)
            saveChanges()
            saveUndoState()
        }
        .onAppear {
            // Always jump to latest version when opening a file
            file.selectLatestVersion()
            
            // Check if version is locked before allowing editing
            if file.currentVersion?.isLocked == true {
                showLockedVersionWarning = true
            }
            
            // Load content from database on first appearance
            // We initialize with empty content in init() to avoid repeated decoding
            // during SwiftUI view updates, then load the real content here once
            if attributedContent.length == 0, let savedContent = file.currentVersion?.attributedContent {
                print("📂 onAppear: Initial load of content, length: \(savedContent.length)")
                attributedContent = savedContent
                previousContent = savedContent.string
                
                // Position cursor at end of text
                let textLength = savedContent.length
                selectedRange = NSRange(location: textLength, length: 0)
            }
            
            // Show keyboard/cursor when opening file (only if not locked)
            if file.currentVersion?.isLocked != true {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.textViewCoordinator.textView?.becomeFirstResponder()
                }
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ImageWasPasted"))) { _ in
            print("🖼️ Received ImageWasPasted notification - updating lastImageInsertTime")
            lastImageInsertTime = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProjectStyleSheetChanged"))) { notification in
            print("📋 ========== ProjectStyleSheetChanged NOTIFICATION ===========")
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
        .sheet(item: $imageToEdit) { imageAttachment in
            let imageData = imageAttachment.imageData ?? imageAttachment.image?.pngData()
            
            ImageStyleEditorView(
                imageData: imageData,
                scale: imageAttachment.scale,
                alignment: imageAttachment.alignment,
                hasCaption: imageAttachment.hasCaption,
                captionText: imageAttachment.captionText ?? "",
                captionStyle: imageAttachment.captionStyle ?? "caption1",
                availableCaptionStyles: ["caption1", "caption2", "footnote"],
                onApply: { imageData, scale, alignment, hasCaption, captionText, captionStyle in
                    updateImage(
                        attachment: imageAttachment,
                        scale: scale,
                        alignment: alignment,
                        hasCaption: hasCaption,
                        captionText: captionText,
                        captionStyle: captionStyle
                    )
                    imageToEdit = nil
                }
            )
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            print("🖼️ File importer completed")
            switch result {
            case .success(let urls):
                print("🖼️ File importer success with \(urls.count) URLs")
                guard let url = urls.first else {
                    print("❌ No URL in file importer result")
                    return
                }
                print("🖼️ File importer selected: \(url.lastPathComponent)")
                print("🖼️ File path: \(url.path)")
                handleImageSelection(url: url)
            case .failure(let error):
                print("❌ File importer error: \(error.localizedDescription)")
            }
        }
        .background(
            DocumentPickerView(
                isPresented: $showDocumentPicker,
                contentTypes: [.image]
            ) { url in
                print("🖼️ Document picker view selected: \(url.lastPathComponent)")
                handleImageSelection(url: url)
            }
        )
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
        
        // Check if version is locked
        if file.currentVersion?.isLocked == true, !attemptedEdit {
            // Show warning on first edit attempt
            showLockedVersionWarning = true
            // Restore previous content
            if let currentVersion = file.currentVersion {
                attributedContent = currentVersion.attributedContent ?? NSAttributedString(string: "")
            }
            return
        }
        
        #if DEBUG
        print("🔄 Previous: '\(previousContent)'")
        print("🔄 New: '\(newContent)'")
        #endif
        
        // Only register change if content actually changed
        guard newContent != previousContent else {
            print("🔄 Content unchanged - skipping")
            return
        }
        
        // Clear image selection when text changes
        selectedImage = nil
        selectedImageFrame = .zero
        selectedImagePosition = -1
        
        // Restore cursor visibility
        if let textView = textViewCoordinator.textView {
            textView.tintColor = .label
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
    
    // MARK: - Image Selection
    
    private func handleImageTap(attachment: ImageAttachment, frame: CGRect, position: Int) {
        print("🖼️ ========== IMAGE TAP HANDLER ==========")
        print("🖼️ Image selected at position \(position)")
        print("🖼️ Frame: \(frame)")
        print("🖼️ Attachment: \(attachment)")
        
        selectedImage = attachment
        selectedImageFrame = frame
        selectedImagePosition = position
        
        print("🖼️ State updated - selectedImage: \(selectedImage != nil)")
        print("🖼️ State updated - selectedImageFrame: \(selectedImageFrame)")
        
        // Select the image character so backspace/delete will remove it
        if let textView = textViewCoordinator.textView {
            textView.selectedRange = NSRange(location: position, length: 1)
            textView.tintColor = .clear // Hide cursor when image is selected
            print("🖼️ Cursor hidden, range set to {\(position), 1}")
        } else {
            print("⚠️ No textView available!")
        }
        print("🖼️ ========== END ==========")
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
    ///
    /// **Design Note**: This function only reapplies TEXT styles from the stylesheet.
    /// Image properties (scale, alignment) are stored per-instance on ImageAttachment objects
    /// and are NOT updated when stylesheet ImageStyles change. This means:
    /// - Changing ImageStyle in stylesheet affects only NEW images
    /// - Existing images retain their custom scale/alignment settings
    /// - Similar to how manually bolded text keeps its formatting even if Body style changes
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
            } else {
                print("📝 New color: NONE (will use system default)")
            }
            
            // Log what color is CURRENTLY in the text before we change it
            if range.location < mutableText.length {
                let oldAttrs = mutableText.attributes(at: range.location, effectiveRange: nil)
                if let oldColor = oldAttrs[.foregroundColor] as? UIColor {
                    print("   🔍 OLD color in document: \(oldColor.toHex() ?? "unknown")")
                } else {
                    print("   🔍 OLD color in document: NONE")
                }
            }
            
            // Check if this range contains an image attachment
            var attachmentPosition: Int? = nil
            var preservedParagraphStyle: NSParagraphStyle?
            
            // Check EVERY position in the range for attachments
            for pos in range.location..<min(range.location + range.length, mutableText.length) {
                let existingAttrs = mutableText.attributes(at: pos, effectiveRange: nil)
                if existingAttrs[.attachment] != nil {
                    attachmentPosition = pos
                    // Preserve the attachment's paragraph style
                    preservedParagraphStyle = existingAttrs[.paragraphStyle] as? NSParagraphStyle
                    print("   🖼️ Found attachment at position \(pos) within range {\(range.location), \(range.length)}")
                    break
                }
            }
            
            // Apply attributes based on whether we have an attachment
            print("✅ Applying new attributes to range {\(range.location), \(range.length)}")
            if let attachmentPos = attachmentPosition {
                print("   🖼️ Range contains attachment at position \(attachmentPos) - using selective application")
                
                // Apply text attributes (without paragraph style) to the entire range
                var attributesToAdd = newAttributes
                attributesToAdd.removeValue(forKey: .paragraphStyle)
                mutableText.addAttributes(attributesToAdd, range: range)
                
                // Apply default left-aligned paragraph style to text portions
                let defaultParagraphStyle = NSMutableParagraphStyle()
                defaultParagraphStyle.alignment = .left
                
                // Apply to text BEFORE the image
                if attachmentPos > range.location {
                    let beforeRange = NSRange(location: range.location, length: attachmentPos - range.location)
                    mutableText.addAttribute(.paragraphStyle, value: defaultParagraphStyle, range: beforeRange)
                    print("   📝 Applied left alignment to text before image: range {\(beforeRange.location), \(beforeRange.length)}")
                }
                
                // Apply to text AFTER the image
                if attachmentPos < range.location + range.length - 1 {
                    let afterStart = attachmentPos + 1
                    let afterLength = (range.location + range.length) - afterStart
                    if afterLength > 0 {
                        let afterRange = NSRange(location: afterStart, length: afterLength)
                        mutableText.addAttribute(.paragraphStyle, value: defaultParagraphStyle, range: afterRange)
                        print("   📝 Applied left alignment to text after image: range {\(afterRange.location), \(afterRange.length)}")
                    }
                }
                
                // Preserve the image's original paragraph style
                if let paragraphStyle = preservedParagraphStyle {
                    mutableText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: attachmentPos, length: 1))
                    print("   🖼️ Preserved image paragraph alignment at position \(attachmentPos)")
                }
            } else {
                // No attachment - apply all attributes including paragraph style normally
                mutableText.setAttributes(newAttributes, range: range)
            }
            
            // Log what color is ACTUALLY in the text after we set it
            if range.location < mutableText.length {
                let finalAttrs = mutableText.attributes(at: range.location, effectiveRange: nil)
                if let finalColor = finalAttrs[.foregroundColor] as? UIColor {
                    print("   🔍 FINAL color after setAttributes: \(finalColor.toHex() ?? "unknown")")
                } else {
                    print("   🔍 FINAL color after setAttributes: NONE ✅ (will adapt!)")
                }
            }
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
    
    // MARK: - Image Insertion
    
    private func showImagePicker() {
        print("🖼️ showImagePicker() called")
        #if targetEnvironment(macCatalyst)
        // On Mac, go directly to file picker
        showDocumentPicker = true
        #else
        // On iPhone/iPad, let user choose between Photos and Files
        showImageSourcePicker = true
        #endif
    }
    
    private func showPhotosPickerFromCoordinator() {
        print("📸 showPhotosPickerFromCoordinator() called")
        
        // Set up the callback for when an image is picked
        textViewCoordinator.onImagePicked = { url in
            print("📸 Coordinator callback received with URL: \(url.lastPathComponent)")
            self.handleImageSelection(url: url)
        }
        
        // Create PHPicker configuration
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        
        // Create the picker
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = textViewCoordinator
        
        // Store strong reference in coordinator to prevent deallocation
        textViewCoordinator.phPicker = picker
        
        // Present the picker
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            var topController = rootViewController
            while let presented = topController.presentedViewController {
                topController = presented
            }
            print("📸 Presenting PHPicker")
            topController.present(picker, animated: true)
        } else {
            print("❌ Could not find root view controller to present PHPicker")
        }
    }
    
    private func showIOSImagePicker() {
        print("🖼️ Using iOS UIDocumentPickerViewController")
        
        // Create a document picker for images
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.image])
        picker.allowsMultipleSelection = false
        picker.delegate = textViewCoordinator
        
        // Store strong reference in coordinator to prevent deallocation (needed for Mac Catalyst)
        textViewCoordinator.documentPicker = picker
        
        // Configure presentation style
        // On Mac Catalyst, sheetPresentationController with detents can cause immediate dismissal
        #if targetEnvironment(macCatalyst)
        picker.modalPresentationStyle = .formSheet
        #else
        picker.modalPresentationStyle = .pageSheet
        if let sheet = picker.sheetPresentationController {
            sheet.prefersGrabberVisible = true
            sheet.detents = [.medium(), .large()]
        }
        #endif
        
        print("🖼️ Document picker created, setting callback...")
        
        // Store reference for when document is picked
        textViewCoordinator.onImagePicked = { url in
            print("🖼️ onImagePicked callback triggered")
            self.handleImageSelection(url: url)
            // Clear references after selection
            self.textViewCoordinator.documentPicker = nil
            self.documentPicker = nil
        }
        
        // Present the picker
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            var topController = rootViewController
            while let presented = topController.presentedViewController {
                topController = presented
            }
            print("🖼️ Presenting document picker...")
            topController.present(picker, animated: true)
        } else {
            print("❌ Failed to find root view controller")
        }
    }
    
    private func handleImageSelection(url: URL) {
        print("🖼️ Image selected: \(url.lastPathComponent)")
        
        // Check if this is a temp file (from PHPicker) or needs security scoping (from file picker)
        let isTempFile = url.path.starts(with: FileManager.default.temporaryDirectory.path)
        
        // Only use security-scoped resources for non-temp files (file picker)
        let needsSecurityScope = !isTempFile
        
        if needsSecurityScope {
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ Failed to access security-scoped resource")
                return
            }
        }
        
        defer {
            if needsSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let imageData = try Data(contentsOf: url)
            print("🖼️ Image data loaded: \(imageData.count) bytes")
            
            // Compress the image
            if let compressedData = compressImageData(imageData) {
                print("🖼️ Image compressed: \(compressedData.count) bytes")
                
                // Insert image immediately with default settings from stylesheet
                DispatchQueue.main.async {
                    // Get default image style from project's stylesheet
                    // These values serve as INITIAL settings for the new image
                    // Once inserted, the image's properties can be customized independently
                    var scale: CGFloat = 1.0
                    var alignment: ImageAttachment.ImageAlignment = .center
                    var hasCaption = false
                    var captionStyle = "caption1"
                    
                    if let project = self.file.project,
                       let stylesheet = project.styleSheet,
                       let imageStyles = stylesheet.imageStyles,
                       let defaultStyle = imageStyles.first(where: { $0.name == "default" }) {
                        scale = defaultStyle.defaultScale
                        alignment = defaultStyle.defaultAlignment
                        hasCaption = defaultStyle.hasCaptionByDefault
                        captionStyle = defaultStyle.defaultCaptionStyle
                        print("🖼️ Using image style '\(defaultStyle.displayName)': scale=\(scale), alignment=\(alignment.rawValue)")
                    } else {
                        print("🖼️ Using hardcoded defaults: scale=1.0, alignment=center")
                    }
                    
                    print("🖼️ Inserting image with settings from stylesheet")
                    self.insertImage(
                        imageData: compressedData,
                        scale: scale,
                        alignment: alignment,
                        hasCaption: hasCaption,
                        captionText: "",
                        captionStyle: captionStyle
                    )
                }
            } else {
                print("❌ Failed to compress image")
            }
        } catch {
            print("❌ Error loading image: \(error)")
        }
    }
    
    private func compressImageData(_ data: Data) -> Data? {
        guard let uiImage = UIImage(data: data) else { return nil }
        return ImageAttachment.compressImage(uiImage)
    }
    
    private func insertImage(
        imageData: Data?,
        scale: CGFloat,
        alignment: ImageAttachment.ImageAlignment,
        hasCaption: Bool,
        captionText: String,
        captionStyle: String
    ) {
        guard let imageData = imageData else { return }
        
        // Get the insertion point
        let insertionPoint = selectedRange.location
        
        // Create and execute undo command
        let command = InsertImageCommand(
            position: insertionPoint,
            imageData: imageData,
            scale: scale,
            alignment: alignment,
            hasCaption: hasCaption,
            captionText: captionText,
            captionStyle: captionStyle,
            targetFile: file
        )
        
        undoManager.execute(command)
        
        // Mark the time of insertion to prevent immediate editor popup
        lastImageInsertTime = Date()
        
        // Update local state to reflect the change
        let newContent = file.currentVersion?.attributedContent ?? NSAttributedString()
        print("🖼️ Before update - attributedContent length: \(attributedContent.length)")
        print("🖼️ After command - newContent length: \(newContent.length)")
        
        // Check if there's an attachment at the insertion point
        if newContent.length > insertionPoint {
            let attrs = newContent.attributes(at: insertionPoint, effectiveRange: nil)
            if let attachment = attrs[.attachment] as? NSTextAttachment {
                print("🖼️ Found attachment at position \(insertionPoint): \(type(of: attachment))")
            } else {
                print("⚠️ NO attachment found at position \(insertionPoint)")
                print("⚠️ Character at \(insertionPoint): '\(newContent.string[newContent.string.index(newContent.string.startIndex, offsetBy: insertionPoint)])'")
            }
        }
        
        attributedContent = newContent
        
        // Move cursor after the inserted image
        selectedRange = NSRange(location: insertionPoint + 1, length: 0)
        
        print("🖼️ Image inserted at position \(insertionPoint) with scale \(scale)")
        
        // Force refresh to ensure UI updates
        forceRefresh.toggle()
        refreshTrigger = UUID()
        
        // Restore keyboard focus after a slight delay to allow UI to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            restoreKeyboardFocus()
        }
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
        
        // PERFORMANCE: Access attributedContent once and cache it
        // The getter deserializes RTF data which is expensive - avoid repeated calls
        guard let currentVersion = file.currentVersion else {
            // No version available - shouldn't happen but handle gracefully
            newAttributedContent = NSAttributedString(
                string: "",
                attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
            )
            print("⚠️ loadCurrentVersion: No current version found")
            attributedContent = newAttributedContent
            previousContent = ""
            selectedRange = NSRange(location: 0, length: 0)
            forceRefresh.toggle()
            refreshTrigger = UUID()
            return
        }
        
        if let versionContent = currentVersion.attributedContent {
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
    
    // MARK: - Image Editing
    
    /// Update an existing image attachment with new properties
    private func updateImage(
        attachment: ImageAttachment,
        scale: CGFloat,
        alignment: ImageAttachment.ImageAlignment,
        hasCaption: Bool,
        captionText: String,
        captionStyle: String
    ) {
        print("🖼️ Updating image: scale=\(scale), alignment=\(alignment.rawValue)")
        
        // Find the attachment in the content
        guard let position = findAttachmentPosition(attachment) else {
            print("❌ Could not find attachment in content")
            return
        }
        
        // Update the attachment properties
        attachment.scale = scale
        attachment.alignment = alignment
        attachment.hasCaption = hasCaption
        attachment.captionText = captionText
        attachment.captionStyle = captionStyle
        
        // Update the paragraph alignment to match image alignment
        let mutableContent = NSMutableAttributedString(attributedString: attributedContent)
        let paragraphStyle = NSMutableParagraphStyle()
        switch alignment {
        case .left:
            paragraphStyle.alignment = .left
        case .center:
            paragraphStyle.alignment = .center
        case .right:
            paragraphStyle.alignment = .right
        case .inline:
            paragraphStyle.alignment = .natural
        }
        
        mutableContent.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: position, length: 1))
        
        // Update the content
        attributedContent = mutableContent
        file.currentVersion?.attributedContent = mutableContent
        file.modifiedDate = Date()
        
        do {
            try modelContext.save()
            print("✅ Image updated and saved")
        } catch {
            print("❌ Error saving image update: \(error)")
        }
        
        // Trigger view refresh to show updated image
        refreshTrigger = UUID()
        
        // Keep the image selected and update the selection border to match new size
        // The selection border will be recalculated when the text view updates
        selectedImage = attachment
        
        // Close the editor
        imageToEdit = nil
    }
    
    /// Find the position of an attachment in the attributed content
    private func findAttachmentPosition(_ targetAttachment: ImageAttachment) -> Int? {
        var position: Int?
        attributedContent.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedContent.length)) { value, range, stop in
            if let attachment = value as? ImageAttachment,
               attachment.imageID == targetAttachment.imageID {
                position = range.location
                stop.pointee = true
            }
        }
        return position
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Project.self, Folder.self, TextFile.self, configurations: config)
        let context = container.mainContext
        
        let project = Project(name: "Sample Project", type: .novel)
        context.insert(project)
        
        let folder = Folder(name: "Draft", project: project)
        context.insert(folder)
        
        let file = TextFile(name: "Chapter 1", initialContent: "Once upon a time...", parentFolder: folder)
        context.insert(file)
        
        return NavigationStack {
            FileEditView(file: file)
                .modelContainer(container)
        }
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
