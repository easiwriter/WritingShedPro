import SwiftUI
import UIKit

/// A sheet that displays all available UIFont.TextStyle options with previews
/// Allows users to select a paragraph style for their text
struct StylePickerSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    /// Currently selected style (if any) - binding so it updates on undo/redo
    @Binding var currentStyle: UIFont.TextStyle?
    
    /// Callback when user selects a style
    let onStyleSelected: (UIFont.TextStyle) -> Void
    
    // MARK: - Available Styles
    
    /// All available text styles with their metadata
    private let styles: [(style: UIFont.TextStyle, name: String, description: String)] = [
        (.largeTitle, "Large Title", "The largest text style, for prominent headlines"),
        (.title1, "Title 1", "Primary title style for major sections"),
        (.title2, "Title 2", "Secondary title style for subsections"),
        (.title3, "Title 3", "Tertiary title style for smaller headings"),
        (.headline, "Headline", "Bold text for emphasizing content"),
        (.body, "Body", "The default reading text style"),
        (.callout, "Callout", "Slightly smaller than body, for secondary text"),
        (.subheadline, "Subheadline", "Smaller text for labels and captions"),
        (.footnote, "Footnote", "Small text for footnotes and annotations"),
        (.caption1, "Caption 1", "Very small text for image captions"),
        (.caption2, "Caption 2", "The smallest text style")
    ]
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            List {
                ForEach(styles, id: \.style) { item in
                    VStack(spacing: 0) {
                        Button(action: {
                            onStyleSelected(item.style)
                            dismiss()
                        }) {
                            StylePreviewRow(
                                style: item.style,
                                name: item.name,
                                description: item.description,
                                isSelected: currentStyle == item.style
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Add divider between items (except after last one)
                        if item.style != styles.last?.style {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Paragraph Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Style Preview Row

/// A row displaying a style preview with name and description
private struct StylePreviewRow: View {
    let style: UIFont.TextStyle
    let name: String
    let description: String
    let isSelected: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Preview text using the actual style
            VStack(alignment: .leading, spacing: 4) {
                Text("Sample")
                    .font(.init(UIFont.preferredFont(forTextStyle: style)))
                    .foregroundColor(.primary)
                
                Text(name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Description
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Checkmark if selected
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview {
    StylePickerSheet(
        currentStyle: .constant(.body),
        onStyleSelected: { style in
            print("Selected style: \(style)")
        }
    )
}
