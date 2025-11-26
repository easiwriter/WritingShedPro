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
    
    private var sortedStyles: [TextStyleModel] {
        guard let styles = styleSheet.textStyles else { return [] }
        return styles.sorted { $0.displayOrder < $1.displayOrder }
    }
    
    private var sortedImageStyles: [ImageStyle] {
        guard let styles = styleSheet.imageStyles else { return [] }
        return styles.sorted { $0.displayOrder < $1.displayOrder }
    }
    
    var body: some View {
        List {
            // Stylesheet Info
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
            
            // Heading Styles
            if sortedStyles.contains(where: { $0.styleCategory == .heading }) {
                Section(NSLocalizedString("styleSheetDetail.headingStyles", comment: "Heading styles section")) {
                    ForEach(sortedStyles.filter { $0.styleCategory == .heading }, id: \.id) { style in
                        NavigationLink {
                            TextStyleEditorView(style: style, isNewStyle: false)
                        } label: {
                            StyleListRow(style: style)
                        }
                    }
                }
            }
            
            // Text Styles
            Section(NSLocalizedString("styleSheetDetail.textStyles", comment: "Text styles section")) {
                ForEach(sortedStyles.filter { $0.styleCategory == .text }, id: \.id) { style in
                    NavigationLink {
                        TextStyleEditorView(style: style, isNewStyle: false)
                    } label: {
                        StyleListRow(style: style)
                    }
                }
            }
            
            // List Styles
            if sortedStyles.contains(where: { $0.styleCategory == .list }) {
                Section(NSLocalizedString("styleSheetDetail.listStyles", comment: "List styles section")) {
                    ForEach(sortedStyles.filter { $0.styleCategory == .list }, id: \.id) { style in
                        NavigationLink {
                            TextStyleEditorView(style: style, isNewStyle: false)
                        } label: {
                            StyleListRow(style: style)
                        }
                    }
                }
            }
            
            // Footnote Styles
            if sortedStyles.contains(where: { $0.styleCategory == .footnote }) {
                Section(NSLocalizedString("styleSheetDetail.footnoteStyles", comment: "Footnote styles section")) {
                    ForEach(sortedStyles.filter { $0.styleCategory == .footnote }, id: \.id) { style in
                        NavigationLink {
                            TextStyleEditorView(style: style, isNewStyle: false)
                        } label: {
                            StyleListRow(style: style)
                        }
                    }
                }
            }
            
            // Image Styles
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
        .navigationTitle(styleSheet.name)
        .navigationBarTitleDisplayMode(.inline)
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
            }
            
            // Preview
            Text(NSLocalizedString("styleSheetDetail.previewText", comment: "Preview text for style"))
                .font(Font(style.generateFont()))
                .foregroundColor(style.textColor != nil ? Color(uiColor: style.textColor!) : .primary)
                .lineLimit(1)
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


