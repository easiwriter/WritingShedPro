import SwiftUI
import UIKit
import SwiftData

/// A sheet that displays all available UIFont.TextStyle options with previews
/// Allows users to select a paragraph style for their text
struct StylePickerSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Properties
    
    /// Currently selected style (if any) - binding so it updates on undo/redo
    @Binding var currentStyle: UIFont.TextStyle?
    
    /// Callback when user selects a style
    let onStyleSelected: (UIFont.TextStyle) -> Void
    
    /// The project to get stylesheet from (optional)
    var project: Project?
    
    /// Callback to reapply all styles in the document
    var onReapplyStyles: (() -> Void)?
    
    @State private var showingStyleEditor = false
    @State private var styleToEdit: TextStyleModel?
    
    // MARK: - Available Styles
    
    /// Get all available styles from the project's stylesheet, excluding footnotes
    private var availableStyles: [TextStyleModel] {
        guard let project = project,
              let stylesheet = project.styleSheet,
              let textStyles = stylesheet.textStyles else {
            // Fallback to default system styles if no project/stylesheet
            return defaultSystemStyles()
        }
        
        // Filter out footnote styles (they're used internally, not user-selectable)
        return textStyles
            .filter { $0.styleCategory != StyleCategory.footnote }
            .sorted { $0.displayOrder < $1.displayOrder }
    }
    
    /// Fallback system styles when no stylesheet is available
    private func defaultSystemStyles() -> [TextStyleModel] {
        let systemStyles: [(UIFont.TextStyle, String, StyleCategory, Int)] = [
            (.largeTitle, "Large Title", .heading, 0),
            (.title1, "Title 1", .heading, 1),
            (.title2, "Title 2", .heading, 2),
            (.title3, "Title 3", .heading, 3),
            (.headline, "Headline", .heading, 4),
            (.body, "Body", .text, 5),
            (.callout, "Body 1", .text, 6),
            (.subheadline, "Body 2", .text, 7),
            (.caption1, "Caption 1", .text, 8),
            (.caption2, "Caption 2", .text, 9)
        ]
        
        return systemStyles.map { (textStyle, displayName, category, order) in
            let style = TextStyleModel(
                name: textStyle.rawValue,
                displayName: displayName,
                displayOrder: order,
                styleCategory: category,
                isSystemStyle: true
            )
            return style
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            List {
                ForEach(availableStyles, id: \.id) { style in
                    VStack(spacing: 0) {
                        Button(action: {
                            // Convert style name to UIFont.TextStyle
                            let textStyle = UIFont.TextStyle(rawValue: style.name)
                            onStyleSelected(textStyle)
                            dismiss()
                        }) {
                            StylePreviewRowFromModel(
                                styleModel: style,
                                isSelected: currentStyle?.rawValue == style.name,
                                project: project,
                                modelContext: modelContext
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Add divider between items (except after last one)
                        if style.id != availableStyles.last?.id {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(NSLocalizedString("stylePicker.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.done", comment: "")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        // Find the current style in the database
                        if let currentStyle = currentStyle,
                           let project = project {
                            let styleName = currentStyle.rawValue
                            if let textStyle = StyleSheetService.resolveStyle(named: styleName, for: project, context: modelContext) {
                                styleToEdit = textStyle
                                showingStyleEditor = true
                            }
                        }
                    }) {
                        Label("stylePicker.editStyle", systemImage: "slider.horizontal.3")
                    }
                    .disabled(currentStyle == nil || project == nil)
                }
            }
            .sheet(item: $styleToEdit) { style in
                NavigationStack {
                    TextStyleEditorView(
                        style: style,
                        isNewStyle: false,
                        onSave: {
                            // Reapply all styles to update existing text with the new style settings
                            onReapplyStyles?()
                        }
                    )
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Style Preview Row

/// A row displaying a style preview directly from TextStyleModel
private struct StylePreviewRowFromModel: View {
    let styleModel: TextStyleModel
    let isSelected: Bool
    let project: Project?
    let modelContext: ModelContext
    
    // Generate a friendly description based on style properties
    private var styleDescription: String {
        var parts: [String] = []
        
        // Category
        switch styleModel.styleCategory {
        case .heading:
            parts.append("Heading")
        case .text:
            parts.append("Text")
        case .list:
            parts.append("List")
        case .footnote:
            parts.append("Footnote")
        case .custom:
            parts.append("Custom")
        }
        
        // Font size
        parts.append("\(Int(styleModel.fontSize))pt")
        
        // Traits
        if styleModel.isBold && styleModel.isItalic {
            parts.append("Bold Italic")
        } else if styleModel.isBold {
            parts.append("Bold")
        } else if styleModel.isItalic {
            parts.append("Italic")
        }
        
        return parts.joined(separator: " • ")
    }
    
    // Get styled attributes from the model
    private var styledAttributes: (font: UIFont, color: UIColor) {
        let attrs = styleModel.generateAttributes()
        let font = attrs[NSAttributedString.Key.font] as? UIFont ?? UIFont.systemFont(ofSize: 17)
        let color = attrs[NSAttributedString.Key.foregroundColor] as? UIColor ?? .label
        return (font, color)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Preview: Style name with actual styling, description below
            VStack(alignment: .leading, spacing: 6) {
                Text(styleModel.displayName)
                    .font(.init(styledAttributes.font).weight(.medium))
                    .foregroundColor(Color(styledAttributes.color))
                
                Text(styleDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Checkmark if selected
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

/// A row displaying a style preview with name and description (legacy - kept for compatibility)
private struct StylePreviewRow: View {
    let style: UIFont.TextStyle
    let name: String
    let description: String
    let isSelected: Bool
    let project: Project?
    let modelContext: ModelContext
    
    // Get styled attributes from project stylesheet
    private var styledAttributes: (font: UIFont, color: UIColor) {
        guard let project = project,
              let textStyle = StyleSheetService.resolveStyle(named: style.rawValue, for: project, context: modelContext) else {
            return (UIFont.preferredFont(forTextStyle: style), .label)
        }
        
        let attrs = textStyle.generateAttributes()
        let font = attrs[NSAttributedString.Key.font] as? UIFont ?? UIFont.preferredFont(forTextStyle: style)
        let color = attrs[NSAttributedString.Key.foregroundColor] as? UIColor ?? .label
        
        return (font, color)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Preview: Style name with actual styling, description below
            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.init(styledAttributes.font).weight(.medium))
                    .foregroundColor(Color(styledAttributes.color))
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Checkmark if selected
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}


