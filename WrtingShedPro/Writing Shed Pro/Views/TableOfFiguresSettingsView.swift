//
//  TableOfFiguresSettingsView.swift
//  Writing Shed Pro
//
//  Feature 112: Table of Figures Settings UI
//

import SwiftUI
import SwiftData

/// Sheet view for configuring Table of Figures settings
struct TableOfFiguresSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var file: TextFile
    
    // Local state for editing (copied from file on appear)
    @State private var title: String = "List of Figures"
    @State private var titleStyleName: String = "UICTFontTextStyleTitle0"
    @State private var entryStyleName: String = "UICTFontTextStyleBody"
    @State private var showPageNumbers: Bool = true
    @State private var separator: String = "."
    @State private var useDotLeaders: Bool = true
    @State private var pageNumberPosition: CGFloat = 480
    @State private var showMissingCaption: Bool = true
    @State private var captionPrefix: String = "Figure"
    @State private var useCaptionPrefix: Bool = true
    
    // Callback to regenerate content after settings change
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
                    TextField(NSLocalizedString("tof.settings.titlePlaceholder", comment: "Table of Figures title"), text: $title)
                        .accessibilityLabel(NSLocalizedString("tof.settings.title.accessibility", comment: "Title"))
                    
                    // Title style picker
                    Picker(NSLocalizedString("tof.settings.titleStyle", comment: "Title style"), selection: $titleStyleName) {
                        ForEach(availableStyles, id: \.name) { style in
                            Text(style.displayName).tag(style.name)
                        }
                    }
                } header: {
                    Text(NSLocalizedString("tof.settings.titleSection", comment: "Title"))
                } footer: {
                    Text(NSLocalizedString("tof.settings.titleFooter", comment: "The heading displayed at the top of the Table of Figures"))
                }
                
                // Entry Style Section
                Section {
                    Picker(NSLocalizedString("tof.settings.entryStyle", comment: "Entry style"), selection: $entryStyleName) {
                        ForEach(availableStyles, id: \.name) { style in
                            Text(style.displayName).tag(style.name)
                        }
                    }
                } header: {
                    Text(NSLocalizedString("tof.settings.entryStyleSection", comment: "Entry Style"))
                } footer: {
                    Text(NSLocalizedString("tof.settings.entryStyleFooter", comment: "Style for figure entries in the list"))
                }
                
                // Caption Prefix Section
                Section {
                    Toggle(NSLocalizedString("tof.settings.useCaptionPrefix", comment: "Use caption prefix"), isOn: $useCaptionPrefix)
                    
                    if useCaptionPrefix {
                        TextField(NSLocalizedString("tof.settings.prefixPlaceholder", comment: "Figure"), text: $captionPrefix)
                            .accessibilityLabel(NSLocalizedString("tof.settings.prefix.accessibility", comment: "Caption prefix"))
                    }
                } header: {
                    Text(NSLocalizedString("tof.settings.prefixSection", comment: "Numbering"))
                } footer: {
                    if useCaptionPrefix {
                        Text(NSLocalizedString("tof.settings.prefixFooter", comment: "Entries will appear as \"Figure 1: Caption text\""))
                    } else {
                        Text(NSLocalizedString("tof.settings.noPrefixFooter", comment: "Entries will show caption text only"))
                    }
                }
                
                // Formatting Section
                Section {
                    // Show page numbers
                    Toggle(NSLocalizedString("tof.settings.showPageNumbers", comment: "Show page numbers"), isOn: $showPageNumbers)
                    
                    // Separator character (only visible if page numbers enabled)
                    if showPageNumbers {
                        HStack {
                            Text(NSLocalizedString("tof.settings.separator", comment: "Separator"))
                            Spacer()
                            Picker("", selection: $separator) {
                                Text(".").tag(".")
                                Text("-").tag("-")
                                Text("_").tag("_")
                                Text(NSLocalizedString("tof.settings.separator.space", comment: "Space")).tag(" ")
                                Text(NSLocalizedString("tof.settings.separator.none", comment: "None")).tag("")
                            }
                            .pickerStyle(.menu)
                            .accessibilityLabel(NSLocalizedString("tof.settings.separator.accessibility", comment: "Separator character"))
                        }
                        
                        // Dot leaders toggle
                        Toggle(NSLocalizedString("tof.settings.useDotLeaders", comment: "Use dot leaders"), isOn: $useDotLeaders)
                            .accessibilityHint(NSLocalizedString("tof.settings.useDotLeaders.hint", comment: "Repeat separator character to fill space"))
                        
                        // Page number position
                        Stepper(value: $pageNumberPosition, in: 300...600, step: 20) {
                            HStack {
                                Text(NSLocalizedString("tof.settings.pageNumberPosition", comment: "Page number position"))
                                Spacer()
                                Text("\(Int(pageNumberPosition)) pt")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text(NSLocalizedString("tof.settings.formattingSection", comment: "Formatting"))
                }
                
                // Missing Captions Section
                Section {
                    Toggle(NSLocalizedString("tof.settings.showMissingCaption", comment: "Show uncaptioned images"), isOn: $showMissingCaption)
                } header: {
                    Text(NSLocalizedString("tof.settings.missingCaptionSection", comment: "Missing Captions"))
                } footer: {
                    if showMissingCaption {
                        Text(NSLocalizedString("tof.settings.missingCaptionFooter.show", comment: "Images without captions will appear with \"Missing caption\" text"))
                    } else {
                        Text(NSLocalizedString("tof.settings.missingCaptionFooter.hide", comment: "Images without captions will be skipped, with a summary shown at the end"))
                    }
                }
                
                // Preview Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        previewEntry(number: 1, caption: "Sunrise over the mountains", pageNumber: 12)
                        previewEntry(number: 2, caption: "The old barn", pageNumber: 27)
                        previewEntry(number: 3, caption: showMissingCaption ? NSLocalizedString("tof.missingCaption", comment: "Missing caption") : nil, pageNumber: 45)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(NSLocalizedString("tof.settings.previewSection", comment: "Preview"))
                }
            }
            .navigationTitle(NSLocalizedString("tof.settings.navigationTitle", comment: "Table of Figures Settings"))
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
    
    // MARK: - Preview Entry
    
    @ViewBuilder
    private func previewEntry(number: Int, caption: String?, pageNumber: Int) -> some View {
        if let caption = caption {
            HStack(spacing: 0) {
                // Entry text
                if useCaptionPrefix && !captionPrefix.isEmpty {
                    Text("\(captionPrefix) \(number): \(caption)")
                        .font(.subheadline)
                } else {
                    Text(caption)
                        .font(.subheadline)
                }
                
                // Separator/Leaders
                if showPageNumbers {
                    if useDotLeaders && !separator.isEmpty {
                        Text(" " + String(repeating: separator + " ", count: 15))
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    } else {
                        Spacer()
                    }
                    
                    // Page number
                    Text("\(pageNumber)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        let settings = file.tableOfFiguresSettings
        title = settings.title
        titleStyleName = settings.titleStyleName
        entryStyleName = settings.entryStyleName
        showPageNumbers = settings.showPageNumbers
        separator = settings.separator
        useDotLeaders = settings.useDotLeaders
        pageNumberPosition = settings.pageNumberPosition
        showMissingCaption = settings.showMissingCaption
        captionPrefix = settings.captionPrefix ?? "Figure"
        useCaptionPrefix = settings.captionPrefix != nil
    }
    
    private func saveSettings() {
        var settings = TableOfFiguresSettings()
        settings.title = title
        settings.titleStyleName = titleStyleName
        settings.entryStyleName = entryStyleName
        settings.showPageNumbers = showPageNumbers
        settings.separator = separator
        settings.useDotLeaders = useDotLeaders
        settings.pageNumberPosition = pageNumberPosition
        settings.showMissingCaption = showMissingCaption
        settings.captionPrefix = useCaptionPrefix ? captionPrefix : nil
        
        file.tableOfFiguresSettings = settings
        
        // Trigger content regeneration
        onSettingsChanged?()
    }
}
