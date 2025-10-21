import Foundation
import SwiftData
import CloudKit

class CloudKitSyncService {
    private let container: CKContainer
    private let database: CKDatabase
    
    init(containerIdentifier: String? = nil) {
        if let id = containerIdentifier {
            self.container = CKContainer(identifier: id)
        } else {
            self.container = CKContainer.default()
        }
        self.database = container.privateCloudDatabase
    }
    
    // Example: Save a record to CloudKit
    func saveProject(_ project: Project, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        let record = CKRecord(recordType: "Project")
        record["id"] = project.id.uuidString as CKRecordValue
        record["name"] = project.name as CKRecordValue
        record["type"] = project.type.rawValue as CKRecordValue
        record["creationDate"] = project.creationDate as CKRecordValue
        record["details"] = project.details as CKRecordValue?
        database.save(record) { savedRecord, error in
            if let error = error {
                completion(.failure(error))
            } else if let savedRecord = savedRecord {
                completion(.success(savedRecord))
            }
        }
    }
    
    // Example: Fetch all projects from CloudKit
    func fetchProjects(completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        let query = CKQuery(recordType: "Project", predicate: NSPredicate(value: true))
        database.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(records ?? []))
            }
        }
    }
    // Add more sync methods as needed
}
