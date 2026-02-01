import SwiftUI
import UniformTypeIdentifiers

extension FolderFilesView {
    
    // MARK: - Navigation Modifiers
    
    func applyNavigationModifiers<V: View>(_ content: V) -> some View {
        content
            .navigationTitle(folder.name ?? "Files")
            .navigationBarTitleDisplayMode(.inline)
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
        content
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.rtf, UTType("org.openxmlformats.wordprocessingml.document") ?? .data, UTType(filenameExtension: "md") ?? .plainText],
                allowsMultipleSelection: false,
                onCompletion: handleImport
            )
            .fileExporter(
                isPresented: $showExportSaveDialog,
                document: ExportDocument(data: exportData ?? Data(), filename: exportFilename, contentType: contentTypeForFormat(exportFormat)),
                contentType: contentTypeForFormat(exportFormat),
                defaultFilename: exportFilename,
                onCompletion: handleExportResult
            )
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
    }
}
