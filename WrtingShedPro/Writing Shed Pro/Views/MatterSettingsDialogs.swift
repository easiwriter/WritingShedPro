//
//  MatterSettingsDialogs.swift
//  Writing Shed Pro
//
//  Settings dialogs for Front Matter and Back Matter folder items
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - Front Matter Settings Dialog

/// Dialog for configuring which front matter items to include
/// Automatically shows Drama-specific items for Drama projects
struct FrontMatterSettingsDialog: View {
    @Bindable var folder: Folder
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Fiction project items
    @State private var enabledItems: Set<FrontMatterItem> = []
    // Drama project items
    @State private var dramaEnabledItems: Set<DramaFrontMatterItem> = []
    @State private var isProcessing = false
    @State private var showMatterStylePicker = false
    
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

                matterStylesSection
            }
            .formStyle(.grouped)
            .navigationTitle(NSLocalizedString("frontMatter.settings.title", comment: "Front Matter"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        dismissSheet()
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
            .sheet(isPresented: $showMatterStylePicker) {
                if let project = folder.resolvedProject {
                    MatterStylePickerSheet(project: project, isPresented: $showMatterStylePicker)
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

    private var matterStylesSection: some View {
        Section {
            Button {
                showMatterStylePicker = true
            } label: {
                Label(NSLocalizedString("manuscript.matterStyles", comment: "Matter Styles"), systemImage: "textformat.size")
            }
        } header: {
            Text(NSLocalizedString("matterStyle.title", comment: "Matter Styles"))
        } footer: {
            Text(NSLocalizedString("matterStyle.headingFooter", comment: "Style used for headings in generated sections like Notes, Glossary, References, Index, and List of Figures."))
        }
    }
    
    private func saveSettings() {
        isProcessing = true
        
        if isDrama {
            saveDramaSettings()
        } else {
            saveFictionSettings()
        }
        
        WriteCoalescer.shared?.requestSave(reason: "front-matter-settings-save")
        WriteCoalescer.shared?.flush()
        isProcessing = false
        dismissSheet()
    }

    private func dismissSheet() {
        isPresented = false
        dismiss()
        #if targetEnvironment(macCatalyst)
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                var topVC = rootVC
                while let presented = topVC.presentedViewController {
                    topVC = presented
                }
                if topVC !== rootVC {
                    topVC.dismiss(animated: true)
                }
            }
        }
        #endif
    }
    
    private func saveFictionSettings() {
        let newSettings = FrontMatterSettings(enabledItems: enabledItems)
        
        for item in enabledItems.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            createFileForItem(item)
        }
        
        for item in FrontMatterItem.allCases where !enabledItems.contains(item) {
            removeFileForItem(item)
        }
        
        folder.frontMatterSettings = newSettings
    }
    
    private func saveDramaSettings() {
        let newSettings = DramaFrontMatterSettings(enabledItems: dramaEnabledItems)
        
        for item in dramaEnabledItems.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            createFileForDramaItem(item)
        }
        
        for item in DramaFrontMatterItem.allCases where !dramaEnabledItems.contains(item) {
            removeFileForDramaItem(item)
        }
        
        folder.dramaFrontMatterSettings = newSettings
    }
    
    private func createFileForItem(_ item: FrontMatterItem) {
        if fetchFile(named: item.fileName) != nil {
            return
        }
        
        let textFile = TextFile(name: item.fileName, initialContent: "", parentFolder: folder)
        textFile.userOrder = item.sortOrder
        
        // Feature 031: Mark Table of Contents files for auto-generation
        if item == .tableOfContents {
            textFile.isTOCFile = true
        }
        
        // Mark cover files for image-only display
        if item.isCover {
            textFile.isCoverFile = true
        }
        
        modelContext.insert(textFile)
        
        if folder.textFiles == nil {
            folder.textFiles = []
        }
        folder.textFiles?.append(textFile)
    }
    
    private func createFileForDramaItem(_ item: DramaFrontMatterItem) {
        if fetchFile(named: item.fileName) != nil {
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
        if let file = fetchFile(named: item.fileName) {
            folder.textFiles?.removeAll { $0.id == file.id }
            modelContext.delete(file)
        }
    }
    
    private func removeFileForDramaItem(_ item: DramaFrontMatterItem) {
        if let file = fetchFile(named: item.fileName) {
            folder.textFiles?.removeAll { $0.id == file.id }
            modelContext.delete(file)
        }
    }

    private func fetchFile(named fileName: String) -> TextFile? {
        let folderID = folder.id
        let descriptor = FetchDescriptor<TextFile>(
            predicate: #Predicate<TextFile> { file in
                file.parentFolder?.id == folderID && file.name == fileName
            }
        )
        return try? modelContext.fetch(descriptor).first
    }
}

// MARK: - Back Matter Settings Dialog

/// Dialog for configuring which back matter items to include
/// Automatically shows Drama-specific items for Drama projects
struct BackMatterSettingsDialog: View {
    @Bindable var folder: Folder
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Fiction project items
    @State private var enabledItems: Set<BackMatterItem> = []
    // Drama project items
    @State private var dramaEnabledItems: Set<DramaBackMatterItem> = []
    // Index settings
    @State private var indexColumnCount: Int = 2
    @State private var isProcessing = false
    // Confirmation alert for items with entries
    @State private var showRemoveEntriesConfirmation = false
    @State private var pendingItemToDisable: BackMatterItem?
    @State private var showMatterStylePicker = false
    
    private var isDrama: Bool {
        folder.isDramaProject
    }
    
    /// Check if a back matter item has any references in the project
    private func hasReferences(for item: BackMatterItem) -> Bool {
        // Back Matter folder's parent should be Manuscript folder, which has project reference
        guard let project = folder.parentFolder?.project else {
            #if DEBUG
            print("⚠️ hasReferences: Could not access project via folder.parentFolder.project")
            print("   folder: \(folder.name ?? "unknown")")
            print("   parentFolder: \(folder.parentFolder?.name ?? "nil")")
            #endif
            return false
        }
        
        let result: Bool
        switch item {
        case .endnotes:
            let entries = project.noteEntries?.filter { $0.isEndnote && $0.referenceCount > 0 } ?? []
            result = !entries.isEmpty
            #if DEBUG
            print("📊 Endnotes: \(entries.count) with references, hasReferences=\(result)")
            #endif
            return result
        case .glossary:
            let entries = project.glossaryEntries?.filter { $0.referenceCount > 0 } ?? []
            result = !entries.isEmpty
            #if DEBUG
            print("📊 Glossary: \(entries.count) with references, hasReferences=\(result)")
            #endif
            return result
        case .references:
            let entries = project.referenceEntries?.filter { $0.referenceCount > 0 } ?? []
            result = !entries.isEmpty
            #if DEBUG
            print("📊 References: \(entries.count) with references, hasReferences=\(result)")
            #endif
            return result
        case .index:
            let entries = project.indexEntries?.filter { $0.referenceCount > 0 } ?? []
            result = !entries.isEmpty
            #if DEBUG
            print("📊 Index: \(entries.count) with references, hasReferences=\(result)")
            #endif
            return result
        case .tableOfFigures:
            // Table of Figures is based on images in manuscript, not reference-based
            return false
        case .contributors:
            // Contributors are user-created, not reference-based - always allow toggling
            return false
        case .backCover:
            // Back cover is an image file, not reference-based
            return false
        }
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
                
                // Index column count option (only shown when index is enabled)
                if !isDrama && enabledItems.contains(.index) {
                    Section {
                        Picker(NSLocalizedString("backMatter.index.columns", comment: "Index Columns"), selection: $indexColumnCount) {
                            Text("1").tag(1)
                            Text("2").tag(2)
                            Text("3").tag(3)
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text(NSLocalizedString("backMatter.index.settings.header", comment: "Index Settings"))
                    } footer: {
                        Text(NSLocalizedString("backMatter.index.columns.footer", comment: "Number of columns to display the index in when exported."))
                    }
                }

                matterStylesSection
            }
            .formStyle(.grouped)
            .navigationTitle(NSLocalizedString("backMatter.settings.title", comment: "Back Matter"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        dismissSheet()
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
                    let settings = folder.backMatterSettings
                    enabledItems = settings.enabledItems
                    indexColumnCount = settings.indexColumnCount
                }
            }
            .sheet(isPresented: $showMatterStylePicker) {
                if let project = folder.resolvedProject {
                    MatterStylePickerSheet(project: project, isPresented: $showMatterStylePicker)
                }
            }
        }
        .confirmationDialog(
            NSLocalizedString("backMatter.removeEntries.title", comment: "Remove Entries?"),
            isPresented: $showRemoveEntriesConfirmation,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("backMatter.removeEntries.removeAndDisable", comment: "Remove All & Disable"), role: .destructive) {
                if let item = pendingItemToDisable {
                    removeAllEntriesAndReferences(for: item)
                    enabledItems.remove(item)
                    pendingItemToDisable = nil
                }
            }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                pendingItemToDisable = nil
            }
        } message: {
            if let item = pendingItemToDisable {
                Text(String(format: NSLocalizedString("backMatter.removeEntries.message", comment: "The %@ section contains entries that are referenced in your manuscript. Removing will delete all entries and their references from your document."), item.localizedName))
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
                    // Check if item has entries - if so, ask user to confirm removal
                    if hasReferences(for: item) {
                        pendingItemToDisable = item
                        showRemoveEntriesConfirmation = true
                        // Don't remove yet - wait for user confirmation
                    } else {
                        enabledItems.remove(item)
                    }
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

    private var matterStylesSection: some View {
        Section {
            Button {
                showMatterStylePicker = true
            } label: {
                Label(NSLocalizedString("manuscript.matterStyles", comment: "Matter Styles"), systemImage: "textformat.size")
            }
        } header: {
            Text(NSLocalizedString("matterStyle.title", comment: "Matter Styles"))
        } footer: {
            Text(NSLocalizedString("matterStyle.headingFooter", comment: "Style used for headings in generated sections like Notes, Glossary, References, Index, and List of Figures."))
        }
    }
    
    private func saveSettings() {
        isProcessing = true
        
        if isDrama {
            saveDramaSettings()
        } else {
            saveFictionSettings()
        }
        
        WriteCoalescer.shared?.requestSave(reason: "back-matter-settings-save")
        WriteCoalescer.shared?.flush()
        isProcessing = false
        dismissSheet()
    }

    private func dismissSheet() {
        isPresented = false
        dismiss()
        #if targetEnvironment(macCatalyst)
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                var topVC = rootVC
                while let presented = topVC.presentedViewController {
                    topVC = presented
                }
                if topVC !== rootVC {
                    topVC.dismiss(animated: true)
                }
            }
        }
        #endif
    }
    
    private func saveFictionSettings() {
        let previousSettings = folder.backMatterSettings
        let newSettings = BackMatterSettings(
            enabledItems: enabledItems,
            indexColumnCount: indexColumnCount,
            itemTitles: previousSettings.itemTitles
        )
        
        for item in enabledItems.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            createFileForItem(item)
        }
        
        for item in BackMatterItem.allCases where !enabledItems.contains(item) {
            removeFileForItem(item)
        }
        
        folder.backMatterSettings = newSettings
    }
    
    private func saveDramaSettings() {
        let newSettings = DramaBackMatterSettings(enabledItems: dramaEnabledItems)
        
        for item in dramaEnabledItems.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            createFileForDramaItem(item)
        }
        
        for item in DramaBackMatterItem.allCases where !dramaEnabledItems.contains(item) {
            removeFileForDramaItem(item)
        }
        
        folder.dramaBackMatterSettings = newSettings
    }
    
    private func createFileForItem(_ item: BackMatterItem) {
        if fetchFile(named: item.fileName) != nil {
            return
        }
        
        let textFile = TextFile(name: item.fileName, initialContent: "", parentFolder: folder)
        textFile.userOrder = item.sortOrder
        
        // Feature 112: Mark Table of Figures files for auto-generation
        if item == .tableOfFigures {
            textFile.isTableOfFiguresFile = true
        }
        
        // Mark cover files for image-only display
        if item.isCover {
            textFile.isCoverFile = true
        }
        
        modelContext.insert(textFile)
        
        if folder.textFiles == nil {
            folder.textFiles = []
        }
        folder.textFiles?.append(textFile)
    }
    
    private func createFileForDramaItem(_ item: DramaBackMatterItem) {
        if fetchFile(named: item.fileName) != nil {
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
        if let file = fetchFile(named: item.fileName) {
            folder.textFiles?.removeAll { $0.id == file.id }
            modelContext.delete(file)
        }
    }
    
    private func removeFileForDramaItem(_ item: DramaBackMatterItem) {
        if let file = fetchFile(named: item.fileName) {
            if let version = file.currentVersion,
               let content = version.attributedContent,
               !content.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return
            }
            folder.textFiles?.removeAll { $0.id == file.id }
            modelContext.delete(file)
        }
    }

    private func fetchFile(named fileName: String) -> TextFile? {
        let folderID = folder.id
        let descriptor = FetchDescriptor<TextFile>(
            predicate: #Predicate<TextFile> { file in
                file.parentFolder?.id == folderID && file.name == fileName
            }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    /// Remove all entries and inline references for a back matter type
    private func removeAllEntriesAndReferences(for item: BackMatterItem) {
        guard let project = folder.parentFolder?.project else {
            #if DEBUG
            print("⚠️ removeAllEntriesAndReferences: Could not access project")
            #endif
            return
        }
        
        #if DEBUG
        print("🗑️ Removing all entries and references for: \(item.rawValue)")
        #endif
        
        var referenceTypeToRemove: ReferenceType?
        
        switch item {
        case .endnotes:
            referenceTypeToRemove = .note
            project.noteEntries?.removeAll(where: { $0.isEndnote })
            #if DEBUG
            print("✅ Removed all endnote entries")
            #endif
        case .glossary:
            referenceTypeToRemove = .glossary
            project.glossaryEntries?.removeAll()
            #if DEBUG
            print("✅ Removed all glossary entries")
            #endif
        case .references:
            referenceTypeToRemove = .reference
            project.referenceEntries?.removeAll()
            #if DEBUG
            print("✅ Removed all reference entries")
            #endif
        case .index:
            referenceTypeToRemove = .index
            project.indexEntries?.removeAll()
            #if DEBUG
            print("✅ Removed all index entries")
            #endif
        case .tableOfFigures:
            // Table of Figures is generated from images, nothing to remove
            return
        case .contributors:
            // Contributors are not reference-based, nothing to remove
            return
        case .backCover:
            // Back cover is an image file, nothing to remove
            return
        }
        
        // Remove all inline references from all files in the project
        if let refType = referenceTypeToRemove {
            #if DEBUG
            print("🔍 Scanning project files to remove \(refType) references...")
            #endif
            removeReferenceAttachmentsFromProject(project: project, referenceType: refType)
        }
        
        #if DEBUG
        print("✅ Removal complete for \(item.rawValue)")
        #endif
    }
    
    /// Scan all project files and remove reference attachments of the specified type
    private func removeReferenceAttachmentsFromProject(project: Project, referenceType: ReferenceType) {
        func scanFolderForFiles(_ folder: Folder) {
            // Process files in this folder
            if let files = folder.files {
                for textFile in files {
                    removeReferenceAttachmentsFromFile(textFile, referenceType: referenceType)
                }
            }
            
            // Recurse into subfolders
            if let subfolders = folder.folders {
                for subfolder in subfolders {
                    scanFolderForFiles(subfolder)
                }
            }
        }
        
        // Start scanning from project folders
        if let folders = project.folders {
            for folder in folders {
                scanFolderForFiles(folder)
            }
        }
    }
    
    /// Remove reference attachments from a single file
    private func removeReferenceAttachmentsFromFile(_ textFile: TextFile, referenceType: ReferenceType) {
        // Get the current version's content
        guard let versions = textFile.versions, versions.count > textFile.currentVersionIndex else {
            return
        }
        
        let currentVersion = versions[textFile.currentVersionIndex]
        guard let attributedText = currentVersion.attributedContent else {
            return
        }
        
        let mutableText = NSMutableAttributedString(attributedString: attributedText)
        var rangesToRemove: [NSRange] = []
        
        // Find all reference attachments of the specified type
        mutableText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutableText.length), options: .reverse) { value, range, _ in
            if let attachment = value as? ReferenceAttachment, attachment.referenceType == referenceType {
                rangesToRemove.append(range)
            }
        }
        
        // Remove from end to start to preserve ranges
        for range in rangesToRemove {
            mutableText.deleteCharacters(in: range)
        }
        
        // Only update if we removed something
        if !rangesToRemove.isEmpty {
            currentVersion.attributedContent = mutableText
            #if DEBUG
            print("  ✅ Removed \(rangesToRemove.count) \(referenceType) references from: \(textFile.name)")
            #endif
        }
    }
}
