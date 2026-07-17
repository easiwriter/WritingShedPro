import Foundation
import SwiftData
import CryptoKit

/// Builds a compact sync diagnostics snapshot suitable for support emails.
enum SupportDiagnosticsSnapshotBuilder {
    @MainActor
    static func buildSnapshot(modelContext: ModelContext) -> String {
        var lines: [String] = []
        let now = Date()
        lines.append("Sync & Data Health Snapshot")
        lines.append("Generated: \(now.formatted(date: .complete, time: .standard))")
        lines.append("syncBackend: Ensembles")
        lines.append("cloudContainer: iCloud.com.appworks.writingshedpro")
        lines.append("activeEnsemblesContainer: \(Write_App.activeEnsemblesContainer != nil)")

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

        lines.append("")
        lines.append("Project Sync Fingerprints (store)")
        lines.append("- format: id | name | modified | fingerprint")
        for project in storeProjects {
            let modified = project.modifiedDate.map { formatter.string(from: $0) } ?? "nil"
            let fingerprint = stableProjectFingerprint(for: project)
            lines.append("- \(project.id.uuidString) | \(project.name ?? "Untitled") | \(modified) | \(fingerprint)")
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

    private static func stableProjectFingerprint(for project: Project) -> String {
        let folderCount = countFolders(in: project)
        let textFileCount = countTextFiles(in: project)
        let versionCount = countVersions(in: project)
        let submittedFileCount = countSubmittedFiles(in: project)
        let submissionCount = countSubmissions(in: project)

        var parts: [String] = []
        parts.reserveCapacity(32)
        parts.append(project.id.uuidString)
        parts.append(project.name ?? "")
        parts.append(project.typeRaw ?? "")
        parts.append(project.isTrashed ? "1" : "0")
        parts.append(project.creationDate?.timeIntervalSince1970.description ?? "")
        parts.append(project.modifiedDate?.timeIntervalSince1970.description ?? "")
        parts.append(String(project.details?.count ?? 0))
        parts.append(String(project.notes?.count ?? 0))
        parts.append(String(project.author?.count ?? 0))
        parts.append(project.fictionClassRaw ?? "")
        parts.append(project.storyStructureRaw ?? "")
        parts.append(project.dramaScriptTypeRaw ?? "")
        parts.append(String(project.manuscriptSettingsData?.count ?? 0))
        parts.append(String(project.tocSettingsData?.count ?? 0))
        parts.append(String(project.publications?.count ?? 0))
        parts.append(String(project.submissions?.count ?? 0))
        parts.append(String(project.submittedFiles?.count ?? 0))
        parts.append(String(project.poetryCollections?.count ?? 0))
        parts.append(String(project.scenes?.count ?? 0))
        parts.append(String(project.chapters?.count ?? 0))
        parts.append(String(project.acts?.count ?? 0))
        parts.append(String(project.sections?.count ?? 0))
        parts.append(String(project.books?.count ?? 0))
        parts.append(String(project.characters?.count ?? 0))
        parts.append(String(project.locations?.count ?? 0))
        parts.append(String(project.plotElements?.count ?? 0))
        parts.append(String(folderCount))
        parts.append(String(textFileCount))
        parts.append(String(versionCount))
        parts.append(String(submittedFileCount))
        parts.append(String(submissionCount))

        let canonical = parts.joined(separator: "|")

        let digest = SHA256.hash(data: Data(canonical.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
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