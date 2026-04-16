//
//  StyleSheetDetailView.swift
//  Writing Shed Pro
//
//  Detail view showing all styles in a stylesheet with edit capability
//

import SwiftUI
import SwiftData

struct StyleSheetDetailView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var styleSheet: StyleSheet
    @State private var showingNewStyleEditor = false
    @State private var newStyle: TextStyleModel?
    @State private var refreshTrigger = false
    
    private var sortedStyles: [TextStyleModel] {
        guard let styles = styleSheet.textStyles else { return [] }
        return styles.sorted { (a: TextStyleModel, b: TextStyleModel) in a.displayOrder < b.displayOrder }
    }
    
    private var sortedImageStyles: [ImageStyle] {
        guard let styles = styleSheet.imageStyles else { return [] }
        return styles.sorted { (a: ImageStyle, b: ImageStyle) in a.displayOrder < b.displayOrder }
    }
    
    private var headingStyles: [TextStyleModel] {
        sortedStyles.filter { (s: TextStyleModel) in s.styleCategory == .heading }
    }
    
    private var textStyles: [TextStyleModel] {
        sortedStyles.filter { (s: TextStyleModel) in s.styleCategory == .text }
    }
    
    private var listStyles: [TextStyleModel] {
        sortedStyles.filter { (s: TextStyleModel) in s.styleCategory == .list }
    }
    
    private var footnoteStyles: [TextStyleModel] {
        sortedStyles.filter { (s: TextStyleModel) in s.styleCategory == .footnote }
    }
    
    var body: some View {
        List {
            stylesheetInfoSection
            headingStylesSection
            textStylesSection
            listStylesSection
            footnoteStylesSection
            imageStylesSection
        }
        .navigationTitle(styleSheet.name)
        .navigationBarTitleDisplayMode(.inline)
        .id(refreshTrigger)
        .onReceive(
            NotificationCenter.default
                .publisher(for: NSNotification.Name("NSPersistentStoreRemoteChangeNotification"))
                .receive(on: RunLoop.main)
        ) { _ in
            refreshTrigger.toggle()
        }
        .onChange(of: styleSheet.footnoteMarkerStyleRaw) { _, _ in
            styleSheet.modifiedDate = Date()
            WriteCoalescer.shared?.requestSave()
            NotificationCenter.default.post(
                name: NSNotification.Name("StyleSheetModified"),
                object: nil,
                userInfo: ["stylesheetID": styleSheet.id]
            )
        }
        .toolbar {
            if !styleSheet.isSystemStyleSheet {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        createNewStyle()
                    }) {
                        Label(NSLocalizedString("styleSheetDetail.newStyle", comment: "New style button"), systemImage: "plus")
                    }
                    .accessibilityLabel(NSLocalizedString("styleSheetDetail.newStyle.accessibility", comment: "New style accessibility"))
                }
            }
        }
        .sheet(item: $newStyle) { style in
            NavigationStack {
                TextStyleEditorView(style: style, isNewStyle: true)
            }
        }
    }
    
    // MARK: - Body Sections
    
    private var stylesheetInfoSection: some View {
        Section {
            HStack {
                Text(NSLocalizedString("styleSheetDetail.name", comment: "Stylesheet name"))
                    .foregroundStyle(.secondary)
                Spacer()
                if styleSheet.isSystemStyleSheet {
                    Text(styleSheet.name)
                } else {
                    TextField(NSLocalizedString("styleSheetDetail.name.placeholder", comment: "Name placeholder"), text: $styleSheet.name)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            HStack {
                Text(NSLocalizedString("styleSheetDetail.stylesCount", comment: "Number of styles"))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(styleSheet.textStyles?.count ?? 0)")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var headingStylesSection: some View {
        if !headingStyles.isEmpty {
            Section(NSLocalizedString("styleSheetDetail.headingStyles", comment: "Heading styles section")) {
                ForEach(headingStyles, id: \.id) { (style: TextStyleModel) in
                    NavigationLink {
                        TextStyleEditorView(style: style, isNewStyle: false)
                    } label: {
                        StyleListRow(style: style)
                    }
                }
            }
        }
    }
    
    private var textStylesSection: some View {
        Section(NSLocalizedString("styleSheetDetail.textStyles", comment: "Text styles section")) {
            ForEach(textStyles, id: \.id) { (style: TextStyleModel) in
                NavigationLink {
                    TextStyleEditorView(style: style, isNewStyle: false)
                } label: {
                    StyleListRow(style: style)
                }
            }
        }
    }
    
    @ViewBuilder
    private var listStylesSection: some View {
        if !listStyles.isEmpty {
            Section(NSLocalizedString("styleSheetDetail.listStyles", comment: "List styles section")) {
                ForEach(listStyles, id: \.id) { (style: TextStyleModel) in
                    NavigationLink {
                        TextStyleEditorView(style: style, isNewStyle: false)
                    } label: {
                        StyleListRow(style: style)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var footnoteStylesSection: some View {
        if !footnoteStyles.isEmpty {
            Section(NSLocalizedString("styleSheetDetail.footnoteStyles", comment: "Footnote styles section")) {
                // Footnote marker style picker
                Picker(NSLocalizedString("styleSheetDetail.footnoteMarkerStyle", comment: "Footnote marker style"), selection: $styleSheet.footnoteMarkerStyleRaw) {
                    ForEach(FootnoteMarkerStyle.allCases, id: \.rawValue) { style in
                        Text(style.localizedName).tag(style.rawValue)
                    }
                }
                
                ForEach(footnoteStyles, id: \.id) { (style: TextStyleModel) in
                    NavigationLink {
                        TextStyleEditorView(style: style, isNewStyle: false)
                    } label: {
                        StyleListRow(style: style)
                    }
                }
            }
        } else {
            Section(NSLocalizedString("styleSheetDetail.footnoteStyles", comment: "Footnote styles section")) {
                Picker(NSLocalizedString("styleSheetDetail.footnoteMarkerStyle", comment: "Footnote marker style"), selection: $styleSheet.footnoteMarkerStyleRaw) {
                    ForEach(FootnoteMarkerStyle.allCases, id: \.rawValue) { style in
                        Text(style.localizedName).tag(style.rawValue)
                    }
                }
            }
        }
    }
    
    private var imageStylesSection: some View {
        Section(NSLocalizedString("styleSheetDetail.imageStyles", comment: "Image styles section")) {
            if sortedImageStyles.isEmpty {
                Text(NSLocalizedString("styleSheetDetail.noImageStyles", comment: "No image styles"))
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                ForEach(sortedImageStyles, id: \.id) { imageStyle in
                    if imageStyle.isSystemStyle && styleSheet.isSystemStyleSheet {
                        // System style in system stylesheet - not editable
                        ImageStyleRow(imageStyle: imageStyle)
                    } else {
                        // User stylesheet or editable style - make it a navigation link
                        NavigationLink {
                            ImageStyleSheetEditorView(imageStyle: imageStyle)
                        } label: {
                            ImageStyleRow(imageStyle: imageStyle)
                        }
                    }
                }
            }
        }
    }
    
    private func createNewStyle() {
        let style = TextStyleModel(
            name: "custom-style-\(UUID().uuidString.prefix(8))",
            displayName: "New Style",
            displayOrder: (styleSheet.textStyles?.count ?? 0)
        )
        style.styleSheet = styleSheet
        modelContext.insert(style)
        newStyle = style
    }
}

// MARK: - Image Style Row

private struct ImageStyleRow: View {
    let imageStyle: ImageStyle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(imageStyle.displayName)
                    .font(.headline)
                
                if imageStyle.isSystemStyle {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            HStack(spacing: 12) {
                // Scale
                Text(String(format: "%.0f%%", imageStyle.defaultScale * 100))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Alignment
                Text(alignmentName(for: imageStyle.defaultAlignment))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Caption
                if imageStyle.hasCaptionByDefault {
                    Text(String(format: NSLocalizedString("styleSheetDetail.caption", comment: "Caption with style"), imageStyle.defaultCaptionStyle))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(NSLocalizedString("styleSheetDetail.noCaption", comment: "No caption"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func alignmentName(for alignment: ImageAttachment.ImageAlignment) -> String {
        switch alignment {
        case .left:
            return NSLocalizedString("styleSheetDetail.alignment.left", comment: "Left alignment")
        case .center:
            return NSLocalizedString("styleSheetDetail.alignment.center", comment: "Center alignment")
        case .right:
            return NSLocalizedString("styleSheetDetail.alignment.right", comment: "Right alignment")
        case .inline:
            return NSLocalizedString("styleSheetDetail.alignment.inline", comment: "Inline alignment")
        }
    }
}

// MARK: - Style List Row

private struct StyleListRow: View {
    let style: TextStyleModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(style.displayName)
                    .font(.headline)
                
                if style.isSystemStyle {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            HStack(spacing: 12) {
                // Font info
                Text(String(format: "%.0f pt", style.fontSize))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Font traits
                if style.isBold {
                    Text(NSLocalizedString("styleSheetDetail.bold", comment: "Bold trait"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if style.isItalic {
                    Text(NSLocalizedString("styleSheetDetail.italic", comment: "Italic trait"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Alignment
                Text(alignmentName(for: style.alignment))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Numbering format
                if style.numberFormat != .none {
                    Text(style.numberFormat.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Preview with numbering if enabled (but not for footnotes)
            HStack(alignment: .top, spacing: 8) {
                if style.numberFormat != .none && style.styleCategory != .footnote {
                    Text(style.numberFormat.symbol(for: 1, adornment: style.numberAdornment))
                        .font(Font(style.generateFont()))
                        .foregroundColor(Color(uiColor: (style.textColor ?? UIColor.label).withAlphaComponent(0.6)))
                }
                
                Text(NSLocalizedString("styleSheetDetail.previewText", comment: "Preview text for style"))
                    .font(Font(style.generateFont()))
                    .foregroundColor(style.textColor != nil ? Color(uiColor: style.textColor!) : .primary)
                    .lineLimit(1)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }
    
    private func alignmentName(for alignment: NSTextAlignment) -> String {
        switch alignment {
        case .left:
            return NSLocalizedString("styleSheetDetail.alignment.left", comment: "Left alignment")
        case .center:
            return NSLocalizedString("styleSheetDetail.alignment.center", comment: "Center alignment")
        case .right:
            return NSLocalizedString("styleSheetDetail.alignment.right", comment: "Right alignment")
        case .justified:
            return NSLocalizedString("styleSheetDetail.alignment.justified", comment: "Justified alignment")
        default:
            return NSLocalizedString("styleSheetDetail.alignment.natural", comment: "Natural alignment")
        }
    }
}


