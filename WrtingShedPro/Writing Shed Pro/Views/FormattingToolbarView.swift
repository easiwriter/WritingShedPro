import SwiftUI
import UIKit

/// UIKit-based formatting toolbar that preserves keyboard focus
struct FormattingToolbarView: UIViewRepresentable {
    let textView: UITextView
    let onFormatAction: (FormattingAction) -> Void
    
    enum FormattingAction {
        case paragraphStyle
        case bold
        case italic
        case underline
        case strikethrough
        case imageStyle
        case insert
    }
    
    func makeUIView(context: Context) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        // Create paragraph style button (non-highlighting)
        let paragraphButton = createStandardButton(
            systemName: "paragraph",
            action: #selector(context.coordinator.showParagraphStyle),
            coordinator: context.coordinator
        )
        
        // Create custom buttons with background highlighting
        let boldButton = createCustomButton(
            systemName: "bold",
            action: #selector(context.coordinator.toggleBold),
            coordinator: context.coordinator
        )
        let italicButton = createCustomButton(
            systemName: "italic",
            action: #selector(context.coordinator.toggleItalic),
            coordinator: context.coordinator
        )
        let underlineButton = createCustomButton(
            systemName: "underline",
            action: #selector(context.coordinator.toggleUnderline),
            coordinator: context.coordinator
        )
        let strikethroughButton = createCustomButton(
            systemName: "strikethrough",
            action: #selector(context.coordinator.toggleStrikethrough),
            coordinator: context.coordinator
        )
        
        // Create image style button (only enabled when image is selected)
        let imageStyleButton = createStandardButton(
            systemName: "photo",
            action: #selector(context.coordinator.showImageStyle),
            coordinator: context.coordinator
        )
        
        // Create insert button with menu
        let insertButton = createMenuButton(
            systemName: "plus.circle",
            coordinator: context.coordinator
        )
        
        // Create cursor movement buttons
        let leftArrowButton = createStandardButton(
            systemName: "chevron.left",
            action: #selector(context.coordinator.moveCursorLeft),
            coordinator: context.coordinator
        )
        leftArrowButton.accessibilityLabel = NSLocalizedString("toolbar.moveCursorLeft", comment: "Move cursor left")
        
        let rightArrowButton = createStandardButton(
            systemName: "chevron.right",
            action: #selector(context.coordinator.moveCursorRight),
            coordinator: context.coordinator
        )
        rightArrowButton.accessibilityLabel = NSLocalizedString("toolbar.moveCursorRight", comment: "Move cursor right")
        
        // Create keyboard dismiss button
        let keyboardDismissButton = createStandardButton(
            systemName: "keyboard.chevron.compact.down",
            action: #selector(context.coordinator.dismissKeyboard),
            coordinator: context.coordinator
        )
        keyboardDismissButton.accessibilityLabel = NSLocalizedString("toolbar.dismissKeyboard", comment: "Dismiss keyboard")
        
        // Store button views in coordinator for state updates
        context.coordinator.boldButton = boldButton
        context.coordinator.italicButton = italicButton
        context.coordinator.underlineButton = underlineButton
        context.coordinator.strikethroughButton = strikethroughButton
        context.coordinator.imageStyleButton = imageStyleButton
        
        // Wrap buttons in UIBarButtonItems
        let paragraphBarItem = UIBarButtonItem(customView: paragraphButton)
        let boldBarItem = UIBarButtonItem(customView: boldButton)
        let italicBarItem = UIBarButtonItem(customView: italicButton)
        let underlineBarItem = UIBarButtonItem(customView: underlineButton)
        let strikethroughBarItem = UIBarButtonItem(customView: strikethroughButton)
        let imageStyleBarItem = UIBarButtonItem(customView: imageStyleButton)
        let insertBarItem = UIBarButtonItem(customView: insertButton)
        let leftArrowBarItem = UIBarButtonItem(customView: leftArrowButton)
        let rightArrowBarItem = UIBarButtonItem(customView: rightArrowButton)
        let keyboardDismissBarItem = UIBarButtonItem(customView: keyboardDismissButton)
        
        // Create individual spacing items
        func createSpace(_ width: CGFloat = 16) -> UIBarButtonItem {
            let space = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
            space.width = width
            return space
        }
        
        func createDivider() -> UIBarButtonItem {
            let divider = UIView()
            divider.backgroundColor = .separator
            divider.translatesAutoresizingMaskIntoConstraints = false
            divider.widthAnchor.constraint(equalToConstant: 1).isActive = true
            divider.heightAnchor.constraint(equalToConstant: 24).isActive = true
            return UIBarButtonItem(customView: divider)
        }
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        // Layout: [flex] ¶ [20] | [20] 📷 [20] | [20] B [20] I [20] U [20] S [20] | [20] + [20] | [20] ← [20] → [20] | [20] ⌨︎↓ [flex]
        toolbar.items = [
            flexSpace,
            paragraphBarItem,
            createSpace(20),
            createDivider(),
            createSpace(20),
            imageStyleBarItem,
            createSpace(20),
            createDivider(),
            createSpace(20),
            boldBarItem,
            createSpace(20),
            italicBarItem,
            createSpace(20),
            underlineBarItem,
            createSpace(20),
            strikethroughBarItem,
            createSpace(20),
            createDivider(),
            createSpace(20),
            insertBarItem,
            createSpace(20),
            createDivider(),
            createSpace(20),
            leftArrowBarItem,
            createSpace(20),
            rightArrowBarItem,
            createSpace(20),
            createDivider(),
            createSpace(20),
            keyboardDismissBarItem,
            flexSpace
        ]
        
        return toolbar
    }
    
    func updateUIView(_ toolbar: UIToolbar, context: Context) {
        context.coordinator.textView = textView
        context.coordinator.updateButtonStates()
        
        // Listen for text changes to update button states
        if context.coordinator.textChangeObserver == nil {
            context.coordinator.textChangeObserver = NotificationCenter.default.addObserver(
                forName: UITextView.textDidChangeNotification,
                object: textView,
                queue: .main
            ) { _ in
                context.coordinator.updateButtonStates()
            }
        }
        
        // Listen for selection changes to update button states
        if context.coordinator.selectionObserver == nil {
            context.coordinator.selectionObserver = NotificationCenter.default.addObserver(
                forName: UITextView.textDidBeginEditingNotification,
                object: textView,
                queue: .main
            ) { _ in
                context.coordinator.updateButtonStates()
            }
        }
    }
    
    static func dismantleUIView(_ toolbar: UIToolbar, coordinator: Coordinator) {
        // Clean up notification observers
        if let observer = coordinator.textChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = coordinator.selectionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onFormatAction: onFormatAction)
    }
    
    // Standard button without highlighting (paragraph, insert)
    private func createStandardButton(systemName: String, action: Selector, coordinator: Coordinator) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: systemName, withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
        button.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        button.addTarget(coordinator, action: action, for: .touchUpInside)
        return button
    }
    
    // Custom button with background highlighting (bold, italic, underline, strikethrough)
    private func createCustomButton(systemName: String, action: Selector, coordinator: Coordinator) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: systemName, withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
        button.frame = CGRect(x: 0, y: 0, width: 32, height: 28)  // Smaller highlight area
        button.layer.cornerRadius = 6  // Reduced corner radius
        button.addTarget(coordinator, action: action, for: .touchUpInside)
        return button
    }
    
    // Menu button for insert options
    private func createMenuButton(systemName: String, coordinator: Coordinator) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: systemName, withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
        button.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        button.showsMenuAsPrimaryAction = true
        
        // Create menu
        #if targetEnvironment(macCatalyst)
        // On Mac Catalyst, UIDocumentPickerViewController delegate doesn't work
        // Users should use copy/paste instead (Cmd+C image in Finder, then Cmd+V in document)
        let imageAction = UIAction(title: "Image (use copy/paste)", image: UIImage(systemName: "photo"), attributes: .disabled) { _ in }
        #else
        let imageAction = UIAction(title: "Image", image: UIImage(systemName: "photo")) { _ in
            coordinator.onFormatAction(.insert)
        }
        #endif
        
        let listAction = UIAction(title: "List", image: UIImage(systemName: "list.bullet"), attributes: .disabled) { _ in }
        let footnoteAction = UIAction(title: "Footnote", image: UIImage(systemName: "text.append"), attributes: .disabled) { _ in }
        let endnoteAction = UIAction(title: "Endnote", image: UIImage(systemName: "text.append"), attributes: .disabled) { _ in }
        let commentAction = UIAction(title: "Comment", image: UIImage(systemName: "text.bubble"), attributes: .disabled) { _ in }
        let indexAction = UIAction(title: "Index Item", image: UIImage(systemName: "tag"), attributes: .disabled) { _ in }
        
        button.menu = UIMenu(title: "", children: [
            imageAction,
            listAction,
            footnoteAction,
            endnoteAction,
            commentAction,
            indexAction
        ])
        
        return button
    }
    
    class Coordinator: NSObject {
        weak var textView: UITextView?
        let onFormatAction: (FormattingAction) -> Void
        var textChangeObserver: NSObjectProtocol?
        var selectionObserver: NSObjectProtocol?
        
        weak var boldButton: UIButton?
        weak var italicButton: UIButton?
        weak var underlineButton: UIButton?
        weak var strikethroughButton: UIButton?
        weak var imageStyleButton: UIButton?
        
        init(onFormatAction: @escaping (FormattingAction) -> Void) {
            self.onFormatAction = onFormatAction
            super.init()
        }
        
        @objc func showParagraphStyle() {
            onFormatAction(.paragraphStyle)
        }
        
        @objc func toggleBold() {
            onFormatAction(.bold)
            // Update button states immediately after action
            DispatchQueue.main.async {
                self.updateButtonStates()
            }
        }
        
        @objc func toggleItalic() {
            onFormatAction(.italic)
            // Update button states immediately after action
            DispatchQueue.main.async {
                self.updateButtonStates()
            }
        }
        
        @objc func toggleUnderline() {
            onFormatAction(.underline)
            // Update button states immediately after action
            DispatchQueue.main.async {
                self.updateButtonStates()
            }
        }
        
        @objc func toggleStrikethrough() {
            onFormatAction(.strikethrough)
            // Update button states immediately after action
            DispatchQueue.main.async {
                self.updateButtonStates()
            }
        }
        
        @objc func showImageStyle() {
            print("🖼️ showImageStyle() called")
            onFormatAction(.imageStyle)
        }
        
        @objc func showInsert() {
            print("🎯 showInsert() called")
            // Just trigger the insert action - let SwiftUI handle the menu
            onFormatAction(.insert)
        }
        
        @objc func moveCursorLeft() {
            guard let textView = textView else { return }
            
            let currentPosition = textView.selectedRange.location
            if currentPosition > 0 {
                let newPosition = currentPosition - 1
                textView.selectedRange = NSRange(location: newPosition, length: 0)
                
                // Scroll to make cursor visible
                textView.scrollRangeToVisible(NSRange(location: newPosition, length: 0))
            }
        }
        
        @objc func moveCursorRight() {
            guard let textView = textView else { return }
            
            let currentPosition = textView.selectedRange.location
            let textLength = textView.text.count
            
            if currentPosition < textLength {
                let newPosition = currentPosition + 1
                textView.selectedRange = NSRange(location: newPosition, length: 0)
                
                // Scroll to make cursor visible
                textView.scrollRangeToVisible(NSRange(location: newPosition, length: 0))
            }
        }
        
        @objc func dismissKeyboard() {
            textView?.resignFirstResponder()
        }
        
        func updateButtonStates() {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            let attributedString = textView.attributedText ?? NSAttributedString()
            
            // Determine attributes to check
            let attributes: [NSAttributedString.Key: Any]
            if selectedRange.length > 0 {
                // Use attributes at start of selection
                attributes = attributedString.attributes(at: selectedRange.location, effectiveRange: nil)
            } else {
                // Use typing attributes at cursor
                attributes = textView.typingAttributes
            }
            
            // Check font traits
            let isBold = hasBoldTrait(attributes: attributes)
            let isItalic = hasItalicTrait(attributes: attributes)
            let isUnderlined = attributes[.underlineStyle] as? Int ?? 0 > 0
            let isStrikethrough = attributes[.strikethroughStyle] as? Int ?? 0 > 0
            
            // Check if cursor is on an image
            var isOnImage = false
            if selectedRange.location < attributedString.length {
                let attrs = attributedString.attributes(at: selectedRange.location, effectiveRange: nil)
                isOnImage = attrs[.attachment] as? ImageAttachment != nil
            }
            
            // Update button backgrounds (like Writing Shed)
            updateButtonAppearance(boldButton, isActive: isBold)
            updateButtonAppearance(italicButton, isActive: isItalic)
            updateButtonAppearance(underlineButton, isActive: isUnderlined)
            updateButtonAppearance(strikethroughButton, isActive: isStrikethrough)
            
            // Enable/disable image style button based on image selection
            imageStyleButton?.isEnabled = isOnImage
            imageStyleButton?.alpha = isOnImage ? 1.0 : 0.4
        }
        
        private func updateButtonAppearance(_ button: UIButton?, isActive: Bool) {
            guard let button = button else { return }
            
            if isActive {
                // Active state: tan/gold background with darker tint (like Writing Shed)
                button.backgroundColor = UIColor(red: 0.85, green: 0.75, blue: 0.55, alpha: 1.0)
                button.tintColor = UIColor(red: 0.4, green: 0.3, blue: 0.1, alpha: 1.0)
            } else {
                // Inactive state: clear background with default tint
                button.backgroundColor = .clear
                button.tintColor = .label
            }
        }
        
        private func hasBoldTrait(attributes: [NSAttributedString.Key: Any]) -> Bool {
            guard let font = attributes[.font] as? UIFont else { return false }
            return font.fontDescriptor.symbolicTraits.contains(.traitBold)
        }
        
        private func hasItalicTrait(attributes: [NSAttributedString.Key: Any]) -> Bool {
            guard let font = attributes[.font] as? UIFont else { return false }
            return font.fontDescriptor.symbolicTraits.contains(.traitItalic)
        }
    }
}

// Helper extension to find view controller
extension UIView {
    func findViewController() -> UIViewController? {
        if let nextResponder = self.next as? UIViewController {
            return nextResponder
        } else if let nextResponder = self.next as? UIView {
            return nextResponder.findViewController()
        } else {
            return nil
        }
    }
}
