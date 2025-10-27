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
    
    // MARK: - Initialization
    
    init(
        attributedText: Binding<NSAttributedString>,
        selectedRange: Binding<NSRange> = .constant(NSRange(location: 0, length: 0)),
        font: UIFont = .preferredFont(forTextStyle: .body),
        textColor: UIColor = .label,
        backgroundColor: UIColor = .systemBackground,
        textContainerInset: UIEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8),
        isEditable: Bool = true,
        onTextChange: ((NSAttributedString) -> Void)? = nil,
        onSelectionChange: ((NSRange) -> Void)? = nil
    ) {
        self._attributedText = attributedText
        self._selectedRange = selectedRange
        self.font = font
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.textContainerInset = textContainerInset
        self.isEditable = isEditable
        self.onTextChange = onTextChange
        self.onSelectionChange = onSelectionChange
    }
    
    // MARK: - UIViewRepresentable
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        
        // Configure appearance
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = backgroundColor
        textView.textContainerInset = textContainerInset
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isScrollEnabled = true
        
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
        
        // Only update if the string content actually changed
        // This prevents overwriting user typing with stale state
        if textView.attributedText.string != attributedText.string {
            print("📝 Content different - updating text view")
            
            // Set flag to prevent feedback from delegate
            context.coordinator.isUpdatingFromSwiftUI = true
            
            let oldSelectedRange = textView.selectedRange
            textView.attributedText = attributedText
            
            // Force layout update after text change
            textView.layoutManager.ensureLayout(for: textView.textContainer)
            
            // Restore selection if it's still valid
            if oldSelectedRange.location <= attributedText.length {
                textView.selectedRange = oldSelectedRange
            } else {
                // If selection is invalid, move to end
                textView.selectedRange = NSRange(location: attributedText.length, length: 0)
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
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = backgroundColor
        textView.textContainerInset = textContainerInset
        textView.isEditable = isEditable
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
        
        init(_ parent: FormattedTextEditor) {
            self.parent = parent
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        // MARK: - UITextViewDelegate
        
        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdatingFromSwiftUI else { return }
            
            // Update the binding so SwiftUI state stays in sync
            // This is safe because updateUIView checks object identity
            if let attributedText = textView.attributedText {
                parent.attributedText = attributedText
                parent.onTextChange?(attributedText)
            }
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isUpdatingFromSwiftUI else { return }
            
            // Ensure layout is complete before trusting the selection
            // This helps with tap-to-position accuracy
            textView.layoutManager.ensureLayout(for: textView.textContainer)
            
            // Only notify via callback - do NOT update the binding here
            let newRange = textView.selectedRange
            
            #if DEBUG
            print("📍 Selection changed to: {\(newRange.location), \(newRange.length)}")
            #endif
            
            parent.onSelectionChange?(newRange)
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // Don't allow changes while updating from SwiftUI
            if isUpdatingFromSwiftUI {
                return false
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
