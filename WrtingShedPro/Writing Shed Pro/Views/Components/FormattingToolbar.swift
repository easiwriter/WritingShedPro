import SwiftUI

/// A formatting toolbar that appears above the keyboard (or at the top on Mac Catalyst)
/// Provides buttons for paragraph styles and character formatting
struct FormattingToolbar: View {
    
    // MARK: - Bindings
    
    /// The currently selected text range
    @Binding var selectedRange: NSRange
    
    /// The attributed text being edited
    @Binding var attributedText: NSAttributedString
    
    // MARK: - Callbacks
    
    /// Called when user wants to change paragraph style
    var onStylePicker: (() -> Void)?
    
    /// Called when user toggles bold
    var onToggleBold: (() -> Void)?
    
    /// Called when user toggles italic
    var onToggleItalic: (() -> Void)?
    
    /// Called when user toggles underline
    var onToggleUnderline: (() -> Void)?
    
    /// Called when user toggles strikethrough
    var onToggleStrikethrough: (() -> Void)?
    
    /// Called when user taps image style button
    var onImageStyle: (() -> Void)?
    
    /// Called when user taps insert button (shows "Coming Soon")
    var onInsert: (() -> Void)?
    
    /// Whether an image is currently selected
    var isImageSelected: Bool = false
    
    // MARK: - State
    
    /// Whether bold is active at current selection
    @State private var isBoldActive: Bool = false
    
    /// Whether italic is active at current selection
    @State private var isItalicActive: Bool = false
    
    /// Whether underline is active at current selection
    @State private var isUnderlineActive: Bool = false
    
    /// Whether strikethrough is active at current selection
    @State private var isStrikethroughActive: Bool = false
    
    /// Whether to show "Coming Soon" alert
    @State private var showComingSoonAlert: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 0) {
            // Left spacing
            Spacer()
//                .frame(width: 16)
            
            // Paragraph Style button
            Button(action: {
                onStylePicker?()
            }) {
                Image(systemName: "paragraph")
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .help("Paragraph Style")
            
            Spacer()
                .frame(width: 20)
            
            Divider()
                .frame(height: 24)
            
            Spacer()
                .frame(width: 20)
            
            // Bold button
            Button(action: {
                onToggleBold?()
            }) {
                Image(systemName: "bold")
                    .imageScale(.large)
                    .foregroundColor(isBoldActive ? .accentColor : .primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Bold")
            
            Spacer()
                .frame(width: 20)
            
            // Italic button
            Button(action: {
                onToggleItalic?()
            }) {
                Image(systemName: "italic")
                    .imageScale(.large)
                    .foregroundColor(isItalicActive ? .accentColor : .primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Italic")
            
            Spacer()
                .frame(width: 20)
            
            // Underline button
            Button(action: {
                onToggleUnderline?()
            }) {
                Image(systemName: "underline")
                    .imageScale(.large)
                    .foregroundColor(isUnderlineActive ? .accentColor : .primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Underline")
            
            Spacer()
                .frame(width: 20)
            
            // Strikethrough button
            Button(action: {
                onToggleStrikethrough?()
            }) {
                Image(systemName: "strikethrough")
                    .imageScale(.large)
                    .foregroundColor(isStrikethroughActive ? .accentColor : .primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Strikethrough")
            
            Spacer()
                .frame(width: 20)
            
            Divider()
                .frame(height: 24)
            
            Spacer()
                .frame(width: 20)
            
            // Image Style button
            Button(action: {
                onImageStyle?()
            }) {
                Image(systemName: "photo")
                    .imageScale(.large)
                    .foregroundColor(isImageSelected ? .accentColor : .secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isImageSelected)
            .help("Image Style")
            
            Spacer()
                .frame(width: 20)
            
            Divider()
                .frame(height: 24)
            
            Spacer()
                .frame(width: 20)
            
            // Insert button (Coming Soon)
            Button(action: {
                showComingSoonAlert = true
            }) {
                Image(systemName: "plus.circle")
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .help("Insert (Coming Soon)")
            
            // Right spacing
            Spacer()
//                .frame(width: 16)
        }
        .frame(height: 44)
        .onChange(of: selectedRange) { _, _ in
            Task { @MainActor in
                updateButtonStates()
            }
        }
        .onChange(of: attributedText) { _, _ in
            Task { @MainActor in
                updateButtonStates()
            }
        }
        .onAppear {
            Task { @MainActor in
                updateButtonStates()
            }
        }
        .alert(NSLocalizedString("formattingToolbar.comingSoon.title", comment: ""), isPresented: $showComingSoonAlert) {
            Button(NSLocalizedString("button.ok", comment: ""), role: .cancel) { }
        } message: {
            Text("formattingToolbar.comingSoon.message")
        }
    }
    
    // MARK: - Private Methods
    
    /// Update button states based on current selection
    private func updateButtonStates() {
        // If no selection or selection is out of bounds, disable all
        guard selectedRange.location != NSNotFound,
              selectedRange.location <= attributedText.length else {
            isBoldActive = false
            isItalicActive = false
            isUnderlineActive = false
            isStrikethroughActive = false
            return
        }
        
        // For collapsed selection (cursor), check typing attributes at cursor position
        // For range selection, check if entire range has the attribute
        let checkRange: NSRange
        if selectedRange.length == 0 {
            // Cursor position - only show state if cursor is after a character
            // Don't show state when cursor is at position 0 (start of document)
            guard selectedRange.location > 0 else {
                isBoldActive = false
                isItalicActive = false
                isUnderlineActive = false
                isStrikethroughActive = false
                return
            }
            
            // Check character before cursor
            let location = selectedRange.location - 1
            checkRange = NSRange(location: location, length: 1)
        } else {
            checkRange = selectedRange
        }
        
        // Skip if empty string
        guard checkRange.length > 0 else {
            isBoldActive = false
            isItalicActive = false
            isUnderlineActive = false
            isStrikethroughActive = false
            return
        }
        
        // Check attributes at the range
        var hasBold = false
        var hasItalic = false
        var hasUnderline = false
        var hasStrikethrough = false
        
        attributedText.enumerateAttributes(in: checkRange, options: []) { attributes, range, stop in
            // Check font traits
            if let font = attributes[.font] as? UIFont {
                let traits = font.fontDescriptor.symbolicTraits
                if traits.contains(.traitBold) {
                    hasBold = true
                }
                if traits.contains(.traitItalic) {
                    hasItalic = true
                }
            }
            
            // Check underline
            if let underlineStyle = attributes[.underlineStyle] as? Int,
               underlineStyle != 0 {
                hasUnderline = true
            }
            
            // Check strikethrough
            if let strikethroughStyle = attributes[.strikethroughStyle] as? Int,
               strikethroughStyle != 0 {
                hasStrikethrough = true
            }
        }
        
        isBoldActive = hasBold
        isItalicActive = hasItalic
        isUnderlineActive = hasUnderline
        isStrikethroughActive = hasStrikethrough
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        
        FormattingToolbar(
            selectedRange: .constant(NSRange(location: 0, length: 0)),
            attributedText: .constant(NSAttributedString(string: "Sample text"))
        )
    }
}
