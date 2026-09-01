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
    let onStyleDefinitionSaved: ((String) -> Void)?
    let hideDeleteButton: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var hasUnsavedChanges = false
    @State private var editedDisplayName: String
    @State private var editedAlignment: NSTextAlignment
    @State private var showingDeleteAlert = false
    @State private var deleteErrorMessage: String?
    @State private var showingReplacementPicker = false
    @State private var replacementPickerPending = false
    @State private var filesUsingStyle: [String] = []
    @State private var showingSaveOptionsAlert = false
    @State private var saveErrorMessage: String?
    
    // Get the project associated with this style's stylesheet
    private var project: Project? {
        style.styleSheet?.projects?.first
    }

    // List styles are required by editor commands and numbering layout.
    // Deleting them breaks bullets/numbering in documents.
    private var isProtectedCoreStyle: Bool {
        style.styleCategory == .list || style.name.hasPrefix("list-")
    }
    
    init(
        style: TextStyleModel,
        isNewStyle: Bool = false,
        onSave: (() -> Void)? = nil,
        onStyleDefinitionSaved: ((String) -> Void)? = nil,
        hideDeleteButton: Bool = false
    ) {
        self.style = style
        self.isNewStyle = isNewStyle
        self.onSave = onSave
        self.onStyleDefinitionSaved = onStyleDefinitionSaved
        self.hideDeleteButton = hideDeleteButton
        _editedDisplayName = State(initialValue: style.displayName)
        _editedAlignment = State(initialValue: style.alignment)
        
        #if DEBUG
        print("📝 TextStyleEditorView - Style: \(style.displayName)")
        #if DEBUG
        print("   Name: \(style.name)")
        #endif
        #if DEBUG
        print("   Category: \(style.styleCategory.rawValue)")
        #endif
        #if DEBUG
        print("   Category raw: \(style.styleCategoryRaw)")
        #endif
        #endif
    }
    
    var body: some View {
        Form {
            Group {
                styleNameSection
                fontSettingsSection
                textColourSection
                paragraphSettingsSection
                numberingSection
                followOnStyleSection
                firstParagraphStyleSection
                tocSection
            }
        }
        .navigationTitle("textStyleEditor.editStyle.title")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("button.cancel") {
                    dismiss()
                }
            }

            // Delete button (only for deletable styles and when not hidden)
            if !style.isSystemStyle && !hideDeleteButton && !isProtectedCoreStyle {
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
                        if saveChanges() {
                            dismiss()
                        }
                    } else {
                        // For existing styles, show options alert
                        showingSaveOptionsAlert = true
                    }
                }
                .disabled(!hasUnsavedChanges || editedDisplayName.isEmpty)
            }
        }
        .alert("textStyleEditor.delete.title", isPresented: $showingDeleteAlert) {
            if filesUsingStyle.isEmpty {
                Button("button.delete", role: .destructive) {
                    performDelete()
                }
                Button("button.cancel", role: .cancel) { }
            } else {
                Button("textStyleEditor.delete.replaceAndDelete", role: .destructive) {
                    replacementPickerPending = true
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
        .onChange(of: showingDeleteAlert) { _, isShowing in
            guard !isShowing, replacementPickerPending else { return }
            replacementPickerPending = false
            showingReplacementPicker = true
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
                if saveChanges() {
                    dismiss()
                }
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
        .alert(
            "textStyleEditor.saveFailed.title",
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )
        ) {
            Button("button.ok", role: .cancel) {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "")
        }
        .alert(
            "textStyleEditor.delete.failedTitle",
            isPresented: Binding(
                get: { deleteErrorMessage != nil },
                set: { if !$0 { deleteErrorMessage = nil } }
            )
        ) {
            Button("button.ok", role: .cancel) {
                deleteErrorMessage = nil
            }
        } message: {
            Text(deleteErrorMessage ?? "")
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

            Menu {
                ForEach(UIFont.familyNames.sorted(), id: \.self) { family in
                    Button(family) {
                        selectFontFamily(family)
                    }
                }
            } label: {
                fontMenuLabel(style.fontFamily ?? FontFaceResolver.defaultFamilyName)
            }
            .accessibilityLabel("textStyleEditor.fontTypeface.accessibility")

            HStack(spacing: 8) {
                Menu {
                    ForEach(availableFontFaces, id: \.self) { fontName in
                        Button(fontFaceDisplayName(fontName)) {
                            style.selectFontFace(fontName)
                            hasUnsavedChanges = true
                        }
                    }
                } label: {
                    fontMenuLabel(selectedFontFaceDisplayName)
                }
                .frame(maxWidth: .infinity)
                .disabled(availableFontFaces.isEmpty)
                .accessibilityLabel("textStyleEditor.fontFace.accessibility")

                HStack(spacing: 0) {
                    Text("\(Int(style.fontSize)) pt")
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(String(format: NSLocalizedString("textStyleEditor.fontSizeValue.accessibility", comment: "Font size"), Int(style.fontSize)))

                    Divider()

                    VStack(spacing: 0) {
                        Button {
                            style.fontSize = min(96, style.fontSize + 1)
                            hasUnsavedChanges = true
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.caption.bold())
                                .frame(width: 26, height: 17)
                        }
                        .accessibilityLabel("textStyleEditor.increaseFontSize.accessibility")

                        Divider()

                        Button {
                            style.fontSize = max(8, style.fontSize - 1)
                            hasUnsavedChanges = true
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.caption.bold())
                                .frame(width: 26, height: 17)
                        }
                        .accessibilityLabel("textStyleEditor.decreaseFontSize.accessibility")
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 112, height: 36)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.secondary.opacity(0.35))
                }
            }

            HStack(spacing: 0) {
                fontTraitButton(
                    label: Text("B").font(.system(size: 20, weight: .bold)),
                    isActive: style.isBold,
                    accessibilityLabel: "textStyleEditor.bold.accessibility"
                ) {
                    style.selectFontTraits(bold: !style.isBold, italic: style.isItalic)
                    hasUnsavedChanges = true
                }

                Divider().frame(height: 24)

                fontTraitButton(
                    label: Text("I").font(.system(size: 20)).italic(),
                    isActive: style.isItalic,
                    accessibilityLabel: "textStyleEditor.italic.accessibility"
                ) {
                    style.selectFontTraits(bold: style.isBold, italic: !style.isItalic)
                    hasUnsavedChanges = true
                }

                Divider().frame(height: 24)

                fontTraitButton(
                    label: Text("U").font(.system(size: 20)).underline(),
                    isActive: style.isUnderlined,
                    accessibilityLabel: "textStyleEditor.underline.accessibility"
                ) {
                    style.isUnderlined.toggle()
                    hasUnsavedChanges = true
                }

                Divider().frame(height: 24)

                fontTraitButton(
                    label: Text("S").font(.system(size: 20)).strikethrough(),
                    isActive: style.isStrikethrough,
                    accessibilityLabel: "textStyleEditor.strikethrough.accessibility"
                ) {
                    style.isStrikethrough.toggle()
                    hasUnsavedChanges = true
                }
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.secondary.opacity(0.35))
            }
        }
    }

    private var availableFontFaces: [String] {
        let family = style.fontFamily ?? FontFaceResolver.defaultFamilyName
        return UIFont.fontNames(forFamilyName: family).sorted {
            fontFaceDisplayName($0).localizedCaseInsensitiveCompare(fontFaceDisplayName($1)) == .orderedAscending
        }
    }

    private var selectedFontFaceDisplayName: String {
        guard let fontName = style.fontName else {
            return fontFaceDisplayName(FontFaceResolver.defaultFontName)
        }
        return fontFaceDisplayName(fontName)
    }

    private func fontFaceDisplayName(_ fontName: String) -> String {
        guard let font = UIFont(name: fontName, size: style.fontSize) else { return fontName }
        return font.fontDescriptor.object(forKey: .face) as? String ?? "Regular"
    }

    private func selectFontFamily(_ family: String) {
        style.fontFamily = family
        let resolved = FontFaceResolver.resolvedFont(
            familyName: family,
            currentFontName: nil,
            size: style.fontSize,
            bold: style.isBold,
            italic: style.isItalic
        )
        style.fontName = resolved.fontName
        hasUnsavedChanges = true
    }

    private func fontMenuLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 36)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.secondary.opacity(0.35))
        }
        .contentShape(Rectangle())
    }

    private func fontTraitButton<Label: View>(
        label: Label,
        isActive: Bool,
        accessibilityLabel: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            label
                .foregroundStyle(isActive ? Color.white : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(isActive ? Color.accentColor : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
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
                    get: { editedAlignment },
                    set: { editedAlignment = $0; hasUnsavedChanges = true }
                )) {
                    Text("textStyleEditor.alignment.left").tag(NSTextAlignment.left)
                    Text("textStyleEditor.alignment.center").tag(NSTextAlignment.center)
                    Text("textStyleEditor.alignment.right").tag(NSTextAlignment.right)
                    Text("textStyleEditor.alignment.justified").tag(NSTextAlignment.justified)
                    Text("textStyleEditor.alignment.natural").tag(NSTextAlignment.natural)
                }
                
                HStack {
                    Text("textStyleEditor.lineSpacing")
                    ZeroableCGFloatField("textStyleEditor.spacing", value: $style.lineSpacing) {
                        hasUnsavedChanges = true
                    }
                        .frame(width: 60)
                        .accessibilityLabel("textStyleEditor.lineSpacing.accessibility")
                }
                
                HStack {
                    Text("textStyleEditor.paragraphSpacingBefore")
                    ZeroableCGFloatField("textStyleEditor.spacing", value: $style.paragraphSpacingBefore) {
                        hasUnsavedChanges = true
                    }
                        .frame(width: 60)
                        .accessibilityLabel("textStyleEditor.paragraphSpacingBefore.accessibility")
                }
                
                HStack {
                    Text("textStyleEditor.paragraphSpacingAfter")
                    ZeroableCGFloatField("textStyleEditor.spacing", value: $style.paragraphSpacingAfter) {
                        hasUnsavedChanges = true
                    }
                        .frame(width: 60)
                        .accessibilityLabel("textStyleEditor.paragraphSpacingAfter.accessibility")
                }
                
                HStack {
                    Text("textStyleEditor.firstLineIndent")
                    ZeroableCGFloatField("textStyleEditor.indent", value: $style.firstLineIndent) {
                        hasUnsavedChanges = true
                    }
                        .frame(width: 60)
                        .accessibilityLabel("textStyleEditor.firstLineIndent.accessibility")
                }
                
                HStack {
                    Text("textStyleEditor.headIndent")
                    ZeroableCGFloatField("textStyleEditor.indent", value: $style.headIndent) {
                        hasUnsavedChanges = true
                    }
                        .frame(width: 60)
                        .accessibilityLabel("textStyleEditor.headIndent.accessibility")
                }
                
                HStack {
                    Text("textStyleEditor.tailIndent")
                    ZeroableCGFloatField("textStyleEditor.indent", value: $style.tailIndent) {
                        hasUnsavedChanges = true
                    }
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
                            // Bullet list styles: explicit bullet symbol choice
                            if style.numberFormat == .bulletSymbols {
                                Picker("textStyleEditor.bulletStyle", selection: Binding(
                                    get: { style.numberAdornment },
                                    set: { style.numberAdornment = $0; hasUnsavedChanges = true }
                                )) {
                                    ForEach(bulletAdornmentOptions, id: \.self) { adornment in
                                        Text(NumberFormat.bulletSymbol(for: adornment)).tag(adornment)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            // Numbered list: show format and adornment pickers
                            else if style.numberFormat != .none {
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
                        
                        // Parent style for hierarchical numbering (e.g., 1.a, 1.b)
                        let availableParentStyles = style.styleSheet?.textStyles?
                            .filter { $0.id != style.id && $0.numberFormat != .none }
                            .sorted(by: { $0.displayOrder < $1.displayOrder }) ?? []
                        
                        Picker("textStyleEditor.parentStyle", selection: Binding(
                            get: { style.parentStyleName ?? "" },
                            set: { newValue in
                                style.parentStyleName = newValue.isEmpty ? nil : newValue
                                hasUnsavedChanges = true
                            }
                        )) {
                            Text("textStyleEditor.parentStyle.none")
                                .tag("")
                            
                            ForEach(availableParentStyles, id: \.id) { parentStyle in
                                Text(parentStyle.displayName)
                                    .tag(parentStyle.name)
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

    private var firstParagraphStyleSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { style.isFirstParagraphStyle },
                set: { newValue in
                    if newValue {
                        style.styleSheet?.setFirstParagraphStyle(style)
                    } else {
                        style.isFirstParagraphStyle = false
                    }
                    hasUnsavedChanges = true
                }
            )) {
                Text("textStyleEditor.firstParagraphStyle.toggle")
            }
        } header: {
            Text("textStyleEditor.firstParagraphStyle.header")
        } footer: {
            Text("textStyleEditor.firstParagraphStyle.footer")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    /// Section for Table of Contents settings
    /// Only shown for heading-category styles
    private var tocSection: some View {
        Group {
            // Only show for heading category styles
            if style.styleCategory == .heading {
                Section {
                    Toggle(isOn: Binding(
                        get: { style.includeInTOC },
                        set: { newValue in
                            style.includeInTOC = newValue
                            hasUnsavedChanges = true
                        }
                    )) {
                        Text("textStyleEditor.toc.include")
                    }
                    
                    if style.includeInTOC {
                        Stepper(value: Binding(
                            get: { style.tocLevel },
                            set: { newValue in
                                style.tocLevel = newValue
                                hasUnsavedChanges = true
                            }
                        ), in: 0...5) {
                            HStack {
                                Text("textStyleEditor.toc.level")
                                Spacer()
                                Text("\(style.tocLevel)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("textStyleEditor.toc.header")
                } footer: {
                    Text("textStyleEditor.toc.footer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // Helper computed properties
    private var numberFormats: [NumberFormat] {
        [.decimal, .lowercaseLetter, .uppercaseLetter, .lowercaseRoman, .uppercaseRoman]
    }

    private var bulletAdornmentOptions: [NumberingAdornment] {
        NumberingAdornment.allCases
    }
    
    // MARK: - Save
    
    @discardableResult
    private func saveChanges() -> Bool {
        style.displayName = editedDisplayName
        style.alignment = editedAlignment
        style.modifiedDate = Date()

        // Defend against duplicate flags from sync/artifacts by normalizing on save.
        if style.isFirstParagraphStyle {
            style.styleSheet?.setFirstParagraphStyle(style)
        }
        
        // Update stylesheet's modified date to trigger view updates
        if let stylesheet = style.styleSheet {
            stylesheet.modifiedDate = Date()
        }
        
        do {
            try WriteCoalescer.shared.requestSaveAndFlush(reason: "text-style-editor-save")

            if let stylesheet = style.styleSheet {
                let updatedFiles = StyleSheetService.reapplyUpdatedStyle(
                    styleName: style.name,
                    in: stylesheet,
                    context: modelContext
                )
                #if DEBUG
                print("✅ Reapplied updated style '\(style.name)' in \(updatedFiles) file(s)")
                #endif
            }

            onStyleDefinitionSaved?(style.name)
            onSave?() // Notify that changes were saved
            
            // Notify that a style in the stylesheet has been modified
            if let stylesheetID = style.styleSheet?.id {
                #if DEBUG
                print("📤 Posting StyleSheetModified notification for stylesheet: \(stylesheetID.uuidString)")
                #endif
                NotificationCenter.default.post(
                    name: NSNotification.Name("StyleSheetModified"),
                    object: nil,
                    userInfo: [
                        "stylesheetID": stylesheetID,
                        "styleName": style.name
                    ]
                )
                #if DEBUG
                print("✅ StyleSheetModified notification posted")
                #endif
                
                // Update back matter files for all projects using this stylesheet
                updateBackMatterForStylesheet(stylesheetID)
            } else {
                #if DEBUG
                print("⚠️ Style has no stylesheet - cannot post notification")
                #endif
            }
            hasUnsavedChanges = false
            return true
        } catch {
            #if DEBUG
            print("Error saving style: \(error)")
            #endif
            saveErrorMessage = error.localizedDescription
            return false
        }
    }
    
    /// Update back matter files for all projects using the given stylesheet
    private func updateBackMatterForStylesheet(_ stylesheetID: UUID) {
        // Find all projects using this stylesheet
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate<Project> { project in
                project.styleSheet?.id == stylesheetID
            }
        )
        
        guard let projects = try? modelContext.fetch(descriptor) else {
            #if DEBUG
            print("⚠️ Could not fetch projects for stylesheet")
            #endif
            return
        }
        
        #if DEBUG
        print("📁 Found \(projects.count) projects using stylesheet \(stylesheetID)")
        #endif
        
        for project in projects {
            let generator = BackMatterGenerator(context: modelContext, project: project)
            
            // Find the Back Matter folder using project helper
            guard let backMatterFolder = project.findBackMatterFolder() else {
                continue
            }
            
            // Update enabled back matter files
            let backMatterItems: [(item: BackMatterItem, shouldUpdate: Bool)] = [
                (.endnotes, true),
                (.glossary, backMatterFolder.backMatterSettings.isEnabled(.glossary)),
                (.references, backMatterFolder.backMatterSettings.isEnabled(.references)),
                (.index, backMatterFolder.backMatterSettings.isEnabled(.index))
            ]
            
            for (item, shouldUpdate) in backMatterItems {
                guard shouldUpdate else { continue }
                
                // Find existing file
                let folderID = backMatterFolder.id
                let fileName = item.fileName
                let fileDescriptor = FetchDescriptor<TextFile>(
                    predicate: #Predicate<TextFile> { file in
                        file.parentFolder?.id == folderID && file.name == fileName
                    }
                )
                
                guard let backMatterFile = try? modelContext.fetch(fileDescriptor).first else {
                    continue
                }
                
                // Generate fresh content
                let generatedContent: NSAttributedString
                switch item {
                case .endnotes:
                    generatedContent = generator.generateNotesSection() ?? NSAttributedString()
                case .glossary:
                    generatedContent = generator.generateGlossarySection() ?? NSAttributedString()
                case .references:
                    generatedContent = generator.generateReferencesSection() ?? NSAttributedString()
                case .tableOfFigures:
                    // Table of Figures is generated dynamically, skip
                    continue
                case .index:
                    generatedContent = generator.generateIndexSection(pageMap: [:]) ?? NSAttributedString()
                case .contributors:
                    generatedContent = generator.generateContributorsSection() ?? NSAttributedString()
                case .backCover:
                    // Back cover is an image file, no generated content
                    continue
                }
                
                // Update the file's content
                if let version = backMatterFile.currentVersion {
                    version.attributedContent = generatedContent
                    backMatterFile.modifiedDate = Date()
                }
            }
        }
        
        WriteCoalescer.shared?.requestSave(reason: "text-style-back-matter-update")
        WriteCoalescer.shared?.flush()
        
        #if DEBUG
        print("✅ Back matter files updated for stylesheet change")
        #endif
    }
    
    private func createNewStyleFromChanges() {
        guard let stylesheet = style.styleSheet else {
            #if DEBUG
            print("⚠️ Cannot create new style - no stylesheet")
            #endif
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
        newStyle.alignment = editedAlignment
        newStyle.lineSpacing = style.lineSpacing
        newStyle.paragraphSpacingBefore = style.paragraphSpacingBefore
        newStyle.paragraphSpacingAfter = style.paragraphSpacingAfter
        newStyle.firstLineIndent = style.firstLineIndent
        newStyle.headIndent = style.headIndent
        newStyle.tailIndent = style.tailIndent
        newStyle.numberFormat = style.numberFormat
        newStyle.numberAdornment = style.numberAdornment
        newStyle.followOnStyleName = style.followOnStyleName
        newStyle.parentStyleName = style.parentStyleName
        newStyle.includeInTOC = style.includeInTOC
        newStyle.tocLevel = style.tocLevel
        newStyle.isFirstParagraphStyle = false
        
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
            try WriteCoalescer.shared.requestSaveAndFlush(reason: "text-style-editor-delete")
            onSave?()
            
            #if DEBUG
            print("✅ Created new style: \(newDisplayName) (\(newStyleName))")
            #endif
            
            // Notify that stylesheet was modified
            NotificationCenter.default.post(
                name: NSNotification.Name("StyleSheetModified"),
                object: nil,
                userInfo: ["stylesheetID": stylesheet.id]
            )
        } catch {
            #if DEBUG
            print("❌ Error creating new style: \(error)")
            #endif
        }
    }
    
    // MARK: - Delete
    
    private func handleDeleteAttempt() {
        #if DEBUG
        print("🗑️ handleDeleteAttempt called for style: \(style.displayName) (\(style.name))")
        #endif

        guard !isProtectedCoreStyle else {
            deleteErrorMessage = NSLocalizedString("textStyleEditor.delete.protectedListStyle", comment: "Cannot delete core list styles")
            return
        }
        
        // Check if style is in use
        guard let proj = project else {
            #if DEBUG
            print("⚠️ No project found for this style's stylesheet")
            #if DEBUG
            print("   Stylesheet: \(style.styleSheet?.name ?? "nil")")
            #endif
            #if DEBUG
            print("   Stylesheet projects count: \(style.styleSheet?.projects?.count ?? 0)")
            #endif
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
        guard !isProtectedCoreStyle else {
            deleteErrorMessage = NSLocalizedString("textStyleEditor.delete.protectedListStyle", comment: "Cannot delete core list styles")
            return
        }

        // Stylesheets created in Settings can exist before they are assigned to a project.
        // In that case the style cannot be in file content yet, so direct deletion is safe.
        guard let proj = project else {
            if let stylesheet = style.styleSheet {
                stylesheet.textStyles?.removeAll { $0.id == style.id }
            }
            modelContext.delete(style)
            do {
                try WriteCoalescer.shared?.requestSaveAndFlush(reason: "text-style-delete")
                onSave?()
                dismiss()
            } catch {
                deleteErrorMessage = error.localizedDescription
            }
            return
        }
        
        do {
            try StyleSheetService.deleteStyle(
                style,
                replacementStyle: replacementStyle,
                from: proj,
                context: modelContext
            )
            try WriteCoalescer.shared?.requestSaveAndFlush(reason: "text-style-delete")
            
            onSave?() // Notify parent that changes occurred
            dismiss()
        } catch {
            deleteErrorMessage = error.localizedDescription
        }
    }
}

private struct ZeroableCGFloatField: View {
    let prompt: LocalizedStringKey
    @Binding var value: CGFloat
    let onValueChanged: () -> Void

    @State private var text: String
    @FocusState private var isFocused: Bool

    init(_ prompt: LocalizedStringKey, value: Binding<CGFloat>, onValueChanged: @escaping () -> Void) {
        self.prompt = prompt
        self._value = value
        self.onValueChanged = onValueChanged
        self._text = State(initialValue: Self.displayText(for: value.wrappedValue))
    }

    var body: some View {
        TextField(prompt, text: $text)
            .keyboardType(.numbersAndPunctuation)
            .focused($isFocused)
            .onChange(of: text) { _, newText in
                let trimmed = newText.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    updateValue(0)
                } else if let parsedValue = Double(trimmed.replacingOccurrences(of: ",", with: ".")) {
                    updateValue(CGFloat(parsedValue))
                }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused {
                    text = Self.displayText(for: value)
                }
            }
            .onChange(of: value) { _, newValue in
                if !isFocused {
                    text = Self.displayText(for: newValue)
                }
            }
    }

    private func updateValue(_ newValue: CGFloat) {
        guard value != newValue else { return }
        value = newValue
        onValueChanged()
    }

    private static func displayText(for value: CGFloat) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(Double(value))
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
