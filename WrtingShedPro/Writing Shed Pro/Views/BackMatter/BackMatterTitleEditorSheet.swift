//
//  BackMatterTitleEditorSheet.swift
//  Writing Shed Pro
//
//  Editor sheet for configuring back matter section title text and heading style
//

import SwiftUI
import SwiftData
#if targetEnvironment(macCatalyst)
import UIKit
#endif

/// Sheet for editing a back matter section's title text and heading style
struct BackMatterTitleEditorSheet: View {
    let item: BackMatterItem
    let folder: Folder?
    @Binding var isPresented: Bool
    var onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var titleText: String = ""
    @State private var headingStyle: BackMatterHeadingStyle = .title1
    @State private var isSaving = false
    @State private var saveErrorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(item.localizedName, text: $titleText)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text(NSLocalizedString("backMatter.titleEditor.titleField", comment: "Section Title"))
                } footer: {
                    Text(String(format: NSLocalizedString("backMatter.titleEditor.titleFooter", comment: "Leave empty to use the default: %@"), item.localizedName))
                }
                
                Section {
                    Picker(NSLocalizedString("backMatter.titleEditor.headingStyle", comment: "Heading Style"), selection: $headingStyle) {
                        ForEach(BackMatterHeadingStyle.allCases) { style in
                            Text(style.localizedName)
                                .tag(style)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text(NSLocalizedString("backMatter.titleEditor.styleSection", comment: "Style"))
                }
                
                // Preview
                Section {
                    let previewTitle = titleText.isEmpty ? item.localizedName : titleText
                    Text(previewTitle)
                        .font(Font(UIFont.preferredFont(forTextStyle: headingStyle.textStyle)))
                        .fontWeight(headingStyle == .headline ? .bold : .regular)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } header: {
                    Text(NSLocalizedString("backMatter.titleEditor.preview", comment: "Preview"))
                }
            }
            .formStyle(.grouped)
            .navigationTitle(NSLocalizedString("backMatter.titleEditor.title", comment: "Section Title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
            .alert(NSLocalizedString("matter.settings.saveFailed.title", comment: "Save Failed"), isPresented: Binding(
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
    
    private func loadSettings() {
        guard let folder = folder else { return }
        let config = folder.backMatterSettings.titleConfig(for: item)
        titleText = config.customTitle ?? ""
        headingStyle = config.headingStyle
    }
    
    private func saveSettings() {
        guard !isSaving else { return }
        guard let folder, let persistenceContext = folder.modelContext else {
            saveErrorMessage = NSLocalizedString(
                "matter.settings.saveFailed.verification",
                comment: "Matter settings could not be verified after saving"
            )
            return
        }

        let config = BackMatterItemTitle(
            customTitle: titleText.isEmpty ? nil : titleText,
            headingStyle: headingStyle
        )
        isSaving = true

        Task { @MainActor in
            let reason = "back-matter-title-save"
            while true {
                while !EnsemblesSaveGate.canSaveNow(reason: reason) {
                    do {
                        try await Task.sleep(nanoseconds: 500_000_000)
                    } catch {
                        isSaving = false
                        return
                    }
                }

                var settings = folder.backMatterSettings
                settings.setTitleConfig(config, for: item)
                folder.backMatterSettings = settings

                do {
                    try EnsemblesSaveGate.save(persistenceContext, reason: reason)
                    guard titleConfigWasPersisted(config, folder: folder, context: persistenceContext) else {
                        throw BackMatterTitleSaveError.verificationFailed
                    }
                    Write_App.scheduleEnsemblesSyncAfterLocalSave(reason: reason)
                    onSave()
                    isSaving = false
                    dismissSheet()
                    return
                } catch is EnsemblesSaveGateError {
                    continue
                } catch {
                    isSaving = false
                    saveErrorMessage = error.localizedDescription
                    return
                }
            }
        }
    }

    private func titleConfigWasPersisted(
        _ expectedConfig: BackMatterItemTitle,
        folder: Folder,
        context: ModelContext
    ) -> Bool {
        let verificationContext = ModelContext(context.container)
        let folderID = folder.id
        let descriptor = FetchDescriptor<Folder>(
            predicate: #Predicate<Folder> { candidate in candidate.id == folderID }
        )
        guard let savedFolder = try? verificationContext.fetch(descriptor).first else { return false }
        return savedFolder.backMatterSettings.titleConfig(for: item) == expectedConfig
    }

    private func dismissSheet() {
        isPresented = false
        dismiss()

        #if targetEnvironment(macCatalyst)
        DispatchQueue.main.async {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow }?
                .rootViewController?
                .presentedViewController?
                .dismiss(animated: true)
        }
        #endif
    }
}

private enum BackMatterTitleSaveError: LocalizedError {
    case verificationFailed

    var errorDescription: String? {
        NSLocalizedString(
            "matter.settings.saveFailed.verification",
            comment: "Matter settings could not be verified after saving"
        )
    }
}
