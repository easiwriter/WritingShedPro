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
    
    @Bindable var submission: Submission
    
    @State private var submittedDate: Date = Date()
    @State private var hasExpectedDate: Bool = false
    @State private var expectedDate: Date = Date()
    @State private var hasReturnedDate: Bool = false
    @State private var returnedDate: Date = Date()
    @State private var hasReminderDate: Bool = false
    @State private var reminderDate: Date = Date()
    
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
                        saveDates()
                        dismiss()
                    }
                }
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
    
    private func saveDates() {
        submission.submittedDate = submittedDate
        submission.returnExpectedBy = hasExpectedDate ? expectedDate : nil
        submission.returnedOn = hasReturnedDate ? returnedDate : nil
        submission.reminderDate = hasReminderDate ? reminderDate : nil
        submission.modifiedDate = Date()
    }
}
