import UIKit

/// A UIView-based input accessory view that attaches to the keyboard like Apple Pages.
/// Using UIView instead of UIToolbar gives complete control over button styling.
class FormattingInputAccessoryView: UIView {
    
    // MARK: - Callback
    
    var onFormatAction: ((FormattingAction) -> Void)?
    
    enum FormattingAction {
        case paragraphStyle
        case bold
        case italic
        case underline
        case strikethrough
        case imageStyle
        case notes
        case toggleKeyboard
        case numberedList
        case bulletedList
        case insertTab
    }
    
    // MARK: - State
    
    private var hasHardwareKeyboard = false
    private var isKeyboardVisible = false
    weak var associatedTextView: UITextView?
    
    // Button references for state updates
    private var boldButton: UIButton?
    private var italicButton: UIButton?
    private var underlineButton: UIButton?
    private var strikethroughButton: UIButton?
    private var imageStyleButton: UIButton?
    private var tabButton: UIButton?
    private var keyboardToggleButton: UIButton?
    
    private var keyboardWillShowObserver: NSObjectProtocol?
    private var keyboardWillHideObserver: NSObjectProtocol?
    private var textChangeObserver: NSObjectProtocol?
    private var selectionChangeObserver: NSObjectProtocol?
    
    // Stack view for button layout
    private var stackView: UIStackView!
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        setupView()
        setupObservers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        setupObservers()
    }
    
    deinit {
        removeObservers()
    }
    
    // MARK: - Size
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: 44)
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize(width: size.width, height: 44)
    }
    
    // MARK: - Setup
    
    private func setupView() {
        // Light gray background for visual distinction from keyboard
        backgroundColor = UIColor(dynamicProvider: { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(white: 0.15, alpha: 1.0)
            } else {
                return UIColor(white: 0.92, alpha: 1.0)
            }
        })
        
        // Ensure fully opaque
        isOpaque = true
        
        // Add a subtle top border
        let topBorder = UIView()
        topBorder.backgroundColor = UIColor(dynamicProvider: { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(white: 0.3, alpha: 1.0)
            } else {
                return UIColor(white: 0.75, alpha: 1.0)
            }
        })
        topBorder.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topBorder)
        NSLayoutConstraint.activate([
            topBorder.topAnchor.constraint(equalTo: topAnchor),
            topBorder.leadingAnchor.constraint(equalTo: leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: trailingAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale)
        ])
        
        // Create stack view for buttons
        stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
        
        rebuildButtons()
    }
    
    private func rebuildButtons() {
        // Clear existing buttons
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        #if !targetEnvironment(macCatalyst)
        // Tab button - always create on iOS (hide only when hardware keyboard detected)
        let tabBtn = createStandardButton(systemName: "arrow.right.to.line", action: #selector(insertTab))
        tabBtn.accessibilityLabel = NSLocalizedString("toolbar.insertTab", comment: "Insert tab")
        tabButton = tabBtn
        stackView.addArrangedSubview(tabBtn)
        let tabSpacer = createSpacer(width: 8)
        stackView.addArrangedSubview(tabSpacer)
        // Hide tab button and spacer only if hardware keyboard is confirmed
        tabBtn.isHidden = hasHardwareKeyboard
        tabSpacer.isHidden = hasHardwareKeyboard
        #endif
        
        // Paragraph style button
        let paragraphBtn = createStandardButton(systemName: "text.square.filled", action: #selector(showParagraphStyle))
        paragraphBtn.accessibilityLabel = NSLocalizedString("toolbar.paragraphStyle", comment: "Paragraph style")
        stackView.addArrangedSubview(paragraphBtn)
        stackView.addArrangedSubview(createSpacer(width: 8))
        
        // Divider
        stackView.addArrangedSubview(createDivider())
        stackView.addArrangedSubview(createSpacer(width: 8))
        
        // Image style button
        let imageBtn = createStandardButton(systemName: "photo", action: #selector(showImageStyle))
        imageBtn.accessibilityLabel = NSLocalizedString("toolbar.imageStyle", comment: "Image style")
        imageBtn.alpha = 0.4
        imageBtn.isEnabled = false
        imageStyleButton = imageBtn
        stackView.addArrangedSubview(imageBtn)
        stackView.addArrangedSubview(createSpacer(width: 8))
        
        // Notes button
        let notesBtn = createStandardButton(systemName: "list.clipboard", action: #selector(showNotes))
        notesBtn.accessibilityLabel = NSLocalizedString("toolbar.notes", comment: "Notes")
        stackView.addArrangedSubview(notesBtn)
        stackView.addArrangedSubview(createSpacer(width: 8))
        
        // Divider
        stackView.addArrangedSubview(createDivider())
        stackView.addArrangedSubview(createSpacer(width: 8))
        
        // Bold button
        let boldBtn = createHighlightButton(systemName: "bold", action: #selector(handleToggleBold))
        boldBtn.accessibilityLabel = NSLocalizedString("toolbar.bold", comment: "Bold")
        boldButton = boldBtn
        stackView.addArrangedSubview(boldBtn)
        stackView.addArrangedSubview(createSpacer(width: 6))
        
        // Italic button
        let italicBtn = createHighlightButton(systemName: "italic", action: #selector(handleToggleItalic))
        italicBtn.accessibilityLabel = NSLocalizedString("toolbar.italic", comment: "Italic")
        italicButton = italicBtn
        stackView.addArrangedSubview(italicBtn)
        stackView.addArrangedSubview(createSpacer(width: 6))
        
        // Underline button
        let underlineBtn = createHighlightButton(systemName: "underline", action: #selector(handleToggleUnderline))
        underlineBtn.accessibilityLabel = NSLocalizedString("toolbar.underline", comment: "Underline")
        underlineButton = underlineBtn
        stackView.addArrangedSubview(underlineBtn)
        stackView.addArrangedSubview(createSpacer(width: 6))
        
        // Strikethrough button
        let strikethroughBtn = createHighlightButton(systemName: "strikethrough", action: #selector(handleToggleStrikethrough))
        strikethroughBtn.accessibilityLabel = NSLocalizedString("toolbar.strikethrough", comment: "Strikethrough")
        strikethroughButton = strikethroughBtn
        stackView.addArrangedSubview(strikethroughBtn)
        
        #if !targetEnvironment(macCatalyst)
        // Keyboard toggle - always create on iOS (hide when hardware keyboard detected)
        let kbSpacer1 = createSpacer(width: 8)
        let kbDivider = createDivider()
        let kbSpacer2 = createSpacer(width: 8)
        stackView.addArrangedSubview(kbSpacer1)
        stackView.addArrangedSubview(kbDivider)
        stackView.addArrangedSubview(kbSpacer2)
        
        let keyboardBtn = createStandardButton(systemName: "keyboard.chevron.compact.down", action: #selector(toggleKeyboard))
        keyboardBtn.accessibilityLabel = NSLocalizedString("toolbar.dismissKeyboard", comment: "Dismiss keyboard")
        keyboardToggleButton = keyboardBtn
        stackView.addArrangedSubview(keyboardBtn)
        
        // Hide keyboard section when hardware keyboard is confirmed
        kbSpacer1.isHidden = hasHardwareKeyboard
        kbDivider.isHidden = hasHardwareKeyboard
        kbSpacer2.isHidden = hasHardwareKeyboard
        keyboardBtn.isHidden = hasHardwareKeyboard
        #endif
    }
    
    // MARK: - Button Creation
    
    private func createStandardButton(systemName: String, action: Selector) -> UIButton {
        let button = UIButton(type: .custom)
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        let image = UIImage(systemName: systemName, withConfiguration: symbolConfig)?.withRenderingMode(.alwaysTemplate)
        button.setImage(image, for: .normal)
        button.tintColor = .label
        button.backgroundColor = .clear
        button.addTarget(self, action: action, for: .touchUpInside)
        
        // Set fixed size
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        return button
    }
    
    private func createHighlightButton(systemName: String, action: Selector) -> UIButton {
        let button = UIButton(type: .custom)
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        let image = UIImage(systemName: systemName, withConfiguration: symbolConfig)?.withRenderingMode(.alwaysTemplate)
        button.setImage(image, for: .normal)
        button.tintColor = .label
        button.backgroundColor = .clear
        button.layer.cornerRadius = 6
        button.clipsToBounds = true
        button.addTarget(self, action: action, for: .touchUpInside)
        
        // Set fixed size
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 32),
            button.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        return button
    }
    
    private func createSpacer(width: CGFloat) -> UIView {
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.widthAnchor.constraint(equalToConstant: width).isActive = true
        return spacer
    }
    
    private func createDivider() -> UIView {
        let divider = UIView()
        divider.backgroundColor = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            divider.widthAnchor.constraint(equalToConstant: 1),
            divider.heightAnchor.constraint(equalToConstant: 24)
        ])
        return divider
    }
    
    // MARK: - Observers
    
    private func setupObservers() {
        keyboardWillShowObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleKeyboardWillShow(notification)
        }
        
        keyboardWillHideObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleKeyboardWillHide(notification)
        }
    }
    
    private func removeObservers() {
        if let observer = keyboardWillShowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = keyboardWillHideObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = textChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = selectionChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func connectToTextView(_ textView: UITextView) {
        associatedTextView = textView
        
        // Observe text changes
        textChangeObserver = NotificationCenter.default.addObserver(
            forName: UITextView.textDidChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            self?.updateButtonStates()
        }
        
        // Observe selection changes
        selectionChangeObserver = NotificationCenter.default.addObserver(
            forName: UITextView.textDidBeginEditingNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            self?.updateButtonStates()
        }
    }
    
    private func handleKeyboardWillShow(_ notification: Notification) {
        isKeyboardVisible = true
        
        // Detect hardware keyboard by checking frame height
        if let userInfo = notification.userInfo,
           let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            hasHardwareKeyboard = endFrame.height < 100
        }
        
        rebuildButtons()
        updateKeyboardButtonIcon()
    }
    
    private func handleKeyboardWillHide(_ notification: Notification) {
        isKeyboardVisible = false
        rebuildButtons()
        updateKeyboardButtonIcon()
    }
    
    private func updateKeyboardButtonIcon() {
        let symbolName = isKeyboardVisible ? "keyboard.chevron.compact.down" : "keyboard"
        let config = UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        keyboardToggleButton?.setImage(UIImage(systemName: symbolName, withConfiguration: config), for: .normal)
        
        let accessibilityLabel = isKeyboardVisible ?
            NSLocalizedString("toolbar.dismissKeyboard", comment: "Dismiss keyboard") :
            NSLocalizedString("toolbar.showKeyboard", comment: "Show keyboard")
        keyboardToggleButton?.accessibilityLabel = accessibilityLabel
    }
    
    // MARK: - Actions
    
    @objc private func insertTab() {
        onFormatAction?(.insertTab)
    }
    
    @objc private func showParagraphStyle() {
        onFormatAction?(.paragraphStyle)
    }
    
    @objc private func showImageStyle() {
        onFormatAction?(.imageStyle)
    }
    
    @objc private func showNotes() {
        onFormatAction?(.notes)
    }
    
    @objc private func handleToggleBold() {
        onFormatAction?(.bold)
        DispatchQueue.main.async { [weak self] in
            self?.updateButtonStates()
        }
    }
    
    @objc private func handleToggleItalic() {
        onFormatAction?(.italic)
        DispatchQueue.main.async { [weak self] in
            self?.updateButtonStates()
        }
    }
    
    @objc private func handleToggleUnderline() {
        onFormatAction?(.underline)
        DispatchQueue.main.async { [weak self] in
            self?.updateButtonStates()
        }
    }
    
    @objc private func handleToggleStrikethrough() {
        onFormatAction?(.strikethrough)
        DispatchQueue.main.async { [weak self] in
            self?.updateButtonStates()
        }
    }
    
    @objc private func toggleKeyboard() {
        onFormatAction?(.toggleKeyboard)
    }
    
    // MARK: - State Updates
    
    func updateButtonStates() {
        guard let textView = associatedTextView else { return }
        
        let selectedRange = textView.selectedRange
        let attributedString = textView.attributedText ?? NSAttributedString()
        
        // Determine attributes to check
        let attributes: [NSAttributedString.Key: Any]
        if selectedRange.length > 0, selectedRange.location < attributedString.length {
            attributes = attributedString.attributes(at: selectedRange.location, effectiveRange: nil)
        } else {
            attributes = textView.typingAttributes
        }
        
        // Check font traits
        let isBold = hasBoldTrait(attributes: attributes)
        let isItalic = hasItalicTrait(attributes: attributes)
        let isUnderlined = (attributes[.underlineStyle] as? Int ?? 0) > 0
        let isStrikethrough = (attributes[.strikethroughStyle] as? Int ?? 0) > 0
        
        // Check if cursor is on an image
        var isOnImage = false
        if selectedRange.location < attributedString.length {
            let attrs = attributedString.attributes(at: selectedRange.location, effectiveRange: nil)
            isOnImage = attrs[.attachment] is ImageAttachment
        }
        
        // Update button appearances
        updateButtonAppearance(boldButton, isActive: isBold)
        updateButtonAppearance(italicButton, isActive: isItalic)
        updateButtonAppearance(underlineButton, isActive: isUnderlined)
        updateButtonAppearance(strikethroughButton, isActive: isStrikethrough)
        
        // Enable/disable image style button
        imageStyleButton?.isEnabled = isOnImage
        imageStyleButton?.alpha = isOnImage ? 1.0 : 0.4
        
        // Disable tab button when image selected
        tabButton?.isEnabled = !isOnImage
        tabButton?.alpha = isOnImage ? 0.4 : 1.0
    }
    
    func setImageSelected(_ selected: Bool) {
        imageStyleButton?.isEnabled = selected
        imageStyleButton?.alpha = selected ? 1.0 : 0.4
        tabButton?.isEnabled = !selected
        tabButton?.alpha = selected ? 0.4 : 1.0
    }
    
    private func updateButtonAppearance(_ button: UIButton?, isActive: Bool) {
        guard let button = button else { return }
        
        if isActive {
            // Active state: tan/gold background with darker tint
            button.backgroundColor = UIColor(red: 0.85, green: 0.75, blue: 0.55, alpha: 1.0)
            button.tintColor = UIColor(red: 0.4, green: 0.3, blue: 0.1, alpha: 1.0)
        } else {
            // Inactive state: clear background with label color
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
