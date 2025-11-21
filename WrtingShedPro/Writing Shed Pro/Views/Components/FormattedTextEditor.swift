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
    
    /// Optional callback when user taps on an image
    var onImageTapped: ((ImageAttachment, CGRect, Int) -> Void)?
    
    /// Optional callback when image selection should be cleared (cursor moved away)
    var onClearImageSelection: (() -> Void)?
    
    /// Optional callback when user taps on a comment
    var onCommentTapped: ((CommentAttachment, Int) -> Void)?
    
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
        onSelectionChange: ((NSRange) -> Void)? = nil,
        onImageTapped: ((ImageAttachment, CGRect, Int) -> Void)? = nil,
        onClearImageSelection: (() -> Void)? = nil,
        onCommentTapped: ((CommentAttachment, Int) -> Void)? = nil
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
        self.onImageTapped = onImageTapped
        self.onClearImageSelection = onClearImageSelection
        self.onCommentTapped = onCommentTapped
    }
    
    // MARK: - UIViewRepresentable
    
    func makeUIView(context: Context) -> UITextView {
        let textView = CustomTextView() // Use custom subclass to support inputAccessoryView
        
        // Store reference to textView in coordinator (if provided)
        context.coordinator.textView = textView
        textViewCoordinator?.textView = textView
        
        // Wire up comment tap callback
        let coordinator = context.coordinator
        textView.onCommentTapped = { [weak coordinator] attachment, position in
            coordinator?.parent.onCommentTapped?(attachment, position)
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
        
        // Add tap gesture recognizer for image selection
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.delegate = context.coordinator
        textView.addGestureRecognizer(tapGesture)
        
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
                
                #if DEBUG
                print("🖼️ Recalculating selection border after content update")
                print("🖼️ New frame: \(adjustedBounds)")
                #endif
                
                // Update the selection border with the new frame (visual only, don't trigger state changes)
                customTextView.showSelectionBorder(at: adjustedBounds)
            }
            
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
    
    class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: FormattedTextEditor
        var isUpdatingFromSwiftUI = false
        weak var textView: UITextView?
        var previousSelection: NSRange = NSRange(location: 0, length: 0)
        
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
            
            textView.layoutManager.ensureLayout(for: textView.textContainer)
            
            let newRange = textView.selectedRange
            let textLength = textView.attributedText?.length ?? 0
            
            #if DEBUG
            print("📍 textViewDidChangeSelection: position=\(newRange.location), length=\(newRange.length), textLength=\(textLength)")
            #endif
            
            // Check if cursor landed on a zero-width space
            if newRange.length == 0, newRange.location > 0, newRange.location < textLength {
                if let attributedText = textView.attributedText {
                    let stringIndex = attributedText.string.index(attributedText.string.startIndex, offsetBy: newRange.location)
                    let char = attributedText.string[stringIndex]
                    
                    if char == "\u{200B}" {
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
            parent.selectedRange = imageRange
            parent.onSelectionChange?(imageRange)
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
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addSubview(selectionBorderView)
        setupCommentInteraction()
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
        
        guard characterIndex < textStorage.length else { return }
        
        // Check if tapped on a comment attachment
        if let commentAttachment = textStorage.attribute(.attachment, at: characterIndex, effectiveRange: nil) as? CommentAttachment {
            onCommentTapped?(commentAttachment, characterIndex)
            // Prevent default text selection
            gesture.cancelsTouchesInView = true
        }
    }
    
    // Change cursor to pointer when hovering over comments (iPad with mouse/trackpad)
    #if targetEnvironment(macCatalyst)
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        var adjustedPoint = point
        adjustedPoint.x -= textContainerInset.left
        adjustedPoint.y -= textContainerInset.top
        
        let characterIndex = layoutManager.characterIndex(
            for: adjustedPoint,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        
        if characterIndex < textStorage.length {
            if let _ = textStorage.attribute(.attachment, at: characterIndex, effectiveRange: nil) as? CommentAttachment {
                // Change cursor to pointer
                NSCursor.pointingHand.set()
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
    
    // Hide the system formatting menu and selection grabbers/handles
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        // Hide the system formatting toolbar options (Bold, Italic, Underline, etc.)
        if shouldHideSystemFormattingMenu {
            if action == #selector(toggleBoldface(_:)) ||
               action == #selector(toggleItalics(_:)) ||
               action == #selector(toggleUnderline(_:)) ||
               action == #selector(UIResponderStandardEditActions.toggleBoldface(_:)) ||
               action == #selector(UIResponderStandardEditActions.toggleItalics(_:)) ||
               action == #selector(UIResponderStandardEditActions.toggleUnderline(_:)) {
                return false
            }
        }
        
        // Disable selection actions when image is selected
        if isImageSelected {
            // Still allow delete/cut to remove the image
            if action == #selector(UIResponderStandardEditActions.delete(_:)) ||
               action == #selector(UIResponderStandardEditActions.cut(_:)) {
                return true
            }
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }
    
    // Update selection border position when layout changes (e.g., rotation)
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // If we have a visible selection border and an image is selected, recalculate its position
        if isImageSelected && !selectionBorderView.isHidden {
            recalculateSelectionBorder()
        }
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
