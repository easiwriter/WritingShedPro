//
//  PublicationDetailView.swift
//  Writing Shed Pro
//
//  Feature 008b Phase 2: Publications Management UI
//

import SwiftUI
import SwiftData

struct PublicationDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var publication: Publication
    
    @State private var showingEditSheet = false
    @State private var showingAddSubmissionSheet = false
    @State private var showReminderPicker = false
    @State private var reminderDate = Date()
    @State private var showReminderPermissionAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                // Info section
                Section {
                    LabeledContent("publications.form.name.label") {
                        Text(publication.name)
                    }
                    
                    LabeledContent("publications.form.type.label") {
                        HStack {
                            if let type = publication.type {
                                Text(type.icon)
                                Text(type.displayName)
                            }
                        }
                    }
                    
                    if let url = publication.url, let urlObject = URL(string: url) {
                        LabeledContent("publications.form.url.label") {
                            Link(url, destination: urlObject)
                                .lineLimit(1)
                        }
                    }
                    
                    if let days = publication.typicalResponseDays {
                        LabeledContent(NSLocalizedString("publications.form.responseTime.label", comment: "Expected Response Time")) {
                            Text(String(format: NSLocalizedString("publications.responseTime.days", comment: "N days"), days))
                        }
                    }
                }
                
                // Deadline section
                if publication.hasDeadline {
                    Section {
                        LabeledContent("publications.form.deadline.label") {
                            VStack(alignment: .trailing, spacing: 4) {
                                if let deadline = publication.deadline {
                                    Text(deadline, style: .date)
                                }
                                
                                HStack(spacing: 4) {
                                    Image(systemName: deadlineIcon)
                                        .font(.caption)
                                    Text(deadlineText)
                                        .font(.caption)
                                }
                                .foregroundStyle(deadlineColor)
                            }
                        }
                    }
                }
                
                // Reminder section (only when deadline exists)
                if publication.hasDeadline {
                    Section {
                        if let existingReminder = publication.reminderDate {
                            LabeledContent(NSLocalizedString("reminder.scheduled.label", comment: "Reminder")) {
                                Text(existingReminder, style: .date)
                            }
                            
                            Button {
                                reminderDate = existingReminder
                                showReminderPicker = true
                            } label: {
                                Label(NSLocalizedString("reminder.change", comment: "Change Reminder"), systemImage: "bell.badge")
                            }
                            
                            Button(role: .destructive) {
                                cancelDeadlineReminder()
                            } label: {
                                Label(NSLocalizedString("reminder.remove", comment: "Remove Reminder"), systemImage: "bell.slash")
                            }
                        } else if showReminderPicker {
                            DatePicker(
                                NSLocalizedString("reminder.date.label", comment: "Reminder Date"),
                                selection: $reminderDate,
                                in: Date()...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            
                            HStack {
                                Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                                    showReminderPicker = false
                                }
                                Spacer()
                                Button(NSLocalizedString("reminder.save", comment: "Save Reminder")) {
                                    scheduleDeadlineReminder()
                                }
                                .fontWeight(.semibold)
                            }
                        } else {
                            Button {
                                if let deadline = publication.deadline {
                                    // Default to 1 day before deadline at 9am
                                    let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: deadline) ?? deadline
                                    reminderDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: dayBefore) ?? dayBefore
                                }
                                showReminderPicker = true
                            } label: {
                                Label(NSLocalizedString("reminder.set", comment: "Set Reminder"), systemImage: "bell")
                            }
                        }
                    } header: {
                        Text(NSLocalizedString("reminder.section.title", comment: "Reminder"))
                    }
                }
                
                // Notes section
                if let notes = publication.notes, !notes.isEmpty {
                    Section {
                        NavigationLink(destination: PublicationNotesView(publication: publication)) {
                            Text(notes)
                                .lineLimit(3)
                                .foregroundStyle(.primary)
                        }
                    } header: {
                        Text("publications.form.notes.label")
                    }
                }
                
                // Submissions section
                Section {
                    let sortedSubs: [Submission] = (publication.submissions ?? []).sorted(by: { (a: Submission, b: Submission) -> Bool in a.submittedDate > b.submittedDate })
                    if !sortedSubs.isEmpty {
                        ForEach(sortedSubs) { submission in
                            NavigationLink(destination: SubmissionDetailView(submission: submission)) {
                                SubmissionRowView(submission: submission)
                            }
                        }
                    } else {
                        Text("publications.submissions.none")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    HStack {
                        Text("publications.submissions.title")
                        Spacer()
                        Button(action: { showingAddSubmissionSheet = true }) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .accessibilityLabel(Text("accessibility.add.submission"))
                        .accessibilityHint(Text("accessibility.add.submission.hint"))
                    }
                }
            }
            .navigationTitle("publications.detail.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("publications.button.edit") {
                        showingEditSheet = true
                    }
                    .accessibilityLabel(Text("accessibility.edit.publication"))
                    .accessibilityHint(Text(NSLocalizedString("accessibility.edit.publication.hint", comment: "Edit hint")))
                }
            }
            .alert(NSLocalizedString("reminder.permission.title", comment: "Notifications Disabled"), isPresented: $showReminderPermissionAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(NSLocalizedString("reminder.permission.message", comment: "Please enable notifications in Settings"))
            }
            .sheet(isPresented: $showingEditSheet) {
                if let project = publication.project {
                    PublicationFormView(project: project, publication: publication)
                }
            }
            .sheet(isPresented: $showingAddSubmissionSheet) {
                if let project = publication.project {
                    AddSubmissionView(publication: publication, project: project)
                }
            }
        }
    }
    
    // MARK: - Reminders
    
    private func scheduleDeadlineReminder() {
        Task {
            let granted = await NotificationReminderService.shared.requestPermission()
            guard granted else {
                await MainActor.run {
                    showReminderPermissionAlert = true
                    showReminderPicker = false
                }
                return
            }
            
            let notificationId = await NotificationReminderService.shared.scheduleDeadlineReminder(
                publicationId: publication.persistentModelID.hashValue.description,
                publicationName: publication.name,
                reminderDate: reminderDate
            )
            
            await MainActor.run {
                publication.reminderDate = reminderDate
                publication.reminderNotificationId = notificationId
                showReminderPicker = false
            }
        }
    }
    
    private func cancelDeadlineReminder() {
        if let notificationId = publication.reminderNotificationId {
            NotificationReminderService.shared.cancelReminder(notificationId: notificationId)
        }
        publication.reminderDate = nil
        publication.reminderNotificationId = nil
    }
    
    private var deadlineIcon: String {
        switch publication.deadlineStatus {
        case .passed: return "exclamationmark.triangle.fill"
        case .approaching: return "clock.fill"
        case .future: return "calendar"
        case .none: return ""
        }
    }
    
    private var deadlineText: String {
        guard let days = publication.daysUntilDeadline else { return "" }
        
        if publication.isDeadlinePassed {
            return NSLocalizedString("publications.deadline.passed", comment: "Deadline passed")
        }
        
        return String(
            format: NSLocalizedString("publications.deadline.approaching", comment: "Days left"),
            days
        )
    }
    
    private var deadlineColor: Color {
        switch publication.deadlineStatus {
        case .passed: return .red
        case .approaching: return .orange
        case .future: return .secondary
        case .none: return .secondary
        }
    }
}
