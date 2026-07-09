import Foundation

enum SyncFieldValue: Equatable {
    case string(String)
    case int(Int64)
    case bool(Bool)
    case date(Date)
    case bytesCount(Int)
    case null
}

enum SyncMappingSeverity: String, Equatable {
    case info
    case warning
    case error

    var sortOrder: Int {
        switch self {
        case .error: return 0
        case .warning: return 1
        case .info: return 2
        }
    }
}

struct SyncMappingDiagnostic: Equatable {
    var severity: SyncMappingSeverity
    var code: String
    var entityType: String
    var entityID: UUID?
    var fieldName: String?
    var message: String
}

struct SyncAssetPlaceholder: Equatable {
    var entityType: String
    var entityID: UUID
    var fieldName: String
    var byteCount: Int
}

struct SyncRecordEnvelope: Equatable {
    var recordType: String
    var recordName: String
    var fields: [String: SyncFieldValue]
    var assetPlaceholders: [SyncAssetPlaceholder]
    var diagnostics: [SyncMappingDiagnostic]
}

enum SyncDeleteReason: String, Equatable {
    case userDelete
    case projectTrash
    case emptyTrash
    case repair
    case migration
}

struct SyncTombstoneEnvelope: Equatable {
    var recordType: String = "Tombstone"
    var recordName: String
    var entityType: String
    var entityID: UUID
    var deletedDate: Date
    var deletedByDeviceID: String
    var deleteReason: SyncDeleteReason
    var parentEntityType: String?
    var parentEntityID: UUID?

    init(
        entityType: String,
        entityID: UUID,
        deletedDate: Date,
        deletedByDeviceID: String,
        deleteReason: SyncDeleteReason,
        parentEntityType: String? = nil,
        parentEntityID: UUID? = nil
    ) {
        self.recordName = "Tombstone:\(entityType):\(entityID.uuidString)"
        self.entityType = entityType
        self.entityID = entityID
        self.deletedDate = deletedDate
        self.deletedByDeviceID = deletedByDeviceID
        self.deleteReason = deleteReason
        self.parentEntityType = parentEntityType
        self.parentEntityID = parentEntityID
    }

    var fields: [String: SyncFieldValue] {
        var values: [String: SyncFieldValue] = [
            "entityType": .string(entityType),
            "entityID": .string(entityID.uuidString),
            "deletedDate": .date(deletedDate),
            "deletedByDeviceID": .string(deletedByDeviceID),
            "deleteReason": .string(deleteReason.rawValue)
        ]
        values["parentEntityType"] = parentEntityType.map(SyncFieldValue.string) ?? .null
        values["parentEntityID"] = parentEntityID.map { .string($0.uuidString) } ?? .null
        return values
    }
}
