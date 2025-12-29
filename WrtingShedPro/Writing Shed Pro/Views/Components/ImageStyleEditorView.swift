import SwiftUI
import UIKit

/// SwiftUI view for editing image properties (scale, alignment, caption)
/// Presented as a sheet when inserting or editing images
struct ImageStyleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isScaleFieldFocused: Bool
    @State private var showInvalidScaleAlert = false
    @State private var styleToEdit: TextStyleModel?
    
    // Image data and properties
    let imageData: Data?
    @State private var scale: CGFloat
    @State private var scaleText: String
    @State private var alignment: ImageAttachment.ImageAlignment
    @State private var hasCaption: Bool
    @State private var captionText: String
    @State private var captionStyle: String
    
    // Available caption styles from stylesheet
    let availableCaptionStyles: [String]
    
    // Optional stylesheet for editing styles
    let styleSheet: StyleSheet?
    
    // Callback when user applies changes
    let onApply: (Data?, CGFloat, ImageAttachment.ImageAlignment, Bool, String, String) -> Void
    
    init(
        imageData: Data? = nil,
        scale: CGFloat = 1.0,
        alignment: ImageAttachment.ImageAlignment = .center,
        hasCaption: Bool = false,
        captionText: String = "",
        captionStyle: String = "UICTFontTextStyleCaption1",
        availableCaptionStyles: [String] = ["UICTFontTextStyleCaption1", "UICTFontTextStyleCaption2"],
        styleSheet: StyleSheet? = nil,
        onApply: @escaping (Data?, CGFloat, ImageAttachment.ImageAlignment, Bool, String, String) -> Void
    ) {
        #if DEBUG
        print("🎨 ImageStyleEditorView.init called with imageData: \(imageData?.count ?? 0) bytes")
        #endif
        self.imageData = imageData
        self._scale = State(initialValue: scale)
        self._scaleText = State(initialValue: "\(Int(scale * 100))")
        self._alignment = State(initialValue: alignment)
        self._hasCaption = State(initialValue: hasCaption)
        self._captionText = State(initialValue: captionText)
        self._captionStyle = State(initialValue: captionStyle)
        self.availableCaptionStyles = availableCaptionStyles
        self.styleSheet = styleSheet
        self.onApply = onApply
    }
    
    /// Convert technical style name to display name
    /// UICTFontTextStyleCaption1 -> Caption 1
    /// UICTFontTextStyleFootnote -> Footnote
    private func displayName(for styleName: String) -> String {
        let withoutPrefix = styleName.replacingOccurrences(of: "UICTFontTextStyle", with: "")
        // Add space before numbers: Caption1 -> Caption 1
        let withSpaces = withoutPrefix.replacingOccurrences(of: #"(\d+)"#, with: " $1", options: .regularExpression)
        return withSpaces
    }
    
    var body: some View {
        let _ = print("🎨 ImageStyleEditorView.body rendering, imageData: \(imageData?.count ?? 0) bytes")
        
        NavigationStack {
            Form {
                // Scale Section
                Section {
                    HStack(spacing: 6) {
                        Spacer()
                        
                        Button(action: {
                            decrementScale()
                        }) {
                            Image(systemName: "minus.circle")
                                .font(.title3)
                        }
                        .disabled(scale <= 0.1)
                        .buttonStyle(.plain)
                        
                        TextField("100", text: $scaleText)
                            .font(.body)
                            .frame(width: 50)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .focused($isScaleFieldFocused)
                            .onSubmit {
                                commitScaleFromText()
                            }
                            .onChange(of: isScaleFieldFocused) { oldValue, newValue in
                                if !newValue {
                                    commitScaleFromText()
                                }
                            }
                        
                        Text("%")
                            .font(.body)
                        
                        Button(action: {
                            incrementScale()
                        }) {
                            Image(systemName: "plus.circle")
                                .font(.title3)
                        }
                        .disabled(scale >= 2.0)
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                } header: {
                    Text("imageStyleEditor.scale")
                }
                
                // Alignment Section
                Section {
                    HStack(spacing: 20) {
                        Spacer()
                        
                        AlignmentButton(
                            icon: "text.alignleft",
                            isSelected: alignment == .left,
                            action: { alignment = .left }
                        )
                        
                        AlignmentButton(
                            icon: "text.aligncenter",
                            isSelected: alignment == .center,
                            action: { alignment = .center }
                        )
                        
                        AlignmentButton(
                            icon: "text.alignright",
                            isSelected: alignment == .right,
                            action: { alignment = .right }
                        )
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("imageStyleEditor.alignment")
                }
                
                // Caption Section
                Section {
                    Toggle("imageStyleEditor.showCaption", isOn: $hasCaption)
                        .padding(.vertical, -4)
                    
                    if hasCaption {
                        HStack {
                            Text("Caption")
                                .frame(width: 60, alignment: .leading)
                            TextField("imageStyleEditor.captionText.placeholder", text: $captionText)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(.vertical, -4)
                        
                        HStack {
                            Picker("imageStyleEditor.captionStyle", selection: $captionStyle) {
                                ForEach(availableCaptionStyles, id: \.self) { style in
                                    Text(displayName(for: style))
                                        .tag(style)
                                }
                            }
                            
                            // Edit Style button - opens the style editor for the selected caption style
                            if styleSheet != nil {
                                Button {
                                    if let style = styleSheet?.style(named: captionStyle) {
                                        styleToEdit = style
                                    }
                                } label: {
                                    Image(systemName: "pencil.circle")
                                        .font(.title2)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, -4)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("imageStyleEditor.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $styleToEdit) { style in
                NavigationStack {
                    TextStyleEditorView(style: style, hideDeleteButton: true)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("button.cancel", comment: "")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("imageStyleEditor.apply", comment: "")) {
                        onApply(imageData, scale, alignment, hasCaption, captionText, captionStyle)
                        dismiss()
                    }
                    .disabled(imageData == nil)
                }
            }
        }
        #if targetEnvironment(macCatalyst)
        .frame(minWidth: 500, minHeight: 450)
        #endif
        .alert(NSLocalizedString("imageStyleEditor.invalidScale.title", comment: ""), isPresented: $showInvalidScaleAlert) {
            Button(NSLocalizedString("button.ok", comment: ""), role: .cancel) {
                // Reset to current scale
                scaleText = "\(Int(scale * 100))"
            }
        } message: {
            Text("imageStyleEditor.invalidScale.message")
        }
    }
    
    // MARK: - Helper Methods
    
    private func incrementScale() {
        let newScale = min(scale + 0.05, 2.0)
        scale = (newScale * 100).rounded() / 100 // Round to 2 decimal places
        scaleText = "\(Int(scale * 100))"
        isScaleFieldFocused = false // Dismiss keyboard
    }
    
    private func decrementScale() {
        let newScale = max(scale - 0.05, 0.1)
        scale = (newScale * 100).rounded() / 100 // Round to 2 decimal places
        scaleText = "\(Int(scale * 100))"
        isScaleFieldFocused = false // Dismiss keyboard
    }
    
    private func commitScaleFromText() {
        // Trim whitespace
        let trimmed = scaleText.trimmingCharacters(in: .whitespaces)
        
        // Empty string is invalid - show alert
        if trimmed.isEmpty {
            showInvalidScaleAlert = true
            return
        }
        
        // Try to parse as integer
        if let percentage = Int(trimmed) {
            // Check if in valid range (10-200%)
            if percentage >= 10 && percentage <= 200 {
                scale = CGFloat(percentage) / 100.0
                scaleText = "\(percentage)"
            } else {
                // Out of range - show alert
                showInvalidScaleAlert = true
            }
        } else {
            // Not a valid number - show alert
            showInvalidScaleAlert = true
        }
    }
}

// MARK: - Alignment Button Component

struct AlignmentButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .accentColor : .primary)
            }
        }
        .buttonStyle(.plain)
    }
}


