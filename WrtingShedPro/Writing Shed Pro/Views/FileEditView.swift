import SwiftUI
import SwiftData
import ToolbarSUI
import UniformTypeIdentifiers
import PhotosUI

struct FileEditView: View {
    @Bindable var file: TextFile
    
    // Track version index changes explicitly for toolbar updates
    @State private var currentVersionIndex: Int = 0
    
    @State private var attributedContent: NSAttributedString
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var previousContent: String = ""
    @State private var previousAttributedContent: NSAttributedString?  // Track for undo without expensive DB fetch
    @State private var saveDebounceTimer: Timer?  // Debounce saves to reduce I/O
    @State private var presentDeleteAlert = false
    @State private var isPerformingUndoRedo = false
    @State private var refreshTrigger = UUID()
    @State private var forceRefresh = false
    @State private var showStylePicker = false
    @State private var showImageEditor = false
    @State private var showLockedVersionWarning = false
    @State private var attemptedEdit = false
    @State private var showNotesEditor = false
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
    @State private var isPaginationMode = false // Toggle between edit and pagination preview modes
    @State private var undoManager: TextFileUndoManager
    @StateObject private var textViewCoordinator = TextViewCoordinator()
    
    // Feature 014: Comments
    @State private var showCommentsList = false
    @State private var showNewCommentDialog = false
    @State private var newCommentText: String = ""
    @State private var selectedCommentForDetail: CommentModel?
    
    // Feature 015: Footnotes
    @State private var showFootnotesList = false
    @State private var showNewFootnoteDialog = false
    @State private var newFootnoteText: String = ""
    @State private var selectedFootnoteForDetail: FootnoteModel?
    
    // Feature 020: Printing
    @State private var showPrintError = false
    @State private var printErrorMessage = ""
    
    // Feature 017: Search and Replace
    @State private var showSearchBar = false
    @State private var searchManager = InEditorSearchManager()
    @State private var isSimplifiedSearchMode = false  // True when opened from multi-file search with replace
    @State private var isFromMultiFileSearch = false  // True when opened from any multi-file search
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SearchContext.self) private var searchContext: SearchContext?
    
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
            _undoManager = State(initialValue: restoredManager)
        } else {
            let newManager = TextFileUndoManager(file: file)
            _undoManager = State(initialValue: newManager)
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
        .zIndex(100)  // Ensure toolbar is above any overlays
    }
    
    private func textEditorSection() -> some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .phone {
                // iPhone: Scale view transform to show more content in less space
                GeometryReader { geometry in
                    let scale: CGFloat = 0.6
                    let inverseScale = 1.0 / scale
                    
                    ScrollView {
                        if forceRefresh {
                            FormattedTextEditor(
                                attributedText: $attributedContent,
                                selectedRange: $selectedRange,
                                textViewCoordinator: textViewCoordinator,
                                project: file.project,
                                textContainerInset: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8),
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
                                },
                                onCommentTapped: { attachment, position in
                                    handleCommentTap(attachment: attachment, position: position)
                                },
                                onFootnoteTapped: { attachment, position in
                                    handleFootnoteTap(attachment: attachment, position: position)
                                }
                            )
                            .frame(width: geometry.size.width * inverseScale, height: geometry.size.height * inverseScale)
                            .scaleEffect(scale, anchor: .topLeading)
                            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                            .id(refreshTrigger)
                            .onAppear {
                                textViewInitialized = true
                            }
                        } else {
                            FormattedTextEditor(
                                attributedText: $attributedContent,
                                selectedRange: $selectedRange,
                                textViewCoordinator: textViewCoordinator,
                                project: file.project,
                                textContainerInset: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8),
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
                                },
                                onCommentTapped: { attachment, position in
                                    handleCommentTap(attachment: attachment, position: position)
                                },
                                onFootnoteTapped: { attachment, position in
                                    handleFootnoteTap(attachment: attachment, position: position)
                                }
                            )
                            .frame(width: geometry.size.width * inverseScale, height: geometry.size.height * inverseScale)
                            .scaleEffect(scale, anchor: .topLeading)
                            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                            .id(refreshTrigger)
                            .onAppear {
                                textViewInitialized = true
                            }
                        }
                    }
                }
            } else {
                // iPad: Use GeometryReader for percentage-based padding
                GeometryReader { geometry in
                    ZStack(alignment: .topLeading) {
                        if forceRefresh {
                            FormattedTextEditor(
                                attributedText: $attributedContent,
                                selectedRange: $selectedRange,
                                textViewCoordinator: textViewCoordinator,
                                project: file.project,
                                textContainerInset: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8),
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
                                },
                                onCommentTapped: { attachment, position in
                                    handleCommentTap(attachment: attachment, position: position)
                                },
                                onFootnoteTapped: { attachment, position in
                                    handleFootnoteTap(attachment: attachment, position: position)
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
                                project: file.project,
                                textContainerInset: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8),
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
                                },
                                onCommentTapped: { attachment, position in
                                    handleCommentTap(attachment: attachment, position: position)
                                },
                                onFootnoteTapped: { attachment, position in
                                    handleFootnoteTap(attachment: attachment, position: position)
                                }
                            )
                            .id(refreshTrigger)
                            .onAppear {
                                textViewInitialized = true
                            }
                        }
                    }
                    .padding(.horizontal, geometry.size.width * 0.05)
                }
            }
        }
    }
    
    @ViewBuilder
    private func formattingToolbar() -> some View {
        // Pure SwiftUI toolbar that respects iOS 26.2+ button styling
        SwiftUIFormattingToolbar(
            onFormatAction: { action in
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
                        imageToEdit = image
                    }
                case .notes:
                    showNotesEditor = true
                case .toggleKeyboard:
                    if let textView = textViewCoordinator.textView {
                        if textView.isFirstResponder {
                            textView.resignFirstResponder()
                        } else {
                            textView.becomeFirstResponder()
                        }
                    }
                case .numberedList:
                    applyNumberFormat(.decimal)
                case .bulletedList:
                    applyNumberFormat(.bulletSymbols)
                }
            },
            hasSelectedImage: selectedImage != nil
        )
    }
    
    @ViewBuilder
    private func paginationSection() -> some View {
        if let project = file.project {
            PaginatedDocumentView(
                textFile: file,
                project: project
            )
            .transition(.opacity)
        } else {
            ContentUnavailableView(
                "fileEdit.noPageSetup.title",
                systemImage: "doc.text",
                description: Text("fileEdit.noPageSetup.description")
            )
        }
    }
    
    @ViewBuilder
    private func navigationBarButtons() -> some View {
        HStack(spacing: 16) {
            // Search button (only in edit mode and not opened from multi-file search)
            if !isPaginationMode && !isFromMultiFileSearch {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSearchBar.toggle()
                        if showSearchBar, let textView = textViewCoordinator.textView {
                            // Connect search manager to text view when opening
                            searchManager.connect(to: textView)
                            // Also connect to the custom undo manager so Replace All can clear it
                            searchManager.customUndoManager = undoManager
                        } else if !showSearchBar {
                            // Disconnect when closing
                            searchManager.disconnect()
                        }
                    }
                }) {
                    Image(systemName: showSearchBar ? "magnifyingglass.circle.fill" : "magnifyingglass")
                }
                .accessibilityLabel("Find and Replace")
                .keyboardShortcut("f", modifiers: .command)
            }
            
            // Pagination mode toggle (always available - uses global page setup)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isPaginationMode.toggle()
                }
            }) {
                Image(systemName: isPaginationMode ? "document.on.document.fill" : "document.on.document")
            }
            .accessibilityLabel(isPaginationMode ? "fileEdit.switchToEditMode.accessibility" : "fileEdit.switchToPaginationPreview.accessibility")
            
            // Insert menu (only in edit mode)
            if !isPaginationMode {
                Menu {
                    Button(action: {
                        showImagePicker()
                    }) {
                        Label("Insert Image", systemImage: "photo")
                    }
                    
                    Button(action: {
                        // TODO: Implement list insertion
                    }) {
                        Label("List", systemImage: "list.bullet")
                    }
                    .disabled(true)
                    
                    // Comments submenu
                    Menu {
                        Button(action: {
                            showNewCommentDialog = true
                        }) {
                            Label("Add Comment", systemImage: "pencil.circle")
                        }
                        
                        if let currentVersion = file.currentVersion, currentVersion.comments?.isEmpty == false {
                            Divider()
                            
                            Button(action: {
                                showCommentsList = true
                            }) {
                                Label("Show Comments", systemImage: "bubble.left.and.bubble.right")
                            }
                        }
                    } label: {
                        Label("Comment", systemImage: "bubble.left")
                    }
                    
                    // Footnotes submenu
                    Menu {
                        Button(action: {
                            showNewFootnoteDialog = true
                        }) {
                            Label("Add Footnote", systemImage: "pencil.circle")
                        }
                        
                        if let currentVersion = file.currentVersion, currentVersion.footnotes?.isEmpty == false {
                            Divider()
                            
                            Button(action: {
                                showFootnotesList = true
                            }) {
                                Label("Show Footnotes", systemImage: "list.number")
                            }
                        }
                    } label: {
                        Label("Footnote", systemImage: "number.circle")
                    }
                    
                    Divider()
                    
                    Button(action: {
                        insertPageBreak()
                    }) {
                        Label("Page Break", systemImage: "page.break")
                    }
                } label: {
                    Image(systemName: "text.badge.plus")
                }
                .accessibilityLabel("fileEdit.insertMenu.accessibility")
            }
            
            // Undo button (only in edit mode)
            if !isPaginationMode {
                Button(action: {
                    performUndo()
                    restoreKeyboardFocus()
                }) {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!undoManager.canUndo || isPerformingUndoRedo)
                .accessibilityLabel("fileEdit.undo.accessibility")
                
                // Redo button
                Button(action: {
                    performRedo()
                    restoreKeyboardFocus()
                }) {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!undoManager.canRedo || isPerformingUndoRedo)
                .accessibilityLabel("fileEdit.redo.accessibility")
            }
            
            // Print button (available in both modes)
            Button(action: {
                printFile()
            }) {
                Image(systemName: "printer")
            }
            .disabled(!PrintService.isPrintingAvailable())
            .accessibilityLabel("fileEdit.print.accessibility")
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Version toolbar (only shown in edit mode)
            if !isPaginationMode {
                versionToolbar()
            }
            
            // Search bar (only shown in edit mode when active)
            if !isPaginationMode {
                InEditorSearchBar(
                    manager: searchManager,
                    isVisible: $showSearchBar,
                    isSimplifiedMode: isSimplifiedSearchMode
                )
            }
            
            // Main content area - switch between edit and pagination modes
            if isPaginationMode {
                paginationSection()
            } else {
                textEditorSection()
                // TODO: KEYBOARD GAP - There's a gap between the toolbar and keyboard
                // This is SwiftUI's default keyboard avoidance behavior
                // Potential solutions to explore:
                // 1. Use UITextView.inputAccessoryView to attach toolbar to keyboard (like Pages does)
                // 2. Use UIKit view controller and attach toolbar as inputAccessoryView
                // 3. Custom keyboard tracking with GeometryReader and keyboard notifications
                // Apple's apps (Pages, Notes, Mail) likely use UIKit's inputAccessoryView
                formattingToolbar()
            }
            
            // Hidden keyboard shortcut handlers for search navigation
            // Using invisible buttons to capture ⌘G and ⌘⇧G
            Group {
                Button("") {
                    if showSearchBar && searchManager.hasMatches {
                        searchManager.nextMatch()
                    }
                }
                .keyboardShortcut("g", modifiers: .command)
                .hidden()
                
                Button("") {
                    if showSearchBar && searchManager.hasMatches {
                        searchManager.previousMatch()
                    }
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .hidden()
                
                // List shortcuts: Cmd+Shift+7 for numbered, Cmd+Shift+8 for bulleted
                Button("") {
                    applyNumberFormat(.decimal)
                }
                .keyboardShortcut("7", modifiers: [.command, .shift])
                .hidden()
                
                Button("") {
                    applyNumberFormat(.bulletSymbols)
                }
                .keyboardShortcut("8", modifiers: [.command, .shift])
                .hidden()
            }
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
            
            // Get available caption styles from stylesheet (use project directly, not StyleSheetProvider)
            let styleSheet = file.project?.styleSheet
            let captionStyles = styleSheet?.textStyles?
                .filter { $0.name.contains("Caption") }
                .map { $0.name } ?? ["UICTFontTextStyleCaption1", "UICTFontTextStyleCaption2"]
            
            ImageStyleEditorView(
                imageData: imageData,
                scale: imageAttachment.scale,
                alignment: imageAttachment.alignment,
                hasCaption: imageAttachment.hasCaption,
                captionText: imageAttachment.captionText ?? "",
                captionStyle: imageAttachment.captionStyle ?? "UICTFontTextStyleCaption1",
                availableCaptionStyles: captionStyles,
                styleSheet: styleSheet,
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
    }
    
    var body: some View {
        mainContent
            .navigationTitle(file.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .onPopToRoot {
                dismiss()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PopToRootBackButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    navigationBarButtons()
                }
            }
            .modifier(DialogsModifier(
                showLockedVersionWarning: $showLockedVersionWarning,
                showImageSourcePicker: $showImageSourcePicker,
                showNewCommentDialog: $showNewCommentDialog,
                newCommentText: $newCommentText,
                showNewFootnoteDialog: $showNewFootnoteDialog,
                newFootnoteText: $newFootnoteText,
                attemptedEdit: $attemptedEdit,
                file: file,
                textViewCoordinator: textViewCoordinator,
                dismiss: dismiss,
                showPhotosPickerFromCoordinator: showPhotosPickerFromCoordinator,
                showDocumentPicker: $showDocumentPicker,
                insertNewComment: insertNewComment,
                insertNewFootnote: insertNewFootnote,
                showCommentsList: { showCommentsList = true }
            ))
            .sheet(isPresented: $showCommentsList) {
                if let currentVersion = file.currentVersion {
                    CommentsListView(
                        version: currentVersion,
                        onJumpToComment: { comment in
                            jumpToComment(comment)
                        },
                        onCommentResolvedChanged: { comment in
                            // Comment resolved state was changed in the list
                            // Update the visual marker in the text
                            refreshCommentMarker(comment)
                        },
                        onCommentDeleted: { comment in
                            // Comment was deleted, remove marker from text
                            removeCommentMarker(comment)
                        }
                    )
                }
            }
            .sheet(item: $selectedCommentForDetail) { comment in
                NavigationView {
                    CommentDetailView(
                        comment: comment,
                        onUpdate: {
                            // Comment text was updated
                            saveChanges()
                        },
                        onDelete: { deletedComment in
                            // Comment was deleted, remove marker from text
                            removeCommentMarker(deletedComment)
                            selectedCommentForDetail = nil
                        },
                        onResolveToggle: {
                            // Comment resolved state was toggled
                            refreshCommentMarker(comment)
                        },
                        onClose: {
                            selectedCommentForDetail = nil
                        }
                    )
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle(NSLocalizedString("fileEdit.commentSheet.title", comment: ""))
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showFootnotesList) {
                if let currentVersion = file.currentVersion {
                    FootnotesListView(
                        version: currentVersion,
                        onJumpToFootnote: { footnote in
                            jumpToFootnote(footnote)
                        },
                        onDismiss: {
                            showFootnotesList = false
                        },
                        onFootnoteChanged: {
                            // Footnote was updated, refresh display
                            saveChanges()
                        },
                        onFootnoteDeleted: { footnote in
                            // Footnote was deleted, remove marker from text
                            removeFootnoteFromText(footnote)
                        }
                    )
                }
            }
            .sheet(item: $selectedFootnoteForDetail) { footnote in
                NavigationView {
                    FootnoteDetailView(
                        footnote: footnote,
                        onUpdate: {
                            // Footnote text was updated - no need to save, already saved in FootnoteManager
                            // Just refresh the view
                            forceRefresh.toggle()
                        },
                        onDelete: {
                            // Footnote was deleted, remove it from the text
                            #if DEBUG
                            print("🗑️ FootnoteDetailView onDelete callback triggered for footnote: \(footnote.id)")
                            #endif
                            removeFootnoteFromText(footnote)
                            selectedFootnoteForDetail = nil
                        },
                        onClose: {
                            selectedFootnoteForDetail = nil
                        }
                    )
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle(NSLocalizedString("fileEdit.footnoteSheet.title", comment: ""))
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showNotesEditor) {
                if let currentVersion = file.currentVersion {
                    NotesEditorSheet(version: currentVersion)
                }
            }
            .onDisappear {
                // Unregister stylesheet from provider
                StyleSheetProvider.shared.unregister(fileID: file.id)
                
                // Disconnect search manager to clean up highlights and observers
                searchManager.disconnect()
                
                // Cancel debounce timer and save immediately
                saveDebounceTimer?.invalidate()
                saveDebounceTimer = nil
                
                saveChanges()
                saveUndoState()
            }
            .onAppear {
                setupOnAppear()
            }
            .onChange(of: selectedRange) { oldValue, newValue in
                updateCurrentParagraphStyle()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ImageWasPasted"))) { _ in
                handleImagePasted()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProjectStyleSheetChanged"))) { notification in
                handleStyleSheetChanged(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StyleSheetModified"))) { notification in
                handleStyleSheetModified(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: .footnoteNumbersDidChange)) { notification in
                handleFootnoteNumbersChanged(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UndoRedoContentRestored"))) { notification in
                handleUndoRedoContentRestored(notification)
            }
            .alert("Print Error", isPresented: $showPrintError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(printErrorMessage)
            }
    }
    
    // MARK: - Search Context Activation
    
    private func activateSearchFromContext(_ context: SearchContext) {
        #if DEBUG
        print("🔍 Setting up search from multi-file context: '\(context.searchText)'")
        #endif
        
        // Connect search manager to text view first
        guard let textView = textViewCoordinator.textView else {
            #if DEBUG
            print("⚠️ Text view not ready, cannot activate search")
            #endif
            return
        }
        
        searchManager.connect(to: textView)
        searchManager.customUndoManager = undoManager
        
        // Set search parameters
        searchManager.searchText = context.searchText
        searchManager.replaceText = context.replaceText ?? ""
        searchManager.isReplaceMode = context.replaceText != nil
        searchManager.isCaseSensitive = context.isCaseSensitive
        searchManager.isWholeWord = context.isWholeWord
        searchManager.isRegex = context.isRegex
        
        // Only show search bar if replace mode is active
        // For search-only mode, matches are highlighted but no UI is shown
        let shouldShowSearchBar = context.replaceText != nil
        
        // Track that this was opened from multi-file search
        isFromMultiFileSearch = context.isFromMultiFileSearch
        
        // Set simplified mode if opened from multi-file search with replace
        isSimplifiedSearchMode = context.isFromMultiFileSearch && shouldShowSearchBar
        
        // Show search bar only if in replace mode
        showSearchBar = shouldShowSearchBar
        
        // Ensure we scroll to first match (performSearch already does this, but may need delay)
        // This ensures both search-only and replace modes show the first match
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.searchManager.hasMatches {
                // Scroll is already done in performSearch, but ensure it's visible
                #if DEBUG
                print("🔍 Ensuring first match is visible")
                #endif
            }
        }
        
        // Reset the context so it won't activate again
        context.reset()
        
        #if DEBUG
        print("🔍 Search activated: \(searchManager.totalMatches) matches found, search bar visible: \(showSearchBar), simplified mode: \(isSimplifiedSearchMode)")
        #endif
    }
    
    // MARK: - View Modifiers Helper
    
    private struct DialogsModifier: ViewModifier {
        @Binding var showLockedVersionWarning: Bool
        @Binding var showImageSourcePicker: Bool
        @Binding var showNewCommentDialog: Bool
        @Binding var newCommentText: String
        @Binding var showNewFootnoteDialog: Bool
        @Binding var newFootnoteText: String
        @Binding var attemptedEdit: Bool
        let file: TextFile
        let textViewCoordinator: TextViewCoordinator
        let dismiss: DismissAction
        let showPhotosPickerFromCoordinator: () -> Void
        @Binding var showDocumentPicker: Bool
        let insertNewComment: () -> Void
        let insertNewFootnote: () -> Void
        let showCommentsList: () -> Void
        
        func body(content: Content) -> some View {
            content
                .confirmationDialog(
                    "version.locked.warning.title",
                    isPresented: $showLockedVersionWarning,
                    titleVisibility: .visible
                ) {
                    Button("version.locked.edit.anyway") {
                        attemptedEdit = true
                        showLockedVersionWarning = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.textViewCoordinator.textView?.becomeFirstResponder()
                        }
                    }
                    Button("button.cancel", role: .cancel) {
                        showLockedVersionWarning = false
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
                    "fileEdit.chooseImageSource.title",
                    isPresented: $showImageSourcePicker,
                    titleVisibility: .visible
                ) {
                    Button("fileEdit.chooseImageSource.photos") {
                        showPhotosPickerFromCoordinator()
                    }
                    Button("fileEdit.chooseImageSource.files") {
                        showDocumentPicker = true
                    }
                    Button("button.cancel", role: .cancel) {
                        showImageSourcePicker = false
                    }
                } message: {
                    Text("fileEdit.chooseImageSource.message")
                }
                .sheet(isPresented: $showNewCommentDialog) {
                    NewCommentSheet(
                        commentText: $newCommentText,
                        hasExistingComments: (file.currentVersion?.comments?.isEmpty ?? true) == false,
                        onAdd: {
                            insertNewComment()
                        },
                        onCancel: {
                            newCommentText = ""
                            showNewCommentDialog = false
                        },
                        onShowComments: {
                            showCommentsList()
                        }
                    )
                    .presentationDetents([.medium])
                }
                .sheet(isPresented: $showNewFootnoteDialog) {
                    NewFootnoteSheet(
                        footnoteText: $newFootnoteText,
                        onAdd: {
                            insertNewFootnote()
                        },
                        onCancel: {
                            newFootnoteText = ""
                            showNewFootnoteDialog = false
                        }
                    )
                    .presentationDetents([.medium])
                }
        }
    }
    // MARK: - Lifecycle Helpers
    
    private func setupOnAppear() {
        
        // Register stylesheet with provider for image caption rendering
        if let styleSheet = file.project?.styleSheet {
            StyleSheetProvider.shared.register(styleSheet: styleSheet, for: file.id)
        }
        
        // Always jump to latest version when opening a file
        file.selectLatestVersion()
        
        // Load content from database - ALWAYS normalize for iPhone
        if let savedContent = file.currentVersion?.attributedContent {
            #if DEBUG
            print("📂 onAppear: Loading content, length: \(savedContent.length)")
            #endif
            // Strip adaptive colors (black/white/gray) to support dark mode properly
            let processedContent = AttributedStringSerializer.stripAdaptiveColors(from: savedContent)
            
            // No iPhone-specific font changes - use view scale transform instead
            
            attributedContent = processedContent
            previousContent = attributedContent.string
            previousAttributedContent = processedContent  // Cache for undo without expensive DB fetch
            
            // CRITICAL: Restore orphaned comment markers from database
            // Comments created before we added serialization support need to be re-inserted
            restoreOrphanedCommentMarkers()
            
            // Position cursor at beginning of text (unless opening from search, which will position at first match)
            if searchContext == nil || searchContext?.shouldActivate == false {
                selectedRange = NSRange(location: 0, length: 0)
            }
        }
        
        // Show keyboard/cursor when opening file (only if not locked and not coming from search)
        if file.currentVersion?.isLocked != true && searchContext == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.textViewCoordinator.textView?.becomeFirstResponder()
            }
        }
        
        // Update current style from content
        updateCurrentParagraphStyle()
        
        // Set typing attributes from current content or stylesheet
        if let project = file.project {
            if attributedContent.length > 0 {
                // CRITICAL: Don't reapply styles to legacy RTF documents!
                // Legacy imports have direct formatting (bold/italic) baked in, not stylesheet styles
                // Reapplying styles would destroy all the bold/italic formatting
                let isLegacyRTF = file.currentVersion?.formattedContent != nil && 
                                  file.currentVersion?.formattedContent?.count ?? 0 > 0
                
                if !isLegacyRTF {
                    #if DEBUG
                    print("📝 onAppear: Reapplying styles to pick up any changes")
                    #endif
                    reapplyAllStyles()
                } else {
                    #if DEBUG
                    print("📝 onAppear: Skipping style reapply for legacy RTF document (preserves direct formatting)")
                    #endif
                }
                
                let attrs = attributedContent.attributes(at: 0, effectiveRange: nil)
                textViewCoordinator.modifyTypingAttributes { textView in
                    textView.typingAttributes = attrs
                }
            } else {
                let bodyAttrs = TextFormatter.getTypingAttributes(
                    forStyleNamed: UIFont.TextStyle.body.rawValue,
                    project: project,
                    context: modelContext
                )
                textViewCoordinator.modifyTypingAttributes { textView in
                    textView.typingAttributes = bodyAttrs
                    // Force redraw to trigger custom draw() method for empty document numbering
                    textView.setNeedsDisplay()
                }
                #if DEBUG
                print("📝 onAppear: Set typing attributes for empty document and forced redraw")
                #endif
            }
        }
        
        // Check if we should activate search from multi-file search context
        if let context = searchContext, context.shouldActivate {
            #if DEBUG
            print("🔍 Activating search from multi-file search context")
            #endif
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                activateSearchFromContext(context)
            }
        }
    }
    
    private func handleImagePasted() {
        #if DEBUG
        print("🖼️ Received ImageWasPasted notification - updating lastImageInsertTime")
        #endif
        lastImageInsertTime = Date()
    }
    
    private func handleStyleSheetChanged(_ notification: Notification) {
        #if DEBUG
        print("📋 ========== ProjectStyleSheetChanged NOTIFICATION ===========")
        #endif
        #if DEBUG
        print("📋 Notification userInfo: \(notification.userInfo ?? [:])")
        #endif
        
        guard let notifiedProjectID = notification.userInfo?["projectID"] as? UUID else {
            #if DEBUG
            print("⚠️ No projectID in notification")
            #endif
            #if DEBUG
            print("📋 ========== END ==========")
            #endif
            return
        }
        
        guard let ourProjectID = file.project?.id else {
            #if DEBUG
            print("⚠️ Our file has no project")
            #endif
            #if DEBUG
            print("📋 ========== END ==========")
            #endif
            return
        }
        
        #if DEBUG
        print("📋 Notified project ID: \(notifiedProjectID.uuidString)")
        #endif
        #if DEBUG
        print("📋 Our project ID: \(ourProjectID.uuidString)")
        #endif
        #if DEBUG
        print("📋 Match: \(notifiedProjectID == ourProjectID)")
        #endif
        
        guard notifiedProjectID == ourProjectID else {
            #if DEBUG
            print("📋 Not for us - ignoring")
            #endif
            #if DEBUG
            print("📋 ========== END ==========")
            #endif
            return
        }
        
        #if DEBUG
        print("📋 Received ProjectStyleSheetChanged notification for our project")
        #endif
        
        if attributedContent.length > 0 {
            #if DEBUG
            print("📋 Reapplying all styles due to stylesheet change")
            #endif
            reapplyAllStyles()
        } else {
            #if DEBUG
            print("📋 Document is empty, skipping reapply")
            #endif
        }
        #if DEBUG
        print("📋 ========== END ==========")
        #endif
    }
    
    private func handleStyleSheetModified(_ notification: Notification) {
        #if DEBUG
        print("📝 ========== StyleSheetModified NOTIFICATION ===========")
        #endif
        #if DEBUG
        print("📝 Notification userInfo: \(notification.userInfo ?? [:])")
        #endif
        
        guard let notifiedStyleSheetID = notification.userInfo?["stylesheetID"] as? UUID else {
            #if DEBUG
            print("⚠️ No stylesheetID in notification")
            #endif
            #if DEBUG
            print("📝 ========== END ==========")
            #endif
            return
        }
        
        guard let ourStyleSheetID = file.project?.styleSheet?.id else {
            #if DEBUG
            print("⚠️ Our file has no project or stylesheet")
            #endif
            #if DEBUG
            print("📝 ========== END ==========")
            #endif
            return
        }
        
        #if DEBUG
        print("📝 Notified stylesheet ID: \(notifiedStyleSheetID.uuidString)")
        #endif
        #if DEBUG
        print("📝 Our stylesheet ID: \(ourStyleSheetID.uuidString)")
        #endif
        #if DEBUG
        print("📝 Match: \(notifiedStyleSheetID == ourStyleSheetID)")
        #endif
        
        guard notifiedStyleSheetID == ourStyleSheetID else {
            #if DEBUG
            print("📝 Not for us - ignoring")
            #endif
            #if DEBUG
            print("📝 ========== END ==========")
            #endif
            return
        }
        
        #if DEBUG
        print("📝 Received StyleSheetModified notification for our stylesheet")
        #endif
        
        if attributedContent.length > 0 {
            #if DEBUG
            print("📝 Reapplying all styles due to style modification")
            #endif
            reapplyAllStyles()
        } else {
            #if DEBUG
            print("📝 Document is empty, skipping reapply")
            #endif
        }
        #if DEBUG
        print("📝 ========== END ==========")
        #endif
    }
    
    private func handleFootnoteNumbersChanged(_ notification: Notification) {
        #if DEBUG
        print("🔢 Received footnoteNumbersDidChange notification")
        #endif
        
        guard let versionIDString = notification.userInfo?["versionID"] as? String,
              let notifiedVersionID = UUID(uuidString: versionIDString) else {
            #if DEBUG
            print("⚠️ No versionID in notification")
            #endif
            return
        }
        
        guard let currentVersion = file.currentVersion else {
            #if DEBUG
            print("⚠️ No current version")
            #endif
            return
        }
        
        guard notifiedVersionID == currentVersion.id else {
            #if DEBUG
            print("🔢 Not for our version - ignoring")
            #endif
            return
        }
        
        #if DEBUG
        print("🔢 Updating footnote attachment numbers for our version")
        #endif
        updateFootnoteAttachmentNumbers()
    }
    
    /// Update footnote attachment numbers in the attributed string
    private func updateFootnoteAttachmentNumbers() {
        guard file.currentVersion != nil else { return }
        
        let mutableContent = NSMutableAttributedString(attributedString: attributedContent)
        var needsUpdate = false
        
        // Enumerate through all attachments
        mutableContent.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutableContent.length)) { value, range, stop in
            guard let attachment = value as? FootnoteAttachment else { return }
            
            // CRITICAL: Look up by attachmentID, not id!
            // attachment.footnoteID corresponds to FootnoteModel.attachmentID
            if let footnote = FootnoteManager.shared.getFootnoteByAttachment(attachmentID: attachment.footnoteID, context: modelContext) {
                if attachment.number != footnote.number {
                    #if DEBUG
                    print("🔢 Updating attachment \(attachment.footnoteID) from \(attachment.number) to \(footnote.number)")
                    #endif
                    attachment.number = footnote.number
                    needsUpdate = true
                }
            } else {
                #if DEBUG
                print("⚠️ Footnote not found in database for attachmentID: \(attachment.footnoteID)")
                #endif
            }
        }
        
        if needsUpdate {
            // Update the attributed content
            attributedContent = mutableContent
            #if DEBUG
            print("✅ Footnote attachment numbers updated")
            #endif
        }
    }
    
    /// Handle undo/redo content restoration notification from FormatApplyCommand
    private func handleUndoRedoContentRestored(_ notification: Notification) {
        guard let restoredContent = notification.userInfo?["content"] as? NSAttributedString else {
            #if DEBUG
            print("⚠️ handleUndoRedoContentRestored - no content in notification")
            #endif
            return
        }
        
        #if DEBUG
        print("🔄 handleUndoRedoContentRestored - updating UI with restored content")
        #endif
        
        // Update the UI with restored content
        attributedContent = restoredContent
        previousContent = restoredContent.string
        
        // Only position cursor at end if selection wasn't already set to an image position
        // This preserves image selection when Apply is clicked in image properties dialog
        if selectedRange.length != 1 {
            selectedRange = NSRange(location: restoredContent.length, length: 0)
        } else {
            #if DEBUG
            print("🔄 Preserving image selection at position \(selectedRange.location)")
            #endif
        }
        
        // Force refresh
        forceRefresh.toggle()
        refreshTrigger = UUID()
        
        // CRITICAL: Reconnect search manager after undo/redo
        // The text view is recreated due to the refresh, so we need to wait for the new text view
        // to be available and then reconnect the search manager
        if showSearchBar {
            // Use DispatchQueue.main.async to wait for the new text view to be created
            DispatchQueue.main.async {
                if let textView = self.textViewCoordinator.textView {
                    #if DEBUG
                    print("🔄 Reconnecting search manager to new text view after undo/redo")
                    #endif
                    self.searchManager.connect(to: textView)
                    // Also reconnect to the custom undo manager
                    self.searchManager.customUndoManager = self.undoManager
                    // Notify search manager that content changed (undo/redo)
                    self.searchManager.notifyTextChanged()
                } else {
                    #if DEBUG
                    print("⚠️ No text view available to reconnect search manager")
                    #endif
                }
            }
        }
    }
    
    // MARK: - Attributed Text Handling
    
    private func handleAttributedTextChange(_ newAttributedText: NSAttributedString) {
        #if DEBUG
        print("🔄 handleAttributedTextChange called")
        #if DEBUG
        print("🔄 isPerformingUndoRedo: \(isPerformingUndoRedo)")
        #endif
        #if DEBUG
        print("🔄 isPerformingBatchReplace: \(searchManager.isPerformingBatchReplace)")
        #endif
        #endif
        
        guard !isPerformingUndoRedo else {
            #if DEBUG
            print("🔄 Skipping - performing undo/redo")
            #endif
            return
        }
        
        // Skip during batch replace - undo will be handled manually
        guard !searchManager.isPerformingBatchReplace else {
            #if DEBUG
            print("🔄 Skipping - performing batch replace")
            #endif
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
        #if DEBUG
        print("🔄 New: '\(newContent)'")
        #endif
        #endif
        
        // Only register change if content actually changed
        guard newContent != previousContent else {
            #if DEBUG
            print("🔄 Content unchanged - skipping")
            #endif
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
        
        #if DEBUG
        print("🔄 Content changed - registering with undo manager")
        #endif
        
        // Create and execute undo command
        // PERFORMANCE FIX: Use cached previousAttributedContent instead of fetching from DB
        // Fetching from file.currentVersion?.attributedContent triggers expensive RTF/JSON decoding
        let beforeContent = previousAttributedContent ?? NSAttributedString(
            string: previousContent,
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )
        
        let command = FormatApplyCommand(
            description: "Typing",
            range: NSRange(location: 0, length: newAttributedText.length),
            beforeContent: beforeContent,
            afterContent: newAttributedText,
            targetFile: file
        )
        undoManager.execute(command)
        
        // Update previous content for next comparison
        previousContent = newContent
        previousAttributedContent = newAttributedText  // Cache for next change
        
        // Note: FormatApplyCommand.execute() already sets file.currentVersion?.attributedContent
        // So we don't need to set it again here - avoiding duplicate expensive encoding
        file.modifiedDate = Date()
        
        // PERFORMANCE FIX: Debounce saves to reduce I/O - save after 0.5 second pause in typing
        saveDebounceTimer?.invalidate()
        saveDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak modelContext] _ in
            do {
                try modelContext?.save()
            } catch {
                #if DEBUG
                print("Error saving context: \(error)")
                #endif
            }
        }
        
        // Force text view display refresh to ensure visual update
        // This is needed especially after undo/redo followed by replace operations
        if let textView = textViewCoordinator.textView {
            textView.setNeedsDisplay()
            textView.layoutIfNeeded()
        }
        
        // Notify search manager that text changed (includes undo/redo)
        searchManager.notifyTextChanged()
    }
    
    // MARK: - Image Selection
    
    private func handleImageTap(attachment: ImageAttachment, frame: CGRect, position: Int) {
        #if DEBUG
        print("🖼️ ========== IMAGE TAP HANDLER ==========")
        #endif
        #if DEBUG
        print("🖼️ Image selected at position \(position)")
        #endif
        #if DEBUG
        print("🖼️ Frame: \(frame)")
        #endif
        #if DEBUG
        print("🖼️ Attachment: \(attachment)")
        #endif
        
        // Defer state updates to avoid "Modifying state during view update" warning
        DispatchQueue.main.async {
            selectedImage = attachment
            selectedImageFrame = frame
            selectedImagePosition = position
            
            #if DEBUG
            print("🖼️ State updated - selectedImage: \(selectedImage != nil)")
            #endif
            #if DEBUG
            print("🖼️ State updated - selectedImageFrame: \(selectedImageFrame)")
            #endif
        }
        
        // Select the image character so backspace/delete will remove it
        if let textView = textViewCoordinator.textView {
            DispatchQueue.main.async {
                textView.selectedRange = NSRange(location: position, length: 1)
                textView.tintColor = .clear // Hide cursor when image is selected
            }
            #if DEBUG
            print("🖼️ Cursor hidden, range set to {\(position), 1}")
            #endif
        } else {
            #if DEBUG
            print("⚠️ No textView available!")
            #endif
        }
        #if DEBUG
        print("🖼️ ========== END ==========")
        #endif
    }
    
    // MARK: - Comment Handling
    
    private func handleCommentTap(attachment: CommentAttachment, position: Int) {
        #if DEBUG
        print("💬 Comment tapped at position \(position)")
        #endif
        #if DEBUG
        print("💬 Comment ID: \(attachment.commentID)")
        #endif
        
        // Fetch the specific comment from the database
        let commentID = attachment.commentID
        let fetchDescriptor = FetchDescriptor<CommentModel>(
            predicate: #Predicate<CommentModel> { comment in
                comment.attachmentID == commentID
            }
        )
        
        do {
            let comments = try modelContext.fetch(fetchDescriptor)
            if let comment = comments.first {
                #if DEBUG
                print("💬 Found comment in database, showing detail view")
                #endif
                selectedCommentForDetail = comment
            } else {
                #if DEBUG
                print("⚠️ Comment not found in database for ID: \(commentID)")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ Error fetching comment: \(error)")
            #endif
        }
    }
    
    private func handleFootnoteTap(attachment: FootnoteAttachment, position: Int) {
        #if DEBUG
        print("🔢 Footnote tapped at position \(position)")
        #endif
        #if DEBUG
        print("🔢 Attachment footnoteID: \(attachment.footnoteID)")
        #endif
        
        // Fetch the specific footnote from the database
        let attachmentID = attachment.footnoteID
        let fetchDescriptor = FetchDescriptor<FootnoteModel>(
            predicate: #Predicate<FootnoteModel> { footnote in
                footnote.attachmentID == attachmentID
            }
        )
        
        do {
            let footnotes = try modelContext.fetch(fetchDescriptor)
            if let footnote = footnotes.first {
                #if DEBUG
                print("🔢 Found footnote in database:")
                #endif
                #if DEBUG
                print("   - Database ID: \(footnote.id)")
                #endif
                #if DEBUG
                print("   - AttachmentID: \(footnote.attachmentID)")
                #endif
                #if DEBUG
                print("   - Number: \(footnote.number)")
                #endif
                selectedFootnoteForDetail = footnote
            } else {
                #if DEBUG
                print("⚠️ Footnote not found in database for attachmentID: \(attachmentID)")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ Error fetching footnote: \(error)")
            #endif
        }
    }
    
    private func jumpToComment(_ comment: CommentModel) {
        // Position cursor at the comment location
        let position = comment.characterPosition
        if position < attributedContent.length {
            selectedRange = NSRange(location: position, length: 0)
            // Optionally scroll to make it visible
            if let textView = textViewCoordinator.textView {
                textView.scrollRangeToVisible(NSRange(location: position, length: 1))
            }
        }
    }
    
    private func jumpToFootnote(_ footnote: FootnoteModel) {
        // Position cursor at the footnote location
        let position = footnote.characterPosition
        if position < attributedContent.length {
            selectedRange = NSRange(location: position, length: 0)
            // Optionally scroll to make it visible
            if let textView = textViewCoordinator.textView {
                textView.scrollRangeToVisible(NSRange(location: position, length: 1))
            }
        }
    }
    
    private func insertNewComment() {
        guard !newCommentText.isEmpty else { return }
        guard let currentVersion = file.currentVersion else {
            #if DEBUG
            print("❌ Cannot insert comment: no current version")
            #endif
            return
        }
        
        // Insert comment at cursor position
        if let textView = textViewCoordinator.textView {
            let comment = CommentInsertionHelper.insertCommentAtCursor(
                in: textView,
                commentText: newCommentText,
                author: "User", // TODO: Get actual user name
                version: currentVersion,
                context: modelContext
            )
            
            if let comment = comment {
                #if DEBUG
                print("💬 Comment inserted: \(comment.text)")
                #endif
                // Update the attributed content binding
                attributedContent = textView.attributedText ?? NSAttributedString()
                saveChanges()
            }
        }
        
        // Reset dialog
        newCommentText = ""
        showNewCommentDialog = false
    }
    
    private func insertNewFootnote() {
        guard !newFootnoteText.isEmpty else { return }
        guard let currentVersion = file.currentVersion else {
            #if DEBUG
            print("❌ Cannot insert footnote: no current version")
            #endif
            return
        }
        
        // Insert footnote at cursor position
        if let textView = textViewCoordinator.textView {
            let footnote = FootnoteInsertionHelper.insertFootnoteAtCursor(
                in: textView,
                footnoteText: newFootnoteText,
                version: currentVersion,
                context: modelContext
            )
            
            if let footnote = footnote {
                #if DEBUG
                print("🔢 Footnote inserted: \(footnote.text)")
                #endif
                
                // CRITICAL: Update all footnote numbers in the text to match database
                let updatedContent = FootnoteInsertionHelper.updateAllFootnoteNumbers(
                    in: textView.attributedText ?? NSAttributedString(),
                    forVersion: currentVersion,
                    context: modelContext
                )
                
                // Update the text view with renumbered footnotes
                textView.textStorage.setAttributedString(updatedContent)
                
                // Update the attributed content binding
                attributedContent = updatedContent
                saveChanges()
            }
        }
        
        // Reset dialog
        newFootnoteText = ""
        showNewFootnoteDialog = false
    }
    
    /// Remove a footnote attachment from the text when it's moved to trash
    private func removeFootnoteFromText(_ footnote: FootnoteModel) {
        guard let textView = textViewCoordinator.textView else {
            #if DEBUG
            print("❌ Cannot remove footnote: no text view")
            #endif
            return
        }
        
        #if DEBUG
        print("🗑️ Removing footnote \(footnote.id) from text (attachmentID: \(footnote.attachmentID))")
        #endif
        
        // Set flag FIRST before any text modifications
        isPerformingUndoRedo = true
        
        // CRITICAL: Use attachmentID, not id! The FootnoteAttachment stores attachmentID, not the footnote's database ID
        // Remove the footnote attachment from the text view
        if let removedRange = FootnoteInsertionHelper.removeFootnoteFromTextView(textView, footnoteID: footnote.attachmentID) {
            // Get the updated text from text view
            let updatedText = textView.attributedText ?? NSAttributedString()
            
            // Update the model directly WITHOUT triggering attributedContent observer
            file.currentVersion?.attributedContent = updatedText
            previousContent = updatedText.string
            file.modifiedDate = Date()
            
            // Save context
            do {
                try modelContext.save()
            } catch {
                #if DEBUG
                print("❌ Error saving context: \(error)")
                #endif
            }
            
            // Update attributedContent LAST, after flag is set
            // This ensures the observer sees isPerformingUndoRedo = true
            attributedContent = updatedText
            
            #if DEBUG
            print("✅ Footnote removed from position \(removedRange.location)")
            #endif
        } else {
            #if DEBUG
            print("⚠️ Footnote attachment not found in text")
            #endif
        }
        
        // Reset flag AFTER attributedContent update completes
        // Use asyncAfter with minimal delay to ensure binding update has fired
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.isPerformingUndoRedo = false
            #if DEBUG
            print("🗑️ Reset isPerformingUndoRedo flag")
            #endif
        }
    }
    
    
    
    private func insertPageBreak() {
        #if DEBUG
        print("📄 Inserting page break at cursor")
        #endif
        
        guard let textView = textViewCoordinator.textView else {
            #if DEBUG
            print("❌ Cannot insert page break: no text view")
            #endif
            return
        }
        
        // Get current selection/cursor position
        let currentRange = textView.selectedRange
        
        // Create page break with visual indicator (attachment) and actual page break (form feed)
        // The attachment provides visual feedback in the editor
        // The form feed (\u{000C}) provides the actual page break for pagination/printing
        let pageBreakAttributed = PageBreakAttachment.createPageBreakString()
        
        // Insert the page break at cursor position
        textView.textStorage.insert(pageBreakAttributed, at: currentRange.location)
        
        // Move cursor after the page break
        let newLocation = currentRange.location + pageBreakAttributed.length
        textView.selectedRange = NSRange(location: newLocation, length: 0)
        
        // Update the attributed content binding
        attributedContent = textView.attributedText ?? NSAttributedString()
        
        // Save changes
        saveChanges()
        
        #if DEBUG
        print("✅ Page break inserted at position \(currentRange.location)")
        #endif
    }
    
    private func updateComment(_ comment: CommentModel, newText: String) {
        comment.updateText(newText)
        try? modelContext.save()
        #if DEBUG
        print("💬 Comment updated: \(newText)")
        #endif
    }
    
    private func deleteComment(_ comment: CommentModel) {
        // Remove from text
        attributedContent = CommentInsertionHelper.removeComment(
            from: attributedContent,
            commentID: comment.attachmentID
        )
        
        // Delete from database
        CommentManager.shared.deleteComment(comment, context: modelContext)
        
        // Save
        saveChanges()
        #if DEBUG
        print("💬 Comment deleted")
        #endif
    }
    
    private func removeCommentMarker(_ comment: CommentModel) {
        // Remove the comment marker from text (called when comment is deleted from detail view)
        attributedContent = CommentInsertionHelper.removeComment(
            from: attributedContent,
            commentID: comment.attachmentID
        )
        
        // Save
        saveChanges()
        #if DEBUG
        print("💬 Comment marker removed: \(comment.attachmentID)")
        #endif
    }
    
    private func toggleCommentResolved(_ comment: CommentModel) {
        #if DEBUG
        print("💬 toggleCommentResolved called - current state: \(comment.isResolved)")
        #endif
        
        if comment.isResolved {
            comment.reopen()
        } else {
            comment.resolve()
        }
        
        #if DEBUG
        print("💬 After toggle - new state: \(comment.isResolved)")
        #endif
        #if DEBUG
        print("💬 Comment attachmentID: \(comment.attachmentID)")
        #endif
        
        // Update visual indicator in text
        let updatedContent = CommentInsertionHelper.updateCommentResolvedState(
            in: attributedContent,
            commentID: comment.attachmentID,
            isResolved: comment.isResolved
        )
        
        #if DEBUG
        print("💬 Updated content length: \(updatedContent.length)")
        #endif
        #if DEBUG
        print("💬 Original content length: \(attributedContent.length)")
        #endif
        
        // Force update the text view to show the new marker color
        if let textView = textViewCoordinator.textView {
            #if DEBUG
            print("💬 Updating textView with new resolved state")
            #endif
            
            // CRITICAL: Update the text storage directly to force re-render of attachments
            textView.textStorage.setAttributedString(updatedContent)
            
            // Invalidate layout and display for the entire document
            let fullRange = NSRange(location: 0, length: updatedContent.length)
            textView.layoutManager.invalidateLayout(forCharacterRange: fullRange, actualCharacterRange: nil)
            textView.layoutManager.invalidateDisplay(forCharacterRange: fullRange)
            
            // Force layout update
            textView.layoutManager.ensureLayout(for: textView.textContainer)
            
            // Force redraw
            textView.setNeedsDisplay()
            textView.setNeedsLayout()
            textView.layoutIfNeeded()
            
            #if DEBUG
            print("💬 TextView updated and forced to redraw")
            #endif
        } else {
            #if DEBUG
            print("⚠️ textView is nil!")
            #endif
        }
        
        // Update SwiftUI state
        attributedContent = updatedContent
        
        try? modelContext.save()
        saveChanges()
        #if DEBUG
        print("💬 Comment resolved state saved: \(comment.isResolved)")
        #endif
    }
    
    /// Update the visual marker for a comment after its resolved state changes externally (e.g., from CommentsListView)
    private func refreshCommentMarker(_ comment: CommentModel) {
        #if DEBUG
        print("💬🔄 refreshCommentMarker called for comment: \(comment.attachmentID)")
        #endif
        #if DEBUG
        print("💬🔄 Current resolved state: \(comment.isResolved)")
        #endif
        
        // Update visual indicator in text
        let updatedContent = CommentInsertionHelper.updateCommentResolvedState(
            in: attributedContent,
            commentID: comment.attachmentID,
            isResolved: comment.isResolved
        )
        
        // Force update the text view to show the new marker color
        if let textView = textViewCoordinator.textView {
            #if DEBUG
            print("💬🔄 Updating textView with new resolved state")
            #endif
            
            // CRITICAL: Update the text storage directly to force re-render of attachments
            textView.textStorage.setAttributedString(updatedContent)
            
            // Invalidate layout and display for the entire document
            let fullRange = NSRange(location: 0, length: updatedContent.length)
            textView.layoutManager.invalidateLayout(forCharacterRange: fullRange, actualCharacterRange: nil)
            textView.layoutManager.invalidateDisplay(forCharacterRange: fullRange)
            
            // Force layout update
            textView.layoutManager.ensureLayout(for: textView.textContainer)
            
            // Force redraw
            textView.setNeedsDisplay()
            textView.setNeedsLayout()
            textView.layoutIfNeeded()
            
            #if DEBUG
            print("💬🔄 TextView updated and forced to redraw")
            #endif
        }
        
        // Update SwiftUI state
        attributedContent = updatedContent
        
        saveChanges()
        #if DEBUG
        print("💬🔄 Comment marker refreshed: resolved=\(comment.isResolved)")
        #endif
    }
    
    /// Restore comment markers from the database for comments that were created before serialization support
    /// This handles "orphaned" comments that exist in the database but don't have markers in the attributed text
    private func restoreOrphanedCommentMarkers() {
        #if DEBUG
        print("💬🔧 Checking for orphaned comment markers...")
        #endif
        
        // Get all comments for this version from the relationship
        guard let currentVersion = file.currentVersion else {
            #if DEBUG
            print("💬🔧 No current version available")
            #endif
            return
        }
        
        let allComments = currentVersion.comments ?? []
        
        guard !allComments.isEmpty else {
            #if DEBUG
            print("💬🔧 No comments found in version")
            #endif
            return
        }
        
        #if DEBUG
        print("💬🔧 Found \(allComments.count) comments in version")
        #endif
        
        // Check which comments are missing from the attributed text
        let mutableText = NSMutableAttributedString(attributedString: attributedContent)
        var existingCommentIDs = Set<UUID>()
        
        // Find all existing comment attachments
        mutableText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutableText.length)) { value, _, _ in
            if let commentAttachment = value as? CommentAttachment {
                existingCommentIDs.insert(commentAttachment.commentID)
            }
        }
        
        #if DEBUG
        print("💬🔧 Found \(existingCommentIDs.count) existing comment markers in text")
        #endif
        
        // Find orphaned comments
        let orphanedComments = allComments.filter { !existingCommentIDs.contains($0.attachmentID) }
        
        guard !orphanedComments.isEmpty else {
            #if DEBUG
            print("💬🔧 No orphaned comments found - all good!")
            #endif
            return
        }
        
        #if DEBUG
        print("💬🔧 Found \(orphanedComments.count) orphaned comments - restoring markers...")
        #endif
        
        // Insert markers for orphaned comments (in reverse order to maintain positions)
        for comment in orphanedComments.reversed() {
            let position = min(comment.characterPosition, mutableText.length)
            let attachment = CommentAttachment(commentID: comment.attachmentID, isResolved: comment.isResolved)
            let attachmentString = NSAttributedString(attachment: attachment)
            
            mutableText.insert(attachmentString, at: position)
            #if DEBUG
            print("💬🔧 Restored marker for comment '\(comment.text)' at position \(position)")
            #endif
        }
        
        // Update the attributed content
        attributedContent = mutableText
        #if DEBUG
        print("💬🔧 ✅ Restored \(orphanedComments.count) orphaned comment markers")
        #endif
        
        // Save the restored markers
        saveChanges()
    }
    
    // MARK: - Undo/Redo
    
    private func performUndo() {
        #if DEBUG
        print("🔄 performUndo called - canUndo: \(undoManager.canUndo)")
        #endif
        guard undoManager.canUndo else { return }
        
        isPerformingUndoRedo = true
        
        // Execute the undo command
        // FormatApplyCommand will restore the attributed content and post a notification
        // that we listen for in handleUndoRedoContentRestored()
        undoManager.undo()
        
        #if DEBUG
        print("🔄 Undo command executed")
        #endif
        
        // Reset flag after UI has updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isPerformingUndoRedo = false
            #if DEBUG
            print("🔄 Reset isPerformingUndoRedo flag")
            #endif
        }
    }
    
    private func performRedo() {
        #if DEBUG
        print("� performRedo called - canRedo: \(undoManager.canRedo)")
        #endif
        guard undoManager.canRedo else { return }
        
        isPerformingUndoRedo = true
        
        undoManager.redo()
        
        // Reload from model (attributedContent getter handles plain text fallback)
        let newAttributedContent = file.currentVersion?.attributedContent ?? NSAttributedString(
            string: "",
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )
        
        #if DEBUG
        print("🔄 After redo - new content: '\(newAttributedContent.string)' (length: \(newAttributedContent.string.count))")
        #endif
        
        // Update all state
        attributedContent = newAttributedContent
        previousContent = newAttributedContent.string
        
        // FIX: Position cursor at end of new content
        selectedRange = NSRange(location: newAttributedContent.string.count, length: 0)
        #if DEBUG
        print("🔄 Set selectedRange to end: \(selectedRange)")
        #endif
        
        // Force refresh
        forceRefresh.toggle()
        refreshTrigger = UUID()
        
        // Reset flag after UI has updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isPerformingUndoRedo = false
            #if DEBUG
            print("🔄 Reset isPerformingUndoRedo flag")
            #endif
        }
    }
    
    // MARK: - Printing
    
    /// Handle print action
    private func printFile() {
        #if DEBUG
        print("🖨️ Print button tapped")
        #endif
        
        // Save any pending changes before printing
        saveChanges()
        
        // Get the view controller to present from
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let viewController = window.rootViewController else {
            #if DEBUG
            print("❌ Could not find view controller for print dialog")
            #endif
            printErrorMessage = "Unable to present print dialog"
            showPrintError = true
            return
        }
        
        // Call print service (need project for stylesheet)
        guard let project = file.project else {
            #if DEBUG
            print("❌ Could not find project for file")
            #endif
            printErrorMessage = "Unable to find project"
            showPrintError = true
            return
        }
        
        PrintService.printFile(
            file,
            project: project,
            context: modelContext,
            from: viewController
        ) { success, error in
            if let error = error {
                #if DEBUG
                print("❌ Print failed: \(error.localizedDescription)")
                #endif
                printErrorMessage = error.localizedDescription
                showPrintError = true
            } else if success {
                #if DEBUG
                print("✅ Print completed successfully")
                #endif
            } else {
                #if DEBUG
                print("⚠️ Print was cancelled")
                #endif
            }
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
        #if DEBUG
        print("🎨 selectedRange: {\(selectedRange.location), \(selectedRange.length)}")
        #endif
        #endif
        
        // Ensure we have a valid selection
        guard selectedRange.location != NSNotFound else {
            #if DEBUG
            print("⚠️ selectedRange.location is NSNotFound")
            #endif
            return
        }
        
        // If no text is selected (cursor only), modify typing attributes
        if selectedRange.length == 0 {
            #if DEBUG
            print("🎨 Modifying typing attributes for \(formatType)")
            #endif
            modifyTypingAttributes(formatType)
            return
        }
        
        #if DEBUG
        print("🎨 Applying \(formatType) to range {\(selectedRange.location), \(selectedRange.length)}")
        #endif
        
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
        
        #if DEBUG
        print("🎨 Format applied successfully")
        #endif
        
        // Update local state immediately for instant UI feedback
        attributedContent = newAttributedContent
        
        #if DEBUG
        print("🎨 Updated local state with formatted content")
        #endif
        
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
        
        #if DEBUG
        print("🎨 Formatting command added to undo stack")
        #endif
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
            
            #if DEBUG
            print("🎨 Modified typing attributes for \(formatType)")
            #endif
            #if DEBUG
            print("🎨 New typing attributes: \(typingAttributes)")
            #endif
        }
        
        // DON'T trigger refresh - it dismisses the keyboard
        // The toolbar will check typing attributes directly when selection changes
    }
    
    /// Apply number format to current paragraph or selection
    private func applyNumberFormat(_ format: NumberFormat) {
        guard let project = file.project else { return }
        
        // Get the range of the current paragraph
        let paragraphRange = (attributedContent.string as NSString).paragraphRange(for: selectedRange)
        
        // Determine which list style to apply based on format
        let listStyleName: String
        if format == .bulletSymbols {
            listStyleName = "list-bullet"
        } else {
            listStyleName = "list-numbered"
        }
        
        // Apply the list style to the paragraph
        guard let listStyle = project.styleSheet?.style(named: listStyleName) else {
            return
        }
        
        // Store before state for undo
        let beforeContent = attributedContent
        
        // Apply the list style attributes to the paragraph
        let mutableContent = NSMutableAttributedString(attributedString: attributedContent)
        let styleAttributes = listStyle.generateAttributes()
        mutableContent.addAttributes(styleAttributes, range: paragraphRange)
        
        // Update content
        attributedContent = mutableContent
        
        // Force a redraw by invalidating the layout
        if let textView = textViewCoordinator.textView {
            textView.setNeedsDisplay()
            textView.layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: attributedContent.length))
        }
        
        // Create undo command
        let command = FormatApplyCommand(
            description: format == .bulletSymbols ? "Apply Bullet List" : "Apply Numbered List",
            range: selectedRange,
            beforeContent: beforeContent,
            afterContent: attributedContent,
            targetFile: file
        )
        
        undoManager.execute(command)
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
        #if DEBUG
        print("🔄 ========== REAPPLY ALL STYLES START ==========")
        #endif
        #if DEBUG
        print("🔄 Document length: \(attributedContent.length)")
        #endif
        
        // Need a project to resolve styles
        guard let project = file.project else {
            #if DEBUG
            print("⚠️ No project - cannot reapply styles")
            #endif
            #if DEBUG
            print("🔄 ========== REAPPLY ALL STYLES END (NO PROJECT) ==========")
            #endif
            return
        }
        
        #if DEBUG
        print("🔄 Project: \(project.name ?? "unnamed")")
        #endif
        #if DEBUG
        print("🔄 Stylesheet: \(project.styleSheet?.name ?? "none")")
        #endif
        #if DEBUG
        print("🔄 Stylesheet ID: \(project.styleSheet?.id.uuidString ?? "none")")
        #endif
        
        // If document is empty, nothing to reapply
        guard attributedContent.length > 0 else {
            #if DEBUG
            print("📝 Document is empty - nothing to reapply")
            #endif
            #if DEBUG
            print("🔄 ========== REAPPLY ALL STYLES END (EMPTY) ==========")
            #endif
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
                #if DEBUG
                print("⚠️ Found TextStyle attribute but value is not a string: \(String(describing: value))")
                #endif
                return 
            }
            
            stylesFound += 1
            #if DEBUG
            print("🔄 [\(stylesFound)] Found style '\(styleName)' at range {\(range.location), \(range.length)}")
            #endif
            
            // Re-fetch the style from database to get latest changes
            guard let updatedStyle = StyleSheetService.resolveStyle(
                named: styleName,
                for: project,
                context: modelContext
            ) else {
                #if DEBUG
                print("⚠️ Could not resolve style '\(styleName)' for project '\(project.name ?? "unnamed")'")
                #endif
                return
            }
            
            #if DEBUG
            print("✅ Resolved style '\(styleName)': fontSize=\(updatedStyle.fontSize), bold=\(updatedStyle.isBold), italic=\(updatedStyle.isItalic)")
            #endif
            
            // Get updated attributes from the style
            let newAttributes = updatedStyle.generateAttributes()
            guard let newFont = newAttributes[NSAttributedString.Key.font] as? UIFont else {
                #if DEBUG
                print("⚠️ Style '\(styleName)' has no font in generated attributes")
                #endif
                return
            }
            
            #if DEBUG
            print("📝 New font: \(newFont.fontName) \(newFont.pointSize)pt, bold=\(updatedStyle.isBold), italic=\(updatedStyle.isItalic)")
            #endif
            if let color = newAttributes[.foregroundColor] as? UIColor {
                #if DEBUG
                print("📝 New color: \(color)")
                #endif
            } else {
                #if DEBUG
                print("📝 New color: NONE (will use system default)")
                #endif
            }
            
            // Log what color is CURRENTLY in the text before we change it
            if range.location < mutableText.length {
                let oldAttrs = mutableText.attributes(at: range.location, effectiveRange: nil)
                if let oldColor = oldAttrs[.foregroundColor] as? UIColor {
                    #if DEBUG
                    print("   🔍 OLD color in document: \(oldColor.toHex() ?? "unknown")")
                    #endif
                } else {
                    #if DEBUG
                    print("   🔍 OLD color in document: NONE")
                    #endif
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
                    #if DEBUG
                    print("   🖼️ Found attachment at position \(pos) within range {\(range.location), \(range.length)}")
                    #endif
                    break
                }
            }
            
            // Apply attributes based on whether we have an attachment
            #if DEBUG
            print("✅ Applying new attributes to range {\(range.location), \(range.length)}")
            #endif
            if let attachmentPos = attachmentPosition {
                #if DEBUG
                print("   🖼️ Range contains attachment at position \(attachmentPos) - using selective application")
                #endif
                
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
                    #if DEBUG
                    print("   📝 Applied left alignment to text before image: range {\(beforeRange.location), \(beforeRange.length)}")
                    #endif
                }
                
                // Apply to text AFTER the image
                if attachmentPos < range.location + range.length - 1 {
                    let afterStart = attachmentPos + 1
                    let afterLength = (range.location + range.length) - afterStart
                    if afterLength > 0 {
                        let afterRange = NSRange(location: afterStart, length: afterLength)
                        mutableText.addAttribute(.paragraphStyle, value: defaultParagraphStyle, range: afterRange)
                        #if DEBUG
                        print("   📝 Applied left alignment to text after image: range {\(afterRange.location), \(afterRange.length)}")
                        #endif
                    }
                }
                
                // Preserve the image's original paragraph style
                if let paragraphStyle = preservedParagraphStyle {
                    mutableText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: attachmentPos, length: 1))
                    #if DEBUG
                    print("   🖼️ Preserved image paragraph alignment at position \(attachmentPos)")
                    #endif
                }
            } else {
                // No attachment - apply all attributes including paragraph style normally
                mutableText.setAttributes(newAttributes, range: range)
            }
            
            // Log what color is ACTUALLY in the text after we set it
            if range.location < mutableText.length {
                let finalAttrs = mutableText.attributes(at: range.location, effectiveRange: nil)
                if let finalColor = finalAttrs[.foregroundColor] as? UIColor {
                    #if DEBUG
                    print("   🔍 FINAL color after setAttributes: \(finalColor.toHex() ?? "unknown")")
                    #endif
                } else {
                    #if DEBUG
                    print("   🔍 FINAL color after setAttributes: NONE ✅ (will adapt!)")
                    #endif
                }
            }
            hasChanges = true
        }
        
        #if DEBUG
        print("🔄 Total styles found and processed: \(stylesFound)")
        #endif
        #if DEBUG
        print("🔄 Has changes: \(hasChanges)")
        #endif
        
        // Update document if any changes were made
        if hasChanges {
            let beforeContent = attributedContent
            attributedContent = mutableText
            
            #if DEBUG
            print("✅ Updated attributedContent with new styles")
            #endif
            #if DEBUG
            print("✅ Reapplied all styles successfully")
            #endif
            
            // Create undo command
            let command = FormatApplyCommand(
                description: "Reapply All Styles",
                range: NSRange(location: 0, length: mutableText.length),
                beforeContent: beforeContent,
                afterContent: mutableText,
                targetFile: file
            )
            
            undoManager.execute(command)
            #if DEBUG
            print("✅ Added undo command")
            #endif
            
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
                    #if DEBUG
                    print("✅ Updated typing attributes")
                    #endif
                }
            }
            
            restoreKeyboardFocus()
            #if DEBUG
            print("✅ Restored keyboard focus")
            #endif
            
            // CRITICAL: Directly update the text view's text storage to ensure visual refresh
            // The SwiftUI binding update may not trigger updateUIView if timing is off
            textViewCoordinator.modifyTypingAttributes { textView in
                // Save selection
                let savedSelection = textView.selectedRange
                
                // Update text storage directly
                textView.textStorage.setAttributedString(mutableText)
                
                // Force layout recalculation
                textView.layoutManager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: textView.textStorage.length), actualCharacterRange: nil)
                textView.layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: textView.textStorage.length))
                textView.layoutManager.ensureLayout(for: textView.textContainer)
                
                // Restore selection
                if savedSelection.location <= textView.textStorage.length {
                    textView.selectedRange = savedSelection
                }
                
                textView.setNeedsDisplay()
            }
            #if DEBUG
            print("✅ Directly updated text storage and invalidated layout")
            #endif
            
            // Force SwiftUI view refresh to ensure text view updates
            refreshTrigger = UUID()
            #if DEBUG
            print("✅ Triggered view refresh")
            #endif
        } else {
            #if DEBUG
            print("📝 No styles found to reapply - hasChanges is false")
            #endif
        }
        
        #if DEBUG
        print("🔄 ========== REAPPLY ALL STYLES END ==========")
        #endif
    }
    
    /// Apply a paragraph style to the current selection
    private func applyParagraphStyle(_ style: UIFont.TextStyle) {
        #if DEBUG
        print("📝 ========== APPLY PARAGRAPH STYLE START ==========")
        #if DEBUG
        print("📝 Style: \(style.rawValue)")
        #endif
        #if DEBUG
        print("📝 selectedRange: {\(selectedRange.location), \(selectedRange.length)}")
        #endif
        #if DEBUG
        print("📝 Document length: \(attributedContent.length)")
        #endif
        
        // Log current attributes at selection
        if attributedContent.length > 0 && selectedRange.location < attributedContent.length {
            let attrs = attributedContent.attributes(at: selectedRange.location, effectiveRange: nil)
            #if DEBUG
            print("📝 Current attributes at selection:")
            #endif
            if let color = attrs[.foregroundColor] as? UIColor {
                #if DEBUG
                print("   Color: \(color.toHex() ?? "unknown")")
                #endif
            }
            if let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle {
                #if DEBUG
                print("   Alignment: \(paragraphStyle.alignment.rawValue)")
                #endif
            }
            if let textStyle = attrs[.textStyle] as? String {
                #if DEBUG
                print("   TextStyle attribute: \(textStyle)")
                #endif
            }
        }
        #endif
        
        // Ensure we have a valid location
        guard selectedRange.location != NSNotFound else {
            #if DEBUG
            print("⚠️ selectedRange.location is NSNotFound")
            #endif
            #if DEBUG
            print("📝 ========== END ==========")
            #endif
            return
        }
        
        // Try to use model-based formatting if we have a project
        let newAttributedContent: NSAttributedString
        if let project = file.project {
            // Special handling for empty text (model-based)
            if attributedContent.length == 0 {
                #if DEBUG
                print("📝 Text is empty - creating attributed string with style: \(style)")
                #endif
                
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
                
                #if DEBUG
                print("📝 Empty text styled with model - picker should update")
                #endif
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
            
            #if DEBUG
            print("📝 Paragraph style applied successfully (model-based)")
            #endif
            
            // Log what we got back
            #if DEBUG
            if newAttributedContent.length > 0 && selectedRange.location < newAttributedContent.length {
                let attrs = newAttributedContent.attributes(at: selectedRange.location, effectiveRange: nil)
                #if DEBUG
                print("📝 New attributes at selection after applying style:")
                #endif
                if let color = attrs[.foregroundColor] as? UIColor {
                    #if DEBUG
                    print("   Color: \(color.toHex() ?? "unknown")")
                    #endif
                }
                if let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle {
                    #if DEBUG
                    print("   Alignment: \(paragraphStyle.alignment.rawValue)")
                    #endif
                }
                if let textStyle = attrs[.textStyle] as? String {
                    #if DEBUG
                    print("   TextStyle attribute: \(textStyle)")
                    #endif
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
            
            #if DEBUG
            print("📝 Updated local state with styled content (model-based)")
            #endif
            
            // Create formatting command for undo/redo
            let command = FormatApplyCommand(
                description: "Paragraph Style",
                range: selectedRange,
                beforeContent: beforeContent,
                afterContent: newAttributedContent,
                targetFile: file
            )
            
            undoManager.execute(command)
            #if DEBUG
            print("📝 Paragraph style command added to undo stack")
            #endif
            #if DEBUG
            print("📝 ========== APPLY PARAGRAPH STYLE END ==========")
            #endif
            restoreKeyboardFocus()
            return
        }
        
        // Fallback to direct UIFont.TextStyle (for files not in a project)
        // Special handling for empty text
        if attributedContent.length == 0 {
            #if DEBUG
            print("📝 Text is empty - creating attributed string with style: \(style)")
            #endif
            
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
            
            #if DEBUG
            print("📝 Empty text styled - picker should update")
            #endif
            return
        }
        
        // Store before state for undo
        let beforeContent = attributedContent
        
        // Apply the style using TextFormatter
        newAttributedContent = TextFormatter.applyStyle(style, to: attributedContent, range: selectedRange)
        
        #if DEBUG
        print("📝 Paragraph style applied successfully")
        #endif
        
        // Update local state immediately for instant UI feedback
        attributedContent = newAttributedContent
        
        // Update the current style state
        currentParagraphStyle = style
        
        // Also update typing attributes so new text in this paragraph uses the style
        // This is especially important for empty paragraphs or when cursor is at paragraph end
        textViewCoordinator.modifyTypingAttributes { textView in
            textView.typingAttributes = TextFormatter.getTypingAttributes(for: style)
        }
        
        #if DEBUG
        print("📝 Updated local state with styled content")
        #endif
        
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
        
        #if DEBUG
        print("📝 Paragraph style command added to undo stack")
        #endif
        
        // Restore keyboard focus after applying style
        restoreKeyboardFocus()
    }
    
    // MARK: - Image Insertion
    
    private func showImagePicker() {
        #if DEBUG
        print("🖼️ showImagePicker() called")
        #endif
        // Note: On Mac Catalyst, Photos library is not accessible (PHPicker doesn't work)
        // So we show the source picker on iOS (Photos + Files), but go directly to Files on Mac
        #if targetEnvironment(macCatalyst)
        // Mac Catalyst: Go directly to file picker (only option available)
        showIOSImagePicker()
        #else
        // iOS: Let user choose between Photos and Files
        showImageSourcePicker = true
        #endif
    }
    
    private func showPhotosPickerFromCoordinator() {
        #if DEBUG
        print("📸 showPhotosPickerFromCoordinator() called")
        #endif
        
        // Set up the callback for when an image is picked
        textViewCoordinator.onImagePicked = { url in
            #if DEBUG
            print("📸 Coordinator callback received with URL: \(url.lastPathComponent)")
            #endif
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
            #if DEBUG
            print("📸 Presenting PHPicker")
            #endif
            topController.present(picker, animated: true)
        } else {
            #if DEBUG
            print("❌ Could not find root view controller to present PHPicker")
            #endif
        }
    }
    
    private func showIOSImagePicker() {
        #if DEBUG
        print("🖼️ Using iOS UIDocumentPickerViewController")
        #endif
        
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
        
        #if DEBUG
        print("🖼️ Document picker created, setting callback...")
        #endif
        
        // Store reference for when document is picked
        textViewCoordinator.onImagePicked = { url in
            #if DEBUG
            print("🖼️ onImagePicked callback triggered")
            #endif
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
            #if DEBUG
            print("🖼️ Presenting document picker...")
            #endif
            topController.present(picker, animated: true)
        } else {
            #if DEBUG
            print("❌ Failed to find root view controller")
            #endif
        }
    }
    
    private func handleImageSelection(url: URL) {
        #if DEBUG
        print("🖼️ Image selected: \(url.lastPathComponent)")
        #endif
        
        // Store the filename for later use
        let filename = url.lastPathComponent
        #if DEBUG
        print("🖼️ Captured filename: \(filename)")
        #endif
        
        // Check if this is a temp file (from PHPicker) or needs security scoping (from file picker)
        let isTempFile = url.path.starts(with: FileManager.default.temporaryDirectory.path)
        
        // Only use security-scoped resources for non-temp files (file picker)
        let needsSecurityScope = !isTempFile
        
        if needsSecurityScope {
            guard url.startAccessingSecurityScopedResource() else {
                #if DEBUG
                print("❌ Failed to access security-scoped resource")
                #endif
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
            #if DEBUG
            print("🖼️ Image data loaded: \(imageData.count) bytes")
            #endif
            
            // Compress the image
            if let compressedData = compressImageData(imageData) {
                #if DEBUG
                print("🖼️ Image compressed: \(compressedData.count) bytes")
                #endif
                
                // Insert image immediately with default settings from stylesheet
                DispatchQueue.main.async {
                    // Get default image style from project's stylesheet
                    // These values serve as INITIAL settings for the new image
                    // Once inserted, the image's properties can be customized independently
                    var scale: CGFloat = 1.0
                    var alignment: ImageAttachment.ImageAlignment = .center
                    var hasCaption = false
                    var captionStyle = "UICTFontTextStyleCaption1"
                    
                    if let project = self.file.project,
                       let stylesheet = project.styleSheet,
                       let imageStyles = stylesheet.imageStyles,
                       let defaultStyle = imageStyles.first(where: { $0.name == "default" }) {
                        scale = defaultStyle.defaultScale
                        alignment = defaultStyle.defaultAlignment
                        hasCaption = defaultStyle.hasCaptionByDefault
                        captionStyle = defaultStyle.defaultCaptionStyle
                        #if DEBUG
                        print("🖼️ Using image style '\(defaultStyle.displayName)': scale=\(scale), alignment=\(alignment.rawValue)")
                        #endif
                    } else {
                        #if DEBUG
                        print("🖼️ Using hardcoded defaults: scale=1.0, alignment=center")
                        #endif
                    }
                    
                    // Calculate scale to fit image to window width
                    if let uiImage = UIImage(data: compressedData),
                       let textView = self.textViewCoordinator.textView {
                        let imageWidth = uiImage.size.width
                        // Get available width (text view width minus container insets)
                        let availableWidth = textView.frame.width - textView.textContainerInset.left - textView.textContainerInset.right - (textView.textContainer.lineFragmentPadding * 2)
                        
                        #if DEBUG
                        print("🖼️ Image size check:")
                        #endif
                        #if DEBUG
                        print("   - uiImage.size: \(uiImage.size)")
                        #endif
                        #if DEBUG
                        print("   - uiImage.scale: \(uiImage.scale)")
                        #endif
                        #if DEBUG
                        print("   - imageWidth (points): \(imageWidth)")
                        #endif
                        #if DEBUG
                        print("   - availableWidth: \(availableWidth)")
                        #endif
                        #if DEBUG
                        print("   - textView.frame.width: \(textView.frame.width)")
                        #endif
                        
                        // Only scale down if image is wider than available space
                        if imageWidth > availableWidth {
                            let fitToWidthScale = availableWidth / imageWidth
                            // Clamp to valid range (0.1 to 2.0)
                            scale = max(0.1, min(2.0, fitToWidthScale))
                            #if DEBUG
                            print("🖼️ Image scaled to fit window: \(imageWidth)px → \(availableWidth)px, scale=\(scale)")
                            #endif
                        } else {
                            #if DEBUG
                            print("🖼️ Image fits naturally, using scale=\(scale)")
                            #endif
                        }
                    }
                    
                    #if DEBUG
                    print("🖼️ Inserting image with settings from stylesheet")
                    #endif
                    #if DEBUG
                    print("🖼️ Original filename: \(filename)")
                    #endif
                    self.insertImage(
                        imageData: compressedData,
                        scale: scale,
                        alignment: alignment,
                        hasCaption: hasCaption,
                        captionText: "",
                        captionStyle: captionStyle,
                        originalFilename: filename
                    )
                }
            } else {
                #if DEBUG
                print("❌ Failed to compress image")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ Error loading image: \(error)")
            #endif
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
        captionStyle: String,
        originalFilename: String? = nil
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
            originalFilename: originalFilename,
            targetFile: file
        )
        
        undoManager.execute(command)
        
        // Mark the time of insertion to prevent immediate editor popup
        lastImageInsertTime = Date()
        
        // Update local state to reflect the change
        let newContent = file.currentVersion?.attributedContent ?? NSAttributedString()
        #if DEBUG
        print("🖼️ Before update - attributedContent length: \(attributedContent.length)")
        #endif
        #if DEBUG
        print("🖼️ After command - newContent length: \(newContent.length)")
        #endif
        
        // Check if there's an attachment at the insertion point
        if newContent.length > insertionPoint {
            let attrs = newContent.attributes(at: insertionPoint, effectiveRange: nil)
            if let attachment = attrs[.attachment] as? NSTextAttachment {
                #if DEBUG
                print("🖼️ Found attachment at position \(insertionPoint): \(type(of: attachment))")
                #endif
            } else {
                #if DEBUG
                print("⚠️ NO attachment found at position \(insertionPoint)")
                #endif
                #if DEBUG
                print("⚠️ Character at \(insertionPoint): '\(newContent.string[newContent.string.index(newContent.string.startIndex, offsetBy: insertionPoint)])'")
                #endif
            }
        }
        
        attributedContent = newContent
        
        // Move cursor after the inserted image
        selectedRange = NSRange(location: insertionPoint + 1, length: 0)
        
        #if DEBUG
        print("🖼️ Image inserted at position \(insertionPoint) with scale \(scale)")
        #endif
        
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
            #if DEBUG
            print("⚠️ loadCurrentVersion: No current version found")
            #endif
            attributedContent = newAttributedContent
            previousContent = ""
            selectedRange = NSRange(location: 0, length: 0)
            forceRefresh.toggle()
            refreshTrigger = UUID()
            return
        }
        
        if let versionContent = currentVersion.attributedContent {
            // Version has saved content - use it
            // CRITICAL: Strip adaptive colors (black/white/gray) to support dark mode properly
            // This is especially important for legacy imports which may have fixed black text
            let processedContent = AttributedStringSerializer.stripAdaptiveColors(from: versionContent)
            
            // No iPhone-specific font changes - use view scale transform instead
            
            newAttributedContent = processedContent
            #if DEBUG
            print("📝 loadCurrentVersion: Loaded existing content, length: \(versionContent.length)")
            #endif
        } else {
            // New/empty version - initialize with Body style from project stylesheet
            if let project = file.project {
                let bodyAttrs = TextFormatter.getTypingAttributes(
                    forStyleNamed: UIFont.TextStyle.body.rawValue,
                    project: project,
                    context: modelContext
                )
                
                // No iPhone-specific font changes - use stylesheet fonts with view scale
                
                // Debug: Log what we're initializing with
                #if DEBUG
                print("📝 loadCurrentVersion: Initializing with Body style from stylesheet '\(project.styleSheet?.name ?? "none")'")
                #endif
                for (key, value) in bodyAttrs {
                    if key == .font {
                        let font = value as? UIFont
                        #if DEBUG
                        print("  - font: \(font?.fontName ?? "nil") \(font?.pointSize ?? 0)pt")
                        #endif
                    } else if key == .foregroundColor {
                        let color = value as? UIColor
                        #if DEBUG
                        print("  - foregroundColor: \(color?.toHex() ?? "nil")")
                        #endif
                    } else if key == .textStyle {
                        #if DEBUG
                        print("  - textStyle: \(value)")
                        #endif
                    }
                }
                
                newAttributedContent = NSAttributedString(string: "", attributes: bodyAttrs)
                #if DEBUG
                print("📝 loadCurrentVersion: Created empty attributed string with Body style")
                #endif
            } else {
                // Fallback if no project (shouldn't happen)
                newAttributedContent = NSAttributedString(
                    string: "",
                    attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
                )
                #if DEBUG
                print("⚠️ loadCurrentVersion: No project found, using system body font")
                #endif
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
        // IMPORTANT: Get the current content from the textView to include all attachments (comments, images)
        if let textView = textViewCoordinator.textView {
            let currentContent = textView.attributedText ?? NSAttributedString()
            
            // On iPhone, content is already normalized to 12pt for display
            // Save it as-is - no scaling needed since we normalize on load, not on save
            file.currentVersion?.attributedContent = currentContent
            
            // Count attachments for debugging
            var commentCount = 0
            var imageCount = 0
            var footnoteCount = 0
            currentContent.enumerateAttribute(.attachment, in: NSRange(location: 0, length: currentContent.length)) { value, range, _ in
                if value is CommentAttachment {
                    commentCount += 1
                } else if value is ImageAttachment {
                    imageCount += 1
                } else if value is FootnoteAttachment {
                    footnoteCount += 1
                }
            }
            #if DEBUG
            print("💾 Saving attributed content with \(commentCount) comments, \(imageCount) images, and \(footnoteCount) footnotes")
            #endif
        } else {
            var contentToSave = attributedContent
            
            // CRITICAL: Reverse the iPhone font scaling before saving
            if UIDevice.current.userInterfaceIdiom == .phone {
                contentToSave = AttributedStringSerializer.scaleFonts(contentToSave, scaleFactor: 1.0 / 0.55)
                #if DEBUG
                print("💾 Reversed iPhone font scaling (1/0.55 = \(1.0/0.55)x) before saving to database")
                #endif
            }
            
            file.currentVersion?.attributedContent = contentToSave
        }
        
        file.modifiedDate = Date()
        
        do {
            try modelContext.save()
            #if DEBUG
            print("💾 Saved attributed content on file close")
            #endif
        } catch {
            #if DEBUG
            print("Error saving context: \(error)")
            #endif
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
        #if DEBUG
        print("🖼️ Updating image: scale=\(scale), alignment=\(alignment.rawValue)")
        #endif
        
        // Find the attachment in the content
        guard let position = findAttachmentPosition(attachment) else {
            #if DEBUG
            print("❌ Could not find attachment in content")
            #endif
            return
        }
        
        // Capture the before state for undo/redo
        let beforeContent = attributedContent
        
        // Update the attachment properties
        let oldScale = attachment.scale
        let oldAlignment = attachment.alignment
        let oldHasCaption = attachment.hasCaption
        let oldCaptionText = attachment.captionText
        let oldCaptionStyle = attachment.captionStyle
        
        attachment.scale = scale
        attachment.alignment = alignment
        #if DEBUG
        print("🖼️ FileEditView.updateImage() - About to update caption")
        #endif
        attachment.updateCaption(hasCaption: hasCaption, text: captionText, style: captionStyle)
        #if DEBUG
        print("   After update: hasCaption=\(attachment.hasCaption), text=\(attachment.captionText ?? "nil")")
        #endif
        
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
            #if DEBUG
            print("✅ Image updated and saved")
            #endif
        } catch {
            #if DEBUG
            print("❌ Error saving image update: \(error)")
            #endif
        }
        
        // Create undo/redo command to restore image properties
        let command = ImageUpdateCommand(
            description: "Update Image",
            beforeContent: beforeContent,
            afterContent: mutableContent,
            attachment: attachment,
            oldScale: oldScale,
            oldAlignment: oldAlignment,
            oldHasCaption: oldHasCaption,
            oldCaptionText: oldCaptionText,
            oldCaptionStyle: oldCaptionStyle,
            newScale: scale,
            newAlignment: alignment,
            newHasCaption: hasCaption,
            newCaptionText: captionText,
            newCaptionStyle: captionStyle,
            targetFile: file
        )
        undoManager.execute(command)
        
        // Keep the image selected and update the selection to the image position
        selectedImage = attachment
        
        // Set the selected range to the image position so when the view refreshes,
        // the selection is preserved
        if let imagePosition = findAttachmentPosition(attachment) {
            selectedRange = NSRange(location: imagePosition, length: 1)
        }
        
        // Trigger view refresh to show updated image
        // Note: We rely on the notification system in ImageAttachmentViewProvider to update the view
        // Accessing layoutManager would force TextKit 1 mode, breaking NSTextAttachmentViewProvider
        refreshTrigger = UUID()
        
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

// MARK: - New Comment Sheet

private struct NewCommentSheet: View {
    @Binding var commentText: String
    let hasExistingComments: Bool
    let onAdd: () -> Void
    let onCancel: () -> Void
    let onShowComments: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("fileEdit.newComment.description")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                TextEditor(text: $commentText)
                    .frame(minHeight: 150)
                    .padding(8)
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(8)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal)
                    .accessibilityLabel("fileEdit.newComment.textEditor.accessibility")
                
                // Show Comments button (only if there are existing comments)
                if hasExistingComments {
                    Button(action: {
                        dismiss()
                        onShowComments()
                    }) {
                        Label("Show Comments", systemImage: "bubble.left.and.bubble.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("fileEdit.newComment.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.add") {
                        onAdd()
                        dismiss()
                    }
                    .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct NewFootnoteSheet: View {
    @Binding var footnoteText: String
    let onAdd: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("fileEdit.newFootnote.description")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                TextEditor(text: $footnoteText)
                    .frame(minHeight: 150)
                    .padding(8)
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(8)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal)
                    .accessibilityLabel("fileEdit.newFootnote.textEditor.accessibility")
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("fileEdit.newFootnote.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.add") {
                        onAdd()
                        dismiss()
                    }
                    .disabled(footnoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
