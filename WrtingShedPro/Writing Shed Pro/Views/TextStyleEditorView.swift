//
//  TextStyleEditorView.swift
//  Writing Shed Pro
//

import SwiftUI
import SwiftData

struct TextStyleEditorView: View {
    @Bindable var style: TextStyleModel
    let isNewStyle: Bool
    let onSave: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var hasUnsavedChanges = false
    @State private var editedDisplayName: String
    @State private var showingFontPicker = false
    
    init(style: TextStyleModel, isNewStyle: Bool = false, onSave: (() -> Void)? = nil) {
        self.style = style
        self.isNewStyle = isNewStyle
        self.onSave = onSave
        _editedDisplayName = State(initialValue: style.displayName)
    }
    
    var body: some View {
        Form {
            // Show read-only banner if this is a system stylesheet
            if style.styleSheet?.isSystemStyleSheet == true {
                Section {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("textStyleEditor.systemStyle.icon.accessibility")
                        Text("textStyleEditor.systemStyle.warning")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Group {
                styleNameSection
                previewSection
                fontSettingsSection
                textColourSection
                paragraphSettingsSection
                if style.styleCategory == .list {
                    listFormatSection
                }
            }
            .disabled(style.styleSheet?.isSystemStyleSheet == true)
        }
        .navigationTitle(style.styleSheet?.isSystemStyleSheet == true ? "textStyleEditor.viewStyle.title" : "textStyleEditor.editStyle.title")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(style.styleSheet?.isSystemStyleSheet == true ? "button.done" : "button.cancel") {
                    dismiss()
                }
            }
            
            if style.styleSheet?.isSystemStyleSheet != true {
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.save") {
                        saveChanges()
                        dismiss()
                    }
                    .disabled(!hasUnsavedChanges || editedDisplayName.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingFontPicker) {
            FontPickerView(selectedFontFamily: Binding(
                get: { style.fontFamily },
                set: { newValue in
                    style.fontFamily = newValue
                    hasUnsavedChanges = true
                }
            ))
        }
    }
    
    // MARK: - Sections
    
    private var styleNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("textStyleEditor.styleName")
                .font(.headline)
            
            TextField("textStyleEditor.styleName", text: $editedDisplayName)
                .onChange(of: editedDisplayName) { hasUnsavedChanges = true }
                .accessibilityLabel("textStyleEditor.styleName.accessibility")
        }
    }
    
    private var fontSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("textStyleEditor.fontSettings")
                .font(.headline)
                
                // Font Family Picker Button
                Button(action: {
                    showingFontPicker = true
                }) {
                    HStack {
                        Text("textStyleEditor.fontTypeface")
                            .foregroundColor(.accentColor)
                        Spacer()
                        Text(style.fontFamily ?? NSLocalizedString("textStyleEditor.fontSystem", comment: "System"))
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("textStyleEditor.fontTypeface.accessibility")
                
                // Font Size
                HStack {
                    Text("textStyleEditor.fontSize")
                    Spacer()
                    Button(action: {
                        style.fontSize = max(8, style.fontSize - 1)
                        hasUnsavedChanges = true
                    }) {
                        Image(systemName: "minus")
                            .frame(width: 44, height: 32)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("textStyleEditor.decreaseFontSize.accessibility")
                    
                    Text("\(Int(style.fontSize)) pt")
                        .frame(width: 60)
                        .accessibilityLabel(String(format: NSLocalizedString("textStyleEditor.fontSizeValue.accessibility", comment: "Font size"), Int(style.fontSize)))
                    
                    Button(action: {
                        style.fontSize = min(96, style.fontSize + 1)
                        hasUnsavedChanges = true
                    }) {
                        Image(systemName: "plus")
                            .frame(width: 44, height: 32)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("textStyleEditor.increaseFontSize.accessibility")
                }
                
                Divider()
                
                // Bold, Italic, Underline, Strikethrough buttons in a row
                HStack(spacing: 20) {
                    Button(action: {
                        style.isBold.toggle()
                        hasUnsavedChanges = true
                    }) {
                        Text("B")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(style.isBold ? .white : .accentColor)
                            .frame(width: 50, height: 44)
                            .background(style.isBold ? Color.accentColor : Color.clear)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentColor, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("textStyleEditor.bold.accessibility")
                    
                    Button(action: {
                        style.isItalic.toggle()
                        hasUnsavedChanges = true
                    }) {
                        Text("I")
                            .font(.system(size: 20, weight: .regular))
                            .italic()
                            .foregroundColor(style.isItalic ? .white : .accentColor)
                            .frame(width: 50, height: 44)
                            .background(style.isItalic ? Color.accentColor : Color.clear)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentColor, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("textStyleEditor.italic.accessibility")
                    
                    Button(action: {
                        style.isUnderlined.toggle()
                        hasUnsavedChanges = true
                    }) {
                        Text("U")
                            .font(.system(size: 20))
                            .underline()
                            .foregroundColor(style.isUnderlined ? .white : .accentColor)
                            .frame(width: 50, height: 44)
                            .background(style.isUnderlined ? Color.accentColor : Color.clear)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentColor, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("textStyleEditor.underline.accessibility")
                    
                    Button(action: {
                        style.isStrikethrough.toggle()
                        hasUnsavedChanges = true
                    }) {
                        Text("S")
                            .font(.system(size: 20))
                            .strikethrough()
                            .foregroundColor(style.isStrikethrough ? .white : .accentColor)
                            .frame(width: 50, height: 44)
                            .background(style.isStrikethrough ? Color.accentColor : Color.clear)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentColor, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("textStyleEditor.strikethrough.accessibility")
                }
                .frame(maxWidth: .infinity)
        }
    }
    
    private var textColourSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("textStyleEditor.textColour")
                .font(.headline)
                
                ColorPicker("textStyleEditor.textColour", selection: Binding(
                    get: {
                        if let uiColor = style.textColor {
                            return Color(uiColor: uiColor)
                        }
                        return Color.primary
                    },
                    set: { newColor in
                        style.textColor = UIColor(newColor)
                        hasUnsavedChanges = true
                    }
                ))
                .accessibilityLabel("textStyleEditor.textColour.accessibility")
        }
    }
    
    private var paragraphSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("textStyleEditor.paragraphSettings")
                .font(.headline)
                
                Picker("textStyleEditor.alignment", selection: Binding(
                    get: { style.alignment },
                    set: { style.alignment = $0; hasUnsavedChanges = true }
                )) {
                    Text("textStyleEditor.alignment.left").tag(NSTextAlignment.left)
                    Text("textStyleEditor.alignment.center").tag(NSTextAlignment.center)
                    Text("textStyleEditor.alignment.right").tag(NSTextAlignment.right)
                    Text("textStyleEditor.alignment.justified").tag(NSTextAlignment.justified)
                    Text("textStyleEditor.alignment.natural").tag(NSTextAlignment.natural)
                }
                
                HStack {
                    Text("textStyleEditor.lineSpacing")
                    TextField("textStyleEditor.spacing", value: Binding(
                        get: { Double(style.lineSpacing) },
                        set: { style.lineSpacing = CGFloat($0); hasUnsavedChanges = true }
                    ), format: .number.precision(.fractionLength(0...1)))
                        .frame(width: 60)
                        .accessibilityLabel("textStyleEditor.lineSpacing.accessibility")
                }
                
                HStack {
                    Text("textStyleEditor.paragraphSpacingBefore")
                    TextField("textStyleEditor.spacing", value: Binding(
                        get: { Double(style.paragraphSpacingBefore) },
                        set: { style.paragraphSpacingBefore = CGFloat($0); hasUnsavedChanges = true }
                    ), format: .number.precision(.fractionLength(0...1)))
                        .frame(width: 60)
                        .accessibilityLabel("textStyleEditor.paragraphSpacingBefore.accessibility")
                }
                
                HStack {
                    Text("textStyleEditor.paragraphSpacingAfter")
                    TextField("textStyleEditor.spacing", value: Binding(
                        get: { Double(style.paragraphSpacingAfter) },
                        set: { style.paragraphSpacingAfter = CGFloat($0); hasUnsavedChanges = true }
                    ), format: .number.precision(.fractionLength(0...1)))
                        .frame(width: 60)
                        .accessibilityLabel("textStyleEditor.paragraphSpacingAfter.accessibility")
                }
                
                HStack {
                    Text("textStyleEditor.firstLineIndent")
                    TextField("textStyleEditor.indent", value: Binding(
                        get: { Double(style.firstLineIndent) },
                        set: { style.firstLineIndent = CGFloat($0); hasUnsavedChanges = true }
                    ), format: .number.precision(.fractionLength(0...1)))
                        .frame(width: 60)
                        .accessibilityLabel("textStyleEditor.firstLineIndent.accessibility")
                }
                
                HStack {
                    Text("textStyleEditor.headIndent")
                    TextField("textStyleEditor.indent", value: Binding(
                        get: { Double(style.headIndent) },
                        set: { style.headIndent = CGFloat($0); hasUnsavedChanges = true }
                    ), format: .number.precision(.fractionLength(0...1)))
                        .frame(width: 60)
                        .accessibilityLabel("textStyleEditor.headIndent.accessibility")
                }
                
                HStack {
                    Text("textStyleEditor.tailIndent")
                    TextField("textStyleEditor.indent", value: Binding(
                        get: { Double(style.tailIndent) },
                        set: { style.tailIndent = CGFloat($0); hasUnsavedChanges = true }
                    ), format: .number.precision(.fractionLength(0...1)))
                        .frame(width: 60)
                        .accessibilityLabel("textStyleEditor.tailIndent.accessibility")
                }
        }
    }
    
    private var listFormatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("textStyleEditor.listFormat")
                .font(.headline)
            
            Picker("textStyleEditor.numberFormat", selection: Binding(
                get: { style.numberFormat },
                set: { style.numberFormat = $0; hasUnsavedChanges = true }
            )) {
                ForEach(NumberFormat.allCases, id: \.self) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .accessibilityLabel("textStyleEditor.numberFormat.accessibility")
        }
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("textStyleEditor.preview")
                .font(.headline)
                
                Text("textStyleEditor.preview.text")
                    .font(Font(style.generateFont()))
                    .underline(style.isUnderlined)
                    .strikethrough(style.isStrikethrough)
                    .foregroundColor(style.textColor != nil ? Color(uiColor: style.textColor!) : .primary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                    .accessibilityLabel("textStyleEditor.preview.accessibility")
        }
    }
    
    // MARK: - Save
    
    private func saveChanges() {
        style.displayName = editedDisplayName
        
        // Update stylesheet's modified date to trigger view updates
        if let stylesheet = style.styleSheet {
            stylesheet.modifiedDate = Date()
        }
        
        do {
            try modelContext.save()
            onSave?() // Notify that changes were saved
            
            // Notify that a style in the stylesheet has been modified
            if let stylesheetID = style.styleSheet?.id {
                print("📤 Posting StyleSheetModified notification for stylesheet: \(stylesheetID.uuidString)")
                NotificationCenter.default.post(
                    name: NSNotification.Name("StyleSheetModified"),
                    object: nil,
                    userInfo: ["stylesheetID": stylesheetID]
                )
                print("✅ StyleSheetModified notification posted")
            } else {
                print("⚠️ Style has no stylesheet - cannot post notification")
            }
        } catch {
            print("Error saving style: \(error)")
        }
    }
}
