import CloudKit
import Foundation

enum CloudKitInspectorAccountStatus: String, Equatable {
    case available
    case noAccount
    case restricted
    case couldNotDetermine
    case temporarilyUnavailable
    case unknown
}

enum CloudKitZoneClassification: String, Equatable {
    case existingCoreDataZone
    case defaultZone
    case proposedCKSyncEngineZone
    case foreignZone
}

struct CloudKitZoneInventoryItem: Equatable {
    var zoneName: String
    var classification: CloudKitZoneClassification
}

private extension CloudKitZoneClassification {
    var sortOrder: Int {
        switch self {
        case .defaultZone:
            return 0
        case .existingCoreDataZone:
            return 1
        case .proposedCKSyncEngineZone:
            return 2
        case .foreignZone:
            return 3
        }
    }
}

struct SyncInspectorReport: Equatable {
    var accountStatus: CloudKitInspectorAccountStatus
    var zones: [CloudKitZoneInventoryItem]
    var warnings: [String]
    var localDryRunReport: DryRunSyncReport?

    func redactedText() -> String {
        var lines = [
            "CKSyncEngine read-only inspector",
            "Account: \(accountStatus.rawValue)",
            "",
            "Zones:"
        ]

        if zones.isEmpty {
            lines.append("- none")
        } else {
            for zone in zones {
                lines.append("- \(zone.zoneName): \(zone.classification.rawValue)")
            }
        }

        if let localDryRunReport {
            lines.append("")
            lines.append("Local dry-run:")
            for key in localDryRunReport.recordCounts.keys.sorted() {
                lines.append("- \(key): \(localDryRunReport.recordCounts[key] ?? 0)")
            }
        }

        lines.append("")
        lines.append("Warnings:")
        if warnings.isEmpty {
            lines.append("- none")
        } else {
            for warning in warnings.sorted() {
                lines.append("- \(warning)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

protocol ReadOnlyCloudKitClient {
    func accountStatus() async -> CloudKitInspectorAccountStatus
    func privateZoneNames() async throws -> [String]
}

struct SystemReadOnlyCloudKitClient: ReadOnlyCloudKitClient {
    private let container: CKContainer

    init(containerIdentifier: String = "iCloud.com.appworks.writingshedpro") {
        self.container = CKContainer(identifier: containerIdentifier)
    }

    func accountStatus() async -> CloudKitInspectorAccountStatus {
        await withCheckedContinuation { continuation in
            container.accountStatus { status, _ in
                continuation.resume(returning: Self.map(status))
            }
        }
    }

    func privateZoneNames() async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            container.privateCloudDatabase.fetchAllRecordZones { zones, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (zones ?? []).map { $0.zoneID.zoneName })
            }
        }
    }

    private static func map(_ status: CKAccountStatus) -> CloudKitInspectorAccountStatus {
        switch status {
        case .available:
            return .available
        case .noAccount:
            return .noAccount
        case .restricted:
            return .restricted
        case .couldNotDetermine:
            return .couldNotDetermine
        case .temporarilyUnavailable:
            return .temporarilyUnavailable
        @unknown default:
            return .unknown
        }
    }
}

struct CloudKitReadOnlyInspector {
    static let existingCoreDataZoneName = "com.apple.coredata.cloudkit.zone"
    static let defaultZoneName = "_defaultZone"
    static let proposedSyncZoneName = "WritingShedProSyncZone"

    private let client: ReadOnlyCloudKitClient

    init(client: ReadOnlyCloudKitClient = SystemReadOnlyCloudKitClient()) {
        self.client = client
    }

    func inspect(localDryRunReport: DryRunSyncReport? = nil) async -> SyncInspectorReport {
        let accountStatus = await client.accountStatus()
        var warnings: [String] = []

        guard accountStatus == .available else {
            warnings.append("iCloud account is not available; inspector did not attempt zone reads.")
            return SyncInspectorReport(accountStatus: accountStatus, zones: [], warnings: warnings, localDryRunReport: localDryRunReport)
        }

        do {
            let zoneNames = try await client.privateZoneNames()
            let zones = classify(zoneNames: zoneNames)
            if !zoneNames.contains(Self.proposedSyncZoneName) {
                warnings.append("Proposed CKSyncEngine zone is missing; this is expected before shadow sync creates it.")
            }
            if zones.contains(where: { $0.classification == .foreignZone }) {
                warnings.append("Foreign CloudKit zones were found; Phase 1 only reports them and does not delete anything.")
            }
            return SyncInspectorReport(accountStatus: accountStatus, zones: zones, warnings: warnings, localDryRunReport: localDryRunReport)
        } catch {
            warnings.append("Read-only CloudKit zone fetch failed: \(error.localizedDescription)")
            return SyncInspectorReport(accountStatus: accountStatus, zones: [], warnings: warnings, localDryRunReport: localDryRunReport)
        }
    }

    func classify(zoneNames: [String]) -> [CloudKitZoneInventoryItem] {
        zoneNames.map { zoneName in
            CloudKitZoneInventoryItem(zoneName: zoneName, classification: classification(for: zoneName))
        }
        .sorted { lhs, rhs in
            if lhs.classification.sortOrder != rhs.classification.sortOrder {
                return lhs.classification.sortOrder < rhs.classification.sortOrder
            }
            return lhs.zoneName < rhs.zoneName
        }
    }

    private func classification(for zoneName: String) -> CloudKitZoneClassification {
        switch zoneName {
        case Self.existingCoreDataZoneName:
            return .existingCoreDataZone
        case Self.defaultZoneName:
            return .defaultZone
        case Self.proposedSyncZoneName:
            return .proposedCKSyncEngineZone
        default:
            return .foreignZone
        }
    }
}
