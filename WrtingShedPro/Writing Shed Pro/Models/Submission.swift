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
    
    @Relationship(deleteRule: .cascade, inverse: \SubmittedFile.submission)
    var submittedFiles: [SubmittedFile]? = []
    
    var submittedDate: Date = Date()
    var notes: String?
    
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
        if acceptedCount == fileCount { return .allAccepted }
        if rejectedCount == fileCount { return .allRejected }
        if acceptedCount > 0 { return .partiallyAccepted }
        return .pending
    }
    
    enum OverallStatus {
        case pending
        case partiallyAccepted
        case allAccepted
        case allRejected
    }
}
