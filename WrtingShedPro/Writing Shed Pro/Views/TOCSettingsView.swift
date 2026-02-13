//
//  TOCSettingsView.swift
//  Writing Shed Pro
//
//  Feature 031: Table of Contents Settings UI
//

import SwiftUI
import SwiftData

/// Sheet view for configuring Table of Contents settings
struct TOCSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var file: TextFile
    
    // Local state for editing (copied from file on appear)
    @State private var title: String = "Contents"
    @State private var separator: String = "."
    @State private var indentPoints: CGFloat = 20
    @State private var showPageNumbers: Bool = true
    @State private var useDotLeaders: Bool = true
    @State private var titleStyleName: String = "UICTFontTextStyleTitle0"
    @State private var pageNumberPosition: CGFloat = 480
    
    // Per-level entry styles (Level 0-5)
    @State private var levelStyleNames: [String] = [
        "UICTFontTextStyleBody",
        "UICTFontTextStyleBody",
        "UICTFontTextStyleBody",
        "UICTFontTextStyleBody",
        "UICTFontTextStyleBody",
        "UICTFontTextStyleBody"
    ]
    
    // Callback to regenerate TOC after settings change
    var onSettingsChanged: (() -> Void)?
    
    // Available styles from project stylesheet (name -> displayName pairs)
    private var availableStyles: [(name: String, displayName: String)] {
        guard let project = file.project ?? file.parentFolder?.project,
              let styleSheet = StyleSheetService.getStyleSheet(for: project, context: modelContext),
              let styles = styleSheet.textStyles else {
            // Fallback defaults if no stylesheet found
            return [
                ("UICTFontTextStyleTitle0", "Large Title"),
                ("UICTFontTextStyleTitle1", "Title 1"),
                ("UICTFontTextStyleTitle2", "Title 2"),
                ("UICTFontTextStyleTitle3", "Title 3"),
                ("UICTFontTextStyleHeadline", "Headline"),
                ("UICTFontTextStyleBody", "Body")
            ]
        }
        return styles.sorted { $0.displayOrder < $1.displayOrder }
            .map { (name: $0.name, displayName: $0.displayName) }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Title Section
                Section {
                    TextField(NSLocalizedString("toc.settings.titlePlaceholder", comment: "Table of Contents title"), text: $title)
                        .accessibilityLabel(NSLocalizedString("toc.settings.title.accessibility", comment: "TOC title"))
                    
                    // Title style picker
                    Picker(NSLocalizedString("toc.settings.titleStyle", comment: "Title style"), selection: $titleStyleName) {
                        ForEach(availableStyles, id: \.name) { style in
                            Text(style.displayName).tag(style.name)
                        }
                    }
                } header: {
                    Text(NSLocalizedString("toc.settings.titleSection", comment: "Title"))
                } footer: {
                    Text(NSLocalizedString("toc.settings.titleFooter", comment: "The heading displayed at the top of the Table of Contents"))
                }
                
                // Entry Styles Section - Per level
                Section {
                    ForEach(0..<4, id: \.self) { level in
                        Picker(levelLabel(for: level), selection: $levelStyleNames[level]) {
                            ForEach(availableStyles, id: \.name) { style in
                                Text(style.displayName).tag(style.name)
                            }
                        }
                    }
                } header: {
                    Text(NSLocalizedString("toc.settings.entryStylesSection", comment: "Entry Styles"))
                } footer: {
                    Text(NSLocalizedString("toc.settings.entryStylesFooter", comment: "Style for each heading level in the Table of Contents"))
                }
                
                // Formatting Section
                Section {
                    // Show page numbers
                    Toggle(NSLocalizedString("toc.settings.showPageNumbers", comment: "Show page numbers"), isOn: $showPageNumbers)
                } header: {
                    Text(NSLocalizedString("toc.settings.formattingSection", comment: "Formatting"))
                }
                
                // Indentation Section
                Section {
                    Stepper(value: $indentPoints, in: 0...60, step: 5) {
                        HStack {
                            Text(NSLocalizedString("toc.settings.indent", comment: "Indent per level"))
                            Spacer()
                            Text("\(Int(indentPoints)) pt")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel(NSLocalizedString("toc.settings.indent.accessibility", comment: "Indent amount per TOC level"))
                } header: {
                    Text(NSLocalizedString("toc.settings.indentSection", comment: "Indentation"))
                } footer: {
                    Text(NSLocalizedString("toc.settings.indentFooter", comment: "Indent amount for each heading level in points"))
                }
                
                // Preview Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        previewEntry(text: "Chapter One", level: 0, pageNumber: 1)
                        previewEntry(text: "Scene One", level: 1, pageNumber: 3)
                        previewEntry(text: "Scene Two", level: 1, pageNumber: 7)
                        previewEntry(text: "Chapter Two", level: 0, pageNumber: 15)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(NSLocalizedString("toc.settings.previewSection", comment: "Preview"))
                }
            }
            .navigationTitle(NSLocalizedString("toc.settings.navigationTitle", comment: "TOC Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.save", comment: "Save")) {
                        saveSettings()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadSettings()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func levelLabel(for level: Int) -> String {
        switch level {
        case 0: return NSLocalizedString("toc.settings.level0", comment: "Level 1")
        case 1: return NSLocalizedString("toc.settings.level1", comment: "Level 2")
        case 2: return NSLocalizedString("toc.settings.level2", comment: "Level 3")
        case 3: return NSLocalizedString("toc.settings.level3", comment: "Level 4")
        default: return "Level \(level + 1)"
        }
    }
    
    // MARK: - Preview Entry
    
    @ViewBuilder
    private func previewEntry(text: String, level: Int, pageNumber: Int) -> some View {
        HStack(spacing: 0) {
            if showPageNumbers {
                Text("\(text)  \(pageNumber)")
                    .font(.subheadline)
            } else {
                Text(text)
                    .font(.subheadline)
            }
            Spacer()
        }
        .padding(.leading, CGFloat(level) * indentPoints)
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        let settings = file.tocSettings
        title = settings.title
        separator = settings.separator
        indentPoints = settings.indentPoints
        showPageNumbers = settings.showPageNumbers
        useDotLeaders = settings.useDotLeaders
        titleStyleName = settings.titleStyleName
        pageNumberPosition = settings.pageNumberPosition
        
        // Load per-level styles
        for i in 0..<min(levelStyleNames.count, settings.levelStyleNames.count) {
            levelStyleNames[i] = settings.levelStyleNames[i]
        }
    }
    
    private func saveSettings() {
        var settings = TOCSettings()
        settings.title = title
        settings.separator = separator
        settings.indentPoints = indentPoints
        settings.showPageNumbers = showPageNumbers
        settings.useDotLeaders = useDotLeaders
        settings.titleStyleName = titleStyleName
        settings.pageNumberPosition = pageNumberPosition
        settings.levelStyleNames = levelStyleNames
        
        file.tocSettings = settings
        
        // Trigger TOC regeneration
        onSettingsChanged?()
    }
}
