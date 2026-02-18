//
//  NotificationReminderService.swift
//  Writing Shed Pro
//
//  Service for scheduling and managing local notification reminders
//  for submission response dates and publication deadlines.
//

import Foundation
import UserNotifications

/// Manages local notification reminders for submissions and publication deadlines.
@Observable
class NotificationReminderService {
    
    static let shared = NotificationReminderService()
    
    /// Whether the user has granted notification permission
    var isAuthorized: Bool = false
    
    private let center = UNUserNotificationCenter.current()
    
    private init() {
        Task { await checkAuthorization() }
    }
    
    // MARK: - Permission
    
    /// Request notification permission from the user
    @discardableResult
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run { isAuthorized = granted }
            return granted
        } catch {
            #if DEBUG
            print("⚠️ [NotificationReminderService] Permission request failed: \(error)")
            #endif
            return false
        }
    }
    
    /// Check current authorization status
    func checkAuthorization() async {
        let settings = await center.notificationSettings()
        let authorized = settings.authorizationStatus == .authorized
        await MainActor.run { isAuthorized = authorized }
    }
    
    // MARK: - Schedule Submission Reminder
    
    /// Schedule a local notification for a submission's expected response date.
    /// - Parameters:
    ///   - submissionId: A string identifier for the submission
    ///   - publicationName: Name of the publication for the notification title
    ///   - submissionName: Name/label of the submission
    ///   - reminderDate: When to fire the notification
    /// - Returns: The notification identifier string
    func scheduleSubmissionReminder(
        submissionId: String,
        publicationName: String,
        submissionName: String,
        reminderDate: Date
    ) async -> String? {
        guard await ensurePermission() else { return nil }
        
        let notificationId = "submission_\(submissionId)"
        
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("reminder.submission.title", comment: "Submission Reminder")
        content.body = String(
            format: NSLocalizedString("reminder.submission.body", comment: "Submission reminder body"),
            submissionName,
            publicationName
        )
        content.sound = .default
        content.categoryIdentifier = "SUBMISSION_REMINDER"
        
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            #if DEBUG
            print("🔔 [NotificationReminderService] Scheduled submission reminder: \(notificationId) for \(reminderDate)")
            #endif
            return notificationId
        } catch {
            #if DEBUG
            print("❌ [NotificationReminderService] Failed to schedule submission reminder: \(error)")
            #endif
            return nil
        }
    }
    
    // MARK: - Schedule Deadline Reminder
    
    /// Schedule a local notification for a publication's deadline.
    /// - Parameters:
    ///   - publicationId: A string identifier for the publication
    ///   - publicationName: Name of the publication
    ///   - reminderDate: When to fire the notification
    /// - Returns: The notification identifier string
    func scheduleDeadlineReminder(
        publicationId: String,
        publicationName: String,
        reminderDate: Date
    ) async -> String? {
        guard await ensurePermission() else { return nil }
        
        let notificationId = "deadline_\(publicationId)"
        
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("reminder.deadline.title", comment: "Deadline Reminder")
        content.body = String(
            format: NSLocalizedString("reminder.deadline.body", comment: "Deadline reminder body"),
            publicationName
        )
        content.sound = .default
        content.categoryIdentifier = "DEADLINE_REMINDER"
        
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            #if DEBUG
            print("🔔 [NotificationReminderService] Scheduled deadline reminder: \(notificationId) for \(reminderDate)")
            #endif
            return notificationId
        } catch {
            #if DEBUG
            print("❌ [NotificationReminderService] Failed to schedule deadline reminder: \(error)")
            #endif
            return nil
        }
    }
    
    // MARK: - Cancel Reminder
    
    /// Cancel a previously scheduled notification
    func cancelReminder(notificationId: String) {
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])
        #if DEBUG
        print("🔕 [NotificationReminderService] Cancelled reminder: \(notificationId)")
        #endif
    }
    
    // MARK: - Private
    
    private func ensurePermission() async -> Bool {
        await checkAuthorization()
        if !isAuthorized {
            return await requestPermission()
        }
        return true
    }
}
