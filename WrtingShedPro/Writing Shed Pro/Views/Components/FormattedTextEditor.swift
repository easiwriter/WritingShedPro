import SwiftUI
import UIKit
import SwiftData

/// A SwiftUI wrapper around UITextView that supports rich text formatting with NSAttributedString
struct FormattedTextEditor: UIViewRepresentable {
    
    // MARK: - Bindings
    
    /// The attributed text content
    @Binding var attributedText: NSAttributedString
    
    /// The currently selected text range
    @Binding var selectedRange: NSRange
    
    /// Optional callback when text changes
    var onTextChange: ((NSAttributedString) -> Void)?
    
    /// Optional callback when selection changes
    var onSelectionChange: ((NSRange) -> Void)?
    
    /// Optional callback when user taps on an image
    var onImageTapped: ((ImageAttachment, CGRect, Int) -> Void)?
    
    /// Optional callback when image selection should be cleared (cursor moved away)
    var onClearImageSelection: (() -> Void)?
    
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
    
    /// Coordinator for managing textView reference
    var textViewCoordinator: TextViewCoordinator?
    
    /// Project reference for dynamic numbering (Feature 016)
    var project: Project?
    
    /// Whether to show invisible characters (spaces, tabs, paragraph marks, page breaks)
    var showInvisibles: Bool = false
    
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
        showInvisibles: Bool = false,
        font: UIFont = .preferredFont(forTextStyle: .body),
        textColor: UIColor = .label,
        backgroundColor: UIColor = .systemBackground,
        textContainerInset: UIEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8),
        isEditable: Bool = true,
        inputAccessoryView: UIView? = nil,
        onTextChange: ((NSAttributedString) -> Void)? = nil,
        onSelectionChange: ((NSRange) -> Void)? = nil,
        onImageTapped: ((ImageAttachment, CGRect, Int) -> Void)? = nil,
        onClearImageSelection: (() -> Void)? = nil,
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
        onShiftTabPressed: (() -> Void)? = nil
    ) {
        self._attributedText = attributedText
        self._selectedRange = selectedRange
        self.textViewCoordinator = textViewCoordinator
        self.project = project
        self.showInvisibles = showInvisibles
        self.font = font
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.textContainerInset = textContainerInset
        self.isEditable = isEditable
        self.inputAccessoryView = inputAccessoryView
        self.onTextChange = onTextChange
        self.onSelectionChange = onSelectionChange
        self.onImageTapped = onImageTapped
        self.onClearImageSelection = onClearImageSelection
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
    }
    
    // MARK: - UIViewRepresentable
    
    func makeUIView(context: Context) -> UITextView {
        // Create text storage, layout manager, and text container
        let textStorage = NSTextStorage()
        let layoutManager = NumberingLayoutManager() // Use custom layout manager for dynamic paragraph numbering
        let textContainer = NSTextContainer()
        
        // Pass project reference to layout manager for style information
        layoutManager.project = project
        layoutManager.showInvisibles = showInvisibles
        
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        
        // Create text view with our custom layout manager
        let textView = CustomTextView(frame: .zero, textContainer: textContainer)
        
        // Store reference to textView in coordinator (if provided)
        context.coordinator.textView = textView
        textViewCoordinator?.textView = textView
        
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
        
        // Wire up glossary add requested callback (Feature 029)
        textView.onGlossaryAddRequested = { [weak coordinator] selectedText in
            coordinator?.parent.onGlossaryAddRequested?(selectedText)
        }
        
        // Wire up index add requested callback (Feature 033)
        textView.onIndexAddRequested = { [weak coordinator] selectedText in
            coordinator?.parent.onIndexAddRequested?(selectedText)
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
        
        // Add extra left inset for paragraph numbers (Feature 016)
        var adjustedInset = textContainerInset
        // No extra margin on iPhone - text at left edge like original Writing Shed
        let numberMargin: CGFloat = UIDevice.current.userInterfaceIdiom == .phone ? 0 : 5
        adjustedInset.left += numberMargin
        textView.textContainerInset = adjustedInset
        
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isScrollEnabled = true
        
        // Disable autocorrect and text suggestions to prevent unwanted text insertion
        // This prevents iOS from inserting spaces when dismissing autocomplete
        textView.autocorrectionType = .no
        // Disable auto-capitalization for poetry projects (poets often use lowercase intentionally)
        textView.autocapitalizationType = (project?.type == .poetry) ? .none : .sentences
        textView.spellCheckingType = .yes  // Keep spell checking, just disable autocorrect
        
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
        let savedZoom = UserDefaults.standard.double(forKey: "textViewZoomFactor")
        if savedZoom > 0 {
            context.coordinator.currentZoomScale = CGFloat(savedZoom)
            textView.transform = CGAffineTransform(scaleX: context.coordinator.currentZoomScale, y: context.coordinator.currentZoomScale)
            #if DEBUG
            print("🔍 Loading saved zoom: \(savedZoom)")
            #endif
        } else {
            context.coordinator.currentZoomScale = 1.0
        }
        
        // Add pan gesture recognizer for drag scrolling (requires 2 fingers to avoid interfering with text selection)
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.minimumNumberOfTouches = 2
        panGesture.maximumNumberOfTouches = 2
        panGesture.delegate = context.coordinator
        textView.addGestureRecognizer(panGesture)
        
        // Configure for rich text
        // On iPad with hardware keyboard, disable system editing attributes to prevent the formatting menu
        #if os(iOS)
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
        
        // Set initial content - this should be done AFTER layout configuration
        textView.attributedText = attributedText
        
        // Initialize previousTextLength for paste detection
        context.coordinator.previousTextLength = attributedText.length
        
        // Update caption numbers for image attachments (Feature 016)
        // This must be done after setting the attributed text
        ImageAttachment.updateCaptionNumbers(in: textView.textStorage, styleSheet: project?.styleSheet)
        
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
        
        // Set initial selection
        if selectedRange.location != NSNotFound && selectedRange.location <= attributedText.length {
            textView.selectedRange = selectedRange
        }
        
        // Handle keyboard notifications
        setupKeyboardNotifications(for: textView, coordinator: context.coordinator)
        
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        let updateStart = CFAbsoluteTimeGetCurrent()
        
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
        }
        
        // Update show invisibles flag on layout manager
        if let layoutManager = textView.layoutManager as? NumberingLayoutManager,
           layoutManager.showInvisibles != showInvisibles {
            layoutManager.showInvisibles = showInvisibles
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
            textView.attributedText = attributedText
            return
        }
        
        let textViewString = textViewAttrs.string
        let newString = attributedText.string
        let stringsMatch = textViewString == newString
        
        // PERFORMANCE FIX: Only update text storage if text content actually changed
        // The expensive isEqual(to:) comparison was causing update loops with large documents
        // because it compares every attribute of every character (O(n) where n = length × attributes)
        // and dictionary key ordering differences caused false positives.
        // For attribute-only updates from formatting, textViewDidChange will handle it.
        if !stringsMatch {
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
            
            // Update text storage directly for better control
            // This ensures attributes are properly applied
            textView.textStorage.setAttributedString(attributedText)
            
            // Update previousTextLength after programmatic updates to avoid false paste detection
            context.coordinator.previousTextLength = attributedText.length
            
            // Update caption numbers for image attachments (Feature 016)
            // This must be done after setting the attributed string
            ImageAttachment.updateCaptionNumbers(in: textView.textStorage, styleSheet: project?.styleSheet)
            
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
                let imageSize = attachment.bounds.size
                
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
            
            // Also update selection when content changed (e.g., after undo/redo)
            if textView.selectedRange != selectedRange && selectedRange.location != NSNotFound {
                if selectedRange.location <= textView.attributedText.length {
                    textView.selectedRange = selectedRange
                }
            }
        } // End of if !stringsMatch
        
        // Update appearance properties (always, regardless of content changes)
        // NOTE: Don't set textView.textColor - it overrides attributed string colors!
        // Colors should come from the attributed string's .foregroundColor attribute
        textView.backgroundColor = backgroundColor
        
        // Add extra left inset for paragraph numbers (Feature 016)
        var adjustedInset = textContainerInset
        // No extra margin on iPhone - text at left edge like original Writing Shed
        let numberMargin: CGFloat = UIDevice.current.userInterfaceIdiom == .phone ? 0 : 5
        adjustedInset.left += numberMargin
        textView.textContainerInset = adjustedInset
        
        textView.isEditable = isEditable
        
        // Ensure autocorrect stays disabled
        textView.autocorrectionType = .no
        textView.spellCheckingType = .yes
        
        let updateTime = CFAbsoluteTimeGetCurrent() - updateStart
        #if DEBUG
        if updateTime > 0.01 { // Only print if > 10ms
            print("📝 updateUIView took: \(String(format: "%.3f", updateTime))s")
        }
        #endif
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Private Methods
    
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
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: FormattedTextEditor
        var isUpdatingFromSwiftUI = false
        weak var textView: UITextView?
        var previousSelection: NSRange = NSRange(location: 0, length: 0)
        var previousTextLength: Int = 0  // Track text length to detect paste operations
        var currentZoomScale: CGFloat = 1.0
        
        init(_ parent: FormattedTextEditor) {
            self.parent = parent
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        // MARK: - UITextViewDelegate
        
        // Intercept text changes to handle Enter key and ensure correct styling
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
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
                    }
                    
                    // If we have a follow-on style, manually insert the newline with correct attributes
                    if useFollowOnStyle {
                        // Insert newline with CURRENT style (end of current paragraph)
                        let currentAttrs = attrText.attributes(at: range.location > 0 ? range.location - 1 : 0, effectiveRange: nil)
                        
                        // Create attributed string: newline (with current style) + zero-width space (with follow-on style)
                        // The zero-width space anchors the new paragraph's style
                        let mutableString = NSMutableAttributedString()
                        mutableString.append(NSAttributedString(string: "\n", attributes: currentAttrs))
                        mutableString.append(NSAttributedString(string: "\u{200B}", attributes: attrs)) // Zero-width space with follow-on style
                        
                        // Insert at the specified range
                        textView.textStorage.replaceCharacters(in: range, with: mutableString)
                        
                        // Move cursor to after the zero-width space (so user types after it)
                        let newCursorPosition = range.location + 2
                        textView.selectedRange = NSRange(location: newCursorPosition, length: 0)
                        
                        // Set typingAttributes to follow-on style for continued typing
                        textView.typingAttributes = attrs
                        
                        // Fix stale .textStyle on the character now after the insertion
                        // (e.g., an old \n that still carries a different numbered style)
                        if let followOnStyleName = attrs[.textStyle] as? String,
                           newCursorPosition < textView.textStorage.length {
                            let nextAttrs = textView.textStorage.attributes(at: newCursorPosition, effectiveRange: nil)
                            if let nextStyle = nextAttrs[.textStyle] as? String,
                               nextStyle != followOnStyleName {
                                textView.textStorage.addAttribute(.textStyle, value: followOnStyleName, range: NSRange(location: newCursorPosition, length: 1))
                            }
                        }
                        
                        // Force layout manager to redraw numbers from insertion point
                        textView.setNeedsDisplay()
                        if let layoutManager = textView.layoutManager as? NumberingLayoutManager {
                            // PERFORMANCE FIX: Only invalidate from the insertion point onwards
                            let invalidateStart = max(0, range.location - 1)
                            let invalidateRange = NSRange(location: invalidateStart, length: textView.textStorage.length - invalidateStart)
                            layoutManager.invalidateDisplay(forCharacterRange: invalidateRange)
                        }
                        
                        // Notify delegate of text change manually since we handled it
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
                        
                        let mutableString = NSMutableAttributedString()
                        mutableString.append(NSAttributedString(string: "\n", attributes: currentAttrs))
                        mutableString.append(NSAttributedString(string: "\u{200B}", attributes: attrs)) // ZWS anchors the style
                        
                        textView.textStorage.replaceCharacters(in: range, with: mutableString)
                        
                        let newCursorPosition = range.location + 2
                        textView.selectedRange = NSRange(location: newCursorPosition, length: 0)
                        textView.typingAttributes = attrs
                        
                        // Fix stale .textStyle on the character now after the insertion
                        if let numberedStyleName = attrs[.textStyle] as? String,
                           newCursorPosition < textView.textStorage.length {
                            let nextAttrs = textView.textStorage.attributes(at: newCursorPosition, effectiveRange: nil)
                            if let nextStyle = nextAttrs[.textStyle] as? String,
                               nextStyle != numberedStyleName {
                                textView.textStorage.addAttribute(.textStyle, value: numberedStyleName, range: NSRange(location: newCursorPosition, length: 1))
                            }
                        }
                        
                        textView.setNeedsDisplay()
                        if let layoutManager = textView.layoutManager as? NumberingLayoutManager {
                            // PERFORMANCE FIX: Only invalidate from the insertion point onwards
                            let invalidateStart = max(0, range.location - 1)
                            let invalidateRange = NSRange(location: invalidateStart, length: textView.textStorage.length - invalidateStart)
                            layoutManager.invalidateDisplay(forCharacterRange: invalidateRange)
                        }
                        
                        self.textViewDidChange(textView)
                        return false
                    }
                    
                    // No follow-on style and no numbering - handle insertion manually
                    // to ensure correct .textStyle on the newline and fix stale styles
                    // on any existing \n that follows (which could cause ghost numbers)
                    
                    // Insert newline with current paragraph's attributes
                    let newlineString = NSAttributedString(string: "\n", attributes: attrs)
                    textView.textStorage.replaceCharacters(in: range, with: newlineString)
                    
                    // Move cursor after the new \n
                    let newCursorPosition = range.location + 1
                    textView.selectedRange = NSRange(location: newCursorPosition, length: 0)
                    textView.typingAttributes = attrs
                    
                    // Fix stale .textStyle on the character now at the cursor position
                    // (e.g., an old \n from a follow-on that still carries a numbered style)
                    if let currentStyle = attrs[.textStyle] as? String,
                       newCursorPosition < textView.textStorage.length {
                        let nextAttrs = textView.textStorage.attributes(at: newCursorPosition, effectiveRange: nil)
                        if let nextStyle = nextAttrs[.textStyle] as? String,
                           nextStyle != currentStyle {
                            textView.textStorage.addAttribute(.textStyle, value: currentStyle, range: NSRange(location: newCursorPosition, length: 1))
                        }
                    }
                    
                    // Force layout manager to redraw numbers from insertion point
                    textView.setNeedsDisplay()
                    if let layoutManager = textView.layoutManager as? NumberingLayoutManager {
                        // PERFORMANCE FIX: Only invalidate from the insertion point onwards
                        let invalidateStart = max(0, range.location - 1)
                        let invalidateRange = NSRange(location: invalidateStart, length: textView.textStorage.length - invalidateStart)
                        layoutManager.invalidateDisplay(forCharacterRange: invalidateRange)
                    }
                    
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
                                    self.textViewDidChange(textView)
                                    
                                    // Force layout redraw from deletion point
                                    textView.setNeedsDisplay()
                                    if let layoutManager = textView.layoutManager as? NumberingLayoutManager {
                                        // PERFORMANCE FIX: Only invalidate from deletion point onwards
                                        let invalidateStart = max(0, range.location - 1)
                                        let invalidateRange = NSRange(location: invalidateStart, length: textView.textStorage.length - invalidateStart)
                                        layoutManager.invalidateDisplay(forCharacterRange: invalidateRange)
                                    }
                                    
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
                        var referencesToDelete: [ReferenceAttachment] = []
                        var commentsToDelete: [CommentAttachment] = []
                        var footnotesToDelete: [FootnoteAttachment] = []
                        var seenAttachments = Set<ObjectIdentifier>()
                        
                        attrText.enumerateAttribute(.attachment, in: range, options: []) { value, _, _ in
                            // Check for ReferenceAttachment (notes, glossary, references)
                            if let attachment = value as? ReferenceAttachment {
                                let identifier = ObjectIdentifier(attachment)
                                guard !seenAttachments.contains(identifier) else { return }
                                seenAttachments.insert(identifier)
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

                        // Count how many different types of attachments are being deleted
                        let typesFound = [!referencesToDelete.isEmpty, !commentsToDelete.isEmpty, !footnotesToDelete.isEmpty].filter { $0 }.count
                        
                        // If multiple types are found, use unified callback
                        if typesFound > 1 {
                            #if DEBUG
                            print("🗑️ Mixed attachments found: \(referencesToDelete.count) references, \(commentsToDelete.count) comments, \(footnotesToDelete.count) footnotes - using unified handler")
                            #endif
                            
                            parent.onMixedAttachmentsDeleted?(referencesToDelete, commentsToDelete, footnotesToDelete, range)
                            return false
                        }
                        
                        // Handle references being deleted (single type)
                        if !referencesToDelete.isEmpty {
                            #if DEBUG
                            print("🗑️ \(referencesToDelete.count) references found in deletion range - showing confirmation")
                            #endif
                           
                            // Prevent the deletion for now - we'll handle it after user confirms
                            parent.onReferenceDeleted?(referencesToDelete, range)
                           
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
            
            #if DEBUG
            print("📝 textViewDidChange called - text: '\(textView.attributedText?.string.prefix(50) ?? "")'")
            
            // Log color information at the start of text
            if let attrText = textView.attributedText, attrText.length > 0 {
                let attrs = attrText.attributes(at: 0, effectiveRange: nil)
                if let color = attrs[.foregroundColor] as? UIColor {
                    print("   Text has color at position 0: \(color.toHex() ?? "unknown")")
                } else {
                    print("   Text has NO color at position 0 (will use default)")
                }
            }
            
            // Log current typing attributes
            print("   Current typingAttributes:")
            if let color = textView.typingAttributes[.foregroundColor] as? UIColor {
                print("      foregroundColor: \(color.toHex() ?? "unknown")")
            } else {
                print("      foregroundColor: NONE")
            }
            #endif
            
            // Detect paste operation: more than 1 character was inserted
            let textStorage = textView.textStorage
            let cursorPos = textView.selectedRange.location
            let currentLength = textStorage.length
            let insertedLength = currentLength - previousTextLength
            
            // PASTE FIX: If multiple characters were inserted, normalize colors for the entire range
            // This handles pasted text that may have hardcoded black color from external sources
            if insertedLength > 1 && cursorPos >= insertedLength {
                let pasteStartPos = cursorPos - insertedLength
                let pasteRange = NSRange(location: pasteStartPos, length: insertedLength)
                
                #if DEBUG
                print("📋 Paste detected: \(insertedLength) characters inserted at position \(pasteStartPos)")
                #endif
                
                // Enumerate through the pasted range and fix colors
                textStorage.enumerateAttribute(.foregroundColor, in: pasteRange, options: []) { value, range, _ in
                    if let color = value as? UIColor {
                        // Check if it's pure black - replace with .label for dark mode compatibility
                        if let hex = color.toHex()?.uppercased(),
                           (hex == "#000000" || hex == "#000000FF") {
                            textStorage.addAttribute(.foregroundColor, value: UIColor.label, range: range)
                            #if DEBUG
                            print("📋 Fixed black color in pasted text at range \(range)")
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
                
                // Also ensure .textStyle is set for pasted content
                textStorage.enumerateAttribute(.textStyle, in: pasteRange, options: []) { value, range, _ in
                    if value == nil {
                        textStorage.addAttribute(.textStyle, value: UIFont.TextStyle.body.rawValue, range: range)
                    }
                }
            } else if currentLength > 0 && cursorPos > 0 && cursorPos <= currentLength {
                // PERFORMANCE FIX: Only check .textStyle at cursor position, not the entire document
                // UITextView sometimes strips this when typing, so reapply it
                // The old approach enumerated the entire document twice per keystroke - very slow
                
                // Only check the character just typed (at cursor - 1)
                let checkPos = cursorPos - 1
                if textStorage.attribute(.textStyle, at: checkPos, effectiveRange: nil) == nil {
                    // Find style from previous character
                    var styleToApply: String = UIFont.TextStyle.body.rawValue
                    if checkPos > 0 {
                        if let prevStyle = textStorage.attribute(.textStyle, at: checkPos - 1, effectiveRange: nil) as? String {
                            styleToApply = prevStyle
                            #if DEBUG
                            print("⚠️ Text missing .textStyle at range {\(checkPos), 1} - inheriting from previous char: \(prevStyle)")
                            #endif
                        }
                    }
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
                        #if DEBUG
                        print("⚠️ Text had black color at {\(checkPos), 1} - replaced with .label for dark mode")
                        #endif
                    }
                } else {
                    // No color attribute - add .label for proper dark mode support
                    textStorage.addAttribute(.foregroundColor, value: UIColor.label, range: NSRange(location: checkPos, length: 1))
                    #if DEBUG
                    print("⚠️ Text missing foregroundColor at {\(checkPos), 1} - added .label")
                    #endif
                }
            }
            
            // Update previous text length for next change detection
            previousTextLength = currentLength
            
            // Update the binding so SwiftUI state stays in sync
            // Update if either content OR formatting changed
            if let attributedText = textView.attributedText {
                // Always update - could be text change or formatting change
                #if DEBUG
                print("📝 Text or formatting changed - updating binding")
                print("📝 Binding will be set to: '\(attributedText.string.prefix(50))'")
                #endif
                parent.attributedText = attributedText
                parent.onTextChange?(attributedText)
                #if DEBUG
                print("📝 Binding updated successfully")
                #endif
            }
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isUpdatingFromSwiftUI else { return }
            
            // PERFORMANCE FIX: Removed ensureLayout(for: textContainer) which was called on every
            // selection change (including every keystroke). This forced layout of the entire document.
            // UITextView already ensures layout is valid around the cursor position when needed.
            
            let newRange = textView.selectedRange
            let textLength = textView.attributedText?.length ?? 0
            
            #if DEBUG
            print("📍 textViewDidChangeSelection: position=\(newRange.location), length=\(newRange.length), textLength=\(textLength)")
            #endif
            
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
                    
                    #if DEBUG
                    print("📍 Checking character at \(newRange.location), nsString.length=\(nsStringLength), attributedText.length=\(attributedText.length)")
                    #endif
                    
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
                        #if DEBUG
                        print("📍 Cursor on zero-width space at position \(newRange.location)")
                        #endif
                        
                        // Determine direction: are we moving forward or backward?
                        let movingForward = newRange.location > previousSelection.location
                        
                        if movingForward {
                            // Moving forward (right arrow) - skip to next position
                            #if DEBUG
                            print("📍 Moving forward - skipping to position \(newRange.location + 1)")
                            #endif
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
                            #if DEBUG
                            print("📍 Moving backward - checking for image before zero-width space")
                            #endif
                            
                            // Check position - 2 for image (skip newline at position - 1)
                            let imagePosition = newRange.location - 2
                            if imagePosition >= 0,
                               let attributedText = textView.attributedText,
                               attributedText.attribute(.attachment, at: imagePosition, effectiveRange: nil) is ImageAttachment {
                                
                                #if DEBUG
                                print("📍 Found image at position \(imagePosition) - selecting it")
                                #endif
                                
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
                #if DEBUG
                print("📍 Checking position \(newRange.location): has attachment? \(textView.attributedText?.attribute(.attachment, at: newRange.location, effectiveRange: nil) != nil)")
                #endif
                
                // Get the character at the cursor position to check for attachment
                if let attributedText = textView.attributedText {
                    // Note: Comment taps are now handled by CustomTextView tap gesture
                    // This ensures direct clicking on comments opens them immediately
                    
                    // Check for image attachment
                    if let _ = attributedText.attribute(.attachment, at: newRange.location, effectiveRange: nil) as? ImageAttachment {
                    
                    // Check if this image was already selected (previous selection was length=1 at this position)
                    // If so, move BEFORE the image instead of re-selecting it
                    if previousSelection.length == 1 && previousSelection.location == newRange.location {
                        #if DEBUG
                        print("📍 Image was already selected - moving before it to position \(newRange.location - 1)")
                        #endif
                        
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
                    
                    #if DEBUG
                    print("📍 Cursor navigated to image at position \(newRange.location) - selecting it")
                    #endif
                    
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
                #if DEBUG
                print("📍 Cursor moved away from image - clearing selection")
                #endif
                
                // Check if moving forward from image - if so, skip past the newline and zero-width space
                let movingForward = newRange.location > previousSelection.location
                if movingForward {
                    // Moving forward from image position (e.g., from position 2 to 3)
                    // We want to skip: position 3 (newline) and position 4 (zero-width space)
                    // and go directly to position 5
                    let targetPosition = previousSelection.location + 3  // Skip image (1) + newline (1) + zero-width space (1)
                    if targetPosition < textView.attributedText.length {
                        #if DEBUG
                        print("📍 Moving forward from image - skipping to position \(targetPosition)")
                        #endif
                        
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
                #if DEBUG
                print("📍 Cursor visibility restored")
                #endif
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
                #if DEBUG
                print("📍 Cursor visibility restored, moved to position \(newRange.location)")
                #endif
            }
            
            // Update stored previous selection
            previousSelection = newRange
            
            // Check if position is out of bounds
            if newRange.location >= textLength {
                #if DEBUG
                print("📍 Position \(newRange.location) >= textLength \(textLength), skipping image check")
                #endif
                DispatchQueue.main.async {
                    self.parent.selectedRange = newRange
                    self.parent.onSelectionChange?(newRange)
                }
                #if DEBUG
                print("📍 Selection changed to: \(newRange)")
                #endif
                return
            }
            
            // If we have a length-1 range (which happens when image is selected),
            // don't process further - the image is already selected
            if newRange.length == 1 {
                #if DEBUG
                print("📍 Range has length 1, skipping image check")
                #endif
                DispatchQueue.main.async {
                    self.parent.selectedRange = newRange
                    self.parent.onSelectionChange?(newRange)
                }
                #if DEBUG
                print("📍 Selection changed to: \(newRange)")
                #endif
                return
            }
            
            // Normal cursor movement - update binding
            // Sync typing attributes to match cursor position paragraph style
            self.syncTypingAttributesForCursorPosition(textView, at: newRange.location)
            
            DispatchQueue.main.async {
                self.parent.selectedRange = newRange
                self.parent.onSelectionChange?(newRange)
            }
            #if DEBUG
            print("📍 Selection changed to: \(newRange)")
            #endif
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
            
            // Use the attachment's actual bounds for accurate size
            let imageSize = attachment.bounds.size
            
            // Calculate position from glyph bounds, but use attachment size
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
            
            // Use the attachment's actual bounds for accurate size
            // The attachment.bounds has the correct displaySize based on scale
            let imageSize = attachment.bounds.size
            
            // Calculate position from glyph bounds, but use attachment size
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
        /// This prevents text typed after special paragraphs (like after images) from inheriting
        /// unwanted alignment or other paragraph properties
        private func syncTypingAttributesForCursorPosition(_ textView: UITextView, at position: Int) {
            guard let attributedText = textView.attributedText, position >= 0, position <= attributedText.length else {
                return
            }
            
            // Always reset typing attributes to default paragraph style
            // This ensures text typed at any position uses body text alignment
            let defaultStyle = NSMutableParagraphStyle()
            defaultStyle.alignment = .natural  // Reset to natural/left alignment
            defaultStyle.lineHeightMultiple = 1.0
            
            // Get current typing attributes and update paragraph style
            var typingAttrs = textView.typingAttributes
            typingAttrs[.paragraphStyle] = defaultStyle
            
            textView.typingAttributes = typingAttrs
            
            #if DEBUG
            print("🎯 Synced typing attributes at position \(position): alignment=.natural")
            #endif
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
                
            case .ended, .cancelled:
                // Update current scale and save to UserDefaults
                let scaleDelta = (gesture.scale - 1.0) * 0.4
                let newScale = currentZoomScale * (1.0 + scaleDelta)
                currentZoomScale = max(0.5, min(3.0, newScale))
                
                // Apply final transform
                textView.transform = CGAffineTransform(scaleX: currentZoomScale, y: currentZoomScale)
                
                // Save zoom factor to UserDefaults
                UserDefaults.standard.set(Double(currentZoomScale), forKey: "textViewZoomFactor")
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

/// Custom UITextView subclass to support inputAccessoryView
private class CustomTextView: UITextView, UIGestureRecognizerDelegate {
    var customAccessoryView: UIView?
    var isImageSelected: Bool = false
    var shouldHideSystemFormattingMenu: Bool = false
    var onCommentTapped: ((CommentAttachment, Int) -> Void)?
    var onFootnoteTapped: ((FootnoteAttachment, Int) -> Void)?
    var onReferenceTapped: ((ReferenceAttachment, Int) -> Void)?
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
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            guard let key = press.key else { continue }
            
            #if DEBUG
            print("⌨️ pressesBegan - keyCode: \(key.keyCode), modifiers: \(key.modifierFlags), characters: '\(key.characters)'")
            #endif
            
            // Check for Shift+Tab (keyCode .keyboardTab with shift modifier)
            if key.keyCode == .keyboardTab && key.modifierFlags.contains(.shift) {
                #if DEBUG
                print("⌨️ pressesBegan intercepted Shift+Tab - onShiftTabPressed is \(onShiftTabPressed != nil ? "set" : "nil")")
                #endif
                if onShiftTabPressed != nil {
                    onShiftTabPressed?()
                    return  // Don't call super, we handled it
                }
            }
        }
        super.pressesBegan(presses, with: event)
    }
    
    // MARK: - Text Input Interception (Mac Catalyst Tab handling)
    
    /// Override insertText to intercept Tab key on Mac Catalyst
    /// UIKeyCommand doesn't reliably intercept Tab in UITextView on Catalyst
    override func insertText(_ text: String) {
        #if DEBUG
        // Log special characters
        if text.count == 1, let scalar = text.unicodeScalars.first, scalar.value < 32 || scalar.value == 127 {
            print("⌨️ insertText - control character: \\u{\(String(format: "%04X", scalar.value))}")
        }
        #endif
        
        // Check for backtab character (ASCII 25, sent by some systems for Shift+Tab)
        if text == "\u{0019}" || text == "\u{000F}" {
            #if DEBUG
            print("⌨️ insertText intercepted backtab character - onShiftTabPressed is \(onShiftTabPressed != nil ? "set" : "nil")")
            #endif
            if onShiftTabPressed != nil {
                onShiftTabPressed?()
                return
            }
        }
        
        if text == "\t" {
            #if DEBUG
            print("⌨️ insertText intercepted Tab - onTabPressed is \(onTabPressed != nil ? "set" : "nil")")
            #endif
            // Call our Tab handler instead of inserting a tab character
            if onTabPressed != nil {
                onTabPressed?()
                #if DEBUG
                print("⌨️ insertText - returning WITHOUT inserting tab")
                #endif
                return
            }
            #if DEBUG
            print("⌨️ WARNING: onTabPressed is nil, will insert tab!")
            #endif
        }
        #if DEBUG
        if text == "\t" {
            print("⌨️ CRITICAL: super.insertText called for Tab - this is a bug!")
        }
        #endif
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
        return super.selectionRects(for: range)
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
        
        // Disable selection actions when image is selected (except cut/delete for removal)
        if isImageSelected {
            if action == #selector(UIResponderStandardEditActions.delete(_:)) ||
               action == #selector(UIResponderStandardEditActions.cut(_:)) {
                return true
            }
            return false
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
    
    /// Override copy to strip reference attachments and inform user
    @objc override func copy(_ sender: Any?) {
        let nsRange = selectedRange
        guard nsRange.length > 0 else {
            super.copy(sender)
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
                let addToGlossaryAction = UIAction(
                    title: NSLocalizedString("insertMenu.addGlossaryTerm", comment: "Add to Glossary"),
                    image: UIImage(systemName: "text.book.closed.fill"),
                    handler: { [weak self] _ in
                        self?.onGlossaryAddRequested?(selectedText)
                    }
                )
                menuChildren.append(addToGlossaryAction)
                
                // Feature 033: Add "Add to Index" action
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
    
    // Custom drawing for empty document numbering (Feature 016)
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        #if DEBUG
        print("🎨 CustomTextView.draw() called, textStorage.length: \(textStorage.length)")
        #endif
        
        // For empty documents (or documents with only invisible chars like zero-width space),
        // draw the number based on either the typingAttributes or the current style
        guard textStorage.length == 0 || textStorage.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        guard let numberingLayoutManager = layoutManager as? NumberingLayoutManager,
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
        
        #if DEBUG
        print("🎨 Drawing number for empty document with style: \(style.name)")
        print("   textContainerInset: \(textContainerInset)")
        #endif
        
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
        
        #if DEBUG
        print("   Drew number '\(formattedNumber)' in rect: \(numberRect)")
        #endif
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
        
        let adjustedBounds = CGRect(
            x: glyphBounds.origin.x + textContainerInset.left,
            y: glyphBounds.origin.y + textContainerInset.top,
            width: attachment.bounds.size.width,
            height: attachment.bounds.size.height
        )
        
        // Update the selection border frame
        selectionBorderView.frame = adjustedBounds
    }
}
