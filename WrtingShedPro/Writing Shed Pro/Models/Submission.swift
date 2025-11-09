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
    var id: UUID
    var publication: Publication
    var project: Project
    
    var submittedFiles: [SubmittedFile]
    
    var submittedDate: Date
    var notes: String?
    
    var createdDate: Date
    var modifiedDate: Date
    
    init(
        id: UUID = UUID(),
        publication: Publication,
        project: Project,
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
        submittedFiles.count
    }
    
    var pendingCount: Int {
        submittedFiles.filter { $0.status == .pending }.count
    }
    
    var acceptedCount: Int {
        submittedFiles.filter { $0.status == .accepted }.count
    }
    
    var rejectedCount: Int {
        submittedFiles.filter { $0.status == .rejected }.count
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
