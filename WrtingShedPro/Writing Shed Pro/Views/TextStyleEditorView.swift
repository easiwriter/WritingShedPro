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
                        Text("This is a system default style and cannot be edited. Create a custom stylesheet to modify styles.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            styleNameSection
            Divider()
            fontSettingsSection
            Divider()
            textColourSection
            Divider()
            paragraphSettingsSection
            Divider()
            if style.styleCategory == .list {
                listFormatSection
                Divider()
            }
            previewSection
        }
        .navigationTitle(style.styleSheet?.isSystemStyleSheet == true ? "View Style" : "Edit Style")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(style.styleSheet?.isSystemStyleSheet == true ? "Done" : "Cancel") {
                    dismiss()
                }
            }
            
            if style.styleSheet?.isSystemStyleSheet != true {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .disabled(!hasUnsavedChanges || editedDisplayName.isEmpty)
                }
            }
        }
        .disabled(style.styleSheet?.isSystemStyleSheet == true)
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
            Text("Style Name")
                .font(.headline)
                .padding(.top)
            
            TextField("Style Name", text: $editedDisplayName)
                .onChange(of: editedDisplayName) { hasUnsavedChanges = true }
        }
        .padding(.bottom, 8)
    }
    
    private var fontSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Font Settings")
                .font(.headline)
                .padding(.top)
                
                // Font Family Picker Button
                Button(action: {
                    showingFontPicker = true
                }) {
                    HStack {
                        Text("Font-Typeface")
                            .foregroundColor(.accentColor)
                        Spacer()
                        Text(style.fontFamily ?? "System")
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                // Font Size
                HStack {
                    Text("Size")
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
                    
                    Text("\(Int(style.fontSize)) pt")
                        .frame(width: 60)
                    
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
                }
                .frame(maxWidth: .infinity)
        }
        .padding(.bottom, 8)
    }
    
    private var textColourSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Text Colour")
                .font(.headline)
                .padding(.top)
                
                ColorPicker("Text Color", selection: Binding(
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
        }
        .padding(.bottom, 8)
    }
    
    private var paragraphSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paragraph Settings")
                .font(.headline)
                .padding(.top)
                
                Picker("Alignment", selection: Binding(
                    get: { style.alignment },
                    set: { style.alignment = $0; hasUnsavedChanges = true }
                )) {
                    Text("Left").tag(NSTextAlignment.left)
                    Text("Center").tag(NSTextAlignment.center)
                    Text("Right").tag(NSTextAlignment.right)
                    Text("Justified").tag(NSTextAlignment.justified)
                    Text("Natural").tag(NSTextAlignment.natural)
                }
                
                HStack {
                    Text("Line Spacing:")
                    TextField("Spacing", value: Binding(
                        get: { Double(style.lineSpacing) },
                        set: { style.lineSpacing = CGFloat($0); hasUnsavedChanges = true }
                    ), format: .number.precision(.fractionLength(0...1)))
                        .frame(width: 60)
                }
                
                HStack {
                    Text("Paragraph Spacing Before:")
                    TextField("Spacing", value: Binding(
                        get: { Double(style.paragraphSpacingBefore) },
                        set: { style.paragraphSpacingBefore = CGFloat($0); hasUnsavedChanges = true }
                    ), format: .number.precision(.fractionLength(0...1)))
                        .frame(width: 60)
                }
                
                HStack {
                    Text("Paragraph Spacing After:")
                    TextField("Spacing", value: Binding(
                        get: { Double(style.paragraphSpacingAfter) },
                        set: { style.paragraphSpacingAfter = CGFloat($0); hasUnsavedChanges = true }
                    ), format: .number.precision(.fractionLength(0...1)))
                        .frame(width: 60)
                }
                
                HStack {
                    Text("First Line Indent:")
                    TextField("Indent", value: Binding(
                        get: { Double(style.firstLineIndent) },
                        set: { style.firstLineIndent = CGFloat($0); hasUnsavedChanges = true }
                    ), format: .number.precision(.fractionLength(0...1)))
                        .frame(width: 60)
                }
                
                HStack {
                    Text("Head Indent (Left):")
                    TextField("Indent", value: Binding(
                        get: { Double(style.headIndent) },
                        set: { style.headIndent = CGFloat($0); hasUnsavedChanges = true }
                    ), format: .number.precision(.fractionLength(0...1)))
                        .frame(width: 60)
                }
                
                HStack {
                    Text("Tail Indent (Right):")
                    TextField("Indent", value: Binding(
                        get: { Double(style.tailIndent) },
                        set: { style.tailIndent = CGFloat($0); hasUnsavedChanges = true }
                    ), format: .number.precision(.fractionLength(0...1)))
                        .frame(width: 60)
                }
        }
        .padding(.bottom, 8)
    }
    
    private var listFormatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("List Format")
                .font(.headline)
                .padding(.top)
            
            Picker("Number Format", selection: Binding(
                get: { style.numberFormat },
                set: { style.numberFormat = $0; hasUnsavedChanges = true }
            )) {
                ForEach(NumberFormat.allCases, id: \.self) { format in
                    Text(format.displayName).tag(format)
                }
            }
        }
        .padding(.bottom, 8)
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.headline)
                .padding(.top)
                
                Text("The quick brown fox jumps over the lazy dog")
                    .font(Font(style.generateFont()))
                    .underline(style.isUnderlined)
                    .strikethrough(style.isStrikethrough)
                    .foregroundColor(style.textColor != nil ? Color(uiColor: style.textColor!) : .primary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Save
    
    private func saveChanges() {
        style.displayName = editedDisplayName
        
        do {
            try modelContext.save()
            onSave?() // Notify that changes were saved
            
            // Notify that a style in the stylesheet has been modified
            if let stylesheetID = style.styleSheet?.id {
                NotificationCenter.default.post(
                    name: NSNotification.Name("StyleSheetModified"),
                    object: nil,
                    userInfo: ["stylesheetID": stylesheetID]
                )
            }
        } catch {
            print("Error saving style: \(error)")
        }
    }
}
