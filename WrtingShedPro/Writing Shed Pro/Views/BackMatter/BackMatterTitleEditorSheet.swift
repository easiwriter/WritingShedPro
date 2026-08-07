//
//  BackMatterTitleEditorSheet.swift
//  Writing Shed Pro
//
//  Editor sheet for configuring back matter section title text and heading style
//

import SwiftUI
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
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.save", comment: "Save")) {
                        saveSettings()
                    }
                }
            }
            .onAppear {
                loadSettings()
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
        guard let folder = folder else {
            dismissSheet()
            return
        }
        var settings = folder.backMatterSettings
        let config = BackMatterItemTitle(
            customTitle: titleText.isEmpty ? nil : titleText,
            headingStyle: headingStyle
        )
        settings.setTitleConfig(config, for: item)
        folder.backMatterSettings = settings
        onSave()
        dismissSheet()
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
