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
    @Binding var isPresented: Bool
    
    // Local state for editing (copied from file on appear)
    @State private var title: String = "List of Figures"
    @State private var showPageNumbers: Bool = true
    @State private var showMissingCaption: Bool = false
    @State private var captionPrefix: String = "Figure"
    @State private var useCaptionPrefix: Bool = true
    
    // Callback to regenerate content after settings change
    var onSettingsChanged: (() -> Void)?
    
    /// Resolve the project's matter heading style display name
    private var matterHeadingDisplayName: String {
        guard let project = file.project ?? file.parentFolder?.project,
              let styleSheet = StyleSheetService.getStyleSheet(for: project, context: modelContext),
              let style = styleSheet.textStyles?.first(where: { $0.name == project.matterHeadingStyleName }) else {
            return "Title 1"
        }
        return style.displayName
    }
    
    /// Resolve the project's matter body style display name
    private var matterBodyDisplayName: String {
        guard let project = file.project ?? file.parentFolder?.project,
              let styleSheet = StyleSheetService.getStyleSheet(for: project, context: modelContext),
              let style = styleSheet.textStyles?.first(where: { $0.name == project.matterBodyStyleName }) else {
            return "Body"
        }
        return style.displayName
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Title Section
                Section {
                    TextField(NSLocalizedString("tof.settings.titlePlaceholder", comment: "Table of Figures title"), text: $title)
                        .accessibilityLabel(NSLocalizedString("tof.settings.title.accessibility", comment: "Title"))
                } header: {
                    Text(NSLocalizedString("tof.settings.titleSection", comment: "Title"))
                } footer: {
                    Text(String(format: NSLocalizedString("tof.settings.titleFooter.withStyle", comment: ""), matterHeadingDisplayName))
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
                } header: {
                    Text(NSLocalizedString("tof.settings.formattingSection", comment: "Formatting"))
                } footer: {
                    Text(String(format: NSLocalizedString("tof.settings.formattingFooter.withStyle", comment: ""), matterBodyDisplayName))
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
                        Text(NSLocalizedString("tof.settings.missingCaptionFooter.hide", comment: "Images without captions will be skipped"))
                    }
                }
                
                // Preview Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.title)
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
                        dismissSheet()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.save", comment: "Save")) {
                        saveSettings()
                        dismissSheet()
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
                        .font(.body)
                } else {
                    Text(caption)
                        .font(.body)
                }
                
                if showPageNumbers {
                    Text(" ")
                    Text(String(repeating: ". ", count: 15))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    Text(" \(pageNumber)")
                        .foregroundStyle(.secondary)
                }
                
                Spacer(minLength: 0)
            }
        }
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        let settings = file.tableOfFiguresSettings
        title = settings.title
        showPageNumbers = settings.showPageNumbers
        showMissingCaption = settings.showMissingCaption
        captionPrefix = settings.captionPrefix ?? "Figure"
        useCaptionPrefix = settings.captionPrefix != nil
    }
    
    /// Dismiss the sheet reliably on all platforms including Mac Catalyst
    private func dismissSheet() {
        isPresented = false
        dismiss()
        dismissPresentedSheetOnCatalyst()
    }
    
    private func saveSettings() {
        var settings = file.tableOfFiguresSettings  // Preserve existing values for fields we don't edit
        settings.title = title
        settings.showPageNumbers = showPageNumbers
        settings.showMissingCaption = showMissingCaption
        settings.captionPrefix = useCaptionPrefix ? captionPrefix : nil
        
        file.tableOfFiguresSettings = settings
        
        // Trigger content regeneration
        onSettingsChanged?()
    }
}
