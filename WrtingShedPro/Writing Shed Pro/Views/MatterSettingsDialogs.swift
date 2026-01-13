//
//  MatterSettingsDialogs.swift
//  Writing Shed Pro
//
//  Settings dialogs for Front Matter and Back Matter folder items
//

import SwiftUI
import SwiftData

// MARK: - Front Matter Settings Dialog

/// Dialog for configuring which front matter items to include
/// Automatically shows Drama-specific items for Drama projects
struct FrontMatterSettingsDialog: View {
    @Bindable var folder: Folder
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Fiction project items
    @State private var enabledItems: Set<FrontMatterItem> = []
    // Drama project items
    @State private var dramaEnabledItems: Set<DramaFrontMatterItem> = []
    @State private var isProcessing = false
    
    private var isDrama: Bool {
        folder.isDramaProject
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if isDrama {
                        ForEach(DramaFrontMatterItem.allCases) { item in
                            Toggle(item.localizedName, isOn: dramaBinding(for: item))
                        }
                    } else {
                        ForEach(FrontMatterItem.allCases) { item in
                            Toggle(item.localizedName, isOn: binding(for: item))
                        }
                    }
                } header: {
                    Text(NSLocalizedString("frontMatter.settings.header", comment: "Select items to include"))
                } footer: {
                    Text(NSLocalizedString("frontMatter.settings.footer", comment: "Enabled items will appear as files in your Front Matter folder."))
                }
            }
            .formStyle(.grouped)
            .navigationTitle(NSLocalizedString("frontMatter.settings.title", comment: "Front Matter"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.save", comment: "Save")) {
                        saveSettings()
                    }
                    .disabled(isProcessing)
                }
            }
            .onAppear {
                if isDrama {
                    dramaEnabledItems = folder.dramaFrontMatterSettings.enabledItems
                } else {
                    enabledItems = folder.frontMatterSettings.enabledItems
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: isDrama ? 350 : 450)
        #endif
    }
    
    private func binding(for item: FrontMatterItem) -> Binding<Bool> {
        Binding(
            get: { enabledItems.contains(item) },
            set: { isEnabled in
                if isEnabled {
                    enabledItems.insert(item)
                } else {
                    enabledItems.remove(item)
                }
            }
        )
    }
    
    private func dramaBinding(for item: DramaFrontMatterItem) -> Binding<Bool> {
        Binding(
            get: { dramaEnabledItems.contains(item) },
            set: { isEnabled in
                if isEnabled {
                    dramaEnabledItems.insert(item)
                } else {
                    dramaEnabledItems.remove(item)
                }
            }
        )
    }
    
    private func saveSettings() {
        isProcessing = true
        
        if isDrama {
            saveDramaSettings()
        } else {
            saveFictionSettings()
        }
        
        try? modelContext.save()
        isProcessing = false
        dismiss()
    }
    
    private func saveFictionSettings() {
        let previousSettings = folder.frontMatterSettings
        let newSettings = FrontMatterSettings(enabledItems: enabledItems)
        
        // Create files for newly enabled items
        let newlyEnabled = enabledItems.subtracting(previousSettings.enabledItems)
        for item in newlyEnabled.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            createFileForItem(item)
        }
        
        // Remove files for newly disabled items
        let newlyDisabled = previousSettings.enabledItems.subtracting(enabledItems)
        for item in newlyDisabled {
            removeFileForItem(item)
        }
        
        folder.frontMatterSettings = newSettings
    }
    
    private func saveDramaSettings() {
        let previousSettings = folder.dramaFrontMatterSettings
        let newSettings = DramaFrontMatterSettings(enabledItems: dramaEnabledItems)
        
        // Create files for newly enabled items
        let newlyEnabled = dramaEnabledItems.subtracting(previousSettings.enabledItems)
        for item in newlyEnabled.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            createFileForDramaItem(item)
        }
        
        // Remove files for newly disabled items
        let newlyDisabled = previousSettings.enabledItems.subtracting(dramaEnabledItems)
        for item in newlyDisabled {
            removeFileForDramaItem(item)
        }
        
        folder.dramaFrontMatterSettings = newSettings
    }
    
    private func createFileForItem(_ item: FrontMatterItem) {
        let existingFiles = folder.textFiles ?? []
        if existingFiles.contains(where: { $0.name == item.fileName }) {
            return
        }
        
        let textFile = TextFile(name: item.fileName, initialContent: "", parentFolder: folder)
        textFile.userOrder = item.sortOrder
        modelContext.insert(textFile)
        
        if folder.textFiles == nil {
            folder.textFiles = []
        }
        folder.textFiles?.append(textFile)
    }
    
    private func createFileForDramaItem(_ item: DramaFrontMatterItem) {
        let existingFiles = folder.textFiles ?? []
        if existingFiles.contains(where: { $0.name == item.fileName }) {
            return
        }
        
        let textFile = TextFile(name: item.fileName, initialContent: "", parentFolder: folder)
        textFile.userOrder = item.sortOrder
        modelContext.insert(textFile)
        
        if folder.textFiles == nil {
            folder.textFiles = []
        }
        folder.textFiles?.append(textFile)
    }
    
    private func removeFileForItem(_ item: FrontMatterItem) {
        guard let files = folder.textFiles else { return }
        if let file = files.first(where: { $0.name == item.fileName }) {
            if let version = file.currentVersion,
               let content = version.attributedContent,
               !content.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return
            }
            modelContext.delete(file)
        }
    }
    
    private func removeFileForDramaItem(_ item: DramaFrontMatterItem) {
        guard let files = folder.textFiles else { return }
        if let file = files.first(where: { $0.name == item.fileName }) {
            if let version = file.currentVersion,
               let content = version.attributedContent,
               !content.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return
            }
            modelContext.delete(file)
        }
    }
}

// MARK: - Back Matter Settings Dialog

/// Dialog for configuring which back matter items to include
/// Automatically shows Drama-specific items for Drama projects
struct BackMatterSettingsDialog: View {
    @Bindable var folder: Folder
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Fiction project items
    @State private var enabledItems: Set<BackMatterItem> = []
    // Drama project items
    @State private var dramaEnabledItems: Set<DramaBackMatterItem> = []
    @State private var isProcessing = false
    
    private var isDrama: Bool {
        folder.isDramaProject
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if isDrama {
                        ForEach(DramaBackMatterItem.allCases) { item in
                            Toggle(item.localizedName, isOn: dramaBinding(for: item))
                        }
                    } else {
                        ForEach(BackMatterItem.allCases) { item in
                            Toggle(item.localizedName, isOn: binding(for: item))
                        }
                    }
                } header: {
                    Text(NSLocalizedString("backMatter.settings.header", comment: "Select items to include"))
                } footer: {
                    Text(NSLocalizedString("backMatter.settings.footer", comment: "Enabled items will appear as files in your Back Matter folder."))
                }
            }
            .formStyle(.grouped)
            .navigationTitle(NSLocalizedString("backMatter.settings.title", comment: "Back Matter"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.save", comment: "Save")) {
                        saveSettings()
                    }
                    .disabled(isProcessing)
                }
            }
            .onAppear {
                if isDrama {
                    dramaEnabledItems = folder.dramaBackMatterSettings.enabledItems
                } else {
                    enabledItems = folder.backMatterSettings.enabledItems
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: isDrama ? 280 : 300)
        #endif
    }
    
    private func binding(for item: BackMatterItem) -> Binding<Bool> {
        Binding(
            get: { enabledItems.contains(item) },
            set: { isEnabled in
                if isEnabled {
                    enabledItems.insert(item)
                } else {
                    enabledItems.remove(item)
                }
            }
        )
    }
    
    private func dramaBinding(for item: DramaBackMatterItem) -> Binding<Bool> {
        Binding(
            get: { dramaEnabledItems.contains(item) },
            set: { isEnabled in
                if isEnabled {
                    dramaEnabledItems.insert(item)
                } else {
                    dramaEnabledItems.remove(item)
                }
            }
        )
    }
    
    private func saveSettings() {
        isProcessing = true
        
        if isDrama {
            saveDramaSettings()
        } else {
            saveFictionSettings()
        }
        
        try? modelContext.save()
        isProcessing = false
        dismiss()
    }
    
    private func saveFictionSettings() {
        let previousSettings = folder.backMatterSettings
        let newSettings = BackMatterSettings(enabledItems: enabledItems)
        
        // Create files for newly enabled items
        let newlyEnabled = enabledItems.subtracting(previousSettings.enabledItems)
        for item in newlyEnabled.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            createFileForItem(item)
        }
        
        // Remove files for newly disabled items
        let newlyDisabled = previousSettings.enabledItems.subtracting(enabledItems)
        for item in newlyDisabled {
            removeFileForItem(item)
        }
        
        folder.backMatterSettings = newSettings
    }
    
    private func saveDramaSettings() {
        let previousSettings = folder.dramaBackMatterSettings
        let newSettings = DramaBackMatterSettings(enabledItems: dramaEnabledItems)
        
        // Create files for newly enabled items
        let newlyEnabled = dramaEnabledItems.subtracting(previousSettings.enabledItems)
        for item in newlyEnabled.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            createFileForDramaItem(item)
        }
        
        // Remove files for newly disabled items
        let newlyDisabled = previousSettings.enabledItems.subtracting(dramaEnabledItems)
        for item in newlyDisabled {
            removeFileForDramaItem(item)
        }
        
        folder.dramaBackMatterSettings = newSettings
    }
    
    private func createFileForItem(_ item: BackMatterItem) {
        let existingFiles = folder.textFiles ?? []
        if existingFiles.contains(where: { $0.name == item.fileName }) {
            return
        }
        
        let textFile = TextFile(name: item.fileName, initialContent: "", parentFolder: folder)
        textFile.userOrder = item.sortOrder
        modelContext.insert(textFile)
        
        if folder.textFiles == nil {
            folder.textFiles = []
        }
        folder.textFiles?.append(textFile)
    }
    
    private func createFileForDramaItem(_ item: DramaBackMatterItem) {
        let existingFiles = folder.textFiles ?? []
        if existingFiles.contains(where: { $0.name == item.fileName }) {
            return
        }
        
        let textFile = TextFile(name: item.fileName, initialContent: "", parentFolder: folder)
        textFile.userOrder = item.sortOrder
        modelContext.insert(textFile)
        
        if folder.textFiles == nil {
            folder.textFiles = []
        }
        folder.textFiles?.append(textFile)
    }
    
    private func removeFileForItem(_ item: BackMatterItem) {
        guard let files = folder.textFiles else { return }
        if let file = files.first(where: { $0.name == item.fileName }) {
            if let version = file.currentVersion,
               let content = version.attributedContent,
               !content.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return
            }
            modelContext.delete(file)
        }
    }
    
    private func removeFileForDramaItem(_ item: DramaBackMatterItem) {
        guard let files = folder.textFiles else { return }
        if let file = files.first(where: { $0.name == item.fileName }) {
            if let version = file.currentVersion,
               let content = version.attributedContent,
               !content.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return
            }
            modelContext.delete(file)
        }
    }
}
