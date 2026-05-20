//
//  Submission.swift
//  Writing Shed Pro
//
//  Created on 9 November 2025.
//  Feature 008b: Publication Management System
//

import Foundation
import SwiftData

@Model
class Submission {
    var id: UUID = UUID()
    var publication: Publication?
    var project: Project?
    
    // Feature 008c: Collections support
    var name: String?  // For collections (when publication is nil)
    var collectionDescription: String?  // For collections
    
    // Flag to distinguish collections from submissions (needed for SwiftData predicates)
    // SwiftData predicates cannot reliably check optional relationships like publication == nil
    var isCollection: Bool = false
    
    @Relationship(deleteRule: .cascade, inverse: \SubmittedFile.submission)
    var submittedFiles: [SubmittedFile]? = []
    
    var submittedDate: Date = Date()
    var returnExpectedBy: Date?  // When response is expected
    var returnedOn: Date?  // When response was actually received
    var notes: String?
    
    /// Typical number of days the publication takes to respond (copied from publication at submission time)
    var typicalResponseDays: Int?
    
    /// Optional reminder: the date/time to fire a local notification
    var reminderDate: Date?
    /// The local notification identifier, used to cancel/update the notification
    var reminderNotificationId: String?
    
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    
    // User-defined sort order for collections
    var userOrder: Int?
    
    init(
        id: UUID = UUID(),
        publication: Publication? = nil,
        project: Project? = nil,
        submittedDate: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.publication = publication
        self.project = project
        self.submittedDate = submittedDate
        self.notes = notes
        self.submittedFiles = []
        self.createdDate = Date()
        self.modifiedDate = Date()
    }
    
    // MARK: - Computed Properties
    
    var fileCount: Int {
        submittedFiles?.count ?? 0
    }
    
    var pendingCount: Int {
        submittedFiles?.filter { $0.status == .pending }.count ?? 0
    }
    
    var acceptedCount: Int {
        submittedFiles?.filter { $0.status == .accepted }.count ?? 0
    }
    
    var rejectedCount: Int {
        submittedFiles?.filter { $0.status == .rejected }.count ?? 0
    }
    
    var overallStatus: OverallStatus {
        let files = submittedFiles ?? []
        guard !files.isEmpty else { return .pending }
        var accepted = 0
        var rejected = 0
        for f in files {
            switch f.status {
            case .accepted: accepted += 1
            case .rejected: rejected += 1
            default: break
            }
        }
        let total = files.count
        if accepted == total { return .allAccepted }
        if rejected == total { return .allRejected }
        if accepted > 0 { return .partiallyAccepted }
        return .pending
    }
    
    enum OverallStatus {
        case pending
        case partiallyAccepted
        case allAccepted
        case allRejected
    }
}
