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
    @State private var showingDeleteAlert = false
    @State private var deleteErrorMessage: String?
    @State private var showingReplacementPicker = false
    @State private var filesUsingStyle: [String] = []
    @State private var showingSaveOptionsAlert = false
    
    // Get the project associated with this style's stylesheet
    private var project: Project? {
        style.styleSheet?.projects?.first
    }
    
    init(style: TextStyleModel, isNewStyle: Bool = false, onSave: (() -> Void)? = nil) {
        self.style = style
        self.isNewStyle = isNewStyle
        self.onSave = onSave
        _editedDisplayName = State(initialValue: style.displayName)
        
        #if DEBUG
        print("📝 TextStyleEditorView - Style: \(style.displayName)")
        print("   Name: \(style.name)")
        print("   Category: \(style.styleCategory.rawValue)")
        print("   Category raw: \(style.styleCategoryRaw)")
        #endif
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
                fontSettingsSection
                textColourSection
                paragraphSettingsSection
                numberingSection
                followOnStyleSection
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
                // Delete button (only for non-system styles)
                if !style.isSystemStyle {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(role: .destructive) {
                            handleDeleteAttempt()
                        } label: {
                            Label("button.delete", systemImage: "trash")
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.save") {
                        if isNewStyle {
                            // For new styles, just save directly
                            saveChanges()
                            dismiss()
                        } else {
                            // For existing styles, show options alert
                            showingSaveOptionsAlert = true
                        }
                    }
                    .disabled(!hasUnsavedChanges || editedDisplayName.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingFontPicker) {
            FontPickerView(
                selectedFontFamily: Binding(
                    get: { style.fontFamily },
                    set: { newValue in
                        style.fontFamily = newValue
                        hasUnsavedChanges = true
                    }
                ),
                selectedFontName: Binding(
                    get: { style.fontName },
                    set: { newValue in
                        style.fontName = newValue
                        // Update bold/italic flags based on font name
                        if newValue != nil {
                            style.updateTraitsFromFontName()
                        }
                        hasUnsavedChanges = true
                    }
                ),
                onFontSelected: {
                    // Font changed, mark as unsaved
                    hasUnsavedChanges = true
                }
            )
        }
        .alert("textStyleEditor.delete.title", isPresented: $showingDeleteAlert) {
            if filesUsingStyle.isEmpty {
                Button("button.delete", role: .destructive) {
                    performDelete()
                }
                Button("button.cancel", role: .cancel) { }
            } else {
                Button("textStyleEditor.delete.replaceAndDelete", role: .destructive) {
                    showingReplacementPicker = true
                }
                Button("button.cancel", role: .cancel) { }
            }
        } message: {
            if filesUsingStyle.isEmpty {
                Text("textStyleEditor.delete.confirm")
            } else {
                let fileList = filesUsingStyle.prefix(3).joined(separator: ", ")
                Text(String(format: NSLocalizedString("textStyleEditor.delete.inUse", comment: ""), filesUsingStyle.count, fileList))
            }
        }
        .sheet(isPresented: $showingReplacementPicker) {
            if let project = project {
                StyleReplacementPickerView(
                    currentStyle: style,
                    project: project,
                    onStyleSelected: { replacementStyle in
                        performDelete(replacementStyle: replacementStyle)
                        showingReplacementPicker = false
                        dismiss()
                    }
                )
            }
        }
        .alert("textStyleEditor.saveOptions.title", isPresented: $showingSaveOptionsAlert) {
            Button("textStyleEditor.saveOptions.updateStyle") {
                // Update the existing style - changes apply to all documents automatically
                saveChanges()
                dismiss()
            }
            Button("textStyleEditor.saveOptions.createNewStyle") {
                // Create a new style with asterisk suffix
                createNewStyleFromChanges()
                dismiss()
            }
            Button("button.cancel", role: .cancel) { }
        } message: {
            Text("textStyleEditor.saveOptions.message")
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
                        updateFontVariant()
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
                        updateFontVariant()
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
    
    private var numberingSection: some View {
        Group {
            // Don't show numbering section for footnote styles - they always use decimal
            if style.styleCategory != .footnote {
                Section {
                    // List styles always have numbering - no toggle needed
                    if style.styleCategory == .list {
                        VStack(alignment: .leading, spacing: 12) {
                            // Bullet list: just show info
                            if style.name == "list-bullet" {
                                Text("textStyleEditor.bulletListInfo")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 4)
                            }
                            // Numbered list: show format and adornment pickers
                            else if style.name == "list-numbered" {
                                Picker("textStyleEditor.numberStyle", selection: Binding(
                                    get: { style.numberFormat },
                                    set: { style.numberFormat = $0; hasUnsavedChanges = true }
                                )) {
                                    ForEach(numberFormats, id: \.self) { format in
                                        Text(format.displayName).tag(format)
                                    }
                                }
                                .pickerStyle(.menu)
                                
                                Picker("textStyleEditor.adornment", selection: Binding(
                                    get: { style.numberAdornment },
                                    set: { style.numberAdornment = $0; hasUnsavedChanges = true }
                                )) {
                                    ForEach(NumberingAdornment.allCases, id: \.self) { adornment in
                                        Text(adornment.displayName).tag(adornment)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    // Non-list styles: show toggle and controls
                    else {
                        // Enable/disable numbering toggle
                        Toggle(isOn: Binding(
                    get: { style.numberFormat != .none },
                    set: { enabled in
                        if enabled {
                            if style.name == "list-bullet" {
                                style.numberFormat = .bulletSymbols
                            } else {
                                style.numberFormat = .decimal
                                style.numberAdornment = .period
                            }
                        } else {
                            // Disable numbering
                            style.numberFormat = .none
                        }
                        hasUnsavedChanges = true
                    }
                )) {
                    Label("textStyleEditor.enableNumbering", systemImage: "list.number")
                }
                
                // Show format options only when numbering is enabled
                if style.numberFormat != .none {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("textStyleEditor.numberStyle", selection: Binding(
                            get: { style.numberFormat },
                            set: { style.numberFormat = $0; hasUnsavedChanges = true }
                        )) {
                            ForEach(numberFormats, id: \.self) { format in
                                Text(format.displayName).tag(format)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Picker("textStyleEditor.adornment", selection: Binding(
                            get: { style.numberAdornment },
                            set: { style.numberAdornment = $0; hasUnsavedChanges = true }
                        )) {
                            ForEach(NumberingAdornment.allCases, id: \.self) { adornment in
                                Text(adornment.displayName).tag(adornment)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.vertical, 4)
                }
                    }
            } header: {
                Text("textStyleEditor.numbering")
            }
            }
        }
    }
    
    private var followOnStyleSection: some View {
        Section {
            // Get available styles from the same stylesheet (excluding current style)
            let availableStyles = style.styleSheet?.textStyles?.filter { $0.id != style.id }.sorted(by: { $0.displayOrder < $1.displayOrder }) ?? []
            
            Picker("textStyleEditor.followOnStyle", selection: Binding(
                get: { style.followOnStyleName ?? "" },
                set: { newValue in
                    style.followOnStyleName = newValue.isEmpty ? nil : newValue
                    hasUnsavedChanges = true
                }
            )) {
                // Option to continue with the same style
                Text("textStyleEditor.followOnStyle.same")
                    .tag("")
                
                // Divider representation
                Divider()
                
                // All other available styles
                ForEach(availableStyles, id: \.id) { otherStyle in
                    Text(otherStyle.displayName)
                        .tag(otherStyle.name)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("textStyleEditor.followOnStyle.header")
        } footer: {
            Text("textStyleEditor.followOnStyle.footer")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // Helper computed properties
    private var numberFormats: [NumberFormat] {
        [.decimal, .lowercaseLetter, .uppercaseLetter, .lowercaseRoman, .uppercaseRoman]
    }
    
    private var bulletCharacters: [String] {
        ["•", "◦", "▪", "▫", "▸", "○", "■", "□", "▹", "▻"]
    }
    
    // MARK: - Font Variant Helpers
    
    /// Find and select the appropriate font variant when bold/italic are toggled
    private func updateFontVariant() {
        guard let family = style.fontFamily else {
            // No custom font family, just toggle the flags
            return
        }
        
        let variants = UIFont.fontNames(forFamilyName: family)
        
        // Try to find a variant that matches the bold/italic state
        let targetVariant = variants.first { variantName in
            let lowercased = variantName.lowercased()
            let hasBold = lowercased.contains("bold")
            let hasItalic = lowercased.contains("italic") || lowercased.contains("oblique")
            
            if style.isBold && style.isItalic {
                return hasBold && hasItalic
            } else if style.isBold {
                return hasBold && !hasItalic
            } else if style.isItalic {
                return hasItalic && !hasBold
            } else {
                // Neither bold nor italic - find "Regular" or the base variant
                return !hasBold && !hasItalic
            }
        }
        
        // If we found a matching variant, use it
        if let variant = targetVariant {
            style.fontName = variant
        } else if !style.isBold && !style.isItalic {
            // If we're trying to go to regular but can't find it, use the first variant
            style.fontName = variants.first
        }
        // Otherwise keep the current fontName and rely on symbolic traits
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
    
    private func createNewStyleFromChanges() {
        guard let stylesheet = style.styleSheet else {
            print("⚠️ Cannot create new style - no stylesheet")
            return
        }
        
        // Create new style name with asterisk suffix
        let newStyleName = style.name + "*"
        let newDisplayName = editedDisplayName + "*"
        
        // Find the next available display order
        let maxOrder = stylesheet.textStyles?.map { $0.displayOrder }.max() ?? 0
        
        // Create new style with current edited properties
        let newStyle = TextStyleModel(
            name: newStyleName,
            displayName: newDisplayName,
            displayOrder: maxOrder + 1,
            styleCategory: style.styleCategory,
            isSystemStyle: false
        )
        
        // Copy all the edited properties from the current style
        newStyle.fontFamily = style.fontFamily
        newStyle.fontName = style.fontName
        newStyle.fontSize = style.fontSize
        newStyle.isBold = style.isBold
        newStyle.isItalic = style.isItalic
        newStyle.textColor = style.textColor
        newStyle.alignment = style.alignment
        newStyle.lineSpacing = style.lineSpacing
        newStyle.paragraphSpacingBefore = style.paragraphSpacingBefore
        newStyle.paragraphSpacingAfter = style.paragraphSpacingAfter
        newStyle.firstLineIndent = style.firstLineIndent
        newStyle.headIndent = style.headIndent
        newStyle.tailIndent = style.tailIndent
        
        // Add to stylesheet
        newStyle.styleSheet = stylesheet
        if stylesheet.textStyles == nil {
            stylesheet.textStyles = []
        }
        stylesheet.textStyles?.append(newStyle)
        
        // Update stylesheet's modified date
        stylesheet.modifiedDate = Date()
        
        do {
            modelContext.insert(newStyle)
            try modelContext.save()
            onSave?()
            
            print("✅ Created new style: \(newDisplayName) (\(newStyleName))")
            
            // Notify that stylesheet was modified
            NotificationCenter.default.post(
                name: NSNotification.Name("StyleSheetModified"),
                object: nil,
                userInfo: ["stylesheetID": stylesheet.id]
            )
        } catch {
            print("❌ Error creating new style: \(error)")
        }
    }
    
    // MARK: - Delete
    
    private func handleDeleteAttempt() {
        #if DEBUG
        print("🗑️ handleDeleteAttempt called for style: \(style.displayName) (\(style.name))")
        #endif
        
        // Check if style is in use
        guard let proj = project else {
            #if DEBUG
            print("⚠️ No project found for this style's stylesheet")
            print("   Stylesheet: \(style.styleSheet?.name ?? "nil")")
            print("   Stylesheet projects count: \(style.styleSheet?.projects?.count ?? 0)")
            #endif
            showingDeleteAlert = true
            return
        }
        
        #if DEBUG
        print("✅ Found project: \(proj.name ?? "Untitled")")
        #endif
        
        filesUsingStyle = StyleSheetService.findStyleUsage(style: style, in: proj)
        
        #if DEBUG
        print("📊 handleDeleteAttempt: filesUsingStyle = \(filesUsingStyle)")
        #endif
        
        showingDeleteAlert = true
    }
    
    private func performDelete(replacementStyle: TextStyleModel? = nil) {
        guard let proj = project else { return }
        
        do {
            try StyleSheetService.deleteStyle(
                style,
                replacementStyle: replacementStyle,
                from: proj,
                context: modelContext
            )
            
            onSave?() // Notify parent that changes occurred
            dismiss()
        } catch {
            deleteErrorMessage = error.localizedDescription
        }
    }
}

// MARK: - Style Replacement Picker

/// A picker for selecting a replacement style when deleting a style in use
private struct StyleReplacementPickerView: View {
    let currentStyle: TextStyleModel
    let project: Project
    let onStyleSelected: (TextStyleModel) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    private var availableStyles: [TextStyleModel] {
        guard let stylesheet = project.styleSheet,
              let styles = stylesheet.textStyles else {
            return []
        }
        
        // Exclude the current style and footnote styles
        return styles
            .filter { $0.id != currentStyle.id && $0.styleCategory != .footnote }
            .sorted { $0.displayOrder < $1.displayOrder }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(availableStyles, id: \.id) { style in
                    Button(action: {
                        onStyleSelected(style)
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(style.displayName)
                                .font(.headline)
                            Text("\(style.styleCategory.rawValue.capitalized) • \(Int(style.fontSize))pt")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("textStyleEditor.selectReplacement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
