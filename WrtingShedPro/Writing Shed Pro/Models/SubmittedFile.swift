//
//  SubmittedFile.swift
//  Writing Shed Pro
//
//  Created on 9 November 2025.
//  Feature 008b: Publication Management System
//

import Foundation
import SwiftData

@Model
@Syncable
class SubmittedFile {
    var id: UUID = UUID()
    var submission: Submission?
    var textFile: TextFile?
    var version: Version?
    
    var status: SubmissionStatus?
    var statusDate: Date?
    var statusNotes: String?
    
    var project: Project?
    
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    
    init(
        id: UUID = UUID(),
        submission: Submission? = nil,
        textFile: TextFile? = nil,
        version: Version? = nil,
        status: SubmissionStatus = .pending,
        statusDate: Date? = nil,
        statusNotes: String? = nil,
        project: Project? = nil
    ) {
        self.id = id
        self.submission = submission
        self.textFile = textFile
        self.version = version
        self.status = status
        self.statusDate = statusDate
        self.statusNotes = statusNotes
        self.project = project
        self.createdDate = Date()
        self.modifiedDate = Date()
    }
    
    // MARK: - Computed Properties
    
    var acceptanceDate: Date? {
        status == .accepted ? statusDate : nil
    }
    
    var rejectionDate: Date? {
        status == .rejected ? statusDate : nil
    }
    
    var daysSinceSubmission: Int {
        guard let submission = submission else { return 0 }
        let endDate = statusDate ?? Date()
        return Calendar.current.dateComponents(
            [.day],
            from: submission.submittedDate,
            to: endDate
        ).day ?? 0
    }
    
    var responseTime: String {
        let days = daysSinceSubmission
        if days == 0 { return "Today" }
        if days == 1 { return "1 day" }
        if days < 7 { return "\(days) days" }
        let weeks = days / 7
        if weeks == 1 { return "1 week" }
        if days < 30 { return "\(weeks) weeks" }
        let months = days / 30
        if months == 1 { return "1 month" }
        return "\(months) months"
    }
}
