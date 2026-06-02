import Foundation
import SwiftData

/// Builds a compact sync diagnostics snapshot suitable for support emails.
enum SupportDiagnosticsSnapshotBuilder {
    @MainActor
    static func buildSnapshot(modelContext: ModelContext) -> String {
        let throttler = CloudKitSyncThrottler.shared
        _ = throttler.hasActiveCloudKitEvent

        var lines: [String] = []
        let now = Date()
        lines.append("CloudKit Diagnostics Snapshot")
        lines.append("Generated: \(now.formatted(date: .complete, time: .standard))")
        lines.append("isSyncing: \(throttler.isSyncing)")
        lines.append("remoteEventsTotal: \(throttler.totalSyncEventCount)")
        lines.append("currentBurstCount: \(throttler.syncEventCount)")
        lines.append("importInProgress: \(throttler.importInProgress)")
        lines.append("exportInProgress: \(throttler.exportInProgress)")
        lines.append("importCompleted: \(throttler.importCompleted)")
        lines.append("importSucceeded: \(throttler.importSucceeded)")
        lines.append("exportCompleted: \(throttler.exportCompleted)")
        lines.append("exportSucceeded: \(throttler.exportSucceeded)")
        lines.append("isRateLimited: \(throttler.isRateLimited)")
        lines.append("consecutiveExportRateLimits: \(throttler.consecutiveExportRateLimits)")
        lines.append("isManualKickPaused: \(throttler.isManualKickPaused)")
        lines.append("consecutiveImportNetworkFailures: \(throttler.consecutiveImportNetworkFailures)")
        lines.append("consecutiveImportFailures: \(throttler.consecutiveImportFailures)")
        lines.append("autoResetScheduled: \(throttler.autoResetScheduled)")
        lines.append("isPostReset: \(throttler.isPostReset)")
        lines.append("lastRemoteEvent: \(throttler.lastSyncTime?.formatted(date: .omitted, time: .standard) ?? "nil")")
        lines.append("lastMirroringEvent: \(throttler.lastMirroringEventTime?.formatted(date: .omitted, time: .standard) ?? "nil")")
        if let importStart = throttler.importStartTime {
            lines.append("importAgeSeconds: \(Int(Date().timeIntervalSince(importStart)))")
        } else {
            lines.append("importAgeSeconds: nil")
        }
        if let exportStart = throttler.exportStartTime {
            lines.append("exportAgeSeconds: \(Int(Date().timeIntervalSince(exportStart)))")
        } else {
            lines.append("exportAgeSeconds: nil")
        }

        lines.append("rateLimitedUntil: \(throttler.rateLimitedUntil?.formatted(date: .omitted, time: .standard) ?? "nil")")
        lines.append("manualKickPausedUntil: \(throttler.manualKickPausedUntil?.formatted(date: .omitted, time: .standard) ?? "nil")")
        lines.append("recentCloudKitEvents:")
        if throttler.recentCloudKitEvents.isEmpty {
            lines.append("- none")
        } else {
            for event in throttler.recentCloudKitEvents.prefix(20) {
                let message = event.message.isEmpty ? "" : " — \(event.message)"
                lines.append("- \(event.timestamp.formatted(date: .omitted, time: .standard)) | \(event.type) | \(event.phase) | \(event.status)\(message)")
            }
        }

        let freshContext = ModelContext(modelContext.container)
        let formatter = ISO8601DateFormatter()

        let storeProjects = ((try? freshContext.fetch(FetchDescriptor<Project>())) ?? [])
            .sorted { lhs, rhs in
                let lhsCreated = lhs.creationDate ?? .distantPast
                let rhsCreated = rhs.creationDate ?? .distantPast
                if lhsCreated != rhsCreated {
                    return lhsCreated < rhsCreated
                }
                return (lhs.name ?? "") < (rhs.name ?? "")
            }

        lines.append("")
        lines.append("Project Inventory")
        lines.append("Source: Fresh ModelContext (store snapshot)")
        for project in storeProjects {
            let created = project.creationDate.map { formatter.string(from: $0) } ?? "nil"
            let modified = project.modifiedDate.map { formatter.string(from: $0) } ?? "nil"
            let deleted = project.deletedDate.map { formatter.string(from: $0) } ?? "nil"
            let folderCount = project.folders?.count ?? 0
            lines.append("- name=\(project.name ?? "Untitled") | id=\(project.id.uuidString) | type=\(project.type.rawValue) | trashed=\(project.isTrashed) | userOrder=\(project.userOrder.map(String.init) ?? "nil") | created=\(created) | modified=\(modified) | deleted=\(deleted) | folders=\(folderCount)")
        }

        lines.append("")
        lines.append("Project Deep Counts (store)")
        lines.append("- format: id | name | folders | textFiles | versions | submittedFiles | submissions | publications | poetryCollections")
        for project in storeProjects {
            let folderCount = countFolders(in: project)
            let textFileCount = countTextFiles(in: project)
            let versionCount = countVersions(in: project)
            let submittedFileCount = countSubmittedFiles(in: project)
            let submissionCount = countSubmissions(in: project)
            let publicationCount = project.publications?.count ?? 0
            let poetryCollectionCount = project.poetryCollections?.count ?? 0

            lines.append("- \(project.id.uuidString) | \(project.name ?? "Untitled") | \(folderCount) | \(textFileCount) | \(versionCount) | \(submittedFileCount) | \(submissionCount) | \(publicationCount) | \(poetryCollectionCount)")
        }

        let storePublications = (try? freshContext.fetch(FetchDescriptor<Publication>())) ?? []
        lines.append("")
        lines.append("Publication Inventory")
        lines.append("Source: Fresh ModelContext (store snapshot)")
        lines.append("- count=\(storePublications.count)")

        lines.append("")
        lines.append("Entity Counts (store):")
        lines.append("- Project: \((try? freshContext.fetchCount(FetchDescriptor<Project>())) ?? -1)")
        lines.append("- Publication: \((try? freshContext.fetchCount(FetchDescriptor<Publication>())) ?? -1)")
        lines.append("- Folder: \((try? freshContext.fetchCount(FetchDescriptor<Folder>())) ?? -1)")
        lines.append("- TextFile: \((try? freshContext.fetchCount(FetchDescriptor<TextFile>())) ?? -1)")
        lines.append("- Version: \((try? freshContext.fetchCount(FetchDescriptor<Version>())) ?? -1)")
        lines.append("- PoetryCollection: \((try? freshContext.fetchCount(FetchDescriptor<PoetryCollection>())) ?? -1)")

        let tombstones = DeduplicationService.tombstoneDescriptions()
        lines.append("")
        lines.append("Zombie Tombstones: \(tombstones.count)")
        for tombstone in tombstones {
            lines.append("- \(tombstone.name) | type=\(tombstone.type) | deleted=\(tombstone.deletedAt.formatted(date: .abbreviated, time: .shortened))")
        }

        return lines.joined(separator: "\n")
    }

    private static func countFolders(in project: Project) -> Int {
        var count = 0
        for folder in project.folders ?? [] {
            count += countFolderTree(folder)
        }
        return count
    }

    private static func countTextFiles(in project: Project) -> Int {
        var count = 0
        for folder in project.folders ?? [] {
            count += countTextFilesInFolderTree(folder)
        }
        return count
    }

    private static func countVersions(in project: Project) -> Int {
        var count = 0
        for folder in project.folders ?? [] {
            count += countVersionsInFolderTree(folder)
        }
        return count
    }

    private static func countSubmittedFiles(in project: Project) -> Int {
        let publications = project.publications ?? []
        var count = 0
        for publication in publications {
            for submission in publication.submissions ?? [] {
                count += submission.submittedFiles?.count ?? 0
            }
        }
        return count
    }

    private static func countSubmissions(in project: Project) -> Int {
        let publications = project.publications ?? []
        var count = 0
        for publication in publications {
            count += publication.submissions?.count ?? 0
        }
        return count
    }

    private static func countFolderTree(_ folder: Folder) -> Int {
        var count = 1
        for child in folder.folders ?? [] {
            count += countFolderTree(child)
        }
        return count
    }

    private static func countTextFilesInFolderTree(_ folder: Folder) -> Int {
        var count = folder.textFiles?.count ?? 0
        for child in folder.folders ?? [] {
            count += countTextFilesInFolderTree(child)
        }
        return count
    }

    private static func countVersionsInFolderTree(_ folder: Folder) -> Int {
        var count = 0
        for file in folder.textFiles ?? [] {
            count += file.versions?.count ?? 0
        }
        for child in folder.folders ?? [] {
            count += countVersionsInFolderTree(child)
        }
        return count
    }
}