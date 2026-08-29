import SwiftUI
import UIKit

enum ImageScaleInput {
    static func scale(from text: String) -> CGFloat? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let percentage = Int(trimmed), (10...200).contains(percentage) else {
            return nil
        }
        return CGFloat(percentage) / 100.0
    }
}

struct ImageStyleEditorValues {
    let imageData: Data?
    let imageStyleName: String
    let scale: CGFloat
    let alignment: ImageAttachment.ImageAlignment
    let hasCaption: Bool
    let captionPrefix: String
    let captionText: String
    let captionStyle: String
    let spacingAbove: CGFloat
    let spacingBelow: CGFloat
    let borderStyle: ImageAttachment.BorderStyle
    let borderPadding: CGFloat
}

/// SwiftUI view for editing image properties (scale, alignment, caption)
/// Presented as a sheet when inserting or editing images
struct ImageStyleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isScaleFieldFocused: Bool
    @State private var showInvalidScaleAlert = false
    @State private var styleToEdit: TextStyleModel?
    @State private var showUpdateStyleConfirmation = false
    @State private var pendingStyleUpdate: ImageStyleEditorValues?
    
    // Image data and properties
    let imageData: Data?
    @State private var scale: CGFloat
    @State private var scaleText: String
    @State private var alignment: ImageAttachment.ImageAlignment
    @State private var hasCaption: Bool
    @State private var captionPrefix: String
    @State private var captionText: String
    @State private var captionStyle: String
    @State private var imageStyleName: String
    @State private var spacingAboveText: String
    @State private var spacingBelowText: String
    @State private var borderStyle: ImageAttachment.BorderStyle
    @State private var borderPaddingText: String
    
    // Available caption styles from stylesheet
    let availableCaptionStyles: [String]
    let availableImageStyles: [ImageStyle]
    
    // Optional stylesheet for editing styles
    let styleSheet: StyleSheet?
    
    // Callback when user applies changes
    let onApply: (ImageStyleEditorValues) -> Void
    let onUpdateStyle: ((ImageStyleEditorValues) -> Void)?
    let onCancel: () -> Void
    
    init(
        imageData: Data? = nil,
        scale: CGFloat = 1.0,
        alignment: ImageAttachment.ImageAlignment = .center,
        hasCaption: Bool = false,
        captionPrefix: String = "Figure",
        captionText: String = "",
        captionStyle: String = "UICTFontTextStyleCaption1",
        imageStyleName: String = "default",
        spacingAbove: CGFloat = 0,
        spacingBelow: CGFloat = 0,
        borderStyle: ImageAttachment.BorderStyle = .none,
        borderPadding: CGFloat = 0,
        availableCaptionStyles: [String] = ["UICTFontTextStyleCaption1", "UICTFontTextStyleCaption2"],
        availableImageStyles: [ImageStyle] = [],
        styleSheet: StyleSheet? = nil,
        onApply: @escaping (ImageStyleEditorValues) -> Void,
        onUpdateStyle: ((ImageStyleEditorValues) -> Void)? = nil,
        onCancel: @escaping () -> Void = {}
    ) {
        #if DEBUG
        print("🎨 ImageStyleEditorView.init called with imageData: \(imageData?.count ?? 0) bytes")
        #endif
        self.imageData = imageData
        self._scale = State(initialValue: scale)
        self._scaleText = State(initialValue: "\(Int(scale * 100))")
        self._alignment = State(initialValue: alignment)
        self._hasCaption = State(initialValue: hasCaption)
        self._captionPrefix = State(initialValue: captionPrefix)
        self._captionText = State(initialValue: captionText)
        self._spacingAboveText = State(initialValue: Self.spacingText(spacingAbove))
        self._spacingBelowText = State(initialValue: Self.spacingText(spacingBelow))
        self._borderStyle = State(initialValue: borderStyle)
        self._borderPaddingText = State(initialValue: Self.spacingText(borderPadding))
        // Normalize caption style to match available styles (handles legacy values like "caption1")
        let normalizedStyle = Self.normalizedCaptionStyle(captionStyle, availableStyles: availableCaptionStyles)
        self._captionStyle = State(initialValue: normalizedStyle)
        let selectedImageStyleName = availableImageStyles.contains(where: { $0.name == imageStyleName })
            ? imageStyleName
            : availableImageStyles.first?.name ?? imageStyleName
        self._imageStyleName = State(initialValue: selectedImageStyleName)
        self.availableCaptionStyles = availableCaptionStyles
        self.availableImageStyles = availableImageStyles.sorted {
            if $0.displayOrder != $1.displayOrder { return $0.displayOrder < $1.displayOrder }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        self.styleSheet = styleSheet
        self.onApply = onApply
        self.onUpdateStyle = onUpdateStyle
        self.onCancel = onCancel
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
    
    /// Normalize caption style to match available styles
    /// Handles legacy values like "caption1" -> "UICTFontTextStyleCaption1"
    private static func normalizedCaptionStyle(_ style: String, availableStyles: [String]) -> String {
        // If it already matches an available style, use it
        if availableStyles.contains(style) {
            return style
        }
        
        // Try to find a matching style (case-insensitive, with or without prefix)
        let normalizedInput = style.lowercased().replacingOccurrences(of: "uictfonttextstyle", with: "")
        
        for availableStyle in availableStyles {
            let normalizedAvailable = availableStyle.lowercased().replacingOccurrences(of: "uictfonttextstyle", with: "")
            if normalizedInput == normalizedAvailable {
                return availableStyle
            }
        }
        
        // Default to first available style, or a sensible default
        return availableStyles.first ?? "UICTFontTextStyleCaption1"
    }
    
    var body: some View {
        let _ = print("🎨 ImageStyleEditorView.body rendering, imageData: \(imageData?.count ?? 0) bytes")
        
        NavigationStack {
            Form {
                if !availableImageStyles.isEmpty {
                    Section("imageStyleEditor.imageStyle") {
                        if availableImageStyles.count > 1 {
                            Picker("imageStyleEditor.imageStyle", selection: $imageStyleName) {
                                ForEach(availableImageStyles, id: \.id) { imageStyle in
                                    Text(imageStyle.displayName).tag(imageStyle.name)
                                }
                            }
                            .onChange(of: imageStyleName) { _, _ in
                                resetToSelectedStyle()
                            }
                        } else if let imageStyle = availableImageStyles.first {
                            LabeledContent("imageStyleEditor.imageStyle", value: imageStyle.displayName)
                        }

                        Button("imageStyleEditor.resetToStyle") {
                            resetToSelectedStyle()
                        }

                        if onUpdateStyle != nil {
                            Button("imageStyleEditor.updateStyle") {
                                requestStyleUpdate()
                            }
                        }
                    }
                }

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

                Section("imageStyleEditor.spacing") {
                    spacingField("imageStyleEditor.spacingAbove", text: $spacingAboveText)
                    spacingField("imageStyleEditor.spacingBelow", text: $spacingBelowText)
                }

                Section("imageStyleEditor.border") {
                    Picker("imageStyleEditor.borderStyle", selection: $borderStyle) {
                        ForEach(ImageAttachment.BorderStyle.allCases, id: \.rawValue) { style in
                            Text(LocalizedStringKey(style.localizationKey)).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    spacingField("imageStyleEditor.borderPadding", text: $borderPaddingText)
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
                            Text("Prefix")
                                .frame(width: 60, alignment: .leading)
                            TextField("Figure", text: $captionPrefix)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(.vertical, -4)
                        
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
                            
                            // Edit Style button
                            if styleSheet != nil {
                                Button {
                                    if let style = styleSheet?.style(named: captionStyle) {
                                        styleToEdit = style
                                    }
                                } label: {
                                    Image(systemName: "pencil.circle")
                                        .font(.title2)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .padding(.vertical, -4)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("imageStyleEditor.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $styleToEdit, onDismiss: {
                styleToEdit = nil
            }) { style in
                NavigationStack {
                    TextStyleEditorView(
                        style: style,
                        onSave: {
                            styleToEdit = nil
                        },
                        hideDeleteButton: true
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("button.cancel", comment: "")) {
                        dismissSheet()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("imageStyleEditor.apply", comment: "")) {
                        commitValues(using: onApply)
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
        .confirmationDialog(
            "imageStyleEditor.updateStyle.confirmation.title",
            isPresented: $showUpdateStyleConfirmation,
            titleVisibility: .visible
        ) {
            Button("imageStyleEditor.updateStyle.confirmation.confirm") {
                guard let values = pendingStyleUpdate, let onUpdateStyle else { return }
                pendingStyleUpdate = nil
                onUpdateStyle(values)
                dismissSheet()
            }
            Button("button.cancel", role: .cancel) {
                pendingStyleUpdate = nil
            }
        } message: {
            Text("imageStyleEditor.updateStyle.confirmation.message")
        }
    }
    
    // MARK: - Helper Methods

    private func spacingField(_ title: LocalizedStringKey, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
            Text("imageStyleEditor.points")
                .foregroundStyle(.secondary)
        }
    }

    private static func spacingValue(_ text: String) -> CGFloat {
        let normalized = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return max(0, CGFloat(Double(normalized) ?? 0))
    }

    private static func spacingText(_ value: CGFloat) -> String {
        value.rounded() == value ? String(Int(value)) : String(Double(value))
    }

    private func resetToSelectedStyle() {
        guard let imageStyle = availableImageStyles.first(where: { $0.name == imageStyleName }) else {
            return
        }
        scale = imageStyle.defaultScale
        scaleText = "\(Int(imageStyle.defaultScale * 100))"
        alignment = imageStyle.defaultAlignment
        hasCaption = imageStyle.hasCaptionByDefault
        captionStyle = Self.normalizedCaptionStyle(
            imageStyle.defaultCaptionStyle,
            availableStyles: availableCaptionStyles
        )
        spacingAboveText = Self.spacingText(imageStyle.defaultSpacingAbove)
        spacingBelowText = Self.spacingText(imageStyle.defaultSpacingBelow)
        borderStyle = imageStyle.defaultBorderStyle
        borderPaddingText = Self.spacingText(imageStyle.defaultBorderPadding)
    }

    private func commitValues(using action: ((ImageStyleEditorValues) -> Void)?) {
        guard let action else { return }
        guard let values = currentValues() else { return }
        action(values)
        dismissSheet()
    }

    private func requestStyleUpdate() {
        guard let values = currentValues() else { return }
        pendingStyleUpdate = values
        showUpdateStyleConfirmation = true
    }

    private func currentValues() -> ImageStyleEditorValues? {
        guard let committedScale = ImageScaleInput.scale(from: scaleText) else {
            showInvalidScaleAlert = true
            return nil
        }
        scale = committedScale
        scaleText = "\(Int(committedScale * 100))"
        return ImageStyleEditorValues(
            imageData: imageData,
            imageStyleName: imageStyleName,
            scale: committedScale,
            alignment: alignment,
            hasCaption: hasCaption,
            captionPrefix: captionPrefix,
            captionText: captionText,
            captionStyle: captionStyle,
            spacingAbove: Self.spacingValue(spacingAboveText),
            spacingBelow: Self.spacingValue(spacingBelowText),
            borderStyle: borderStyle,
            borderPadding: Self.spacingValue(borderPaddingText)
        )
    }
    
    private func dismissSheet() {
        onCancel()
        dismiss()
        dismissPresentedSheetOnCatalyst()
    }
    
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
        if let committedScale = ImageScaleInput.scale(from: scaleText) {
            scale = committedScale
            scaleText = "\(Int(committedScale * 100))"
        } else {
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


