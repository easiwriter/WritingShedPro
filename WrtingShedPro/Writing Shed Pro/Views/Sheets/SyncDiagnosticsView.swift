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
    @State private var tombstoneCount = 0
    @State private var snapshotCopied = false
    @State private var syncStatusMessage = ""
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
        }
    }

    @MainActor
    private func runManualSync() async {
        guard let container = Write_App.activeEnsemblesContainer else { return }
        syncStatusMessage = "Syncing..."
        await container.sync()
        syncStatusMessage = "Sync completed at \(Date().formatted(date: .omitted, time: .standard))"
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
        tombstoneCount = DeduplicationService.tombstoneCount
        lastRefreshed = Date()
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
