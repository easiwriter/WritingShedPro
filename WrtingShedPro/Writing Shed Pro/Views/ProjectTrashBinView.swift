import SwiftUI
import SwiftData

/// ProjectTrashBinView: Shows deleted projects with Put Back and Permanent Delete options.
struct ProjectTrashBinView: View {
    @Query(filter: #Predicate<Project> { $0.isTrashed == true }, sort: \Project.deletedDate, order: .reverse)
    private var trashedProjects: [Project]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProjectIDs: Set<UUID> = []
    @State private var showPutBackConfirmation = false
    @State private var showPermanentDeleteConfirmation = false
    @State private var showDeleteError = false
    @State private var deleteErrorTitle = NSLocalizedString("project.deleteForever.saveFailed.title", comment: "Delete failed")
    @State private var deleteErrorMessage = ""
    @State private var projectsToPutBack: [Project] = []
    @State private var projectsToDelete: [Project] = []

    var body: some View {
        NavigationStack {
            Group {
                if trashedProjects.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "trash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("projectTrash.empty", comment: "No deleted projects"))
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List(selection: $selectedProjectIDs) {
                        ForEach(trashedProjects) { project in
                            HStack {
                                Text(project.name ?? NSLocalizedString("projectItem.untitledProject", comment: "Untitled project"))
                                Spacer()
                                if let deletedDate = project.deletedDate {
                                    Text(deletedDate, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("projectTrash.title", comment: "Deleted Projects"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("button.done", comment: "Done")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !selectedProjectIDs.isEmpty {
                        Button(NSLocalizedString("projectTrash.putBack", comment: "Put Back")) {
                            projectsToPutBack = trashedProjects.filter { selectedProjectIDs.contains($0.id) }
                            showPutBackConfirmation = true
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !selectedProjectIDs.isEmpty {
                        Button(NSLocalizedString("projectTrash.deleteForever", comment: "Delete Forever"), role: .destructive) {
                            projectsToDelete = trashedProjects.filter { selectedProjectIDs.contains($0.id) }
                            showPermanentDeleteConfirmation = true
                        }
                    }
                }
            }
            .alert(NSLocalizedString("projectTrash.putBackConfirm", comment: "Restore selected projects?"), isPresented: $showPutBackConfirmation) {
                Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {}
                Button(NSLocalizedString("projectTrash.putBack", comment: "Put Back")) {
                    for project in projectsToPutBack {
                        DeduplicationService.restoreProjectFamily(project, context: modelContext)
                    }
                    WriteCoalescer.shared?.requestSave(reason: "project-trash-restore")
                    WriteCoalescer.shared?.flush()
                    selectedProjectIDs.removeAll()
                }
            }
            .alert(NSLocalizedString("projectTrash.deleteForeverConfirm", comment: "Permanently delete selected projects?"), isPresented: $showPermanentDeleteConfirmation) {
                Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {}
                Button(NSLocalizedString("projectTrash.deleteForever", comment: "Delete Forever"), role: .destructive) {
                    guard canPermanentlyDeleteFromTrash() else { return }
                    for project in projectsToDelete {
                        DeduplicationService.permanentlyDeleteProjectFamily(project, context: modelContext)
                    }
                    do {
                        try WriteCoalescer.shared.requestSaveAndFlush(reason: "project-trash-bin-delete")
                    } catch {
                        showDeleteSaveError(error)
                        return
                    }
                    selectedProjectIDs.removeAll()
                }
            }
            .alert(deleteErrorTitle, isPresented: $showDeleteError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteErrorMessage)
            }
        }
    }

    private func canPermanentlyDeleteFromTrash() -> Bool {
        let reason = "project-trash-bin-delete"
        guard let ensemblesContainer = Write_App.activeEnsemblesContainer,
              !EnsemblesSaveGate.canSaveNow(reason: reason) else {
            return true
        }

        let error = EnsemblesSaveGateError.syncBusy(
            reason: reason,
            attached: ensemblesContainer.isAttached,
            activity: String(describing: ensemblesContainer.currentActivity)
        )
        showDeleteSaveError(error)
        return false
    }

    private func showDeleteSaveError(_ error: Error) {
        if case EnsemblesSaveGateError.syncBusy = error {
            deleteErrorTitle = NSLocalizedString("projectTrash.deleteDeferred.title", comment: "Delete deferred title")
            deleteErrorMessage = NSLocalizedString("projectTrash.deleteDeferred.message", comment: "Delete deferred message")
            showDeleteError = true
            return
        }

        deleteErrorTitle = NSLocalizedString("project.deleteForever.saveFailed.title", comment: "Delete failed")
        deleteErrorMessage = String(
            format: NSLocalizedString("project.deleteForever.saveFailed.message", comment: "Delete failed message"),
            error.localizedDescription
        )
        showDeleteError = true
    }
}


