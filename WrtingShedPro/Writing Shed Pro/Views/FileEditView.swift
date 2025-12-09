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
                // iPhone: No GeometryReader needed, use direct layout
                ZStack(alignment: .topLeading) {
                    if forceRefresh {
                        FormattedTextEditor(
                            attributedText: $attributedContent,
                            selectedRange: $selectedRange,
                            textViewCoordinator: textViewCoordinator,
                            textContainerInset: UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4),
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
                            textContainerInset: UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4),
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
            } else {
                // iPad: Use GeometryReader for percentage-based padding
                GeometryReader { geometry in
                    ZStack(alignment: .topLeading) {
                        if forceRefresh {
                            FormattedTextEditor(
                                attributedText: $attributedContent,
                                selectedRange: $selectedRange,
                                textViewCoordinator: textViewCoordinator,
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
                            Label("Add Comment", systemImage: "square.and.pencil")
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
                            Label("Add Footnote", systemImage: "square.and.pencil")
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
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        textEditorSection()
                        
                        formattingToolbar()
                            .offset(y: geometry.safeAreaInsets.bottom)
                    }
                }
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
    }
    
    var body: some View {
        mainContent
            .navigationTitle(file.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
                            print("🗑️ FootnoteDetailView onDelete callback triggered for footnote: \(footnote.id)")
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
            .onDisappear {
                // Disconnect search manager to clean up highlights and observers
                searchManager.disconnect()
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
        print("🔍 Setting up search from multi-file context: '\(context.searchText)'")
        
        // Connect search manager to text view first
        guard let textView = textViewCoordinator.textView else {
            print("⚠️ Text view not ready, cannot activate search")
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
                print("🔍 Ensuring first match is visible")
            }
        }
        
        // Reset the context so it won't activate again
        context.reset()
        
        print("🔍 Search activated: \(searchManager.totalMatches) matches found, search bar visible: \(showSearchBar), simplified mode: \(isSimplifiedSearchMode)")
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
        
        // Always jump to latest version when opening a file
        file.selectLatestVersion()
        
        // Check if version is locked before allowing editing
        if file.currentVersion?.isLocked == true {
            showLockedVersionWarning = true
        }
        
        // Load content from database on first appearance
        if attributedContent.length == 0, let savedContent = file.currentVersion?.attributedContent {
            print("📂 onAppear: Initial load of content, length: \(savedContent.length)")
            // Strip adaptive colors (black/white/gray) to support dark mode properly
            attributedContent = AttributedStringSerializer.stripAdaptiveColors(from: savedContent)
            previousContent = attributedContent.string
            
            // CRITICAL: Restore orphaned comment markers from database
            // Comments created before we added serialization support need to be re-inserted
            restoreOrphanedCommentMarkers()
            
            // Position cursor at beginning of text (unless opening from search, which will position at first match)
            if searchContext == nil || searchContext?.shouldActivate == false {
                selectedRange = NSRange(location: 0, length: 0)
            }
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
                // CRITICAL: Don't reapply styles to legacy RTF documents!
                // Legacy imports have direct formatting (bold/italic) baked in, not stylesheet styles
                // Reapplying styles would destroy all the bold/italic formatting
                let isLegacyRTF = file.currentVersion?.formattedContent != nil && 
                                  file.currentVersion?.formattedContent?.count ?? 0 > 0
                
                if !isLegacyRTF {
                    print("📝 onAppear: Reapplying styles to pick up any changes")
                    reapplyAllStyles()
                } else {
                    print("📝 onAppear: Skipping style reapply for legacy RTF document (preserves direct formatting)")
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
                }
                print("📝 onAppear: Set typing attributes for empty document from stylesheet")
            }
        }
        
        // Check if we should activate search from multi-file search context
        if let context = searchContext, context.shouldActivate {
            print("🔍 Activating search from multi-file search context")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                activateSearchFromContext(context)
            }
        }
    }
    
    private func handleImagePasted() {
        print("🖼️ Received ImageWasPasted notification - updating lastImageInsertTime")
        lastImageInsertTime = Date()
    }
    
    private func handleStyleSheetChanged(_ notification: Notification) {
        print("📋 ========== ProjectStyleSheetChanged NOTIFICATION ===========")
        print("📋 Notification userInfo: \(notification.userInfo ?? [:])")
        
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
        
        if attributedContent.length > 0 {
            print("📋 Reapplying all styles due to stylesheet change")
            reapplyAllStyles()
        } else {
            print("📋 Document is empty, skipping reapply")
        }
        print("📋 ========== END ==========")
    }
    
    private func handleStyleSheetModified(_ notification: Notification) {
        print("📝 ========== StyleSheetModified NOTIFICATION ===========")
        print("📝 Notification userInfo: \(notification.userInfo ?? [:])")
        
        guard let notifiedStyleSheetID = notification.userInfo?["stylesheetID"] as? UUID else {
            print("⚠️ No stylesheetID in notification")
            print("📝 ========== END ==========")
            return
        }
        
        guard let ourStyleSheetID = file.project?.styleSheet?.id else {
            print("⚠️ Our file has no project or stylesheet")
            print("📝 ========== END ==========")
            return
        }
        
        print("📝 Notified stylesheet ID: \(notifiedStyleSheetID.uuidString)")
        print("📝 Our stylesheet ID: \(ourStyleSheetID.uuidString)")
        print("📝 Match: \(notifiedStyleSheetID == ourStyleSheetID)")
        
        guard notifiedStyleSheetID == ourStyleSheetID else {
            print("📝 Not for us - ignoring")
            print("📝 ========== END ==========")
            return
        }
        
        print("📝 Received StyleSheetModified notification for our stylesheet")
        
        if attributedContent.length > 0 {
            print("📝 Reapplying all styles due to style modification")
            reapplyAllStyles()
        } else {
            print("📝 Document is empty, skipping reapply")
        }
        print("📝 ========== END ==========")
    }
    
    private func handleFootnoteNumbersChanged(_ notification: Notification) {
        print("🔢 Received footnoteNumbersDidChange notification")
        
        guard let versionIDString = notification.userInfo?["versionID"] as? String,
              let notifiedVersionID = UUID(uuidString: versionIDString) else {
            print("⚠️ No versionID in notification")
            return
        }
        
        guard let currentVersion = file.currentVersion else {
            print("⚠️ No current version")
            return
        }
        
        guard notifiedVersionID == currentVersion.id else {
            print("🔢 Not for our version - ignoring")
            return
        }
        
        print("🔢 Updating footnote attachment numbers for our version")
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
                    print("🔢 Updating attachment \(attachment.footnoteID) from \(attachment.number) to \(footnote.number)")
                    attachment.number = footnote.number
                    needsUpdate = true
                }
            } else {
                print("⚠️ Footnote not found in database for attachmentID: \(attachment.footnoteID)")
            }
        }
        
        if needsUpdate {
            // Update the attributed content
            attributedContent = mutableContent
            print("✅ Footnote attachment numbers updated")
        }
    }
    
    /// Handle undo/redo content restoration notification from FormatApplyCommand
    private func handleUndoRedoContentRestored(_ notification: Notification) {
        guard let restoredContent = notification.userInfo?["content"] as? NSAttributedString else {
            print("⚠️ handleUndoRedoContentRestored - no content in notification")
            return
        }
        
        print("🔄 handleUndoRedoContentRestored - updating UI with restored content")
        
        // Update the UI with restored content
        attributedContent = restoredContent
        previousContent = restoredContent.string
        
        // Position cursor at end
        selectedRange = NSRange(location: restoredContent.length, length: 0)
        
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
                    print("🔄 Reconnecting search manager to new text view after undo/redo")
                    self.searchManager.connect(to: textView)
                    // Also reconnect to the custom undo manager
                    self.searchManager.customUndoManager = self.undoManager
                    // Notify search manager that content changed (undo/redo)
                    self.searchManager.notifyTextChanged()
                } else {
                    print("⚠️ No text view available to reconnect search manager")
                }
            }
        }
    }
    
    // MARK: - Attributed Text Handling
    
    private func handleAttributedTextChange(_ newAttributedText: NSAttributedString) {
        #if DEBUG
        print("🔄 handleAttributedTextChange called")
        print("🔄 isPerformingUndoRedo: \(isPerformingUndoRedo)")
        print("🔄 isPerformingBatchReplace: \(searchManager.isPerformingBatchReplace)")
        #endif
        
        guard !isPerformingUndoRedo else {
            print("🔄 Skipping - performing undo/redo")
            return
        }
        
        // Skip during batch replace - undo will be handled manually
        guard !searchManager.isPerformingBatchReplace else {
            print("🔄 Skipping - performing batch replace")
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
        // IMPORTANT: Use FormatApplyCommand to preserve formatting, not TextDiffService (which only stores plain text)
        let previousAttributedContent = file.currentVersion?.attributedContent ?? NSAttributedString(
            string: previousContent,
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )
        
        let command = FormatApplyCommand(
            description: "Typing",
            range: NSRange(location: 0, length: newAttributedText.length),
            beforeContent: previousAttributedContent,
            afterContent: newAttributedText,
            targetFile: file
        )
        undoManager.execute(command)
        
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
    
    // MARK: - Comment Handling
    
    private func handleCommentTap(attachment: CommentAttachment, position: Int) {
        print("💬 Comment tapped at position \(position)")
        print("💬 Comment ID: \(attachment.commentID)")
        
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
                print("💬 Found comment in database, showing detail view")
                selectedCommentForDetail = comment
            } else {
                print("⚠️ Comment not found in database for ID: \(commentID)")
            }
        } catch {
            print("❌ Error fetching comment: \(error)")
        }
    }
    
    private func handleFootnoteTap(attachment: FootnoteAttachment, position: Int) {
        print("🔢 Footnote tapped at position \(position)")
        print("🔢 Attachment footnoteID: \(attachment.footnoteID)")
        
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
                print("🔢 Found footnote in database:")
                print("   - Database ID: \(footnote.id)")
                print("   - AttachmentID: \(footnote.attachmentID)")
                print("   - Number: \(footnote.number)")
                selectedFootnoteForDetail = footnote
            } else {
                print("⚠️ Footnote not found in database for attachmentID: \(attachmentID)")
            }
        } catch {
            print("❌ Error fetching footnote: \(error)")
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
            print("❌ Cannot insert comment: no current version")
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
                print("💬 Comment inserted: \(comment.text)")
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
            print("❌ Cannot insert footnote: no current version")
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
                print("🔢 Footnote inserted: \(footnote.text)")
                
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
            print("❌ Cannot remove footnote: no text view")
            return
        }
        
        print("🗑️ Removing footnote \(footnote.id) from text (attachmentID: \(footnote.attachmentID))")
        
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
                print("❌ Error saving context: \(error)")
            }
            
            // Update attributedContent LAST, after flag is set
            // This ensures the observer sees isPerformingUndoRedo = true
            attributedContent = updatedText
            
            print("✅ Footnote removed from position \(removedRange.location)")
        } else {
            print("⚠️ Footnote attachment not found in text")
        }
        
        // Reset flag AFTER attributedContent update completes
        // Use asyncAfter with minimal delay to ensure binding update has fired
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.isPerformingUndoRedo = false
            print("🗑️ Reset isPerformingUndoRedo flag")
        }
    }
    
    
    
    private func insertPageBreak() {
        print("📄 Inserting page break at cursor")
        
        guard let textView = textViewCoordinator.textView else {
            print("❌ Cannot insert page break: no text view")
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
        
        print("✅ Page break inserted at position \(currentRange.location)")
    }
    
    private func updateComment(_ comment: CommentModel, newText: String) {
        comment.updateText(newText)
        try? modelContext.save()
        print("💬 Comment updated: \(newText)")
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
        print("💬 Comment deleted")
    }
    
    private func removeCommentMarker(_ comment: CommentModel) {
        // Remove the comment marker from text (called when comment is deleted from detail view)
        attributedContent = CommentInsertionHelper.removeComment(
            from: attributedContent,
            commentID: comment.attachmentID
        )
        
        // Save
        saveChanges()
        print("💬 Comment marker removed: \(comment.attachmentID)")
    }
    
    private func toggleCommentResolved(_ comment: CommentModel) {
        print("💬 toggleCommentResolved called - current state: \(comment.isResolved)")
        
        if comment.isResolved {
            comment.reopen()
        } else {
            comment.resolve()
        }
        
        print("💬 After toggle - new state: \(comment.isResolved)")
        print("💬 Comment attachmentID: \(comment.attachmentID)")
        
        // Update visual indicator in text
        let updatedContent = CommentInsertionHelper.updateCommentResolvedState(
            in: attributedContent,
            commentID: comment.attachmentID,
            isResolved: comment.isResolved
        )
        
        print("💬 Updated content length: \(updatedContent.length)")
        print("💬 Original content length: \(attributedContent.length)")
        
        // Force update the text view to show the new marker color
        if let textView = textViewCoordinator.textView {
            print("💬 Updating textView with new resolved state")
            
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
            
            print("💬 TextView updated and forced to redraw")
        } else {
            print("⚠️ textView is nil!")
        }
        
        // Update SwiftUI state
        attributedContent = updatedContent
        
        try? modelContext.save()
        saveChanges()
        print("💬 Comment resolved state saved: \(comment.isResolved)")
    }
    
    /// Update the visual marker for a comment after its resolved state changes externally (e.g., from CommentsListView)
    private func refreshCommentMarker(_ comment: CommentModel) {
        print("💬🔄 refreshCommentMarker called for comment: \(comment.attachmentID)")
        print("💬🔄 Current resolved state: \(comment.isResolved)")
        
        // Update visual indicator in text
        let updatedContent = CommentInsertionHelper.updateCommentResolvedState(
            in: attributedContent,
            commentID: comment.attachmentID,
            isResolved: comment.isResolved
        )
        
        // Force update the text view to show the new marker color
        if let textView = textViewCoordinator.textView {
            print("💬🔄 Updating textView with new resolved state")
            
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
            
            print("💬🔄 TextView updated and forced to redraw")
        }
        
        // Update SwiftUI state
        attributedContent = updatedContent
        
        saveChanges()
        print("💬🔄 Comment marker refreshed: resolved=\(comment.isResolved)")
    }
    
    /// Restore comment markers from the database for comments that were created before serialization support
    /// This handles "orphaned" comments that exist in the database but don't have markers in the attributed text
    private func restoreOrphanedCommentMarkers() {
        print("💬🔧 Checking for orphaned comment markers...")
        
        // Get all comments for this version from the relationship
        guard let currentVersion = file.currentVersion else {
            print("💬🔧 No current version available")
            return
        }
        
        let allComments = currentVersion.comments ?? []
        
        guard !allComments.isEmpty else {
            print("💬🔧 No comments found in version")
            return
        }
        
        print("💬🔧 Found \(allComments.count) comments in version")
        
        // Check which comments are missing from the attributed text
        let mutableText = NSMutableAttributedString(attributedString: attributedContent)
        var existingCommentIDs = Set<UUID>()
        
        // Find all existing comment attachments
        mutableText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutableText.length)) { value, _, _ in
            if let commentAttachment = value as? CommentAttachment {
                existingCommentIDs.insert(commentAttachment.commentID)
            }
        }
        
        print("💬🔧 Found \(existingCommentIDs.count) existing comment markers in text")
        
        // Find orphaned comments
        let orphanedComments = allComments.filter { !existingCommentIDs.contains($0.attachmentID) }
        
        guard !orphanedComments.isEmpty else {
            print("💬🔧 No orphaned comments found - all good!")
            return
        }
        
        print("💬🔧 Found \(orphanedComments.count) orphaned comments - restoring markers...")
        
        // Insert markers for orphaned comments (in reverse order to maintain positions)
        for comment in orphanedComments.reversed() {
            let position = min(comment.characterPosition, mutableText.length)
            let attachment = CommentAttachment(commentID: comment.attachmentID, isResolved: comment.isResolved)
            let attachmentString = NSAttributedString(attachment: attachment)
            
            mutableText.insert(attachmentString, at: position)
            print("💬🔧 Restored marker for comment '\(comment.text)' at position \(position)")
        }
        
        // Update the attributed content
        attributedContent = mutableText
        print("💬🔧 ✅ Restored \(orphanedComments.count) orphaned comment markers")
        
        // Save the restored markers
        saveChanges()
    }
    
    // MARK: - Undo/Redo
    
    private func performUndo() {
        print("🔄 performUndo called - canUndo: \(undoManager.canUndo)")
        guard undoManager.canUndo else { return }
        
        isPerformingUndoRedo = true
        
        // Execute the undo command
        // FormatApplyCommand will restore the attributed content and post a notification
        // that we listen for in handleUndoRedoContentRestored()
        undoManager.undo()
        
        print("🔄 Undo command executed")
        
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
    
    // MARK: - Printing
    
    /// Handle print action
    private func printFile() {
        print("🖨️ Print button tapped")
        
        // Save any pending changes before printing
        saveChanges()
        
        // Get the view controller to present from
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let viewController = window.rootViewController else {
            print("❌ Could not find view controller for print dialog")
            printErrorMessage = "Unable to present print dialog"
            showPrintError = true
            return
        }
        
        // Call print service (need project for stylesheet)
        guard let project = file.project else {
            print("❌ Could not find project for file")
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
                print("❌ Print failed: \(error.localizedDescription)")
                printErrorMessage = error.localizedDescription
                showPrintError = true
            } else if success {
                print("✅ Print completed successfully")
            } else {
                print("⚠️ Print was cancelled")
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
                    
                    // Calculate scale to fit image to window width
                    if let uiImage = UIImage(data: compressedData),
                       let textView = self.textViewCoordinator.textView {
                        let imageWidth = uiImage.size.width
                        // Get available width (text view width minus container insets)
                        let availableWidth = textView.frame.width - textView.textContainerInset.left - textView.textContainerInset.right - (textView.textContainer.lineFragmentPadding * 2)
                        
                        // Only scale down if image is wider than available space
                        if imageWidth > availableWidth {
                            let fitToWidthScale = availableWidth / imageWidth
                            // Clamp to valid range (0.1 to 2.0)
                            scale = max(0.1, min(2.0, fitToWidthScale))
                            print("🖼️ Image scaled to fit window: \(imageWidth)px → \(availableWidth)px, scale=\(scale)")
                        } else {
                            print("🖼️ Image fits naturally, using scale=\(scale)")
                        }
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
            // CRITICAL: Strip adaptive colors (black/white/gray) to support dark mode properly
            // This is especially important for legacy imports which may have fixed black text
            var processedContent = AttributedStringSerializer.stripAdaptiveColors(from: versionContent)
            
            // Scale fonts for iPhone to match visual appearance
            if UIDevice.current.userInterfaceIdiom == .phone {
                processedContent = AttributedStringSerializer.scaleFonts(processedContent, scaleFactor: 0.80)
                print("📝 loadCurrentVersion: Scaled fonts to 80% for iPhone")
            }
            
            newAttributedContent = processedContent
            print("📝 loadCurrentVersion: Loaded existing content, length: \(versionContent.length)")
        } else {
            // New/empty version - initialize with Body style from project stylesheet
            if let project = file.project {
                var bodyAttrs = TextFormatter.getTypingAttributes(
                    forStyleNamed: UIFont.TextStyle.body.rawValue,
                    project: project,
                    context: modelContext
                )
                
                // Scale font for iPhone
                if UIDevice.current.userInterfaceIdiom == .phone, let font = bodyAttrs[.font] as? UIFont {
                    let scaledFont = font.withSize(font.pointSize * 0.80)
                    bodyAttrs[.font] = scaledFont
                    print("📝 loadCurrentVersion: Scaled Body font to 80% for iPhone (\(font.pointSize)pt -> \(scaledFont.pointSize)pt)")
                }
                
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
        // IMPORTANT: Get the current content from the textView to include all attachments (comments, images)
        if let textView = textViewCoordinator.textView {
            let currentContent = textView.attributedText ?? NSAttributedString()
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
            print("💾 Saving attributed content with \(commentCount) comments, \(imageCount) images, and \(footnoteCount) footnotes")
        } else {
            file.currentVersion?.attributedContent = attributedContent
        }
        
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
