import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SyncDiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var projectCount = 0
    @State private var activeProjectCount = 0
    @State private var trashedProjectCount = 0
    @State private var publicationCount = 0
    @State private var folderCount = 0
    @State private var fileCount = 0
    @State private var versionCount = 0
    @State private var styleSheetCount = 0
    @State private var textStyleCount = 0
    @State private var imageStyleCount = 0
    @State private var poetryFormCount = 0
    @State private var poetryCollectionCount = 0
    @State private var duplicateProjectCount = 0
    @State private var detachedSceneCount = 0
    @State private var tombstoneCount = 0
    @State private var snapshotCopied = false
    @State private var syncStatusMessage = ""
    @State private var showLocalResetConfirmation = false
    @State private var localResetQueued = false
    @State private var lastRefreshed: Date?

    var body: some View {
        NavigationStack {
            Form {
                Section("Sync Backend") {
                    LabeledContent("Backend", value: "Ensembles")
                    LabeledContent("Cloud Container", value: "iCloud.com.appworks.writingshedpro")
                    LabeledContent("Container Active", value: Write_App.activeEnsemblesContainer == nil ? "No" : "Yes")

                    Button {
                        Task { await runManualSync() }
                    } label: {
                        Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(Write_App.activeEnsemblesContainer == nil)

                    Button(role: .destructive) {
                        showLocalResetConfirmation = true
                    } label: {
                        Label("Reset This Device on Next Launch", systemImage: "arrow.clockwise.icloud")
                    }

                    if localResetQueued {
                        Text("Local reset queued. Quit and relaunch this Mac app to back up the local store and re-import from sync.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if !syncStatusMessage.isEmpty {
                        Text(syncStatusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Local Data") {
                    LabeledContent("Projects", value: "\(projectCount)")
                    LabeledContent("Active Projects", value: "\(activeProjectCount)")
                    LabeledContent("Trashed Projects", value: "\(trashedProjectCount)")
                    LabeledContent("Publications", value: "\(publicationCount)")
                    LabeledContent("Folders", value: "\(folderCount)")
                    LabeledContent("Files", value: "\(fileCount)")
                    LabeledContent("Versions", value: "\(versionCount)")
                    LabeledContent("Poetry Collections", value: "\(poetryCollectionCount)")
                }

                Section("Styles") {
                    LabeledContent("Style Sheets", value: "\(styleSheetCount)")
                    LabeledContent("Text Styles", value: "\(textStyleCount)")
                    LabeledContent("Image Styles", value: "\(imageStyleCount)")
                    LabeledContent("Poetry Forms", value: "\(poetryFormCount)")
                }

                Section("Data Health") {
                    LabeledContent("Duplicate Projects", value: "\(duplicateProjectCount)")
                    LabeledContent("Detached Scene Rows", value: "\(detachedSceneCount)")
                    LabeledContent("Zombie Tombstones", value: "\(tombstoneCount)")

                    Button {
                        refreshCounts()
                    } label: {
                        Label("Refresh Checks", systemImage: "arrow.clockwise")
                    }

                    if tombstoneCount > 0 {
                        Button(role: .destructive) {
                            DeduplicationService.clearAllTombstones()
                            refreshCounts()
                        } label: {
                            Label("Clear Tombstones", systemImage: "trash")
                        }
                    }

                    if detachedSceneCount > 0 {
                        Button(role: .destructive) {
                            trashDetachedScenes()
                        } label: {
                            Label("Trash Detached Scene Rows", systemImage: "rectangle.stack.badge.minus")
                        }
                    }

                    if let lastRefreshed {
                        Text("Last refreshed \(lastRefreshed.formatted(date: .omitted, time: .standard))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Support") {
                    Button {
                        copyDiagnosticsSnapshot()
                    } label: {
                        Label(snapshotCopied ? "Snapshot Copied" : "Copy Diagnostics Snapshot", systemImage: snapshotCopied ? "checkmark" : "doc.on.doc")
                    }
                }
            }
            .navigationTitle("Sync & Data Health")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                refreshCounts()
            }
            .confirmationDialog(
                "Reset this device's local sync data?",
                isPresented: $showLocalResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Back Up and Reset on Next Launch", role: .destructive) {
                    UserDefaults.standard.set(true, forKey: Write_App.resetLocalEnsemblesStoreOnNextLaunchKey)
                    localResetQueued = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This only affects this Mac. On next launch the app will back up its local SQLite store and Ensembles event cache, remove the local copies, then re-import from the sync cloud. Do not use this if this Mac has unsynced work that is not on your iOS devices.")
            }
        }
    }

    @MainActor
    private func runManualSync() async {
        guard let container = Write_App.activeEnsemblesContainer else { return }
        syncStatusMessage = "Syncing..."
        Write_App.logToFile("🔄 [Ensembles] Manual sync started from diagnostics (isAttached=\(container.isAttached), activity=\(String(describing: container.currentActivity)))")
        let didSync = await container.sync()
        syncStatusMessage = "Sync completed at \(Date().formatted(date: .omitted, time: .standard)) (didSync=\(didSync))"
        Write_App.logToFile("✅ [Ensembles] Manual sync completed from diagnostics (didSync=\(didSync), isAttached=\(container.isAttached), activity=\(String(describing: container.currentActivity)))")
        refreshCounts()
    }

    @MainActor
    private func refreshCounts() {
        let freshContext = ModelContext(modelContext.container)

        let projects = (try? freshContext.fetch(FetchDescriptor<Project>())) ?? []
        projectCount = projects.count
        activeProjectCount = projects.filter { !$0.isTrashed }.count
        trashedProjectCount = projects.filter(\.isTrashed).count

        publicationCount = fetchCount(Publication.self, in: freshContext)
        folderCount = fetchCount(Folder.self, in: freshContext)
        fileCount = fetchCount(TextFile.self, in: freshContext)
        versionCount = fetchCount(Version.self, in: freshContext)
        styleSheetCount = fetchCount(StyleSheet.self, in: freshContext)
        textStyleCount = fetchCount(TextStyleModel.self, in: freshContext)
        imageStyleCount = fetchCount(ImageStyle.self, in: freshContext)
        poetryFormCount = fetchCount(PoetryFormModel.self, in: freshContext)
        poetryCollectionCount = fetchCount(PoetryCollection.self, in: freshContext)
        duplicateProjectCount = DeduplicationService.countDuplicateProjects(context: freshContext)
        detachedSceneCount = countDetachedScenes(in: freshContext)
        tombstoneCount = DeduplicationService.tombstoneCount
        lastRefreshed = Date()
    }

    @MainActor
    private func trashDetachedScenes() {
        let freshContext = ModelContext(modelContext.container)
        let scenes = detachedScenes(in: freshContext)
        let now = Date()

        for scene in scenes {
            scene.moveToTrash()
            scene.modifiedDate = now
            scene.project?.modifiedDate = now
            scene.textFile?.modifiedDate = now
        }

        do {
            try freshContext.save()
            syncStatusMessage = "Trashed \(scenes.count) detached scene row\(scenes.count == 1 ? "" : "s")."
        } catch {
            syncStatusMessage = "Failed to trash detached scene rows: \(error.localizedDescription)"
        }

        refreshCounts()
    }

    private func countDetachedScenes(in context: ModelContext) -> Int {
        detachedScenes(in: context).count
    }

    private func detachedScenes(in context: ModelContext) -> [StoryScene] {
        let scenes = (try? context.fetch(FetchDescriptor<StoryScene>())) ?? []
        return scenes.filter { scene in
            !scene.isTrashed && scene.textFile != nil && scene.textFile?.parentFolder == nil
        }
    }

    private func fetchCount<T: PersistentModel>(_ type: T.Type, in context: ModelContext) -> Int {
        (try? context.fetchCount(FetchDescriptor<T>())) ?? 0
    }

    private func copyDiagnosticsSnapshot() {
        let snapshot = SupportDiagnosticsSnapshotBuilder.buildSnapshot(modelContext: modelContext)
        #if canImport(UIKit)
        UIPasteboard.general.string = snapshot
        #endif

        snapshotCopied = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            snapshotCopied = false
        }
    }
}
