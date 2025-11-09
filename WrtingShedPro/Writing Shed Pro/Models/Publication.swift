//
//  Publication.swift
//  Writing Shed Pro
//
//  Created on 9 November 2025.
//  Feature 008b: Publication Management System
//

import Foundation
import SwiftData

@Model
class Publication {
    var id: UUID = UUID()
    var name: String = ""
    var type: PublicationType = .magazine
    var url: String?
    var notes: String?
    var deadline: Date?
    
    var project: Project?
    @Relationship(deleteRule: .cascade, inverse: \Submission.publication)
    var submissions: [Submission] = []
    
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    
    init(
        id: UUID = UUID(),
        name: String,
        type: PublicationType,
        url: String? = nil,
        notes: String? = nil,
        deadline: Date? = nil,
        project: Project
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.url = url
        self.notes = notes
        self.deadline = deadline
        self.project = project
        self.submissions = []
        self.createdDate = Date()
        self.modifiedDate = Date()
    }
    
    // MARK: - Computed Properties
    
    var hasDeadline: Bool {
        deadline != nil
    }
    
    var daysUntilDeadline: Int? {
        guard let deadline = deadline else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: deadline).day
    }
    
    var isDeadlinePassed: Bool {
        guard let deadline = deadline else { return false }
        return deadline < Date()
    }
    
    var isDeadlineApproaching: Bool {
        guard let days = daysUntilDeadline else { return false }
        return days >= 0 && days < 7
    }
    
    var deadlineStatus: DeadlineStatus {
        guard hasDeadline else { return .none }
        if isDeadlinePassed { return .passed }
        if isDeadlineApproaching { return .approaching }
        return .future
    }
    
    enum DeadlineStatus {
        case none       // No deadline set
        case future     // More than 7 days away
        case approaching // Less than 7 days
        case passed     // Past deadline
    }
}
