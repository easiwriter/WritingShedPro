import SwiftUI
import UIKit

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
    
    /// Coordinator for managing textView reference
    var textViewCoordinator: TextViewCoordinator?
    
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
        font: UIFont = .preferredFont(forTextStyle: .body),
        textColor: UIColor = .label,
        backgroundColor: UIColor = .systemBackground,
        textContainerInset: UIEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8),
        isEditable: Bool = true,
        inputAccessoryView: UIView? = nil,
        onTextChange: ((NSAttributedString) -> Void)? = nil,
        onSelectionChange: ((NSRange) -> Void)? = nil
    ) {
        self._attributedText = attributedText
        self._selectedRange = selectedRange
        self.textViewCoordinator = textViewCoordinator
        self.font = font
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.textContainerInset = textContainerInset
        self.isEditable = isEditable
        self.inputAccessoryView = inputAccessoryView
        self.onTextChange = onTextChange
        self.onSelectionChange = onSelectionChange
    }
    
    // MARK: - UIViewRepresentable
    
    func makeUIView(context: Context) -> UITextView {
        let textView = CustomTextView() // Use custom subclass to support inputAccessoryView
        
        // Store reference to textView in coordinator (if provided)
        context.coordinator.textView = textView
        textViewCoordinator?.textView = textView
        
        // Set input accessory view if provided
        if let accessoryView = inputAccessoryView {
            textView.customAccessoryView = accessoryView
        }
        
        // Configure appearance
        // NOTE: Don't set textView.font or textView.textColor - they override attributed string attributes!
        // The font and textColor parameters are only used for fallback in typing attributes
        textView.backgroundColor = backgroundColor
        textView.textContainerInset = textContainerInset
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isScrollEnabled = true
        
        // Disable autocorrect and text suggestions to prevent unwanted text insertion
        // This prevents iOS from inserting spaces when dismissing autocomplete
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .sentences
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
        
        // Configure for rich text
        textView.allowsEditingTextAttributes = true
        
        // Set initial content - this should be done AFTER layout configuration
        textView.attributedText = attributedText
        
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
        print("📝 updateUIView called")
        print("📝 isUpdatingFromSwiftUI: \(context.coordinator.isUpdatingFromSwiftUI)")
        
        // Skip if we're already in the middle of an update to prevent feedback loops
        guard !context.coordinator.isUpdatingFromSwiftUI else {
            print("📝 Skipping - already updating from SwiftUI")
            return
        }
        
        print("📝 Current text: '\(textView.attributedText.string.prefix(50))'")
        print("📝 New text: '\(attributedText.string.prefix(50))'")
        
        // Check if attributed text actually changed (either content OR formatting)
        // We need to update if either the string OR the attributes changed
        guard let textViewAttrs = textView.attributedText else {
            // If textView has no attributed text, we definitely need to update
            print("📝 Text view has no attributed text - updating")
            context.coordinator.isUpdatingFromSwiftUI = true
            defer {
                print("📝 Reset isUpdatingFromSwiftUI flag")
                context.coordinator.isUpdatingFromSwiftUI = false
            }
            textView.attributedText = attributedText
            return
        }
        
        let textViewString = textViewAttrs.string
        let newString = attributedText.string
        let stringsMatch = textViewString == newString
        
        // If strings match, check if attributes changed
        let attributesChanged = !stringsMatch || !textViewAttrs.isEqual(to: attributedText)
        
        #if DEBUG
        print("📝 Strings match: \(stringsMatch)")
        print("📝 Attributes changed: \(attributesChanged)")
        if stringsMatch && attributesChanged && textViewAttrs.length > 0 && attributedText.length > 0 {
            print("📝 Current attributes at 0: \(textViewAttrs.attributes(at: 0, effectiveRange: nil))")
            print("📝 New attributes at 0: \(attributedText.attributes(at: 0, effectiveRange: nil))")
            if attributedText.length >= 11 {
                print("📝 New attributes at 10: \(attributedText.attributes(at: 10, effectiveRange: nil))")
            }
            // Log paragraph styles specifically
            if let currentPS = textViewAttrs.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle {
                print("📝 Current paragraph style at 0: alignment=\(currentPS.alignment.rawValue)")
            }
            if let newPS = attributedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle {
                print("📝 New paragraph style at 0: alignment=\(newPS.alignment.rawValue)")
            }
        }
        #endif
        
        if attributesChanged {
            if stringsMatch {
                print("📝 Formatting changed - updating attributes only")
            } else {
                print("📝 Content different - updating text view")
            }
            
            // Set flag to prevent feedback from delegate
            context.coordinator.isUpdatingFromSwiftUI = true
            
            let oldSelectedRange = textView.selectedRange
            
            // Update text storage directly for better control
            // This ensures attributes are properly applied
            textView.textStorage.setAttributedString(attributedText)
            
            #if DEBUG
            // Check if paragraph style survived the setAttributedString
            if textView.textStorage.length > 0 {
                if let ps = textView.textStorage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle {
                    print("📝 After setAttributedString, paragraph style at 0: alignment=\(ps.alignment.rawValue)")
                } else {
                    print("⚠️ After setAttributedString, NO paragraph style at 0!")
                }
            }
            #endif
            
            // Critical: Tell text storage that attributes changed
            textView.textStorage.edited(.editedAttributes, range: NSRange(location: 0, length: textView.textStorage.length), changeInLength: 0)
            
            // Invalidate layout and display FIRST
            let fullRange = NSRange(location: 0, length: textView.textStorage.length)
            textView.layoutManager.invalidateLayout(forCharacterRange: fullRange, actualCharacterRange: nil)
            textView.layoutManager.invalidateDisplay(forCharacterRange: fullRange)
            
            // THEN force layout update - this makes UITextView recalculate paragraph layout
            textView.layoutManager.ensureLayout(for: textView.textContainer)
            
            #if DEBUG
            // Check if paragraph style survived the layout operations
            if textView.textStorage.length > 0 {
                if let ps = textView.textStorage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle {
                    print("📝 After layout operations, paragraph style at 0: alignment=\(ps.alignment.rawValue)")
                } else {
                    print("⚠️ After layout operations, NO paragraph style at 0!")
                }
            }
            #endif
            
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
                        #if DEBUG
                        print("📝 Removed adaptive color \(color.toHex() ?? "nil") from typing attributes at position \(textView.selectedRange.location - 1)")
                        #endif
                    } else {
                        #if DEBUG
                        print("📝 Keeping explicit color \(color.toHex() ?? "nil") in typing attributes")
                        #endif
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
                        #if DEBUG
                        print("📝 Removed adaptive color from typing attributes at document start")
                        #endif
                    }
                }
                
                textView.typingAttributes = attrs
            }
            print("📝 Text view updated")
            
            // Reset flag after a short delay to allow delegate callbacks to settle
            DispatchQueue.main.async {
                context.coordinator.isUpdatingFromSwiftUI = false
                print("📝 Reset isUpdatingFromSwiftUI flag")
            }
            
            // Also update selection when content changed (e.g., after undo/redo)
            if textView.selectedRange != selectedRange && selectedRange.location != NSNotFound {
                print("📝 Updating selection to \(selectedRange) after content change")
                if selectedRange.location <= textView.attributedText.length {
                    textView.selectedRange = selectedRange
                }
            }
        } else {
            print("📝 Content identical - skipping text update")
            
            // IMPORTANT: If content unchanged, DON'T update selection
            // User is typing normally - let UITextView handle cursor naturally
        }
        
        // Update appearance properties
        // NOTE: Don't set textView.textColor - it overrides attributed string colors!
        // Colors should come from the attributed string's .foregroundColor attribute
        textView.backgroundColor = backgroundColor
        textView.textContainerInset = textContainerInset
        textView.isEditable = isEditable
        
        // Ensure autocorrect stays disabled
        textView.autocorrectionType = .no
        textView.spellCheckingType = .yes
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
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: FormattedTextEditor
        var isUpdatingFromSwiftUI = false
        weak var textView: UITextView?
        
        init(_ parent: FormattedTextEditor) {
            self.parent = parent
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        // MARK: - UITextViewDelegate
        
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
            
            // Update the binding so SwiftUI state stays in sync
            // Update if either content OR formatting changed
            if let attributedText = textView.attributedText {
                // Always update - could be text change or formatting change
                print("📝 Text or formatting changed - updating binding")
                parent.attributedText = attributedText
                parent.onTextChange?(attributedText)
            }
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isUpdatingFromSwiftUI else { return }
            
            // Ensure layout is complete before trusting the selection
            // This helps with tap-to-position accuracy
            textView.layoutManager.ensureLayout(for: textView.textContainer)
            
            let newRange = textView.selectedRange
            
            #if DEBUG
            print("📍 Selection changed to: {\(newRange.location), \(newRange.length)}")
            #endif
            
            // Check if we're selecting or near an image attachment
            checkForImageAttachment(at: newRange, in: textView)
            
            // Only update the binding if it actually changed
            // This prevents unnecessary view updates
            if parent.selectedRange.location != newRange.location || 
               parent.selectedRange.length != newRange.length {
                parent.selectedRange = newRange
            }
            
            // Also notify via callback
            parent.onSelectionChange?(newRange)
        }
        
        /// Check if the selection is on or near an image attachment
        private func checkForImageAttachment(at range: NSRange, in textView: UITextView) {
            guard let attributedText = textView.attributedText else { return }
            
            // Check multiple positions: selection start, selection end, and position before cursor
            let positionsToCheck = [
                range.location,
                range.location > 0 ? range.location - 1 : -1,
                range.location + range.length < attributedText.length ? range.location + range.length : -1
            ].compactMap { $0 >= 0 && $0 < attributedText.length ? $0 : nil }
            
            for position in positionsToCheck {
                let attrs = attributedText.attributes(at: position, effectiveRange: nil)
                if let attachment = attrs[.attachment] as? ImageAttachment {
                    print("🖼️ Image attachment found at position \(position)")
                    // Notify parent view through a callback
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ImageAttachmentSelected"),
                        object: nil,
                        userInfo: ["attachment": attachment, "position": position]
                    )
                    return
                }
            }
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // Don't allow changes while updating from SwiftUI
            if isUpdatingFromSwiftUI {
                return false
            }
            
            // If user is pressing Enter (newline)
            if text == "\n" {
                print("📝 ========== ENTER PRESSED ==========")
                print("📝 Range: \(range)")
                print("📝 Current selection: \(textView.selectedRange)")
                
                // Check if the character before cursor is an image attachment
                if range.location > 0,
                   let attributedText = textView.attributedText {
                    let checkPos = range.location - 1
                    let attrs = attributedText.attributes(at: checkPos, effectiveRange: nil)
                    
                    print("📝 Checking position \(checkPos) for attachment")
                    if let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle {
                        print("📝 Current paragraph style alignment: \(paragraphStyle.alignment.rawValue)")
                    }
                    
                    if attrs[.attachment] as? ImageAttachment != nil {
                        print("📝 ✅ Found image attachment before cursor")
                        print("📝 STRATEGY: Insert newline + invisible character with explicit left alignment")
                        
                        // Paragraph styles in iOS apply to the ENTIRE paragraph, not individual characters.
                        // The image has center alignment, which affects its whole paragraph.
                        // To create a NEW paragraph with left alignment, we need to:
                        // 1. Insert a newline to end the image's paragraph
                        // 2. Insert an invisible character (zero-width space) with EXPLICIT left alignment
                        //    to establish the new paragraph's style
                        
                        let defaultParagraphStyle = NSMutableParagraphStyle()
                        defaultParagraphStyle.alignment = .left
                        
                        // Get typing attributes but override paragraph style
                        var newParagraphAttrs = textView.typingAttributes
                        newParagraphAttrs[.paragraphStyle] = defaultParagraphStyle
                        
                        // Create newline + zero-width space with left alignment
                        // The zero-width space establishes the paragraph style
                        let newParagraphString = NSAttributedString(string: "\n\u{200B}", attributes: newParagraphAttrs)
                        
                        // Insert it
                        let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
                        mutableText.insert(newParagraphString, at: range.location)
                        
                        print("📝 Inserted newline + zero-width space with left alignment")
                        
                        // Update both text view and binding
                        textView.attributedText = mutableText
                        parent.attributedText = mutableText
                        
                        // Move cursor to after the zero-width space
                        textView.selectedRange = NSRange(location: range.location + 2, length: 0)
                        
                        print("📝 Cursor at position \(textView.selectedRange.location)")
                        print("📝 ========== END ==========")
                        
                        return false
                    } else {
                        print("📝 ❌ No image attachment found before cursor")
                    }
                }
                print("📝 ========== END (allowing default) ==========")
            }
            
            // Log text changes for debugging
            #if DEBUG
            if !text.isEmpty && text != "\n" {
                print("📝 shouldChange - range: \(range), text: '\(text)', length: \(text.count)")
            }
            #endif
            
            // Allow all user-initiated changes
            return true
        }
        
        // MARK: - Keyboard Notifications
        
        @objc func keyboardWillShow(_ notification: Notification) {
            // Handle keyboard appearance if needed
            // Can be used to adjust content insets or scroll position
        }
        
        @objc func keyboardWillHide(_ notification: Notification) {
            // Handle keyboard dismissal if needed
        }
    }
}

// MARK: - Custom UITextView

/// Custom UITextView subclass that supports a custom input accessory view  
/// We use an associated object pattern to work around inputAccessoryView being read-only
private class CustomTextView: UITextView {
    private static var customAccessoryViewKey: UInt8 = 0
    
    var customAccessoryView: UIView? {
        get {
            return objc_getAssociatedObject(self, &Self.customAccessoryViewKey) as? UIView
        }
        set {
            objc_setAssociatedObject(self, &Self.customAccessoryViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            reloadInputViews()
        }
    }
    
    override var inputAccessoryView: UIView? {
        get {
            // Return custom view if set, otherwise return an empty view to suppress system default
            if let customView = customAccessoryView {
                return customView
            }
            // Return an empty view with zero height to suppress the system's default input accessory
            let emptyView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
            emptyView.isHidden = true
            return emptyView
        }
        set { customAccessoryView = newValue }
    }
    
    // CRITICAL: Disable the shortcuts bar that appears on iPad with external keyboard
    override var inputAssistantItem: UITextInputAssistantItem {
        let item = super.inputAssistantItem
        item.leadingBarButtonGroups = []
        item.trailingBarButtonGroups = []
        return item
    }
    
    // Disable the editing menu (B/I/U/S) that appears above keyboard on iPad
    @available(iOS 16.0, macCatalyst 16.0, *)
    override var editingInteractionConfiguration: UIEditingInteractionConfiguration {
        return .none
    }
    
    // Completely disable the editing menu (the B/I/U/S popup)
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        // Check if this is the system's formatting menu
        // We want to disable formatting actions that appear in the menu above the keyboard
        let formattingActions: [Selector] = [
            #selector(toggleBoldface(_:)),
            #selector(toggleItalics(_:)),
            #selector(toggleUnderline(_:)),
            Selector(("_toggleStrikethrough:")),
            #selector(UIResponderStandardEditActions.increaseSize(_:)),
            #selector(UIResponderStandardEditActions.decreaseSize(_:))
        ]
        
        if formattingActions.contains(action) {
            return false
        }
        
        // Allow standard editing actions (cut, copy, paste, select, etc.)
        return super.canPerformAction(action, withSender: sender)
    }
    
    override func paste(_ sender: Any?) {
        print("📋 PASTE: Custom paste handler called")
        
        // Get the pasteboard content
        let pasteboard = UIPasteboard.general
        
        print("📋 PASTE: Available types: \(pasteboard.types)")
        
        // Try to get attributed string - check for RTFD first, then RTF, then plain text
        var attributedString: NSAttributedString?
        
        // Try RTFD (RTF with attachments) first
        if pasteboard.contains(pasteboardTypes: ["com.apple.flat-rtfd"]) {
            if let rtfdData = pasteboard.data(forPasteboardType: "com.apple.flat-rtfd") {
                print("📋 PASTE: Got RTFD data, length: \(rtfdData.count)")
                attributedString = try? NSAttributedString(
                    data: rtfdData,
                    options: [.documentType: NSAttributedString.DocumentType.rtfd],
                    documentAttributes: nil
                )
            }
        }
        
        // Try RTF if RTFD didn't work
        if attributedString == nil && pasteboard.contains(pasteboardTypes: ["public.rtf"]) {
            if let rtfData = pasteboard.data(forPasteboardType: "public.rtf") {
                print("📋 PASTE: Got RTF data, length: \(rtfData.count)")
                attributedString = try? NSAttributedString(
                    data: rtfData,
                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                    documentAttributes: nil
                )
            }
        }
        
        // Fallback: try string
        if attributedString == nil, let string = pasteboard.string {
            print("📋 PASTE: Got plain string, length: \(string.count)")
            attributedString = NSAttributedString(string: string)
        }
        
        if let attributedString = attributedString {
            print("📋 PASTE: Processing attributed string, length: \(attributedString.length)")
            
            // Walk through and fix any NSTextAttachment that should be ImageAttachment
            let mutableString = NSMutableAttributedString(attributedString: attributedString)
            var foundAttachments = false
            
            mutableString.enumerateAttribute(NSAttributedString.Key.attachment, in: NSRange(location: 0, length: mutableString.length)) { value, range, _ in
                if let attachment = value as? NSTextAttachment {
                    foundAttachments = true
                    print("📋 PASTE: Found attachment at \(range.location), type: \(type(of: attachment))")
                    
                    // Check if it's already an ImageAttachment
                    if let imageAttachment = attachment as? ImageAttachment {
                        print("📋 PASTE: Already an ImageAttachment - scale: \(imageAttachment.scale), alignment: \(imageAttachment.alignment)")
                        // Nothing to do, it's already our custom type
                    } else {
                        // It's a generic NSTextAttachment - try to decode it as an ImageAttachment
                        print("📋 PASTE: Attempting to decode ImageAttachment properties...")
                        
                        // Try to unarchive the attachment as an ImageAttachment to preserve properties
                        var restoredAttachment: ImageAttachment?
                        
                        // Try to get archived data from fileWrapper
                        if let fileWrapper = attachment.fileWrapper,
                           let data = fileWrapper.regularFileContents {
                            print("📋 PASTE: Found fileWrapper data (\(data.count) bytes)")
                            
                            // Try to unarchive as ImageAttachment
                            do {
                                if let unarchived = try NSKeyedUnarchiver.unarchivedObject(
                                    ofClass: ImageAttachment.self,
                                    from: data
                                ) {
                                    restoredAttachment = unarchived
                                    print("📋 PASTE: ✅ Successfully decoded ImageAttachment from fileWrapper!")
                                    print("📋 PASTE:    scale=\(unarchived.scale), alignment=\(unarchived.alignment)")
                                    print("📋 PASTE:    imageStyleName=\(unarchived.imageStyleName)")
                                }
                            } catch {
                                print("📋 PASTE: Could not unarchive as ImageAttachment: \(error)")
                            }
                        }
                        
                        // If we couldn't restore the ImageAttachment, create a new one from the image
                        if restoredAttachment == nil {
                            print("📋 PASTE: Creating new ImageAttachment from image data...")
                            var image: UIImage? = attachment.image
                            
                            // If image is nil, try to load from contents or fileWrapper
                            if image == nil, let contents = attachment.contents {
                                print("📋 PASTE: No .image, trying to load from contents (\(contents.count) bytes)")
                                image = UIImage(data: contents)
                            }
                            
                            if image == nil, let fileWrapper = attachment.fileWrapper, let data = fileWrapper.regularFileContents {
                                print("📋 PASTE: No .image, trying to load from fileWrapper (\(data.count) bytes)")
                                image = UIImage(data: data)
                            }
                            
                            if let image = image {
                                print("📋 PASTE: Image size: \(image.size)")
                                
                                // Create a new ImageAttachment with the image
                                let imageAttachment = ImageAttachment()
                                imageAttachment.image = image
                                
                                // Try to get the image data
                                if let imageData = image.jpegData(compressionQuality: 0.8) {
                                    imageAttachment.imageData = imageData
                                    print("📋 PASTE: Saved image data: \(imageData.count) bytes")
                                } else if let imageData = image.pngData() {
                                    imageAttachment.imageData = imageData
                                    print("📋 PASTE: Saved image data (PNG): \(imageData.count) bytes")
                                }
                                
                                // Use sensible defaults for pasted images
                                // Note: We use 0.25 (25%) as default since full-size images are usually too large
                                // The user can adjust via the image style settings if needed
                                imageAttachment.scale = 0.25
                                imageAttachment.alignment = .center
                                imageAttachment.imageStyleName = "Images" // Default style
                                imageAttachment.updateBounds()
                                
                                print("📋 PASTE: Created ImageAttachment with defaults: scale=\(imageAttachment.scale), alignment=\(imageAttachment.alignment)")
                                
                                restoredAttachment = imageAttachment
                            }
                        }
                        
                        // If we have a restored or newly created attachment, use it
                        if let imageAttachment = restoredAttachment {
                            // Replace the generic NSTextAttachment with our ImageAttachment
                            mutableString.removeAttribute(NSAttributedString.Key.attachment, range: range)
                            mutableString.addAttribute(NSAttributedString.Key.attachment, value: imageAttachment, range: range)
                            print("📋 PASTE: ✅ Replaced NSTextAttachment with ImageAttachment")
                        } else {
                            print("📋 PASTE: ⚠️ Could not create ImageAttachment - skipping")
                        }
                    }
                }
            }
            
            if foundAttachments {
                print("📋 PASTE: Found attachments - using custom insertion")
                // Insert the fixed attributed string
                let selectedRange = self.selectedRange
                let mutableText = NSMutableAttributedString(attributedString: self.attributedText)
                mutableText.replaceCharacters(in: selectedRange, with: mutableString)
                self.attributedText = mutableText
                
                // Update selection
                self.selectedRange = NSRange(location: selectedRange.location + mutableString.length, length: 0)
                
                print("📋 PASTE: Inserted content at position \(selectedRange.location)")
                
                // Notify the delegate to update the SwiftUI binding
                self.delegate?.textViewDidChange?(self)
                
                return
            } else {
                print("📋 PASTE: No attachments found - using default paste")
            }
        } else {
            print("📋 PASTE: No attributed string found in pasteboard")
        }
        
        // Fall back to default paste behavior
        print("📋 PASTE: Using default paste behavior")
        super.paste(sender)
    }
    
    // Override to prevent the editing menu from showing for formatting
    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        
        // Remove format menu from the editing menu
        if #available(iOS 16.0, macCatalyst 16.0, *) {
            builder.remove(menu: .format)
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var attributedText: NSAttributedString = {
            let text = "Hello, World!\n\nThis is a formatted text editor."
            let mutableAttrString = NSMutableAttributedString(string: text)
            
            // Make "Hello, World!" bold
            mutableAttrString.addAttribute(
                .font,
                value: UIFont.boldSystemFont(ofSize: 17),
                range: NSRange(location: 0, length: 13)
            )
            
            // Make "formatted" italic
            let formattedRange = (text as NSString).range(of: "formatted")
            if formattedRange.location != NSNotFound {
                mutableAttrString.addAttribute(
                    .font,
                    value: UIFont.italicSystemFont(ofSize: 17),
                    range: formattedRange
                )
            }
            
            return mutableAttrString
        }()
        
        @State private var selectedRange = NSRange(location: 0, length: 0)
        
        var body: some View {
            VStack {
                FormattedTextEditor(
                    attributedText: $attributedText,
                    selectedRange: $selectedRange,
                    onTextChange: { newText in
                        print("Text changed: \(newText.string.prefix(50))...")
                    },
                    onSelectionChange: { newRange in
                        print("Selection: \(newRange)")
                    }
                )
                .frame(height: 300)
                .border(Color.gray, width: 1)
                
                Text("Selection: \(selectedRange.location), \(selectedRange.length)")
                    .font(.caption)
                    .padding()
            }
            .padding()
        }
    }
    
    return PreviewWrapper()
}
