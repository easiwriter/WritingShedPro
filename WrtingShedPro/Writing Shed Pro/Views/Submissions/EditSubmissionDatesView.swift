//
//  EditSubmissionDatesView.swift
//  Writing Shed Pro
//
//  Feature: Edit Submission Dates
//

import SwiftUI
import SwiftData

struct EditSubmissionDatesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var submission: Submission
    
    @State private var submittedDate: Date = Date()
    @State private var hasExpectedDate: Bool = false
    @State private var expectedDate: Date = Date()
    @State private var hasReturnedDate: Bool = false
    @State private var returnedDate: Date = Date()
    @State private var hasReminderDate: Bool = false
    @State private var reminderDate: Date = Date()
    @State private var showReminderPermissionAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        NSLocalizedString("submissions.submitted.label", comment: "Submitted"),
                        selection: $submittedDate,
                        displayedComponents: .date
                    )
                } header: {
                    Text(NSLocalizedString("submissions.editDates.submitted.header", comment: "Submitted Date"))
                }
                
                Section {
                    Toggle(isOn: $hasExpectedDate) {
                        Text(NSLocalizedString("submissions.expectedBy.label", comment: "Expected by"))
                    }
                    if hasExpectedDate {
                        DatePicker(
                            NSLocalizedString("submissions.editDates.expectedDate", comment: "Expected Date"),
                            selection: $expectedDate,
                            displayedComponents: .date
                        )
                    }
                } header: {
                    Text(NSLocalizedString("submissions.editDates.expectedResponse.header", comment: "Expected Response"))
                }
                
                Section {
                    Toggle(isOn: $hasReturnedDate) {
                        Text(NSLocalizedString("submissions.returnedOn.label", comment: "Response Received"))
                    }
                    if hasReturnedDate {
                        DatePicker(
                            NSLocalizedString("submissions.editDates.returnedDate", comment: "Response Date"),
                            selection: $returnedDate,
                            displayedComponents: .date
                        )
                    }
                } header: {
                    Text(NSLocalizedString("submissions.editDates.responseReceived.header", comment: "Response Received"))
                }
                
                Section {
                    Toggle(isOn: $hasReminderDate) {
                        Text(NSLocalizedString("submissions.editDates.reminder", comment: "Reminder"))
                    }
                    if hasReminderDate {
                        DatePicker(
                            NSLocalizedString("submissions.editDates.reminderDate", comment: "Reminder Date"),
                            selection: $reminderDate
                        )
                    }
                } header: {
                    Text(NSLocalizedString("submissions.editDates.reminder.header", comment: "Reminder"))
                }
            }
            .navigationTitle(NSLocalizedString("submissions.editDates.title", comment: "Edit Dates"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.save", comment: "Save")) {
                        Task {
                            await saveDates()
                        }
                    }
                }
            }
            .alert(NSLocalizedString("reminder.permission.title", comment: "Notifications Disabled"), isPresented: $showReminderPermissionAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(NSLocalizedString("reminder.permission.message", comment: "Please enable notifications in Settings"))
            }
            .onAppear {
                loadDates()
            }
        }
    }
    
    private func loadDates() {
        submittedDate = submission.submittedDate
        
        hasExpectedDate = submission.returnExpectedBy != nil
        expectedDate = submission.returnExpectedBy ?? Date()
        
        hasReturnedDate = submission.returnedOn != nil
        returnedDate = submission.returnedOn ?? Date()
        
        hasReminderDate = submission.reminderDate != nil
        reminderDate = submission.reminderDate ?? Date()
    }
    
    @MainActor
    private func saveDates() async {
        submission.submittedDate = submittedDate
        submission.returnExpectedBy = hasExpectedDate ? expectedDate : nil
        submission.returnedOn = hasReturnedDate ? returnedDate : nil

        if hasReminderDate {
            let granted = await NotificationReminderService.shared.requestPermission()
            guard granted else {
                await MainActor.run {
                    showReminderPermissionAlert = true
                }
                return
            }

            if let existingReminderId = submission.reminderNotificationId {
                NotificationReminderService.shared.cancelReminder(notificationId: existingReminderId)
                submission.reminderNotificationId = nil
            }

            let notificationId = await NotificationReminderService.shared.scheduleSubmissionReminder(
                submissionId: submission.id.uuidString,
                publicationName: submission.publication?.name ?? NSLocalizedString("reminder.unknown.publication", comment: "Unknown Publication"),
                submissionName: submission.name ?? NSLocalizedString("submissions.untitled", comment: "Untitled submission"),
                reminderDate: reminderDate
            )

            submission.reminderDate = reminderDate
            submission.reminderNotificationId = notificationId
        } else {
            if let existingReminderId = submission.reminderNotificationId {
                NotificationReminderService.shared.cancelReminder(notificationId: existingReminderId)
                submission.reminderNotificationId = nil
            }
            submission.reminderDate = nil
        }

        submission.modifiedDate = Date()

        do {
            try WriteCoalescer.shared.requestSaveAndFlush(reason: "edit-submission-dates-save")
            dismiss()
        } catch {
            #if DEBUG
            print("[EditSubmissionDatesView] Error saving dates: \(error)")
            #endif
        }
    }
}
