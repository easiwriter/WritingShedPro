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
            systemName: "text.square.filled",
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
        context.coordinator.leftArrowButton = leftArrowButton
        context.coordinator.rightArrowButton = rightArrowButton
        context.coordinator.keyboardToggleButton = keyboardDismissButton
        
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
        
        // Store bar items in coordinator for dynamic updates
        context.coordinator.paragraphBarItem = paragraphBarItem
        context.coordinator.boldBarItem = boldBarItem
        context.coordinator.italicBarItem = italicBarItem
        context.coordinator.underlineBarItem = underlineBarItem
        context.coordinator.strikethroughBarItem = strikethroughBarItem
        context.coordinator.imageStyleBarItem = imageStyleBarItem
        context.coordinator.insertBarItem = insertBarItem
        context.coordinator.leftArrowBarItem = leftArrowBarItem
        context.coordinator.rightArrowBarItem = rightArrowBarItem
        context.coordinator.keyboardToggleBarItem = keyboardDismissBarItem
        context.coordinator.toolbar = toolbar
        
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
        
        // Store toolbar building function in coordinator
        context.coordinator.buildToolbarItems = { hasHardwareKeyboard, keyboardVisible in
            var items: [UIBarButtonItem] = [
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
                insertBarItem
            ]
            
            // Only show cursor arrows and keyboard toggle on iOS (not Mac Catalyst)
            #if !targetEnvironment(macCatalyst)
            // Only show cursor arrows when there's NO hardware keyboard AND keyboard is visible
            if !hasHardwareKeyboard && keyboardVisible {
                items.append(contentsOf: [
                    createSpace(20),
                    createDivider(),
                    createSpace(20),
                    leftArrowBarItem,
                    createSpace(20),
                    rightArrowBarItem
                ])
            }
            
            // Only show keyboard toggle when there's NO hardware keyboard
            if !hasHardwareKeyboard {
                items.append(contentsOf: [
                    createSpace(20),
                    createDivider(),
                    createSpace(20),
                    keyboardDismissBarItem
                ])
            }
            #endif
            
            items.append(flexSpace)
            return items
        }
        
        // Initial layout - start with keyboard visible on iOS
        #if targetEnvironment(macCatalyst)
        toolbar.items = context.coordinator.buildToolbarItems?(true, false) ?? []
        #else
        // On iPad, assume hardware keyboard by default; on iPhone, assume soft keyboard
        let hasHardwareKeyboard = UIDevice.current.userInterfaceIdiom == .pad
        toolbar.items = context.coordinator.buildToolbarItems?(hasHardwareKeyboard, !hasHardwareKeyboard) ?? []
        context.coordinator.hasHardwareKeyboard = hasHardwareKeyboard
        context.coordinator.isKeyboardVisible = !hasHardwareKeyboard
        #endif
        
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
        
        // Listen for keyboard show/hide notifications
        if context.coordinator.keyboardWillShowObserver == nil {
            context.coordinator.keyboardWillShowObserver = NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillShowNotification,
                object: nil,
                queue: .main
            ) { notification in
                context.coordinator.handleKeyboardWillShow(notification)
            }
        }
        
        if context.coordinator.keyboardWillHideObserver == nil {
            context.coordinator.keyboardWillHideObserver = NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { notification in
                context.coordinator.handleKeyboardWillHide(notification)
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
        if let observer = coordinator.keyboardWillShowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = coordinator.keyboardWillHideObserver {
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
        var keyboardWillShowObserver: NSObjectProtocol?
        var keyboardWillHideObserver: NSObjectProtocol?
        
        weak var boldButton: UIButton?
        weak var italicButton: UIButton?
        weak var underlineButton: UIButton?
        weak var strikethroughButton: UIButton?
        weak var imageStyleButton: UIButton?
        weak var leftArrowButton: UIButton?
        weak var rightArrowButton: UIButton?
        weak var keyboardToggleButton: UIButton?
        
        weak var toolbar: UIToolbar?
        weak var paragraphBarItem: UIBarButtonItem?
        weak var boldBarItem: UIBarButtonItem?
        weak var italicBarItem: UIBarButtonItem?
        weak var underlineBarItem: UIBarButtonItem?
        weak var strikethroughBarItem: UIBarButtonItem?
        weak var imageStyleBarItem: UIBarButtonItem?
        weak var insertBarItem: UIBarButtonItem?
        weak var leftArrowBarItem: UIBarButtonItem?
        weak var rightArrowBarItem: UIBarButtonItem?
        weak var keyboardToggleBarItem: UIBarButtonItem?
        
        var buildToolbarItems: ((Bool, Bool) -> [UIBarButtonItem])?
        
        var isKeyboardVisible = false
        var hasHardwareKeyboard = false
        
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
            if isKeyboardVisible {
                // Hide keyboard
                textView?.resignFirstResponder()
            } else {
                // Show keyboard
                textView?.becomeFirstResponder()
            }
        }
        
        func handleKeyboardWillShow(_ notification: Notification) {
            isKeyboardVisible = true
            
            // Detect if this is a hardware keyboard
            // Hardware keyboard will have endFrame height of 0 or very small
            if let userInfo = notification.userInfo,
               let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                hasHardwareKeyboard = endFrame.height < 100
            }
            
            // On iPad, also check device idiom and keyboard presence
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                // On iPad, if endFrame height is 0 or keyboard never appears, it's a hardware keyboard
                if let userInfo = notification.userInfo,
                   let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    hasHardwareKeyboard = endFrame.height == 0 || endFrame.height < 50
                } else {
                    hasHardwareKeyboard = true  // Default to hardware keyboard on iPad if detection fails
                }
            }
            #endif
            
            updateToolbarLayout()
            updateKeyboardButtonIcon()
        }
        
        func handleKeyboardWillHide(_ notification: Notification) {
            isKeyboardVisible = false
            // Update toolbar layout to hide cursor keys when keyboard is hidden
            updateToolbarLayout()
            updateKeyboardButtonIcon()
        }
        
        func updateToolbarLayout() {
            guard let toolbar = toolbar,
                  let buildToolbarItems = buildToolbarItems else { return }
            
            toolbar.items = buildToolbarItems(hasHardwareKeyboard, isKeyboardVisible)
        }
        
        func updateKeyboardButtonIcon() {
            guard let button = keyboardToggleButton else { return }
            
            let symbolName = isKeyboardVisible ? "keyboard.chevron.compact.down" : "keyboard"
            let accessibilityLabel = isKeyboardVisible ? 
                NSLocalizedString("toolbar.dismissKeyboard", comment: "Dismiss keyboard") :
                NSLocalizedString("toolbar.showKeyboard", comment: "Show keyboard")
            
            button.setImage(
                UIImage(systemName: symbolName, withConfiguration: UIImage.SymbolConfiguration(scale: .large)),
                for: .normal
            )
            button.accessibilityLabel = accessibilityLabel
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
            
            // Cursor buttons should always be enabled on iOS (not Catalyst)
            #if !targetEnvironment(macCatalyst)
            leftArrowButton?.isEnabled = true
            rightArrowButton?.isEnabled = true
            keyboardToggleButton?.isEnabled = true
            #endif
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
