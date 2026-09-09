import SwiftUI
import SwiftData
import ToolbarSUI
import UniformTypeIdentifiers
import PhotosUI

enum StyleReapplicationAttributeMerger {
    static func merge(
        styleAttributes: [NSAttributedString.Key: Any],
        currentAttributes: [NSAttributedString.Key: Any]
    ) -> [NSAttributedString.Key: Any] {
        var merged = styleAttributes

        if let newFont = styleAttributes[.font] as? UIFont {
            let baseTraits = FontFaceResolver.traits(of: newFont)
            let bold = currentAttributes[.explicitBold] as? Bool ?? baseTraits.bold
            let italic = currentAttributes[.explicitItalic] as? Bool ?? baseTraits.italic
            merged[.font] = FontFaceResolver.resolvedFont(from: newFont, bold: bold, italic: italic)
            if let explicitBold = currentAttributes[.explicitBold] { merged[.explicitBold] = explicitBold }
            if let explicitItalic = currentAttributes[.explicitItalic] { merged[.explicitItalic] = explicitItalic }
            if currentAttributes[.explicitBold] != nil || currentAttributes[.explicitItalic] != nil {
                merged[.inlineFormattingBaseFontName] = newFont.fontName
            }
        }

        if let attachment = currentAttributes[.attachment] {
            merged[.attachment] = attachment
            if let attachmentParagraphStyle = currentAttributes[.paragraphStyle] {
                merged[.paragraphStyle] = attachmentParagraphStyle
            }
        }

        if let poemSectionType = currentAttributes[.poemSectionType] {
            merged[.poemSectionType] = poemSectionType
            merged[.foregroundColor] = UIColor.systemGray
        }

        if currentAttributes[.spellingIgnored] as? Bool == true {
            merged[.spellingIgnored] = true
        }

        if merged[.underlineStyle] == nil, let underlineStyle = currentAttributes[.underlineStyle] {
            merged[.underlineStyle] = underlineStyle
        }
        if merged[.strikethroughStyle] == nil, let strikethroughStyle = currentAttributes[.strikethroughStyle] {
            merged[.strikethroughStyle] = strikethroughStyle
        }

        return merged
    }

    static func reapplyStyles(
        in source: NSAttributedString,
        resolveStyle: (String) -> TextStyleModel?
    ) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: source)
        var styleRuns: [(name: String, range: NSRange)] = []
        mutable.enumerateAttribute(
            .textStyle,
            in: NSRange(location: 0, length: mutable.length),
            options: []
        ) { value, range, _ in
            guard let name = value as? String else { return }
            styleRuns.append((name, range))
        }

        for styleRun in styleRuns {
            guard let style = resolveStyle(styleRun.name) else { continue }
            let styleAttributes = style.generateAttributes()
            var attributeRuns: [([NSAttributedString.Key: Any], NSRange)] = []
            mutable.enumerateAttributes(in: styleRun.range, options: []) { attributes, range, _ in
                attributeRuns.append((attributes, range))
            }
            for (attributes, range) in attributeRuns {
                mutable.setAttributes(
                    merge(styleAttributes: styleAttributes, currentAttributes: attributes),
                    range: range
                )
            }
        }

        return mutable
    }

    static func hasStyleMismatch(
        in source: NSAttributedString,
        resolveStyle: (String) -> TextStyleModel?
    ) -> Bool {
        guard source.length > 0 else { return false }

        var hasMismatch = false
        source.enumerateAttributes(
            in: NSRange(location: 0, length: source.length),
            options: []
        ) { attributes, _, stop in
            guard let styleName = attributes[.textStyle] as? String,
                  let style = resolveStyle(styleName) else {
                return
            }

            let expectedAttributes = merge(
                styleAttributes: style.generateAttributes(),
                currentAttributes: attributes
            )
            guard let expectedFont = expectedAttributes[.font] as? UIFont else {
                return
            }

            guard let currentFont = attributes[.font] as? UIFont,
                  currentFont.fontName.caseInsensitiveCompare(expectedFont.fontName) == .orderedSame,
                  abs(currentFont.pointSize - expectedFont.pointSize) < 0.01 else {
                hasMismatch = true
                stop.pointee = true
                return
            }

            if style.numberFormat != .none,
               style.styleCategory != .list,
               let expectedParagraph = expectedAttributes[.paragraphStyle] as? NSParagraphStyle {
                let currentIndent = (attributes[.paragraphStyle] as? NSParagraphStyle)?.firstLineHeadIndent ?? 0
                if abs(currentIndent - expectedParagraph.firstLineHeadIndent) >= 0.01 {
                    hasMismatch = true
                    stop.pointee = true
                }
            }
        }

        return hasMismatch
    }
}

/// Data for presenting the new index entry dialog
/// Using Identifiable allows us to use sheet(item:) pattern which is more reliable than sheet(isPresented:)
struct NewIndexEntryData: Identifiable {
    let id = UUID()
    let project: Project
    let prefilledKeyword: String?
}

struct FileEditView: View {
    private static let editorZoomScaleDefaultsKey = "editorZoomScale"
    private static let showLineNumbersDefaultsKey = "showDocumentLineNumbers"
    private let styleSheetRegistrationOwnerID = UUID()
    private let initialCharacterPosition: Int?
    private let initialHeadingText: String?

    @Environment(\.scenePhase) private var scenePhase

        @State private var presentDeleteBackMatterAlert = false
    @Bindable var file: TextFile
    
    // Track version index changes explicitly for toolbar updates
    @State private var currentVersionIndex: Int = 0
    
    @State private var attributedContent: NSAttributedString
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var previousContent: String = ""
    @State private var previousAttributedContent: NSAttributedString?  // Track for undo without expensive DB fetch
    @State private var saveDebounceTimer: Timer?  // Debounce saves to reduce I/O
    @State private var pendingDebouncedAttributedContent: NSAttributedString?
    @State private var pendingDebouncedSaveNeedsTextViewSnapshot = false
    @State private var endnoteCleanupTimer: Timer?  // Debounce endnote cleanup
    @State private var validationBadgeTimer: Timer?  // Debounce poetry validation
    /// True when the loaded content has U+FFFC placeholders but the corresponding
    /// ImageAttachments are missing from formattedContent (CloudKit sync incomplete).
    /// While set, saves are suppressed to avoid overwriting the phone's full content.
    @State private var hasMissingAttachments = false
    @State private var hasMismatchedFormattedContent = false
    @State private var hasMissingSyncedBody = false
    @State private var showMissingBodyEditConfirmation = false
    @State private var presentDeleteAlert = false
    @State private var presentClearTextAlert = false
    @State private var showClearTextToast = false
    @State private var clearTextToastTask: Task<Void, Never>?
    @State private var isPerformingUndoRedo = false
    @State private var refreshTrigger = UUID()
    @State private var forceRefresh = false
    @State private var showStylePicker = false
    @State private var needsStyleReapplyAfterPickerDismiss = false
    @State private var hasPendingStyleReapply = false
    @State private var allowsLegacyStyleReapply = false
    @State private var isReapplyingStyles = false
    @State private var hasPendingRemoteRefresh = false
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
    @State private var showImageSourcePicker = false // Show Photos vs Files chooser
    @State private var isPaginationMode = false // Toggle between edit and pagination preview modes
    @State private var showInvisibles = false // Toggle to show invisible characters (spaces, tabs, paragraph marks, page breaks)
    @State private var showLineNumbers = false // Toggle to show editor line numbers in right gutter
    @State private var isPreviewingAsAlternateFormat = false // When true, showing file in opposite format (non-destructive preview)
    @State private var prePreviewContent: NSAttributedString? // Stores original content before entering preview mode
    @State private var editorZoomScale: CGFloat = 1.0 // User-controlled zoom for text editor
    @State private var lastEditorZoomScale: CGFloat = 1.0 // Baseline scale for pinch gesture
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
    @State private var isInsertingFootnote = false
    
    // Feature 029: Notes & Endnotes (Back Matter)
    @State private var showNotesList = false
    @State private var showNewNoteDialog = false
    @State private var showNewEndnoteDialog = false
    @State private var selectedNoteForDetail: NoteEntry?
    @State private var pendingNoteInsertion: NoteEntry?  // Note to insert marker for after sheet closes
    
    // Feature 029: Glossary (Back Matter)
    @State private var showGlossaryList = false
    @State private var showNewGlossaryTermDialog = false
    @State private var selectedGlossaryTerm: GlossaryEntry?
    @State private var glossaryTermFromContextMenu: String?  // Term selected from context menu "Add to Glossary"
    
    // Feature 029: Index (Back Matter)
    @State private var showIndexList = false
    @State private var newIndexEntryData: NewIndexEntryData?  // Data for new index entry dialog (using sheet(item:) pattern)
    @State private var selectedIndexEntry: IndexEntry?
    
    // Feature 029: References (Back Matter)
    @State private var showReferencesList = false
    @State private var showNewReferenceDialog = false
    @State private var selectedReference: ReferenceEntry?
    
    // Feature 029: Reference interaction (single-tap support)
    @State private var showReferenceEditor = false
    @State private var selectedReferenceAttachment: ReferenceAttachment?
    @State private var selectedReferencePosition: Int = 0
    
    // Feature 020: Printing
    @State private var showPrintError = false
    @State private var printErrorMessage = ""
    
    // IAP gating
    @State private var upgradePromptReason: UpgradePromptReason?
    
    // Feature 021: Smart Poetry Creation
    @State private var showPoetryFormReference = false
    @State private var showPoetryMetrics = false
    @State private var showPoetryFormPicker = false
    @State private var cachedValidationIssueCount: Int = 0  // Cached to avoid expensive recomputation on every render
    
    // Feature 022: Smart Fiction Creation
    @State private var selectedPlotElement: PlotElement?
    @State private var selectedCharacter: Character?
    @State private var selectedLocation: Location?
    
    // Feature 022/023: Character and Location Autocomplete
    @State private var showCharacterPicker = false
    @State private var showLocationPicker = false
    
    // Feature 022/023: View project details from editor
    @State private var showProjectCharacters = false
    @State private var showProjectLocations = false
    @State private var showProjectPlot = false
    
    // Feature 017: Search and Replace
    @State private var showSearchBar = false
    @State private var searchManager = InEditorSearchManager()
    @State private var isSimplifiedSearchMode = false  // True when opened from multi-file search with replace
    @State private var isFromMultiFileSearch = false  // True when opened from any multi-file search
    @State private var showSpellingBar = false
    @State private var spellingManager = DocumentSpellingManager()
    
    // Feature 031: Table of Contents
    @State private var showTOCSettings = false
    @State private var isCalculatingTOCPages = false  // Progress indicator for page calculation
    
    // Feature 112: Table of Figures
    @State private var showTableOfFiguresSettings = false

    // Feature 040: Manuscript Analyst
    @State private var showManuscriptAnalyst = false
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SearchContext.self) private var searchContext: SearchContext?
    @Environment(ContentViewState.self) private var contentViewState
    
    enum VersionAction: Int {
        case previous
        case next
        case add
        case delete
    }
    
    init(file: TextFile, initialCharacterPosition: Int? = nil, initialHeadingText: String? = nil) {
        self.file = file
        self.initialCharacterPosition = initialCharacterPosition
        self.initialHeadingText = initialHeadingText
        
        // Initialize with empty content - will load in onAppear to avoid repeated init calls
        let emptyAttributed = NSAttributedString(
            string: "",
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )
        
        _attributedContent = State(initialValue: emptyAttributed)
        _previousContent = State(initialValue: "")
        _selectedRange = State(initialValue: NSRange(location: 0, length: 0))
        
        // Always start a fresh undo session when opening a file, unless this is a synced-empty
        // shell. Mutating undo fields for a shell record creates local sync noise while the
        // actual body is still missing from this device.
        if !Self.isMissingSyncedBody(file.currentVersion) {
            file.clearUndoHistory()
        }
        let newManager = TextFileUndoManager(file: file)
        _undoManager = State(initialValue: newManager)
    }
    
    // MARK: - Body Components
    
    private func versionToolbar() -> some View {
        // Access version count directly to ensure UI updates when versions change
        let versionCount = file.versions?.count ?? 0
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
                disabled: isFormattedContentSyncIncomplete
            ),
            SUIToolbarItem(
                icon: "trash.circle",
                title: "Delete this version",
                disabled: versionCount <= 1
            )
        ]
        
        return ToolbarView(
            label: file.versionLabel(),
            items: versionItems
        ) { action in
            #if DEBUG
            print("📝 ToolbarView action callback: \(action)")
            #endif
            handleVersionAction(VersionAction(rawValue: action) ?? .next)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .zIndex(100)  // Ensure toolbar is above any overlays
        .id(refreshTrigger)  // Force re-render when versions change
    }
    
    private func editorScalingControls() -> some View {
        HStack(spacing: 4) {
            Button {
                setEditorZoomScale(editorZoomScale - 0.05)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            
            VStack(spacing: 0) {
                Text("\(editorZoomPercent)%")
                Text(localizedEditorWordCount)
                    .lineLimit(1)
            }
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(minWidth: 64, alignment: .center)
            
            Button {
                setEditorZoomScale(editorZoomScale + 0.05)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            
            Button {
                setEditorZoomScale(1.0)
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
    
    private var editorZoomPercent: Int {
        Int(round(editorZoomScale * 100))
    }

    private var localizedEditorWordCount: String {
        let count = attributedContent.string
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
        let key = count == 1 ? "common.wordCountSingularFormat" : "common.wordCountPluralFormat"
        return String(format: NSLocalizedString(key, comment: "Word count format"), count)
    }

    /// Glossary/Index marker insertion is only valid in body files, not
    /// manuscript front matter or back matter files.
    private var canInsertGlossaryAndIndexMarkers: Bool {
        let folderName = file.parentFolder?.name ?? ""
        return folderName != "Front Matter" && !file.isBackMatterFile
    }

    /// Glossary marker commands should only be available in body files
    /// when the Glossary section is enabled in Back Matter settings.
    private var canAddGlossaryMarkers: Bool {
        canInsertGlossaryAndIndexMarkers && backMatterSettings.isEnabled(.glossary)
    }

    /// Index marker commands should only be available in body files
    /// when the Index section is enabled in Back Matter settings.
    private var canAddIndexMarkers: Bool {
        canInsertGlossaryAndIndexMarkers && backMatterSettings.isEnabled(.index)
    }

    private var manuscriptCaptionNumberOffsets: [String: Int] {
        guard let project = file.project else { return [:] }
        return ManuscriptAssemblyService(context: modelContext)
            .captionNumberOffsets(for: file, in: project)
    }

    private var manuscriptHeadingNumberState: (styleCounters: [String: Int], lastNumberForStyle: [String: Int]) {
        guard let project = file.project else { return ([:], [:]) }
        return ManuscriptAssemblyService(context: modelContext)
            .headingNumberCounterState(for: file, in: project)
    }
    
    private func textEditorSection() -> some View {
        let headingNumberState = manuscriptHeadingNumberState

        return Group {
            if UIDevice.current.userInterfaceIdiom == .phone {
                // iPhone: Render at true point size so text matches native editors (e.g. Pages).
                GeometryReader { geometry in
                    let scale: CGFloat = 0.95
                    let inverseScale = 1.0 / scale
                    
                    ScrollView {
                        if forceRefresh {
                            FormattedTextEditor(
                                attributedText: $attributedContent,
                                selectedRange: $selectedRange,
                                textViewCoordinator: textViewCoordinator,
                                project: file.project,
                                captionNumberOffsets: manuscriptCaptionNumberOffsets,
                                headingStyleCounters: headingNumberState.styleCounters,
                                headingLastNumberForStyle: headingNumberState.lastNumberForStyle,
                                showInvisibles: showInvisibles,
                                showLineNumbers: showLineNumbers,
                                textContainerInset: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8),
                                isEditable: isFileEditable,
                                onTextChange: { change in
                                    handleAttributedTextChange(change)
                                },
                                onSimpleTypingChange: { range, replacementText, selectedRange in
                                    handleSimpleTypingChange(range: range, replacementText: replacementText, selectedRange: selectedRange)
                                },
                                onSelectionChange: { range in
                                    updateCurrentParagraphStyle(at: range)
                                },
                                onImageTapped: { attachment, frame, position in
                                    handleImageTap(attachment: attachment, frame: frame, position: position)
                                },
                                onClearImageSelection: {
                                    selectedImage = nil
                                    selectedImageFrame = .zero
                                    selectedImagePosition = -1
                                },
                                onImageCutRequested: { attachment, position in
                                    handleImageCutRequested(attachment: attachment, position: position)
                                },
                                onImagePasteRequested: { attachment, position in
                                    handleImagePasteRequested(attachment: attachment, position: position)
                                },
                                onCommentTapped: { attachment, position in
                                    handleCommentTap(attachment: attachment, position: position)
                                },
                                onFootnoteTapped: { attachment, position in
                                    handleFootnoteTap(attachment: attachment, position: position)
                                },
                                onReferenceTapped: { attachment, position in
                                    selectedReferenceAttachment = attachment
                                    selectedReferencePosition = position
                                    showReferenceEditor = true
                                },
                                onReferenceDeleted: { attachments, deletionRange in
                                    handleReferenceDeleted(attachments, in: deletionRange)
                                },
                                onCommentDeleted: { attachments, deletionRange in
                                    handleCommentMarkerDeleted(attachments, in: deletionRange)
                                },
                                onFootnoteDeleted: { attachments, deletionRange in
                                    handleFootnoteMarkerDeleted(attachments, in: deletionRange)
                                },
                                onMixedAttachmentsDeleted: { references, comments, footnotes, deletionRange in
                                    handleMixedAttachmentsDeleted(references, comments: comments, footnotes: footnotes, in: deletionRange)
                                },
                                onGlossaryAddRequested: canAddGlossaryMarkers ? { selectedText in
                                    handleGlossaryAddRequested(selectedText)
                                } : nil,
                                onIndexAddRequested: canAddIndexMarkers ? { selectedText in
                                    handleIndexAddRequested(selectedText)
                                } : nil,
                                onTabPressed: {
                                    insertTab()
                                },
                                onShiftTabPressed: {
                                    decreaseListIndent()
                                },
                                onZoomScaleChange: { newScale in
                                    setEditorZoomScale(newScale)
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
                                captionNumberOffsets: manuscriptCaptionNumberOffsets,
                                headingStyleCounters: headingNumberState.styleCounters,
                                headingLastNumberForStyle: headingNumberState.lastNumberForStyle,
                                showInvisibles: showInvisibles,
                                showLineNumbers: showLineNumbers,
                                textContainerInset: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8),
                                isEditable: isFileEditable,
                                onTextChange: { change in
                                    handleAttributedTextChange(change)
                                },
                                onSimpleTypingChange: { range, replacementText, selectedRange in
                                    handleSimpleTypingChange(range: range, replacementText: replacementText, selectedRange: selectedRange)
                                },
                                onSelectionChange: { range in
                                    updateCurrentParagraphStyle(at: range)
                                },
                                onImageTapped: { attachment, frame, position in
                                    handleImageTap(attachment: attachment, frame: frame, position: position)
                                },
                                onClearImageSelection: {
                                    selectedImage = nil
                                    selectedImageFrame = .zero
                                    selectedImagePosition = -1
                                },
                                onImageCutRequested: { attachment, position in
                                    handleImageCutRequested(attachment: attachment, position: position)
                                },
                                onImagePasteRequested: { attachment, position in
                                    handleImagePasteRequested(attachment: attachment, position: position)
                                },
                                onCommentTapped: { attachment, position in
                                    handleCommentTap(attachment: attachment, position: position)
                                },
                                onFootnoteTapped: { attachment, position in
                                    handleFootnoteTap(attachment: attachment, position: position)
                                },
                                onReferenceTapped: { attachment, position in
                                    selectedReferenceAttachment = attachment
                                    selectedReferencePosition = position
                                    showReferenceEditor = true
                                },
                                onReferenceDeleted: { attachments, deletionRange in
                                    handleReferenceDeleted(attachments, in: deletionRange)
                                },
                                onCommentDeleted: { attachments, deletionRange in
                                    handleCommentMarkerDeleted(attachments, in: deletionRange)
                                },
                                onFootnoteDeleted: { attachments, deletionRange in
                                    handleFootnoteMarkerDeleted(attachments, in: deletionRange)
                                },
                                onMixedAttachmentsDeleted: { references, comments, footnotes, deletionRange in
                                    handleMixedAttachmentsDeleted(references, comments: comments, footnotes: footnotes, in: deletionRange)
                                },
                                onGlossaryAddRequested: canAddGlossaryMarkers ? { selectedText in
                                    handleGlossaryAddRequested(selectedText)
                                } : nil,
                                onIndexAddRequested: canAddIndexMarkers ? { selectedText in
                                    handleIndexAddRequested(selectedText)
                                } : nil,
                                onTabPressed: {
                                    insertTab()
                                },
                                onShiftTabPressed: {
                                    decreaseListIndent()
                                },
                                onZoomScaleChange: { newScale in
                                    setEditorZoomScale(newScale)
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
                                captionNumberOffsets: manuscriptCaptionNumberOffsets,
                                headingStyleCounters: headingNumberState.styleCounters,
                                headingLastNumberForStyle: headingNumberState.lastNumberForStyle,
                                showInvisibles: showInvisibles,
                                showLineNumbers: showLineNumbers,
                                textContainerInset: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8),
                                isEditable: isFileEditable,
                                onTextChange: { change in
                                    handleAttributedTextChange(change)
                                },
                                onSimpleTypingChange: { range, replacementText, selectedRange in
                                    handleSimpleTypingChange(range: range, replacementText: replacementText, selectedRange: selectedRange)
                                },
                                onSelectionChange: { range in
                                    updateCurrentParagraphStyle(at: range)
                                },
                                onImageTapped: { attachment, frame, position in
                                    handleImageTap(attachment: attachment, frame: frame, position: position)
                                },
                                onClearImageSelection: {
                                    selectedImage = nil
                                    selectedImageFrame = .zero
                                    selectedImagePosition = -1
                                },
                                onImageCutRequested: { attachment, position in
                                    handleImageCutRequested(attachment: attachment, position: position)
                                },
                                onImagePasteRequested: { attachment, position in
                                    handleImagePasteRequested(attachment: attachment, position: position)
                                },
                                onCommentTapped: { attachment, position in
                                    handleCommentTap(attachment: attachment, position: position)
                                },
                                onFootnoteTapped: { attachment, position in
                                    handleFootnoteTap(attachment: attachment, position: position)
                                },
                                onReferenceTapped: { attachment, position in
                                    selectedReferenceAttachment = attachment
                                    selectedReferencePosition = position
                                    showReferenceEditor = true
                                },
                                onReferenceDeleted: { attachments, deletionRange in
                                    handleReferenceDeleted(attachments, in: deletionRange)
                                },
                                onCommentDeleted: { attachments, deletionRange in
                                    handleCommentMarkerDeleted(attachments, in: deletionRange)
                                },
                                onFootnoteDeleted: { attachments, deletionRange in
                                    handleFootnoteMarkerDeleted(attachments, in: deletionRange)
                                },
                                onMixedAttachmentsDeleted: { references, comments, footnotes, deletionRange in
                                    handleMixedAttachmentsDeleted(references, comments: comments, footnotes: footnotes, in: deletionRange)
                                },
                                onGlossaryAddRequested: canAddGlossaryMarkers ? { selectedText in
                                    handleGlossaryAddRequested(selectedText)
                                } : nil,
                                onIndexAddRequested: canAddIndexMarkers ? { selectedText in
                                    handleIndexAddRequested(selectedText)
                                } : nil,
                                onTabPressed: {
                                    insertTab()
                                },
                                onShiftTabPressed: {
                                    decreaseListIndent()
                                },
                                onZoomScaleChange: { newScale in
                                    setEditorZoomScale(newScale)
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
                                captionNumberOffsets: manuscriptCaptionNumberOffsets,
                                headingStyleCounters: headingNumberState.styleCounters,
                                headingLastNumberForStyle: headingNumberState.lastNumberForStyle,
                                showInvisibles: showInvisibles,
                                showLineNumbers: showLineNumbers,
                                textContainerInset: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8),
                                isEditable: isFileEditable,
                                onTextChange: { change in
                                    handleAttributedTextChange(change)
                                },
                                onSimpleTypingChange: { range, replacementText, selectedRange in
                                    handleSimpleTypingChange(range: range, replacementText: replacementText, selectedRange: selectedRange)
                                },
                                onSelectionChange: { range in
                                    updateCurrentParagraphStyle(at: range)
                                },
                                onImageTapped: { attachment, frame, position in
                                    handleImageTap(attachment: attachment, frame: frame, position: position)
                                },
                                onClearImageSelection: {
                                    selectedImage = nil
                                    selectedImageFrame = .zero
                                    selectedImagePosition = -1
                                },
                                onImageCutRequested: { attachment, position in
                                    handleImageCutRequested(attachment: attachment, position: position)
                                },
                                onImagePasteRequested: { attachment, position in
                                    handleImagePasteRequested(attachment: attachment, position: position)
                                },
                                onCommentTapped: { attachment, position in
                                    handleCommentTap(attachment: attachment, position: position)
                                },
                                onFootnoteTapped: { attachment, position in
                                    handleFootnoteTap(attachment: attachment, position: position)
                                },
                                onReferenceTapped: { attachment, position in
                                    selectedReferenceAttachment = attachment
                                    selectedReferencePosition = position
                                    showReferenceEditor = true
                                },
                                onReferenceDeleted: { attachments, deletionRange in
                                    handleReferenceDeleted(attachments, in: deletionRange)
                                },
                                onCommentDeleted: { attachments, deletionRange in
                                    handleCommentMarkerDeleted(attachments, in: deletionRange)
                                },
                                onFootnoteDeleted: { attachments, deletionRange in
                                    handleFootnoteMarkerDeleted(attachments, in: deletionRange)
                                },
                                onMixedAttachmentsDeleted: { references, comments, footnotes, deletionRange in
                                    handleMixedAttachmentsDeleted(references, comments: comments, footnotes: footnotes, in: deletionRange)
                                },
                                onGlossaryAddRequested: canAddGlossaryMarkers ? { selectedText in
                                    handleGlossaryAddRequested(selectedText)
                                } : nil,
                                onIndexAddRequested: canAddIndexMarkers ? { selectedText in
                                    handleIndexAddRequested(selectedText)
                                } : nil,
                                onTabPressed: {
                                    insertTab()
                                },
                                onShiftTabPressed: {
                                    decreaseListIndent()
                                },
                                onZoomScaleChange: { newScale in
                                    setEditorZoomScale(newScale)
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
        let notesExist = file.currentVersion?.notes?.isEmpty == false
        let indexEnabled = backMatterSettings.isEnabled(.index) && canInsertGlossaryAndIndexMarkers
        SwiftUIFormattingToolbar(
            onFormatAction: { action in
                switch action {
                case .paragraphStyle:
                    needsStyleReapplyAfterPickerDismiss = false
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
                case .clearText:
                    presentClearTextAlert = true
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
                case .insertTab:
                    insertTab()
                case .increaseIndent:
                    increaseListIndent()
                case .decreaseIndent:
                    decreaseListIndent()
                case .addIndex:
                    if canAddIndexMarkers {
                        showIndexEntryDialogWithSelectedText()
                    }
                }
            },
            hasSelectedImage: selectedImage != nil,
            notesExist: notesExist,
            indexEnabled: indexEnabled,
            isBoldActive: currentFormattingState().bold,
            isItalicActive: currentFormattingState().italic,
            isUnderlineActive: currentFormattingState().underline,
            isStrikethroughActive: currentFormattingState().strikethrough
        )
    }
    
    @ViewBuilder
    private func paginationSection() -> some View {
        if let project = file.project {
            PaginatedDocumentView(
                textFile: file,
                project: project
            )
            .id(refreshTrigger)
            .transition(.opacity)
        } else {
            ContentUnavailableView(
                "fileEdit.noPageSetup.title",
                systemImage: "doc.text",
                description: Text("fileEdit.noPageSetup.description")
            )
        }
    }
    
    /// Indicator bar shown at the bottom for markdown files
    @ViewBuilder
    private func markdownIndicatorBar() -> some View {
        HStack {
            Label(NSLocalizedString("markdown.mode.indicator", comment: "Markdown"), systemImage: "number.square")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            #if !targetEnvironment(macCatalyst)
            // Keyboard dismiss button (iOS only - Mac has physical keyboard)
            Button {
                if let textView = textViewCoordinator.textView {
                    if textView.isFirstResponder {
                        textView.resignFirstResponder()
                    } else {
                        textView.becomeFirstResponder()
                    }
                }
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 17))
            }
            #endif
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }
    
    /// iPhone menu content for insert and actions
    @ViewBuilder
    private func compactInsertMenuContent() -> some View {
        // Pagination mode toggle
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                isPaginationMode.toggle()
            }
        }) {
            Label(isPaginationMode ? "Edit Mode" : "Page Preview", systemImage: isPaginationMode ? "pencil" : "document.on.document")
        }
        
        // Show/Hide Invisibles toggle
        Button(action: {
            showInvisibles.toggle()
        }) {
            Label(
                showInvisibles
                    ? NSLocalizedString("fileEdit.hideInvisibles", comment: "Hide Invisibles")
                    : NSLocalizedString("fileEdit.showInvisibles", comment: "Show Invisibles"),
                systemImage: showInvisibles ? "eye.slash" : "eye"
            )
        }

        Button(action: {
            toggleLineNumbers()
        }) {
            Label(
                showLineNumbers
                    ? NSLocalizedString("fileEdit.hideLineNumbers", comment: "Hide Line Numbers")
                    : NSLocalizedString("fileEdit.showLineNumbers", comment: "Show Line Numbers"),
                systemImage: showLineNumbers ? "list.bullet.rectangle.portrait" : "list.number"
            )
        }

        Button(action: {
            startDocumentSpellingCheck()
        }) {
            Label(
                NSLocalizedString("spelling.checkDocument", comment: "Check spelling throughout the document"),
                systemImage: "text.badge.checkmark"
            )
        }
        .disabled(isPaginationMode)
        
        // Content type toggle (Rich Text / Markdown) - not for poetry or drama projects
        if supportsMarkdown {
            Button(action: {
                toggleContentType()
            }) {
                Label(
                    isDisplayingAsMarkdown 
                        ? NSLocalizedString("contentType.switchToRichText", comment: "Switch to Rich Text")
                        : NSLocalizedString("contentType.switchToMarkdown", comment: "Switch to Markdown"),
                    systemImage: isDisplayingAsMarkdown ? "richtext.page.fill" : "number.square"
                )
            }
        }

        if isPoetryProject {
            Button(action: {
                showPoetryFormPicker = true
            }) {
                Label(NSLocalizedString("poetryForm.changeForm", comment: "Change Form"), systemImage: "text.book.closed")
            }
        } else {
            Button(action: {
                presentManuscriptAnalyst()
            }) {
                Label("Analyze", systemImage: "text.magnifyingglass")
            }
        }
        
        Divider()
        
        // Insert options
        Button(action: {
            showImagePicker()
        }) {
            Label("Insert Image", systemImage: "photo")
        }
        
        compactCommentsSubmenu()
        compactFootnotesSubmenu()
        
        // Endnote (top-level)
        if backMatterSettings.isEnabled(.endnotes) {
            compactEndnotesSubmenu()
        }
        
        // Glossary (top-level)
        if backMatterSettings.isEnabled(.glossary) && canInsertGlossaryAndIndexMarkers {
            compactGlossarySubmenu()
        }
        
        // Reference (top-level)
        if backMatterSettings.isEnabled(.references) {
            compactReferenceSubmenu()
        }
        
        // Index (top-level)
        if backMatterSettings.isEnabled(.index) && canInsertGlossaryAndIndexMarkers {
            compactIndexSubmenu()
        }
        
        // Lists submenu (only if stylesheet has list styles)
        if file.project?.styleSheet?.hasListStyles == true {
            Menu {
                Button(action: { insertList(numbered: true) }) {
                    Label(NSLocalizedString("insertMenu.numberedList", comment: "Numbered List"), systemImage: "list.number")
                }
                Button(action: { insertList(numbered: false) }) {
                    Label(NSLocalizedString("insertMenu.bulletList", comment: "Bullet List"), systemImage: "list.bullet")
                }
            } label: {
                Label(NSLocalizedString("insertMenu.list", comment: "List"), systemImage: "list.bullet.rectangle")
            }
        }
        
        // Section marking menu (poetry projects only)
        if isPoetryProject {
            sectionMarkingMenu
        }
        
        Divider()
        
        Button(action: {
            insertPageBreak()
        }) {
            Label("Insert Page Break", systemImage: "arrow.up.and.line.horizontal.and.arrow.down")
        }
        
        Divider()
        
        Button(action: {
            printFile()
        }) {
            Label("Print", systemImage: "printer")
        }
        .disabled(!PrintService.isPrintingAvailable())
    }
    
    /// Comments submenu for compact mode
    @ViewBuilder
    private func compactCommentsSubmenu() -> some View {
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
    }
    
    /// Footnotes submenu for compact mode
    @ViewBuilder
    private func compactFootnotesSubmenu() -> some View {
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
    }
    
    /// Endnotes button for compact mode
    @ViewBuilder
    private func compactEndnotesSubmenu() -> some View {
        Button(action: { showNewEndnoteDialog = true }) {
            Label(NSLocalizedString("insertMenu.addEndnote", comment: "Add Endnote"), systemImage: "number.circle.fill")
        }
    }
    
    /// Glossary button for compact mode
    @ViewBuilder
    private func compactGlossarySubmenu() -> some View {
        Button(action: { showGlossaryTermDialogWithSelectedText() }) {
            Label(NSLocalizedString("insertMenu.addGlossaryTerm", comment: "Add Glossary Term"), systemImage: "text.book.closed.fill")
        }
    }

    /// Reference button for compact mode
    @ViewBuilder
    private func compactReferenceSubmenu() -> some View {
        Button(action: { showNewReferenceDialog = true }) {
            Label(NSLocalizedString("insertMenu.addReference", comment: "Add Reference"), systemImage: "books.vertical.fill")
        }
    }
    
    /// Index button for compact mode
    @ViewBuilder
    private func compactIndexSubmenu() -> some View {
        Button(action: { showIndexEntryDialogWithSelectedText() }) {
            Label(NSLocalizedString("insertMenu.addIndexEntry", comment: "Add Index Entry"), systemImage: "character.book.closed.fill")
        }
    }

    /// Info banner shown above the TOC editor content explaining that
    /// the final preview/print includes dot leaders and right-aligned page numbers.
    private var tocInfoBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.accentColor)
            Text(NSLocalizedString("toc.infoBanner", comment: "The final manuscript preview and print/export includes formatted dot leaders and right-aligned page numbers."))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
    }

    @ViewBuilder
    private func navigationBarButtons() -> some View {
        // TOC files: show only settings button
        if file.isTOCFile {
            Button(action: {
                showTOCSettings = true
            }) {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel(NSLocalizedString("toc.settings.button.accessibility", comment: "TOC Settings"))
        }
        // Table of Figures files: show settings button
        else if file.isTableOfFiguresFile {
            Button(action: {
                showTableOfFiguresSettings = true
            }) {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel(NSLocalizedString("tof.settings.button.accessibility", comment: "Table of Figures Settings"))
        }
        // Preview mode: show toggle button to exit preview (plus info about preview state)
        else if isPreviewingAsAlternateFormat {
            HStack(spacing: 16) {
                // Show preview indicator
                Text(isDisplayingAsMarkdown 
                    ? NSLocalizedString("preview.markdownMode", comment: "Markdown Preview")
                    : NSLocalizedString("preview.richTextMode", comment: "Rich Text Preview"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Toggle button to exit preview
                Button(action: {
                    toggleContentType()
                }) {
                    Image(systemName: isDisplayingAsMarkdown ? "richtext.page.fill" : "number.square")
                }
                .accessibilityLabel(isDisplayingAsMarkdown 
                    ? NSLocalizedString("contentType.switchToRichText", comment: "Switch to Rich Text")
                    : NSLocalizedString("contentType.switchToMarkdown", comment: "Switch to Markdown"))
            }
        }
        // Back matter files: show delete/trash button only
        else if file.isBackMatterFile {
            HStack {
                Button(role: .destructive) {
                    #if DEBUG
                    print("🗑️ Delete button tapped for: \(file.name)")
                    print("🗑️ Setting presentDeleteBackMatterAlert to true")
                    #endif
                    presentDeleteBackMatterAlert = true
                    #if DEBUG
                    print("🗑️ presentDeleteBackMatterAlert is now: \(presentDeleteBackMatterAlert)")
                    #endif
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete Back Matter File")
            }
            .onAppear {
                #if DEBUG
                print("🗑️ Showing delete button for back matter file: \(file.name)")
                #endif
            }
        } else {
            let isCompact = UIDevice.current.userInterfaceIdiom == .phone
            let showSearchButton = !isPaginationMode && !isFromMultiFileSearch
            
            HStack(spacing: isCompact ? 12 : 16) {
                if isPoetryProject {
                    // Poetry metrics button with validation badge (English only - analysis requires CMU dictionary)
                    if isEnglishLocale {
                        Button(action: {
                            showPoetryMetrics = true
                        }) {
                            Image(systemName: "chart.bar")
                                .overlay(alignment: .topTrailing) {
                                    // Show badge with cached issue count (computed asynchronously)
                                    if cachedValidationIssueCount > 0 {
                                        Text("\(min(cachedValidationIssueCount, 99))")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(3)
                                            .background(Color.red)
                                            .clipShape(Circle())
                                            .offset(x: 6, y: -6)
                                    }
                                }
                        }
                        // Keep a little extra separation before Search on iOS poetry files.
                        .padding(.trailing, showSearchButton ? 6 : 0)
                        .accessibilityLabel(NSLocalizedString("poetryMetrics.buttonAccessibility", comment: "Show poetry metrics"))
                    }
                }

                // Search button (only in edit mode and not opened from multi-file search)
                if showSearchButton {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            closeDocumentSpellingCheck()
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

                if !isCompact && !isPaginationMode {
                    Button(action: {
                        startDocumentSpellingCheck()
                    }) {
                        Image(systemName: showSpellingBar ? "text.badge.checkmark.fill" : "text.badge.checkmark")
                    }
                    .accessibilityLabel(NSLocalizedString("spelling.checkDocument", comment: "Check spelling throughout the document"))
                }
                
                // Plot elements button (only for files linked to fiction scenes with plot elements)
                if let scene = file.scene,
                   let plotElements = scene.plotElements,
                   !plotElements.isEmpty {
                    plotElementsButton(plotElements: plotElements)
                }
                
                // Character and Location insert buttons (for Fiction and Drama projects)
                if let project = file.project,
                   (project.type == .fiction || project.type == .drama) {
                    characterLocationInsertMenu(project: project)
                        .disabled(!hasCharactersLocationsOrPlotElements(project: project))
                }
                
                // On iPhone, group paginate/insert/print into a menu to save space
                // Undo/redo are more commonly used, so they're visible buttons
                if isCompact {
                    if !isPaginationMode {
                        Button(action: {
                            presentManuscriptAnalyst()
                        }) {
                            Image(systemName: "text.magnifyingglass")
                        }
                        .accessibilityLabel("Analyze with Manuscript Analyst")

                        // Undo/redo as visible buttons on iPhone
                        Button(action: {
                            performUndo()
                            restoreKeyboardFocus()
                        }) {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .disabled(!undoManager.canUndo || isPerformingUndoRedo)
                        .accessibilityLabel("fileEdit.undo.accessibility")
                        
                        Button(action: {
                            performRedo()
                            restoreKeyboardFocus()
                        }) {
                            Image(systemName: "arrow.uturn.forward")
                        }
                        .disabled(!undoManager.canRedo || isPerformingUndoRedo)
                        .accessibilityLabel("fileEdit.redo.accessibility")
                        
                        // Menu with paginate, insert options, and print
                        Menu {
                            compactInsertMenuContent()
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    } else {
                        // In pagination mode on iPhone, just show the toggle button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPaginationMode.toggle()
                            }
                        }) {
                            Image(systemName: "document.on.document.fill")
                        }
                        .accessibilityLabel("fileEdit.switchToEditMode.accessibility")
                    }
                } else {
                    Button(action: {
                        presentManuscriptAnalyst()
                    }) {
                        Label("Analyze", systemImage: "text.magnifyingglass")
                    }
                    .accessibilityLabel("Analyze with Manuscript Analyst")

                    // iPad/Mac: Pagination mode toggle (always available)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPaginationMode.toggle()
                        }
                    }) {
                        Image(systemName: isPaginationMode ? "document.on.document.fill" : "document.on.document")
                    }
                    .accessibilityLabel(isPaginationMode ? "fileEdit.switchToEditMode.accessibility" : "fileEdit.switchToPaginationPreview.accessibility")
                    
                    // Show/Hide Invisibles toggle
                    if !isPaginationMode {
                        Button(action: {
                            showInvisibles.toggle()
                        }) {
                            Image(systemName: showInvisibles ? "eye.slash" : "eye")
                        }
                        .accessibilityLabel(showInvisibles
                            ? NSLocalizedString("fileEdit.hideInvisibles", comment: "Hide Invisibles")
                            : NSLocalizedString("fileEdit.showInvisibles", comment: "Show Invisibles"))

                        Button(action: {
                            toggleLineNumbers()
                        }) {
                            Image(systemName: showLineNumbers ? "list.bullet.rectangle.portrait" : "list.number")
                        }
                        .accessibilityLabel(showLineNumbers
                            ? NSLocalizedString("fileEdit.hideLineNumbers", comment: "Hide Line Numbers")
                            : NSLocalizedString("fileEdit.showLineNumbers", comment: "Show Line Numbers"))
                    }
                    
                    // Content type toggle (Rich Text / Markdown) - not for poetry or drama projects
                    if supportsMarkdown && !isPaginationMode {
                        Button(action: {
                            toggleContentType()
                        }) {
                            Image(systemName: isDisplayingAsMarkdown ? "richtext.page.fill" : "number.square")
                        }
                        .accessibilityLabel(isDisplayingAsMarkdown 
                            ? NSLocalizedString("contentType.switchToRichText", comment: "Switch to Rich Text")
                            : NSLocalizedString("contentType.switchToMarkdown", comment: "Switch to Markdown"))
                    }
                    
                    // Insert menu (only in edit mode)
                    if !isPaginationMode {
                        insertMenu
                    }
                    
                    // iPad/Mac: Show undo/redo/print as separate buttons
                    if !isPaginationMode {
                        Button(action: {
                            performUndo()
                            restoreKeyboardFocus()
                        }) {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .disabled(!undoManager.canUndo || isPerformingUndoRedo)
                        .accessibilityLabel("fileEdit.undo.accessibility")
                        
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
        }
    }
    
    /// Button to view plot elements associated with this scene
    /// Shows a single button if one plot element, or a menu if multiple
    @ViewBuilder
    private func plotElementsButton(plotElements: [PlotElement]) -> some View {
        let sortedElements = plotElements.sorted { 
            ($0.userOrder ?? 0) < ($1.userOrder ?? 0) 
        }
        
        if sortedElements.count == 1 {
            // Single plot element - direct button
            Button(action: {
                selectedPlotElement = sortedElements.first
            }) {
                Image(systemName: "list.bullet.clipboard")
            }
            .accessibilityLabel(NSLocalizedString("fiction.viewPlotElement", comment: "View Plot Element"))
        } else {
            // Multiple plot elements - show menu
            Menu {
                ForEach(sortedElements, id: \.id) { element in
                    Button(action: {
                        selectedPlotElement = element
                    }) {
                        Label(element.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"), systemImage: "bookmark")
                    }
                }
            } label: {
                Image(systemName: "list.bullet.clipboard")
            }
            .accessibilityLabel(NSLocalizedString("fiction.viewPlotElements", comment: "View Plot Elements"))
        }
    }
    
    /// Menu for inserting character or location names (Fiction and Drama projects)
    private func hasCharactersLocationsOrPlotElements(project: Project) -> Bool {
        let hasCharacters = file.scene != nil
            ? !sceneCharactersForInsertMenu.isEmpty
            : !(project.characters ?? []).isEmpty
        let hasLocations = file.scene != nil
            ? !sceneLocationsForInsertMenu.isEmpty
            : !(project.locations ?? []).isEmpty
        let hasPlotElements = !(file.scene?.plotElements ?? []).isEmpty
        return hasCharacters || hasLocations || hasPlotElements
    }

    /// All characters relevant to this scene: the scene's own direct links unioned
    /// with characters directly linked to any of the scene's plot elements.
    private var sceneCharactersForInsertMenu: [Character] {
        guard let scene = file.scene else { return [] }
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
    }

    /// All locations relevant to this scene: the scene's own direct links unioned
    /// with locations directly linked to any of the scene's plot elements.
    private var sceneLocationsForInsertMenu: [Location] {
        guard let scene = file.scene else { return [] }
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
    }
    
    private func characterLocationInsertMenu(project: Project) -> some View {
        Menu {
            characterInsertSection(project: project)
            locationInsertSection(project: project)
            scenePlotElementsSection()
        } label: {
            Image(systemName: "person.text.rectangle")
        }
        .accessibilityLabel(NSLocalizedString("fiction.insertCharacterLocation", comment: "Insert Character or Location"))
    }
    
    @ViewBuilder
    private func characterInsertSection(project: Project) -> some View {
        // When editing a scene file, show the scene's own characters unioned with
        // characters directly linked to the scene's plot elements.
        // If the file has no scene, fall back to all project characters.
        let characters = file.scene != nil
            ? sceneCharactersForInsertMenu
            : (project.characters ?? []).sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }
        if !characters.isEmpty {
            Section(NSLocalizedString("autocomplete.characters", comment: "Characters")) {
                ForEach(characters, id: \.id) { character in
                    characterMenuButton(character)
                }
            }
        }
    }
    
    /// Button for character: tap shows detail, long-press inserts name
    private func characterMenuButton(_ character: Character) -> some View {
        Button {
            selectedCharacter = character
        } label: {
            Label(character.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"), systemImage: "person.fill")
        }
    }
    
    @ViewBuilder
    private func locationInsertSection(project: Project) -> some View {
        // Show this scene's locations unioned with locations directly linked to the
        // scene's plot elements. Fall back to all project locations if no scene.
        let locations = file.scene != nil
            ? sceneLocationsForInsertMenu
            : (project.locations ?? []).sorted { ($0.name ?? "") < ($1.name ?? "") }
        if !locations.isEmpty {
            Section(NSLocalizedString("autocomplete.locations", comment: "Locations")) {
                ForEach(locations, id: \.id) { location in
                    locationMenuButton(location)
                }
            }
        }
    }
    
    /// Button for location: tap shows detail, long-press inserts name
    private func locationMenuButton(_ location: Location) -> some View {
        Button {
            selectedLocation = location
        } label: {
            Label(location.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"), systemImage: "mappin.circle.fill")
        }
    }
    
    @ViewBuilder
    private func scenePlotElementsSection() -> some View {
        let elements = file.scene?.plotElements ?? []
        if !elements.isEmpty {
            Section(NSLocalizedString("editor.scenePlotElements", comment: "Scene Plot Elements")) {
                ForEach(elements.sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }, id: \.id) { element in
                    plotElementMenuButton(element)
                }
            }
        }
    }
    
    /// Button for plot element: tap shows detail
    private func plotElementMenuButton(_ element: PlotElement) -> some View {
        Button {
            selectedPlotElement = element
        } label: {
            Label(element.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"), systemImage: "bookmark")
        }
    }
    
    /// Insert menu for adding images, comments, footnotes, etc.
    private var insertMenu: some View {
        Menu {
            Button(action: {
                showImagePicker()
            }) {
                Label("Insert Image", systemImage: "photo")
            }

            if isPoetryProject {
                Button(action: {
                    showPoetryFormPicker = true
                }) {
                    Label(NSLocalizedString("poetryForm.changeForm", comment: "Change Form"), systemImage: "text.book.closed")
                }
            }

            // Comments
            // Comments - submenu only if there are comments
            if let currentVersion = file.currentVersion, currentVersion.comments?.isEmpty == false {
                Menu {
                    Button(action: { showNewCommentDialog = true }) {
                        Label("Add Comment", systemImage: "pencil.circle")
                    }
                    Divider()
                    Button(action: { showCommentsList = true }) {
                        Label("Show Comments", systemImage: "bubble.left.and.bubble.right")
                    }
                } label: {
                    Label("Comment", systemImage: "bubble.left")
                }
            } else {
                Button(action: { showNewCommentDialog = true }) {
                    Label("Add Comment", systemImage: "pencil.circle")
                }
            }

            // Footnotes - submenu only if there are footnotes
            if let currentVersion = file.currentVersion, currentVersion.footnotes?.isEmpty == false {
                Menu {
                    Button(action: { showNewFootnoteDialog = true }) {
                        Label("Add Footnote", systemImage: "pencil.circle")
                    }
                    Divider()
                    Button(action: { showFootnotesList = true }) {
                        Label("Show Footnotes", systemImage: "list.number")
                    }
                } label: {
                    Label("Footnote", systemImage: "number.circle")
                }
            } else {
                Button(action: { showNewFootnoteDialog = true }) {
                    Label("Add Footnote", systemImage: "pencil.circle")
                }
            }

            // Endnote - direct button, no submenu
            if backMatterSettings.isEnabled(.endnotes) {
                Button(action: { showNewEndnoteDialog = true }) {
                    Label(NSLocalizedString("insertMenu.addEndnote", comment: "Add Endnote"), systemImage: "number.circle.fill")
                }
            }

            // Glossary - direct button, no submenu
            if backMatterSettings.isEnabled(.glossary) && canInsertGlossaryAndIndexMarkers {
                Button(action: { showGlossaryTermDialogWithSelectedText() }) {
                    Label(NSLocalizedString("insertMenu.addGlossaryTerm", comment: "Add Term"), systemImage: "text.book.closed.fill")
                }
            }
            
            // Reference - direct button, no submenu
            if backMatterSettings.isEnabled(.references) {
                Button(action: { showNewReferenceDialog = true }) {
                    Label(NSLocalizedString("insertMenu.addReference", comment: "Add Reference"), systemImage: "books.vertical.fill")
                }
            }
            
            // Index - direct button, no submenu
            if backMatterSettings.isEnabled(.index) && canInsertGlossaryAndIndexMarkers {
                Button(action: { showIndexEntryDialogWithSelectedText() }) {
                    Label(NSLocalizedString("insertMenu.addIndexEntry", comment: "Add Index Entry"), systemImage: "character.book.closed.fill")
                }
            }

            // Lists submenu (only if stylesheet has list styles)
            if file.project?.styleSheet?.hasListStyles == true {
                Menu {
                    Button(action: { insertList(numbered: true) }) {
                        Label(NSLocalizedString("insertMenu.numberedList", comment: "Numbered List"), systemImage: "list.number")
                    }
                    Button(action: { insertList(numbered: false) }) {
                        Label(NSLocalizedString("insertMenu.bulletList", comment: "Bullet List"), systemImage: "list.bullet")
                    }
                } label: {
                    Label(NSLocalizedString("insertMenu.list", comment: "List"), systemImage: "list.bullet.rectangle")
                }
            }

            if isPoetryProject {
                sectionMarkingMenu
            }

            Divider()

            Button(action: { insertPageBreak() }) {
                Label("Insert Page Break", systemImage: "arrow.up.and.line.horizontal.and.arrow.down")
            }
        } label: {
            Image(systemName: "text.badge.plus")
        }
        .accessibilityLabel("fileEdit.insertMenu.accessibility")
    }
    
    /// Menu for marking text sections in poetry files
    /// Marked sections are excluded from poetry analysis and shown in grey
    @ViewBuilder
    private var sectionMarkingMenu: some View {
        Menu {
            // Add marked section button
            Button(action: {
                addMarkedSection()
            }) {
                Label(NSLocalizedString("poemSection.addToMarked", comment: "Add Marked Section"), systemImage: "plus.circle")
            }
            
            // Unmark selection button
            Button(action: {
                unmarkSelection()
            }) {
                Label(NSLocalizedString("poemSection.unmarkSelection", comment: "Unmark Selection"), systemImage: "minus.circle")
            }
            
            Divider()
            
            // Clear all marks button
            Button(action: {
                clearAllSectionMarks()
            }) {
                Label(NSLocalizedString("poemSection.clearAllMarks", comment: "Clear All Marks"), systemImage: "xmark.circle")
            }
        } label: {
            Label(NSLocalizedString("poemSection.markSection", comment: "Mark Section"), systemImage: "text.badge.checkmark")
        }
    }
    
    /// Mark the current selection as excluded from analysis (shown in grey)
    /// If no text is selected, marks the entire line at cursor position
    private func addMarkedSection() {
        guard let textView = textViewCoordinator.textView,
              let selectedRange = textView.selectedRange as NSRange? else {
            return
        }
        
        // Extend to line boundaries for cleaner marking
        // This works even when selection length is 0 (just a cursor)
        let mutableContent = NSMutableAttributedString(attributedString: textView.attributedText ?? NSAttributedString())
        let lineRange = mutableContent.extendToLinesBoundaries(selectedRange)
        
        // Don't mark empty ranges
        guard lineRange.length > 0 else { return }
        
        // Mark as excluded section (using .title as the marker type - any non-.poem type works)
        mutableContent.markSection(.title, in: lineRange)
        
        #if DEBUG
        // Verify the attribute was added
        var markedCount = 0
        mutableContent.enumerateAttribute(.poemSectionType, in: lineRange) { value, range, _ in
            if value != nil {
                markedCount += 1
                print("📌 Marked section at \(range): \(value!)")
            }
        }
        print("📌 addMarkedSection: Applied poemSectionType to \(markedCount) ranges in lineRange \(lineRange)")
        #endif
        
        // Apply grey text styling
        mutableContent.addAttribute(.foregroundColor, value: UIColor.systemGray, range: lineRange)
        
        // Update text view storage (source of truth)
        textView.textStorage.setAttributedString(mutableContent)
        
        // Update content binding
        attributedContent = mutableContent
        
        // Save changes to persist the section marker
        saveChanges()
        
        // Move cursor to end of marked section, then reset typing attributes
        // Order matters: set selection first, THEN override typing attributes
        let endOfMarkedSection = NSRange(location: lineRange.location + lineRange.length, length: 0)
        textView.selectedRange = endOfMarkedSection
        
        // Reset typing attributes to use adaptive color for subsequent typing
        // This must happen AFTER setting selectedRange to override UITextView's auto-inherited attrs
        var typingAttrs = textView.typingAttributes
        typingAttrs[.foregroundColor] = UIColor.label
        textView.typingAttributes = typingAttrs
    }
    
    /// Unmark the current selection, restoring it to normal poem text
    /// If no text is selected, unmarks the entire line at cursor position
    private func unmarkSelection() {
        guard let textView = textViewCoordinator.textView,
              let selectedRange = textView.selectedRange as NSRange? else {
            return
        }
        
        // Extend to line boundaries for cleaner unmarking
        let mutableContent = NSMutableAttributedString(attributedString: textView.attributedText ?? NSAttributedString())
        let lineRange = mutableContent.extendToLinesBoundaries(selectedRange)
        
        // Don't process empty ranges
        guard lineRange.length > 0 else { return }
        
        // Remove section type attribute (restores to default poem type)
        mutableContent.removeAttribute(.poemSectionType, range: lineRange)
        
        // Restore normal text color
        mutableContent.addAttribute(.foregroundColor, value: UIColor.label, range: lineRange)
        
        // Update text view storage (source of truth)
        textView.textStorage.setAttributedString(mutableContent)
        
        // Update content binding
        attributedContent = mutableContent
        
        // Save changes to persist the unmarking
        saveChanges()
        
        // Keep selection on the unmarked text
        textView.selectedRange = lineRange
    }
    
    /// Clear all section marks from the document, resetting everything to poem type
    private func clearAllSectionMarks() {
        guard let textView = textViewCoordinator.textView else { return }
        
        let mutableContent = NSMutableAttributedString(attributedString: textView.attributedText ?? NSAttributedString())
        let fullRange = NSRange(location: 0, length: mutableContent.length)
        
        // Remove section type attribute
        mutableContent.removeAttribute(.poemSectionType, range: fullRange)
        
        // Remove grey text styling - restore to label color
        mutableContent.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)
        
        // Update text view storage (source of truth)
        textView.textStorage.setAttributedString(mutableContent)
        
        // Update content binding
        attributedContent = mutableContent
        
        // Save changes to persist the cleared markers
        saveChanges()
    }
    
    /// Whether this file should use the poetry editor
    /// True for Poetry project files, files with a poetry form, or Verse Novel episodes
    private var isPoetryProject: Bool {
        file.project?.type == .poetry || file.poetryFormId != nil || file.project?.fictionClass == .verseNovel
    }
    
    /// Whether this file belongs to a Drama project
    private var isDramaProject: Bool {
        file.project?.type == .drama
    }
    
    /// Whether markdown content type is available (not for Poetry or Drama)
    private var supportsMarkdown: Bool {
        !isPoetryProject && !isDramaProject
    }
    
    /// Whether the editor is currently displaying content as markdown (may differ from file's actual type in preview mode)
    /// When isPreviewingAsAlternateFormat is true, we show the opposite of the file's actual format
    private var isDisplayingAsMarkdown: Bool {
        isPreviewingAsAlternateFormat ? !file.isMarkdown : file.isMarkdown
    }
    
    /// Get the Back Matter settings from the project's Back Matter folder
    private var backMatterSettings: BackMatterSettings {
        guard let project = file.project ?? file.parentFolder?.project ?? findProjectInHierarchy() else {
            return BackMatterSettings()
        }

        // Drama has its own back-matter model and none of its sections insert markers
        // into the manuscript editor.
        guard project.type != .drama else { return BackMatterSettings() }

        // Fetch from the live context instead of traversing cached relationships, which
        // Ensembles may invalidate while applying a merge.
        let projectID = project.id
        let localizedBackMatterName = NSLocalizedString("folder.backMatter", comment: "Back Matter")
        let descriptor = FetchDescriptor<Folder>(
            predicate: #Predicate<Folder> { folder in
                folder.name == "Back Matter" || folder.name == localizedBackMatterName
            }
        )

        if let folders = try? modelContext.fetch(descriptor) {
            let projectFolders = folders.filter {
                $0.project?.id == projectID || $0.parentFolder?.project?.id == projectID
            }
            let backMatterFolder = projectFolders.first {
                $0.parentFolder?.name == "Manuscript"
            } ?? projectFolders.first
            if let backMatterFolder {
                return backMatterFolder.backMatterSettings
            }
        }

        return BackMatterSettings()
    }
    
    /// Whether the device is set to an English locale
    /// Poetry analysis (syllables, stress, rhyme) only works for English
    private var isEnglishLocale: Bool {
        Locale.current.language.languageCode?.identifier == "en"
    }
    
    /// Custom title view showing file name and poetry form
    private var poetryTitleView: some View {
        VStack(spacing: 2) {
            Text(file.name)
                .font(.headline)
                .lineLimit(1)
            
            if let formName = file.poetryFormName ?? file.poetryForm?.name {
                Text(formName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text(NSLocalizedString("poetryForm.freeVerse", comment: "Free Verse"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Version navigation remains available when sync protection makes content read-only.
            if !isPaginationMode && !file.isBackMatterFile && !file.isTOCFile {
                HStack(spacing: 0) {
                    versionToolbar()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if isFileEditable {
                        editorScalingControls()
                    }
                }
            }

            // Search bar (only shown in edit mode when active)
            if !isPaginationMode {
                InEditorSearchBar(
                    manager: searchManager,
                    isVisible: $showSearchBar,
                    isSimplifiedMode: isSimplifiedSearchMode
                )

                DocumentSpellingBar(
                    manager: spellingManager,
                    isVisible: $showSpellingBar,
                    canReplace: isFileEditable,
                    onReplace: replaceCurrentSpellingIssue,
                    onIgnore: ignoreCurrentSpellingIssue,
                    onIgnoreAll: ignoreAllOccurrencesOfCurrentSpellingWord,
                    onRescan: scanDocumentSpelling,
                    onClose: closeDocumentSpellingCheck
                )
            }
            
            // Main content area - switch between edit and pagination modes
            if isPaginationMode {
                paginationSection()
            } else {
                // Info banner for TOC files
                if file.isTOCFile {
                    tocInfoBanner
                }
                if hasMissingSyncedBody {
                    missingSyncedBodyBanner
                }
                textEditorSection()
                // Formatting toolbar (only shown for editable rich text files, not when displaying as markdown)
                if isFileEditable && !isDisplayingAsMarkdown {
                    formattingToolbar()
                }
                // Markdown indicator bar (only when displaying as markdown)
                if isDisplayingAsMarkdown {
                    markdownIndicatorBar()
                }
            }
        }
        // Hidden keyboard shortcut handlers - using overlay so they don't affect layout
        .overlay {
            Group {
                Button("") {
                    if showSearchBar && searchManager.hasMatches {
                        searchManager.nextMatch()
                    }
                }
                .keyboardShortcut("g", modifiers: .command)
                
                Button("") {
                    if showSearchBar && searchManager.hasMatches {
                        searchManager.previousMatch()
                    }
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])

                Button("") {
                    startDocumentSpellingCheck()
                }
                .keyboardShortcut(";", modifiers: .command)
                
                // List shortcuts: Cmd+Shift+7 for numbered, Cmd+Shift+8 for bulleted
                Button("") {
                    applyNumberFormat(.decimal)
                }
                .keyboardShortcut("7", modifiers: [.command, .shift])
                
                Button("") {
                    applyNumberFormat(.bulletSymbols)
                }
                .keyboardShortcut("8", modifiers: [.command, .shift])
                
                // Select All: Cmd+A
                Button("") {
                    if let textView = textViewCoordinator.textView {
                        textView.selectAll(nil)
                    }
                }
                .keyboardShortcut("a", modifiers: .command)
                
                // Add Index Entry: Cmd+Shift+X
                Button("") {
                    if backMatterSettings.isEnabled(.index) && canInsertGlossaryAndIndexMarkers {
                        showIndexEntryDialogWithSelectedText()
                    }
                }
                .keyboardShortcut("x", modifiers: [.command, .shift])
            }
            .frame(width: 0, height: 0)
            .opacity(0)
        }
        // Progress overlay for TOC page calculation
        .overlay {
            if isCalculatingTOCPages {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(NSLocalizedString("toc.calculatingPages", comment: "Calculating page numbers..."))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(24)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 10)
                }
            }
        }
        .overlay(alignment: .top) {
            if showClearTextToast {
                Label("Text cleared", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.green, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showStylePicker, onDismiss: {
            // Avoid a second full-document style pass after a simple style selection,
            // which causes visible "twitch"/jump on macOS. Only reapply when the
            // style definition itself was edited inside the picker flow.
            if needsStyleReapplyAfterPickerDismiss {
                attemptPendingStyleReapply()
            }
            needsStyleReapplyAfterPickerDismiss = false
        }) {
            StylePickerSheet(
                currentStyle: $currentParagraphStyle,
                onStyleSelected: { style in
                    applyParagraphStyle(style)
                },
                onClose: {
                    showStylePicker = false
                },
                project: file.project,
                onStyleDefinitionSaved: { styleName in
                    needsStyleReapplyAfterPickerDismiss = true
                    requestStyleDefinitionReapply(styleName: styleName)
                }
            )
        }
        .sheet(item: $imageToEdit) { imageAttachment in
            ImageStyleEditorSheetContent(
                imageAttachment: imageAttachment,
                file: file,
                onApply: { values in
                    updateImage(
                        attachment: imageAttachment,
                        imageStyleName: values.imageStyleName,
                        scale: values.scale,
                        alignment: values.alignment,
                        hasCaption: values.hasCaption,
                        captionPrefix: values.captionPrefix,
                        captionText: values.captionText,
                        captionStyle: values.captionStyle,
                        spacingAbove: values.spacingAbove,
                        spacingBelow: values.spacingBelow,
                        borderStyle: values.borderStyle,
                        borderPadding: values.borderPadding
                    )
                    imageToEdit = nil
                },
                onUpdateStyle: { values in
                    updateImageStyle(values, attachment: imageAttachment)
                    imageToEdit = nil
                },
                onCancel: {
                    imageToEdit = nil
                }
            )
        }
    }
    
    // MARK: - Computed Properties
    
    /// Check if the current file should be editable
    /// Back matter files and TOC files are read-only
    /// Also read-only when previewing in alternate format (to prevent accidental edits to preview content)
    private var isFileEditable: Bool {
        if isFormattedContentSyncIncomplete {
            return false
        }

        // Don't allow editing while previewing in alternate format
        if isPreviewingAsAlternateFormat {
            return false
        }
        return !file.isBackMatterFile && !file.isTOCFile
    }

    private var missingSyncedBodyBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "icloud.and.arrow.down")
                .font(.body)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("fileEditor.missingBody.title", comment: "Missing synced file body warning title"))
                    .font(.subheadline.weight(.semibold))
                Text(NSLocalizedString("fileEditor.missingBody.message", comment: "Missing synced file body warning message"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(NSLocalizedString("fileEditor.missingBody.editEmpty", comment: "Edit an intentionally empty file")) {
                    showMissingBodyEditConfirmation = true
                }
                .font(.caption.weight(.semibold))
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .padding(.top, 8)
        .alert(
            NSLocalizedString("fileEditor.missingBody.confirmTitle", comment: "Confirm editing an intentionally empty file"),
            isPresented: $showMissingBodyEditConfirmation
        ) {
            Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {}
            Button(NSLocalizedString("fileEditor.missingBody.confirmEdit", comment: "Confirm editing empty file")) {
                hasMissingSyncedBody = false
            }
        } message: {
            Text(NSLocalizedString("fileEditor.missingBody.confirmMessage", comment: "Warning before overriding missing body protection"))
        }
    }
    
    var body: some View {
        mainContentWithAllSheets
            // For poetry projects, hide the navigation title since we use a custom title view
            .navigationTitle(isPoetryProject ? "" : file.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(initialCharacterPosition != nil)
            .toolbar {
                if initialCharacterPosition != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            returnToProjectTopLevel()
                        } label: {
                            Label(
                                NSLocalizedString("navigation.back", comment: "Back"),
                                systemImage: "chevron.left"
                            )
                        }
                    }
                }
                // Custom title with form subtitle for poetry projects
                if isPoetryProject {
                    ToolbarItem(placement: .principal) {
                        poetryTitleView
                    }
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
                showFilesPickerFromCoordinator: showIOSImagePicker,
                insertNewComment: insertNewComment,
                insertNewFootnote: insertNewFootnote,
                showCommentsList: { showCommentsList = true }
            ))
            .upgradePrompt(reason: $upgradePromptReason)
            .onDisappear {
                // Unregister stylesheet from provider
                StyleSheetProvider.shared.unregister(
                    fileID: file.id,
                    ownerID: styleSheetRegistrationOwnerID
                )
                
                // Disconnect search manager to clean up highlights and observers
                searchManager.disconnect()
                spellingManager.disconnect()

                flushPendingEditorChanges(reason: "editor-disappear-flush")
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                handleEditorDidEnterBackground()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                flushPendingEditorChanges(reason: "editor-will-terminate-flush")
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                refreshRemoteContentAndStylesIfSafe()
            }
            .onReceive(NotificationCenter.default.publisher(for: .writingShedProSyncDidUpdateLocalData)) { _ in
                refreshRemoteContentAndStylesIfSafe()
            }
            .onReceive(NotificationCenter.default.publisher(for: .writeCoalescerDidFinishSave)) { _ in
                guard hasPendingRemoteRefresh else { return }
                hasPendingRemoteRefresh = false
                refreshRemoteContentAndStylesIfSafe()
            }
            .onReceive(NotificationCenter.default.publisher(for: .formattedTextEditorDidEndEditing)) { notification in
                guard let endedTextView = notification.object as? UITextView,
                      endedTextView === textViewCoordinator.textView else { return }
                if hasPendingStyleReapply {
                    _ = commitPendingEditorSave(reason: "style-reapply-editing-ended")
                }
                attemptPendingStyleReapply()
                if hasPendingRemoteRefresh {
                    let committedPendingEdit: Bool
                    if saveDebounceTimer != nil ||
                        pendingDebouncedAttributedContent != nil ||
                        pendingDebouncedSaveNeedsTextViewSnapshot {
                        committedPendingEdit = commitPendingEditorSave(reason: "remote-refresh-editing-ended")
                    } else {
                        committedPendingEdit = false
                    }
                    if !committedPendingEdit {
                        hasPendingRemoteRefresh = false
                        refreshRemoteContentAndStylesIfSafe()
                    }
                }
            }
            .onAppear {
                setupOnAppear()
            }
            .onChange(of: selectedRange) { oldValue, newValue in
                if WriteCoalescer.shared?.hasRecentEditingActivity(within: 0.25) == true,
                   oldValue.length == 0,
                   newValue.length == 0 {
                    return
                }
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
    
    // MARK: - Sheet Groupings (extracted to reduce body type-checking complexity)
    
    /// Top-level: chains alert sheets on top of comment/footnote/note/reference sheets
    private var mainContentWithAllSheets: some View {
        mainContentWithReferenceAndUtilitySheets
            .alert(isPresented: $presentDeleteBackMatterAlert) {
                Alert(
                    title: Text("Delete Back Matter File?"),
                    message: Text("This will remove all references to its contents and the referenced items themselves. This cannot be undone. Continue?"),
                    primaryButton: .destructive(Text("Delete")) {
                        deleteBackMatterFileAndCleanup()
                    },
                    secondaryButton: .cancel()
                )
            }
            .confirmationDialog(
                NSLocalizedString("fileEdit.deleteVersionTitle", comment: "Delete Version?"),
                isPresented: $presentDeleteAlert,
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("contentView.delete", comment: "Delete"), role: .destructive) {
                    #if DEBUG
                    print("📝 Delete version confirmed, deleting...")
                    logVersionDiagnostics("before file.deleteVersion()")
                    #endif
                    file.deleteVersion()
                    #if DEBUG
                    logVersionDiagnostics("after file.deleteVersion() before loadCurrentVersion()")
                    #endif
                    loadCurrentVersion()
                    #if DEBUG
                    logVersionDiagnostics("after loadCurrentVersion()")
                    #endif
                    // NOTE: Do NOT call saveChanges() here - the editor still has the deleted version's content
                    // and calling save would overwrite the new current version with the old content
                    // Force toolbar to re-render with updated version count
                    refreshTrigger = UUID()
                }
                Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("fileEdit.deleteVersionMessage", comment: "Please confirm that you want to delete this version"))
            }
            .alert(isPresented: $presentClearTextAlert) {
                Alert(
                    title: Text("Clear Text?"),
                    message: Text("This will remove all text from this file version."),
                    primaryButton: .destructive(Text("Clear")) {
                        clearCurrentTextContent()
                    },
                    secondaryButton: .cancel()
                )
            }
    }
    
    /// Reference, poetry, and utility sheets
    private var mainContentWithReferenceAndUtilitySheets: some View {
        mainContentWithNoteAndGlossarySheets
            // Feature 029: References sheets
            .sheet(isPresented: $showReferencesList) {
                if let project = file.project {
                    ReferencesListView(project: project)
                }
            }
            .sheet(isPresented: $showNewReferenceDialog) {
                if let project = file.project {
                    ReferenceCreatorSheet(
                        project: project,
                        onSave: { reference in
                            insertReferenceMarker(for: reference)
                        }
                    )
                    .presentationDetents([.medium, .large])
                }
            }
            .sheet(item: $selectedReference) { reference in
                if let project = file.project {
                    ReferenceCreatorSheet(
                        project: project,
                        existingReference: reference,
                        onSave: { _ in
                            forceRefresh.toggle()
                        },
                        onCancel: {
                            selectedReference = nil
                        }
                    )
                    .presentationDetents([.medium, .large])
                }
            }
            // Feature 029: Reference editor sheet (shows appropriate editor based on reference type)
            .sheet(isPresented: $showReferenceEditor) {
                if let attachment = selectedReferenceAttachment {
                    ReferenceEditorSheet(
                        project: file.project,
                        referenceAttachment: attachment
                    )
                }
            }
            .sheet(isPresented: $showNotesEditor) {
                if let currentVersion = file.currentVersion {
                    NotesEditorSheet(version: currentVersion)
                }
            }
            .sheet(isPresented: $showPoetryFormReference) {
                if let form = file.poetryForm {
                    PoetryFormReference(form: form)
                } else {
                    // Default to free verse reference if no form set
                    FreeVerseReference()
                }
            }
            .sheet(isPresented: $showTOCSettings) {
                TOCSettingsView(file: file, isPresented: $showTOCSettings) {
                    // Regenerate TOC when settings change
                    // Need to traverse folder hierarchy since file.project may be nil
                    var project: Project? = file.project
                    if project == nil {
                        var currentFolder = file.parentFolder
                        while let folder = currentFolder {
                            if let proj = folder.project {
                                project = proj
                                break
                            }
                            currentFolder = folder.parentFolder
                        }
                    }
                    if let project = project {
                        regenerateTOCContent(for: project)
                    }
                }
            }
            .sheet(isPresented: $showTableOfFiguresSettings) {
                TableOfFiguresSettingsView(file: file, isPresented: $showTableOfFiguresSettings) {
                    // Refresh content when settings change
                    // Content is dynamically generated in BackMatterGeneratedContentView
                }
            }
            .sheet(isPresented: $showPoetryMetrics) {
                NavigationStack {
                    PoetryMetricsDashboard(
                        attributedText: attributedContent,
                        form: file.poetryForm
                    )
                    .navigationTitle(NSLocalizedString("poetryMetrics.title", comment: "Poetry Metrics"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(NSLocalizedString("poetryMetrics.done", comment: "Done")) {
                                showPoetryMetrics = false
                            }
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showManuscriptAnalyst) {
                ManuscriptAnalystActionSheet(textFile: file)
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
            .sheet(isPresented: $showPoetryFormPicker) {
                PoetryFormPickerSheet(file: file)
            }
            .sheet(isPresented: $showProjectCharacters) {
                NavigationStack {
                    if let project = file.project {
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
            }
            .sheet(isPresented: $showProjectLocations) {
                NavigationStack {
                    if let project = file.project {
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
            }
            .sheet(isPresented: $showProjectPlot) {
                NavigationStack {
                    if let project = file.project {
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
            }
    }
    
    /// Notes, endnotes, glossary, and index sheets
    private var mainContentWithNoteAndGlossarySheets: some View {
        mainContentWithCommentAndFootnoteSheets
            // Feature 029: Notes & Endnotes sheets
            .sheet(isPresented: $showNotesList) {
                if let project = file.project {
                    NotesListView(
                        project: project,
                        onDismiss: {
                            showNotesList = false
                        },
                        onNoteChanged: {
                            WriteCoalescer.shared?.flush()
                            forceRefresh.toggle()
                        },
                        onNoteDeleted: { note in
                            removeNoteMarkers(for: note)
                        }
                    )
                    .onAppear {
                        // Set filter to .endnotes if possible
                        NotificationCenter.default.post(name: NSNotification.Name("NotesListView.SetFilter.Endnotes"), object: nil)
                    }
                }
            }
            .sheet(isPresented: $showNewNoteDialog) {
                if let project = file.project {
                    NoteEditorSheet(
                        project: project,
                        isEndnote: false,
                        onSave: { note in
                            insertNoteMarker(for: note)
                        }
                    )
                }
            }
            .sheet(isPresented: $showNewEndnoteDialog) {
                if let project = file.project {
                    NoteEditorSheet(
                        project: project,
                        isEndnote: true,
                        onSave: { note in
                            insertNoteMarker(for: note)
                        }
                    )
                }
            }
            .sheet(item: $selectedNoteForDetail) { note in
                if let project = file.project {
                    NoteEditorSheet(
                        project: project,
                        existingNote: note,
                        onSave: { _ in
                            forceRefresh.toggle()
                        },
                        onCancel: {
                            selectedNoteForDetail = nil
                        }
                    )
                }
            }
            // Feature 029: Glossary sheets
            .sheet(isPresented: $showGlossaryList) {
                if let project = file.project {
                    GlossaryListView(
                        project: project,
                        onJumpToTerm: { term in
                            jumpToGlossaryMarker(term)
                        },
                        onDismiss: {
                            showGlossaryList = false
                        },
                        onTermChanged: {
                            WriteCoalescer.shared?.flush()
                            forceRefresh.toggle()
                        },
                        onTermDeleted: { term in
                            removeGlossaryMarkers(for: term)
                        }
                    )
                }
            }
            .sheet(isPresented: $showNewGlossaryTermDialog) {
                if let project = file.project {
                    GlossaryEditorSheet(
                        project: project,
                        prefilledTerm: glossaryTermFromContextMenu,
                        onSave: { term in
                            insertGlossaryMarker(for: term)
                            glossaryTermFromContextMenu = nil
                        }
                    )
                }
            }
            .sheet(item: $selectedGlossaryTerm) { term in
                if let project = file.project {
                    GlossaryEditorSheet(
                        project: project,
                        existingTerm: term,
                        onSave: { _ in
                            forceRefresh.toggle()
                        },
                        onCancel: {
                            selectedGlossaryTerm = nil
                        }
                    )
                }
            }
            // Feature 029: Index sheets
            .sheet(isPresented: $showIndexList) {
                if let project = file.project {
                    IndexListView(
                        project: project,
                        onJumpToEntry: { entry in
                            jumpToIndexMarker(entry)
                        },
                        onDismiss: {
                            showIndexList = false
                        },
                        onEntryChanged: {
                            WriteCoalescer.shared?.flush()
                            forceRefresh.toggle()
                        },
                        onEntryDeleted: { entry in
                            removeIndexMarkers(for: entry)
                        }
                    )
                }
            }
            .sheet(item: $newIndexEntryData) { data in
                IndexEditorSheet(
                    project: data.project,
                    prefilledKeyword: data.prefilledKeyword,
                    onSave: { entry, isPrimary in
                        #if DEBUG
                        print("📑 Index onSave callback: entry='\(entry.keyword)', isPrimary=\(isPrimary)")
                        #endif
                        newIndexEntryData = nil
                        insertIndexMarker(for: entry, isPrimary: isPrimary)
                    },
                    onCancel: {
                        newIndexEntryData = nil
                    }
                )
            }
            .sheet(item: $selectedIndexEntry) { entry in
                if let project = file.project {
                    IndexEditorSheet(
                        project: project,
                        existingEntry: entry,
                        onSave: { _, _ in
                            selectedIndexEntry = nil
                            forceRefresh.toggle()
                        },
                        onCancel: {
                            selectedIndexEntry = nil
                        }
                    )
                }
            }
    }
    
    /// Comment and footnote list/detail sheets
    private var mainContentWithCommentAndFootnoteSheets: some View {
        mainContent
            .sheet(isPresented: $showCommentsList) {
                if let currentVersion = file.currentVersion {
                    CommentsListView(
                        version: currentVersion,
                        onJumpToComment: { comment in
                            jumpToComment(comment)
                        },
                        onDismiss: {
                            showCommentsList = false
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
            .sheet(item: $selectedCommentForDetail, onDismiss: {
                selectedCommentForDetail = nil
            }) { comment in
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
                        markerStyle: file.project?.styleSheet?.footnoteMarkerStyle ?? .numeric,
                        onJumpToFootnote: { footnote in
                            jumpToFootnote(footnote)
                        },
                        onDismiss: {
                            showFootnotesList = false
                        },
                        onFootnoteChanged: {
                            // Footnote text was updated by FootnoteManager; refresh without rewriting editor content.
                            WriteCoalescer.shared?.flush()
                            forceRefresh.toggle()
                        },
                        onFootnoteDeleted: { footnote in
                            // Footnote was deleted, remove marker from text
                            removeFootnoteFromText(footnote)
                        }
                    )
                }
            }
            .sheet(item: $selectedFootnoteForDetail, onDismiss: {
                selectedFootnoteForDetail = nil
            }) { footnote in
                NavigationView {
                    FootnoteDetailView(
                        footnote: footnote,
                        markerStyle: file.project?.styleSheet?.footnoteMarkerStyle ?? .numeric,
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
    }
    
    // MARK: - Document Spelling

    private func startDocumentSpellingCheck() {
        guard !isPaginationMode else { return }

        showSearchBar = false
        searchManager.disconnect()
        showSpellingBar = true

        if let textView = textViewCoordinator.textView {
            spellingManager.connect(to: textView)
            spellingManager.scan(attributedText: textView.attributedText, startingAt: textView.selectedRange.location)
        } else {
            DispatchQueue.main.async {
                scanDocumentSpelling()
            }
        }
    }

    private func scanDocumentSpelling() {
        guard let textView = textViewCoordinator.textView else { return }
        spellingManager.connect(to: textView)
        spellingManager.scan(attributedText: textView.attributedText, startingAt: textView.selectedRange.location)
    }

    private func closeDocumentSpellingCheck() {
        showSpellingBar = false
        spellingManager.disconnect()
    }

    private func replaceCurrentSpellingIssue(with replacement: String) {
        guard isFileEditable,
              !replacement.isEmpty,
              let issue = spellingManager.currentIssue,
              let textView = textViewCoordinator.textView,
              NSMaxRange(issue.range) <= textView.textStorage.length else { return }

        flushPendingEditorChanges(reason: "spelling-replacement-preflight")

        let beforeContent = NSAttributedString(attributedString: textView.attributedText)
        let replacementAttributes = beforeContent.attributes(at: issue.range.location, effectiveRange: nil)
        let mutableContent = NSMutableAttributedString(attributedString: beforeContent)
        mutableContent.replaceCharacters(
            in: issue.range,
            with: NSAttributedString(string: replacement, attributes: replacementAttributes)
        )
        let afterContent = NSAttributedString(attributedString: mutableContent)

        textView.textStorage.setAttributedString(afterContent)
        attributedContent = afterContent
        previousContent = afterContent.string
        previousAttributedContent = afterContent
        file.currentVersion?.attributedContent = afterContent
        file.currentVersion?.referenceMetadataData = extractReferenceMetadata(from: afterContent).encode()
        file.modifiedDate = Date()

        let command = FormatApplyCommand(
            description: NSLocalizedString("spelling.replaceUndo", comment: "Undo description for replacing a misspelled word"),
            range: issue.range,
            beforeContent: beforeContent,
            afterContent: afterContent,
            targetFile: file
        )
        undoManager.registerExecuted(command)
        try? WriteCoalescer.shared?.requestSaveAndFlush(reason: "spelling-replacement")

        spellingManager.didReplaceCurrentIssue(with: replacement)
        searchManager.notifyTextChanged()
    }

    private func ignoreCurrentSpellingIssue() {
        guard let issue = spellingManager.currentIssue else { return }
        persistIgnoredSpellingRanges([issue.range])
        spellingManager.ignoreCurrentIssue()
    }

    private func ignoreAllOccurrencesOfCurrentSpellingWord() {
        guard let issue = spellingManager.currentIssue else { return }
        let normalizedWord = issue.word.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let ranges = spellingManager.issues.compactMap { candidate -> NSRange? in
            let candidateWord = candidate.word.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return candidateWord == normalizedWord ? candidate.range : nil
        }
        persistIgnoredSpellingRanges(ranges)
        spellingManager.ignoreAllOccurrencesOfCurrentWord()
    }

    private func persistIgnoredSpellingRanges(_ ranges: [NSRange]) {
        guard isFileEditable,
              !ranges.isEmpty,
              let textView = textViewCoordinator.textView else { return }

        flushPendingEditorChanges(reason: "spelling-ignore-preflight")
        let mutableContent = NSMutableAttributedString(attributedString: textView.attributedText)
        for range in ranges where NSMaxRange(range) <= mutableContent.length {
            mutableContent.addAttribute(.spellingIgnored, value: true, range: range)
        }
        let updatedContent = NSAttributedString(attributedString: mutableContent)
        textView.textStorage.setAttributedString(updatedContent)
        attributedContent = updatedContent
        previousContent = updatedContent.string
        previousAttributedContent = updatedContent
        file.currentVersion?.attributedContent = updatedContent
        file.currentVersion?.referenceMetadataData = extractReferenceMetadata(from: updatedContent).encode()
        file.modifiedDate = Date()
        try? WriteCoalescer.shared?.requestSaveAndFlush(reason: "spelling-ignore")
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
        let showFilesPickerFromCoordinator: () -> Void
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
                        showFilesPickerFromCoordinator()
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

    private func setEditorZoomScale(_ value: CGFloat) {
        let clampedScale = max(0.5, min(4.0, value))

        if let textView = textViewCoordinator.textView {
            textView.transform = CGAffineTransform(scaleX: clampedScale, y: clampedScale)
        }

        #if os(iOS)
        UserDefaults.standard.set(Double(clampedScale), forKey: Self.editorZoomScaleDefaultsKey)
        #endif

        DispatchQueue.main.async {
            editorZoomScale = clampedScale
            lastEditorZoomScale = clampedScale
        }
    }

    private func loadSavedEditorZoomScaleIfNeeded() {
        #if os(iOS)
        let savedScale = UserDefaults.standard.double(forKey: Self.editorZoomScaleDefaultsKey)
        if savedScale > 0 {
            setEditorZoomScale(CGFloat(savedScale))
        }
        #endif
    }

    private func toggleLineNumbers() {
        showLineNumbers.toggle()
        UserDefaults.standard.set(showLineNumbers, forKey: Self.showLineNumbersDefaultsKey)
    }

    private func loadSavedLineNumberPreferenceIfNeeded() {
        let defaults = UserDefaults.standard

        #if os(iOS) && !targetEnvironment(macCatalyst)
        if defaults.object(forKey: Self.showLineNumbersDefaultsKey) == nil {
            showLineNumbers = false
            defaults.set(false, forKey: Self.showLineNumbersDefaultsKey)
        } else {
            showLineNumbers = defaults.bool(forKey: Self.showLineNumbersDefaultsKey)
        }
        #else
        showLineNumbers = defaults.bool(forKey: Self.showLineNumbersDefaultsKey)
        #endif
    }

    private func presentManuscriptAnalyst() {
        // Ensure the analysis request uses the latest in-editor text,
        // consistent across devices regardless of debounce timing.
        flushPendingEditorChanges()
        ManuscriptAnalystService.shared.clearReviewCache(for: file)
        showManuscriptAnalyst = true
    }
    
    private func setupOnAppear() {
        loadSavedEditorZoomScaleIfNeeded()
        loadSavedLineNumberPreferenceIfNeeded()

        // Register stylesheet with provider for image caption rendering
        if let styleSheet = file.project?.styleSheet {
            _ = StyleSheetProvider.shared.register(
                styleSheet: styleSheet,
                for: file.id,
                ownerID: styleSheetRegistrationOwnerID
            )
        }
        
        // Open the latest usable version without saving just because the file was selected.
        // Under Ensembles, a follower can briefly have an empty latest version while the
        // content-bearing version arrives separately; selecting that empty version and saving
        // on open makes the blank state look authoritative.
        selectLatestUsableVersionForEditing()
        hasMissingSyncedBody = Self.isMissingSyncedBody(file.currentVersion)
        if hasMissingSyncedBody {
            #if DEBUG
            print("⚠️ [FileEditView] '\(file.name)' has a synced-empty body shell; keeping editor read-only until body data arrives")
            #endif
        }

        if let currentVersion = file.currentVersion,
           currentVersion.reconcileContentFromFormattedPayloadIfPossible() {
            file.modifiedDate = Date()
            WriteCoalescer.shared?.requestSave(reason: "reconcile-formatted-source-text")
            #if DEBUG
            print("🩹 [FileEditView] Recovered stale plain text from verified formatted payload")
            #endif
        }
        
        // Load content from database - ALWAYS normalize for iPhone
        if let savedContent = file.currentVersion?.attributedContent {
            hasMismatchedFormattedContent = file.currentVersion?.hasFormattedContentSyncMismatch == true
            hasMissingAttachments = Self.hasUnrecognizedAttachmentPlaceholders(in: savedContent)
            let isFormattedPayloadComplete = !hasMismatchedFormattedContent && !hasMissingAttachments
            #if DEBUG
            if hasMismatchedFormattedContent {
                print("⚠️ [FileEditView] formattedContent fingerprint mismatches plain text — suppressing automatic saves until sync completes or user edits")
            }
            if hasMissingAttachments {
                print("⚠️ [FileEditView] Detected unrecognized U+FFFC placeholder(s) — suppressing saves until sync completes")
            }
            #endif

            if isFormattedPayloadComplete,
               file.currentVersion?.formattedContentSyncData == nil,
               let existingFormattedContent = file.currentVersion?.formattedContent {
                file.currentVersion?.setFormattedContentData(existingFormattedContent, sourceText: file.currentVersion?.content)
                file.modifiedDate = Date()
                WriteCoalescer.shared?.requestSave(reason: "backfill-formatted-content-sync-data")
            }

            let shouldPersistInlineHeadingRepair: Bool = {
                guard let raw = file.currentVersion?.effectiveFormattedContent else { return false }
                return AttributedStringSerializer.containsInlineHeadingStyleArtifacts(in: raw, text: file.currentVersion?.content ?? "")
            }()

            let hasFragmentedTextStyleArtifacts: Bool = {
                guard let raw = file.currentVersion?.effectiveFormattedContent else { return false }
                return AttributedStringSerializer.containsFragmentedTextStyleArtifacts(
                    in: raw,
                    text: file.currentVersion?.content ?? ""
                )
            }()

            // Strip adaptive colors (black/white/gray) to support dark mode properly
            var processedContent = AttributedStringSerializer.stripAdaptiveColors(from: savedContent)
            var shouldPersistFragmentedStyleRepair = false

            if hasFragmentedTextStyleArtifacts, let project = file.project {
                let repairedContent = StyleReapplicationAttributeMerger.reapplyStyles(
                    in: processedContent
                ) { styleName in
                    StyleSheetService.resolveStyle(
                        named: styleName,
                        for: project,
                        context: modelContext
                    )
                }
                if !repairedContent.isEqual(to: processedContent) {
                    processedContent = repairedContent
                    shouldPersistFragmentedStyleRepair = true
                }
            }

            if ImageAttachment.normalizeFileIDs(in: processedContent, to: file.id),
               isFormattedPayloadComplete {
                file.currentVersion?.attributedContent = processedContent
                file.modifiedDate = Date()
                WriteCoalescer.shared?.requestSave(reason: "open-image-attachment-file-id-repair")
            }
            
            // No iPhone-specific font changes - use view scale transform instead
            
            // Strip orphaned U+FFFC characters: these are stale attachment placeholders
            // left behind when an attachment was deleted but the character remained.
            // Only do this when formattedContent IS present — if formattedContent is nil,
            // the U+FFFC might belong to a real attachment waiting for CloudKit sync.
            if isFormattedPayloadComplete,
               file.currentVersion?.effectiveFormattedContent != nil {
                let cleanedContent = Self.stripOrphanedAttachmentPlaceholders(from: processedContent)
                if cleanedContent.length != processedContent.length {
                    #if DEBUG
                    print("🧹 [FileEditView] Stripped \(processedContent.length - cleanedContent.length) orphaned U+FFFC character(s) from content")
                    #endif
                    processedContent = cleanedContent
                    // Persist the cleaned content so the stale U+FFFC doesn't recur
                    file.currentVersion?.attributedContent = cleanedContent
                    WriteCoalescer.shared?.requestSave(reason: "open-orphaned-attachment-placeholder-cleanup")
                }
            }
            
            attributedContent = processedContent
            previousContent = attributedContent.string
            previousAttributedContent = processedContent  // Cache for undo without expensive DB fetch

            if shouldPersistFragmentedStyleRepair, isFormattedPayloadComplete {
                file.currentVersion?.attributedContent = processedContent
                file.modifiedDate = Date()
                WriteCoalescer.shared?.requestSave(reason: "open-fragmented-style-repair")
                #if DEBUG
                print("🩹 Persisted fragmented text-style repair for CloudKit sync")
                #endif
            }

            // If decode repaired malformed inline heading runs (oversized "bold" fragments),
            // persist immediately so CloudKit exports the cleaned content to other devices.
            if shouldPersistInlineHeadingRepair {
                if isFormattedPayloadComplete {
                    file.currentVersion?.attributedContent = processedContent
                    file.modifiedDate = Date()
                    WriteCoalescer.shared?.requestSave(reason: "open-inline-heading-repair")
                    #if DEBUG
                    print("🩹 Persisted inline-heading repair for CloudKit sync")
                    #endif
                } else {
                    #if DEBUG
                    print("⚠️ [FileEditView] Skipping inline-heading repair persistence — formatted content is still syncing")
                    #endif
                }
            }
            
            // Detect incomplete CloudKit sync: plain text has U+FFFC attachment
            // placeholders but the decoded attributed content has no recognized attachments.
            // This happens when the phone's formattedContent (with base64 image data)
            // hasn't been exported/imported yet. Suppress saves until sync delivers it
            // or the user makes an intentional edit.
            // CRITICAL: Count ALL recognized attachment types, not just images.
            // U+FFFC is used by ImageAttachment, CommentAttachment, FootnoteAttachment,
            // and ReferenceAttachment. Only unrecognized placeholders indicate sync issues.
            hasMissingAttachments = Self.hasUnrecognizedAttachmentPlaceholders(in: processedContent)
            
            if !isFormattedContentSyncIncomplete {
                // CRITICAL: Restore orphaned comment markers from database
                // Comments created before we added serialization support need to be re-inserted
                restoreOrphanedCommentMarkers()
                
                // Reconcile footnote attachment numbers with database
                // Ensures text attachment numbers match the authoritative model numbers
                reconcileFootnoteNumbers()
            } else {
                #if DEBUG
                print("⚠️ [FileEditView] Skipping marker restoration/reconciliation — formatted content is still syncing")
                #endif
            }
            
            // FEATURE 029: Restore ReferenceAttachment instances from metadata
            // Since RTF format doesn't preserve custom attachment subclasses,
            // we use the metadata to recreate them on load
            if let metadataData = file.currentVersion?.referenceMetadataData,
               let metadata = ReferenceMetadata.decode(metadataData) {
                attributedContent = restoreReferenceAttachments(in: attributedContent, from: metadata)
            }
            attributedContent = normalizeReferenceAttachmentsToText(in: attributedContent)
            
            // Position cursor at beginning of text (unless opening from search, which will position at first match)
            if searchContext == nil || searchContext?.shouldActivate == false {
                selectedRange = NSRange(location: 0, length: 0)
            }
        }
        
        // Feature 031: TOC file detection and regeneration
        // If this is a TOC file (flagged or by name), regenerate its content from manuscript headings
        let isTOCByName = file.name == "Table of Contents" || file.name == "Contents"
        let isInFrontMatter = file.parentFolder?.name == "Front Matter"
        
        // Try to find project - first directly, then by traversing folder hierarchy
        var projectForTOC: Project? = file.project
        if projectForTOC == nil {
            // Traverse up the folder tree to find the project
            var currentFolder = file.parentFolder
            while let folder = currentFolder {
                if let proj = folder.project {
                    projectForTOC = proj
                    break
                }
                currentFolder = folder.parentFolder
            }
        }
        
        #if DEBUG
        print("📑 TOC Detection check:")
        print("   File name: '\(file.name)'")
        print("   isTOCByName: \(isTOCByName)")
        print("   Parent folder: '\(file.parentFolder?.name ?? "nil")'")
        print("   isInFrontMatter: \(isInFrontMatter)")
        print("   file.isTOCFile: \(file.isTOCFile)")
        print("   file.project (direct): \(file.project != nil ? "✅ \(file.project?.name ?? "")" : "❌ nil")")
        print("   projectForTOC (traversed): \(projectForTOC != nil ? "✅ \(projectForTOC?.name ?? "")" : "❌ nil")")
        #endif
        
        if (file.isTOCFile || (isTOCByName && isInFrontMatter)), let project = projectForTOC {
            // CRITICAL: Do NOT regenerate TOC for markdown files!
            // Markdown TOC files have manually-crafted links that would be destroyed by regeneration.
            // The regeneration service only produces rich text, not markdown.
            if file.isMarkdown {
                #if DEBUG
                print("📑 ⚠️ TOC file detected but skipping regeneration - file is markdown mode")
                print("📑 Markdown TOC files use manual link syntax that must be preserved")
                #endif
            } else {
                #if DEBUG
                print("📑 ✅ TOC file detected! Regenerating content...")
                #endif
                // Mark as TOC file if detected by name
                if !file.isTOCFile && isTOCByName {
                    file.isTOCFile = true
                }
                regenerateTOCContent(for: project)
            }
        } else {
            #if DEBUG
            print("📑 ❌ Not detected as TOC file")
            if !file.isTOCFile && !isTOCByName {
                print("   Reason: Name doesn't match 'Table of Contents' or 'Contents'")
            } else if isTOCByName && !isInFrontMatter {
                print("   Reason: Not in 'Front Matter' folder")
            } else if projectForTOC == nil {
                print("   Reason: Could not find project (neither direct nor via folder traversal)")
            }
            #endif
        }
        
        // Position cursor at end of file without showing keyboard for existing content.
        // Empty files are usually opened to start typing immediately, so don't schedule
        // delayed resigns that can interrupt the first keystroke.
        if file.currentVersion?.isLocked != true && searchContext == nil {
            let shouldSuppressInitialKeyboard = attributedContent.length > 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.positionEditorForInitialNavigation(
                    shouldSuppressInitialKeyboard: shouldSuppressInitialKeyboard
                )
            }
            // Second resign after navigation transition completes
            // iOS can auto-focus the first editable text view after push animation finishes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if let textView = self.textViewCoordinator.textView,
                   shouldSuppressInitialKeyboard,
                   textView.isFirstResponder {
                    textView.resignFirstResponder()
                }
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
                // Modern JSON format documents SHOULD have styles reapplied
                let isLegacyRTF = AttributedStringSerializer.isLegacyRTFFormat(file.currentVersion?.effectiveFormattedContent)
                
                if !isLegacyRTF
                    && !hasMissingAttachments
                    && !hasMismatchedFormattedContent
                    && !hasMissingSyncedBody
                    && shouldReapplyStylesOnOpen(for: project) {
                    #if DEBUG
                    print("📝 onAppear: Reapplying styles to pick up any changes")
                    #endif
                    requestStyleReapply()
                } else {
                    #if DEBUG
                    if hasMissingAttachments {
                        print("📝 onAppear: Skipping style reapply — content has missing attachments (CloudKit sync incomplete)")
                    } else if hasMismatchedFormattedContent {
                        print("📝 onAppear: Skipping style reapply — formattedContent does not match plain text (CloudKit sync incomplete)")
                    } else {
                        print("📝 onAppear: Skipping style reapply for legacy RTF document (preserves direct formatting)")
                    }
                    #endif
                }
                
                let attrs = attributedContent.attributes(at: 0, effectiveRange: nil)
                textViewCoordinator.modifyTypingAttributes { textView in
                    textView.typingAttributes = attrs
                }
            } else if !hasMissingSyncedBody {
                let firstParagraphStyleName = project.styleSheet?.firstParagraphStyle?.name ?? UIFont.TextStyle.body.rawValue
                let bodyAttrs = TextFormatter.getTypingAttributes(
                    forStyleNamed: firstParagraphStyleName,
                    project: project,
                    context: modelContext
                )
                textViewCoordinator.modifyTypingAttributes { textView in
                    textView.typingAttributes = bodyAttrs
                    // Force redraw to trigger custom draw() method for empty document numbering
                    textView.setNeedsDisplay()
                }
                currentParagraphStyle = UIFont.TextStyle(rawValue: firstParagraphStyleName)
                #if DEBUG
                print("📝 onAppear: Set typing attributes for empty document using '\(firstParagraphStyleName)' and forced redraw")
                #endif
            } else {
                #if DEBUG
                print("📝 onAppear: Skipping empty-document typing attributes — synced body is missing")
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
        
        // Update poetry validation badge asynchronously to avoid blocking initial render
        updateValidationBadgeAsync()
        
        // Sync back matter settings with actual files (handles imported projects)
        syncBackMatterSettingsWithActualFiles()
        
    }

    private func returnToProjectTopLevel() {
        flushPendingEditorChanges()
        guard let project = file.project ?? file.parentFolder?.resolvedProject ?? findProjectInHierarchy() else {
            dismiss()
            return
        }
        contentViewState.showProjectContent(project)
    }
    
    private func selectLatestUsableVersionForEditing() {
        let sortedVersions = file.sortedVersions
        guard !sortedVersions.isEmpty else { return }

        func hasUsableContent(_ version: Version) -> Bool {
            if !version.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
            if let data = version.effectiveFormattedContent,
               !data.isEmpty,
               AttributedStringSerializer.isLegacyRTFFormat(data) {
                return true
            }
            return false
        }

        let selectedIndex = sortedVersions.lastIndex(where: hasUsableContent) ?? (sortedVersions.count - 1)
        #if DEBUG
        let versionSummaries = sortedVersions.enumerated().map { index, version in
            let marker = index == selectedIndex ? "*" : " "
            return "\(marker)v\(version.versionNumber):text=\(version.content.count),formatted=\(version.effectiveFormattedContent?.count ?? 0),sourceLen=\(version.formattedContentSourceTextLength.map(String.init) ?? "nil"),legacyRTF=\(AttributedStringSerializer.isLegacyRTFFormat(version.effectiveFormattedContent))"
        }.joined(separator: " | ")
        print("📝 [FileEditView] Version candidates for '\(file.name)': \(versionSummaries)")
        #endif

        if file.currentVersionIndex != selectedIndex {
            #if DEBUG
            let selectedVersion = sortedVersions[selectedIndex]
            print("📝 [FileEditView] Opening version v\(selectedVersion.versionNumber) for '\(file.name)' without open-time save (contentLength=\(selectedVersion.content.count), formattedBytes=\(selectedVersion.effectiveFormattedContent?.count ?? 0))")
            #endif
            file.currentVersionIndex = selectedIndex
        }
    }

    private static func isMissingSyncedBody(_ version: Version?) -> Bool {
        guard let version,
              version.content.isEmpty,
              let data = version.effectiveFormattedContent,
              !data.isEmpty,
              !AttributedStringSerializer.isLegacyRTFFormat(data),
              version.formattedContentSourceTextLength == 0 else {
            return false
        }

        return true
    }

    private func updateValidationBadgeAsync() {
        // Only for poetry projects with a structured form
        guard isPoetryProject,
              let form = file.poetryForm,
              form.id != PoetryForm.freeVerseId else {
            cachedValidationIssueCount = 0
            return
        }
        
        // Capture the attributed text for background processing (needs section markers to extract poem body)
        let attrText = NSAttributedString(attributedString: attributedContent)
        
        // Run validation on a background queue
        DispatchQueue.global(qos: .userInitiated).async {
            let validation = PoetryValidator.shared.validate(attributedText: attrText, against: form)
            let issueCount = validation.hasIssues ? validation.issueCount : 0
            
            // Update UI on main queue
            DispatchQueue.main.async {
                self.cachedValidationIssueCount = issueCount
            }
        }
    }

    private func positionEditorForInitialNavigation(
        shouldSuppressInitialKeyboard: Bool,
        attempt: Int = 0
    ) {
        guard let textView = textViewCoordinator.textView else { return }

        if initialCharacterPosition != nil,
           textView.attributedText.string != attributedContent.string,
           attempt < 10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.positionEditorForInitialNavigation(
                    shouldSuppressInitialKeyboard: shouldSuppressInitialKeyboard,
                    attempt: attempt + 1
                )
            }
            return
        }

        let requestedPosition = initialCharacterPosition ?? textView.attributedText.length
        let position = initialCharacterPosition == nil
            ? min(max(0, requestedPosition), textView.attributedText.length)
            : textView.resolvedNavigationPosition(requestedPosition, headingText: initialHeadingText)
        let range = NSRange(location: position, length: 0)
        selectedRange = range
        textView.selectedRange = range

        if initialCharacterPosition != nil {
            #if targetEnvironment(macCatalyst)
            textView.scrollCharacterToTop(position, animated: true)
            #else
            textView.scrollCharacterToTop(position)
            #endif
        } else {
            textView.scrollRangeToVisible(range)
        }

        if shouldSuppressInitialKeyboard {
            textView.resignFirstResponder()
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
            requestStyleReapply()
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
            if let styleName = notification.userInfo?["styleName"] as? String {
                requestStyleDefinitionReapply(styleName: styleName)
            } else {
                requestStyleReapply()
            }
        } else {
            #if DEBUG
            print("📝 Document is empty, skipping reapply")
            #endif
        }
        
        // Update footnote marker style (numeric/typographic) from stylesheet
        reconcileFootnoteNumbers()
        
        // Regenerate back matter files with updated styles
        updateBackMatterFiles()
        
        // If we're viewing a back matter file, reload its content
        if file.isBackMatterFile {
            #if DEBUG
            print("📝 Reloading back matter file content after style change")
            #endif
            if let version = file.currentVersion,
               let content = version.attributedContent {
                attributedContent = content
                refreshTrigger = UUID()
            }
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
        guard let currentVersion = file.currentVersion else { return }
        
        let markerStyle = file.project?.styleSheet?.footnoteMarkerStyle ?? .numeric
        let sourceContent = textViewCoordinator.textView?.attributedText ?? attributedContent
        let mutableContent = NSMutableAttributedString(attributedString: sourceContent)

        if FootnoteInsertionHelper.syncFootnotesWithMarkers(
            in: mutableContent,
            forVersion: currentVersion,
            context: modelContext,
            markerStyle: markerStyle,
            deleteMissingModels: false
        ) {
            // Update the attributed content
            attributedContent = mutableContent

            textViewCoordinator.modifyTypingAttributes { textView in
                let savedSelection = textView.selectedRange
                textView.textStorage.setAttributedString(mutableContent)
                if savedSelection.location <= textView.textStorage.length {
                    textView.selectedRange = savedSelection
                }
                textView.layoutManager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: textView.textStorage.length), actualCharacterRange: nil)
                textView.layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: textView.textStorage.length))
                textView.setNeedsDisplay()
            }

            cancelPendingEditorSave()
            saveChanges()
            refreshTrigger = UUID()
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
        previousAttributedContent = restoredContent
        clearMissingImageSelection(afterRestoring: restoredContent)

        if notification.userInfo?["rebuildEditor"] as? Bool == true {
            selectedImage = nil
            selectedImageFrame = .zero
            selectedImagePosition = -1
            selectedRange = NSRange(
                location: min(selectedRange.location, restoredContent.length),
                length: 0
            )
            forceRefresh.toggle()
            refreshTrigger = UUID()
            searchManager.notifyTextChanged()
            if showSpellingBar {
                DispatchQueue.main.async {
                    scanDocumentSpelling()
                }
            }
            return
        }

        if notification.userInfo?["updateEditorInPlace"] as? Bool == true,
           let textView = textViewCoordinator.textView {
            let currentSelection = textView.selectedRange
            textView.textStorage.setAttributedString(restoredContent)
            if let caretPosition = notification.userInfo?["caretPosition"] as? Int {
                let location = min(caretPosition, restoredContent.length)
                selectedRange = NSRange(location: location, length: 0)
                textView.selectedRange = selectedRange
                textView.tintColor = .systemBlue
            } else if currentSelection.location <= restoredContent.length {
                textView.selectedRange = NSRange(
                    location: currentSelection.location,
                    length: min(currentSelection.length, restoredContent.length - currentSelection.location)
                )
            }
            textView.layoutManager.invalidateLayout(
                forCharacterRange: NSRange(location: 0, length: restoredContent.length),
                actualCharacterRange: nil
            )
            textView.layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: restoredContent.length))
            textView.layoutManager.ensureLayout(for: textView.textContainer)
            textView.setNeedsLayout()
            textView.setNeedsDisplay()
            searchManager.notifyTextChanged()
            if showSpellingBar {
                spellingManager.connect(to: textView)
                spellingManager.scan(attributedText: textView.attributedText, startingAt: textView.selectedRange.location)
            }
            return
        }
        
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
        if showSpellingBar {
            DispatchQueue.main.async {
                scanDocumentSpelling()
            }
        }
    }

    private func clearMissingImageSelection(afterRestoring content: NSAttributedString) {
        let restoredImage = selectedImagePosition >= 0 && selectedImagePosition < content.length
            ? content.attribute(
                .attachment,
                at: selectedImagePosition,
                effectiveRange: nil
            ) as? ImageAttachment
            : nil
        let imageStillExists = if let selectedImage {
            restoredImage?.imageID == selectedImage.imageID
        } else {
            restoredImage != nil
        }

        guard !imageStillExists else { return }

        selectedImage = nil
        selectedImageFrame = .zero
        selectedImagePosition = -1
        textViewCoordinator.textView?.clearImageSelectionOverlay()
    }
    
    // MARK: - Attributed Text Handling

    private func simpleInsertion(from oldText: String, to newText: String) -> (position: Int, text: String)? {
        guard newText.count > oldText.count else { return nil }

        var oldPrefixIndex = oldText.startIndex
        var newPrefixIndex = newText.startIndex
        var position = 0

        while oldPrefixIndex < oldText.endIndex,
              newPrefixIndex < newText.endIndex,
              oldText[oldPrefixIndex] == newText[newPrefixIndex] {
            oldPrefixIndex = oldText.index(after: oldPrefixIndex)
            newPrefixIndex = newText.index(after: newPrefixIndex)
            position += 1
        }

        var oldSuffixIndex = oldText.endIndex
        var newSuffixIndex = newText.endIndex

        while oldSuffixIndex > oldPrefixIndex,
              newSuffixIndex > newPrefixIndex {
            let previousOldIndex = oldText.index(before: oldSuffixIndex)
            let previousNewIndex = newText.index(before: newSuffixIndex)
            guard oldText[previousOldIndex] == newText[previousNewIndex] else { break }
            oldSuffixIndex = previousOldIndex
            newSuffixIndex = previousNewIndex
        }

        guard oldPrefixIndex == oldSuffixIndex else { return nil }

        let insertedText = String(newText[newPrefixIndex..<newSuffixIndex])
        guard !insertedText.isEmpty else { return nil }
        return (position, insertedText)
    }

    private var isFormattedContentSyncIncomplete: Bool {
        hasMissingAttachments || hasMismatchedFormattedContent || hasMissingSyncedBody
    }

    private func suppressEditorWriteForIncompleteSync(reason: String) -> Bool {
        guard isFormattedContentSyncIncomplete else { return false }
        cancelPendingEditorSave()
        #if DEBUG
        print("⚠️ [FileEditView] Suppressing editor write (\(reason)) — formatted content is still syncing")
        #endif
        reloadFromRemoteChangeIfSafe()
        return true
    }
    
    private func scheduleEditorSave(_ attributedTextToSave: NSAttributedString) {
        guard !isFormattedContentSyncIncomplete else {
            #if DEBUG
            print("⚠️ [FileEditView] Skipping scheduled editor save — formatted content is still syncing")
            #endif
            return
        }

        saveDebounceTimer?.invalidate()
        pendingDebouncedAttributedContent = attributedTextToSave
        pendingDebouncedSaveNeedsTextViewSnapshot = false
        let coalescer = WriteCoalescer.shared
        scheduleEditorSaveTimer(coalescer: coalescer)
    }

    private func scheduleEditorSaveFromTextView(delay: TimeInterval = 15.0, waitsForRecentEditingToSettle: Bool = true) {
        guard !isFormattedContentSyncIncomplete else {
            #if DEBUG
            print("⚠️ [FileEditView] Skipping scheduled text-view save — formatted content is still syncing")
            #endif
            return
        }

        saveDebounceTimer?.invalidate()
        pendingDebouncedAttributedContent = nil
        pendingDebouncedSaveNeedsTextViewSnapshot = true
        let coalescer = WriteCoalescer.shared
        scheduleEditorSaveTimer(coalescer: coalescer, delay: delay, waitsForRecentEditingToSettle: waitsForRecentEditingToSettle)
    }

    private func scheduleEditorSaveTimer(coalescer: WriteCoalescer?, delay: TimeInterval = 15.0, waitsForRecentEditingToSettle: Bool = true) {
        saveDebounceTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            Task { @MainActor in
                if waitsForRecentEditingToSettle,
                   coalescer?.editingActivity != .idle || coalescer?.hasRecentEditingActivity(within: 20) == true {
                    self.scheduleEditorSaveTimer(coalescer: coalescer, delay: delay, waitsForRecentEditingToSettle: waitsForRecentEditingToSettle)
                    return
                }

                self.commitPendingEditorSave(reason: "file-editor-typing-save-timer", coalescer: coalescer)
            }
        }
    }

    @discardableResult
    private func commitPendingEditorSave(reason: String, coalescer: WriteCoalescer? = nil) -> Bool {
        guard !isFormattedContentSyncIncomplete else {
            cancelPendingEditorSave()
            #if DEBUG
            print("⚠️ [FileEditView] Commit skipped (\(reason)) — formatted content is still syncing")
            #endif
            return false
        }

        let attributedTextToSave: NSAttributedString
        if let pendingDebouncedAttributedContent {
            attributedTextToSave = pendingDebouncedAttributedContent
        } else if pendingDebouncedSaveNeedsTextViewSnapshot,
                  let textView = textViewCoordinator.textView,
                  let textViewContent = textView.attributedText {
            attributedTextToSave = NSAttributedString(attributedString: textViewContent)
        } else {
            return false
        }
        saveDebounceTimer?.invalidate()
        saveDebounceTimer = nil
        pendingDebouncedAttributedContent = nil
        pendingDebouncedSaveNeedsTextViewSnapshot = false

        let contentToPersist = normalizeReferenceAttachmentsToText(in: attributedTextToSave)
        if contentToPersist !== attributedTextToSave,
           let textView = textViewCoordinator.textView {
            textView.textStorage.setAttributedString(contentToPersist)
        }

        attributedContent = contentToPersist
        file.currentVersion?.attributedContent = contentToPersist
        file.currentVersion?.referenceMetadataData = extractReferenceMetadata(from: contentToPersist).encode()
        previousContent = contentToPersist.string
        previousAttributedContent = contentToPersist
        file.modifiedDate = Date()

        (coalescer ?? WriteCoalescer.shared)?.requestSave(reason: reason)
        attemptPendingStyleReapply()
        return true
    }

    private func cancelPendingEditorSave() {
        saveDebounceTimer?.invalidate()
        saveDebounceTimer = nil
        pendingDebouncedAttributedContent = nil
        pendingDebouncedSaveNeedsTextViewSnapshot = false
    }

    private func handleSimpleTypingChange(range: NSRange, replacementText: String, selectedRange newSelectedRange: NSRange) {
        guard !isPerformingUndoRedo else { return }
        WriteCoalescer.shared?.noteEditingActivity()

        guard !suppressEditorWriteForIncompleteSync(reason: "simple typing") else { return }

        guard !searchManager.isPerformingBatchReplace else { return }

        if file.currentVersion?.isLocked == true, !attemptedEdit {
            showLockedVersionWarning = true
            if let currentVersion = file.currentVersion {
                attributedContent = currentVersion.attributedContent ?? NSAttributedString(string: "")
            }
            return
        }

        undoManager.execute(TextInsertCommand(position: range.location, text: replacementText, targetFile: file))

        let previousNSString = previousContent as NSString
        if range.location <= previousNSString.length,
           range.location + range.length <= previousNSString.length {
            previousContent = previousNSString.replacingCharacters(in: range, with: replacementText)
        } else if let liveText = textViewCoordinator.textView?.attributedText?.string {
            previousContent = liveText
        }
        previousAttributedContent = nil
        scheduleEditorSaveFromTextView(delay: 2.0, waitsForRecentEditingToSettle: false)
    }

    private func handleAttributedTextChange(_ change: TextEditorChange) {
        let newAttributedText = change.attributedText
        guard !isPerformingUndoRedo else {
            return
        }
        WriteCoalescer.shared?.noteEditingActivity()

        guard !suppressEditorWriteForIncompleteSync(reason: "attributed text change") else { return }
        
        // Skip during batch replace - undo will be handled manually
        guard !searchManager.isPerformingBatchReplace else {
            return
        }

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

        if let range = change.range,
           range.length == 0,
           let replacementText = change.replacementText,
           !replacementText.isEmpty,
           replacementText.rangeOfCharacter(from: .newlines) == nil {
            undoManager.execute(TextInsertCommand(position: range.location, text: replacementText, targetFile: file))
            previousContent = newAttributedText.string
            previousAttributedContent = newAttributedText
            scheduleEditorSave(newAttributedText)
            return
        }
        
        let newContent = newAttributedText.string
        
        // Register both text changes and attribute-only formatting changes.
        // BIU actions and some system edit actions can change attributes while keeping the same string.
        let hasTextChanged = newContent != previousContent
        let hasAttributeChanged: Bool = hasTextChanged ? false : {
            guard let previousAttributedContent else { return false }
            return !newAttributedText.isEqual(to: previousAttributedContent)
        }()

        guard hasTextChanged || hasAttributeChanged else {
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
        
        if hasTextChanged, let insertion = simpleInsertion(from: previousContent, to: newContent) {
            undoManager.execute(TextInsertCommand(position: insertion.position, text: insertion.text, targetFile: file))
        } else {
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
            // PERFORMANCE FIX: Don't call undoManager.execute() which triggers expensive
            // AttributedStringSerializer.encode() on every keystroke via the attributedContent setter.
            // Instead, just push the command for undo support and defer encoding to the save timer.
            undoManager.push(command)
        }
        
        // Update previous content for next comparison
        previousContent = newContent
        previousAttributedContent = newAttributedText  // Cache for next change
        
        scheduleEditorSave(newAttributedText)
        
        // PERFORMANCE FIX: Debounce endnote cleanup - no need to check on every keystroke
        endnoteCleanupTimer?.invalidate()
        endnoteCleanupTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            self.cleanupOrphanedEndnoteReferences()
        }
        
        // PERFORMANCE FIX: Debounce poetry validation badge update
        validationBadgeTimer?.invalidate()
        validationBadgeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            self.updateValidationBadgeAsync()
        }
        
        // PERFORMANCE FIX: Removed forced textView.setNeedsDisplay() + layoutIfNeeded()
        // UITextView already handles display updates after textViewDidChange.
        // The forced layout was redundant for normal typing and caused extra layout passes.
        
        // Notify search manager that text changed (only re-searches if search is active)
        searchManager.notifyTextChanged()
    }
    
    // MARK: - Image Selection

    private func handleImageCutRequested(attachment: ImageAttachment, position: Int) {
        textViewCoordinator.flushPendingTyping?()
        guard let command = DeleteImageCommand(position: position, attachment: attachment, targetFile: file) else {
            return
        }

        selectedImage = nil
        selectedImageFrame = .zero
        selectedImagePosition = -1
        selectedRange = NSRange(location: position, length: 0)
        undoManager.execute(command)
    }

    private func handleImagePasteRequested(attachment: ImageAttachment, position: Int) {
        flushPendingEditorChanges(reason: "image-paste-preflight")
        guard let imageData = attachment.imageData ?? attachment.image?.pngData() else {
            return
        }

        let command = InsertImageCommand(
            description: "Paste Image",
            position: position,
            imageData: imageData,
            scale: attachment.scale,
            alignment: attachment.alignment,
            hasCaption: attachment.hasCaption,
            captionText: attachment.captionText ?? "",
            captionStyle: attachment.captionStyle ?? "UICTFontTextStyleCaption1",
            captionPrefix: attachment.captionPrefix,
            imageStyleName: attachment.imageStyleName,
            spacingAbove: attachment.spacingAbove,
            spacingBelow: attachment.spacingBelow,
            borderStyle: attachment.borderStyle,
            borderPadding: attachment.borderPadding,
            originalFilename: attachment.originalFilename,
            targetFile: file
        )
        undoManager.execute(command)
        try? WriteCoalescer.shared?.requestSaveAndFlush(reason: "image-paste")

        let imagePosition = command.insertedImagePosition ?? position
        selectedRange = NSRange(location: imagePosition + 1, length: 0)
        selectedImage = nil
        selectedImageFrame = .zero
        selectedImagePosition = -1
    }
    
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
                guard position >= 0,
                      position < textView.textStorage.length,
                      textView.textStorage.attribute(.attachment, at: position, effectiveRange: nil) is ImageAttachment else {
                    return
                }
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
        guard !suppressEditorWriteForIncompleteSync(reason: "insert comment") else { return }
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
                // Cancel any pending debounce timer to prevent it from overwriting
                // our save with stale pre-comment content
                cancelPendingEditorSave()
                
                // Update the attributed content binding
                let updatedContent = textView.attributedText ?? NSAttributedString()
                attributedContent = updatedContent
                previousContent = updatedContent.string
                previousAttributedContent = updatedContent
                saveChanges()
            }
        }
        
        // Reset dialog
        newCommentText = ""
        showNewCommentDialog = false
    }
    
    private func insertNewFootnote() {
        guard !newFootnoteText.isEmpty else { return }
        guard !suppressEditorWriteForIncompleteSync(reason: "insert footnote") else { return }
        guard !isInsertingFootnote else { return }
        guard let currentVersion = file.currentVersion else {
            #if DEBUG
            print("❌ Cannot insert footnote: no current version")
            #endif
            return
        }

        isInsertingFootnote = true
        defer { isInsertingFootnote = false }
        
        // Insert footnote at cursor position
        if let textView = textViewCoordinator.textView {
            let markerStyle = file.project?.styleSheet?.footnoteMarkerStyle ?? .numeric
            #if DEBUG
            print("🧪 [FootnoteDiag] insertNewFootnote BEFORE insert textView=\(footnoteDebugSummary(textView.attributedText)) binding=\(footnoteDebugSummary(attributedContent)) selected=\(textView.selectedRange)")
            #endif
            isPerformingUndoRedo = true
            let footnote = FootnoteInsertionHelper.insertFootnoteAtCursor(
                in: textView,
                footnoteText: newFootnoteText,
                version: currentVersion,
                context: modelContext,
                markerStyle: markerStyle
            )
            
            if let footnote = footnote {
                #if DEBUG
                print("🔢 Footnote inserted: \(footnote.text)")
                print("🧪 [FootnoteDiag] insertNewFootnote AFTER helper textView=\(footnoteDebugSummary(textView.attributedText)) modelAttachment=\(footnote.attachmentID.uuidString.prefix(8)) modelNumber=\(footnote.number) modelPosition=\(footnote.characterPosition)")
                #endif
                
                // CRITICAL: Update all footnote numbers in the text to match database
                let updatedContent = FootnoteInsertionHelper.updateAllFootnoteNumbers(
                    in: textView.attributedText ?? NSAttributedString(),
                    forVersion: currentVersion,
                    context: modelContext,
                    markerStyle: file.project?.styleSheet?.footnoteMarkerStyle ?? .numeric
                )

                #if DEBUG
                print("🧪 [FootnoteDiag] insertNewFootnote AFTER updateAll updatedContent=\(footnoteDebugSummary(updatedContent))")
                #endif
                
                // Update the text view with renumbered footnotes
                textView.textStorage.setAttributedString(updatedContent)
                textView.layoutManager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: textView.textStorage.length), actualCharacterRange: nil)
                textView.layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: textView.textStorage.length))
                textView.setNeedsDisplay()
                
                // Cancel any pending debounce timer to prevent it from overwriting
                // our save with stale pre-footnote content
                cancelPendingEditorSave()
                
                // Update the attributed content binding
                attributedContent = updatedContent
                previousContent = updatedContent.string
                previousAttributedContent = updatedContent
                #if DEBUG
                print("🧪 [FootnoteDiag] insertNewFootnote AFTER binding textView=\(footnoteDebugSummary(textView.attributedText)) binding=\(footnoteDebugSummary(attributedContent))")
                #endif
                saveChanges()
                WriteCoalescer.shared?.flush()
                #if DEBUG
                print("🧪 [FootnoteDiag] insertNewFootnote AFTER save/flush textView=\(footnoteDebugSummary(textView.attributedText)) binding=\(footnoteDebugSummary(attributedContent)) stored=\(footnoteDebugSummary(currentVersion.attributedContent))")
                #endif
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.isPerformingUndoRedo = false
            }
        }
        
        // Reset dialog
        newFootnoteText = ""
        showNewFootnoteDialog = false
    }
    
    /// Remove a footnote attachment from the text when it's moved to trash
    private func removeFootnoteFromText(_ footnote: FootnoteModel) {
        #if DEBUG
        print("🗑️ Removing footnote \(footnote.id) from text (attachmentID: \(footnote.attachmentID))")
        #endif
        
        // Set flag FIRST before any text modifications
        isPerformingUndoRedo = true

        var updatedText: NSAttributedString?
        var removedLocation: Int?

        if let textView = textViewCoordinator.textView,
           let removedRange = FootnoteInsertionHelper.removeFootnoteFromTextView(textView, footnoteID: footnote.attachmentID) {
            updatedText = textView.attributedText ?? NSAttributedString()
            removedLocation = removedRange.location
        } else {
            let sourceText = file.currentVersion?.attributedContent ?? attributedContent
            let withoutFootnote = FootnoteInsertionHelper.removeFootnote(from: sourceText, footnoteID: footnote.attachmentID)
            if withoutFootnote.string != sourceText.string || withoutFootnote.length != sourceText.length {
                updatedText = withoutFootnote
            }
        }

        if let updatedText {
            if let textView = textViewCoordinator.textView,
               textView.attributedText?.string != updatedText.string {
                textView.textStorage.setAttributedString(updatedText)
            }

            file.currentVersion?.attributedContent = updatedText
            previousContent = updatedText.string
            previousAttributedContent = updatedText
            file.modifiedDate = Date()
            attributedContent = updatedText

            WriteCoalescer.shared?.requestSave()
            WriteCoalescer.shared?.flush()

            #if DEBUG
            print("✅ Footnote removed from position \(removedLocation ?? -1)")
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
    
    // MARK: - Notes & Endnotes (Feature 029)

    private func referenceAttachmentString(_ attachment: ReferenceAttachment, in textView: UITextView, at location: Int) -> NSAttributedString {
        var attributes = textView.typingAttributes

        func nearbyAttribute(_ key: NSAttributedString.Key) -> Any? {
            let textStorage = textView.textStorage
            let candidateLocations = [location - 1, location, location + 1]
            for candidate in candidateLocations where candidate >= 0 && candidate < textStorage.length {
                if textStorage.attribute(.attachment, at: candidate, effectiveRange: nil) != nil {
                    continue
                }
                if let value = textStorage.attribute(key, at: candidate, effectiveRange: nil) {
                    return value
                }
            }
            return nil
        }

        func nearbyTextStyleName() -> String? {
            nearbyAttribute(.textStyle) as? String
        }

        func fontForTextStyle(_ styleName: String?) -> UIFont? {
            guard let styleName,
                  let style = file.project?.styleSheet?.style(named: styleName) else { return nil }
            return style.generateFont(applyPlatformScaling: true)
        }

        func character(at index: Int) -> String? {
            let nsString = textView.textStorage.string as NSString
            guard index >= 0 && index < nsString.length else { return nil }
            return nsString.substring(with: NSRange(location: index, length: 1))
        }

        func isWhitespace(_ character: String?) -> Bool {
            guard let character, let scalar = character.unicodeScalars.first else { return true }
            return CharacterSet.whitespacesAndNewlines.contains(scalar)
        }

        func shouldAddLeadingSpace() -> Bool {
            guard attachment.referenceType != .index,
                  let previous = character(at: location - 1),
                  !isWhitespace(previous) else { return false }
            return true
        }

        func shouldAddTrailingSpace() -> Bool {
            guard attachment.referenceType != .index,
                  let next = character(at: location),
                  !isWhitespace(next) else { return false }
            let noSpaceBefore = CharacterSet(charactersIn: ".,;:!?)]}")
            if let scalar = next.unicodeScalars.first, noSpaceBefore.contains(scalar) {
                return false
            }
            return true
        }

        let nearbyStyleName = nearbyTextStyleName()
        attributes[.textStyle] = nearbyStyleName ?? attributes[.textStyle]
        attributes[.font] = fontForTextStyle(nearbyStyleName) ?? nearbyAttribute(.font) ?? attributes[.font] ?? textView.font ?? UIFont.preferredFont(forTextStyle: .body)
        attributes[.foregroundColor] = nearbyAttribute(.foregroundColor) ?? attributes[.foregroundColor] ?? textView.textColor ?? UIColor.label

        attributes.removeValue(forKey: .attachment)
        attributes.removeValue(forKey: .referenceType)
        attributes.removeValue(forKey: .referenceID)
        attributes.removeValue(forKey: .referencePrimary)

        let result = NSMutableAttributedString()
        if shouldAddLeadingSpace() {
            result.append(NSAttributedString(string: " ", attributes: attributes))
        }

        let markerString: NSMutableAttributedString
        if attachment.referenceType == .index {
            markerString = NSMutableAttributedString(attachment: attachment)
        } else {
            markerString = NSMutableAttributedString(string: attachment.displayText)
        }
        let markerRange = NSRange(location: 0, length: markerString.length)
        markerString.addAttributes(attributes, range: markerRange)
        let referenceAttributes: [NSAttributedString.Key: Any] = [
            .referenceType: attachment.referenceType.rawValue,
            .referenceID: attachment.entryID.uuidString,
            .referencePrimary: attachment.isPrimaryReference
        ]
        markerString.addAttributes(referenceAttributes, range: markerRange)
        result.append(markerString)

        if shouldAddTrailingSpace() {
            result.append(NSAttributedString(string: " ", attributes: attributes))
        }

        return result
    }
    
    /// Insert a note marker at the current cursor position
    private func insertNoteMarker(for note: NoteEntry) {
        guard !suppressEditorWriteForIncompleteSync(reason: "insert note marker") else { return }
        guard let textView = textViewCoordinator.textView else {
            #if DEBUG
            print("❌ Cannot insert note marker: no text view")
            #endif
            return
        }
        
        #if DEBUG
        print("📝 Inserting \(note.isEndnote ? "endnote" : "note") marker for note \(note.id)")
        #endif
        
        // Get current cursor position
        let currentRange = textView.selectedRange
        
        // Create the reference attachment using tag-based initializer
        let attachment: ReferenceAttachment
        if let tag = note.tag, !tag.isEmpty {
            // Use tag-based reference
            attachment = ReferenceAttachment(
                referenceType: .note,
                entryID: note.id,
                tag: tag
            )
            #if DEBUG
            print("📍 Using tag-based reference: \(tag)")
            #endif
        } else {
            // Fallback to number-based reference (legacy)
            attachment = ReferenceAttachment(
                referenceType: .note,
                entryID: note.id,
                number: note.displayNumber
            )
            #if DEBUG
            print("📍 Using number-based reference: \(note.displayNumber)")
            #endif
        }
        
        // Create attributed string with the attachment
        let attachmentString = referenceAttachmentString(attachment, in: textView, at: currentRange.location)
        
        // Insert at cursor
        isPerformingUndoRedo = true
        textView.textStorage.insert(attachmentString, at: currentRange.location)
        
        // Move cursor after the marker
        let newLocation = currentRange.location + attachmentString.length
        textView.selectedRange = NSRange(location: newLocation, length: 0)
        
        // Increment reference count
        note.referenceCount += 1
        
        // Track which file contains this reference
        if !note.referencingFileIDs.contains(file.id) {
            note.referencingFileIDs.append(file.id)
        }
        
        // Update the attributed content binding
        attributedContent = textView.attributedText ?? NSAttributedString()
        
        // Save changes
        saveChanges()
        
        // Update back matter files with the new endnote
        updateBackMatterFiles()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.isPerformingUndoRedo = false
        }
        
        #if DEBUG
        print("✅ Note marker inserted at position \(currentRange.location)")
        #endif
    }
    
    private func removeReferenceMarkersFromStoredContent(entryID: UUID, referenceType: ReferenceType? = nil) -> (content: NSAttributedString, removedCount: Int) {
        let sourceContent = file.currentVersion?.attributedContent ?? attributedContent
        let mutableContent = NSMutableAttributedString(attributedString: sourceContent)
        var rangesToRemove: [NSRange] = []

        mutableContent.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutableContent.length)) { value, range, _ in
            guard let attachment = value as? ReferenceAttachment,
                  attachment.entryID == entryID else {
                return
            }

            if let referenceType, attachment.referenceType != referenceType {
                return
            }

            rangesToRemove.append(range)
        }

        mutableContent.enumerateAttributes(in: NSRange(location: 0, length: mutableContent.length)) { attributes, range, _ in
            guard let idString = attributes[.referenceID] as? String,
                  let attributedEntryID = UUID(uuidString: idString),
                  attributedEntryID == entryID else {
                return
            }

            if let referenceType,
               let typeString = attributes[.referenceType] as? String,
               ReferenceType(rawValue: typeString) != referenceType {
                return
            }

            rangesToRemove.append(range)
        }

        rangesToRemove = Array(Set(rangesToRemove.map { "\($0.location):\($0.length)" })).compactMap { key in
            let parts = key.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }
            return NSRange(location: parts[0], length: parts[1])
        }.sorted { $0.location < $1.location }

        for range in rangesToRemove.reversed() {
            mutableContent.deleteCharacters(in: range)
        }

        return (mutableContent, rangesToRemove.count)
    }

    private func persistReferenceMarkerRemoval(_ content: NSAttributedString) {
        if let textView = textViewCoordinator.textView {
            textView.textStorage.setAttributedString(content)
        }

        file.currentVersion?.attributedContent = content
        let referenceMetadata = extractReferenceMetadata(from: content)
        file.currentVersion?.referenceMetadataData = referenceMetadata.encode()
        previousContent = content.string
        previousAttributedContent = content
        file.modifiedDate = Date()
        attributedContent = content

        WriteCoalescer.shared?.requestSave()
        WriteCoalescer.shared?.flush()
    }

    /// Remove all markers for a deleted note from the text
    private func removeNoteMarkers(for note: NoteEntry) {
        #if DEBUG
        print("🗑️ Removing markers for note \(note.id)")
        #endif
        
        isPerformingUndoRedo = true

        let result = removeReferenceMarkersFromStoredContent(entryID: note.id)
        let removedCount = result.removedCount
        
        if removedCount > 0 {
            persistReferenceMarkerRemoval(result.content)
            
            // Update reference count
            note.referenceCount -= removedCount
            
            // Remove file ID if no more references in this file
            if note.referenceCount == 0 {
                note.referencingFileIDs.removeAll()
            } else {
                note.referencingFileIDs.removeAll { $0 == file.id }
            }
            
            // Update back matter files after removing note markers
            updateBackMatterFiles()
            
            #if DEBUG
            print("✅ Removed \(removedCount) markers for note \(note.id)")
            #endif
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.isPerformingUndoRedo = false
        }
    }
    
    /// Jump to the first reference marker for a note in the text
    
    /// Update back matter files with current content when notes change
    private func updateBackMatterFiles() {
        guard let fileProject = file.project else {
            #if DEBUG
            print("⚠️ Cannot update back matter files: no project")
            #endif
            return
        }
        
        #if DEBUG
        print("📁 Project folders: \(fileProject.folders?.map { $0.name } ?? [])")
        #endif
        
        // Find the Back Matter folder for this project using helper
        var backMatterFolder = fileProject.findBackMatterFolder()
        
        // If still not found, create at root level as fallback
        if backMatterFolder == nil {
            #if DEBUG
            print("⚠️ No Back Matter folder found, creating one...")
            #endif
            backMatterFolder = Folder(name: "Back Matter", project: fileProject)
            modelContext.insert(backMatterFolder!)
        }
        
        guard let backMatterFolder = backMatterFolder else { return }
        
        #if DEBUG
        print("📄 Back Matter folder files: \(backMatterFolder.files?.map { $0.name } ?? [])")
        #endif
        
        // Create BackMatterGenerator for generating content
        let backMatterGenerator = BackMatterGenerator(context: modelContext, project: fileProject)
        
        let backMatterItems: [(item: BackMatterItem, shouldUpdate: Bool)] = [
            (.endnotes, true),
            (.glossary, backMatterFolder.backMatterSettings.isEnabled(.glossary)),
            (.references, backMatterFolder.backMatterSettings.isEnabled(.references)),
            (.index, backMatterFolder.backMatterSettings.isEnabled(.index))
        ]
        
        for (item, shouldUpdate) in backMatterItems {
            guard shouldUpdate else { continue }
            
            #if DEBUG
            print("🔍 Looking for back matter file: \(item.fileName) (lowercase: \(item.fileName.lowercased()))")
            #endif
            
            // Query database directly for the file instead of using folder.files relationship
            let folderID = backMatterFolder.id
            let fileName = item.fileName
            let descriptor = FetchDescriptor<TextFile>(
                predicate: #Predicate<TextFile> { file in
                    file.parentFolder?.id == folderID && file.name == fileName
                }
            )
            
            var backMatterFile: TextFile?
            if let existingFile = try? modelContext.fetch(descriptor).first {
                backMatterFile = existingFile
                #if DEBUG
                print("✅ Found existing back matter file: \(existingFile.name)")
                #endif
            } else {
                #if DEBUG
                print("📄 Creating back matter file: \(item.fileName)")
                #endif
                backMatterFile = TextFile(name: item.fileName, parentFolder: backMatterFolder)
                modelContext.insert(backMatterFile!)
            }
            
            guard let backMatterFile = backMatterFile else { continue }
            
            #if DEBUG
            print("✏️ Updating back matter file: \(backMatterFile.name)")
            #endif
            
            // Generate fresh content for this back matter item using the generator's methods
            let generatedContent: NSAttributedString
            
            switch item {
            case .endnotes:
                generatedContent = backMatterGenerator.generateNotesSection() ?? NSAttributedString()
            case .glossary:
                generatedContent = backMatterGenerator.generateGlossarySection() ?? NSAttributedString()
            case .references:
                generatedContent = backMatterGenerator.generateReferencesSection() ?? NSAttributedString()
            case .tableOfFigures:
                // Table of Figures is generated dynamically in BackMatterGeneratedContentView
                continue
            case .index:
                generatedContent = backMatterGenerator.generateIndexSection(pageMap: [:]) ?? NSAttributedString()
            case .contributors:
                generatedContent = backMatterGenerator.generateContributorsSection() ?? NSAttributedString()
            case .backCover:
                // Back cover is an image file, no generated content
                continue
            }
            
            // Update or create the file's current version with the generated content
            if backMatterFile.currentVersion == nil {
                let newVersion = Version(versionNumber: 1)
                newVersion.textFile = backMatterFile
                newVersion.attributedContent = generatedContent
                modelContext.insert(newVersion)
                backMatterFile.currentVersionIndex = 0
            } else {
                backMatterFile.currentVersion?.attributedContent = generatedContent
            }
            
            backMatterFile.modifiedDate = Date()
            
            #if DEBUG
            print("✅ Updated back matter file: \(item.fileName)")
            #endif
        }
        
        // Save changes to the database
        WriteCoalescer.shared?.requestSave()
    }

    private func cleanupOrphanedEndnoteReferences() {
        // Find all endnote entries that are no longer referenced in the text
        let project = file.project ?? file.parentFolder?.project ?? findProjectInHierarchy()
        guard let project = project else {
            return
        }
        
        guard let entries = project.noteEntries?.filter({ $0.isEndnote }) else {
            return
        }
        
        guard let textView = textViewCoordinator.textView,
              let attributedText = textView.attributedText else {
            return
        }
        
        // Collect all endnote reference IDs currently in the text
        var referencedEntryIDs = Set<UUID>()
        attributedText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedText.length), options: []) { attachment, _, _ in
            if let refAttachment = attachment as? ReferenceAttachment,
               refAttachment.referenceType == .endnote {
                referencedEntryIDs.insert(refAttachment.entryID)
                #if DEBUG
                print("🔖 Found reference in text: \(refAttachment.entryID)")
                #endif
            }
        }
        
        // Find entries that are not referenced
        var entriesToRemove: [NoteEntry] = []
        for entry in entries {
            if !referencedEntryIDs.contains(entry.id) {
                #if DEBUG
                print("🗑️ Found orphaned endnote: \(entry.id) - not referenced in text")
                #endif
                entriesToRemove.append(entry)
            }
        }
        
        // Remove orphaned entries
        for entry in entriesToRemove {
            if let index = project.noteEntries?.firstIndex(of: entry) {
                project.noteEntries?.remove(at: index)
                #if DEBUG
                print("🗑️ Removed orphaned endnote entry: \(entry.id)")
                #endif
            }
        }
        
        // Save if any entries were removed
        if !entriesToRemove.isEmpty {
            WriteCoalescer.shared?.requestSave()
        }
    }
    
    private func findProjectInHierarchy() -> Project? {
        var current = file.parentFolder
        while current != nil {
            if let project = current?.project {
                return project
            }
            current = current?.parentFolder
        }
        return nil
    }

    /// Sync back matter settings with actual files in the Back Matter folder
    /// This is called after import to enable settings for back matter files that actually exist
    private func syncBackMatterSettingsWithActualFiles() {
        guard let project = file.project ?? file.parentFolder?.project ?? findProjectInHierarchy() else {
            #if DEBUG
            print("🔄 syncBackMatterSettings: Could not find project")
            #endif
            return
        }
        
        #if DEBUG
        print("🔄 syncBackMatterSettings: Found project: \(project.name ?? "unnamed")")
        print("  Project has \(project.folders?.count ?? 0) folders")
        if let folders = project.folders {
            for folder in folders {
                print("    - \(folder.name ?? "unnamed") (\(folder.files?.count ?? 0) files)")
            }
        }
        #endif
        
        // Find the Back Matter folder using project helper
        guard let backMatterFolder = project.findBackMatterFolder() else {
            #if DEBUG
            print("🔄 syncBackMatterSettings: Could not find Back Matter folder")
            #endif
            return
        }

        // Existing files are only authoritative for legacy projects that predate stored
        // back-matter settings. Once settings exist, a stale synced file must not re-enable itself.
        guard backMatterFolder.backMatterSettingsData == nil else { return }
        
        #if DEBUG
        print("🔄 Syncing back matter settings with actual files...")
        print("  Folder ID: \(backMatterFolder.id)")
        print("  Folder has \(backMatterFolder.files?.count ?? 0) files in relationship (diagnostic only)")
        #endif

        // Query database directly to avoid stale in-memory relationship state.
        let folderID = backMatterFolder.id
        do {
            let descriptor = FetchDescriptor<TextFile>(
                predicate: #Predicate<TextFile> { file in
                    file.parentFolder?.id == folderID
                }
            )
            let backMatterFiles = try modelContext.fetch(descriptor)
            let fileNames = Set(backMatterFiles.compactMap { $0.name })
            
            #if DEBUG
            print("📄 Back matter files from database query: \(fileNames)")
            #endif
            syncSettingsWithFileNames(fileNames, backMatterFolder: backMatterFolder)
        } catch {
            #if DEBUG
            print("❌ Failed to query back matter files: \(error)")
            #endif
        }
    }
    
    private func syncSettingsWithFileNames(_ fileNames: Set<String>, backMatterFolder: Folder) {
        // Enable settings for files that exist
        let backMatterItems: [(name: String, type: BackMatterItem)] = [
            ("Endnotes", .endnotes),
            ("Glossary", .glossary),
            ("References", .references),
            ("Index", .index)
        ]
        var didChangeSettings = false
        
        for (fileName, backMatterType) in backMatterItems {
            let fileExists = fileNames.contains(fileName)
            let isCurrentlyEnabled = backMatterFolder.backMatterSettings.isEnabled(backMatterType)
            
            #if DEBUG
            print("  Checking \(fileName): exists=\(fileExists), enabled=\(isCurrentlyEnabled)")
            #endif
            
            if fileExists && !isCurrentlyEnabled {
                #if DEBUG
                print("  ✅ Enabling \(fileName) setting (file exists)")
                #endif
                backMatterFolder.backMatterSettings.setEnabled(backMatterType, enabled: true)
                didChangeSettings = true
            } else if !fileExists && isCurrentlyEnabled {
                #if DEBUG
                print("  ❌ Disabling \(fileName) setting (file doesn't exist)")
                #endif
                backMatterFolder.backMatterSettings.setEnabled(backMatterType, enabled: false)
                didChangeSettings = true
            }
        }

        guard didChangeSettings else {
            #if DEBUG
            print("✅ Back matter settings already matched files")
            #endif
            return
        }

        WriteCoalescer.shared?.requestSave(reason: "back-matter-settings-sync")
        
        #if DEBUG
        print("✅ Back matter settings synced")
        #endif
    }
    
    // MARK: - Table of Contents (Feature 031)
    
    /// Regenerate TOC content from manuscript headings
    /// Called when a TOC file is opened
    private func regenerateTOCContent(for project: Project) {
        #if DEBUG
        print("📑 ========== TOC REGENERATION START ==========")
        print("📑 Project: \(project.name ?? "unnamed")")
        print("📑 Project type: \(project.type.rawValue)")
        print("📑 StyleSheet: \(project.styleSheet?.name ?? "none")")
        if let sheet = project.styleSheet {
            print("📑 StyleSheet has \(sheet.textStyles?.count ?? 0) text styles")
            if let styles = sheet.textStyles {
                let tocStyles = styles.filter { $0.includeInTOC }
                print("📑 Styles with includeInTOC=true: \(tocStyles.count)")
                for style in tocStyles {
                    print("📑   - \(style.displayName) (name: \(style.name), level: \(style.tocLevel))")
                }
            }
        }
        #endif
        
        let tocService = TOCGenerationService(context: modelContext)
        
        // Check how many styles are configured for TOC (for appropriate empty message)
        let stylesConfigured = tocService.countConfiguredTOCStyles(for: project)
        
        // Generate TOC entries (excluding this TOC file to avoid circular reference)
        let entries = tocService.generateEntries(for: project, tocFile: file)
        
        #if DEBUG
        print("📑 Found \(entries.count) TOC entries")
        for entry in entries {
            print("📑   Entry: '\(entry.headingText)' level=\(entry.indentLevel) from file=\(entry.sourceFile.name)")
        }
        #endif
        
        // Get TOC settings
        let settings = file.tocSettings
        #if DEBUG
        print("📑 TOC Settings: title='\(settings.title)', titleStyle=\(settings.titleStyleName), entryStyle=\(settings.entryStyleName)")
        #endif
        
        // If showing page numbers, calculate them (this may take a moment)
        if settings.showPageNumbers && !entries.isEmpty {
            isCalculatingTOCPages = true
            
            Task {
                #if DEBUG
                print("📑 Calculating page numbers...")
                #endif
                
                let entriesWithPages = await tocService.calculatePageNumbers(
                    for: entries,
                    project: project,
                    tocFile: file
                )
                
                await MainActor.run {
                    // Render TOC with calculated page numbers
                    let tocContent = tocService.renderTOC(
                        entries: entriesWithPages,
                        settings: settings,
                        project: project,
                        stylesConfigured: stylesConfigured
                    )
                    
                    #if DEBUG
                    print("📑 Rendered TOC content length: \(tocContent.length) chars")
                    print("📑 Rendered TOC preview: '\(tocContent.string.prefix(200))...'")
                    #endif
                    
                    // Update the content
                    attributedContent = tocContent
                    previousContent = attributedContent.string
                    previousAttributedContent = tocContent
                    
                    // Force view refresh to show new content
                    forceRefresh.toggle()
                    
                    // Save the generated content
                    saveChanges()
                    
                    isCalculatingTOCPages = false
                    
                    #if DEBUG
                    print("📑 ========== TOC REGENERATION END ==========")
                    #endif
                }
            }
        } else {
            // No page numbers needed, render immediately
            let tocContent = tocService.renderTOC(entries: entries, settings: settings, project: project, stylesConfigured: stylesConfigured)
            
            #if DEBUG
            print("📑 Rendered TOC content length: \(tocContent.length) chars")
            print("📑 Rendered TOC preview: '\(tocContent.string.prefix(200))...'")
            #endif
            
            // Update the content
            attributedContent = tocContent
            previousContent = attributedContent.string
            previousAttributedContent = tocContent
            
            // Force view refresh to show new content
            forceRefresh.toggle()
            
            // Save the generated content
            saveChanges()
            
            #if DEBUG
            print("📑 ========== TOC REGENERATION END ==========")
            #endif
        }
    }

    private func deleteBackMatterFileAndCleanup() {
        #if DEBUG
        print("🗑️ deleteBackMatterFileAndCleanup called")
        print("  file.name: \(file.name)")
        print("  file.parentFolder: \(file.parentFolder != nil ? "✅" : "❌ nil")")
        print("  file.project: \(file.project != nil ? "✅" : "❌ nil")")
        #endif
        
        // Navigate up to find the project through the folder hierarchy
        var currentFolder = file.parentFolder
        var project: Project?
        
        // Traverse up the folder tree to find a folder that has a project
        while let folder = currentFolder {
            #if DEBUG
            print("  Checking folder: \(folder.name ?? "unknown")")
            #endif
            if let proj = folder.project {
                project = proj
                #if DEBUG
                print("  Found project: \(proj.name ?? "unknown")")
                #endif
                break
            }
            currentFolder = folder.parentFolder
        }
        
        guard let project = project else {
            #if DEBUG
            print("❌ Cannot delete: could not find project through folder hierarchy")
            #endif
            return
        }
        
        guard let backMatterFolder = file.parentFolder else {
            #if DEBUG
            print("❌ Cannot delete: missing parent folder")
            #endif
            return
        }
        
        #if DEBUG
        print("🗑️ Deleting back matter file: \(file.name)")
        #endif
        
        // Determine reference type being removed
        var referenceTypeToRemove: ReferenceType?
        
        // Remove all references and entries for this back matter type
        if file.name == "Endnotes" {
            // NOTE: Endnotes are stored as .note type attachments (not .endnote)
            // The ReferenceAttachment.referenceType is always .note for both notes and endnotes
            // The isEndnote flag on NoteEntry distinguishes them
            referenceTypeToRemove = .note
            // Remove all endnote entries
            project.noteEntries?.removeAll(where: { $0.isEndnote })
            #if DEBUG
            print("✅ Removed all endnote entries from project")
            #endif
            // Turn off endnotes in settings
            backMatterFolder.backMatterSettings.setEnabled(.endnotes, enabled: false)
            #if DEBUG
            print("✅ Disabled endnotes setting")
            #endif
        } else if file.name == "Glossary" {
            referenceTypeToRemove = .glossary
            project.glossaryEntries?.removeAll()
            backMatterFolder.backMatterSettings.setEnabled(.glossary, enabled: false)
        } else if file.name == "References" {
            referenceTypeToRemove = .reference
            project.referenceEntries?.removeAll()
            backMatterFolder.backMatterSettings.setEnabled(.references, enabled: false)
        } else if file.name == "Index" {
            referenceTypeToRemove = .index
            project.indexEntries?.removeAll()
            backMatterFolder.backMatterSettings.setEnabled(.index, enabled: false)
        }
        
        // If this is a reference type, remove all references from all files in the project
        if let refType = referenceTypeToRemove {
            #if DEBUG
            print("🔍 Scanning project files to remove \(refType) references...")
            #endif
            removeReferenceAttachmentsFromProjectFiles(project: project, referenceType: refType)
        }
        
        // Delete the file from SwiftData
        modelContext.delete(file)
        
        #if DEBUG
        print("🗑️ File deleted from context")
        #endif
        
        WriteCoalescer.shared?.requestSave()
        
        updateBackMatterFiles()
        
        // Dismiss view
        #if DEBUG
        print("👈 Dismissing view")
        #endif
        dismiss()
    }
    
    private func removeReferenceAttachmentsFromProjectFiles(project: Project, referenceType: ReferenceType) {
        #if DEBUG
        print("🔍 removeReferenceAttachmentsFromProjectFiles: \(referenceType)")
        #endif
        
        var totalRemoved = 0
        
        func scanFolderForFiles(_ folder: Folder) {
            // Process files in this folder
            if let files = folder.files {
                for textFile in files {
                    #if DEBUG
                    let beforeLength = textFile.versions?[textFile.currentVersionIndex].attributedContent?.length ?? 0
                    #endif
                    
                    removeReferenceAttachmentsFromFile(textFile, referenceType: referenceType)
                    
                    #if DEBUG
                    let afterLength = textFile.versions?[textFile.currentVersionIndex].attributedContent?.length ?? 0
                    if beforeLength != afterLength {
                        print("  ✅ \(textFile.name): \(beforeLength) → \(afterLength) chars")
                        totalRemoved += (beforeLength - afterLength)
                    }
                    #endif
                }
            }
            
            // Recurse into subfolders
            if let subfolders = folder.folders {
                for subfolder in subfolders {
                    scanFolderForFiles(subfolder)
                }
            }
        }
        
        // Start scanning from project folders
        if let folders = project.folders {
            for folder in folders {
                scanFolderForFiles(folder)
            }
        }
        
        #if DEBUG
        print("🔍 Removal complete: \(totalRemoved) chars removed total")
        #endif
    }
    
    private func removeReferenceAttachmentsFromFile(_ textFile: TextFile, referenceType: ReferenceType) {
        #if DEBUG
        print("  📄 Scanning file: \(textFile.name)")
        #endif
        
        // Get the current version's content
        guard let versions = textFile.versions, versions.count > textFile.currentVersionIndex else {
            #if DEBUG
            print("  ⚠️ No versions found")
            #endif
            return
        }
        
        let currentVersion = versions[textFile.currentVersionIndex]
        guard let attributedText = currentVersion.attributedContent else {
            #if DEBUG
            print("  ⚠️ No content found")
            #endif
            return
        }
        
        #if DEBUG
        print("    📊 Content before: length=\(attributedText.length)")
        #endif
        
        let mutableText = NSMutableAttributedString(attributedString: attributedText)
        var removedCount = 0
        
        #if DEBUG
        // Debug: Check what attributes are actually in the string
        var foundAnyAttachments = false
        mutableText.enumerateAttributes(in: NSRange(location: 0, length: mutableText.length), options: []) { attrs, range, _ in
            if attrs[NSAttributedString.Key.attachment] != nil {
                foundAnyAttachments = true
            }
        }
        print("    🔍 Has any attachments: \(foundAnyAttachments)")
        #endif
        
        // Enumerate in reverse order to avoid index shifting issues
        var rangesToRemove: [(NSRange, ReferenceAttachment)] = []
        
        mutableText.enumerateAttribute(NSAttributedString.Key.attachment, in: NSRange(location: 0, length: mutableText.length), options: []) { attachment, range, _ in
            #if DEBUG
            print("    🔎 Attachment at \(range): \(type(of: attachment)) = \(String(describing: attachment))")
            #endif
            
            if let refAttachment = attachment as? ReferenceAttachment {
                #if DEBUG
                print("    ✅ Cast successful to ReferenceAttachment")
                #endif
                if refAttachment.referenceType == referenceType {
                    #if DEBUG
                    print("    🗑️ Found \(referenceType) reference: \(refAttachment.entryID) at range \(range)")
                    #endif
                    rangesToRemove.append((range, refAttachment))
                    removedCount += 1
                } else {
                    #if DEBUG
                    print("    ⏭️ Skipping \(refAttachment.referenceType) (not \(referenceType))")
                    #endif
                }
            } else {
                #if DEBUG
                if attachment != nil {
                    print("    ⚠️ Attachment exists but is \(type(of: attachment)), not ReferenceAttachment")
                } else {
                    print("    ℹ️ nil attachment at range \(range)")
                }
                #endif
            }
        }
        
        #if DEBUG
        print("    📝 Found \(removedCount) references to remove")
        #endif
        
        // Remove in reverse order
        for (_, (range, _)) in rangesToRemove.enumerated().reversed() {
            #if DEBUG
            print("    🗑️ Removing range: \(range)")
            #endif
            mutableText.deleteCharacters(in: range)
        }
        
        if removedCount > 0 {
            #if DEBUG
            print("    📊 Content after removal: length=\(mutableText.length)")
            print("    💾 Updating version.attributedContent...")
            #endif
            
            // Update the version's attributed content (which will encode to formattedContent)
            currentVersion.attributedContent = mutableText
            
            // Mark the file as modified so SwiftData tracks the change
            textFile.modifiedDate = Date()
            
            #if DEBUG
            print("    ✅ Removed \(removedCount) \(referenceType) references from \(textFile.name)")
            print("    📊 New content length: \(currentVersion.attributedContent?.length ?? 0)")
            #endif
        } else {
            #if DEBUG
            print("    ℹ️ No \(referenceType) references found in \(textFile.name)")
            #endif
        }
    }
    
    /// Handle tap on a reference attachment (shows popover or detail view)
    private func handleReferenceTapped(_ attachment: ReferenceAttachment, at position: Int) {
        #if DEBUG
        print("📝 Reference tapped: \(attachment.referenceType) at position \(position)")
        #endif
        
        guard let project = file.project else {
            #if DEBUG
            print("⚠️ No project found")
            #endif
            return
        }
        
        switch attachment.referenceType {
        case .note, .endnote:
            // Find the corresponding note entry
            if let notes = project.noteEntries,
               let note = notes.first(where: { $0.id == attachment.entryID }) {
                selectedNoteForDetail = note
            } else {
                #if DEBUG
                print("⚠️ Note entry not found for ID: \(attachment.entryID)")
                #endif
            }
            
        case .glossary:
            // Find the corresponding glossary entry
            if let terms = project.glossaryEntries,
               let term = terms.first(where: { $0.id == attachment.entryID }) {
                selectedGlossaryTerm = term
            } else {
                #if DEBUG
                print("⚠️ Glossary term not found for ID: \(attachment.entryID)")
                #endif
            }
            
        case .reference:
            // Find the corresponding reference entry
            if let references = project.referenceEntries,
               let reference = references.first(where: { $0.id == attachment.entryID }) {
                selectedReference = reference
            } else {
                #if DEBUG
                print("⚠️ Reference not found for ID: \(attachment.entryID)")
                #endif
            }
            
        case .index:
            // Index entries are invisible, but if somehow tapped, show the editor
            if let entries = project.indexEntries,
               let entry = entries.first(where: { $0.id == attachment.entryID }) {
                selectedIndexEntry = entry
            } else {
                #if DEBUG
                print("⚠️ Index entry not found for ID: \(attachment.entryID)")
                #endif
            }
            
        case .figure, .table:
            // Figure and table references - not implemented yet
            #if DEBUG
            print("ℹ️ Figure/Table reference tapped: \(attachment.referenceType)")
            #endif
        }
    }
    
    /// Handle deletion of mixed attachment types (references, comments, footnotes) from text
    /// Shows unified confirmation alert - deletion is permanent and not undoable
    private func handleMixedAttachmentsDeleted(
        _ references: [ReferenceAttachment],
        comments: [CommentAttachment],
        footnotes: [FootnoteAttachment],
        in deletionRange: NSRange
    ) {
        #if DEBUG
        print("🗑️🔀 handleMixedAttachmentsDeleted called")
        print("   References: \(references.count), Comments: \(comments.count), Footnotes: \(footnotes.count)")
        #endif
        
        guard let textView = textViewCoordinator.textView else { return }
        
        // Count total items for message
        let totalCount = references.count + comments.count + footnotes.count
        
        let message: String
        if totalCount > 1 {
            message = "Cutting or deleting these references copies the text when cutting, but the references and their back matter entries are removed permanently. This cannot be undone."
        } else {
            message = "Cutting or deleting this reference copies the text when cutting, but the reference and its back matter entry are removed permanently. This cannot be undone."
        }
        
        // Show confirmation alert
        let alert = UIAlertController(
            title: "Delete References?",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Don't Delete", style: .cancel) { _ in
            #if DEBUG
            print("🔙 Mixed deletion cancelled - no action taken")
            #endif
        })
        
        alert.addAction(UIAlertAction(title: "Delete References", style: .destructive) { _ in
            #if DEBUG
            print("✅ User confirmed mixed deletion - deleting all attachments")
            #endif
            
            // Set flag to bypass undo stack - deletion is not undoable
            self.isPerformingUndoRedo = true
            
            guard deletionRange.length > 0 else {
                #if DEBUG
                print("⚠️ Deletion range empty, nothing to remove")
                #endif
                return
            }
            
            // Safely clamp range to current text storage
            let maxLength = textView.textStorage.length
            let safeRange = NSIntersectionRange(deletionRange, NSRange(location: 0, length: maxLength))
            guard safeRange.length > 0 else {
                #if DEBUG
                print("⚠️ Safe deletion range is empty")
                #endif
                return
            }
            
            // Delete the text
            textView.textStorage.replaceCharacters(in: safeRange, with: "")
            textView.selectedRange = NSRange(location: safeRange.location, length: 0)
            self.attributedContent = textView.attributedText ?? NSAttributedString()
            
            // Delete references from database
            if !references.isEmpty {
                self.deleteReferenceFromDatabase(references, textView: textView)
            }
            
            // Delete comments from database
            for attachment in comments {
                if let commentsArray = self.file.currentVersion?.comments,
                   let comment = commentsArray.first(where: { $0.attachmentID == attachment.commentID }) {
                    self.modelContext.delete(comment)
                    #if DEBUG
                    print("💬 Deleted comment from database: \(attachment.commentID.uuidString.prefix(8))")
                    #endif
                }
            }
            
            // Move footnotes to trash
            for attachment in footnotes {
                let relationshipFootnote = self.file.currentVersion?.footnotes?.first {
                    $0.attachmentID == attachment.footnoteID
                }
                let fetchedFootnote = FootnoteManager.shared.getFootnoteByAttachment(
                    attachmentID: attachment.footnoteID,
                    context: self.modelContext
                )
                if let footnote = relationshipFootnote ?? fetchedFootnote {
                    FootnoteManager.shared.deleteFootnote(footnote, context: self.modelContext)
                    #if DEBUG
                    print("📝 Moved footnote to trash: \(attachment.footnoteID.uuidString.prefix(8))")
                    #endif
                }
            }
            self.reconcileFootnoteNumbers()
            
            // Update back matter
            self.updateBackMatterFiles()
            
            // Save changes
            self.saveChanges()
            
            // Reset flag after update completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.isPerformingUndoRedo = false
            }
        })
        
        // Present alert on the root view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            root.present(alert, animated: true)
        }
    }
    
    /// Handle deletion of a reference attachment from text (Feature 029)
    /// Shows confirmation alert - deletion is permanent and not undoable
    private func handleReferenceDeleted(_ attachments: [ReferenceAttachment], in deletionRange: NSRange) {
        #if DEBUG
        print("🗑️📌 handleReferenceDeleted called")
        for attachment in attachments {
            print("   Type: \(attachment.referenceType)")
            print("   EntryID: \(attachment.entryID.uuidString.prefix(8))")
            print("   DisplayText: \(attachment.displayText)")
        }
        #endif
        
        guard let textView = textViewCoordinator.textView else { return }
        
        let message: String
        if attachments.count > 1 {
            message = "Cutting or deleting these references copies the text when cutting, but the references and their back matter entries are removed permanently. This cannot be undone."
        } else {
            message = "Cutting or deleting this reference copies the text when cutting, but the reference and its back matter entry are removed permanently. This cannot be undone."
        }
        
        // Show confirmation alert
        let alert = UIAlertController(
            title: "Delete Reference?",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Don't Delete", style: .cancel) { _ in
            #if DEBUG
            print("🔙 Reference deletion cancelled - no action taken")
            #endif
        })
        
        alert.addAction(UIAlertAction(title: "Delete Reference", style: .destructive) { _ in
            #if DEBUG
            print("✅ User confirmed reference deletion - deleting text and updating database")
            #endif

            guard deletionRange.length > 0 else {
                #if DEBUG
                print("⚠️ Deletion range empty, nothing to remove")
                #endif
                return
            }
            
            // Safely clamp range to current text storage
            let maxLength = textView.textStorage.length
            let safeRange = NSIntersectionRange(deletionRange, NSRange(location: 0, length: maxLength))
            guard safeRange.length > 0 else {
                #if DEBUG
                print("⚠️ Safe deletion range is empty")
                #endif
                return
            }

            textView.textStorage.replaceCharacters(in: safeRange, with: "")
            textView.selectedRange = NSRange(location: safeRange.location, length: 0)
            attributedContent = textView.attributedText ?? NSAttributedString()

            // Delete the reference(s) from the database
            self.deleteReferenceFromDatabase(attachments, textView: textView)

            // Update back matter
            self.updateBackMatterFiles()
        })
        
        // Present alert on the root view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            root.present(alert, animated: true)
        }
    }
    
    /// Handle deletion of comment marker(s) from text
    /// Shows confirmation alert - deletion is permanent and not undoable
    private func handleCommentMarkerDeleted(_ attachments: [CommentAttachment], in deletionRange: NSRange) {
        #if DEBUG
        print("🗑️💬 handleCommentMarkerDeleted called")
        for attachment in attachments {
            print("   CommentID: \(attachment.commentID.uuidString.prefix(8))")
        }
        #endif
        
        guard let textView = textViewCoordinator.textView else { return }
        
        let title: String
        let message: String
        if attachments.count > 1 {
            title = String(format: NSLocalizedString("commentsList.confirmDeleteMultiple.title", comment: "Delete %d Comments?"), attachments.count)
            message = String(format: NSLocalizedString("commentsList.confirmDeleteMultiple.message", comment: "This will permanently delete %d comments and remove their markers from your text. This cannot be undone."), attachments.count)
        } else {
            title = NSLocalizedString("commentsList.confirmDelete.title", comment: "Delete Comment?")
            message = NSLocalizedString("commentsList.confirmDelete.message", comment: "This will permanently delete the comment and remove its marker from your text. This cannot be undone.")
        }
        
        // Show confirmation alert
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("button.cancel", comment: "Cancel"), style: .cancel) { _ in
            #if DEBUG
            print("🔙 Comment deletion cancelled - no action taken")
            #endif
        })
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("commentsList.confirmDelete.button", comment: "Delete"), style: .destructive) { _ in
            #if DEBUG
            print("✅ User confirmed comment deletion - deleting text and database entry")
            #endif
            
            // Set flag to bypass undo stack - comment deletion is not undoable
            self.isPerformingUndoRedo = true
            
            guard deletionRange.length > 0 else {
                #if DEBUG
                print("⚠️ Deletion range empty, nothing to remove")
                #endif
                return
            }
            
            // Safely clamp range to current text storage
            let maxLength = textView.textStorage.length
            let safeRange = NSIntersectionRange(deletionRange, NSRange(location: 0, length: maxLength))
            guard safeRange.length > 0 else {
                #if DEBUG
                print("⚠️ Safe deletion range is empty")
                #endif
                return
            }
            
            // Delete the text
            textView.textStorage.replaceCharacters(in: safeRange, with: "")
            textView.selectedRange = NSRange(location: safeRange.location, length: 0)
            self.attributedContent = textView.attributedText ?? NSAttributedString()
            
            // Delete the comment(s) from the database
            for attachment in attachments {
                if let comments = self.file.currentVersion?.comments,
                   let comment = comments.first(where: { $0.attachmentID == attachment.commentID }) {
                    self.modelContext.delete(comment)
                    #if DEBUG
                    print("💬 Deleted comment from database: \(attachment.commentID.uuidString.prefix(8))")
                    #endif
                }
            }
            
            // Save changes
            self.saveChanges()
            
            // Reset flag after update completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.isPerformingUndoRedo = false
            }
        })
        
        // Present alert on the root view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            root.present(alert, animated: true)
        }
    }
    
    /// Handle deletion of footnote marker(s) from text
    /// Shows confirmation alert - deletion is permanent and not undoable
    private func handleFootnoteMarkerDeleted(_ attachments: [FootnoteAttachment], in deletionRange: NSRange) {
        #if DEBUG
        print("🗑️📝 handleFootnoteMarkerDeleted called")
        print("🧪 [FootnoteDiag] handleFootnoteMarkerDeleted range=\(deletionRange) textView=\(footnoteDebugSummary(textViewCoordinator.textView?.attributedText)) binding=\(footnoteDebugSummary(attributedContent))")
        for attachment in attachments {
            print("   FootnoteID: \(attachment.footnoteID.uuidString.prefix(8))")
        }
        #endif
        
        guard let textView = textViewCoordinator.textView else { return }
        
        let title: String
        let message: String
        if attachments.count > 1 {
            title = String(format: NSLocalizedString("footnotesList.confirmDeleteMultiple.title", comment: "Delete %d Footnotes?"), attachments.count)
            message = String(format: NSLocalizedString("footnotesList.confirmDeleteMultiple.message", comment: "This will permanently delete %d footnotes and remove their markers from your text. This cannot be undone."), attachments.count)
        } else {
            title = NSLocalizedString("footnotesList.confirmDelete.title", comment: "Delete Footnote?")
            message = NSLocalizedString("footnotesList.confirmDelete.message", comment: "Deleting this footnote will move it to the trash. You can restore it from there if needed. This cannot be undone.")
        }
        
        // Show confirmation alert
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("button.cancel", comment: "Cancel"), style: .cancel) { _ in
            #if DEBUG
            print("🔙 Footnote deletion cancelled - no action taken")
            #endif
        })
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("footnotesList.confirmDelete.button", comment: "Delete"), style: .destructive) { _ in
            #if DEBUG
            print("✅ User confirmed footnote deletion - deleting text and moving to trash")
            print("🧪 [FootnoteDiag] confirmed footnote deletion BEFORE textView=\(self.footnoteDebugSummary(textView.attributedText))")
            #endif
            
            // Set flag to bypass undo stack - footnote deletion is not undoable
            self.isPerformingUndoRedo = true
            
            guard deletionRange.length > 0 else {
                #if DEBUG
                print("⚠️ Deletion range empty, nothing to remove")
                #endif
                return
            }
            
            // Safely clamp range to current text storage
            let maxLength = textView.textStorage.length
            let safeRange = NSIntersectionRange(deletionRange, NSRange(location: 0, length: maxLength))
            guard safeRange.length > 0 else {
                #if DEBUG
                print("⚠️ Safe deletion range is empty")
                #endif
                return
            }
            
            // Delete the text
            textView.textStorage.replaceCharacters(in: safeRange, with: "")
            textView.selectedRange = NSRange(location: safeRange.location, length: 0)
            self.attributedContent = textView.attributedText ?? NSAttributedString()
            #if DEBUG
            print("🧪 [FootnoteDiag] confirmed footnote deletion AFTER text removal textView=\(self.footnoteDebugSummary(textView.attributedText)) binding=\(self.footnoteDebugSummary(self.attributedContent))")
            #endif
            
            // Move the footnote(s) to trash using FootnoteManager (handles renumbering)
            for attachment in attachments {
                let relationshipFootnote = self.file.currentVersion?.footnotes?.first {
                    $0.attachmentID == attachment.footnoteID
                }
                let fetchedFootnote = FootnoteManager.shared.getFootnoteByAttachment(
                    attachmentID: attachment.footnoteID,
                    context: self.modelContext
                )
                if let footnote = relationshipFootnote ?? fetchedFootnote {
                    FootnoteManager.shared.deleteFootnote(footnote, context: self.modelContext)
                    #if DEBUG
                    print("📝 Moved footnote to trash: \(attachment.footnoteID.uuidString.prefix(8))")
                    #endif
                }
            }
            self.reconcileFootnoteNumbers()
            
            // Save changes
            self.saveChanges()
            #if DEBUG
            print("🧪 [FootnoteDiag] confirmed footnote deletion AFTER save textView=\(self.footnoteDebugSummary(textView.attributedText)) binding=\(self.footnoteDebugSummary(self.attributedContent))")
            #endif
            
            // Reset flag after update completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.isPerformingUndoRedo = false
            }
        })
        
        // Present alert on the root view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            root.present(alert, animated: true)
        }
    }
    
    /// Delete reference from database without undo
    private func deleteReferenceFromDatabase(_ attachments: [ReferenceAttachment], textView: UITextView) {
        guard !attachments.isEmpty else { return }
        #if DEBUG
        print("🗑️ Deleting \(attachments.count) reference(s) from database")
        #endif

        var groupedByEntry: [UUID: (type: ReferenceType, count: Int)] = [:]
        for attachment in attachments {
            if let entry = groupedByEntry[attachment.entryID] {
                groupedByEntry[attachment.entryID] = (type: entry.type, count: entry.count + 1)
            } else {
                groupedByEntry[attachment.entryID] = (type: attachment.referenceType, count: 1)
            }
        }

        for (entryID, entryInfo) in groupedByEntry {
            switch entryInfo.type {
            case .note, .endnote:
                if let noteEntry = try? modelContext.fetch(FetchDescriptor<NoteEntry>())
                    .first(where: { $0.id == entryID }) {
                    let newCount = max(0, noteEntry.referenceCount - entryInfo.count)
                    if newCount == 0 {
                        modelContext.delete(noteEntry)
                    } else {
                        noteEntry.referenceCount = newCount
                    }
                    #if DEBUG
                    print("📝 \(newCount == 0 ? "Deleted unreferenced note entry" : "Decremented note ref count to: \(newCount)")")
                    #endif
                }
            case .glossary:
                if let glossaryEntry = try? modelContext.fetch(FetchDescriptor<GlossaryEntry>())
                    .first(where: { $0.id == entryID }) {
                    let newCount = max(0, glossaryEntry.referenceCount - entryInfo.count)
                    if newCount == 0 {
                        modelContext.delete(glossaryEntry)
                    } else {
                        glossaryEntry.referenceCount = newCount
                    }
                    #if DEBUG
                    print("📕 \(newCount == 0 ? "Deleted unreferenced glossary entry" : "Decremented glossary ref count to: \(newCount)")")
                    #endif
                }
            case .reference:
                if let referenceEntry = try? modelContext.fetch(FetchDescriptor<ReferenceEntry>())
                    .first(where: { $0.id == entryID }) {
                    let newCount = max(0, referenceEntry.referenceCount - entryInfo.count)
                    if newCount == 0 {
                        modelContext.delete(referenceEntry)
                    } else {
                        referenceEntry.referenceCount = newCount
                    }
                    #if DEBUG
                    print("📗 \(newCount == 0 ? "Deleted unreferenced reference entry" : "Decremented reference ref count to: \(newCount)")")
                    #endif
                }
            case .index, .figure, .table:
                if let indexEntry = try? modelContext.fetch(FetchDescriptor<IndexEntry>())
                    .first(where: { $0.id == entryID }) {
                    let newCount = max(0, indexEntry.referenceCount - entryInfo.count)
                    if newCount == 0 {
                        modelContext.delete(indexEntry)
                    } else {
                        indexEntry.referenceCount = newCount
                    }
                    #if DEBUG
                    print("📙 \(newCount == 0 ? "Deleted unreferenced index entry" : "Decremented index ref count to: \(newCount)")")
                    #endif
                }
            }
        }

        if let currentVersion = file.versions?[file.currentVersionIndex] {
            let currentContent = textView.attributedText ?? NSAttributedString()
            currentVersion.attributedContent = currentContent
            let referenceMetadata = extractReferenceMetadata(from: currentContent)
            currentVersion.referenceMetadataData = referenceMetadata.encode()
        }

        WriteCoalescer.shared?.requestSave()
    }
    
    // MARK: - Glossary (Feature 029)
    
    /// Handle "Add to Glossary" from context menu with selected text
    private func handleGlossaryAddRequested(_ selectedText: String) {
        guard canAddGlossaryMarkers else { return }

        let trimmedText = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        guard let project = file.project else { return }
        
        // Check if this glossary term already exists (case-insensitive)
        if let existingTerm = project.glossaryEntries?.first(where: { 
            $0.term.lowercased() == trimmedText.lowercased() 
        }) {
            // Term exists - insert marker directly
            #if DEBUG
            print("📖 Glossary term '\(trimmedText)' already exists, inserting marker directly")
            #endif
            insertGlossaryMarker(for: existingTerm)
        } else {
            // Term is new - show editor with pre-filled term name
            #if DEBUG
            print("📖 New glossary term '\(trimmedText)' - showing editor")
            #endif
            glossaryTermFromContextMenu = trimmedText
            showNewGlossaryTermDialog = true
        }
    }

    /// Show the glossary term dialog, pre-filling with selected text if any.
    /// If the selected term already exists, insert a marker directly.
    private func showGlossaryTermDialogWithSelectedText() {
        guard canAddGlossaryMarkers else { return }

        if let textView = textViewCoordinator.textView {
            let selectedRange = textView.selectedRange
            if selectedRange.length > 0,
               let selectedText = textView.textStorage.attributedSubstring(from: selectedRange).string
                .trimmingCharacters(in: .whitespacesAndNewlines) as String?,
               !selectedText.isEmpty {
                handleGlossaryAddRequested(selectedText)
                return
            }
        }

        glossaryTermFromContextMenu = nil
        showNewGlossaryTermDialog = true
    }
    
    /// Insert a glossary term marker at the current cursor position
    private func insertGlossaryMarker(for term: GlossaryEntry) {
        guard let textView = textViewCoordinator.textView else {
            #if DEBUG
            print("❌ Cannot insert glossary marker: no text view")
            #endif
            return
        }
        
        #if DEBUG
        print("📖 Inserting glossary marker for term: \(term.term)")
        #endif
        
        // Get current cursor position
        let currentRange = textView.selectedRange
        
        // Create the reference attachment using the convenience init for glossary
        let attachment = ReferenceAttachment(
            glossaryEntryID: term.id,
            term: term.term
        )
        
        // Create attributed string with the attachment
        let attachmentString = referenceAttachmentString(attachment, in: textView, at: currentRange.location)
        
        // Insert at cursor
        isPerformingUndoRedo = true
        textView.textStorage.insert(attachmentString, at: currentRange.location)
        
        // Move cursor after the marker
        let newLocation = currentRange.location + attachmentString.length
        textView.selectedRange = NSRange(location: newLocation, length: 0)
        
        // Increment reference count
        term.referenceCount += 1
        
        // Update the attributed content binding
        attributedContent = textView.attributedText ?? NSAttributedString()
        
        // Save changes
        saveChanges()
        
        // Regenerate back matter files to show the glossary entry
        if let project = file.project {
            regenerateBackMatterFilesForGlossary(project)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.isPerformingUndoRedo = false
        }
        
        #if DEBUG
        print("✅ Glossary marker inserted at position \(currentRange.location)")
        #endif
    }
    
    /// Remove all markers for a deleted glossary term from the text
    private func removeGlossaryMarkers(for term: GlossaryEntry) {
        #if DEBUG
        print("🗑️ Removing markers for glossary term: \(term.term)")
        #endif
        
        isPerformingUndoRedo = true

        let result = removeReferenceMarkersFromStoredContent(entryID: term.id, referenceType: .glossary)
        let removedCount = result.removedCount
        
        if removedCount > 0 {
            persistReferenceMarkerRemoval(result.content)
            
            // Regenerate back matter files to update the glossary
            if let project = file.project {
                regenerateBackMatterFilesForGlossary(project)
            }
            
            #if DEBUG
            print("✅ Removed \(removedCount) markers for glossary term: \(term.term)")
            #endif
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.isPerformingUndoRedo = false
        }
    }
    
    /// Jump to the first reference marker for a glossary term in the text
    private func jumpToGlossaryMarker(_ term: GlossaryEntry) {
        guard let textView = textViewCoordinator.textView else {
            #if DEBUG
            print("❌ Cannot jump to glossary marker: no text view")
            #endif
            return
        }
        
        let content = textView.attributedText ?? NSAttributedString()
        
        // Find the first marker for this term
        var foundRange: NSRange?
        content.enumerateAttribute(.attachment, in: NSRange(location: 0, length: content.length)) { value, range, stop in
            if let attachment = value as? ReferenceAttachment,
               attachment.referenceType == .glossary,
               attachment.entryID == term.id {
                foundRange = range
                stop.pointee = true
            }
        }
        
        if let range = foundRange {
            // Scroll to and select the marker
            textView.selectedRange = range
            textView.scrollRangeToVisible(range)
            
            #if DEBUG
            print("📍 Jumped to glossary marker at position \(range.location)")
            #endif
        } else {
            #if DEBUG
            print("⚠️ No marker found for glossary term: \(term.term)")
            #endif
        }
    }
    
    // MARK: - Citations (Feature 029)
    
    /// Insert a citation marker at the current cursor position
    private func insertCitationMarker(for reference: ReferenceEntry) {
        guard let textView = textViewCoordinator.textView else {
            #if DEBUG
            print("❌ Cannot insert reference marker: no text view")
            #endif
            return
        }
        
        #if DEBUG
        print("📚 Inserting reference marker for: \(reference.author) (\(reference.publicationDate))")
        #endif
        
        // Get current cursor position
        let currentRange = textView.selectedRange
        
        // Create the reference attachment using the convenience init for references
        let attachment = ReferenceAttachment(
            referenceEntryID: reference.id,
            author: reference.author,
            date: reference.publicationDate
        )
        
        // Create attributed string with the attachment
        let attachmentString = referenceAttachmentString(attachment, in: textView, at: currentRange.location)
        
        // Insert at cursor
        isPerformingUndoRedo = true
        textView.textStorage.insert(attachmentString, at: currentRange.location)
        
        // Move cursor after the marker
        let newLocation = currentRange.location + attachmentString.length
        textView.selectedRange = NSRange(location: newLocation, length: 0)
        
        // Increment reference count
        reference.referenceCount += 1
        
        // Update the attributed content binding
        attributedContent = textView.attributedText ?? NSAttributedString()
        
        // Save changes
        saveChanges()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.isPerformingUndoRedo = false
        }
        
        #if DEBUG
        print("✅ Citation marker inserted at position \(currentRange.location)")
        #endif
    }
    
    /// Remove all markers for a deleted citation from the text
    private func removeCitationMarkers(for citation: CitationEntry) {
        guard let textView = textViewCoordinator.textView else {
            #if DEBUG
            print("❌ Cannot remove citation markers: no text view")
            #endif
            return
        }
        
        #if DEBUG
        print("🗑️ Removing markers for citation: \(citation.authors.first ?? "Unknown") (\(citation.year.map { String($0) } ?? "n.d."))")
        #endif
        
        isPerformingUndoRedo = true
        
        let mutableContent = NSMutableAttributedString(attributedString: textView.attributedText ?? NSAttributedString())
        var removedCount = 0
        
        // Find and remove all reference attachments for this citation
        var rangesToRemove: [NSRange] = []
        
        mutableContent.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutableContent.length)) { value, range, _ in
            if let attachment = value as? ReferenceAttachment,
               attachment.referenceType == .reference,
               attachment.entryID == citation.id {
                rangesToRemove.append(range)
            }
        }
        
        // Remove in reverse order
        for range in rangesToRemove.reversed() {
            mutableContent.deleteCharacters(in: range)
            removedCount += 1
        }
        
        if removedCount > 0 {
            textView.attributedText = mutableContent
            attributedContent = mutableContent
            saveChanges()
            
            #if DEBUG
            print("✅ Removed \(removedCount) markers for citation: \(citation.authors.first ?? "Unknown")")
            #endif
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.isPerformingUndoRedo = false
        }
    }
    
    /// Jump to the first reference marker for a citation in the text
    private func jumpToCitationMarker(_ citation: CitationEntry) {
        guard let textView = textViewCoordinator.textView else {
            #if DEBUG
            print("❌ Cannot jump to citation marker: no text view")
            #endif
            return
        }
        
        let content = textView.attributedText ?? NSAttributedString()
        
        // Find the first marker for this citation
        var foundRange: NSRange?
        content.enumerateAttribute(.attachment, in: NSRange(location: 0, length: content.length)) { value, range, stop in
            if let attachment = value as? ReferenceAttachment,
               attachment.referenceType == .reference,
               attachment.entryID == citation.id {
                foundRange = range
                stop.pointee = true
            }
        }
        
        if let range = foundRange {
            // Scroll to and select the marker
            textView.selectedRange = range
            textView.scrollRangeToVisible(range)
            
            #if DEBUG
            print("📍 Jumped to citation marker at position \(range.location)")
            #endif
        } else {
            #if DEBUG
            print("⚠️ No marker found for citation: \(citation.authors.first ?? "Unknown")")
            #endif
        }
    }
    
    // MARK: - Index (Feature 029)
    
    /// Show the index entry dialog, pre-filling with selected text if any
    private func showIndexEntryDialogWithSelectedText() {
        guard canAddIndexMarkers else { return }

        #if DEBUG
        print("📑 showIndexEntryDialogWithSelectedText called")
        #endif
        
        // Capture any selected text to use as the keyword
        if let textView = textViewCoordinator.textView {
            let selectedRange = textView.selectedRange
            #if DEBUG
            print("📑 selectedRange: location=\(selectedRange.location), length=\(selectedRange.length)")
            #endif
            
            if selectedRange.length > 0,
               let selectedText = textView.textStorage.attributedSubstring(from: selectedRange).string.trimmingCharacters(in: .whitespacesAndNewlines) as String?,
               !selectedText.isEmpty {
                #if DEBUG
                print("📑 Selected text: '\(selectedText)'")
                #endif
                // Use the context menu handler which handles existing entry detection
                handleIndexAddRequested(selectedText)
                return
            }
        }
        // No selection - just show the dialog with no pre-filled keyword
        #if DEBUG
        print("📑 No selection, showing empty dialog")
        #endif
        if let project = file.project {
            newIndexEntryData = NewIndexEntryData(project: project, prefilledKeyword: nil)
        }
    }
    
    /// Handle "Add to Index" from context menu with selected text (Feature 033)
    private func handleIndexAddRequested(_ selectedText: String) {
        guard canAddIndexMarkers else { return }

        let trimmedText = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        guard let project = file.project else { return }
        
        // Check if this index entry already exists (case-insensitive).
        // Use a direct fetch fallback to avoid stale relationship reads.
        if let existingEntry = findExistingIndexEntry(keyword: trimmedText, project: project) {
            // Entry exists - insert marker directly
            #if DEBUG
            print("📑 Index entry '\(trimmedText)' already exists, inserting marker directly")
            #endif
            insertIndexMarker(for: existingEntry)
            
            // Track the file reference
            existingEntry.addReferencingFile(file.id)
        } else {
            // Entry is new - show editor with pre-filled keyword
            #if DEBUG
            print("📑 New index entry '\(trimmedText)' - showing editor with prefilledKeyword='\(trimmedText)'")
            #endif
            newIndexEntryData = NewIndexEntryData(project: project, prefilledKeyword: trimmedText)
        }
    }

    /// Find an existing index entry for keyword using relationship data first,
    /// then a direct store fetch as a fallback.
    private func findExistingIndexEntry(keyword: String, project: Project) -> IndexEntry? {
        let normalized = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }

        if let relationshipMatch = project.indexEntries?.first(where: {
            $0.keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }) {
            return relationshipMatch
        }

        let projectID = project.id
        let descriptor = FetchDescriptor<IndexEntry>(
            predicate: #Predicate<IndexEntry> { entry in
                entry.project?.id == projectID
            }
        )

        if let entries = try? modelContext.fetch(descriptor) {
            return entries.first(where: {
                $0.keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
            })
        }

        return nil
    }
    
    /// Insert an index marker at the current cursor position
    /// Note: Index markers are invisible in the editor
    /// - Parameters:
    ///   - entry: The index entry to create a marker for
    ///   - isPrimary: Whether this is a primary reference (displayed bold in generated index)
    private func insertIndexMarker(for entry: IndexEntry, isPrimary: Bool = false) {
        guard let textView = textViewCoordinator.textView else {
            #if DEBUG
            print("❌ Cannot insert index marker: no text view")
            #endif
            return
        }
        
        #if DEBUG
        print("📑 Inserting index marker for: \(entry.keyword) (primary: \(isPrimary))")
        #endif
        
        // Get current cursor position
        let currentRange = textView.selectedRange
        
        // Create the reference attachment using the convenience init for index
        let attachment = ReferenceAttachment(
            indexEntryID: entry.id,
            isPrimary: isPrimary
        )
        
        // Create attributed string with the attachment
        let attachmentString = referenceAttachmentString(attachment, in: textView, at: currentRange.location)
        
        // Suppress autocomplete/OTP suggestions during insertion
        // This prevents the "Refusing to display OTP completion list relative to null rect" flash
        // We need to temporarily resign first responder to fully clear the input system state
        let wasFirstResponder = textView.isFirstResponder
        if wasFirstResponder {
            textView.resignFirstResponder()
        }
        
        // Use beginEditing/endEditing to batch the change
        textView.textStorage.beginEditing()
        
        // Insert at cursor
        isPerformingUndoRedo = true
        textView.textStorage.insert(attachmentString, at: currentRange.location)
        
        textView.textStorage.endEditing()
        
        // Move cursor after the marker
        let newLocation = currentRange.location + attachmentString.length
        textView.selectedRange = NSRange(location: newLocation, length: 0)
        
        // Increment reference count
        entry.referenceCount += 1
        
        // Track file reference
        entry.addReferencingFile(file.id)
        
        // Update the attributed content binding
        attributedContent = textView.attributedText ?? NSAttributedString()
        
        // Save changes
        saveChanges()
        
        // Restore first responder after a brief delay to let the input system settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if wasFirstResponder {
                textView.becomeFirstResponder()
            }
            self.isPerformingUndoRedo = false
        }
        
        #if DEBUG
        print("✅ Index marker inserted at position \(currentRange.location)")
        #endif
    }
    
    /// Remove all markers for a deleted index entry from the text
    private func removeIndexMarkers(for entry: IndexEntry) {
        #if DEBUG
        print("🗑️ Removing markers for index entry: \(entry.keyword)")
        #endif
        
        isPerformingUndoRedo = true

        let result = removeReferenceMarkersFromStoredContent(entryID: entry.id, referenceType: .index)
        let removedCount = result.removedCount
        
        if removedCount > 0 {
            persistReferenceMarkerRemoval(result.content)
            
            #if DEBUG
            print("✅ Removed \(removedCount) markers for index entry: \(entry.keyword)")
            #endif
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.isPerformingUndoRedo = false
        }
    }
    
    /// Jump to the first reference marker for an index entry in the text
    private func jumpToIndexMarker(_ entry: IndexEntry) {
        guard let textView = textViewCoordinator.textView else {
            #if DEBUG
            print("❌ Cannot jump to index marker: no text view")
            #endif
            return
        }
        
        let content = textView.attributedText ?? NSAttributedString()
        
        // Find the first marker for this entry
        var foundRange: NSRange?
        content.enumerateAttribute(.attachment, in: NSRange(location: 0, length: content.length)) { value, range, stop in
            if let attachment = value as? ReferenceAttachment,
               attachment.referenceType == .index,
               attachment.entryID == entry.id {
                foundRange = range
                stop.pointee = true
            }
        }
        
        if let range = foundRange {
            // Scroll to and select the marker (even though invisible, cursor will be there)
            textView.selectedRange = range
            textView.scrollRangeToVisible(range)
            
            #if DEBUG
            print("📍 Jumped to index marker at position \(range.location)")
            #endif
        } else {
            #if DEBUG
            print("⚠️ No marker found for index entry: \(entry.keyword)")
            #endif
        }
    }
    
    // MARK: - Reference Methods (Feature 029: References)
    
    /// Insert a reference marker at the current cursor position
    private func insertReferenceMarker(for reference: ReferenceEntry) {
        guard let textView = textViewCoordinator.textView else {
            #if DEBUG
            print("❌ Cannot insert reference marker: no text view")
            #endif
            return
        }
        
        #if DEBUG
        print("📚 Inserting reference marker for: \(reference.author), \(reference.publicationDate)")
        #endif
        
        // Get current cursor position
        let currentRange = textView.selectedRange
        
        // Create the reference attachment using the convenience init for references
        let attachment = ReferenceAttachment(
            referenceEntryID: reference.id,
            author: reference.author,
            date: reference.publicationDate
        )
        
        // Create attributed string with the attachment
        let attachmentString = referenceAttachmentString(attachment, in: textView, at: currentRange.location)
        
        // Insert at cursor
        isPerformingUndoRedo = true
        textView.textStorage.insert(attachmentString, at: currentRange.location)
        
        // Move cursor after the marker
        let newLocation = currentRange.location + attachmentString.length
        textView.selectedRange = NSRange(location: newLocation, length: 0)
        
        // Increment reference count
        reference.referenceCount += 1
        
        // Update the attributed content binding
        attributedContent = textView.attributedText ?? NSAttributedString()
        
        // Save changes
        saveChanges()
        
        // Regenerate back matter files to show the reference in the References section
        if let project = file.project {
            regenerateBackMatterFilesForReferences(project)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.isPerformingUndoRedo = false
        }
        
        #if DEBUG
        print("✅ Reference marker inserted at position \(currentRange.location)")
        #endif
    }
    
    /// Remove all markers for a deleted reference from the text
    private func removeReferenceMarkers(for reference: ReferenceEntry) {
        #if DEBUG
        print("🗑️ Removing markers for reference: \(reference.author), \(reference.publicationDate)")
        #endif
        
        isPerformingUndoRedo = true

        let result = removeReferenceMarkersFromStoredContent(entryID: reference.id, referenceType: .reference)
        let removedCount = result.removedCount
        
        if removedCount > 0 {
            persistReferenceMarkerRemoval(result.content)
            
            #if DEBUG
            print("✅ Removed \(removedCount) markers for reference: \(reference.author)")
            #endif
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.isPerformingUndoRedo = false
        }
    }
    
    /// Jump to the first reference marker for a reference in the text
    private func jumpToReferenceMarker(_ reference: ReferenceEntry) {
        guard let textView = textViewCoordinator.textView else {
            #if DEBUG
            print("❌ Cannot jump to reference marker: no text view")
            #endif
            return
        }
        
        let content = textView.attributedText ?? NSAttributedString()
        
        // Find the first marker for this reference
        var foundRange: NSRange?
        content.enumerateAttribute(.attachment, in: NSRange(location: 0, length: content.length)) { value, range, stop in
            if let attachment = value as? ReferenceAttachment,
               attachment.referenceType == .reference,
               attachment.entryID == reference.id {
                foundRange = range
                stop.pointee = true
            }
        }
        
        if let range = foundRange {
            // Scroll to and select the marker
            textView.selectedRange = range
            textView.scrollRangeToVisible(range)
            
            #if DEBUG
            print("📍 Jumped to reference marker at position \(range.location)")
            #endif
        } else {
            #if DEBUG
            print("⚠️ No marker found for reference: \(reference.author)")
            #endif
        }
    }
    
    /// Regenerate back matter files after reference count changes
    private func regenerateBackMatterFilesForReferences(_ project: Project) {
        // Find the Back Matter folder using project helper
        guard let backMatterFolder = project.findBackMatterFolder() else {
            return
        }
        
        let backMatterGenerator = BackMatterGenerator(context: modelContext, project: project)
        
        // Only regenerate the References section
        guard backMatterFolder.backMatterSettings.isEnabled(.references) else { return }
        
        // Find or create the References back matter file
        let folderID = backMatterFolder.id
        let fileName = BackMatterItem.references.fileName
        let descriptor = FetchDescriptor<TextFile>(
            predicate: #Predicate<TextFile> { file in
                file.parentFolder?.id == folderID && file.name == fileName
            }
        )
        
        if let backMatterFile = try? modelContext.fetch(descriptor).first {
            // Generate new content
            let generatedContent = backMatterGenerator.generateReferencesSection() ?? NSAttributedString()
            
            // Update or create current version
            if backMatterFile.currentVersion == nil {
                let newVersion = Version(versionNumber: 1)
                newVersion.textFile = backMatterFile
                newVersion.attributedContent = generatedContent
                modelContext.insert(newVersion)
                backMatterFile.currentVersionIndex = 0
            } else {
                backMatterFile.currentVersion?.attributedContent = generatedContent
            }
            
            WriteCoalescer.shared?.requestSave()
        }
    }
    
    /// Regenerate back matter files after glossary entry count changes
    private func regenerateBackMatterFilesForGlossary(_ project: Project) {
        // Find the Back Matter folder using project helper
        guard let backMatterFolder = project.findBackMatterFolder() else {
            return
        }
        
        let backMatterGenerator = BackMatterGenerator(context: modelContext, project: project)
        
        // Only regenerate the Glossary section
        guard backMatterFolder.backMatterSettings.isEnabled(.glossary) else { return }
        
        // Find or create the Glossary back matter file
        let folderID = backMatterFolder.id
        let fileName = BackMatterItem.glossary.fileName
        let descriptor = FetchDescriptor<TextFile>(
            predicate: #Predicate<TextFile> { file in
                file.parentFolder?.id == folderID && file.name == fileName
            }
        )
        
        if let backMatterFile = try? modelContext.fetch(descriptor).first {
            // Generate new content
            let generatedContent = backMatterGenerator.generateGlossarySection() ?? NSAttributedString()
            
            // Update or create current version
            if backMatterFile.currentVersion == nil {
                let newVersion = Version(versionNumber: 1)
                newVersion.textFile = backMatterFile
                newVersion.attributedContent = generatedContent
                modelContext.insert(newVersion)
                backMatterFile.currentVersionIndex = 0
            } else {
                backMatterFile.currentVersion?.attributedContent = generatedContent
            }
            
            WriteCoalescer.shared?.requestSave()
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
        WriteCoalescer.shared?.requestSave()
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
        guard let textView = textViewCoordinator.textView else {
            #if DEBUG
            print("❌ Cannot remove comment marker: no text view")
            #endif
            return
        }

        // Set flag to bypass undo stack - comment deletion is not undoable (consistent with notes/glossary/footnotes)
        isPerformingUndoRedo = true

        // Remove the comment marker from the live text view so saveChanges() does not persist the stale marker back.
        let updatedContent = CommentInsertionHelper.removeComment(
            from: textView.attributedText ?? attributedContent,
            commentID: comment.attachmentID
        )

        textView.attributedText = updatedContent
        file.currentVersion?.attributedContent = updatedContent
        previousContent = updatedContent.string
        file.modifiedDate = Date()
        WriteCoalescer.shared?.requestSave()
        attributedContent = updatedContent

        #if DEBUG
        print("💬 Comment marker removed: \(comment.attachmentID)")
        #endif
        
        // Reset flag after update completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.isPerformingUndoRedo = false
        }
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
        
        WriteCoalescer.shared?.requestSave()
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
        
        let allComments = CommentManager.shared
            .getComments(forVersion: currentVersion, context: modelContext)
            .filter { !$0.isDeleted }
        
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
    
    /// Reconcile footnote attachment numbers and marker style in the text with the authoritative
    /// database models and the project's stylesheet.
    /// Does not delete models; explicit marker deletion is the only destructive path.
    private func reconcileFootnoteNumbers() {
        guard let currentVersion = file.currentVersion else { return }
        
        let markerStyle = file.project?.styleSheet?.footnoteMarkerStyle ?? .numeric

        let sourceContent = textViewCoordinator.textView?.attributedText ?? attributedContent
        let mutableContent = NSMutableAttributedString(attributedString: sourceContent)
        let needsUpdate = FootnoteInsertionHelper.syncFootnotesWithMarkers(
            in: mutableContent,
            forVersion: currentVersion,
            context: modelContext,
            markerStyle: markerStyle,
            deleteMissingModels: false
        )
        
        if needsUpdate {
            attributedContent = mutableContent
            
            // CRITICAL: Push directly to the text view. FormattedTextEditor.updateUIView
            // only propagates when the plain text string changes. Replacing an attachment
            // at an existing U+FFFC position doesn't change the string, so the text view
            // would keep displaying the old marker image. Without this, saveChanges()
            // reads stale marker styles from the text view and persists them.
            textViewCoordinator.modifyTypingAttributes { textView in
                let savedSelection = textView.selectedRange
                textView.textStorage.setAttributedString(mutableContent)
                if savedSelection.location <= textView.textStorage.length {
                    textView.selectedRange = savedSelection
                }
            }
            
            #if DEBUG
            print("📝🔢 Reconciled footnote numbers/marker style on load")
            #endif
        }
    }
    
    // MARK: - Undo/Redo
    
    private func performUndo() {
        #if DEBUG
        print("🔄 performUndo called - canUndo: \(undoManager.canUndo)")
        #endif
        textViewCoordinator.flushPendingTyping?()
        guard undoManager.canUndo else { return }

        commitPendingEditorSave(reason: "file-editor-undo-flush")
        
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
        
        // Check entitlement for printing
        if let projectType = file.project?.type,
           !EntitlementManager.shared.canPrint(projectType: projectType) {
            upgradePromptReason = .printBlocked(projectType: projectType)
            return
        }
        
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
    
    // MARK: - Tab Insertion
    
    /// Insert a tab character at the current cursor position, or increase indent if in a list
    private func insertTab() {
        #if DEBUG
        print("⌨️ insertTab() called")
        #endif
        
        // Check if we're in a list paragraph - if so, increase indent instead of inserting tab
        let paragraphRange = (attributedContent.string as NSString).paragraphRange(for: selectedRange)
        
        #if DEBUG
        print("⌨️ insertTab - paragraphRange: \(paragraphRange), selectedRange: \(selectedRange)")
        #endif
        
        var currentStyleName: String?
        if paragraphRange.length > 0 {
            attributedContent.enumerateAttribute(.textStyle, in: paragraphRange, options: []) { value, _, stop in
                if let styleName = value as? String {
                    currentStyleName = styleName
                    stop.pointee = true
                }
            }
        }
        
        // Also check typing attributes for empty paragraph case
        if currentStyleName == nil {
            if let typingStyle = textViewCoordinator.textView?.typingAttributes[.textStyle] as? String {
                currentStyleName = typingStyle
                #if DEBUG
                print("⌨️ insertTab - found style from typingAttributes: \(typingStyle)")
                #endif
            }
        }
        
        #if DEBUG
        print("⌨️ insertTab - currentStyleName: \(currentStyleName ?? "nil")")
        print("⌨️ insertTab - listIndentMap keys: \(Self.listIndentMap.keys)")
        #endif
        
        // If in a list style, increase indent instead of inserting tab
        if let styleName = currentStyleName, Self.listIndentMap[styleName] != nil {
            #if DEBUG
            print("⌨️ insertTab - calling increaseListIndent()")
            #endif
            increaseListIndent()
            return
        }
        
        #if DEBUG
        print("⌨️ insertTab - not in list, inserting tab character")
        #endif
        
        guard let textView = textViewCoordinator.textView else { return }
        
        // Insert tab character at current selection
        let tabString = "\t"
        
        // Use UITextView's built-in replace method which handles undo automatically
        if let selectedTextRange = textView.selectedTextRange {
            textView.replace(selectedTextRange, withText: tabString)
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

    /// Returns BIU state for the current selection/cursor so toolbar controls can reflect active formatting.
    private func currentFormattingState() -> (bold: Bool, italic: Bool, underline: Bool, strikethrough: Bool) {
        guard selectedRange.location != NSNotFound else {
            return (false, false, false, false)
        }

        if selectedRange.length == 0 {
            if let attrs = textViewCoordinator.textView?.typingAttributes {
                return formattingState(from: attrs)
            }

            guard attributedContent.length > 0,
                  selectedRange.location > 0,
                  selectedRange.location <= attributedContent.length else {
                return (false, false, false, false)
            }

            let fallbackRange = NSRange(location: selectedRange.location - 1, length: 1)
            return formattingState(in: fallbackRange)
        }

        guard selectedRange.location + selectedRange.length <= attributedContent.length else {
            return (false, false, false, false)
        }

        return formattingState(in: selectedRange)
    }

    private func formattingState(from attributes: [NSAttributedString.Key: Any]) -> (bold: Bool, italic: Bool, underline: Bool, strikethrough: Bool) {
        let fontTraits = (attributes[.font] as? UIFont).map(FontFaceResolver.traits)

        let underline = styleValueIsNonZero(attributes[.underlineStyle])
        let strikethrough = styleValueIsNonZero(attributes[.strikethroughStyle])
        return (fontTraits?.bold ?? false, fontTraits?.italic ?? false, underline, strikethrough)
    }

    private func formattingState(in range: NSRange) -> (bold: Bool, italic: Bool, underline: Bool, strikethrough: Bool) {
        guard range.length > 0 else {
            return (false, false, false, false)
        }

        var bold = false
        var italic = false
        var underline = false
        var strikethrough = false

        attributedContent.enumerateAttributes(in: range, options: []) { attrs, _, _ in
            if let font = attrs[.font] as? UIFont {
                let traits = FontFaceResolver.traits(of: font)
                if traits.bold { bold = true }
                if traits.italic { italic = true }
            }

            if styleValueIsNonZero(attrs[.underlineStyle]) {
                underline = true
            }

            if styleValueIsNonZero(attrs[.strikethroughStyle]) {
                strikethrough = true
            }
        }

        return (bold, italic, underline, strikethrough)
    }

    private func styleValueIsNonZero(_ value: Any?) -> Bool {
        if let intValue = value as? Int {
            return intValue != 0
        }
        if let numberValue = value as? NSNumber {
            return numberValue.intValue != 0
        }
        return false
    }
    
    /// Apply formatting to the current selection
    private func applyFormatting(_ formatType: FormatType) {
        #if DEBUG
        print("🎨 applyFormatting(\(formatType)) called")
        print("🎨 selectedRange: {\(selectedRange.location), \(selectedRange.length)}")
        #endif
        
        // Don't apply rich text formatting when displaying as markdown
        if isDisplayingAsMarkdown {
            #if DEBUG
            print("⚠️ Skipping rich text formatting - displaying as markdown")
            #endif
            return
        }
        
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
        
        // CRITICAL: Also update the UITextView directly since state binding is one-way
        if let textView = textViewCoordinator.textView {
            // Preserve selection range
            let currentSelection = textView.selectedRange
            textView.attributedText = newAttributedContent
            // Restore selection (if valid)
            if currentSelection.location + currentSelection.length <= newAttributedContent.length {
                textView.selectedRange = currentSelection
            }
        }
        
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

        // Keep change-tracking state aligned with formatted content
        previousContent = newAttributedContent.string
        previousAttributedContent = newAttributedContent

        file.modifiedDate = Date()

        // Persist formatting changes immediately.
        // On Catalyst, project/file close can happen before a debounce timer fires,
        // which drops BIU changes on reopen.
        cancelPendingEditorSave()
        file.currentVersion?.attributedContent = newAttributedContent
        WriteCoalescer.shared?.requestSave()
        
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
                let traits = FontFaceResolver.traits(of: currentFont)
                typingAttributes[.font] = FontFaceResolver.resolvedFont(
                    from: currentFont,
                    bold: !traits.bold,
                    italic: traits.italic
                )
                typingAttributes[.explicitBold] = !traits.bold
                
            case .italic:
                let traits = FontFaceResolver.traits(of: currentFont)
                typingAttributes[.font] = FontFaceResolver.resolvedFont(
                    from: currentFont,
                    bold: traits.bold,
                    italic: !traits.italic
                )
                typingAttributes[.explicitItalic] = !traits.italic
                
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
    
    /// Insert a new list at the current cursor position
    /// Creates an empty paragraph with the appropriate list style
    /// - Parameter numbered: If true, creates a numbered list; otherwise creates a bullet list
    private func insertList(numbered: Bool) {
        guard let project = file.project else {
            #if DEBUG
            print("⚠️ insertList: No project found for file")
            #endif
            return
        }
        
        let listStyleName = numbered ? "list-numbered" : "list-bullet"
        guard let listStyle = project.styleSheet?.style(named: listStyleName) else {
            #if DEBUG
            print("⚠️ insertList: Could not find style '\(listStyleName)'")
            if let styleSheet = project.styleSheet {
                let styleNames = styleSheet.textStyles?.map { "\($0.name) (\($0.styleCategory.rawValue))" } ?? []
                print("⚠️ insertList: Stylesheet '\(styleSheet.name)' has \(styleSheet.textStyles?.count ?? 0) styles: \(styleNames)")
                print("⚠️ insertList: hasListStyles = \(styleSheet.hasListStyles)")
            } else {
                print("⚠️ insertList: Project has no stylesheet assigned")
            }
            #endif
            return
        }
        
        #if DEBUG
        print("📝 insertList: Creating \(numbered ? "numbered" : "bullet") list")
        #endif
        
        // Get the style attributes for the list
        let styleAttributes = listStyle.generateAttributes()
        
        // Set typing attributes so new text will use the list style
        if let textView = textViewCoordinator.textView {
            // Build typing attributes from the style
            var typingAttrs = styleAttributes
            typingAttrs[.textStyle] = listStyleName
            
            textView.typingAttributes = typingAttrs
            
            // Trigger redraw so the list number/bullet appears immediately
            // Need both setNeedsDisplay and layoutManager invalidation for immediate update
            textView.setNeedsDisplay()
            textView.layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: max(1, textView.textStorage.length)))
            
            #if DEBUG
            print("📝 insertList: Set typing attributes for \(listStyleName)")
            #endif
            
            // If we're not at an empty paragraph, we may want to insert a newline first
            // Check if current paragraph is empty
            let paragraphRange = (attributedContent.string as NSString).paragraphRange(for: selectedRange)
            let paragraphText = (attributedContent.string as NSString).substring(with: paragraphRange)
            let trimmedParagraph = paragraphText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !trimmedParagraph.isEmpty && paragraphRange.length > 0 {
                // Current paragraph has content - insert newline first, then apply style
                let insertLocation = NSMaxRange(paragraphRange) - (paragraphText.hasSuffix("\n") ? 1 : 0)
                
                // Get current paragraph attributes for the newline
                let currentAttrs = attributedContent.attributes(at: max(0, insertLocation - 1), effectiveRange: nil)
                
                // Create attributed string: newline (with current style) + zero-width space (with list style)
                // The zero-width space anchors the new paragraph's style so the number/bullet appears immediately
                let mutableString = NSMutableAttributedString()
                mutableString.append(NSAttributedString(string: "\n", attributes: currentAttrs))
                mutableString.append(NSAttributedString(string: "\u{200B}", attributes: typingAttrs)) // Zero-width space with list style
                
                // Insert at end of current paragraph
                let mutableContent = NSMutableAttributedString(attributedString: attributedContent)
                mutableContent.insert(mutableString, at: insertLocation)
                
                attributedContent = mutableContent
                
                // Move cursor to after the zero-width space (so user types after it)
                let newCursorPosition = insertLocation + 2
                selectedRange = NSRange(location: newCursorPosition, length: 0)
                textView.selectedRange = selectedRange
                
                // Re-set typingAttributes AFTER cursor move to ensure Tab/Shift+Tab can detect list style
                textView.typingAttributes = typingAttrs
                
                // Force layout manager to redraw numbers
                textView.setNeedsDisplay()
                if let layoutManager = textView.layoutManager as? NumberingLayoutManager {
                    layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: textView.textStorage.length))
                }
                
                #if DEBUG
                print("📝 insertList: Inserted newline + zero-width space at position \(insertLocation)")
                #endif
            } else {
                // Empty paragraph - insert zero-width space with list style to anchor it
                // This makes the number/bullet appear immediately
                let mutableContent = NSMutableAttributedString(attributedString: attributedContent)
                
                if attributedContent.length == 0 {
                    // Completely empty document - insert zero-width space with list style
                    let zwsWithStyle = NSAttributedString(string: "\u{200B}", attributes: typingAttrs)
                    mutableContent.insert(zwsWithStyle, at: 0)
                    attributedContent = mutableContent
                    
                    // Move cursor after zero-width space
                    selectedRange = NSRange(location: 1, length: 0)
                    textView.selectedRange = selectedRange
                    
                    // Re-set typingAttributes AFTER cursor move
                    textView.typingAttributes = typingAttrs
                } else if paragraphRange.length > 0 {
                    // Paragraph exists but is empty (just whitespace) - add attributes and zero-width space
                    mutableContent.addAttributes(typingAttrs, range: paragraphRange)
                    
                    // Insert zero-width space at start of paragraph to anchor style
                    let zwsWithStyle = NSAttributedString(string: "\u{200B}", attributes: typingAttrs)
                    mutableContent.insert(zwsWithStyle, at: paragraphRange.location)
                    attributedContent = mutableContent
                    
                    // Move cursor after zero-width space
                    selectedRange = NSRange(location: paragraphRange.location + 1, length: 0)
                    textView.selectedRange = selectedRange
                    
                    // Re-set typingAttributes AFTER cursor move
                    textView.typingAttributes = typingAttrs
                }
                
                // Force layout manager to redraw numbers
                textView.setNeedsDisplay()
                if let layoutManager = textView.layoutManager as? NumberingLayoutManager {
                    layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: max(1, textView.textStorage.length)))
                }
            }
            
            // Make sure text view has focus
            textView.becomeFirstResponder()
        }
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
        
        // Apply the list style to the paragraph.
        // If the style was removed from the stylesheet, fall back to synthesized
        // list attributes so bullets/numbering continue to function.
        let styleAttributes: [NSAttributedString.Key: Any]
        if let listStyle = project.styleSheet?.style(named: listStyleName) {
            styleAttributes = listStyle.generateAttributes()
        } else {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            paragraphStyle.firstLineHeadIndent = 36
            paragraphStyle.headIndent = 36

            styleAttributes = [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraphStyle,
                .textStyle: listStyleName,
                .numberFormat: format.rawValue
            ]
        }
        
        // Store before state for undo
        let beforeContent = attributedContent
        
        // Apply the list style attributes to the paragraph
        let mutableContent = NSMutableAttributedString(attributedString: attributedContent)
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
    
    // MARK: - List Indent/Outdent
    
    /// Mapping of list styles to their indented versions
    private static let listIndentMap: [String: String] = [
        "list-bullet": "list-bullet-level-2",
        "list-bullet-level-2": "list-bullet-level-3",
        "list-numbered": "list-numbered-level-2",
        "list-numbered-level-2": "list-numbered-level-3"
    ]
    
    /// Mapping of list styles to their outdented versions
    private static let listOutdentMap: [String: String] = [
        "list-bullet-level-3": "list-bullet-level-2",
        "list-bullet-level-2": "list-bullet",
        "list-numbered-level-3": "list-numbered-level-2",
        "list-numbered-level-2": "list-numbered"
    ]
    
    /// Increase the indent level of the current paragraph (for nested lists)
    private func increaseListIndent() {
        guard let project = file.project else { return }
        
        #if DEBUG
        print("⌨️ increaseListIndent() called")
        #endif
        
        // Get the range of the current paragraph
        let paragraphRange = (attributedContent.string as NSString).paragraphRange(for: selectedRange)
        
        #if DEBUG
        print("⌨️ increaseListIndent - paragraphRange: \(paragraphRange)")
        #endif
        
        // Get the current style name
        var currentStyleName: String?
        if paragraphRange.length > 0 {
            attributedContent.enumerateAttribute(.textStyle, in: paragraphRange, options: []) { value, _, stop in
                if let styleName = value as? String {
                    currentStyleName = styleName
                    stop.pointee = true
                }
            }
        }
        
        // For empty paragraphs, check typing attributes
        if currentStyleName == nil {
            if let typingStyle = textViewCoordinator.textView?.typingAttributes[.textStyle] as? String {
                currentStyleName = typingStyle
                #if DEBUG
                print("⌨️ increaseListIndent - found style from typingAttributes: \(typingStyle)")
                #endif
            }
        }
        
        #if DEBUG
        print("⌨️ increaseListIndent - currentStyleName: \(currentStyleName ?? "nil")")
        #endif
        
        guard let styleName = currentStyleName,
              let nextStyleName = Self.listIndentMap[styleName],
              let nextStyle = project.styleSheet?.style(named: nextStyleName) else {
            #if DEBUG
            print("⌨️ increaseListIndent - cannot find next style, aborting")
            #endif
            // Not a list style or already at max indent level
            return
        }
        
        #if DEBUG
        print("⌨️ increaseListIndent - changing from \(styleName) to \(nextStyleName)")
        #endif
        
        // Store before state for undo
        let beforeContent = attributedContent
        
        let styleAttributes = nextStyle.generateAttributes()
        
        // For empty paragraphs at the end (after a trailing newline), we need to:
        // 1. Update the preceding newline character's style (so NumberingLayoutManager draws correct number)
        // 2. Update typing attributes (for future typed text)
        if paragraphRange.length == 0 {
            #if DEBUG
            print("⌨️ increaseListIndent - empty paragraph at position \(paragraphRange.location)")
            #endif
            
            // Check if there's a preceding newline we need to update
            if paragraphRange.location > 0, let textView = textViewCoordinator.textView {
                let newlinePosition = paragraphRange.location - 1
                let char = (attributedContent.string as NSString).character(at: newlinePosition)
                
                if char == 10 { // newline character
                    #if DEBUG
                    print("⌨️ increaseListIndent - updating newline at position \(newlinePosition)")
                    #endif
                    
                    // Use proper NSTextStorage editing to trigger layout recalculation
                    // This is the architectural way to update attributes and have caret reposition
                    textView.textStorage.beginEditing()
                    textView.textStorage.addAttributes(styleAttributes, range: NSRange(location: newlinePosition, length: 1))
                    textView.textStorage.endEditing()
                    
                    // Also update our binding
                    attributedContent = NSAttributedString(attributedString: textView.textStorage)
                    
                    // Force redraw so NumberingLayoutManager draws the new number
                    textView.setNeedsDisplay()
                }
            }
            
            // Also update typing attributes for any new text
            if let textView = textViewCoordinator.textView {
                for (key, value) in styleAttributes {
                    textView.typingAttributes[key] = value
                }
                #if DEBUG
                print("⌨️ increaseListIndent - set typingAttributes to \(nextStyleName)")
                #endif
            }

            // Keep style picker state in sync even when only typingAttributes changed.
            currentParagraphStyle = UIFont.TextStyle(rawValue: nextStyleName)
            return
        }
        
        // Apply the next level style to non-empty paragraphs using proper editing
        if let textView = textViewCoordinator.textView {
            textView.textStorage.beginEditing()
            textView.textStorage.addAttributes(styleAttributes, range: paragraphRange)
            textView.textStorage.endEditing()
            
            // Also update typing attributes so new characters get the correct style
            for (key, value) in styleAttributes {
                textView.typingAttributes[key] = value
            }
            #if DEBUG
            print("⌨️ increaseListIndent - set typingAttributes to \(nextStyleName) (non-empty paragraph)")
            #endif
            
            // Sync with our binding
            attributedContent = NSAttributedString(attributedString: textView.textStorage)
            
            // Create undo command
            let command = FormatApplyCommand(
                description: "Increase List Indent",
                range: selectedRange,
                beforeContent: beforeContent,
                afterContent: attributedContent,
                targetFile: file
            )
            undoManager.execute(command)

            // Reflect updated paragraph style in the picker immediately.
            currentParagraphStyle = UIFont.TextStyle(rawValue: nextStyleName)
        }
    }
    
    /// Decrease the indent level of the current paragraph (for nested lists)
    private func decreaseListIndent() {
        guard let project = file.project else { return }
        
        // Get the range of the current paragraph
        let paragraphRange = (attributedContent.string as NSString).paragraphRange(for: selectedRange)
        
        #if DEBUG
        print("⌨️ decreaseListIndent - paragraphRange: \(paragraphRange)")
        #endif
        
        // Get the current style name - check typingAttributes for empty paragraphs
        var currentStyleName: String?
        
        if paragraphRange.length == 0 {
            // Empty paragraph - check typingAttributes
            if let textView = textViewCoordinator.textView {
                currentStyleName = textView.typingAttributes[.textStyle] as? String
                #if DEBUG
                print("⌨️ decreaseListIndent - empty paragraph, typingAttributes style: \(currentStyleName ?? "nil")")
                #endif
            }
        } else {
            attributedContent.enumerateAttribute(.textStyle, in: paragraphRange, options: []) { value, _, stop in
                if let styleName = value as? String {
                    currentStyleName = styleName
                    stop.pointee = true
                }
            }
        }
        
        guard let styleName = currentStyleName else { return }
        
        #if DEBUG
        print("⌨️ decreaseListIndent - current style: \(styleName)")
        #endif
        
        // Check if we can outdent (style is in the outdent map)
        guard let prevStyleName = Self.listOutdentMap[styleName],
              let prevStyle = project.styleSheet?.style(named: prevStyleName) else {
            // If at base list level, convert back to body text
            if styleName == "list-bullet" || styleName == "list-numbered" {
                #if DEBUG
                print("⌨️ decreaseListIndent - at base level, converting to body text")
                #endif
                // Apply body style instead
                if let bodyStyle = project.styleSheet?.style(named: "UICTFontTextStyleBody"),
                   let textView = textViewCoordinator.textView {
                    let beforeContent = attributedContent
                    let styleAttributes = bodyStyle.generateAttributes()
                    
                    if paragraphRange.length == 0 {
                        // Empty paragraph - update preceding newline and typing attributes
                        if paragraphRange.location > 0 {
                            let newlinePosition = paragraphRange.location - 1
                            let char = (attributedContent.string as NSString).character(at: newlinePosition)
                            
                            if char == 10 {
                                textView.textStorage.beginEditing()
                                textView.textStorage.addAttributes(styleAttributes, range: NSRange(location: newlinePosition, length: 1))
                                textView.textStorage.endEditing()
                                
                                attributedContent = NSAttributedString(attributedString: textView.textStorage)
                                
                                // Force redraw
                                textView.setNeedsDisplay()
                            }
                        }
                        
                        // Update typing attributes
                        for (key, value) in styleAttributes {
                            textView.typingAttributes[key] = value
                        }

                        // Keep style picker state in sync for empty paragraph outdent.
                        currentParagraphStyle = .body
                    } else {
                        // Non-empty paragraph
                        textView.textStorage.beginEditing()
                        textView.textStorage.addAttributes(styleAttributes, range: paragraphRange)
                        textView.textStorage.endEditing()
                        
                        // Also update typing attributes so new characters get the correct style
                        for (key, value) in styleAttributes {
                            textView.typingAttributes[key] = value
                        }
                        
                        attributedContent = NSAttributedString(attributedString: textView.textStorage)
                        
                        let command = FormatApplyCommand(
                            description: "Exit List",
                            range: selectedRange,
                            beforeContent: beforeContent,
                            afterContent: attributedContent,
                            targetFile: file
                        )
                        undoManager.execute(command)

                        // Reflect exit-to-body in style picker.
                        currentParagraphStyle = .body
                    }
                }
            }
            return
        }
        
        #if DEBUG
        print("⌨️ decreaseListIndent - will apply style: \(prevStyleName)")
        #endif
        
        // Store before state for undo
        let beforeContent = attributedContent
        let styleAttributes = prevStyle.generateAttributes()
        
        guard let textView = textViewCoordinator.textView else { return }
        
        // Handle empty paragraphs (after trailing newline)
        if paragraphRange.length == 0 {
            #if DEBUG
            print("⌨️ decreaseListIndent - empty paragraph at position \(paragraphRange.location)")
            #endif
            
            // Update preceding newline character's style
            if paragraphRange.location > 0 {
                let newlinePosition = paragraphRange.location - 1
                let char = (attributedContent.string as NSString).character(at: newlinePosition)
                
                if char == 10 {
                    #if DEBUG
                    print("⌨️ decreaseListIndent - updating newline at position \(newlinePosition)")
                    #endif
                    
                    textView.textStorage.beginEditing()
                    textView.textStorage.addAttributes(styleAttributes, range: NSRange(location: newlinePosition, length: 1))
                    textView.textStorage.endEditing()
                    
                    attributedContent = NSAttributedString(attributedString: textView.textStorage)
                    
                    // Force redraw so NumberingLayoutManager draws the new number
                    textView.setNeedsDisplay()
                }
            }
            
            // Update typing attributes for future typed text
            for (key, value) in styleAttributes {
                textView.typingAttributes[key] = value
            }
            #if DEBUG
            print("⌨️ decreaseListIndent - set typingAttributes to \(prevStyleName)")
            #endif

            // Keep style picker state in sync even when only typingAttributes changed.
            currentParagraphStyle = UIFont.TextStyle(rawValue: prevStyleName)
            return
        }
        
        // Apply to non-empty paragraph using proper editing
        textView.textStorage.beginEditing()
        textView.textStorage.addAttributes(styleAttributes, range: paragraphRange)
        textView.textStorage.endEditing()
        
        // Also update typing attributes so new characters get the correct style
        for (key, value) in styleAttributes {
            textView.typingAttributes[key] = value
        }
        #if DEBUG
        print("⌨️ decreaseListIndent - set typingAttributes to \(prevStyleName) (non-empty paragraph)")
        #endif
        
        attributedContent = NSAttributedString(attributedString: textView.textStorage)
        
        // Create undo command
        let command = FormatApplyCommand(
            description: "Decrease List Indent",
            range: selectedRange,
            beforeContent: beforeContent,
            afterContent: attributedContent,
            targetFile: file
        )
        undoManager.execute(command)

        // Reflect updated paragraph style in the picker immediately.
        currentParagraphStyle = UIFont.TextStyle(rawValue: prevStyleName)
    }
    
    /// Update the current paragraph style state by checking the attributed content
    private func updateCurrentParagraphStyle(at range: NSRange? = nil) {
        let rangeToCheck = range ?? selectedRange
        let contentToCheck = textViewCoordinator.textView?.attributedText ?? attributedContent

        // Try model-based lookup if we have a project. An inconclusive result must
        // remain unset rather than falling through to generic Body inference.
        if let project = file.project {
            let styleName = TextFormatter.getCurrentStyleName(
               in: contentToCheck,
               at: rangeToCheck,
               project: project,
               context: modelContext
            )
            currentParagraphStyle = styleName.flatMap(UIFont.TextStyle.init(rawValue:))
            return
        }
        
        // Fallback to direct UIFont.TextStyle lookup
        if let style = TextFormatter.getCurrentStyle(in: contentToCheck, at: rangeToCheck) {
            currentParagraphStyle = style
            return
        }

        if let typingStyleName = textViewCoordinator.textView?.typingAttributes[.textStyle] as? String {
            currentParagraphStyle = UIFont.TextStyle(rawValue: typingStyleName)
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
    /// - Parameter registerUndo: Whether to register an undo command for the style changes (default true, false for initial load)
    @discardableResult
    private func reapplyAllStyles(registerUndo: Bool = true) -> Bool {
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
            return false
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
        
        let sourceContent = textViewCoordinator.textView.map {
            NSAttributedString(attributedString: $0.attributedText)
        } ?? attributedContent

        // If document is empty, nothing to reapply
        guard sourceContent.length > 0 else {
            #if DEBUG
            print("📝 Document is empty - nothing to reapply")
            #endif
            #if DEBUG
            print("🔄 ========== REAPPLY ALL STYLES END (EMPTY) ==========")
            #endif
            return true
        }
        
        let mutableText = NSMutableAttributedString(attributedString: sourceContent)
        var hasChanges = false
        var stylesFound = 0
        var hasUnresolvedStyles = false
        
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
                hasUnresolvedStyles = true
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
                hasUnresolvedStyles = true
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
            
            #if DEBUG
            print("✅ Applying new attributes to range {\(range.location), \(range.length)}")
            #endif
            mutableText.enumerateAttributes(in: range, options: []) { currentAttrs, subrange, _ in
                let merged = StyleReapplicationAttributeMerger.merge(
                    styleAttributes: newAttributes,
                    currentAttributes: currentAttrs
                )
                mutableText.setAttributes(merged, range: subrange)
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

        if hasChanges && mutableText.isEqual(to: sourceContent) {
            hasChanges = false
            #if DEBUG
            print("📝 Reapplied style output matches existing content - skipping open-time rewrite")
            #endif
        }
        
        // Update document if any changes were made
        if hasChanges {
            let beforeContent = sourceContent
            attributedContent = mutableText
            cancelPendingEditorSave()
            file.currentVersion?.attributedContent = mutableText
            previousAttributedContent = mutableText
            file.modifiedDate = Date()
            WriteCoalescer.shared?.requestSave(reason: "stylesheet-reapply")
            
            #if DEBUG
            print("✅ Updated attributedContent with new styles")
            #endif
            #if DEBUG
            print("✅ Reapplied all styles successfully")
            #endif
            
            // Create undo command only if requested (not during initial document load)
            if registerUndo {
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
            } else {
                #if DEBUG
                print("ℹ️ Skipping undo command (initial load)")
                #endif
            }
            
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
        return !hasUnresolvedStyles
    }

    private func requestStyleReapply() {
        hasPendingStyleReapply = true
        attemptPendingStyleReapply()
    }

    private func requestStyleDefinitionReapply(styleName: String) {
        allowsLegacyStyleReapply = true
        requestStyleReapply()
        if hasPendingStyleReapply && (
            saveDebounceTimer != nil ||
            pendingDebouncedAttributedContent != nil ||
            pendingDebouncedSaveNeedsTextViewSnapshot
        ) {
            _ = commitPendingEditorSave(reason: "style-definition-change-preflight")
        }
    }

    private func attemptPendingStyleReapply() {
        guard hasPendingStyleReapply,
              !isReapplyingStyles,
              saveDebounceTimer == nil,
              !isPreviewingAsAlternateFormat,
              !isPerformingUndoRedo,
              !hasMissingAttachments,
              !hasMismatchedFormattedContent,
              !hasMissingSyncedBody,
              attributedContent.length > 0,
                            !AttributedStringSerializer.isLegacyRTFFormat(file.currentVersion?.effectiveFormattedContent)
                                || allowsLegacyStyleReapply else {
            return
        }

        isReapplyingStyles = true
        let completed = reapplyAllStyles(registerUndo: false)
        isReapplyingStyles = false

        guard completed else { return }
        hasPendingStyleReapply = false
        allowsLegacyStyleReapply = false
        if let project = file.project {
            markStylesReappliedOnOpen(for: project)
        }
    }

    private func styleReapplyCacheKey(for project: Project) -> String? {
        guard let styleSheet = project.styleSheet else { return nil }
        return "FileEditView.lastStyleReapply.\(file.id.uuidString).\(styleSheet.id.uuidString)"
    }

    private func shouldReapplyStylesOnOpen(for project: Project) -> Bool {
        guard let styleSheet = project.styleSheet,
              let cacheKey = styleReapplyCacheKey(for: project) else {
            return false
        }

        let styleModifiedDate = styleSheet.latestStyleModifiedDate
        let styleModified = styleModifiedDate.timeIntervalSinceReferenceDate
        let lastApplied = UserDefaults.standard.double(forKey: cacheKey)
        if lastApplied < styleModified {
            return true
        }

        let sourceContent = textViewCoordinator.textView.map {
            NSAttributedString(attributedString: $0.attributedText)
        } ?? attributedContent
        return StyleReapplicationAttributeMerger.hasStyleMismatch(in: sourceContent) { styleName in
            styleSheet.style(named: styleName)
        }
    }

    private func markStylesReappliedOnOpen(for project: Project) {
        guard let styleSheet = project.styleSheet,
              let cacheKey = styleReapplyCacheKey(for: project) else {
            return
        }
        UserDefaults.standard.set(styleSheet.latestStyleModifiedDate.timeIntervalSinceReferenceDate, forKey: cacheKey)
    }

    /// Apply a paragraph style to the current selection
    private func applyParagraphStyle(_ style: UIFont.TextStyle) {
        let activeRange: NSRange
        let sourceContent: NSAttributedString
        if let textView = textViewCoordinator.textView {
            activeRange = textView.selectedRange
            sourceContent = NSAttributedString(attributedString: textView.attributedText)
            selectedRange = activeRange
        } else {
            activeRange = selectedRange
            sourceContent = attributedContent
        }

        #if DEBUG
        print("📝 ========== APPLY PARAGRAPH STYLE START ==========")
        #if DEBUG
        print("📝 Style: \(style.rawValue)")
        #endif
        #if DEBUG
        print("📝 selectedRange: {\(activeRange.location), \(activeRange.length)}")
        #endif
        #if DEBUG
        print("📝 Document length: \(sourceContent.length)")
        #endif
        
        // Log current attributes at selection
        if sourceContent.length > 0 && activeRange.location < sourceContent.length {
            let attrs = sourceContent.attributes(at: activeRange.location, effectiveRange: nil)
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
        guard activeRange.location != NSNotFound,
              activeRange.location <= sourceContent.length else {
            #if DEBUG
            print("⚠️ selectedRange.location is invalid")
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
            if sourceContent.length == 0 {
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
                
                // Set typing attributes and trigger redraw synchronously
                // Using async dispatch here would race with SwiftUI's view update cycle,
                // causing the number to not appear until the user types
                if let textView = textViewCoordinator.textView {
                    textView.typingAttributes = typingAttrs
                    textView.setNeedsDisplay()
                }
                
                #if DEBUG
                print("📝 Empty text styled with model - picker should update")
                #endif
                return
            }
            
            // Store before state for undo
            let beforeContent = sourceContent
            
            // Apply the selected style, then normalize every semantic style run
            // so legacy physical fonts cannot render differently from the stylesheet.
            let styledSelection = TextFormatter.applyStyle(
                named: style.rawValue,
                to: sourceContent,
                range: activeRange,
                project: project,
                context: modelContext
            )
            newAttributedContent = StyleReapplicationAttributeMerger.reapplyStyles(
                in: styledSelection
            ) { styleName in
                StyleSheetService.resolveStyle(
                    named: styleName,
                    for: project,
                    context: modelContext
                )
            }
            
            #if DEBUG
            print("📝 Paragraph style applied successfully (model-based)")
            #endif
            
            // Log what we got back
            #if DEBUG
            if newAttributedContent.length > 0 && activeRange.location < newAttributedContent.length {
                let attrs = newAttributedContent.attributes(at: activeRange.location, effectiveRange: nil)
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
            
            // CRITICAL: Update the text view's textStorage first for immediate visual feedback
            // Then update the binding to keep them in sync
            let cursorPosition = activeRange
            textViewCoordinator.modifyTypingAttributes { textView in
                textView.textStorage.setAttributedString(newAttributedContent)
                // Restore cursor position
                textView.selectedRange = cursorPosition
            }
            
            // Update local state
            attributedContent = newAttributedContent
            currentParagraphStyle = style
            
            // Update typing attributes for new text
            let typingAttrs = TextFormatter.getTypingAttributes(
                forStyleNamed: style.rawValue,
                project: project,
                context: modelContext
            )
            textViewCoordinator.modifyTypingAttributes { textView in
                textView.typingAttributes = typingAttrs
            }
            
            #if DEBUG
            print("📝 Updated text view and local state with styled content (model-based)")
            #endif
            
            // Create formatting command for undo/redo
            let command = FormatApplyCommand(
                description: "Paragraph Style",
                range: activeRange,
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
        if sourceContent.length == 0 {
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
                // Trigger redraw so the list number appears immediately
                textView.setNeedsDisplay()
            }
            
            #if DEBUG
            print("📝 Empty text styled - picker should update")
            #endif
            return
        }
        
        // Store before state for undo
        let beforeContent = sourceContent
        
        // Apply the style using TextFormatter
        newAttributedContent = TextFormatter.applyStyle(style, to: sourceContent, range: activeRange)
        
        #if DEBUG
        print("📝 Paragraph style applied successfully")
        #endif
        
        // CRITICAL: Update the text view's textStorage first for immediate visual feedback
        // Then update the binding to keep them in sync
        let cursorPosition = activeRange
        textViewCoordinator.modifyTypingAttributes { textView in
            textView.textStorage.setAttributedString(newAttributedContent)
            textView.selectedRange = cursorPosition
        }
        
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
            range: activeRange,
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
                    var imageStyleName = "default"
                    var spacingAbove: CGFloat = 0
                    var spacingBelow: CGFloat = 0
                    var borderStyle: ImageAttachment.BorderStyle = .none
                    var borderPadding: CGFloat = 0
                    
                    if let project = self.file.project,
                       let stylesheet = project.styleSheet,
                       let imageStyles = stylesheet.imageStyles,
                       let defaultStyle = imageStyles.first(where: { $0.name == "default" }) {
                        scale = defaultStyle.defaultScale
                        alignment = defaultStyle.defaultAlignment
                        hasCaption = defaultStyle.hasCaptionByDefault
                        captionStyle = defaultStyle.defaultCaptionStyle
                        imageStyleName = defaultStyle.name
                        spacingAbove = defaultStyle.defaultSpacingAbove
                        spacingBelow = defaultStyle.defaultSpacingBelow
                        borderStyle = defaultStyle.defaultBorderStyle
                        borderPadding = defaultStyle.defaultBorderPadding
                        #if DEBUG
                        print("🖼️ Using image style '\(defaultStyle.displayName)': scale=\(scale), alignment=\(alignment.rawValue)")
                        #endif
                    } else {
                        #if DEBUG
                        print("🖼️ Using hardcoded defaults: scale=1.0, alignment=center")
                        #endif
                    }
                    
                    // NOTE: Do NOT bake a device-specific "fit to width" scale into the
                    // image here. `scale` is interpreted as a fraction of the text
                    // column width (1.0 == fill the column) and the display size is
                    // computed per-device at layout time (see ImageAttachment.displaySize
                    // and attachmentBounds). Computing a fit factor from this device's
                    // window would make the image render at the wrong size on other
                    // devices and on the printed page. We keep the stylesheet default
                    // scale so the image fills the column on every device.
                    
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
                        imageStyleName: imageStyleName,
                        spacingAbove: spacingAbove,
                        spacingBelow: spacingBelow,
                        borderStyle: borderStyle,
                        borderPadding: borderPadding,
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
        imageStyleName: String,
        spacingAbove: CGFloat,
        spacingBelow: CGFloat,
        borderStyle: ImageAttachment.BorderStyle,
        borderPadding: CGFloat,
        originalFilename: String? = nil
    ) {
        guard let imageData = imageData else { return }

        flushPendingEditorChanges(reason: "image-insert-preflight")
        
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
            imageStyleName: imageStyleName,
            spacingAbove: spacingAbove,
            spacingBelow: spacingBelow,
            borderStyle: borderStyle,
            borderPadding: borderPadding,
            originalFilename: originalFilename,
            targetFile: file
        )
        
        undoManager.execute(command)
        try? WriteCoalescer.shared?.requestSaveAndFlush(reason: "image-insert")
        let imagePosition = command.insertedImagePosition ?? insertionPoint
        
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
        if newContent.length > imagePosition {
            let attrs = newContent.attributes(at: imagePosition, effectiveRange: nil)
            if let attachment = attrs[.attachment] as? NSTextAttachment {
                #if DEBUG
                print("🖼️ Found attachment at position \(imagePosition): \(type(of: attachment))")
                #endif
            } else {
                #if DEBUG
                print("⚠️ NO attachment found at position \(imagePosition)")
                #endif
                #if DEBUG
                let character = (newContent.string as NSString).substring(with: NSRange(location: imagePosition, length: 1))
                print("⚠️ Character at \(imagePosition): '\(character)'")
                #endif
            }
        }
        
        attributedContent = newContent
        
        // Move cursor after the inserted image
        selectedRange = NSRange(location: imagePosition + 1, length: 0)
        
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

    #if DEBUG
    private func logVersionDiagnostics(_ context: String) {
        let rawVersions = file.versions ?? []
        let sortedVersions = rawVersions.sorted { $0.versionNumber < $1.versionNumber }
        let rawLabels = rawVersions.map { "v\($0.versionNumber):\($0.id.uuidString.prefix(8))" }
        let sortedLabels = sortedVersions.map { "v\($0.versionNumber):\($0.id.uuidString.prefix(8))" }
        let current = file.currentVersion
        let sortedIndex = sortedVersions.firstIndex(where: { $0.id == current?.id })
        print("🧪 [VersionDelete] \(context)")
        print("   file: \(file.name)")
        print("   file.currentVersionIndex: \(file.currentVersionIndex)")
        print("   ui currentVersionIndex state: \(currentVersionIndex)")
        print("   raw count: \(rawVersions.count) raw: \(rawLabels)")
        print("   sorted count: \(sortedVersions.count) sorted: \(sortedLabels)")
        print("   current version: \(current?.versionNumber ?? -1) id: \(current?.id.uuidString.prefix(8) ?? "nil")")
        print("   current sorted index: \(sortedIndex.map(String.init) ?? "nil")")
    }
    #endif

    
    private func handleVersionAction(_ action: VersionAction) {
        #if DEBUG
        print("📝 handleVersionAction called with action: \(action) (rawValue: \(action.rawValue))")
        print("   Version count: \(file.versions?.count ?? 0)")
        logVersionDiagnostics("toolbar action received")
        #endif
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
            // Force UI refresh to update delete button state
            refreshTrigger = UUID()
        case .delete:
            #if DEBUG
            logVersionDiagnostics("about to present delete alert")
            #endif
            presentDeleteAlert = true
        }
    }

    private func clearCurrentTextContent() {
        let bodyAttributes: [NSAttributedString.Key: Any]
        if let project = file.project {
            bodyAttributes = TextFormatter.getTypingAttributes(
                forStyleNamed: UIFont.TextStyle.body.rawValue,
                project: project,
                context: modelContext
            )
        } else {
            bodyAttributes = [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.label
            ]
        }

        let clearedContent = NSAttributedString(string: "", attributes: bodyAttributes)

        textViewCoordinator.modifyTypingAttributes { textView in
            textView.attributedText = clearedContent
            textView.typingAttributes = bodyAttributes
            textView.selectedRange = NSRange(location: 0, length: 0)
        }

        attributedContent = clearedContent
        previousContent = ""
        previousAttributedContent = clearedContent
        selectedRange = NSRange(location: 0, length: 0)

        cancelPendingEditorSave()

        saveChanges()
        saveUndoState()
        refreshTrigger = UUID()

        clearTextToastTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            showClearTextToast = true
        }

        clearTextToastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                showClearTextToast = false
            }
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
                let firstParagraphStyleName = project.styleSheet?.firstParagraphStyle?.name ?? UIFont.TextStyle.body.rawValue
                let bodyAttrs = TextFormatter.getTypingAttributes(
                    forStyleNamed: firstParagraphStyleName,
                    project: project,
                    context: modelContext
                )
                
                // No iPhone-specific font changes - use stylesheet fonts with view scale
                
                // Debug: Log what we're initializing with
                #if DEBUG
                print("📝 loadCurrentVersion: Initializing with first-paragraph style '\(firstParagraphStyleName)' from stylesheet '\(project.styleSheet?.name ?? "none")'")
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
        // NOTE: Do NOT call saveChanges() here. The caller (onDisappear) already calls
        // saveChanges() before saveUndoState(). A double-save can cause textStyle degradation
        // because the encode→decode round-trip may lose font descriptor metadata.
    }
    
    /// Toggle between Rich Text and Markdown display modes (non-destructive preview)
    /// This only changes how content is displayed - it does NOT permanently convert the file.
    /// The file's actual contentType is preserved. Users can view their content in either format
    /// without risk of data loss.
    private func toggleContentType() {
        guard let textView = textViewCoordinator.textView else {
            #if DEBUG
            print("⚠️ toggleContentType: No text view available")
            #endif
            return
        }
        
        if isPreviewingAsAlternateFormat {
            // Toggling BACK from preview mode → restore original content from memory
            if let savedContent = prePreviewContent {
                textView.attributedText = savedContent
                attributedContent = savedContent
                
                #if DEBUG
                print("📝 Restored original \(file.isMarkdown ? "Markdown" : "Rich Text") content from prePreviewContent")
                #endif
            }
            prePreviewContent = nil
            isPreviewingAsAlternateFormat = false
        } else {
            // Toggling INTO preview mode → convert for display only (don't save)
            // Store the current content so we can restore it later (NOT from file, from memory)
            let currentContent = textView.attributedText ?? NSAttributedString()
            prePreviewContent = currentContent
            
            if file.isMarkdown {
                // Markdown file → show as Rich Text preview
                do {
                    let markdownText = currentContent.string
                    let styleSheet = file.project?.styleSheet
                    let renderedContent = try MarkdownImportService.importMarkdown(from: markdownText, styleSheet: styleSheet)
                    
                    // Update display only - do NOT save to file
                    textView.attributedText = renderedContent
                    attributedContent = renderedContent
                    
                    #if DEBUG
                    print("📝 Preview: Markdown → Rich Text (\(markdownText.count) chars → \(renderedContent.length) styled)")
                    #endif
                } catch {
                    #if DEBUG
                    print("❌ Failed to render Markdown as Rich Text: \(error)")
                    #endif
                    // Don't enter preview mode if conversion fails
                    return
                }
            } else {
                // Rich Text file → show as Markdown preview
                do {
                    let filename = file.name
                    let markdownString = try MarkdownExportService.exportToMarkdown(
                        currentContent,
                        filename: filename,
                        footnotes: file.currentVersion?.footnotes
                    )
                    
                    let markdownContent = NSAttributedString(
                        string: markdownString,
                        attributes: [
                            .font: UIFont.systemFont(ofSize: 17),
                            .foregroundColor: UIColor.label
                        ]
                    )
                    
                    // Update display only - do NOT save to file
                    textView.attributedText = markdownContent
                    attributedContent = markdownContent
                    
                    #if DEBUG
                    print("📝 Preview: Rich Text → Markdown (\(currentContent.length) styled → \(markdownString.count) chars)")
                    #endif
                } catch {
                    #if DEBUG
                    print("❌ Failed to export Rich Text as Markdown: \(error)")
                    #endif
                    // Don't enter preview mode if conversion fails
                    return
                }
            }
            isPreviewingAsAlternateFormat = true
        }
        
        // Force UI refresh
        refreshTrigger = UUID()
    }
    
    // MARK: - Orphaned Attachment Cleanup
    
    /// Remove U+FFFC characters that have no corresponding NSTextAttachment.
    /// These are stale placeholders left behind when an attachment was deleted
    /// but the replacement character was not cleaned up.
    private static func stripOrphanedAttachmentPlaceholders(from attributedString: NSAttributedString) -> NSAttributedString {
        let text = attributedString.string
        guard text.contains("\u{FFFC}") else { return attributedString }
        
        let mutable = NSMutableAttributedString(attributedString: attributedString)
        // Collect ranges of orphaned U+FFFC (no attachment attribute) in reverse
        var orphanedRanges: [NSRange] = []
        mutable.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutable.length), options: []) { _, _, _ in }
        
        // Walk every character; if it's U+FFFC and has no attachment, it's orphaned
        let nsString = text as NSString
        for i in stride(from: nsString.length - 1, through: 0, by: -1) {
            if nsString.character(at: i) == 0xFFFC {
                let hasAttachment = mutable.attribute(.attachment, at: i, effectiveRange: nil) != nil
                let hasReferenceMetadata = mutable.attribute(.referenceType, at: i, effectiveRange: nil) != nil
                    && mutable.attribute(.referenceID, at: i, effectiveRange: nil) != nil
                if !hasAttachment && !hasReferenceMetadata {
                    orphanedRanges.append(NSRange(location: i, length: 1))
                }
            }
        }
        
        guard !orphanedRanges.isEmpty else { return attributedString }
        
        // Delete in reverse order (ranges already reversed from the stride)
        for range in orphanedRanges {
            mutable.deleteCharacters(in: range)
        }
        
        return mutable
    }

    private static func hasUnrecognizedAttachmentPlaceholders(in attributedString: NSAttributedString) -> Bool {
        let placeholderCount = attributedString.string.filter { $0 == "\u{FFFC}" }.count
        guard placeholderCount > 0 else { return false }

        var recognizedAttachmentCount = 0
        let nsString = attributedString.string as NSString
        for i in 0..<nsString.length where nsString.character(at: i) == 0xFFFC {
            let value = attributedString.attribute(.attachment, at: i, effectiveRange: nil)
            let hasReferenceMetadata = attributedString.attribute(.referenceType, at: i, effectiveRange: nil) != nil
                && attributedString.attribute(.referenceID, at: i, effectiveRange: nil) != nil
            if value is ImageAttachment || value is CommentAttachment || value is FootnoteAttachment || value is ReferenceAttachment || hasReferenceMetadata {
                recognizedAttachmentCount += 1
            }
        }

        return recognizedAttachmentCount < placeholderCount
    }

    private func attachmentSignature(in content: NSAttributedString) -> Set<String> {
        var signature = Set<String>()
        content.enumerateAttribute(.attachment, in: NSRange(location: 0, length: content.length), options: []) { value, range, _ in
            if let attachment = value as? FootnoteAttachment {
                signature.insert("footnote:\(attachment.footnoteID.uuidString)")
            } else if let attachment = value as? CommentAttachment {
                signature.insert("comment:\(attachment.commentID.uuidString)")
            } else if let attachment = value as? ReferenceAttachment {
                signature.insert("reference:\(attachment.entryID.uuidString):\(attachment.referenceType.rawValue)")
            } else if value is ImageAttachment {
                signature.insert("image:\(range.location)")
            }
        }
        return signature
    }

    #if DEBUG
    private func attachmentDebugSummary(_ content: NSAttributedString) -> String {
        attachmentSignature(in: content).sorted().joined(separator: ",")
    }

    private func footnoteDebugSummary(_ content: NSAttributedString?) -> String {
        guard let content else { return "nil" }

        var markers: [String] = []
        content.enumerateAttribute(.attachment, in: NSRange(location: 0, length: content.length), options: []) { value, range, _ in
            guard let attachment = value as? FootnoteAttachment else { return }
            markers.append("@\(range.location)#\(attachment.number):\(attachment.footnoteID.uuidString.prefix(8))")
        }

        return "len=\(content.length) markers=[\(markers.joined(separator: ","))]"
    }
    #endif
    
    private func saveChanges(reason: String = "file-editor-saveChanges") {
        // IMPORTANT: Do NOT save if formattedContent is incomplete from CloudKit sync.
        // The decoded content is missing image attachments that exist on another device.
        // Saving would overwrite the phone's complete formattedContent with a stripped version.
        if hasMissingAttachments {
            #if DEBUG
            print("⚠️ [FileEditView] saveChanges skipped — hasMissingAttachments is true (CloudKit sync incomplete)")
            #endif
            return
        }
        if hasMismatchedFormattedContent {
            #if DEBUG
            print("⚠️ [FileEditView] saveChanges skipped — formattedContent does not match plain text (CloudKit sync incomplete)")
            #endif
            return
        }
        if hasMissingSyncedBody {
            #if DEBUG
            print("⚠️ [FileEditView] saveChanges skipped — synced text body is missing on this device")
            #endif
            return
        }
        
        // IMPORTANT: Do NOT save while previewing in alternate format!
        // The textView contains converted preview content, not the actual file content.
        // Saving now would corrupt the file by overwriting the original with preview content.
        if isPreviewingAsAlternateFormat {
            #if DEBUG
            print("⚠️ saveChanges skipped - currently in preview mode (alternate format)")
            #endif
            return
        }
        
        // Save the current attributed content to the model
        // IMPORTANT: Get the current content from the textView to include all attachments (comments, images)
        var contentToPersist: NSAttributedString
        var metadataToPersist: Data?
        if let textView = textViewCoordinator.textView {
            let rawContent = textView.attributedText ?? NSAttributedString()
            let currentContent = normalizeReferenceAttachmentsToText(in: rawContent)
            if rawContent !== currentContent {
                textView.textStorage.setAttributedString(currentContent)
            }
            contentToPersist = currentContent
            metadataToPersist = extractReferenceMetadata(from: currentContent).encode()
            
            // Count attachments for debugging
            var commentCount = 0
            var imageCount = 0
            var footnoteCount = 0
            var referenceCount = 0
            var poemSectionCount = 0
            currentContent.enumerateAttribute(.attachment, in: NSRange(location: 0, length: currentContent.length)) { value, range, _ in
                if value is CommentAttachment {
                    commentCount += 1
                } else if value is ImageAttachment {
                    imageCount += 1
                } else if value is FootnoteAttachment {
                    footnoteCount += 1
                } else if value is ReferenceAttachment {
                    referenceCount += 1
                }
            }
            currentContent.enumerateAttribute(.poemSectionType, in: NSRange(location: 0, length: currentContent.length)) { value, range, _ in
                if value != nil {
                    poemSectionCount += 1
                }
            }
        } else {
            contentToPersist = attributedContent
            metadataToPersist = extractReferenceMetadata(from: contentToPersist).encode()
        }

        guard let currentVersion = file.currentVersion else { return }

        let storedContent = currentVersion.attributedContent ?? NSAttributedString()
        let contentChanged = !storedContent.isEqual(to: contentToPersist)
        let metadataChanged = currentVersion.referenceMetadataData != metadataToPersist

        guard contentChanged || metadataChanged else {
            return
        }

        currentVersion.attributedContent = contentToPersist
        currentVersion.referenceMetadataData = metadataToPersist
        
        file.modifiedDate = Date()
        
        WriteCoalescer.shared?.requestSave(reason: reason)
    }

    private func flushPendingEditorChanges(reason: String = "editor-flush") {
        textViewCoordinator.flushPendingTyping?()
        if !commitPendingEditorSave(reason: reason) {
            saveChanges(reason: reason)
        }
        saveUndoState()
        WriteCoalescer.shared?.flush()
    }

    private func handleEditorDidEnterBackground() {
        #if targetEnvironment(macCatalyst)
        flushPendingEditorChanges(reason: "editor-did-enter-background-flush")
        #else
        if scenePhase == .active, textViewCoordinator.textView?.isFirstResponder == true {
            #if DEBUG
            print("💾 [FileEditView] skipped background flush — editor still active")
            #endif
            return
        }

        flushPendingEditorChanges(reason: "editor-did-enter-background-flush")
        #endif
    }

    /// Reload the editor's attributed content from the SwiftData model after a CloudKit import,
    /// but ONLY when the user is not actively typing. This keeps the Mac editor in sync with
    /// changes made on other devices without clobbering in-progress local edits.
    private func reloadFromRemoteChangeIfSafe() {
        // Fresh contexts read SQLite, so reloading while the main context has an
        // unsaved style reapply would restore the previous paragraph attributes.
        if WriteCoalescer.shared?.pendingSave == true {
            hasPendingRemoteRefresh = true
            #if DEBUG
            print("⬇️ [Remote Refresh] Deferring reload — local save is pending")
            #endif
            return
        }

        // Skip if user is actively typing (debounce timer is live)
        guard saveDebounceTimer == nil else {
            hasPendingRemoteRefresh = true
            #if DEBUG
            print("⬇️ [Remote Refresh] Deferring reload — user is actively typing")
            #endif
            return
        }
        // Skip when in preview mode — editor shows converted content, not real content
        guard !isPreviewingAsAlternateFormat else { return }
        // Skip during undo/redo operations
        guard !isPerformingUndoRedo else { return }

        guard let versionId = file.currentVersion?.id else { return }

        // Use a fresh ModelContext to bypass SwiftData's in-memory @Transient cache.
        // The in-memory Version object's _cachedAttributedContent may not have been
        // invalidated after a CloudKit import — SwiftData does not clear @Transient
        // properties when merging remote changes. A fresh context reads directly from
        // the SQLite store, which always reflects the latest imported data.
        let freshContext = ModelContext(modelContext.container)
        let targetId = versionId
        guard let freshVersion = (try? freshContext.fetch(
            FetchDescriptor<Version>(predicate: #Predicate { $0.id == targetId })
        ))?.first else { return }

        let freshHasMismatchedFormattedContent = freshVersion.hasFormattedContentSyncMismatch
        if freshHasMismatchedFormattedContent {
            hasMismatchedFormattedContent = true
            #if DEBUG
            print("⬇️ [Remote Refresh] Fresh formattedContent still mismatches plain text — keeping editor read-only")
            #endif
            return
        }

        guard let freshContent = freshVersion.attributedContent else { return }
        let freshHasMissingAttachments = Self.hasUnrecognizedAttachmentPlaceholders(in: freshContent)
        if freshHasMissingAttachments {
            hasMissingAttachments = true
            #if DEBUG
            print("⬇️ [Remote Refresh] Fresh content has unrecognized attachment placeholders — keeping editor read-only")
            #endif
            return
        }

        // Fresh validation also unlocks an editor whose previous sync snapshot
        // was incomplete. Do this before the unchanged-content return below.
        hasMismatchedFormattedContent = false
        hasMissingAttachments = false
        hasMissingSyncedBody = Self.isMissingSyncedBody(freshVersion)

        // Only reload if content actually differs (check attributes too — e.g. underline removal
        // changes no plain text but the formatted attributes are different).
        let plainTextSame = freshContent.string == attributedContent.string
        let attributesSame = plainTextSame && freshContent.isEqual(to: attributedContent)
        guard !attributesSame else {
            #if DEBUG
            print("⬇️ [Remote Refresh] Content unchanged for '\(file.name)' — no reload needed")
            #endif
            return
        }

        #if DEBUG
        print("⬇️ [Remote Refresh] Sync imported new content for '\(file.name)' version=#\(freshVersion.versionNumber) — reloading editor (\(attributedContent.length) → \(freshContent.length) chars)")
        #endif

        // Strip adaptive colors for dark-mode safety (same as setupOnAppear)
        let processedContent = AttributedStringSerializer.stripAdaptiveColors(from: freshContent)
        hasMissingAttachments = Self.hasUnrecognizedAttachmentPlaceholders(in: processedContent)
        attributedContent = processedContent
        previousContent = processedContent.string
        previousAttributedContent = processedContent
    }

    private func refreshRemoteContentAndStylesIfSafe() {
        reloadFromRemoteChangeIfSafe()
    }
    
    /// FEATURE 029: Extract all reference attachments and create metadata
    /// This creates a persistent record of references that survives RTF serialization
    private func extractReferenceMetadata(from attributedString: NSAttributedString) -> ReferenceMetadata {
        var metadata = ReferenceMetadata()
        
        attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length)) { attributes, range, _ in
            if let referenceAttachment = attributes[.attachment] as? ReferenceAttachment {
                metadata.add(
                    type: referenceAttachment.referenceType,
                    entryID: referenceAttachment.entryID,
                    displayText: referenceAttachment.displayText,
                    displayNumber: referenceAttachment.displayNumber
                )
            } else if let typeString = attributes[.referenceType] as? String,
                      let type = ReferenceType(rawValue: typeString),
                      let idString = attributes[.referenceID] as? String,
                      let entryID = UUID(uuidString: idString) {
                let displayText = (attributedString.string as NSString).substring(with: range)
                metadata.add(
                    type: type,
                    entryID: entryID,
                    displayText: displayText,
                    displayNumber: 0
                )
            }
        }
        
        return metadata
    }

    private func normalizeReferenceAttachmentsToText(in attributedString: NSAttributedString) -> NSAttributedString {
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        var replacements: [(range: NSRange, attachment: ReferenceAttachment)] = []

        mutableString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutableString.length)) { value, range, _ in
            if let referenceAttachment = value as? ReferenceAttachment,
               referenceAttachment.referenceType != .index {
                replacements.append((range, referenceAttachment))
            }
        }

        guard !replacements.isEmpty else { return attributedString }

        for replacement in replacements.reversed() {
            var inheritedAttributes = mutableString.attributes(at: replacement.range.location, effectiveRange: nil)
            if replacement.range.location > 0 {
                inheritedAttributes.merge(mutableString.attributes(at: replacement.range.location - 1, effectiveRange: nil)) { current, _ in current }
            } else if replacement.range.location + replacement.range.length < mutableString.length {
                inheritedAttributes.merge(mutableString.attributes(at: replacement.range.location + replacement.range.length, effectiveRange: nil)) { current, _ in current }
            }
            inheritedAttributes.removeValue(forKey: .attachment)
            inheritedAttributes[.referenceType] = replacement.attachment.referenceType.rawValue
            inheritedAttributes[.referenceID] = replacement.attachment.entryID.uuidString
            inheritedAttributes[.referencePrimary] = replacement.attachment.isPrimaryReference

            let markerString = NSAttributedString(string: replacement.attachment.displayText, attributes: inheritedAttributes)
            mutableString.replaceCharacters(in: replacement.range, with: markerString)
        }

        return mutableString
    }
    
    /// FEATURE 029: Restore ReferenceAttachment instances from metadata
    /// RTF format doesn't preserve custom NSTextAttachment subclasses, so we use
    /// the stored metadata to recreate ReferenceAttachment instances on file load
    private func restoreReferenceAttachments(in attributedString: NSAttributedString, from metadata: ReferenceMetadata) -> NSAttributedString {
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        var mutableMetadata = metadata
        var attachmentsToReplace: [(range: NSRange, entry: ReferenceMetadataEntry)] = []
        var orphanedAttachments: [NSRange] = []
        
        func attributedReferenceString(for entry: ReferenceMetadataEntry, inheritedAttributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
            let result = NSMutableAttributedString(string: entry.displayText)
            let range = NSRange(location: 0, length: result.length)
            result.addAttributes(inheritedAttributes.filter { key, _ in
                key != .attachment && key != .referenceType && key != .referenceID && key != .referencePrimary
            }, range: range)
            result.addAttributes([
                .referenceType: entry.type.rawValue,
                .referenceID: entry.entryID.uuidString,
                .referencePrimary: false
            ], range: range)
            return result
        }

        // Find all generic attachments and match them with metadata entries
        mutableString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutableString.length)) { value, range, _ in
            if value != nil {
                // Check if this is a ReferenceAttachment (from saved content)
                if let refAttachment = value as? ReferenceAttachment {
                    // Check if there's a metadata entry for this
                    if let index = mutableMetadata.references.firstIndex(where: { $0.entryID == refAttachment.entryID }) {
                        let entry = mutableMetadata.references.remove(at: index)
                        attachmentsToReplace.append((range: range, entry: entry))
                    } else {
                        let entry = ReferenceMetadataEntry(type: refAttachment.referenceType, entryID: refAttachment.entryID, displayText: refAttachment.displayText, displayNumber: refAttachment.displayNumber)
                        attachmentsToReplace.append((range: range, entry: entry))
                    }
                } else if !(value is CommentAttachment) && !(value is ImageAttachment) && !(value is FootnoteAttachment) {
                    // Generic attachment (should not happen, but handle it)
                    if !mutableMetadata.references.isEmpty {
                        let entry = mutableMetadata.references.removeFirst()
                        attachmentsToReplace.append((range: range, entry: entry))
                    } else {
                        orphanedAttachments.append(range)
                    }
                }
            }
        }

        let nsString = mutableString.string as NSString
        for index in 0..<nsString.length where nsString.character(at: index) == 0xFFFC {
            guard mutableString.attribute(.attachment, at: index, effectiveRange: nil) == nil,
                  let typeString = mutableString.attribute(.referenceType, at: index, effectiveRange: nil) as? String,
                  let type = ReferenceType(rawValue: typeString),
                  let idString = mutableString.attribute(.referenceID, at: index, effectiveRange: nil) as? String,
                  let entryID = UUID(uuidString: idString) else {
                continue
            }

            if let metadataIndex = mutableMetadata.references.firstIndex(where: { $0.entryID == entryID && $0.type == type }) {
                let entry = mutableMetadata.references.remove(at: metadataIndex)
                attachmentsToReplace.append((range: NSRange(location: index, length: 1), entry: entry))
            }
        }
        
        // Remove orphaned attachments in reverse order to maintain ranges
        for range in orphanedAttachments.reversed() {
            mutableString.deleteCharacters(in: range)
        }
        
        // Replace generic attachments with proper ReferenceAttachment instances
        for (range, entry) in attachmentsToReplace.reversed() {
            let inheritedAttributes: [NSAttributedString.Key: Any]
            if range.location > 0 {
                inheritedAttributes = mutableString.attributes(at: range.location - 1, effectiveRange: nil)
            } else if range.location + range.length < mutableString.length {
                inheritedAttributes = mutableString.attributes(at: range.location + range.length, effectiveRange: nil)
            } else {
                inheritedAttributes = [:]
            }
            let attachmentString = attributedReferenceString(for: entry, inheritedAttributes: inheritedAttributes)
            mutableString.replaceCharacters(in: range, with: attachmentString)
        }
        
        return mutableString
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

    private func updateImageStyle(
        _ values: ImageStyleEditorValues,
        attachment: ImageAttachment
    ) {
        guard let styleSheet = file.project?.styleSheet else {
            return
        }
        let relatedStyle = styleSheet.imageStyles?.first(where: { $0.name == values.imageStyleName })
        let persistedStyle = (try? modelContext.fetch(FetchDescriptor<ImageStyle>()))?.first {
            $0.name == values.imageStyleName && $0.styleSheet?.id == styleSheet.id
        }
        guard let imageStyle = relatedStyle ?? persistedStyle else { return }

        imageStyle.defaultScale = values.scale
        imageStyle.defaultAlignment = values.alignment
        imageStyle.hasCaptionByDefault = values.hasCaption
        imageStyle.defaultCaptionStyle = values.captionStyle
        imageStyle.defaultSpacingAbove = values.spacingAbove
        imageStyle.defaultSpacingBelow = values.spacingBelow
        imageStyle.defaultBorderStyle = values.borderStyle
        imageStyle.defaultBorderPadding = values.borderPadding
        imageStyle.modifiedDate = Date()
        styleSheet.modifiedDate = Date()
        WriteCoalescer.shared?.requestSave(reason: "image-style-update")

        if let content = file.currentVersion?.attributedContent {
            content.enumerateAttribute(
                .attachment,
                in: NSRange(location: 0, length: content.length)
            ) { value, _, stop in
                guard let storedAttachment = value as? ImageAttachment,
                      storedAttachment.imageID == attachment.imageID else { return }
                storedAttachment.imageStyleName = imageStyle.name
                stop.pointee = true
            }
        }

        let updatedFiles = StyleSheetService.reapplyUpdatedImageStyle(
            imageStyle,
            in: styleSheet,
            context: modelContext
        )
        #if DEBUG
        print("✅ Reapplied image style '\(imageStyle.name)' in \(updatedFiles) file(s)")
        #endif

        guard let updatedContent = file.currentVersion?.attributedContent else { return }
        attributedContent = updatedContent
        previousAttributedContent = updatedContent
        if let textView = textViewCoordinator.textView {
            textView.textStorage.setAttributedString(updatedContent)
            textView.layoutManager.invalidateLayout(
                forCharacterRange: NSRange(location: 0, length: updatedContent.length),
                actualCharacterRange: nil
            )
            textView.layoutManager.invalidateDisplay(
                forCharacterRange: NSRange(location: 0, length: updatedContent.length)
            )
            textView.setNeedsLayout()
            textView.setNeedsDisplay()
        }
        selectedImage = attachment
        refreshTrigger = UUID()
    }
    
    /// Update an existing image attachment with new properties
    private func updateImage(
        attachment: ImageAttachment,
        imageStyleName: String,
        scale: CGFloat,
        alignment: ImageAttachment.ImageAlignment,
        hasCaption: Bool,
        captionPrefix: String,
        captionText: String,
        captionStyle: String,
        spacingAbove: CGFloat,
        spacingBelow: CGFloat,
        borderStyle: ImageAttachment.BorderStyle,
        borderPadding: CGFloat
    ) {
        #if DEBUG
        print("🖼️ Updating image: scale=\(scale), alignment=\(alignment.rawValue)")
        #endif
        
        let sourceContent = textViewCoordinator.textView.map {
            NSAttributedString(attributedString: $0.attributedText)
        } ?? attributedContent
        let mutableContent = NSMutableAttributedString(attributedString: sourceContent)

        var storedAttachment: ImageAttachment?
        var position: Int?
        mutableContent.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: mutableContent.length)
        ) { value, range, stop in
            guard let candidate = value as? ImageAttachment,
                  candidate.imageID == attachment.imageID else { return }
            storedAttachment = candidate
            position = range.location
            stop.pointee = true
        }

        guard let storedAttachment, let position else {
            #if DEBUG
            print("❌ Could not find attachment in content")
            #endif
            return
        }
        
        // Capture the before state for undo/redo
        let beforeContent = sourceContent
        
        // Update the attachment properties
        let oldScale = storedAttachment.scale
        let oldAlignment = storedAttachment.alignment
        let oldHasCaption = storedAttachment.hasCaption
        let oldCaptionPrefix = storedAttachment.captionPrefix
        let oldCaptionText = storedAttachment.captionText
        let oldCaptionStyle = storedAttachment.captionStyle
        let oldImageStyleName = storedAttachment.imageStyleName
        let oldSpacingAbove = storedAttachment.spacingAbove
        let oldSpacingBelow = storedAttachment.spacingBelow
        let oldBorderStyle = storedAttachment.borderStyle
        let oldBorderPadding = storedAttachment.borderPadding

        storedAttachment.scale = scale
        storedAttachment.alignment = alignment
        storedAttachment.imageStyleName = imageStyleName
        storedAttachment.spacingAbove = max(0, spacingAbove)
        storedAttachment.spacingBelow = max(0, spacingBelow)
        storedAttachment.borderStyle = borderStyle
        storedAttachment.borderPadding = max(0, borderPadding)
        #if DEBUG
        print("🖼️ FileEditView.updateImage() - About to update caption")
        #endif
        storedAttachment.updateCaption(hasCaption: hasCaption, prefix: captionPrefix, text: captionText, style: captionStyle)
        #if DEBUG
        print("   After update: hasCaption=\(storedAttachment.hasCaption), prefix=\(storedAttachment.captionPrefix ?? "nil"), text=\(storedAttachment.captionText ?? "nil")")
        #endif
        
        mutableContent.addAttribute(
            .paragraphStyle,
            value: storedAttachment.paragraphStyle(),
            range: NSRange(location: position, length: 1)
        )
        
        // Update the content
        attributedContent = mutableContent
        file.currentVersion?.attributedContent = mutableContent
        file.modifiedDate = Date()

        if let textView = textViewCoordinator.textView {
            textView.textStorage.setAttributedString(mutableContent)
            let attachmentRange = NSRange(location: position, length: 1)
            let fullRange = NSRange(location: 0, length: textView.textStorage.length)
            textView.textStorage.addAttribute(.attachment, value: storedAttachment, range: attachmentRange)
            ImageAttachment.updateCaptionNumbers(
                in: textView.textStorage,
                styleSheet: file.project?.styleSheet,
                startingNumbers: manuscriptCaptionNumberOffsets
            )
            textView.textStorage.edited(.editedAttributes, range: fullRange, changeInLength: 0)
            textView.selectedRange = NSRange(location: position, length: 1)
            textView.layoutManager.invalidateLayout(
                forCharacterRange: fullRange,
                actualCharacterRange: nil
            )
            textView.layoutManager.invalidateDisplay(forCharacterRange: fullRange)
            textView.layoutManager.ensureLayout(for: textView.textContainer)
            textView.setNeedsDisplay()
            textView.setNeedsLayout()
            textView.layoutIfNeeded()
        }
        
        WriteCoalescer.shared?.requestSave(reason: "image-editor-apply")
        
        // Create undo/redo command to restore image properties
        let command = ImageUpdateCommand(
            description: "Update Image",
            beforeContent: beforeContent,
            afterContent: mutableContent,
            attachment: storedAttachment,
            oldScale: oldScale,
            oldAlignment: oldAlignment,
            oldHasCaption: oldHasCaption,
            oldCaptionPrefix: oldCaptionPrefix,
            oldCaptionText: oldCaptionText,
            oldCaptionStyle: oldCaptionStyle,
            oldImageStyleName: oldImageStyleName,
            oldSpacingAbove: oldSpacingAbove,
            oldSpacingBelow: oldSpacingBelow,
            oldBorderStyle: oldBorderStyle,
            oldBorderPadding: oldBorderPadding,
            newScale: scale,
            newAlignment: alignment,
            newHasCaption: hasCaption,
            newCaptionPrefix: captionPrefix,
            newCaptionText: captionText,
            newCaptionStyle: captionStyle,
            newImageStyleName: imageStyleName,
            newSpacingAbove: storedAttachment.spacingAbove,
            newSpacingBelow: storedAttachment.spacingBelow,
            newBorderStyle: storedAttachment.borderStyle,
            newBorderPadding: storedAttachment.borderPadding,
            targetFile: file
        )
        undoManager.execute(command)
        
        // Keep the image selected and update the selection to the image position
        selectedImage = storedAttachment
        
        // Set the selected range to the image position so when the view refreshes,
        // the selection is preserved
        selectedRange = NSRange(location: position, length: 1)
        
        // Trigger view refresh to show updated image
        // Note: We rely on the notification system in ImageAttachmentViewProvider to update the view
        // Accessing layoutManager would force TextKit 1 mode, breaking NSTextAttachmentViewProvider
        refreshTrigger = UUID()
        
        // Close the editor
        imageToEdit = nil
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
            Form {
                Section {
                    TextEditor(text: $commentText)
                        .font(.body)
                } header: {
                    Text("fileEdit.newComment.description")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
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
            Form {
                Section {
                    TextEditor(text: $footnoteText)
                        .font(.body)
                } header: {
                    Text("fileEdit.newFootnote.description")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
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
                    }
                    .disabled(footnoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Image Style Editor Sheet Content

/// Helper view to encapsulate the caption style logic for ImageStyleEditorView
private struct ImageStyleEditorSheetContent: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ImageStyle.displayOrder) private var persistedImageStyles: [ImageStyle]

    let imageAttachment: ImageAttachment
    let file: TextFile
    let onApply: (ImageStyleEditorValues) -> Void
    let onUpdateStyle: (ImageStyleEditorValues) -> Void
    let onCancel: () -> Void
    
    private var imageData: Data? {
        imageAttachment.imageData ?? imageAttachment.image?.pngData()
    }
    
    private var styleSheet: StyleSheet? {
        file.project?.styleSheet
    }
    
    private var captionStyles: [String] {
        // Get available caption styles from stylesheet
        let filteredCaptionStyles = styleSheet?.textStyles?
            .filter { $0.name.contains("Caption") }
            .map { $0.name }
            .sorted() ?? []
        
        if !filteredCaptionStyles.isEmpty {
            return filteredCaptionStyles
        }
        
        // Fallback: check if default caption styles exist in the stylesheet
        let defaults = ["UICTFontTextStyleCaption1", "UICTFontTextStyleCaption2"]
        let existingDefaults = defaults.filter { styleSheet?.style(named: $0) != nil }
        
        // If still empty, use defaults anyway for display
        return existingDefaults.isEmpty ? defaults : existingDefaults
    }

    private var imageStyles: [ImageStyle] {
        if let relatedStyles = styleSheet?.imageStyles, !relatedStyles.isEmpty {
            return relatedStyles
        }
        guard let styleSheetID = styleSheet?.id else { return [] }
        return persistedImageStyles.filter { $0.styleSheet?.id == styleSheetID }
    }
    
    var body: some View {
        ImageStyleEditorView(
            imageData: imageData,
            scale: imageAttachment.scale,
            alignment: imageAttachment.alignment,
            hasCaption: imageAttachment.hasCaption,
            captionPrefix: imageAttachment.captionPrefix ?? "Figure",
            captionText: imageAttachment.captionText ?? "",
            captionStyle: imageAttachment.captionStyle ?? "UICTFontTextStyleCaption1",
            imageStyleName: imageAttachment.imageStyleName,
            spacingAbove: imageAttachment.spacingAbove,
            spacingBelow: imageAttachment.spacingBelow,
            borderStyle: imageAttachment.borderStyle,
            borderPadding: imageAttachment.borderPadding,
            availableCaptionStyles: captionStyles,
            availableImageStyles: imageStyles,
            styleSheet: styleSheet,
            onApply: onApply,
            onUpdateStyle: onUpdateStyle,
            onCancel: onCancel
        )
        .onAppear {
            guard let styleSheet else { return }
            StyleSheetService.ensureDefaultImageStyle(in: styleSheet, context: modelContext)
        }
    }
}
/// Helper view to encapsulate the caption style logic for ImageStyleEditorView

