import SwiftUI
import GameController

/// Pure SwiftUI formatting toolbar - works correctly with iOS 26.2+ button styling
struct SwiftUIFormattingToolbar: View {
    let onFormatAction: (FormattingAction) -> Void
    let hasSelectedImage: Bool
    let notesExist: Bool
    @State private var hasHardwareKeyboard = false
    @State private var isKeyboardVisible = false
    
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
        case increaseIndent
        case decreaseIndent
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
                
                // Paragraph style (disabled when image selected)
                toolbarButton(systemName: "paragraph", action: .paragraphStyle)
                    .opacity(hasSelectedImage ? 0.3 : 1.0)
                    .disabled(hasSelectedImage)
                
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
                
                // Text formatting (disabled when image selected)
                toolbarButton(systemName: "bold", action: .bold)
                    .opacity(hasSelectedImage ? 0.3 : 1.0)
                    .disabled(hasSelectedImage)
                toolbarButton(systemName: "italic", action: .italic)
                    .opacity(hasSelectedImage ? 0.3 : 1.0)
                    .disabled(hasSelectedImage)
                toolbarButton(systemName: "underline", action: .underline)
                    .opacity(hasSelectedImage ? 0.3 : 1.0)
                    .disabled(hasSelectedImage)
                toolbarButton(systemName: "strikethrough", action: .strikethrough)
                    .opacity(hasSelectedImage ? 0.3 : 1.0)
                    .disabled(hasSelectedImage)
                
                Divider()
                    .frame(height: 24)
                
                // List indent/outdent buttons (disabled when image selected)
                toolbarButton(systemName: "decrease.indent", action: .decreaseIndent)
                    .opacity(hasSelectedImage ? 0.3 : 1.0)
                    .disabled(hasSelectedImage)
                toolbarButton(systemName: "increase.indent", action: .increaseIndent)
                    .opacity(hasSelectedImage ? 0.3 : 1.0)
                    .disabled(hasSelectedImage)
                
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
    
    private func toolbarButton(systemName: String, action: FormattingAction, tint: Color? = nil) -> some View {
        Button {
            onFormatAction(action)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 17))
                .frame(width: 32, height: 44)
                .foregroundColor(tint)
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
