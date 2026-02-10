import SwiftUI
import TipKit
import UniformTypeIdentifiers

extension FolderFilesView {
    
    // MARK: - Navigation Modifiers
    
    func applyNavigationModifiers<V: View>(_ content: V) -> some View {
        content
            .navigationTitle(folder.name ?? "Files")
            .navigationBarTitleDisplayMode(.inline)
            // File list toolbar guide tip — placed in safeAreaInset so it doesn't
            // break the navigation title rendering.
            .safeAreaInset(edge: .top, spacing: 0) {
                if TipKitConfiguration.tipsEnabled && !isMatterFolder {
                    if !toolbarTipDismissed {
                        TipView(fileListToolbarTip)
                    } else {
                        TipView(FolderOrganisationTip()) { action in
                            TipActionHandler.handle(action, guideSection: FolderOrganisationTip.guideSection)
                        }
                    }
                }
            }
            // When the toolbar tip is dismissed, donate the event so
            // FolderOrganisationTip becomes eligible to appear.
            .task {
                for await status in fileListToolbarTip.statusUpdates {
                    if case .invalidated = status {
                        toolbarTipDismissed = true
                        FolderOrganisationTip.fileListToolbarTipDismissed.sendDonation()
                    }
                }
            }
            // Use native iOS back button - it's rendered by UIKit and immune to SwiftUI render blocking
            .navigationBarBackButtonHidden(false)
            .navigationDestination(isPresented: $navigateToFile) {
                navigationDestinationContent
            }
            .environment(\.editMode, $editMode)
            .onPopToRoot {
                #if DEBUG
                print("🔙 [FolderFilesView+Modifiers] onPopToRoot received, setting isDismissing = true")
                #endif
                isDismissing = true
                dismiss()
            }
            .toolbar { folderToolbar }
    }
    
    // MARK: - Sheet Modifiers
    
    func applySheetModifiers<V: View>(_ content: V) -> some View {
        content
            .sheet(isPresented: $showMoveDestinationPicker) { moveDestinationSheet }
            .sheet(isPresented: $showSearchView) { searchSheet }
            .sheet(isPresented: $showAddFileSheet) { addFileSheetContent }
            .sheet(isPresented: $showAddFolderSheet) { addFolderSheet }
            .sheet(isPresented: $showSubmissionPicker) { submissionPickerSheet }
            .sheet(isPresented: $showCollectionPicker) { collectionPickerSheet }
            .sheet(isPresented: $showRenamePicker) { renamePickerSheet }
            .sheet(isPresented: $showFolderMoveDestinationPicker) { folderMoveDestinationSheet }
            .sheet(isPresented: $showStatusPicker) { statusPickerSheet }
            .sheet(isPresented: $showFrontMatterSettings) {
                FrontMatterSettingsDialog(folder: folder)
            }
            .sheet(isPresented: $showBackMatterSettings) {
                BackMatterSettingsDialog(folder: folder)
            }
            .upgradePrompt(reason: $upgradePromptReason)
    }
    
    // MARK: - File Import/Export Modifiers
    
    func applyFileModifiers<V: View>(_ content: V) -> some View {
        let document = ExportDocument(
            data: exportData ?? Data(),
            filename: exportFilename,
            contentType: contentTypeForFormat(exportFormat)
        )
        
        return content
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.rtf, UTType("org.openxmlformats.wordprocessingml.document") ?? .data, UTType(filenameExtension: "md") ?? .plainText],
                allowsMultipleSelection: false,
                onCompletion: handleImport
            )
            .fileExporter(
                isPresented: $showExportSaveDialog,
                document: document,
                contentType: contentTypeForFormat(exportFormat),
                defaultFilename: exportFilename,
                onCompletion: handleExportResult
            )
            .onChange(of: showExportSaveDialog) { oldValue, newValue in
                #if DEBUG
                print("📤 showExportSaveDialog changed: \(oldValue) → \(newValue)")
                print("   exportData: \(exportData != nil ? "\(exportData!.count) bytes" : "nil")")
                print("   exportFilename: \(exportFilename)")
                print("   exportFormat: \(exportFormat)")
                #endif
            }
    }
    
    // MARK: - Alert Modifiers
    
    func applyAlertModifiers<V: View>(_ content: V) -> some View {
        content
            .alert("Import Failed", isPresented: $showImportError) {
                Button("OK", role: .cancel) {}
            } message: { Text(importErrorMessage) }
            .alert("Images Not Supported", isPresented: $showImageWarning) {
                Button("Continue Export") { continueExportAfterImageWarning() }
                Button("Cancel", role: .cancel) { }
            } message: { Text(imageWarningMessage) }
    }
    
    // MARK: - Confirmation Dialog Modifiers
    
    func applyDialogModifiers<V: View>(_ content: V) -> some View {
        content
            .confirmationDialog(
                NSLocalizedString("folderFiles.deletePermanently.title", comment: "Delete Permanently"),
                isPresented: $showPermanentDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("folderFiles.deletePermanently.confirm", comment: ""), role: .destructive) { confirmPermanentDelete() }
                Button(NSLocalizedString("button.cancel", comment: ""), role: .cancel) { cancelPermanentDelete() }
            } message: { Text(permanentDeleteMessage) }
            .confirmationDialog(NSLocalizedString("export.dialog.title", comment: ""), isPresented: $showExportMenu) {
                exportMenuButtons
            } message: { Text(exportMenuMessage) }
            .confirmationDialog(NSLocalizedString("export.folder.dialog.title", comment: ""), isPresented: $showExportFolderMenu) {
                exportFolderMenuButtons
            } message: { Text(exportFolderMenuMessage) }
            .sheet(isPresented: $showHeaderFooterEditor) { headerFooterDialog }
            .alert(NSLocalizedString("headerFooter.notEnabled.title", comment: "Headers & Footers Not Enabled"), isPresented: $showHeaderFooterWarning) {
                Button(NSLocalizedString("button.ok", comment: "OK"), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("headerFooter.notEnabled.message", comment: "Enable headers or footers in Page Setup in your project's settings before editing their content."))
            }
    }
}
