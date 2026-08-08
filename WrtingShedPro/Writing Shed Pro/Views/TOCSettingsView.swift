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
    @Binding var isPresented: Bool
    
    // Local state for editing (copied from file on appear)
    @State private var title: String = "Contents"
    @State private var separator: String = "."
    @State private var showPageNumbers: Bool = true
    @State private var useDotLeaders: Bool = true
    @State private var pageNumberPosition: CGFloat = 480
    @State private var titleStyleName: String = "UICTFontTextStyleTitle0"
    
    @State private var level0StyleName: String = "UICTFontTextStyleBody"
    @State private var level1StyleName: String = "UICTFontTextStyleBody"
    @State private var level2StyleName: String = "UICTFontTextStyleBody"
    @State private var level3StyleName: String = "UICTFontTextStyleBody"
    @State private var saveErrorMessage: String?
    @State private var isSaving = false
    
    // Callback to regenerate TOC after settings change
    var onSettingsChanged: (() -> Void)?

    private var project: Project? {
        var currentFolder = file.parentFolder
        while let folder = currentFolder {
            if let project = folder.project { return project }
            currentFolder = folder.parentFolder
        }
        return file.project
    }

    private var persistenceContext: ModelContext {
        file.modelContext ?? modelContext
    }
    
    // Available styles from project stylesheet (name -> displayName pairs)
    private var availableStyles: [(name: String, displayName: String)] {
          guard let project,
              let styleSheet = StyleSheetService.getStyleSheet(for: project, context: persistenceContext),
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
                    Picker(NSLocalizedString("toc.settings.titleStyle", comment: "Title style"), selection: $titleStyleName) {
                        ForEach(availableStyles, id: \.name) { style in
                            Text(style.displayName).tag(style.name)
                        }
                    }
                } header: {
                    Text(NSLocalizedString("toc.settings.titleSection", comment: "Title"))
                } footer: {
                    Text(NSLocalizedString("toc.settings.stylesFooter", comment: "Styles applied to the TOC title and entries"))
                }
                
                // Entry Styles Section - Per level
                Section {
                    levelStylePicker(level: 0, selection: $level0StyleName)
                    levelStylePicker(level: 1, selection: $level1StyleName)
                    levelStylePicker(level: 2, selection: $level2StyleName)
                    levelStylePicker(level: 3, selection: $level3StyleName)
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
                
            }
            .navigationTitle(NSLocalizedString("toc.settings.navigationTitle", comment: "TOC Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        dismissSheet()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.save", comment: "Save")) {
                        saveSettings()
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                loadSettings()
            }
            .alert(NSLocalizedString("toc.settings.saveFailed.title", comment: "TOC settings save failed title"), isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button(NSLocalizedString("button.ok", comment: "OK")) {
                    saveErrorMessage = nil
                }
            } message: {
                Text(saveErrorMessage ?? "")
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

    private func levelStylePicker(level: Int, selection: Binding<String>) -> some View {
        Picker(levelLabel(for: level), selection: selection) {
            ForEach(availableStyles, id: \.name) { style in
                Text(style.displayName).tag(style.name)
            }
        }
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        let settings = file.tocSettings
        title = settings.title
        separator = settings.separator
        showPageNumbers = settings.showPageNumbers
        useDotLeaders = settings.useDotLeaders
        pageNumberPosition = settings.pageNumberPosition
        titleStyleName = settings.titleStyleName
        
        let styleNames = normalizedLevelStyleNames(from: settings.levelStyleNames)
        level0StyleName = styleNames[0]
        level1StyleName = styleNames[1]
        level2StyleName = styleNames[2]
        level3StyleName = styleNames[3]
    }
    
    /// Dismiss the sheet reliably on all platforms including Mac Catalyst
    private func dismissSheet() {
        isPresented = false
        #if targetEnvironment(macCatalyst)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            if topVC != rootVC {
                topVC.dismiss(animated: true)
            }
        }
        #endif
    }
    
    private func saveSettings() {
        guard !isSaving else { return }
        isSaving = true

        Task { @MainActor in
            await persistSettingsWhenEnsemblesIsIdle()
        }
    }

    @MainActor
    private func persistSettingsWhenEnsemblesIsIdle() async {
        var settings = file.tocSettings
        settings.title = title
        settings.separator = separator
        settings.showPageNumbers = showPageNumbers
        settings.useDotLeaders = useDotLeaders
        settings.pageNumberPosition = pageNumberPosition
        settings.titleStyleName = titleStyleName
        settings.levelStyleNames = [
            level0StyleName,
            level1StyleName,
            level2StyleName,
            level3StyleName,
            "UICTFontTextStyleBody",
            "UICTFontTextStyleBody"
        ]
        
        do {
            let data = try JSONEncoder().encode(settings)
            let reason = "toc-settings-save"

            while true {
                while !EnsemblesSaveGate.canSaveNow(reason: reason) {
                    try await Task.sleep(nanoseconds: 500_000_000)
                }

                file.tocSettingsData = data
                file.modifiedDate = Date()
                applySettingsDataToProjectTOCFiles(data)

                do {
                    try EnsemblesSaveGate.save(persistenceContext, reason: reason)
                    guard tocSettingsWerePersisted(settings) else {
                        throw TOCSettingsSaveError.verificationFailed
                    }
                    Write_App.scheduleEnsemblesSyncAfterLocalSave(reason: reason)
                    onSettingsChanged?()
                    isSaving = false
                    dismissSheet()
                    return
                } catch is EnsemblesSaveGateError {
                    continue
                }
            }
        } catch {
            #if DEBUG
            print("❌ TOCSettingsView failed to save settings: \(error)")
            #endif
            isSaving = false
            saveErrorMessage = error.localizedDescription
        }
    }

    private func applySettingsDataToProjectTOCFiles(_ data: Data) {
        guard let project else { return }
        project.modifiedDate = Date()

        let projectID = project.id
        let allTextFiles = (try? persistenceContext.fetch(FetchDescriptor<TextFile>())) ?? []
        for textFile in allTextFiles {
            guard textFile.id == file.id || textFile.project?.id == projectID else { continue }
            guard textFile.id == file.id || textFile.isTOCFile || textFile.name == "Table of Contents" || textFile.name == "Contents" else { continue }
            textFile.tocSettingsData = data
            textFile.modifiedDate = Date()
        }
    }

    private func tocSettingsWerePersisted(_ expectedSettings: TOCSettings) -> Bool {
        let verificationContext = ModelContext(modelContext.container)
        let fileID = file.id
        let descriptor = FetchDescriptor<TextFile>(
            predicate: #Predicate<TextFile> { candidate in
                candidate.id == fileID
            }
        )
        guard let savedFile = try? verificationContext.fetch(descriptor).first else { return false }
        return savedFile.tocSettings == expectedSettings
    }

    private func normalizedLevelStyleNames(from styleNames: [String]) -> [String] {
        var normalized = styleNames
        while normalized.count < 4 {
            normalized.append("UICTFontTextStyleBody")
        }
        return Array(normalized.prefix(4))
    }
}

private enum TOCSettingsSaveError: LocalizedError {
    case verificationFailed

    var errorDescription: String? {
        NSLocalizedString(
            "toc.settings.saveFailed.verification",
            comment: "TOC settings could not be verified after saving"
        )
    }
}
