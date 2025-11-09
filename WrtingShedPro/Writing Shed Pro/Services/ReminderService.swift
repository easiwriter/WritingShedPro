//
//  ReminderService.swift
//  Writing Shed Pro
//
//  Created on 9 November 2025.
//  Feature 008b: Publication Management System
//

import Foundation
import EventKit

/// Service for creating iOS Reminders for submission follow-ups and deadlines
class ReminderService {
    private let eventStore = EKEventStore()
    
    // MARK: - Permission Handling
    
    /// Request access to Reminders
    func requestAccess() async throws -> Bool {
        return try await eventStore.requestAccess(to: .reminder)
    }
    
    // MARK: - Submission Reminders
    
    /// Create reminder for submission follow-up
    /// - Parameters:
    ///   - submission: The submission to create reminder for
    ///   - daysAfterSubmission: Number of days after submission date
    ///   - notes: Optional custom notes
    /// - Returns: The created reminder
    func createSubmissionReminder(
        for submission: Submission,
        daysAfterSubmission: Int,
        notes: String? = nil
    ) async throws -> EKReminder {
        // Verify permission
        guard try await requestAccess() else {
            throw ReminderError.permissionDenied
        }
        
        // Create reminder
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = "Follow up: \(submission.publication.name)"
        reminder.notes = notes ?? "Check on submission status"
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        
        // Calculate due date
        let dueDate = Calendar.current.date(
            byAdding: .day,
            value: daysAfterSubmission,
            to: submission.submittedDate
        ) ?? Date()
        
        reminder.dueDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: dueDate
        )
        
        // Save reminder
        try eventStore.save(reminder, commit: true)
        return reminder
    }
    
    // MARK: - Deadline Reminders
    
    /// Create reminder for publication deadline
    /// - Parameters:
    ///   - publication: The publication with deadline
    ///   - daysBefore: Number of days before deadline (0 = on deadline date)
    ///   - notes: Optional custom notes
    /// - Returns: The created reminder
    func createDeadlineReminder(
        for publication: Publication,
        daysBefore: Int,
        notes: String? = nil
    ) async throws -> EKReminder {
        guard let deadline = publication.deadline else {
            throw ReminderError.noDeadline
        }
        
        // Verify permission
        guard try await requestAccess() else {
            throw ReminderError.permissionDenied
        }
        
        // Create reminder
        let reminder = EKReminder(eventStore: eventStore)
        
        if daysBefore == 0 {
            reminder.title = "Deadline Today: \(publication.name)"
            reminder.notes = notes ?? "Submission deadline is today"
        } else {
            reminder.title = "Deadline: \(publication.name)"
            reminder.notes = notes ?? "Submission deadline in \(daysBefore) days"
        }
        
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        
        // Calculate reminder date
        let reminderDate = Calendar.current.date(
            byAdding: .day,
            value: -daysBefore,
            to: deadline
        ) ?? Date()
        
        reminder.dueDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        
        // Save reminder
        try eventStore.save(reminder, commit: true)
        return reminder
    }
}

// MARK: - Errors

enum ReminderError: LocalizedError {
    case permissionDenied
    case noDeadline
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Permission to access Reminders was denied. Please enable in Settings."
        case .noDeadline:
            return "This publication has no deadline set."
        }
    }
}
