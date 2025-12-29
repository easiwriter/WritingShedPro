import SwiftUI

/// Pure SwiftUI formatting toolbar - works correctly with iOS 26.2+ button styling
struct SwiftUIFormattingToolbar: View {
    let onFormatAction: (FormattingAction) -> Void
    let hasSelectedImage: Bool
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
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Paragraph style (disabled when image selected)
            toolbarButton(systemName: "text.square.filled", action: .paragraphStyle)
                .opacity(hasSelectedImage ? 0.3 : 1.0)
                .disabled(hasSelectedImage)
            
            Divider()
                .frame(height: 24)
            
            // Image style (only enabled when image selected)
            toolbarButton(systemName: "photo", action: .imageStyle)
                .opacity(hasSelectedImage ? 1.0 : 0.3)
                .disabled(!hasSelectedImage)
            
            // Notes (disabled when image selected)
            toolbarButton(systemName: "list.clipboard", action: .notes)
                .opacity(hasSelectedImage ? 0.3 : 1.0)
                .disabled(hasSelectedImage)
            
            Divider()
                .frame(height: 24)
            
            // Lists (disabled when image selected)
            toolbarButton(systemName: "list.number", action: .numberedList)
                .opacity(hasSelectedImage ? 0.3 : 1.0)
                .disabled(hasSelectedImage)
            toolbarButton(systemName: "list.bullet", action: .bulletedList)
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
        .frame(maxWidth: .infinity, maxHeight: 44)
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .top) {
            Divider()
        }
        .onAppear {
            detectHardwareKeyboard()
            observeKeyboardNotifications()
        }
    }
    
    private func toolbarButton(systemName: String, action: FormattingAction) -> some View {
        Button {
            onFormatAction(action)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 17))
                .frame(width: 32, height: 44)
        }
        .buttonStyle(.plain)
        .controlSize(.small)
    }
    
    private func detectHardwareKeyboard() {
        #if !targetEnvironment(macCatalyst)
        // Check if hardware keyboard is connected
        if UIDevice.current.userInterfaceIdiom == .pad {
            // On iPad, assume hardware keyboard might be present
            hasHardwareKeyboard = false // Start showing cursor buttons, will hide if hardware keyboard detected
        } else {
            hasHardwareKeyboard = false
        }
        #endif
    }
    
    private func observeKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { _ in
            isKeyboardVisible = true
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            isKeyboardVisible = false
        }
    }
}
