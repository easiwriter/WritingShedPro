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
    
    var body: some View {
        List {
            // Stylesheet Info
            Section {
                HStack {
                    Text("Name")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if styleSheet.isSystemStyleSheet {
                        Text(styleSheet.name)
                    } else {
                        TextField("Stylesheet Name", text: $styleSheet.name)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                HStack {
                    Text("Styles")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(styleSheet.textStyles?.count ?? 0)")
                        .foregroundStyle(.secondary)
                }
            }
            
            // Text Styles
            Section("Text Styles") {
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
                Section("List Styles") {
                    ForEach(sortedStyles.filter { $0.styleCategory == .list }, id: \.id) { style in
                        NavigationLink {
                            TextStyleEditorView(style: style, isNewStyle: false)
                        } label: {
                            StyleListRow(style: style)
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
                        Label("New Style", systemImage: "plus")
                    }
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
                    Text("Bold")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if style.isItalic {
                    Text("Italic")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Alignment
                Text(alignmentName(for: style.alignment))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Preview
            Text("The quick brown fox jumps over the lazy dog")
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
            return "Left"
        case .center:
            return "Center"
        case .right:
            return "Right"
        case .justified:
            return "Justified"
        default:
            return "Natural"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        StyleSheetDetailView(
            styleSheet: StyleSheet(name: "Custom", isSystemStyleSheet: false)
        )
    }
}
