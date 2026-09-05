import SwiftUI
import UIKit
import SwiftData

extension Notification.Name {
    static let formattedTextEditorDidEndEditing = Notification.Name("FormattedTextEditorDidEndEditing")
}

struct TextEditorChange {
    let attributedText: NSAttributedString
    let range: NSRange?
    let replacementText: String?
}

enum FormattedTextEditorInsertionAttributes {
    static func sourceAttributes(
        in attributedText: NSAttributedString,
        typingAttributes: [NSAttributedString.Key: Any],
        replacing range: NSRange
    ) -> [NSAttributedString.Key: Any] {
        if range.length == 0,
           range.location > 0,
           range.location - 1 < attributedText.length {
            return attributedText.attributes(at: range.location - 1, effectiveRange: nil)
        }
        if range.location < attributedText.length {
            return attributedText.attributes(at: range.location, effectiveRange: nil)
        }
        return typingAttributes
    }

    static func merge(
        styleAttributes: [NSAttributedString.Key: Any],
        replacedAttributes: [NSAttributedString.Key: Any]
    ) -> [NSAttributedString.Key: Any] {
        var attributes = styleAttributes
        let targetStyle = styleAttributes[.textStyle] as? String
        let replacedStyle = replacedAttributes[.textStyle] as? String
        let preservesCharacterTraits = targetStyle == nil
            || replacedStyle == nil
            || targetStyle == replacedStyle

          if preservesCharacterTraits,
              let styleFont = styleAttributes[.font] as? UIFont {
                let styleTraits = FontFaceResolver.traits(of: styleFont)
                let bold = replacedAttributes[.explicitBold] as? Bool ?? styleTraits.bold
                let italic = replacedAttributes[.explicitItalic] as? Bool ?? styleTraits.italic
            attributes[.font] = FontFaceResolver.resolvedFont(from: styleFont, bold: bold, italic: italic)
            if let explicitBold = replacedAttributes[.explicitBold] { attributes[.explicitBold] = explicitBold }
            if let explicitItalic = replacedAttributes[.explicitItalic] { attributes[.explicitItalic] = explicitItalic }
        }

          if preservesCharacterTraits,
              styleAttributes[.underlineStyle] == nil,
           let underline = replacedAttributes[.underlineStyle] {
            attributes[.underlineStyle] = underline
        }
          if preservesCharacterTraits,
              styleAttributes[.strikethroughStyle] == nil,
           let strikethrough = replacedAttributes[.strikethroughStyle] {
            attributes[.strikethroughStyle] = strikethrough
        }

        return attributes
    }
}

enum FormattedTextEditorParagraphBreak {
    static func attributedString(
        currentParagraphAttributes: [NSAttributedString.Key: Any],
        newParagraphAttributes: [NSAttributedString.Key: Any]
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        result.append(NSAttributedString(string: "\n", attributes: currentParagraphAttributes))
        result.append(NSAttributedString(string: "\u{200B}", attributes: newParagraphAttributes))
        return result
    }
}

enum FormattedTextEditorImageClipboard {
    static let pasteboardType = "com.appworks.writingshedpro.image-attachment"

    static func selectedAttachment(in attributedString: NSAttributedString, range: NSRange) -> ImageAttachment? {
        guard range.length == 1,
              range.location >= 0,
              NSMaxRange(range) <= attributedString.length else {
            return nil
        }

        return attributedString.attribute(.attachment, at: range.location, effectiveRange: nil) as? ImageAttachment
    }

    static func encode(_ attachment: ImageAttachment) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: attachment, requiringSecureCoding: true)
    }

    static func decode(_ data: Data) -> ImageAttachment? {
        guard let attachment = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ImageAttachment.self, from: data) else {
            return nil
        }

        attachment.imageID = UUID()
        return attachment
    }
}

enum FormattedTextEditorAttachmentComparison {
    static func attachmentsMatch(_ first: NSAttributedString, _ second: NSAttributedString, includeLocation: Bool = true) -> Bool {
        attachmentSignature(in: first, includeLocation: includeLocation) == attachmentSignature(in: second, includeLocation: includeLocation)
    }

    static func attachmentSignature(in attributedString: NSAttributedString, includeLocation: Bool = true) -> [String] {
        var signature: [String] = []
        let fullRange = NSRange(location: 0, length: attributedString.length)

        attributedString.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
            guard let attachment = value as? NSTextAttachment else { return }

            let identity: String
            switch attachment {
            case let footnote as FootnoteAttachment:
                identity = "footnote:\(footnote.footnoteID.uuidString)"
            case let comment as CommentAttachment:
                identity = "comment:\(comment.commentID.uuidString)"
            case let reference as ReferenceAttachment:
                identity = "reference:\(reference.referenceType.rawValue):\(reference.entryID.uuidString)"
            case let image as ImageAttachment:
                identity = "image:\(image.imageID.uuidString)"
            case is PageBreakAttachment:
                identity = "pageBreak"
            default:
                identity = String(describing: type(of: attachment))
            }

            if includeLocation {
                signature.append("\(range.location):\(range.length):\(identity)")
            } else {
                signature.append(identity)
            }
        }

        return signature
    }
}

enum FormattedTextEditorContentComparison {
    static func hasExternalAttributeChange(
        current: NSAttributedString,
        incoming: NSAttributedString,
        bindingObjectChanged: Bool,
        isProcessingUserTextChange: Bool
    ) -> Bool {
        guard current.string == incoming.string,
              bindingObjectChanged,
              !isProcessingUserTextChange else {
            return false
        }

        return !current.isEqual(to: incoming)
    }
}

enum FormattedTextEditorImageBoundary {
    static func isImmediatelyAfterImage(in attributedString: NSAttributedString, location: Int) -> Bool {
        guard location > 0, location <= attributedString.length else { return false }

        let string = attributedString.string as NSString
        var index = location - 1
        var skippedNewline = false

        while index >= 0 {
            let character = string.character(at: index)
            if character == 0x200B {
                index -= 1
                continue
            }
            if character == 0x0A, !skippedNewline {
                skippedNewline = true
                index -= 1
                continue
            }
            return attributedString.attribute(.attachment, at: index, effectiveRange: nil) is ImageAttachment
        }

        return false
    }

    static func bodyParagraphInsertion(
        currentAttributes: [NSAttributedString.Key: Any],
        bodyAttributes: [NSAttributedString.Key: Any]
    ) -> NSAttributedString {
        let insertion = NSMutableAttributedString()
        insertion.append(NSAttributedString(string: "\n", attributes: currentAttributes))
        insertion.append(NSAttributedString(string: "\u{200B}", attributes: bodyAttributes))
        return insertion
    }
}

struct FormattedTextEditor: View {
    @Binding var attributedText: NSAttributedString
    @Binding var selectedRange: NSRange
    var onTextChange: ((TextEditorChange) -> Void)?
    var onSimpleTypingChange: ((NSRange, String, NSRange) -> Void)?
    var onSelectionChange: ((NSRange) -> Void)?
    var onImageTapped: ((ImageAttachment, CGRect, Int) -> Void)?
    var onClearImageSelection: (() -> Void)?
    var onImageCutRequested: ((ImageAttachment, Int) -> Void)?
    var onImagePasteRequested: ((ImageAttachment, Int) -> Void)?
    var onCommentTapped: ((CommentAttachment, Int) -> Void)?
    var onFootnoteTapped: ((FootnoteAttachment, Int) -> Void)?
    var onReferenceTapped: ((ReferenceAttachment, Int) -> Void)?
    var onReferenceDeleted: (([ReferenceAttachment], NSRange) -> Void)?
    var onCommentDeleted: (([CommentAttachment], NSRange) -> Void)?
    var onFootnoteDeleted: (([FootnoteAttachment], NSRange) -> Void)?
    var onMixedAttachmentsDeleted: (([ReferenceAttachment], [CommentAttachment], [FootnoteAttachment], NSRange) -> Void)?
    var onGlossaryAddRequested: ((String) -> Void)?
    var onIndexAddRequested: ((String) -> Void)?
    var onTabPressed: (() -> Void)?
    var onShiftTabPressed: (() -> Void)?
    var onZoomScaleChange: ((CGFloat) -> Void)?
    var textViewCoordinator: TextViewCoordinator?
    var project: Project?
    var captionNumberOffsets: [String: Int]
    var headingStyleCounters: [String: Int]
    var headingLastNumberForStyle: [String: Int]
    var showInvisibles: Bool = false
    var showLineNumbers: Bool = false
    var font: UIFont
    var textColor: UIColor
    var backgroundColor: UIColor
    var textContainerInset: UIEdgeInsets
    var isEditable: Bool
    var inputAccessoryView: UIView?

    init(
        attributedText: Binding<NSAttributedString>,
        selectedRange: Binding<NSRange> = .constant(NSRange(location: 0, length: 0)),
        textViewCoordinator: TextViewCoordinator? = nil,
        project: Project? = nil,
        captionNumberOffsets: [String: Int] = [:],
        headingStyleCounters: [String: Int] = [:],
        headingLastNumberForStyle: [String: Int] = [:],
        showInvisibles: Bool = false,
        showLineNumbers: Bool = false,
        font: UIFont = .preferredFont(forTextStyle: .body),
        textColor: UIColor = .label,
        backgroundColor: UIColor = .systemBackground,
        textContainerInset: UIEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8),
        isEditable: Bool = true,
        inputAccessoryView: UIView? = nil,
        onTextChange: ((TextEditorChange) -> Void)? = nil,
        onSimpleTypingChange: ((NSRange, String, NSRange) -> Void)? = nil,
        onSelectionChange: ((NSRange) -> Void)? = nil,
        onImageTapped: ((ImageAttachment, CGRect, Int) -> Void)? = nil,
        onClearImageSelection: (() -> Void)? = nil,
        onImageCutRequested: ((ImageAttachment, Int) -> Void)? = nil,
        onImagePasteRequested: ((ImageAttachment, Int) -> Void)? = nil,
        onCommentTapped: ((CommentAttachment, Int) -> Void)? = nil,
        onFootnoteTapped: ((FootnoteAttachment, Int) -> Void)? = nil,
        onReferenceTapped: ((ReferenceAttachment, Int) -> Void)? = nil,
        onReferenceDeleted: (([ReferenceAttachment], NSRange) -> Void)? = nil,
        onCommentDeleted: (([CommentAttachment], NSRange) -> Void)? = nil,
        onFootnoteDeleted: (([FootnoteAttachment], NSRange) -> Void)? = nil,
        onMixedAttachmentsDeleted: (([ReferenceAttachment], [CommentAttachment], [FootnoteAttachment], NSRange) -> Void)? = nil,
        onGlossaryAddRequested: ((String) -> Void)? = nil,
        onIndexAddRequested: ((String) -> Void)? = nil,
        onTabPressed: (() -> Void)? = nil,
        onShiftTabPressed: (() -> Void)? = nil,
        onZoomScaleChange: ((CGFloat) -> Void)? = nil
    ) {
        self._attributedText = attributedText
        self._selectedRange = selectedRange
        self.textViewCoordinator = textViewCoordinator
        self.project = project
        self.captionNumberOffsets = captionNumberOffsets
        self.headingStyleCounters = headingStyleCounters
        self.headingLastNumberForStyle = headingLastNumberForStyle
        self.showInvisibles = showInvisibles
        self.showLineNumbers = showLineNumbers
        self.font = font
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.textContainerInset = textContainerInset
        self.isEditable = isEditable
        self.inputAccessoryView = inputAccessoryView
        self.onTextChange = onTextChange
        self.onSimpleTypingChange = onSimpleTypingChange
        self.onSelectionChange = onSelectionChange
        self.onImageTapped = onImageTapped
        self.onClearImageSelection = onClearImageSelection
        self.onImageCutRequested = onImageCutRequested
        self.onImagePasteRequested = onImagePasteRequested
        self.onCommentTapped = onCommentTapped
        self.onFootnoteTapped = onFootnoteTapped
        self.onReferenceTapped = onReferenceTapped
        self.onReferenceDeleted = onReferenceDeleted
        self.onCommentDeleted = onCommentDeleted
        self.onFootnoteDeleted = onFootnoteDeleted
        self.onMixedAttachmentsDeleted = onMixedAttachmentsDeleted
        self.onGlossaryAddRequested = onGlossaryAddRequested
        self.onIndexAddRequested = onIndexAddRequested
        self.onTabPressed = onTabPressed
        self.onShiftTabPressed = onShiftTabPressed
        self.onZoomScaleChange = onZoomScaleChange
    }

    var body: some View {
        legacyEditor
    }

    private var legacyEditor: some View {
        LegacyFormattedTextEditor(
            attributedText: $attributedText,
            selectedRange: $selectedRange,
            textViewCoordinator: textViewCoordinator,
            project: project,
            captionNumberOffsets: captionNumberOffsets,
            headingStyleCounters: headingStyleCounters,
            headingLastNumberForStyle: headingLastNumberForStyle,
            showInvisibles: showInvisibles,
            showLineNumbers: showLineNumbers,
            font: font,
            textColor: textColor,
            backgroundColor: backgroundColor,
            textContainerInset: textContainerInset,
            isEditable: isEditable,
            inputAccessoryView: inputAccessoryView,
            onTextChange: onTextChange,
            onSimpleTypingChange: onSimpleTypingChange,
            onSelectionChange: onSelectionChange,
            onImageTapped: onImageTapped,
            onClearImageSelection: onClearImageSelection,
            onImageCutRequested: onImageCutRequested,
            onImagePasteRequested: onImagePasteRequested,
            onCommentTapped: onCommentTapped,
            onFootnoteTapped: onFootnoteTapped,
            onReferenceTapped: onReferenceTapped,
            onReferenceDeleted: onReferenceDeleted,
            onCommentDeleted: onCommentDeleted,
            onFootnoteDeleted: onFootnoteDeleted,
            onMixedAttachmentsDeleted: onMixedAttachmentsDeleted,
            onGlossaryAddRequested: onGlossaryAddRequested,
            onIndexAddRequested: onIndexAddRequested,
            onTabPressed: onTabPressed,
            onShiftTabPressed: onShiftTabPressed,
            onZoomScaleChange: onZoomScaleChange
        )
    }
}

/// A SwiftUI wrapper around UITextView that supports rich text formatting with NSAttributedString
struct LegacyFormattedTextEditor: UIViewRepresentable {
    
    // MARK: - Bindings
    
    /// The attributed text content
    @Binding var attributedText: NSAttributedString
    
    /// The currently selected text range
    @Binding var selectedRange: NSRange
    
    /// Optional callback when text changes
    var onTextChange: ((TextEditorChange) -> Void)?

    /// Lightweight callback for simple live typing where the text view already owns the change.
    var onSimpleTypingChange: ((NSRange, String, NSRange) -> Void)?
    
    /// Optional callback when selection changes
    var onSelectionChange: ((NSRange) -> Void)?
    
    /// Optional callback when user taps on an image
    var onImageTapped: ((ImageAttachment, CGRect, Int) -> Void)?
    
    /// Optional callback when image selection should be cleared (cursor moved away)
    var onClearImageSelection: (() -> Void)?

    /// Clipboard image operations are executed by FileEditView so they use its custom undo stack.
    var onImageCutRequested: ((ImageAttachment, Int) -> Void)?
    var onImagePasteRequested: ((ImageAttachment, Int) -> Void)?
    
    /// Optional callback when user taps on a comment
    var onCommentTapped: ((CommentAttachment, Int) -> Void)?
    
    /// Optional callback when user taps on a footnote
    var onFootnoteTapped: ((FootnoteAttachment, Int) -> Void)?
    
    /// Optional callback when user taps on a reference marker (Feature 029)
    var onReferenceTapped: ((ReferenceAttachment, Int) -> Void)?
    
    /// Optional callback when a reference marker is being deleted (Feature 029)
    var onReferenceDeleted: (([ReferenceAttachment], NSRange) -> Void)?
    
    /// Optional callback when a comment marker is being deleted
    var onCommentDeleted: (([CommentAttachment], NSRange) -> Void)?
    
    /// Optional callback when a footnote marker is being deleted
    var onFootnoteDeleted: (([FootnoteAttachment], NSRange) -> Void)?
    
    /// Unified callback when mixed attachment types are being deleted together
    /// Called when selection contains a mix of references, comments, and/or footnotes
    var onMixedAttachmentsDeleted: (([ReferenceAttachment], [CommentAttachment], [FootnoteAttachment], NSRange) -> Void)?
    
    /// Optional callback when user selects "Add to Glossary" from context menu (Feature 029)
    var onGlossaryAddRequested: ((String) -> Void)?
    
    /// Optional callback when user selects "Add to Index" from context menu (Feature 033)
    var onIndexAddRequested: ((String) -> Void)?
    
    /// Optional callback when Tab key is pressed (Feature 016 - list indent)
    var onTabPressed: (() -> Void)?
    
    /// Optional callback when Shift+Tab is pressed (Feature 016 - list outdent)
    var onShiftTabPressed: (() -> Void)?

    /// Optional callback when zoom scale changes via pinch or initial load
    var onZoomScaleChange: ((CGFloat) -> Void)?
    
    /// Coordinator for managing textView reference
    var textViewCoordinator: TextViewCoordinator?
    
    /// Project reference for dynamic numbering (Feature 016)
    var project: Project?

    /// Numbered captions in manuscript files preceding this file, keyed by style name.
    var captionNumberOffsets: [String: Int]

    /// Heading counters accumulated from manuscript files preceding this file.
    var headingStyleCounters: [String: Int]
    var headingLastNumberForStyle: [String: Int]
    
    /// Whether to show invisible characters (spaces, tabs, paragraph marks, page breaks)
    var showInvisibles: Bool = false

    /// Whether to show editor line numbers in the left gutter
    var showLineNumbers: Bool = false

    /// Width reserved for line number gutter
    private let lineNumberGutterWidth: CGFloat = 56
    
    // MARK: - Configuration
    
    /// Font to use for new text (when no formatting is applied)
    var font: UIFont
    
/// Text color for new text
    var textColor: UIColor
    
    /// Background color
    var backgroundColor: UIColor
    
    /// Text insets (padding)
    var textContainerInset: UIEdgeInsets
    
    /// Whether the text view is editable
    var isEditable: Bool
    
    /// Optional input accessory view (toolbar shown above keyboard)
    var inputAccessoryView: UIView?
    
    // MARK: - Initialization
    
    init(
        attributedText: Binding<NSAttributedString>,
        selectedRange: Binding<NSRange> = .constant(NSRange(location: 0, length: 0)),
        textViewCoordinator: TextViewCoordinator? = nil,
        project: Project? = nil,
        captionNumberOffsets: [String: Int] = [:],
        headingStyleCounters: [String: Int] = [:],
        headingLastNumberForStyle: [String: Int] = [:],
        showInvisibles: Bool = false,
        showLineNumbers: Bool = false,
        font: UIFont = .preferredFont(forTextStyle: .body),
        textColor: UIColor = .label,
        backgroundColor: UIColor = .systemBackground,
        textContainerInset: UIEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8),
        isEditable: Bool = true,
        inputAccessoryView: UIView? = nil,
        onTextChange: ((TextEditorChange) -> Void)? = nil,
        onSimpleTypingChange: ((NSRange, String, NSRange) -> Void)? = nil,
        onSelectionChange: ((NSRange) -> Void)? = nil,
        onImageTapped: ((ImageAttachment, CGRect, Int) -> Void)? = nil,
        onClearImageSelection: (() -> Void)? = nil,
        onImageCutRequested: ((ImageAttachment, Int) -> Void)? = nil,
        onImagePasteRequested: ((ImageAttachment, Int) -> Void)? = nil,
        onCommentTapped: ((CommentAttachment, Int) -> Void)? = nil,
        onFootnoteTapped: ((FootnoteAttachment, Int) -> Void)? = nil,
        onReferenceTapped: ((ReferenceAttachment, Int) -> Void)? = nil,
        onReferenceDeleted: (([ReferenceAttachment], NSRange) -> Void)? = nil,
        onCommentDeleted: (([CommentAttachment], NSRange) -> Void)? = nil,
        onFootnoteDeleted: (([FootnoteAttachment], NSRange) -> Void)? = nil,
        onMixedAttachmentsDeleted: (([ReferenceAttachment], [CommentAttachment], [FootnoteAttachment], NSRange) -> Void)? = nil,
        onGlossaryAddRequested: ((String) -> Void)? = nil,
        onIndexAddRequested: ((String) -> Void)? = nil,
        onTabPressed: (() -> Void)? = nil,
        onShiftTabPressed: (() -> Void)? = nil,
        onZoomScaleChange: ((CGFloat) -> Void)? = nil
    ) {
        self._attributedText = attributedText
        self._selectedRange = selectedRange
        self.textViewCoordinator = textViewCoordinator
        self.project = project
        self.captionNumberOffsets = captionNumberOffsets
        self.headingStyleCounters = headingStyleCounters
        self.headingLastNumberForStyle = headingLastNumberForStyle
        self.showInvisibles = showInvisibles
        self.showLineNumbers = showLineNumbers
        self.font = font
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.textContainerInset = textContainerInset
        self.isEditable = isEditable
        self.inputAccessoryView = inputAccessoryView
        self.onTextChange = onTextChange
        self.onSimpleTypingChange = onSimpleTypingChange
        self.onSelectionChange = onSelectionChange
        self.onImageTapped = onImageTapped
        self.onClearImageSelection = onClearImageSelection
        self.onImageCutRequested = onImageCutRequested
        self.onImagePasteRequested = onImagePasteRequested
        self.onCommentTapped = onCommentTapped
        self.onFootnoteTapped = onFootnoteTapped
        self.onReferenceTapped = onReferenceTapped
        self.onReferenceDeleted = onReferenceDeleted
        self.onCommentDeleted = onCommentDeleted
        self.onFootnoteDeleted = onFootnoteDeleted
        self.onMixedAttachmentsDeleted = onMixedAttachmentsDeleted
        self.onGlossaryAddRequested = onGlossaryAddRequested
        self.onIndexAddRequested = onIndexAddRequested
        self.onTabPressed = onTabPressed
        self.onShiftTabPressed = onShiftTabPressed
        self.onZoomScaleChange = onZoomScaleChange
    }
    
    // MARK: - UIViewRepresentable
    
    func makeUIView(context: Context) -> UITextView {
        // Create text storage, layout manager, and text container
        let textStorage = NSTextStorage()
        let layoutManager = NumberingLayoutManager() // Use custom layout manager for dynamic paragraph numbering
        let textContainer = NSTextContainer()
        
        // Pass project reference to layout manager for style information
        layoutManager.project = project
        layoutManager.initialStyleCounters = headingStyleCounters
        layoutManager.initialLastNumberForStyle = headingLastNumberForStyle
        layoutManager.showInvisibles = showInvisibles
        layoutManager.showDocumentLineNumbers = showLineNumbers
        
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        
        // Create text view with our custom layout manager
        let textView = CustomTextView(frame: .zero, textContainer: textContainer)
        
        // Store reference to textView in coordinator (if provided)
        context.coordinator.textView = textView
        textViewCoordinator?.textView = textView
        textViewCoordinator?.flushPendingTyping = { [weak coordinator = context.coordinator] in
            #if targetEnvironment(macCatalyst)
            coordinator?.flushPendingSimpleTypingChange()
            #endif
        }
        
        // Wire up comment tap callback
        let coordinator = context.coordinator
        textView.onCommentTapped = { [weak coordinator] attachment, position in
            coordinator?.parent.onCommentTapped?(attachment, position)
        }
        
        // Wire up footnote tap callback
        textView.onFootnoteTapped = { [weak coordinator] attachment, position in
            coordinator?.parent.onFootnoteTapped?(attachment, position)
        }
        
        // Wire up reference tap callback (Feature 029)
        textView.onReferenceTapped = { [weak coordinator] attachment, position in
            coordinator?.parent.onReferenceTapped?(attachment, position)
        }

        textView.onImageCutRequested = { [weak coordinator] attachment, position in
            coordinator?.parent.onImageCutRequested?(attachment, position)
        }
        textView.onImagePasteRequested = { [weak coordinator] attachment, position in
            coordinator?.parent.onImagePasteRequested?(attachment, position)
        }
        
        // Wire up glossary/index callbacks only when enabled by the parent.
        // This controls whether actions appear in the native context menu.
        if onGlossaryAddRequested != nil {
            textView.onGlossaryAddRequested = { [weak coordinator] selectedText in
                coordinator?.parent.onGlossaryAddRequested?(selectedText)
            }
        } else {
            textView.onGlossaryAddRequested = nil
        }

        if onIndexAddRequested != nil {
            textView.onIndexAddRequested = { [weak coordinator] selectedText in
                coordinator?.parent.onIndexAddRequested?(selectedText)
            }
        } else {
            textView.onIndexAddRequested = nil
        }
        
        // Wire up Tab/Shift+Tab callbacks for list indent/outdent (Feature 016)
        textView.onTabPressed = { [weak coordinator] in
            coordinator?.parent.onTabPressed?()
        }
        textView.onShiftTabPressed = { [weak coordinator] in
            coordinator?.parent.onShiftTabPressed?()
        }
        
        // Set input accessory view if provided
        if let accessoryView = inputAccessoryView {
            textView.customAccessoryView = accessoryView
        }
        
        // Configure appearance
        // NOTE: Don't set textView.font - it overrides attributed string font attributes!
        // IMPORTANT: Set textColor to .label for adaptive dark/light mode support
        // This ensures text without explicit color adapts to appearance mode
        textView.textColor = .label
        textView.backgroundColor = backgroundColor
        
        // Add extra left inset for paragraph numbering and optional line-number gutter
        var adjustedInset = textContainerInset
        // No extra margin on iPhone - text at left edge like original Writing Shed
        let numberMargin: CGFloat = UIDevice.current.userInterfaceIdiom == .phone ? 0 : 5
        adjustedInset.left += numberMargin
        if showLineNumbers {
            adjustedInset.left += lineNumberGutterWidth
        }
        textView.textContainerInset = adjustedInset
        
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isScrollEnabled = true
        
        configureEditorInputTraits(textView)
        
        // Configure text container for proper layout
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.textContainer.heightTracksTextView = false
        
        // Important: Ensure layoutManager is properly configured
        // Disable non-contiguous layout to ensure accurate tap-to-position
        textView.layoutManager.allowsNonContiguousLayout = false
        
        // Use typographic line fragment padding for better accuracy
        textView.layoutManager.usesFontLeading = true
        
        // Set delegate
        textView.delegate = context.coordinator
        
        // Add tap gesture recognizer for image selection
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.delegate = context.coordinator
        textView.addGestureRecognizer(tapGesture)
        
        // Add pinch gesture recognizer for zoom (with reduced speed)
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        pinchGesture.delegate = context.coordinator
        textView.addGestureRecognizer(pinchGesture)
        
        // Load saved zoom factor from UserDefaults
        // Use the shared editor zoom key with fallback to the legacy key.
        let savedZoom = UserDefaults.standard.double(forKey: "editorZoomScale")
        let legacySavedZoom = UserDefaults.standard.double(forKey: "textViewZoomFactor")
        let effectiveZoom = savedZoom > 0 ? savedZoom : legacySavedZoom
        if effectiveZoom > 0 {
            context.coordinator.currentZoomScale = CGFloat(effectiveZoom)
            textView.transform = CGAffineTransform(scaleX: context.coordinator.currentZoomScale, y: context.coordinator.currentZoomScale)
            context.coordinator.parent.onZoomScaleChange?(context.coordinator.currentZoomScale)
            #if DEBUG
            print("🔍 Loading saved zoom: \(effectiveZoom)")
            #endif
        } else {
            context.coordinator.currentZoomScale = 1.0
            context.coordinator.parent.onZoomScaleChange?(1.0)
        }
        
        // Add pan gesture recognizer for drag scrolling (requires 2 fingers to avoid interfering with text selection)
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.minimumNumberOfTouches = 2
        panGesture.maximumNumberOfTouches = 2
        panGesture.delegate = context.coordinator
        textView.addGestureRecognizer(panGesture)
        
        // Configure for rich text
        // On iPad/Catalyst, disable system editing attributes to prevent the formatting menu
        // and extra text-services work. WSP applies rich text through its own toolbar.
        #if targetEnvironment(macCatalyst)
        textView.allowsEditingTextAttributes = false
        #elseif os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            textView.allowsEditingTextAttributes = false
        } else {
            textView.allowsEditingTextAttributes = true
        }
        #else
        textView.allowsEditingTextAttributes = true
        #endif
        
        // Disable system formatting menu (we have our own toolbar)
        textView.shouldHideSystemFormattingMenu = true
        
        // TODO: Suppress drag handles on images/attachments
        // The drag handles (lollipop handles) appear when tapping on images in iOS
        // Attempted solutions that didn't work:
        // - textView.textDragOptions = [] (iOS 15+) - doesn't suppress handles on attachments
        // Possible future approaches:
        // - Custom UITextView subclass overriding canPerformAction for drag/drop
        // - Disable textView.textDragInteraction or textView.interactions
        // - Custom gesture recognizer to intercept taps on images
        // - Override selectionRectsForRange to hide selection UI on attachments
        // For now, drag handles remain visible but don't interfere with functionality
        
        // Number before assignment so attachment copies have valid values during
        // TextKit's immediate provider layout, then refresh the owned copies.
        ImageAttachment.updateCaptionNumbersInAttributedString(
            attributedText,
            styleSheet: project?.styleSheet,
            startingNumbers: captionNumberOffsets
        )
        textView.attributedText = attributedText
        ImageAttachment.updateCaptionNumbers(
            in: textView.textStorage,
            styleSheet: project?.styleSheet,
            startingNumbers: captionNumberOffsets
        )
        context.coordinator.lastObservedAttributedText = attributedText
        
        // Initialize previousTextLength for paste detection
        context.coordinator.previousTextLength = attributedText.length
        
        // Set typing attributes to match the content
        // This ensures that when typing in an empty document or at the end,
        // the correct font is used
        if attributedText.length > 0 {
            // Get attributes from the start of the text
            var attrs = attributedText.attributes(at: 0, effectiveRange: nil)
            
            #if DEBUG
            print("🎨 Setting typing attributes from position 0")
            if let color = attrs[.foregroundColor] as? UIColor {
                print("   Original color: \(color.toHex() ?? "unknown")")
            } else {
                print("   Original color: NONE")
            }
            #endif
            
            // CRITICAL: Remove foregroundColor if it's an adaptive color (black/white)
            // This allows text to adapt to light/dark mode automatically
            if let color = attrs[.foregroundColor] as? UIColor {
                if AttributedStringSerializer.isAdaptiveSystemColor(color) || 
                   AttributedStringSerializer.isFixedBlackOrWhite(color) {
                    attrs.removeValue(forKey: .foregroundColor)
                    #if DEBUG
                    print("   🧹 Removed adaptive color from typing attributes")
                    #endif
                }
            }
            
            #if DEBUG
            if let color = attrs[.foregroundColor] as? UIColor {
                print("   Final color after filter: \(color.toHex() ?? "unknown")")
            } else {
                print("   Final color after filter: NONE (will use system default)")
            }
            #endif
            
            textView.typingAttributes = attrs
        } else {
            // Empty document - use attributes from attributed string if available
            // This preserves style information even in empty documents
            var attrs: [NSAttributedString.Key: Any] = [:]
            attributedText.enumerateAttributes(in: NSRange(location: 0, length: 0), options: []) { attributes, _, _ in
                attrs = attributes
            }
            
            // CRITICAL: Remove foregroundColor if it's an adaptive color
            if let color = attrs[.foregroundColor] as? UIColor {
                if AttributedStringSerializer.isAdaptiveSystemColor(color) || 
                   AttributedStringSerializer.isFixedBlackOrWhite(color) {
                    attrs.removeValue(forKey: .foregroundColor)
                    #if DEBUG
                    print("🎨 Removed adaptive color from empty doc typing attributes")
                    #endif
                }
            }
            
            if !attrs.isEmpty {
                textView.typingAttributes = attrs
            } else {
                // Final fallback - use body font
                textView.typingAttributes = [.font: font]
            }
        }
        
        // Force layout before setting selection
        textView.layoutManager.ensureLayout(for: textView.textContainer)
        ImageAttachment.refreshCaptionNumberProviders(in: textView.textStorage, styleSheet: project?.styleSheet)
        
        // Set initial selection
        if selectedRange.location != NSNotFound && selectedRange.location <= attributedText.length {
            textView.selectedRange = selectedRange
        }
        
        // Handle keyboard notifications
        setupKeyboardNotifications(for: textView, coordinator: context.coordinator)
        
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        // CRITICAL: Update the coordinator's parent reference to ensure callbacks work
        // The FormattedTextEditor struct is recreated on each SwiftUI update with new callbacks
        context.coordinator.parent = self
        
        // Also update the CustomTextView's callbacks to use the current parent
        if let customTextView = textView as? CustomTextView {
            let coordinator = context.coordinator
            customTextView.onTabPressed = { [weak coordinator] in
                coordinator?.parent.onTabPressed?()
            }
            customTextView.onShiftTabPressed = { [weak coordinator] in
                coordinator?.parent.onShiftTabPressed?()
            }

            if onGlossaryAddRequested != nil {
                customTextView.onGlossaryAddRequested = { [weak coordinator] selectedText in
                    coordinator?.parent.onGlossaryAddRequested?(selectedText)
                }
            } else {
                customTextView.onGlossaryAddRequested = nil
            }

            if onIndexAddRequested != nil {
                customTextView.onIndexAddRequested = { [weak coordinator] selectedText in
                    coordinator?.parent.onIndexAddRequested?(selectedText)
                }
            } else {
                customTextView.onIndexAddRequested = nil
            }
        }
        
          // Update numbering state and decorative flags when manuscript order or preceding content changes.
          if let layoutManager = textView.layoutManager as? NumberingLayoutManager,
              (layoutManager.initialStyleCounters != headingStyleCounters
                || layoutManager.initialLastNumberForStyle != headingLastNumberForStyle
                || layoutManager.showInvisibles != showInvisibles
                || layoutManager.showDocumentLineNumbers != showLineNumbers) {
                layoutManager.initialStyleCounters = headingStyleCounters
                layoutManager.initialLastNumberForStyle = headingLastNumberForStyle
            layoutManager.showInvisibles = showInvisibles
            layoutManager.showDocumentLineNumbers = showLineNumbers
            layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: textView.textStorage.length))
        }
        
        // Skip if we're already in the middle of an update to prevent feedback loops
        guard !context.coordinator.isUpdatingFromSwiftUI else {
            return
        }
        
        // Check if attributed text actually changed (either content OR formatting)
        // We need to update if either the string OR the attributes changed
        guard let textViewAttrs = textView.attributedText else {
            // If textView has no attributed text, we definitely need to update
            context.coordinator.isUpdatingFromSwiftUI = true
            defer {
                context.coordinator.isUpdatingFromSwiftUI = false
            }
            ImageAttachment.updateCaptionNumbersInAttributedString(
                attributedText,
                styleSheet: project?.styleSheet,
                startingNumbers: captionNumberOffsets
            )
            textView.attributedText = attributedText
            ImageAttachment.updateCaptionNumbers(
                in: textView.textStorage,
                styleSheet: project?.styleSheet,
                startingNumbers: captionNumberOffsets
            )
            return
        }
        
        let bindingObjectChanged = attributedText !== context.coordinator.lastObservedAttributedText
        context.coordinator.lastObservedAttributedText = attributedText

        let textViewString = textViewAttrs.string
        let newString = attributedText.string
        let stringsMatch = textViewString == newString
        let shouldCheckAttachments = !stringsMatch || !context.coordinator.isProcessingUserTextChange
        let attachmentsMatch = shouldCheckAttachments
            ? FormattedTextEditorAttachmentComparison.attachmentsMatch(textViewAttrs, attributedText, includeLocation: stringsMatch)
            : true
        let hasAttachmentChange = !attachmentsMatch
        let hasAttributeChange = FormattedTextEditorContentComparison.hasExternalAttributeChange(
            current: textViewAttrs,
            incoming: attributedText,
            bindingObjectChanged: bindingObjectChanged,
            isProcessingUserTextChange: context.coordinator.isProcessingUserTextChange
        )

        if !stringsMatch, textView.isFirstResponder, !hasAttachmentChange {
            return
        }

        if !stringsMatch,
           !hasAttachmentChange,
           let lastUserTextChangeTime = context.coordinator.lastUserTextChangeTime,
           Date().timeIntervalSince(lastUserTextChangeTime) < Coordinator.simpleTypingIdleDelay {
            return
        }
        #if DEBUG
        if shouldCheckAttachments && (!attachmentsMatch || textViewAttrs.footnoteAttachments().count != attributedText.footnoteAttachments().count) {
            print("🧪 [FootnoteDiag] updateUIView compare stringsMatch=\(stringsMatch) attachmentsMatch=\(attachmentsMatch) textView=\(footnoteDebugSummary(textViewAttrs)) binding=\(footnoteDebugSummary(attributedText))")
        }
        #endif
        
        // Compare all attributes only when SwiftUI supplies a different attributed-string object.
        // This keeps routine view updates cheap while still rendering external formatting changes
        // such as paragraph spacing, alignment, font, and colour.
        if !stringsMatch || !attachmentsMatch || hasAttributeChange {
            // Text content changed - need to update
            // Set flag to prevent feedback from delegate
            context.coordinator.isUpdatingFromSwiftUI = true
            
            let oldSelectedRange = textView.selectedRange
            
            // CRITICAL: Preserve search highlights before updating
            // The search manager applies background colors and underlines that we don't want to lose
            struct SearchHighlight {
                let range: NSRange
                let backgroundColor: UIColor?
                let underlineStyle: Int?
                let underlineColor: UIColor?
            }
            
            var searchHighlights: [SearchHighlight] = []
            if textView.textStorage.length > 0 {
                let fullRange = NSRange(location: 0, length: textView.textStorage.length)
                
                // Enumerate all background colors (search highlights)
                textView.textStorage.enumerateAttribute(.backgroundColor, in: fullRange, options: []) { value, range, _ in
                    if let bgColor = value as? UIColor {
                        // Get associated underline attributes if they exist
                        let underlineStyle = textView.textStorage.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int
                        let underlineColor = textView.textStorage.attribute(.underlineColor, at: range.location, effectiveRange: nil) as? UIColor
                        
                        searchHighlights.append(SearchHighlight(
                            range: range,
                            backgroundColor: bgColor,
                            underlineStyle: underlineStyle,
                            underlineColor: underlineColor
                        ))
                    }
                }
                #if DEBUG
                if !searchHighlights.isEmpty {
                    print("📝 Preserved \(searchHighlights.count) search highlight ranges")
                }
                #endif
            }
            
            ImageAttachment.updateCaptionNumbersInAttributedString(
                attributedText,
                styleSheet: project?.styleSheet,
                startingNumbers: captionNumberOffsets
            )

            // Update text storage directly for better control
            // This ensures attributes are properly applied
            textView.textStorage.setAttributedString(attributedText)
            
            // Update previousTextLength after programmatic updates to avoid false paste detection
            context.coordinator.previousTextLength = attributedText.length
            
            // Update caption numbers for image attachments (Feature 016)
            // This must be done after setting the attributed string
            ImageAttachment.updateCaptionNumbers(
                in: textView.textStorage,
                styleSheet: project?.styleSheet,
                startingNumbers: captionNumberOffsets
            )
            
            // CRITICAL: Restore search highlights after updating attributes
            if !searchHighlights.isEmpty {
                for highlight in searchHighlights {
                    // Validate range is still valid after update
                    if highlight.range.location + highlight.range.length <= textView.textStorage.length {
                        if let bgColor = highlight.backgroundColor {
                            textView.textStorage.addAttribute(.backgroundColor, value: bgColor, range: highlight.range)
                        }
                        if let underlineStyle = highlight.underlineStyle {
                            textView.textStorage.addAttribute(.underlineStyle, value: underlineStyle, range: highlight.range)
                        }
                        if let underlineColor = highlight.underlineColor {
                            textView.textStorage.addAttribute(.underlineColor, value: underlineColor, range: highlight.range)
                        }
                    }
                }
                #if DEBUG
                print("📝 Restored \(searchHighlights.count) search highlight ranges")
                #endif
            }
            
            // Critical: Tell text storage that attributes changed
            textView.textStorage.edited(.editedAttributes, range: NSRange(location: 0, length: textView.textStorage.length), changeInLength: 0)
            
            // Invalidate layout and display FIRST
            let fullRange = NSRange(location: 0, length: textView.textStorage.length)
            textView.layoutManager.invalidateLayout(forCharacterRange: fullRange, actualCharacterRange: nil)
            textView.layoutManager.invalidateDisplay(forCharacterRange: fullRange)
            
            // THEN force layout update - this makes UITextView recalculate paragraph layout
            textView.layoutManager.ensureLayout(for: textView.textContainer)
            ImageAttachment.refreshCaptionNumberProviders(in: textView.textStorage, styleSheet: project?.styleSheet)
            
            // Force the text view itself to update its display
            textView.setNeedsDisplay()
            textView.setNeedsLayout()
            textView.layoutIfNeeded()
            
            // Restore selection if it's still valid
            if oldSelectedRange.location <= attributedText.length {
                textView.selectedRange = oldSelectedRange
            } else {
                // If selection is invalid, move to end
                textView.selectedRange = NSRange(location: attributedText.length, length: 0)
            }
            
            // CRITICAL: Update typing attributes to match the formatting at the cursor
            // Without this, UITextView reverts to default color (labelColor) for new text
            if textView.selectedRange.location > 0 && textView.selectedRange.location <= textView.textStorage.length {
                // Get attributes from character before cursor (where we'll continue typing)
                var attrs = textView.textStorage.attributes(at: textView.selectedRange.location - 1, effectiveRange: nil)
                
                // CRITICAL: Remove adaptive colors from typing attributes
                if let color = attrs[.foregroundColor] as? UIColor {
                    if AttributedStringSerializer.isAdaptiveSystemColor(color) || 
                       AttributedStringSerializer.isFixedBlackOrWhite(color) {
                        attrs.removeValue(forKey: .foregroundColor)
                    }
                }
                
                textView.typingAttributes = attrs
            } else if textView.textStorage.length > 0 {
                // At start of document, use attributes from first character
                var attrs = textView.textStorage.attributes(at: 0, effectiveRange: nil)
                
                // CRITICAL: Remove adaptive colors from typing attributes
                if let color = attrs[.foregroundColor] as? UIColor {
                    if AttributedStringSerializer.isAdaptiveSystemColor(color) || 
                       AttributedStringSerializer.isFixedBlackOrWhite(color) {
                        attrs.removeValue(forKey: .foregroundColor)
                    }
                }
                
                textView.typingAttributes = attrs
            }
            
            // If there's a selected image, recalculate its frame and update the border
            if let customTextView = textView as? CustomTextView,
               customTextView.isImageSelected,
               textView.selectedRange.length == 1,
               textView.selectedRange.location < textView.textStorage.length,
               let attachment = textView.textStorage.attribute(.attachment, at: textView.selectedRange.location, effectiveRange: nil) as? ImageAttachment {
                
                // Recalculate the image frame with the new scale
                let glyphRange = textView.layoutManager.glyphRange(forCharacterRange: textView.selectedRange, actualCharacterRange: nil)
                let glyphBounds = textView.layoutManager.boundingRect(forGlyphRange: glyphRange, in: textView.textContainer)
                let availableWidth = ImageAttachment.availableWidth(for: textView.textContainer)
                let imageSize = attachment.displaySize(forAvailableWidth: availableWidth)
                
                let adjustedBounds = CGRect(
                    x: glyphBounds.origin.x + textView.textContainerInset.left,
                    y: glyphBounds.origin.y + textView.textContainerInset.top,
                    width: imageSize.width,
                    height: imageSize.height
                )
                
                // Update the selection border with the new frame (visual only, don't trigger state changes)
                customTextView.showSelectionBorder(at: adjustedBounds)
            }
            
            // Reset flag after a short delay to allow delegate callbacks to settle
            DispatchQueue.main.async {
                context.coordinator.isUpdatingFromSwiftUI = false
            }
            
            // Also update selection when content changed (e.g., after undo/redo).
            // During live typing, UIKit owns the caret; applying the SwiftUI binding can
            // briefly restore an older range and make the caret appear to lag behind text.
            if !context.coordinator.isLiveTypingSimpleInsertion,
               textView.selectedRange != selectedRange && selectedRange.location != NSNotFound {
                if selectedRange.location <= textView.attributedText.length {
                    textView.selectedRange = selectedRange
                }
            }
        } // End of if !stringsMatch || !attachmentsMatch
        
        // Update appearance properties (always, regardless of content changes)
        // NOTE: Don't set textView.textColor - it overrides attributed string colors!
        // Colors should come from the attributed string's .foregroundColor attribute
        textView.backgroundColor = backgroundColor
        
        // Add extra left inset for paragraph numbering and optional line-number gutter
        var adjustedInset = textContainerInset
        // No extra margin on iPhone - text at left edge like original Writing Shed
        let numberMargin: CGFloat = UIDevice.current.userInterfaceIdiom == .phone ? 0 : 5
        adjustedInset.left += numberMargin
        if showLineNumbers {
            adjustedInset.left += lineNumberGutterWidth
        }
        textView.textContainerInset = adjustedInset
        
        textView.isEditable = isEditable
        
        configureEditorInputTraits(textView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Private Methods

    private func configureEditorInputTraits(_ textView: UITextView) {
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no
        textView.textContentType = nil
        #if targetEnvironment(macCatalyst)
        textView.textContentType = UITextContentType(rawValue: "")
        if #available(iOS 18.0, *) {
            textView.writingToolsBehavior = .none
        }
        #endif
        textView.dataDetectorTypes = []
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.smartInsertDeleteType = .no
        textView.autocapitalizationType = (project?.type == .poetry) ? .none : .sentences
        textView.inputAssistantItem.leadingBarButtonGroups = []
        textView.inputAssistantItem.trailingBarButtonGroups = []

        if #available(iOS 17.0, *) {
            textView.inlinePredictionType = .no
        }
    }

    #if DEBUG
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
    
    private func setupKeyboardNotifications(for textView: UITextView, coordinator: Coordinator) {
        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(Coordinator.keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(Coordinator.keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(Coordinator.flushPendingTypingNotification(_:)),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: LegacyFormattedTextEditor
        var isUpdatingFromSwiftUI = false
        weak var textView: UITextView?
        var lastObservedAttributedText: NSAttributedString?
        var previousSelection: NSRange = NSRange(location: 0, length: 0)
        var previousTextLength: Int = 0  // Track text length to detect paste operations
        var currentZoomScale: CGFloat = 1.0
        var isProcessingUserTextChange = false
        var pendingChangeRange: NSRange?
        var pendingReplacementText: String?
        var pendingInsertionAttributes: [NSAttributedString.Key: Any]?
        var lastUserTextChangeTime: Date?
        var isLiveTypingSimpleInsertion = false
        fileprivate static let simpleTypingIdleDelay: TimeInterval = 1.5
        private var pendingSimpleTypingSelectionWorkItem: DispatchWorkItem?
        #if targetEnvironment(macCatalyst)
        private var pendingSimpleTypingRange: NSRange?
        private var pendingSimpleTypingText = ""
        private var pendingSimpleTypingSelection = NSRange(location: 0, length: 0)
        private var pendingSimpleTypingWorkItem: DispatchWorkItem?
        #endif

        private func bodyStyleAttributesFallback() -> [NSAttributedString.Key: Any] {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .natural
            paragraphStyle.lineHeightMultiple = 1.0

            return [
                .font: parent.font,
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraphStyle,
                .textStyle: UIFont.TextStyle.body.rawValue
            ]
        }

        private func resolvedBodyStyleAttributes() -> [NSAttributedString.Key: Any] {
            if let style = parent.project?.styleSheet?.style(named: UIFont.TextStyle.body.rawValue) {
                return style.generateAttributes()
            }
            return bodyStyleAttributesFallback()
        }

        private func insertionAttributes(in textView: UITextView, replacing range: NSRange) -> [NSAttributedString.Key: Any] {
            let sourceAttributes = FormattedTextEditorInsertionAttributes.sourceAttributes(
                in: textView.textStorage,
                typingAttributes: textView.typingAttributes,
                replacing: range
            )

            let styleName = (sourceAttributes[.textStyle] as? String)
                ?? (textView.typingAttributes[.textStyle] as? String)
                ?? UIFont.TextStyle.body.rawValue
            let styleAttributes = parent.project?.styleSheet?.style(named: styleName)?.generateAttributes()
                ?? resolvedBodyStyleAttributes()

            return FormattedTextEditorInsertionAttributes.merge(
                styleAttributes: styleAttributes,
                replacedAttributes: sourceAttributes
            )
        }

        private func normalizePendingInsertion(in textView: UITextView) {
            defer { pendingInsertionAttributes = nil }
            guard let attributes = pendingInsertionAttributes,
                  let range = pendingChangeRange,
                  let replacementText = pendingReplacementText,
                  !replacementText.isEmpty else {
                return
            }

            let replacementLength = (replacementText as NSString).length
            guard replacementLength > 0,
                  range.location >= 0,
                  range.location + replacementLength <= textView.textStorage.length else {
                return
            }

            textView.textStorage.addAttributes(
                attributes,
                range: NSRange(location: range.location, length: replacementLength)
            )
            textView.typingAttributes = attributes
        }

        private func refreshLineNumberDisplay(in textView: UITextView, from location: Int) {
            let textLength = textView.textStorage.length
            let invalidateStart = min(max(0, location), textLength)
            let invalidateLength = textLength - invalidateStart
            let invalidateRange = NSRange(location: invalidateStart, length: invalidateLength)

            if invalidateRange.length > 0 {
                textView.layoutManager.invalidateLayout(forCharacterRange: invalidateRange, actualCharacterRange: nil)
                textView.layoutManager.invalidateDisplay(forCharacterRange: invalidateRange)
            }
            textView.layoutManager.ensureLayout(for: textView.textContainer)
            textView.setNeedsDisplay()
        }
        
        init(_ parent: LegacyFormattedTextEditor) {
            self.parent = parent
        }
        
        deinit {
            #if targetEnvironment(macCatalyst)
            pendingSimpleTypingWorkItem?.cancel()
            #endif
            NotificationCenter.default.removeObserver(self)
        }

        private func isSimpleCharacterInsertion(range: NSRange?, replacementText: String?) -> Bool {
            guard let range,
                  range.length == 0,
                  let replacementText,
                  !replacementText.isEmpty,
                  replacementText.rangeOfCharacter(from: .newlines) == nil else {
                return false
            }

            return (replacementText as NSString).length == 1
        }

        private func emitSimpleTypingChange(from textView: UITextView, range: NSRange, replacementText: String) {
            #if targetEnvironment(macCatalyst)
            lastUserTextChangeTime = Date()
            WriteCoalescer.shared?.noteEditingActivity()
            appendPendingSimpleTypingChange(range: range, replacementText: replacementText, selection: textView.selectedRange)
            #else
            guard let attributedText = textView.attributedText else { return }
            isProcessingUserTextChange = true
            lastUserTextChangeTime = Date()
            parent.onTextChange?(TextEditorChange(
                attributedText: attributedText,
                range: range,
                replacementText: replacementText
            ))
            scheduleSimpleTypingSelectionSync(textView.selectedRange)
            DispatchQueue.main.async { [weak self] in
                self?.isProcessingUserTextChange = false
            }
            #endif
        }

        private func scheduleSimpleTypingSelectionSync(_ selection: NSRange) {
            pendingSimpleTypingSelectionWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.parent.selectedRange = selection
                self.parent.onSelectionChange?(selection)
            }
            pendingSimpleTypingSelectionWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.simpleTypingIdleDelay, execute: workItem)
        }

        #if targetEnvironment(macCatalyst)
        private func appendPendingSimpleTypingChange(range: NSRange, replacementText: String, selection: NSRange) {
            if let pendingRange = pendingSimpleTypingRange,
               pendingRange.location + (pendingSimpleTypingText as NSString).length == range.location {
                pendingSimpleTypingText += replacementText
            } else {
                flushPendingSimpleTypingChange()
                pendingSimpleTypingRange = range
                pendingSimpleTypingText = replacementText
            }

            pendingSimpleTypingSelection = selection
            pendingSimpleTypingWorkItem?.cancel()

            let workItem = DispatchWorkItem { [weak self] in
                self?.flushPendingSimpleTypingChange()
            }
            pendingSimpleTypingWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.simpleTypingIdleDelay, execute: workItem)
        }

        func flushPendingSimpleTypingChange() {
            guard let range = pendingSimpleTypingRange,
                  !pendingSimpleTypingText.isEmpty else { return }

            let replacementText = pendingSimpleTypingText
            let selection = pendingSimpleTypingSelection
            pendingSimpleTypingRange = nil
            pendingSimpleTypingText = ""
            pendingSimpleTypingWorkItem?.cancel()
            pendingSimpleTypingWorkItem = nil

            isProcessingUserTextChange = true
            if let onSimpleTypingChange = parent.onSimpleTypingChange {
                onSimpleTypingChange(range, replacementText, selection)
            } else if let textView,
                      let attributedText = textView.attributedText {
                parent.onTextChange?(TextEditorChange(
                    attributedText: attributedText,
                    range: range,
                    replacementText: replacementText
                ))
            }
            pendingSimpleTypingSelectionWorkItem?.cancel()
            parent.selectedRange = selection
            parent.onSelectionChange?(selection)

            DispatchQueue.main.async { [weak self] in
                self?.isProcessingUserTextChange = false
            }
        }
        #endif
        
        // MARK: - UITextViewDelegate
        
        // Intercept text changes to handle Enter key and ensure correct styling
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            pendingChangeRange = range
            pendingReplacementText = text
            pendingInsertionAttributes = !text.isEmpty && text.rangeOfCharacter(from: .newlines) == nil
                ? insertionAttributes(in: textView, replacing: range)
                : nil
            isLiveTypingSimpleInsertion = isSimpleCharacterInsertion(range: range, replacementText: text)

            if text.isEmpty,
               let attachment = FormattedTextEditorImageClipboard.selectedAttachment(
                   in: textView.attributedText,
                   range: range
               ) {
                pendingChangeRange = nil
                pendingReplacementText = nil
                isLiveTypingSimpleInsertion = false
                parent.onImageCutRequested?(attachment, range.location)
                return false
            }

            #if targetEnvironment(macCatalyst)
            if isLiveTypingSimpleInsertion {
                lastUserTextChangeTime = Date()
            }
            #endif

            #if DEBUG
            if text.isEmpty && range.length > 0 {
                print("📝 shouldChangeTextIn: deletion detected (range: \(range), text: '\(text)' - empty: \(text.isEmpty))")
            }
            #endif
            
            // Check if user pressed Enter (newline character)
            if text == "\n" {
                
                // Get the attributes at the current position
                if range.location > 0, let attrText = textView.attributedText {
                    var attrs = attrText.attributes(at: range.location > 0 ? range.location - 1 : 0, effectiveRange: nil)

                    // Images use a synthetic newline/ZWS boundary for caret navigation, so the
                    // character immediately before the caret is not always the attachment itself.
                    let isAfterImage = FormattedTextEditorImageBoundary.isImmediatelyAfterImage(
                        in: attrText,
                        location: range.location
                    )
                    if isAfterImage {
                        let bodyAttributes = resolvedBodyStyleAttributes()
                        let insertion = FormattedTextEditorImageBoundary.bodyParagraphInsertion(
                            currentAttributes: attrs,
                            bodyAttributes: bodyAttributes
                        )
                        textView.textStorage.replaceCharacters(in: range, with: insertion)

                        let newCursorPosition = range.location + insertion.length
                        textView.selectedRange = NSRange(location: newCursorPosition, length: 0)
                        textView.typingAttributes = bodyAttributes
                        refreshLineNumberDisplay(in: textView, from: range.location - 1)

                        pendingChangeRange = range
                        pendingReplacementText = "\n\u{200B}"
                        self.textViewDidChange(textView)
                        return false
                    }

                    var useFollowOnStyle = false
                    
                    if let styleName = attrs[.textStyle] as? String {
                        
                        // Check if current style has a follow-on style defined
                        if let project = parent.project,
                           let styleSheet = project.styleSheet,
                           let currentStyle = styleSheet.textStyles?.first(where: { $0.name == styleName }),
                           let followOnStyleName = currentStyle.followOnStyleName,
                           !followOnStyleName.isEmpty,
                           let followOnStyle = styleSheet.textStyles?.first(where: { $0.name == followOnStyleName }) {
                            
                            // Generate new attributes from the follow-on style
                            attrs = followOnStyle.generateAttributes()
                            useFollowOnStyle = true
                        }

                        // First-paragraph styles are one-shot styles.
                        // If the current style is flagged as the first paragraph style
                        // and it does not define a follow-on style, the next paragraph
                        // should revert to Body rather than inheriting the heading style.
                        if !useFollowOnStyle,
                           let project = parent.project,
                           let styleSheet = project.styleSheet,
                           let currentStyle = styleSheet.textStyles?.first(where: { $0.name == styleName }),
                           currentStyle.isFirstParagraphStyle {
                            attrs = resolvedBodyStyleAttributes()
                        }
                    }
                    
                    // If we have a follow-on style, manually insert the newline with correct attributes
                    if useFollowOnStyle {
                        // Insert newline with CURRENT style (end of current paragraph)
                        let currentAttrs = attrText.attributes(at: range.location > 0 ? range.location - 1 : 0, effectiveRange: nil)
                        
                        let paragraphBreak = FormattedTextEditorParagraphBreak.attributedString(
                            currentParagraphAttributes: currentAttrs,
                            newParagraphAttributes: attrs
                        )
                        
                        // Insert at the specified range
                        textView.textStorage.replaceCharacters(in: range, with: paragraphBreak)
                        
                        // Move cursor to after the zero-width space (so user types after it)
                        let newCursorPosition = range.location + 2
                        textView.selectedRange = NSRange(location: newCursorPosition, length: 0)
                        
                        // Set typingAttributes to follow-on style for continued typing
                        textView.typingAttributes = attrs
                        
                        refreshLineNumberDisplay(in: textView, from: range.location - 1)
                        
                        // Notify delegate of text change manually since we handled it
                        pendingChangeRange = range
                        pendingReplacementText = "\n\u{200B}"
                        self.textViewDidChange(textView)
                        
                        // Return false - we handled the insertion ourselves
                        return false
                    }
                    
                    // For list/numbered styles (no follow-on), manually insert newline + ZWS
                    // to ensure the new paragraph has a glyph so NumberingLayoutManager's
                    // drawBackground clip rect extends to it (prevents number clipping)
                    if let styleName = attrs[.textStyle] as? String,
                       let project = parent.project,
                       let styleSheet = project.styleSheet,
                       let currentStyle = styleSheet.textStyles?.first(where: { $0.name == styleName }),
                       currentStyle.numberFormat != .none {
                        
                        // Insert newline with CURRENT style + ZWS with same style
                        let currentAttrs = attrText.attributes(at: range.location > 0 ? range.location - 1 : 0, effectiveRange: nil)
                        
                        let paragraphBreak = FormattedTextEditorParagraphBreak.attributedString(
                            currentParagraphAttributes: currentAttrs,
                            newParagraphAttributes: attrs
                        )
                        
                        textView.textStorage.replaceCharacters(in: range, with: paragraphBreak)
                        
                        let newCursorPosition = range.location + 2
                        textView.selectedRange = NSRange(location: newCursorPosition, length: 0)
                        textView.typingAttributes = attrs
                        
                        refreshLineNumberDisplay(in: textView, from: range.location - 1)
                        
                        pendingChangeRange = range
                        pendingReplacementText = "\n\u{200B}"
                        self.textViewDidChange(textView)
                        return false
                    }
                    
                    // Anchor the new paragraph independently so typing cannot inherit the
                    // physical font or semantic style of an existing following paragraph.
                    let paragraphBreak = FormattedTextEditorParagraphBreak.attributedString(
                        currentParagraphAttributes: attrs,
                        newParagraphAttributes: attrs
                    )
                    textView.textStorage.replaceCharacters(in: range, with: paragraphBreak)
                    
                    let newCursorPosition = range.location + 2
                    textView.selectedRange = NSRange(location: newCursorPosition, length: 0)
                    textView.typingAttributes = attrs
                    
                    refreshLineNumberDisplay(in: textView, from: range.location - 1)
                    
                    pendingChangeRange = range
                    pendingReplacementText = "\n\u{200B}"
                    self.textViewDidChange(textView)
                    return false
                }
            }
            
            // Handle backspace at start of empty paragraph (only zero-width space after newline)
            // When user backspaces, delete both the zero-width space AND the newline in one action
            if text.isEmpty && range.length == 1 {
                if let attrText = textView.attributedText, range.location < attrText.length {
                    // Use NSString for UTF-16 safe character access (NSRange uses UTF-16 offsets)
                    let nsString = attrText.string as NSString
                    
                    // Safety check for bounds
                    guard range.location < nsString.length else {
                        #if DEBUG
                        print("⚠️ shouldChangeTextIn: range.location \(range.location) >= nsString.length \(nsString.length)")
                        #endif
                        return true
                    }
                    
                    let charToDelete = nsString.character(at: range.location)
                    
                    // Check if we're deleting a zero-width space (U+200B = 0x200B)
                    if charToDelete == 0x200B {
                        // Check if there's a newline before it
                        if range.location > 0 {
                            let prevChar = nsString.character(at: range.location - 1)
                            
                            // Check for newline (0x0A = line feed)
                            if prevChar == 0x0A {
                                // Check if this is the only content on the line (just zero-width space)
                                // Find the next newline or end of string
                                let afterZWSLocation = range.location + 1
                                let isEndOfLine = afterZWSLocation >= nsString.length || nsString.character(at: afterZWSLocation) == 0x0A
                                
                                if isEndOfLine {
                                    // Delete both the newline and zero-width space
                                    let extendedRange = NSRange(location: range.location - 1, length: 2)
                                    textView.textStorage.replaceCharacters(in: extendedRange, with: "")
                                    
                                    // Move cursor to end of previous line
                                    textView.selectedRange = NSRange(location: range.location - 1, length: 0)
                                    
                                    // Notify delegate of text change
                                    pendingChangeRange = extendedRange
                                    pendingReplacementText = ""
                                    self.textViewDidChange(textView)
                                    
                                    refreshLineNumberDisplay(in: textView, from: range.location - 1)
                                    
                                    return false // We handled the deletion
                                }
                            }
                        }
                    }
                }
            }
            
            // FEATURE 029: Detect when references, comments, or footnotes are being deleted
            // When replacementText is empty and we're deleting characters, check for any markers in the deletion range
            if text.isEmpty && range.length > 0 {
                #if DEBUG
                print("📝🗑️ Text deletion detected: deleting \(range.length) chars at position \(range.location)")
                #endif
                
                    if let attrText = textView.attributedText {
                        // Find all attachments in the range being deleted
                        let referenceDeletionRange = attrText.deletionRangeIncludingReferences(range)
                        var referencesToDelete: [ReferenceAttachment] = []
                        var commentsToDelete: [CommentAttachment] = []
                        var footnotesToDelete: [FootnoteAttachment] = []
                        var seenAttachments = Set<ObjectIdentifier>()
                        var seenReferenceMarkers = Set<String>()
                        
                        attrText.enumerateAttribute(.attachment, in: range, options: []) { value, markerRange, _ in
                            // Check for ReferenceAttachment (notes, glossary, references)
                            if let attachment = value as? ReferenceAttachment {
                                let identifier = ObjectIdentifier(attachment)
                                guard !seenAttachments.contains(identifier) else { return }
                                seenAttachments.insert(identifier)
                                seenReferenceMarkers.insert("\(attachment.referenceType.rawValue):\(attachment.entryID.uuidString):\(markerRange.location):\(markerRange.length)")
                                referencesToDelete.append(attachment)
                                #if DEBUG
                                print("🗑️ 📌 Found ReferenceAttachment in deletion range: \(attachment.displayText) (type: \(attachment.referenceType), id: \(attachment.entryID.uuidString.prefix(8)))")
                                #endif
                            }
                            // Check for CommentAttachment
                            else if let attachment = value as? CommentAttachment {
                                let identifier = ObjectIdentifier(attachment)
                                guard !seenAttachments.contains(identifier) else { return }
                                seenAttachments.insert(identifier)
                                commentsToDelete.append(attachment)
                                #if DEBUG
                                print("🗑️ 💬 Found CommentAttachment in deletion range: commentID=\(attachment.commentID.uuidString.prefix(8))")
                                #endif
                            }
                            // Check for FootnoteAttachment
                            else if let attachment = value as? FootnoteAttachment {
                                let identifier = ObjectIdentifier(attachment)
                                guard !seenAttachments.contains(identifier) else { return }
                                seenAttachments.insert(identifier)
                                footnotesToDelete.append(attachment)
                                #if DEBUG
                                print("🗑️ 📝 Found FootnoteAttachment in deletion range: footnoteID=\(attachment.footnoteID.uuidString.prefix(8))")
                                #endif
                            }
                        }

                        // Inline reference markers are stored as attributed text rather than
                        // NSTextAttachment instances. Include them in the same confirmation flow.
                        for marker in attrText.references(in: range) {
                            let markerKey = "\(marker.type.rawValue):\(marker.entryID.uuidString):\(marker.range.location):\(marker.range.length)"
                            guard !seenReferenceMarkers.contains(markerKey) else { continue }

                            let attachment = ReferenceAttachment(
                                referenceType: marker.type,
                                entryID: marker.entryID,
                                displayText: marker.markerText
                            )
                            attachment.isPrimaryReference = marker.isPrimary
                            seenReferenceMarkers.insert(markerKey)
                            referencesToDelete.append(attachment)
                        }

                        // Count how many different types of attachments are being deleted
                        let typesFound = [!referencesToDelete.isEmpty, !commentsToDelete.isEmpty, !footnotesToDelete.isEmpty].filter { $0 }.count
                        
                        // If multiple types are found, use unified callback
                        if typesFound > 1 {
                            #if DEBUG
                            print("🗑️ Mixed attachments found: \(referencesToDelete.count) references, \(commentsToDelete.count) comments, \(footnotesToDelete.count) footnotes - using unified handler")
                            #endif
                            
                            pendingChangeRange = nil
                            pendingReplacementText = nil
                            parent.onMixedAttachmentsDeleted?(referencesToDelete, commentsToDelete, footnotesToDelete, referenceDeletionRange)
                            return false
                        }
                        
                        // Handle references being deleted (single type)
                        if !referencesToDelete.isEmpty {
                            #if DEBUG
                            print("🗑️ \(referencesToDelete.count) references found in deletion range - showing confirmation")
                            #endif
                           
                            // Prevent the deletion for now - we'll handle it after user confirms
                            pendingChangeRange = nil
                            pendingReplacementText = nil
                            parent.onReferenceDeleted?(referencesToDelete, referenceDeletionRange)
                           
                            // Return false to prevent UITextView from deleting the text
                            // We'll manually delete after the user confirms in the alert
                            return false
                        }
                        
                        // Handle comments being deleted (single type)
                        if !commentsToDelete.isEmpty {
                            #if DEBUG
                            print("🗑️ \(commentsToDelete.count) comments found in deletion range - showing confirmation")
                            #endif
                           
                            // Prevent the deletion for now - we'll handle it after user confirms
                            pendingChangeRange = nil
                            pendingReplacementText = nil
                            parent.onCommentDeleted?(commentsToDelete, range)
                           
                            // Return false to prevent UITextView from deleting the text
                            return false
                        }
                        
                        // Handle footnotes being deleted (single type)
                        if !footnotesToDelete.isEmpty {
                            #if DEBUG
                            print("🗑️ \(footnotesToDelete.count) footnotes found in deletion range - showing confirmation")
                            #endif
                           
                            // Prevent the deletion for now - we'll handle it after user confirms
                            pendingChangeRange = nil
                            pendingReplacementText = nil
                            parent.onFootnoteDeleted?(footnotesToDelete, range)
                           
                            // Return false to prevent UITextView from deleting the text
                            return false
                        }
                        
                        #if DEBUG
                        if referencesToDelete.isEmpty && commentsToDelete.isEmpty && footnotesToDelete.isEmpty {
                            print("🗑️ No references, comments, or footnotes found in deletion range - allowing normal deletion")
                        }
                        #endif
                    } else {
                        #if DEBUG
                        print("🗑️ ⚠️ No attributed text available")
                        #endif
                    }
            }
            
            return true
        }
        
        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdatingFromSwiftUI else { return }

            let textStorage = textView.textStorage
            let currentLength = textStorage.length
            normalizePendingInsertion(in: textView)

            if isSimpleCharacterInsertion(range: pendingChangeRange, replacementText: pendingReplacementText),
               let range = pendingChangeRange,
               let replacementText = pendingReplacementText {
                previousTextLength = currentLength
                emitSimpleTypingChange(from: textView, range: range, replacementText: replacementText)
                pendingChangeRange = nil
                pendingReplacementText = nil
                return
            }

            WriteCoalescer.shared?.noteEditingActivity()

            if let layoutManager = textView.layoutManager as? NumberingLayoutManager,
               layoutManager.showDocumentLineNumbers {
                refreshLineNumberDisplay(in: textView, from: textView.selectedRange.location)
            }
            
            // Detect paste operation: more than 1 character was inserted
            let cursorPos = textView.selectedRange.location
            let insertedLength = currentLength - previousTextLength
            let replacementLength = pendingReplacementText.map { ($0 as NSString).length } ?? 0
            let pasteRange: NSRange? = {
                if let changedRange = pendingChangeRange,
                   replacementLength > 1,
                   changedRange.location + replacementLength <= currentLength {
                    return NSRange(location: changedRange.location, length: replacementLength)
                }
                if insertedLength > 1 && cursorPos >= insertedLength {
                    return NSRange(location: cursorPos - insertedLength, length: insertedLength)
                }
                return nil
            }()
            
            // PASTE FIX: If multiple characters were inserted, normalize colors for the entire range
            // This handles pasted text that may have fixed or adaptive neutral colors from external sources.
            if let pasteRange {
                #if DEBUG
                print("📋 Paste detected: \(pasteRange.length) characters inserted at position \(pasteRange.location)")
                #endif
                
                // Enumerate through the pasted range and fix colors
                textStorage.enumerateAttribute(.foregroundColor, in: pasteRange, options: []) { value, range, _ in
                    if let color = value as? UIColor {
                        if AttributedStringSerializer.isAdaptiveSystemColor(color) ||
                           AttributedStringSerializer.isFixedBlackOrWhite(color) {
                            textStorage.addAttribute(.foregroundColor, value: UIColor.label, range: range)
                            #if DEBUG
                            print("📋 Normalized neutral color in pasted text at range \(range)")
                            #endif
                        }
                    } else {
                        // No color attribute - add .label
                        textStorage.addAttribute(.foregroundColor, value: UIColor.label, range: range)
                        #if DEBUG
                        print("📋 Added .label color to pasted text at range \(range)")
                        #endif
                    }
                }
                
                // Preserve the insertion style when pasted content has no semantic style tag.
                let precedingStyle: String? = if pasteRange.location > 0 {
                    textStorage.attribute(
                        .textStyle,
                        at: pasteRange.location - 1,
                        effectiveRange: nil
                    ) as? String
                } else {
                    nil
                }
                let pasteStyle = (textView.typingAttributes[.textStyle] as? String)
                    ?? precedingStyle
                    ?? parent.project?.styleSheet?.firstParagraphStyle?.name
                    ?? UIFont.TextStyle.body.rawValue
                textStorage.enumerateAttribute(.textStyle, in: pasteRange, options: []) { value, range, _ in
                    if value == nil {
                        textStorage.addAttribute(.textStyle, value: pasteStyle, range: range)
                    }
                }
            } else if currentLength > 0 && cursorPos > 0 && cursorPos <= currentLength {
                // PERFORMANCE FIX: Only check .textStyle at cursor position, not the entire document
                // UITextView sometimes strips this when typing, so reapply it
                // The old approach enumerated the entire document twice per keystroke - very slow
                
                // Only check the character just typed (at cursor - 1)
                let checkPos = cursorPos - 1
                if textStorage.attribute(.textStyle, at: checkPos, effectiveRange: nil) == nil {
                    let previousStyle = checkPos > 0
                        ? textStorage.attribute(.textStyle, at: checkPos - 1, effectiveRange: nil) as? String
                        : nil
                    let styleToApply = (textView.typingAttributes[.textStyle] as? String)
                        ?? previousStyle
                        ?? parent.project?.styleSheet?.firstParagraphStyle?.name
                        ?? UIFont.TextStyle.body.rawValue
                    textStorage.addAttribute(.textStyle, value: styleToApply, range: NSRange(location: checkPos, length: 1))
                }
                
                // DARK MODE FIX: Ensure foreground color is set to adaptive .label color
                // When UITextView has no foregroundColor or has black (from setAttributedString reset),
                // text appears wrong in dark mode. Always ensure .label is applied for body text.
                if let existingColor = textStorage.attribute(.foregroundColor, at: checkPos, effectiveRange: nil) as? UIColor {
                    // Check if it's pure black (not intentionally colored) - replace with .label
                    if let hex = existingColor.toHex()?.uppercased(), 
                       (hex == "#000000" || hex == "#000000FF") {
                        textStorage.addAttribute(.foregroundColor, value: UIColor.label, range: NSRange(location: checkPos, length: 1))
                    }
                } else {
                    // No color attribute - add .label for proper dark mode support
                    textStorage.addAttribute(.foregroundColor, value: UIColor.label, range: NSRange(location: checkPos, length: 1))
                }
            }
            
            // Update previous text length for next change detection
            previousTextLength = currentLength
            
            // Update the binding so SwiftUI state stays in sync
            // Update if either content OR formatting changed
            if let attributedText = textView.attributedText {
                // Always update - could be text change or formatting change
                isProcessingUserTextChange = true
                lastUserTextChangeTime = Date()
                parent.onTextChange?(TextEditorChange(
                    attributedText: attributedText,
                    range: pendingChangeRange,
                    replacementText: pendingReplacementText
                ))
                pendingChangeRange = nil
                pendingReplacementText = nil
                DispatchQueue.main.async { [weak self] in
                    self?.isProcessingUserTextChange = false
                }
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            #if targetEnvironment(macCatalyst)
            flushPendingSimpleTypingChange()
            #endif
            NotificationCenter.default.post(name: .formattedTextEditorDidEndEditing, object: textView)
        }

        @objc func flushPendingTypingNotification(_ notification: Notification) {
            #if targetEnvironment(macCatalyst)
            flushPendingSimpleTypingChange()
            #endif
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isUpdatingFromSwiftUI else { return }
            
            // PERFORMANCE FIX: Removed ensureLayout(for: textContainer) which was called on every
            // selection change (including every keystroke). This forced layout of the entire document.
            // UITextView already ensures layout is valid around the cursor position when needed.
            
            let newRange = textView.selectedRange

            if isLiveTypingSimpleInsertion && newRange.length == 0 {
                previousSelection = newRange
                return
            }

            let textLength = textView.attributedText?.length ?? 0
            
            // Safety check: ensure location is within bounds
            guard newRange.location <= textLength else {
                #if DEBUG
                print("⚠️ textViewDidChangeSelection: location \(newRange.location) exceeds textLength \(textLength) - skipping")
                #endif
                previousSelection = newRange
                parent.selectedRange = newRange
                parent.onSelectionChange?(newRange)
                return
            }

            // Check if cursor landed on a zero-width space
            if newRange.length == 0, newRange.location > 0, newRange.location < textLength {
                if let attributedText = textView.attributedText {
                    // Use NSString for UTF-16 safe character access (NSRange uses UTF-16 offsets)
                    let nsString = attributedText.string as NSString
                    let nsStringLength = nsString.length
                    
                    // Extra safety check for nsString bounds
                    guard newRange.location < nsStringLength else {
                        #if DEBUG
                        print("⚠️ location \(newRange.location) >= nsStringLength \(nsStringLength) - skipping character check")
                        #endif
                        previousSelection = newRange
                        parent.selectedRange = newRange
                        parent.onSelectionChange?(newRange)
                        return
                    }
                    
                    let charAtLocation = nsString.character(at: newRange.location)
                    
                    // Check for zero-width space (U+200B = 0x200B = 8203)
                    if charAtLocation == 0x200B {
                        // Determine direction: are we moving forward or backward?
                        let movingForward = newRange.location > previousSelection.location
                        
                        if movingForward {
                            // Moving forward (right arrow) - skip to next position
                            let nextPosition = newRange.location + 1
                            if nextPosition <= textLength {
                                isUpdatingFromSwiftUI = true
                                textView.selectedRange = NSRange(location: nextPosition, length: 0)
                                previousSelection = NSRange(location: nextPosition, length: 0)
                                parent.selectedRange = NSRange(location: nextPosition, length: 0)
                                parent.onSelectionChange?(NSRange(location: nextPosition, length: 0))
                                DispatchQueue.main.async {
                                    self.isUpdatingFromSwiftUI = false
                                }
                                return
                            }
                        } else {
                            // Moving backward (left arrow/backspace) - skip back to find the image
                            // Zero-width space structure: [image][newline][zero-width-space]
                            // We need to skip back 2 positions to get to the image
                            // Check position - 2 for image (skip newline at position - 1)
                            let imagePosition = newRange.location - 2
                            if imagePosition >= 0,
                               let attributedText = textView.attributedText,
                               attributedText.attribute(.attachment, at: imagePosition, effectiveRange: nil) is ImageAttachment {
                                
                                // Select the image directly (don't just place cursor, select with length=1)
                                isUpdatingFromSwiftUI = true
                                selectImage(at: imagePosition, in: textView)
                                DispatchQueue.main.async {
                                    self.isUpdatingFromSwiftUI = false
                                }
                                return
                            }
                        }
                    }
                }
            }
            
            // Check if cursor is directly ON an image
            // Only check for images if it's a zero-length selection (cursor, not selection)
            // and the position is valid (not at end of document)
            if newRange.length == 0, newRange.location < textLength {
                // Get the character at the cursor position to check for attachment
                if let attributedText = textView.attributedText {
                    // Note: Comment taps are now handled by CustomTextView tap gesture
                    // This ensures direct clicking on comments opens them immediately
                    
                    // Check for image attachment
                    if let _ = attributedText.attribute(.attachment, at: newRange.location, effectiveRange: nil) as? ImageAttachment {
                    
                    // Check if this image was already selected (previous selection was length=1 at this position)
                    // If so, move BEFORE the image instead of re-selecting it
                    if previousSelection.length == 1 && previousSelection.location == newRange.location {
                        let beforeImagePosition = newRange.location - 1
                        if beforeImagePosition >= 0 {
                            isUpdatingFromSwiftUI = true
                            
                            // Restore cursor visibility immediately
                            textView.tintColor = .systemBlue
                            
                            // Clear image selection flag and hide border
                            if let customTextView = textView as? CustomTextView {
                                customTextView.isImageSelected = false
                                customTextView.hideSelectionBorder()
                            }
                            
                            textView.selectedRange = NSRange(location: beforeImagePosition, length: 0)
                            previousSelection = NSRange(location: beforeImagePosition, length: 0)
                            parent.selectedRange = NSRange(location: beforeImagePosition, length: 0)
                            parent.onSelectionChange?(NSRange(location: beforeImagePosition, length: 0))
                            
                            // Clear image selection
                            DispatchQueue.main.async {
                                self.parent.onClearImageSelection?()
                                self.isUpdatingFromSwiftUI = false
                            }
                            return
                        }
                    }
                    
                    // Cursor landed directly on an image character
                    // Select the image (which includes calling the tap handler)
                    selectImage(at: newRange.location, in: textView)
                    return
                    }
                }
            }

            // Check if cursor moved away from an image (to clear selection)
            // Only do this if:
            // 1. The selection length is 0 (it's a cursor, not a selection)
            // 2. The previous selection was length 1 (was on an image)
            // 3. The position has changed
            if newRange.length == 0 && previousSelection.length == 1 && newRange.location != previousSelection.location {
                // Check if moving forward from image - if so, skip past the newline and zero-width space
                let movingForward = newRange.location > previousSelection.location
                if movingForward {
                    // Moving forward from image position (e.g., from position 2 to 3)
                    // We want to skip: position 3 (newline) and position 4 (zero-width space)
                    // and go directly to position 5
                    let targetPosition = previousSelection.location + 3  // Skip image (1) + newline (1) + zero-width space (1)
                    if targetPosition < textView.attributedText.length {
                        isUpdatingFromSwiftUI = true
                        textView.selectedRange = NSRange(location: targetPosition, length: 0)
                        previousSelection = NSRange(location: targetPosition, length: 0)
                        parent.selectedRange = NSRange(location: targetPosition, length: 0)
                        parent.onSelectionChange?(NSRange(location: targetPosition, length: 0))
                        
                        // Clear image selection and restore cursor
                        textView.tintColor = .systemBlue
                        
                        // Clear image selection flag and hide border
                        if let customTextView = textView as? CustomTextView {
                            customTextView.isImageSelected = false
                            customTextView.hideSelectionBorder()
                        }
                        
                        DispatchQueue.main.async {
                            self.parent.onClearImageSelection?()
                            self.isUpdatingFromSwiftUI = false
                        }
                        return
                    }
                }
                
                // Not moving forward, or target position invalid - just clear selection normally
                DispatchQueue.main.async {
                    self.parent.onClearImageSelection?()
                }
                
                // Clear image selection flag and hide border
                if let customTextView = textView as? CustomTextView {
                    customTextView.isImageSelected = false
                    customTextView.hideSelectionBorder()
                }
                
                // Make sure cursor is visible again
                textView.tintColor = .systemBlue
            }
            
            // Check if we have a length-1 selection and cursor moved away
            // This handles the case where image was selected but user moved cursor
            if newRange.length == 0 && previousSelection.length == 1 {
                // Cursor was on an image, now moved away
                // Clear image selection flag and hide border
                if let customTextView = textView as? CustomTextView {
                    customTextView.isImageSelected = false
                    customTextView.hideSelectionBorder()
                }
                
                // Restore cursor visibility
                textView.tintColor = .systemBlue
            }
            
            // Update stored previous selection
            previousSelection = newRange

            if isLiveTypingSimpleInsertion,
               let lastUserTextChangeTime,
               Date().timeIntervalSince(lastUserTextChangeTime) < Self.simpleTypingIdleDelay {
                return
            }
            
            // Check if position is out of bounds
            if newRange.location >= textLength {
                DispatchQueue.main.async {
                    self.parent.selectedRange = newRange
                    self.parent.onSelectionChange?(newRange)
                }
                return
            }
            
            // If we have a length-1 range over an image, don't process further - the image is already selected.
            // Other length-1 selections are normal text selections and must not leave image state active.
            if newRange.length == 1,
               newRange.location < textLength,
               textView.attributedText?.attribute(.attachment, at: newRange.location, effectiveRange: nil) is ImageAttachment {
                DispatchQueue.main.async {
                    self.parent.selectedRange = newRange
                    self.parent.onSelectionChange?(newRange)
                }
                return
            }
            
            // Normal cursor movement - update binding
            // Sync typing attributes to match cursor position paragraph style
            self.syncTypingAttributesForCursorPosition(textView, at: newRange.location)
            
            DispatchQueue.main.async {
                self.parent.selectedRange = newRange
                self.parent.onSelectionChange?(newRange)
            }
        }
        
        private func selectImage(at position: Int, in textView: UITextView) {
            guard let attributedText = textView.attributedText,
                  position < attributedText.length,
                  let attachment = attributedText.attribute(.attachment, at: position, effectiveRange: nil) as? ImageAttachment else {
                return
            }
            
            #if DEBUG
            print("🖼️ ========== IMAGE TAP HANDLER ==========")
            print("🖼️ Image selected at position \(position)")
            #endif
            
            // Get the image bounds
            textView.layoutManager.ensureLayout(for: textView.textContainer)
            
            let glyphRange = textView.layoutManager.glyphRange(forCharacterRange: NSRange(location: position, length: 1), actualCharacterRange: nil)
            let glyphBounds = textView.layoutManager.boundingRect(forGlyphRange: glyphRange, in: textView.textContainer)
            
            // Size the selection from the LIVE text-column width, exactly as the
            // renderer does via attachmentBounds(for:). attachment.bounds is baked
            // from the fallback column width and would be too small on wider columns.
            let availableWidth = ImageAttachment.availableWidth(for: textView.textContainer)
            let imageSize = attachment.displaySize(forAvailableWidth: availableWidth)
            
            // Calculate position from glyph bounds, but use rendered image size
            let adjustedBounds = CGRect(
                x: glyphBounds.origin.x + textView.textContainerInset.left,
                y: glyphBounds.origin.y + textView.textContainerInset.top,
                width: imageSize.width,
                height: imageSize.height
            )
            
            #if DEBUG
            print("🖼️ Glyph bounds: \(glyphBounds)")
            print("🖼️ Attachment size: \(imageSize)")
            print("🖼️ Frame: \(adjustedBounds)")
            print("🖼️ Attachment: \(attachment)")
            #endif
            
            // Call the image tapped callback
            parent.onImageTapped?(attachment, adjustedBounds, position)
            
            #if DEBUG
            print("🖼️ State updated - selectedImage: true")
            print("🖼️ State updated - selectedImageFrame: \(adjustedBounds)")
            #endif
            
            // Select the attachment character to prevent text insertion
            // CRITICAL: Setting selectedRange here triggers textViewDidChangeSelection again!
            // That's why we check previousSelection above to prevent infinite loop
            let imageRange = NSRange(location: position, length: 1)
            textView.selectedRange = imageRange
            DispatchQueue.main.async {
                self.parent.selectedRange = imageRange
                self.parent.onSelectionChange?(imageRange)
            }
            previousSelection = imageRange  // Update previous AFTER setting new range
            
            // Mark that an image is selected to suppress selection UI
            if let customTextView = textView as? CustomTextView {
                customTextView.isImageSelected = true
            }
            
            // Hide cursor by making tint color clear
            // This prevents the blinking cursor from appearing over the image
            textView.tintColor = .clear
            
            #if DEBUG
            print("🖼️ Cursor hidden, range set to \(imageRange)")
            print("🖼️ ========== END ==========")
            #endif
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let textView = gesture.view as? UITextView else { return }
            
            let location = gesture.location(in: textView)
            
            // Ensure layout is up to date
            textView.layoutManager.ensureLayout(for: textView.textContainer)
            
            // Adjust location for text container insets
            let adjustedLocation = CGPoint(
                x: location.x - textView.textContainerInset.left,
                y: location.y - textView.textContainerInset.top
            )
            
            // Find the character index at the tap location
            let characterIndex = textView.layoutManager.characterIndex(
                for: adjustedLocation,
                in: textView.textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )
            
            // Check if there's an image at this position
            guard let attributedText = textView.attributedText,
                  characterIndex < attributedText.length,
                  let attachment = attributedText.attribute(.attachment, at: characterIndex, effectiveRange: nil) as? ImageAttachment else {
                // Not on an image - let text view handle normally
                return
            }
            
            #if DEBUG
            print("🖼️ ========== IMAGE TAP HANDLER ==========")
            print("🖼️ Tap location: \(location)")
            print("🖼️ Adjusted location: \(adjustedLocation)")
            print("🖼️ Character index: \(characterIndex)")
            print("🖼️ Attachment: \(attachment)")
            #endif
            
            // Get the glyph range for the attachment
            let glyphRange = textView.layoutManager.glyphRange(forCharacterRange: NSRange(location: characterIndex, length: 1), actualCharacterRange: nil)
            let glyphBounds = textView.layoutManager.boundingRect(forGlyphRange: glyphRange, in: textView.textContainer)
            
            // Size the selection from the LIVE text-column width, exactly as the
            // renderer does via attachmentBounds(for:). attachment.bounds is baked
            // from the fallback column width and would be too small on wider columns.
            let availableWidth = ImageAttachment.availableWidth(for: textView.textContainer)
            let imageSize = attachment.displaySize(forAvailableWidth: availableWidth)
            
            // Calculate position from glyph bounds, but use rendered image size
            let adjustedBounds = CGRect(
                x: glyphBounds.origin.x + textView.textContainerInset.left,
                y: glyphBounds.origin.y + textView.textContainerInset.top,
                width: imageSize.width,
                height: imageSize.height
            )
            
            #if DEBUG
            print("🖼️ Glyph bounds: \(glyphBounds)")
            print("🖼️ Attachment size: \(imageSize)")
            print("🖼️ Final bounds: \(adjustedBounds)")
            #endif
            
            // Call the image tapped callback
            parent.onImageTapped?(attachment, adjustedBounds, characterIndex)
            
            #if DEBUG
            print("🖼️ State updated - selectedImage: true")
            print("🖼️ State updated - selectedImageFrame: \(adjustedBounds)")
            #endif
            
            // Select the attachment character
            let imageRange = NSRange(location: characterIndex, length: 1)
            textView.selectedRange = imageRange
            parent.selectedRange = imageRange
            parent.onSelectionChange?(imageRange)
            previousSelection = imageRange
            
            // Mark that an image is selected to suppress selection UI
            if let customTextView = textView as? CustomTextView {
                customTextView.isImageSelected = true
                // Show blue border around the image
                customTextView.showSelectionBorder(at: adjustedBounds)
            }
            
            // Hide cursor by making tint color clear
            textView.tintColor = .clear
            
            #if DEBUG
            print("🖼️ Cursor hidden, range set to \(imageRange)")
            print("🖼️ ========== END ==========")
            #endif
        }

        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let textView = gesture.view as? UITextView else { return }
            
            let translation = gesture.translation(in: textView)
            
            switch gesture.state {
            case .changed:
                // Scroll the text view by the translation amount
                var contentOffset = textView.contentOffset
                contentOffset.y -= translation.y
                
                // Clamp to valid scroll bounds
                let maxOffsetY = max(0, textView.contentSize.height - textView.bounds.height + textView.contentInset.top + textView.contentInset.bottom)
                contentOffset.y = max(0, min(maxOffsetY, contentOffset.y))
                
                textView.contentOffset = contentOffset
                
                // Reset translation for next update
                gesture.setTranslation(.zero, in: textView)
                
            default:
                break
            }
        }
        
        /// Sync typing attributes to match the paragraph style at the cursor position
        /// This preserves the alignment and other paragraph properties from the text at the cursor
        private func syncTypingAttributesForCursorPosition(_ textView: UITextView, at position: Int) {
            guard let attributedText = textView.attributedText, position >= 0, position <= attributedText.length else {
                return
            }
            
            // Read the paragraph style from the text at the cursor position
            let checkPos = max(0, min(position, attributedText.length - 1))
            let paragraphStyle: NSParagraphStyle
            if attributedText.length > 0,
               let ps = attributedText.attribute(.paragraphStyle, at: checkPos, effectiveRange: nil) as? NSParagraphStyle {
                paragraphStyle = ps
            } else {
                // Fallback for empty documents
                let defaultStyle = NSMutableParagraphStyle()
                defaultStyle.alignment = .natural
                defaultStyle.lineHeightMultiple = 1.0
                paragraphStyle = defaultStyle
            }
            
            // Update typing attributes to match the paragraph style at cursor
            var typingAttrs = textView.typingAttributes
            typingAttrs[.paragraphStyle] = paragraphStyle

            if attributedText.length > 0,
               let styleName = attributedText.attribute(.textStyle, at: checkPos, effectiveRange: nil) as? String {
                typingAttrs[.textStyle] = styleName
            } else if let firstParagraphStyleName = parent.project?.styleSheet?.firstParagraphStyle?.name,
                      position == 0 {
                typingAttrs[.textStyle] = firstParagraphStyleName
            }
            
            textView.typingAttributes = typingAttrs
            
        }
        
        // MARK: - UIGestureRecognizerDelegate
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Allow our tap gesture to work alongside the text view's built-in gestures
            return true
        }
        
        // MARK: - Gesture Handlers
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let textView = gesture.view as? UITextView else { return }
            
            switch gesture.state {
            case .began:
                // Store initial scale
                break
                
            case .changed:
                // Apply zoom with reduced speed (40% of original sensitivity)
                let scaleDelta = (gesture.scale - 1.0) * 0.4
                let newScale = currentZoomScale * (1.0 + scaleDelta)
                // Clamp zoom between 0.5x and 3.0x
                let clampedScale = max(0.5, min(3.0, newScale))
                
                // Apply transform to scale the view
                textView.transform = CGAffineTransform(scaleX: clampedScale, y: clampedScale)
                parent.onZoomScaleChange?(clampedScale)
                
            case .ended, .cancelled:
                // Update current scale and save to UserDefaults
                let scaleDelta = (gesture.scale - 1.0) * 0.4
                let newScale = currentZoomScale * (1.0 + scaleDelta)
                currentZoomScale = max(0.5, min(3.0, newScale))
                
                // Apply final transform
                textView.transform = CGAffineTransform(scaleX: currentZoomScale, y: currentZoomScale)
                
                // Save zoom factor to UserDefaults
                UserDefaults.standard.set(Double(currentZoomScale), forKey: "editorZoomScale")
                parent.onZoomScaleChange?(currentZoomScale)
                #if DEBUG
                print("🔍 Zoom factor saved: \(currentZoomScale)")
                #endif
                
            default:
                break
            }
        }
        
        // MARK: - Keyboard Notifications
        
        @objc func keyboardWillShow(_ notification: Notification) {
            // Handle keyboard appearance if needed
        }
        
        @objc func keyboardWillHide(_ notification: Notification) {
            // Handle keyboard dismissal if needed
        }
    }
}

// MARK: - Custom UITextView

extension UITextView {
    func clearImageSelectionOverlay() {
        guard let customTextView = self as? CustomTextView else {
            tintColor = UIColor.systemBlue
            return
        }

        customTextView.isImageSelected = false
        customTextView.hideSelectionBorder()
        customTextView.tintColor = UIColor.systemBlue
    }
}

/// Custom UITextView subclass to support inputAccessoryView
private class CustomTextView: UITextView, UIGestureRecognizerDelegate {
    private final class FallbackSelectionRect: UITextSelectionRect {
        private let fallbackRect: CGRect

        init(rect: CGRect) {
            self.fallbackRect = rect
            super.init()
        }

        override var rect: CGRect { fallbackRect }
        override var writingDirection: NSWritingDirection { .leftToRight }
        override var containsStart: Bool { true }
        override var containsEnd: Bool { true }
        override var isVertical: Bool { false }
    }

    var customAccessoryView: UIView?
    var isImageSelected: Bool = false
    var shouldHideSystemFormattingMenu: Bool = false
    var onCommentTapped: ((CommentAttachment, Int) -> Void)?
    var onFootnoteTapped: ((FootnoteAttachment, Int) -> Void)?
    var onReferenceTapped: ((ReferenceAttachment, Int) -> Void)?
    var onImageCutRequested: ((ImageAttachment, Int) -> Void)?
    var onImagePasteRequested: ((ImageAttachment, Int) -> Void)?
    var onGlossaryAddRequested: ((String) -> Void)?  // Called with selected text when user selects "Add to Glossary"
    var onIndexAddRequested: ((String) -> Void)?  // Called with selected text when user selects "Add to Index" (Feature 033)
    
    // Callbacks for list indent/outdent (Feature 016)
    var onTabPressed: (() -> Void)?
    var onShiftTabPressed: (() -> Void)?
    
    // Selection border view for images
    private let selectionBorderView: UIView = {
        let view = UIView()
        view.layer.borderColor = UIColor.systemBlue.cgColor
        view.layer.borderWidth = 3
        view.layer.cornerRadius = 4
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.isHidden = true
        return view
    }()
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        addSubview(selectionBorderView)
        setupCommentInteraction()
        setupTraitChangeObservation()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addSubview(selectionBorderView)
        setupCommentInteraction()
        setupTraitChangeObservation()
    }

    #if targetEnvironment(macCatalyst)
    override var textInputContextIdentifier: String? {
        nil
    }
    #endif

    private func validInputRect(_ rect: CGRect?) -> CGRect? {
        guard let rect, !rect.isNull, !rect.isInfinite, !rect.isEmpty else { return nil }
        return rect
    }

    private func fallbackInputRect() -> CGRect {
        let fallbackBounds = bounds.inset(by: textContainerInset)
        guard !fallbackBounds.isNull, !fallbackBounds.isInfinite, !fallbackBounds.isEmpty else {
            return CGRect(x: 0, y: 0, width: 1, height: font?.lineHeight ?? 17)
        }

        return CGRect(
            x: fallbackBounds.minX,
            y: fallbackBounds.minY,
            width: 1,
            height: font?.lineHeight ?? 17
        )
    }

    private func caretCharacterIndex(at position: UITextPosition) -> Int? {
        let offset = self.offset(from: beginningOfDocument, to: position)
        let textLength = attributedText.length

        guard textLength > 0 else { return nil }

        let clampedOffset = min(max(offset, 0), textLength)
        let previousCharacterIsNewline = clampedOffset > 0
            && (attributedText.string as NSString).character(at: clampedOffset - 1) == 0x0A
        if clampedOffset == 0 || previousCharacterIsNewline {
            return min(clampedOffset, textLength - 1)
        }

        return clampedOffset - 1
    }

    override func caretRect(for position: UITextPosition) -> CGRect {
        if let rect = validInputRect(super.caretRect(for: position)) {
            guard let characterIndex = caretCharacterIndex(at: position),
                  let caretFont = attributedText.attribute(.font, at: characterIndex, effectiveRange: nil) as? UIFont else {
                return rect
            }

            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: NSRange(location: characterIndex, length: 1),
                actualCharacterRange: nil
            )
            guard glyphRange.length > 0 else { return rect }

            let lineFragmentRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphRange.location,
                effectiveRange: nil
            )
            let glyphLocation = layoutManager.location(forGlyphAt: glyphRange.location)
            let baselineY = textContainerInset.top + lineFragmentRect.minY + glyphLocation.y
            let descenderDepth = max(0, -caretFont.descender)
            let caretHeight = caretFont.ascender + descenderDepth
            guard caretHeight > 0 else { return rect }

            return CGRect(
                x: rect.minX,
                y: baselineY - caretFont.ascender,
                width: rect.width,
                height: caretHeight
            )
        }

        return fallbackInputRect()
    }

    override func firstRect(for range: UITextRange) -> CGRect {
        let rect = super.firstRect(for: range)
        if !rect.isNull && !rect.isInfinite && !rect.isEmpty {
            return rect
        }

        if let caretRect = validInputRect(self.caretRect(for: range.start)) {
            return caretRect
        }

        return fallbackInputRect()
    }
    
    // MARK: - Key Commands (Tab/Shift+Tab for list indent/outdent)
    
    /// Cached key commands to avoid creating new UIKeyCommand objects on every access.
    /// On Mac Catalyst, keyCommands is called frequently during responder chain traversal
    /// for menu validation and keyboard shortcut processing.
    private lazy var _cachedKeyCommands: [UIKeyCommand] = {
        var commands: [UIKeyCommand] = []
        
        // Tab key - increase list indent (or insert tab in non-list content)
        let tabCommand = UIKeyCommand(
            input: "\t",
            modifierFlags: [],
            action: #selector(handleTab)
        )
        tabCommand.title = NSLocalizedString("formattingToolbar.increaseIndent", comment: "Increase Indent")
        commands.append(tabCommand)
        
        // Shift+Tab - decrease list indent
        let shiftTabCommand = UIKeyCommand(
            input: "\t",
            modifierFlags: .shift,
            action: #selector(handleShiftTab)
        )
        shiftTabCommand.title = NSLocalizedString("formattingToolbar.decreaseIndent", comment: "Decrease Indent")
        commands.append(shiftTabCommand)
        
        return commands
    }()
    
    override var keyCommands: [UIKeyCommand]? {
        // Return cached commands + any super commands.
        // super.keyCommands is typically nil or cheap for UITextView.
        if let superCommands = super.keyCommands, !superCommands.isEmpty {
            return superCommands + _cachedKeyCommands
        }
        return _cachedKeyCommands
    }
    
    @objc private func handleTab() {
        #if DEBUG
        print("⌨️ handleTab() called - onTabPressed is \(onTabPressed != nil ? "set" : "nil")")
        #endif
        onTabPressed?()
    }
    
    @objc private func handleShiftTab() {
        #if DEBUG
        print("⌨️ handleShiftTab() called - onShiftTabPressed is \(onShiftTabPressed != nil ? "set" : "nil")")
        #endif
        onShiftTabPressed?()
    }
    
    // MARK: - Menu-based indent actions (for Mac Catalyst keyboard shortcuts)
    
    /// Increase indent - called from Format menu (Tab key)
    @objc func increaseIndent(_ sender: Any?) {
        #if DEBUG
        print("⌨️ increaseIndent: called from menu - onTabPressed is \(onTabPressed != nil ? "set" : "nil")")
        #endif
        onTabPressed?()
    }
    
    /// Decrease indent - called from Format menu (Shift+Tab key)
    @objc func decreaseIndent(_ sender: Any?) {
        #if DEBUG
        print("⌨️ decreaseIndent: called from menu - onShiftTabPressed is \(onShiftTabPressed != nil ? "set" : "nil")")
        #endif
        onShiftTabPressed?()
    }
    
    // MARK: - Mac Catalyst Shift+Tab handling
    
    /// On Mac Catalyst, Shift+Tab triggers insertBacktab: from AppKit bridging
    /// This is the proper way to intercept Shift+Tab on Catalyst
    @objc func insertBacktab(_ sender: Any?) {
        #if DEBUG
        print("⌨️ insertBacktab: called - onShiftTabPressed is \(onShiftTabPressed != nil ? "set" : "nil")")
        #endif
        if onShiftTabPressed != nil {
            onShiftTabPressed?()
        }
        // Don't call super - we've handled it
    }
    
    // MARK: - Keyboard Press Interception (Mac Catalyst)
    
    /// Override pressesBegan to intercept Shift+Tab on Mac Catalyst
    /// UIKeyCommand doesn't reliably intercept modifier key combinations in UITextView on Catalyst
    #if targetEnvironment(macCatalyst)
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            guard let key = press.key else { continue }
            
            // Check for Shift+Tab (keyCode .keyboardTab with shift modifier)
            if key.keyCode == .keyboardTab && key.modifierFlags.contains(.shift) {
                if onShiftTabPressed != nil {
                    onShiftTabPressed?()
                    return  // Don't call super, we handled it
                }
            }
        }
        super.pressesBegan(presses, with: event)
    }
    #endif
    
    // MARK: - Text Input Interception (Mac Catalyst Tab handling)
    
    /// Override insertText to intercept Tab key on Mac Catalyst
    /// UIKeyCommand doesn't reliably intercept Tab in UITextView on Catalyst
    override func insertText(_ text: String) {
        // Check for backtab character (ASCII 25, sent by some systems for Shift+Tab)
        if text == "\u{0019}" || text == "\u{000F}" {
            if onShiftTabPressed != nil {
                onShiftTabPressed?()
                return
            }
        }
        
        if text == "\t" {
            // Call our Tab handler instead of inserting a tab character
            if onTabPressed != nil {
                onTabPressed?()
                return
            }
        }
        // For all other text, use default behavior
        super.insertText(text)
    }
    
    // MARK: - Appearance Handling
    
    private func setupTraitChangeObservation() {
        // Register for trait changes using the new iOS 17+ API
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, previousTraitCollection: UITraitCollection) in
            // When appearance changes (light/dark mode), ensure text color updates
            // This is critical for System appearance mode to work correctly
            #if DEBUG
            print("🎨 Trait collection changed - updating text color for appearance mode")
            print("   Previous: \(previousTraitCollection.userInterfaceStyle.rawValue), New: \(self.traitCollection.userInterfaceStyle.rawValue)")
            #endif
            
            // Re-set textColor to .label so it resolves to the correct color for new appearance
            self.textColor = .label
            
            // Force the text view to redraw with new colors
            self.setNeedsDisplay()
        }
    }
    
    private func setupCommentInteraction() {
        // Add tap gesture to handle comment taps directly
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGesture.delegate = self
        addGestureRecognizer(tapGesture)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        
        // Convert tap location to character index
        var point = location
        point.x -= textContainerInset.left
        point.y -= textContainerInset.top
        
        let characterIndex = layoutManager.characterIndex(
            for: point,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        
        guard characterIndex < textStorage.length else {
            print("🔢 Tap outside text bounds")
            return
        }
        
        // Check if tapped on a footnote attachment
        if let footnoteAttachment = textStorage.attribute(.attachment, at: characterIndex, effectiveRange: nil) as? FootnoteAttachment {
            print("🔢 Footnote attachment tapped! ID: \(footnoteAttachment.footnoteID), number: \(footnoteAttachment.number)")
            onFootnoteTapped?(footnoteAttachment, characterIndex)
            // Prevent default text selection
            gesture.cancelsTouchesInView = true
            return
        }
        
        // Check if tapped on a comment attachment
        if let commentAttachment = textStorage.attribute(.attachment, at: characterIndex, effectiveRange: nil) as? CommentAttachment {
            onCommentTapped?(commentAttachment, characterIndex)
            // Prevent default text selection
            gesture.cancelsTouchesInView = true
            return
        }
        
        // Check if tapped on a reference attachment (Feature 029)
        if let referenceAttachment = textStorage.attribute(.attachment, at: characterIndex, effectiveRange: nil) as? ReferenceAttachment {
            print("🔖 Reference attachment tapped! Type: \(referenceAttachment.referenceType), entryID: \(referenceAttachment.entryID)")
            onReferenceTapped?(referenceAttachment, characterIndex)
            // Prevent default text selection
            gesture.cancelsTouchesInView = true
            return
        }
    }
    
    // MARK: - UIGestureRecognizerDelegate
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow our tap gesture to work alongside the text view's built-in gestures
        return true
    }
    
    // Change cursor to pointer when hovering over comments (iPad with mouse/trackpad)
    #if targetEnvironment(macCatalyst)
    /// Cached character index from last cursor update to avoid redundant attribute lookups
    private var _lastCursorCharIndex: Int = -1
    /// Timestamp of last cursor update to throttle expensive layout calculations
    private var _lastCursorUpdateTime: CFTimeInterval = 0
    /// Minimum interval between cursor updates (seconds) — ~20 updates/sec max
    private static let cursorUpdateInterval: CFTimeInterval = 0.05
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Throttle cursor updates: layoutManager.characterIndex + attribute lookups
        // are expensive and hitTest fires on every mouse move on Mac Catalyst.
        let now = CACurrentMediaTime()
        if now - _lastCursorUpdateTime >= Self.cursorUpdateInterval {
            _lastCursorUpdateTime = now
            
            var adjustedPoint = point
            adjustedPoint.x -= textContainerInset.left
            adjustedPoint.y -= textContainerInset.top
            
            let characterIndex = layoutManager.characterIndex(
                for: adjustedPoint,
                in: textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )
            
            // Only update cursor if we moved to a different character
            if characterIndex != _lastCursorCharIndex {
                _lastCursorCharIndex = characterIndex
                
                if characterIndex < textStorage.length,
                   let attachment = textStorage.attribute(.attachment, at: characterIndex, effectiveRange: nil) {
                    // Single attribute lookup — check type
                    if attachment is FootnoteAttachment || attachment is CommentAttachment || attachment is ReferenceAttachment {
                        NSCursor.pointingHand.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                } else {
                    NSCursor.arrow.set()
                }
            }
        }
        
        return super.hitTest(point, with: event)
    }
    #endif
    
    // Show/hide selection border
    func showSelectionBorder(at frame: CGRect) {
        selectionBorderView.frame = frame
        selectionBorderView.isHidden = false
    }
    
    func hideSelectionBorder() {
        selectionBorderView.isHidden = true
    }
    
    override var inputAccessoryView: UIView? {
        get {
            return customAccessoryView
        }
        set {
            customAccessoryView = newValue
        }
    }
    
    // Hide selection UI (drag handles) when an image is selected
    override func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        // If an image is selected, return empty array to hide selection UI
        if isImageSelected {
            return []
        }

        let rects = super.selectionRects(for: range)
        if rects.contains(where: { validInputRect($0.rect) != nil }) {
            return rects
        }

        return [FallbackSelectionRect(rect: firstRect(for: range))]
    }
    
    // MARK: - Context Menu Customization
    // ⚠️ CONTEXT MENU ISSUE: Despite multiple attempts, the context menu still shows unwanted items
    // See docs/CONTEXT_MENU_ISSUE.md for details and potential solutions
    // Goal: Show only Look Up, Cut, Copy, Paste
    // Current: Also shows Search, Share, Spelling/Grammar, Substitutions, etc.
    
    // Hide the system formatting menu and selection grabbers/handles
    
    /// Pre-built set of allowed actions for fast canPerformAction lookups.
    /// On Mac Catalyst, canPerformAction is called for dozens of selectors during
    /// every menu validation pass. Using a Set avoids O(n) linear scans.
    private static let _allowedActions: Set<Selector> = [
        #selector(UIResponderStandardEditActions.cut(_:)),
        #selector(UIResponderStandardEditActions.copy(_:)),
        #selector(UIResponderStandardEditActions.paste(_:)),
        Selector(("_lookup:")),  // Look Up action - internal Apple selector
        Selector(("_promptForReplace:")),  // Spelling replacement action
        Selector(("replace:")),  // Replace selected text action
        #selector(UIResponderStandardEditActions.delete(_:)),  // Allow delete for image removal
        #selector(CustomTextView.increaseIndent(_:)),  // Tab - increase list indent
        #selector(CustomTextView.decreaseIndent(_:))   // Shift+Tab - decrease list indent
    ]
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        // Always allow indent actions for menu commands and keyCommands
        if action == #selector(increaseIndent(_:)) || action == #selector(decreaseIndent(_:)) ||
           action == #selector(handleTab) || action == #selector(handleShiftTab) {
            return true
        }

        if action == #selector(UIResponderStandardEditActions.paste(_:)) {
            let pasteboard = UIPasteboard.general
            if pasteboard.data(forPasteboardType: FormattedTextEditorImageClipboard.pasteboardType) != nil || pasteboard.hasImages {
                return isEditable
            }
        }
        
        // Image selections use custom clipboard handling below.
        if isImageSelected {
            return action == #selector(UIResponderStandardEditActions.delete(_:)) ||
                action == #selector(UIResponderStandardEditActions.cut(_:)) ||
                action == #selector(UIResponderStandardEditActions.copy(_:)) ||
                action == #selector(UIResponderStandardEditActions.paste(_:))
        }
        
        // Fast Set lookup instead of linear scan
        if Self._allowedActions.contains(action) {
            return super.canPerformAction(action, withSender: sender)
        }

        // Allow spelling/replace selectors to keep native misspelling replacement working.
        // iOS may use private selector names that include these terms.
        let actionName = NSStringFromSelector(action).lowercased()
        if actionName.contains("replace") || actionName.contains("spell") {
            return super.canPerformAction(action, withSender: sender)
        }
        
        // Explicitly deny all other actions
        return false
    }
    
    // MARK: - Copy with Reference Stripping
    
    /// Override copy to preserve image attachments and strip reference attachments.
    @objc override func copy(_ sender: Any?) {
        let nsRange = selectedRange
        guard nsRange.length > 0 else {
            super.copy(sender)
            return
        }

        if let attachment = FormattedTextEditorImageClipboard.selectedAttachment(in: attributedText, range: nsRange),
           copyImageAttachmentToPasteboard(attachment) {
            return
        }
        
        let selectedString = attributedText.attributedSubstring(from: nsRange)
        
        // Check if selection contains any reference attachments
        var hasReferences = false
        selectedString.enumerateAttribute(NSAttributedString.Key.attachment, in: NSRange(0..<selectedString.length), options: []) { value, _, _ in
            if let _ = value as? ReferenceAttachment {
                hasReferences = true
            }
        }
        
        if hasReferences {
            #if DEBUG
            print("📋 Copy operation detected - stripping reference attachments")
            #endif
            
            // Create plain text version without reference attachments
            let plainString = selectedString.string
            
            // Copy to pasteboard
            UIPasteboard.general.string = plainString
            
            // Show brief feedback to user
            let alert = UIAlertController(
                title: "References Not Copied",
                message: "References cannot be copied. Only the text will be copied. This helps maintain accurate reference tracking.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            // Present on root view controller
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = windowScene.windows.first?.rootViewController {
                root.present(alert, animated: true)
            }
        } else {
            // No references - proceed with normal copy
            super.copy(sender)
        }
    }

    @objc override func cut(_ sender: Any?) {
        let range = selectedRange
        guard let attachment = FormattedTextEditorImageClipboard.selectedAttachment(in: attributedText, range: range),
              copyImageAttachmentToPasteboard(attachment) else {
            super.cut(sender)
            return
        }

        onImageCutRequested?(attachment, range.location)
    }

    @objc override func paste(_ sender: Any?) {
        let pasteboard = UIPasteboard.general
        let attachment: ImageAttachment?

        if let data = pasteboard.data(forPasteboardType: FormattedTextEditorImageClipboard.pasteboardType) {
            attachment = FormattedTextEditorImageClipboard.decode(data)
        } else if let image = pasteboard.image,
                  let imageData = ImageAttachment.compressImage(image) {
            let externalAttachment = ImageAttachment()
            externalAttachment.imageData = imageData
            externalAttachment.image = UIImage(data: imageData)
            externalAttachment.alignment = .center
            externalAttachment.updateBounds()
            attachment = externalAttachment
        } else {
            super.paste(sender)
            return
        }

        guard let attachment else {
            super.paste(sender)
            return
        }

        onImagePasteRequested?(attachment, selectedRange.location)
    }

    private func copyImageAttachmentToPasteboard(_ attachment: ImageAttachment) -> Bool {
        guard let encodedAttachment = FormattedTextEditorImageClipboard.encode(attachment) else {
            return false
        }

        var item: [String: Any] = [
            FormattedTextEditorImageClipboard.pasteboardType: encodedAttachment
        ]
        if let image = attachment.image ?? attachment.imageData.flatMap(UIImage.init(data:)),
           let pngData = image.pngData() {
            item["public.png"] = pngData
        }
        UIPasteboard.general.items = [item]
        return true
    }

    // iOS 16+ Edit Menu Customization
    @available(iOS 16.0, *)
    override func editMenu(for textRange: UITextRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        // Feature 029: Add "Add to Glossary" action if text is selected
        // Keep native suggested actions intact so spelling replacement can work.
        var menuChildren: [UIMenuElement] = suggestedActions
        
        // Get selected text
        if let selectedTextRange = self.selectedTextRange {
            let selectedText = self.text(in: selectedTextRange)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            // Only add glossary option if text is selected and not empty
            if !selectedText.isEmpty {
                if onGlossaryAddRequested != nil {
                    let addToGlossaryAction = UIAction(
                        title: NSLocalizedString("insertMenu.addGlossaryTerm", comment: "Add to Glossary"),
                        image: UIImage(systemName: "text.book.closed.fill"),
                        handler: { [weak self] _ in
                            self?.onGlossaryAddRequested?(selectedText)
                        }
                    )
                    menuChildren.append(addToGlossaryAction)
                }

                // Feature 033: Add "Add to Index" action
                if onIndexAddRequested != nil {
                    let addToIndexAction = UIAction(
                        title: NSLocalizedString("insertMenu.addIndexEntry", comment: "Add to Index"),
                        image: UIImage(systemName: "list.number"),
                        handler: { [weak self] _ in
                            self?.onIndexAddRequested?(selectedText)
                        }
                    )
                    menuChildren.append(addToIndexAction)
                }
            }
        }
        
        return UIMenu(children: menuChildren)
    }
    
    // Update selection border position when layout changes (e.g., rotation)
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // If we have a visible selection border and an image is selected, recalculate its position
        if isImageSelected && !selectionBorderView.isHidden {
            recalculateSelectionBorder()
        }
    }

    private func hasOnlyInvisiblePlaceholderText() -> Bool {
        let length = textStorage.length
        guard length > 0 else { return true }

        let text = textStorage.string as NSString
        for location in 0..<length {
            let character = text.character(at: location)
            if character == 0x200B {
                continue
            }

            guard let scalar = UnicodeScalar(Int(character)),
                  CharacterSet.whitespacesAndNewlines.contains(scalar) else {
                return false
            }
        }
        return true
    }
    
    // Custom drawing for empty document numbering (Feature 016)
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        // For empty documents (or documents with only invisible chars like zero-width space),
        // draw the number based on either the typingAttributes or the current style
        guard hasOnlyInvisiblePlaceholderText() else {
            return
        }
        
            guard let numberingLayoutManager = layoutManager as? NumberingLayoutManager,
              !numberingLayoutManager.isDecorativeDrawingSuppressed,
              let project = numberingLayoutManager.project,
              let styleSheet = project.styleSheet else {
            return
        }
        
        // First, check the typingAttributes for a numbered style (this handles the case
        // where user just applied a list style to an empty paragraph)
        var activeStyle: TextStyleModel? = nil
        
        if let styleName = typingAttributes[.textStyle] as? String,
           let style = styleSheet.style(named: styleName),
           style.numberFormat != .none {
            activeStyle = style
        }
        
        // If no numbered style in typing attributes, check the text storage attributes
        if activeStyle == nil && textStorage.length > 0 {
            let attrs = textStorage.attributes(at: 0, effectiveRange: nil)
            if let styleName = attrs[.textStyle] as? String,
               let style = styleSheet.style(named: styleName),
               style.numberFormat != .none {
                activeStyle = style
            }
        }
        
        // Finally, fall back to Body style (for legacy behavior)
        if activeStyle == nil,
           let bodyStyle = styleSheet.style(named: "UICTFontTextStyleBody"),
           bodyStyle.numberFormat != .none {
            activeStyle = bodyStyle
        }
        
        guard let style = activeStyle else {
            return
        }
        
        // Determine bullet level from style name for bullet lists
        let bulletLevel: Int
        if style.name.contains("level-3") { bulletLevel = 2 }
        else if style.name.contains("level-2") { bulletLevel = 1 }
        else { bulletLevel = 0 }
        
        // Format the number using the style's format and adornment
        let formattedNumber = style.numberFormat.symbol(for: 0, adornment: style.numberAdornment, level: bulletLevel)
        
        // Get font and color from style (matching NumberingLayoutManager approach)
        let font = style.generateFont(applyPlatformScaling: true)
        let color = style.textColor ?? UIColor.label
        
        // Build number attributes
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        
        let numberString = formattedNumber as NSString
        let numberSize = numberString.size(withAttributes: numberAttributes)
        
        // For list styles, position the number based on headIndent (matching NumberingLayoutManager)
        let numberX: CGFloat
        let gap: CGFloat = 4.0
        if style.styleCategory == .list {
            // List items: number goes just before headIndent position
            numberX = textContainerInset.left + style.headIndent - numberSize.width - gap
        } else {
            // Non-list numbered styles: draw at the start of the line
            // (matching NumberingLayoutManager.drawNumber which uses origin.x + lineFragmentRect.origin.x)
            numberX = textContainerInset.left + textContainer.lineFragmentPadding
        }
        
        let numberRect = CGRect(
            x: numberX,
            y: textContainerInset.top,
            width: numberSize.width,
            height: numberSize.height
        )
        
        numberString.draw(in: numberRect, withAttributes: numberAttributes)
    }
    
    // Hide the system formatting menu on iPad with hardware keyboard (iOS 13+)
    @available(iOS 13.0, *)
    override func buildMenu(with builder: UIMenuBuilder) {
        // If we want to hide the formatting menu, we need to remove the formatting actions
        if shouldHideSystemFormattingMenu {
            // Remove format submenu
            builder.remove(menu: .format)
        }
        
        super.buildMenu(with: builder)
    }
    
    private func recalculateSelectionBorder() {
        // Find the selected range
        let selectedRange = self.selectedRange
        guard selectedRange.length == 1 else { return }
        
        let position = selectedRange.location
        guard position < textStorage.length else { return }
        
        // Check if there's an attachment at this position
        guard let attachment = textStorage.attribute(.attachment, at: position, effectiveRange: nil) as? ImageAttachment else {
            return
        }
        
        // Recalculate the frame for the attachment
        let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: position, length: 1), actualCharacterRange: nil)
        let glyphBounds = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        
        // Size from the LIVE text-column width, matching attachmentBounds(for:).
        let availableWidth = ImageAttachment.availableWidth(for: textContainer)
        let imageSize = attachment.displaySize(forAvailableWidth: availableWidth)
        
        let adjustedBounds = CGRect(
            x: glyphBounds.origin.x + textContainerInset.left,
            y: glyphBounds.origin.y + textContainerInset.top,
            width: imageSize.width,
            height: imageSize.height
        )
        
        // Update the selection border frame
        selectionBorderView.frame = adjustedBounds
    }
}
