import SwiftUI
import GameController

/// Pure SwiftUI formatting toolbar - works correctly with iOS 26.2+ button styling
struct SwiftUIFormattingToolbar: View {
    let onFormatAction: (FormattingAction) -> Void
    let hasSelectedImage: Bool
    let notesExist: Bool
    let indexEnabled: Bool
    let isBoldActive: Bool
    let isItalicActive: Bool
    let isUnderlineActive: Bool
    let isStrikethroughActive: Bool
    @State private var hasHardwareKeyboard = false
    @State private var isKeyboardVisible = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var isCompactWidth: Bool {
        horizontalSizeClass == .compact
    }

    private var hasActiveEmphasis: Bool {
        isBoldActive || isItalicActive || isUnderlineActive || isStrikethroughActive
    }
    
    enum FormattingAction {
        case paragraphStyle
        case bold
        case italic
        case underline
        case strikethrough
        case imageStyle
        case notes
        case clearText
        case toggleKeyboard
        case numberedList
        case bulletedList
        case insertTab
        case increaseIndent
        case decreaseIndent
        case addIndex
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                #if !targetEnvironment(macCatalyst)
                // Tab key (only on software keyboard, disabled when image selected)
                if !hasHardwareKeyboard {
                    toolbarButton(systemName: "arrow.right.to.line", action: .insertTab)
                        .opacity(hasSelectedImage ? 0.3 : 1.0)
                        .disabled(hasSelectedImage)
                }
                #endif
                
                Divider()
                    .frame(height: 24)
                
                // Image style (only enabled when image selected)
                toolbarButton(systemName: "photo", action: .imageStyle)
                    .opacity(hasSelectedImage ? 1.0 : 0.3)
                    .disabled(!hasSelectedImage)
                
                // Notes (disabled when image selected)
                toolbarButton(systemName: "list.clipboard", action: .notes, tint: notesExist ? Color.accentColor : nil)
                    .opacity(hasSelectedImage ? 0.3 : 1.0)
                    .disabled(hasSelectedImage)
                
                Divider()
                    .frame(height: 24)
                
                // Paragraph style (disabled when image selected)
                // Moved to left of text formatting group
                toolbarButton(systemName: "paragraph", action: .paragraphStyle)
                    .opacity(hasSelectedImage ? 0.3 : 1.0)
                    .disabled(hasSelectedImage)
                
                // Text formatting
                #if targetEnvironment(macCatalyst)
                // Mac/iPad: individual buttons
                toolbarButton(systemName: "bold", action: .bold, isActive: isBoldActive)
                    .opacity(hasSelectedImage ? 0.3 : 1.0)
                    .disabled(hasSelectedImage)
                toolbarButton(systemName: "italic", action: .italic, isActive: isItalicActive)
                    .opacity(hasSelectedImage ? 0.3 : 1.0)
                    .disabled(hasSelectedImage)
                toolbarButton(systemName: "underline", action: .underline, isActive: isUnderlineActive)
                    .opacity(hasSelectedImage ? 0.3 : 1.0)
                    .disabled(hasSelectedImage)
                toolbarButton(systemName: "strikethrough", action: .strikethrough, isActive: isStrikethroughActive)
                    .opacity(hasSelectedImage ? 0.3 : 1.0)
                    .disabled(hasSelectedImage)
                #else
                if isCompactWidth {
                    // iPhone: single menu button for B/I/U/S
                    textFormattingMenuButton()
                        .opacity(hasSelectedImage ? 0.3 : 1.0)
                        .disabled(hasSelectedImage)
                } else {
                    // iPad: individual buttons
                    toolbarButton(systemName: "bold", action: .bold, isActive: isBoldActive)
                        .opacity(hasSelectedImage ? 0.3 : 1.0)
                        .disabled(hasSelectedImage)
                    toolbarButton(systemName: "italic", action: .italic, isActive: isItalicActive)
                        .opacity(hasSelectedImage ? 0.3 : 1.0)
                        .disabled(hasSelectedImage)
                    toolbarButton(systemName: "underline", action: .underline, isActive: isUnderlineActive)
                        .opacity(hasSelectedImage ? 0.3 : 1.0)
                        .disabled(hasSelectedImage)
                    toolbarButton(systemName: "strikethrough", action: .strikethrough, isActive: isStrikethroughActive)
                        .opacity(hasSelectedImage ? 0.3 : 1.0)
                        .disabled(hasSelectedImage)
                }
                #endif
                
                Divider()
                    .frame(height: 24)
                
                // List indent/outdent buttons (disabled when image selected)
                toolbarButton(systemName: "decrease.indent", action: .decreaseIndent)
                    .opacity(hasSelectedImage ? 0.3 : 1.0)
                    .disabled(hasSelectedImage)
                toolbarButton(systemName: "increase.indent", action: .increaseIndent)
                    .opacity(hasSelectedImage ? 0.3 : 1.0)
                    .disabled(hasSelectedImage)
                
                // Index button (only shown when index is enabled in back matter)
                if indexEnabled {
                    Divider()
                        .frame(height: 24)
                    
                    toolbarButton(systemName: "list.bullet.indent", action: .addIndex)
                        .opacity(hasSelectedImage ? 0.3 : 1.0)
                        .disabled(hasSelectedImage)
                }
                
                #if !targetEnvironment(macCatalyst)
                if !hasHardwareKeyboard {
                    Divider()
                        .frame(height: 24)
                    
                    toolbarButton(
                        systemName: isKeyboardVisible ? "keyboard.chevron.compact.down" : "keyboard",
                        action: .toggleKeyboard
                    )
                }
                #endif
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 44)
        .background(Color(uiColor: .secondarySystemBackground))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(uiColor: .separator))
                .frame(height: 1)
        }
        .onAppear {
            detectHardwareKeyboard()
            observeKeyboardNotifications()
        }
    }
    
    private func textFormattingMenuButton() -> some View {
        Menu {
            Button {
                onFormatAction(.bold)
            } label: {
                Label(
                    NSLocalizedString("toolbar.bold", comment: "Bold"),
                    systemImage: isBoldActive ? "checkmark" : "bold"
                )
            }
            Button {
                onFormatAction(.italic)
            } label: {
                Label(
                    NSLocalizedString("toolbar.italic", comment: "Italic"),
                    systemImage: isItalicActive ? "checkmark" : "italic"
                )
            }
            Button {
                onFormatAction(.underline)
            } label: {
                Label(
                    NSLocalizedString("toolbar.underline", comment: "Underline"),
                    systemImage: isUnderlineActive ? "checkmark" : "underline"
                )
            }
            Button {
                onFormatAction(.strikethrough)
            } label: {
                Label(
                    NSLocalizedString("toolbar.strikethrough", comment: "Strikethrough"),
                    systemImage: isStrikethroughActive ? "checkmark" : "strikethrough"
                )
            }
            Divider()
            Button(role: .destructive) {
                onFormatAction(.clearText)
            } label: {
                Label("Clear Text", systemImage: "eraser.fill")
            }
        } label: {
            Group {
                if hasActiveEmphasis {
                    ZStack {
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 22, height: 22)
                        Image(systemName: "bold.italic.underline")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(uiColor: .systemBackground))
                    }
                } else {
                    Image(systemName: "bold.italic.underline")
                        .font(.system(size: 17))
                        .foregroundStyle(Color.primary)
                }
            }
            .frame(width: 32, height: 44)
        }
        .buttonStyle(.plain)
        .controlSize(.small)
        .accessibilityLabel(NSLocalizedString("toolbar.textFormatting", comment: "Text formatting"))
    }
    
    private func toolbarButton(systemName: String, action: FormattingAction, tint: Color? = nil, isActive: Bool = false) -> some View {
        Button {
            onFormatAction(action)
        } label: {
            Group {
                if isActive {
                    ZStack {
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 22, height: 22)
                        Image(systemName: systemName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(uiColor: .systemBackground))
                    }
                } else {
                    Image(systemName: systemName)
                        .font(.system(size: 17))
                        .foregroundStyle(tint ?? Color.primary)
                }
            }
            .frame(width: 32, height: 44)
        }
        .buttonStyle(.plain)
        .controlSize(.small)
    }
    
    private func detectHardwareKeyboard() {
        #if !targetEnvironment(macCatalyst)
        // Check if a hardware keyboard is connected using GameController
        hasHardwareKeyboard = GCKeyboard.coalesced != nil
        #else
        // On Mac Catalyst, always assume hardware keyboard
        hasHardwareKeyboard = true
        #endif
    }
    
    private func observeKeyboardNotifications() {
        #if !targetEnvironment(macCatalyst)
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            isKeyboardVisible = true
            
            // Detect hardware keyboard by checking keyboard height
            // Hardware keyboard shows only a small shortcut bar (~55pt)
            // Software keyboard is much taller (>200pt)
            if let userInfo = notification.userInfo,
               let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                let keyboardHeight = keyboardFrame.height
                // If keyboard height is less than 100, it's likely hardware keyboard with shortcut bar
                hasHardwareKeyboard = keyboardHeight < 100
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            isKeyboardVisible = false
            // Re-check hardware keyboard when keyboard hides (in case it was disconnected)
            hasHardwareKeyboard = GCKeyboard.coalesced != nil
        }
        
        // Also observe hardware keyboard connect/disconnect
        NotificationCenter.default.addObserver(
            forName: .GCKeyboardDidConnect,
            object: nil,
            queue: .main
        ) { _ in
            hasHardwareKeyboard = true
        }
        
        NotificationCenter.default.addObserver(
            forName: .GCKeyboardDidDisconnect,
            object: nil,
            queue: .main
        ) { _ in
            hasHardwareKeyboard = GCKeyboard.coalesced != nil
        }
        #endif
    }
}
