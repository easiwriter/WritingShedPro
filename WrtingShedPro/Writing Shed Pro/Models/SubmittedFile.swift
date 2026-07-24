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
class SubmittedFile {
    var id: UUID = UUID()
    var submission: Submission?
    var textFile: TextFile?
    var version: Version?
    
    var statusRaw: String = SubmissionStatus.pending.rawValue
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
        self.statusRaw = status.rawValue
        self.statusDate = statusDate
        self.statusNotes = statusNotes
        self.project = project
        self.createdDate = Date()
        self.modifiedDate = Date()
        linkInverseRelationships()
    }

    private func linkInverseRelationships() {
        if let submission {
            if submission.submittedFiles == nil {
                submission.submittedFiles = []
            }
            if submission.submittedFiles?.contains(where: { $0.id == id }) != true {
                submission.submittedFiles?.append(self)
            }
        }

        if let textFile {
            if textFile.submittedFiles == nil {
                textFile.submittedFiles = []
            }
            if textFile.submittedFiles?.contains(where: { $0.id == id }) != true {
                textFile.submittedFiles?.append(self)
            }
        }

        if let version {
            if version.submittedFiles == nil {
                version.submittedFiles = []
            }
            if version.submittedFiles?.contains(where: { $0.id == id }) != true {
                version.submittedFiles?.append(self)
            }
        }

        if let project {
            if project.submittedFiles == nil {
                project.submittedFiles = []
            }
            if project.submittedFiles?.contains(where: { $0.id == id }) != true {
                project.submittedFiles?.append(self)
            }
        }
    }
    
    // MARK: - Computed Properties

    var submissionStatus: SubmissionStatus? {
        get { SubmissionStatus(rawValue: normalizedStatusRawValue(statusRaw)) }
        set { statusRaw = newValue?.rawValue ?? SubmissionStatus.pending.rawValue }
    }

    private func normalizedStatusRawValue(_ rawValue: String) -> String {
        if SubmissionStatus(rawValue: rawValue) != nil {
            return rawValue
        }
        if rawValue.contains("accepted") {
            return SubmissionStatus.accepted.rawValue
        }
        if rawValue.contains("rejected") {
            return SubmissionStatus.rejected.rawValue
        }
        return SubmissionStatus.pending.rawValue
    }
    
    var acceptanceDate: Date? {
        submissionStatus == .accepted ? statusDate : nil
    }
    
    var rejectionDate: Date? {
        submissionStatus == .rejected ? statusDate : nil
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
