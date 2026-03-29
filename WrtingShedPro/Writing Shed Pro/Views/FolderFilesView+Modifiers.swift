import SwiftUI
import UniformTypeIdentifiers

extension FolderFilesView {
    
    // MARK: - Navigation Modifiers
    
    func applyNavigationModifiers<V: View>(_ content: V) -> some View {
        content
            .navigationTitle(folder.name ?? "Files")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $navigateToFile) {
                navigationDestinationContent
            }
            .environment(\.editMode, $editMode)
            .toolbar { folderToolbar }
    }
    
    // MARK: - Sheet Modifiers
    
    func applySheetModifiers<V: View>(_ content: V) -> some View {
        content
            .sheet(isPresented: $showMoveDestinationPicker) { moveDestinationSheet }
            .sheet(isPresented: $showSearchView) { searchSheet }
            .sheet(isPresented: $showAddFileSheet) { addFileSheetContent }
            .sheet(isPresented: $showAddFolderSheet) { addFolderSheet }
            .sheet(isPresented: $showRenamePicker) { renamePickerSheet }
            .sheet(isPresented: $showFolderMoveDestinationPicker) { folderMoveDestinationSheet }
            .sheet(isPresented: $showStatusPicker) { statusPickerSheet }
            .sheet(isPresented: $showCollectionPicker) { collectionPickerSheet }
            .sheet(isPresented: $showFrontMatterSettings) {
                FrontMatterSettingsDialog(folder: folder)
            }
            .sheet(isPresented: $showBackMatterSettings) {
                BackMatterSettingsDialog(folder: folder)
            }
            .sheet(item: $containerAssignmentFiles) { item in
                if let project = folder.resolvedProject, project.type == .poetry {
                    ContainerAssignmentView.forPoetryCollections(
                        project: project,
                        selectedFiles: item.files,
                        modelContext: modelContext
                    )
                }
            }
            .sheet(isPresented: $showCopyToProject) {
                copyToProjectSheet
            }
            .alert(
                copyResultIsError
                    ? NSLocalizedString("copyToProject.error.title", comment: "Copy Failed")
                    : NSLocalizedString("copyToProject.success.title", comment: "Files Copied"),
                isPresented: $showCopyResult
            ) {
                Button(NSLocalizedString("button.ok", comment: "OK")) { }
            } message: {
                Text(copyResultMessage)
            }
            .upgradePrompt(reason: $upgradePromptReason)
    }
    
    // MARK: - File Import/Export Modifiers
    
    /// Cached UTTypes for file importer to avoid repeated lookups on every body evaluation
    private static let _importContentTypes: [UTType] = [
        .rtf,
        UTType("org.openxmlformats.wordprocessingml.document") ?? .data,
        UTType(filenameExtension: "md") ?? .plainText
    ]
    
    func applyFileModifiers<V: View>(_ content: V) -> some View {
        let document = ExportDocument(
            data: exportData ?? Data(),
            filename: exportFilename,
            contentType: contentTypeForFormat(exportFormat)
        )
        
        return content
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: Self._importContentTypes,
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

            .sheet(isPresented: $showSubmissionNamePrompt) {
                if let project = folder.project {
                    SubmissionNameSheet(
                        project: project,
                        filesToSubmit: filesToSubmit,
                        onCreateNew: { name in
                            createSubmissionFromFiles(name: name)
                        },
                        onSelectExisting: { submission in
                            addFilesToExistingSubmission(submission)
                        }
                    )
                }
            }
            .alert(NSLocalizedString("submissions.created.title", comment: "Submission Created"), isPresented: $showSubmissionCreated) {
                Button(NSLocalizedString("button.ok", comment: "OK")) { }
            } message: {
                Text(String(format: NSLocalizedString("submissions.created.message", comment: "Created message"), createdSubmissionName))
            }
            .alert(NSLocalizedString("submissions.duplicate.title", comment: "Duplicate Submission"), isPresented: $showDuplicateSubmission) {
                Button(NSLocalizedString("button.ok", comment: "OK")) { }
            } message: {
                Text(String(format: NSLocalizedString("submissions.duplicate.message", comment: "Duplicate message"), createdSubmissionName))
            }
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
            .alert(NSLocalizedString("export.imageWarning.title", comment: "Images Not Included"), isPresented: $showExportImageWarning) {
                Button(NSLocalizedString("export.imageWarning.continue", comment: "Continue")) {
                    pendingExportAction?()
                    pendingExportAction = nil
                }
                Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                    pendingExportAction = nil
                }
            } message: {
                Text(NSLocalizedString("export.imageWarning.message", comment: "Images will not be included in this export format. Use PDF or Word (.docx) to include images."))
            }
            .sheet(isPresented: $showHeaderFooterEditor) { headerFooterDialog }
            .alert(NSLocalizedString("headerFooter.notEnabled.title", comment: "Headers & Footers Not Enabled"), isPresented: $showHeaderFooterWarning) {
                Button(NSLocalizedString("button.ok", comment: "OK"), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("headerFooter.notEnabled.message", comment: "Enable headers or footers in Page Setup in your project's settings before editing their content."))
            }
    }
}
