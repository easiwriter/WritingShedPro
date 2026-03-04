//
//  PublicationFormView.swift
//  Writing Shed Pro
//
//  Feature 008b Phase 2: Publications Management UI
//

import SwiftUI
import SwiftData

struct PublicationFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let project: Project
    let publication: Publication? // nil = add, non-nil = edit
    
    @Query private var allPublications: [Publication]
    
    @State private var name: String = ""
    @State private var selectedType: PublicationType = .magazine
    @State private var url: String = ""
    @State private var hasDeadline: Bool = false
    @State private var deadline: Date = Date().addingTimeInterval(86400 * 30) // 30 days default
    @State private var notes: String = ""
    @State private var hasResponseTime: Bool = false
    @State private var typicalResponseDays: Int = 90
    @State private var setReminder: Bool = false
    @State private var reminderDate: Date = Date()
    @State private var showReminderPermissionAlert = false
    
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDuplicateWarning = false
    @State private var pendingSaveName: String = ""
    
    var isEditing: Bool { publication != nil }
    
    /// Available publication types based on project type
    private var availableTypes: [PublicationType] {
        PublicationType.availableTypes(for: project.type)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Name section
                Section {
                    TextField(
                        NSLocalizedString("publications.form.name.placeholder", comment: "Name placeholder"),
                        text: $name
                    )
                    .accessibilityLabel(Text(NSLocalizedString("publications.form.name.label", comment: "Name label")))
                } header: {
                    Text(NSLocalizedString("publications.form.name.label", comment: "Name label"))
                }
                
                // Type section
                Section {
                    Picker(
                        NSLocalizedString("publications.form.type.label", comment: "Type label"),
                        selection: $selectedType
                    ) {
                        ForEach(availableTypes, id: \.self) { type in
                            Text(type.displayName)
                                .tag(type)
                        }
                    }
                    .accessibilityLabel(Text(NSLocalizedString("accessibility.type.picker", comment: "Type picker")))
                } header: {
                    Text(NSLocalizedString("publications.form.type.label", comment: "Type label"))
                }
                
                // Deadline section
                Section {
                    Toggle(isOn: $hasDeadline) {
                        Text(NSLocalizedString("publications.form.deadline.label", comment: "Deadline label"))
                    }
                    .accessibilityLabel(Text(NSLocalizedString("accessibility.deadline.toggle", comment: "Deadline toggle")))
                    .accessibilityHint(Text(NSLocalizedString("accessibility.deadline.toggle.hint", comment: "Toggle deadline hint")))
                    
                    if hasDeadline {
                        DatePicker(
                            "",
                            selection: $deadline,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .onChange(of: deadline) { _, newDate in
                            let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: newDate) ?? newDate
                            reminderDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: dayBefore) ?? dayBefore
                        }
                        
                        Toggle(isOn: $setReminder) {
                            Label(NSLocalizedString("reminder.set", comment: "Set Reminder"), systemImage: "bell")
                        }
                        
                        if setReminder {
                            DatePicker(
                                NSLocalizedString("reminder.date.label", comment: "Reminder Date"),
                                selection: $reminderDate,
                                in: Date()...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                        }
                    }
                } header: {
                    Text(NSLocalizedString("publications.form.deadline.label", comment: "Deadline label"))
                }
                
                // URL section
                Section {
                    TextField(
                        NSLocalizedString("publications.form.url.placeholder", comment: "URL placeholder"),
                        text: $url
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .accessibilityLabel(Text(NSLocalizedString("publications.form.url.label", comment: "URL label")))
                } header: {
                    Text(NSLocalizedString("publications.form.url.label", comment: "URL label"))
                }
                
                // Notes section
                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                        .accessibilityLabel(Text(NSLocalizedString("publications.form.notes.label", comment: "Notes label")))
                } header: {
                    Text(NSLocalizedString("publications.form.notes.label", comment: "Notes label"))
                }
            }
            .navigationTitle(Text(NSLocalizedString(
                isEditing ? "publications.edit.title" : "publications.add.title",
                comment: "Form title"
            )))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("publications.button.cancel", comment: "Cancel button")) {
                        dismiss()
                    }
                    .accessibilityHint(Text(NSLocalizedString("accessibility.cancel.hint", comment: "Cancel hint")))
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("publications.button.save", comment: "Save button")) {
                        savePublication()
                    }
                    .accessibilityHint(Text(NSLocalizedString("accessibility.save.publication.hint", comment: "Save hint")))
                }
            }
            .alert(
                NSLocalizedString("publications.error.title", comment: "Error title"),
                isPresented: $showingError
            ) {
                Button("button.ok") { }
            } message: {
                Text(errorMessage)
            }
            .confirmationDialog(
                "publications.duplicate.title",
                isPresented: $showingDuplicateWarning,
                titleVisibility: .visible
            ) {
                Button("publications.duplicate.useOriginal") {
                    performSave(withName: pendingSaveName)
                }
                Button("publications.duplicate.makeUnique") {
                    let uniqueName = makeUniqueName(pendingSaveName)
                    name = uniqueName
                    performSave(withName: uniqueName)
                }
                Button("button.cancel", role: .cancel) {
                    pendingSaveName = ""
                }
            } message: {
                Text("publications.duplicate.message")
            }
            .onAppear {
                loadPublication()
            }
            .alert(NSLocalizedString("reminder.permission.title", comment: "Notifications Disabled"), isPresented: $showReminderPermissionAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(NSLocalizedString("reminder.permission.message", comment: "Please enable notifications in Settings"))
            }
        }
    }
    
    private func loadPublication() {
        if let publication = publication {
            // Editing existing publication
            name = publication.name
            // Use existing type if available for this project, otherwise use first available
            if let existingType = publication.type, availableTypes.contains(existingType) {
                selectedType = existingType
            } else {
                selectedType = availableTypes.first ?? .other
            }
            url = publication.url ?? ""
            hasDeadline = publication.hasDeadline
            deadline = publication.deadline ?? Date().addingTimeInterval(86400 * 30)
            hasResponseTime = publication.typicalResponseDays != nil
            typicalResponseDays = publication.typicalResponseDays ?? 90
            notes = publication.notes ?? ""
            setReminder = publication.reminderDate != nil
            reminderDate = publication.reminderDate ?? {
                let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: publication.deadline ?? Date()) ?? Date()
                return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: dayBefore) ?? dayBefore
            }()
        } else {
            // Creating new publication - set default type for project
            selectedType = availableTypes.first ?? .other
            let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: deadline) ?? deadline
            reminderDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: dayBefore) ?? dayBefore
        }
    }
    
    private func savePublication() {
        // Validate
        guard validateInput() else { return }
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for duplicates (only when creating new or changing name)
        if publication == nil || publication?.name != trimmedName {
            if hasDuplicateName(trimmedName) {
                pendingSaveName = trimmedName
                showingDuplicateWarning = true
                return
            }
        }
        
        performSave(withName: trimmedName)
    }
    
    private func performSave(withName finalName: String) {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let publication = publication {
            // Edit existing
            publication.name = finalName
            publication.type = selectedType
            publication.url = trimmedURL.isEmpty ? nil : trimmedURL
            publication.deadline = hasDeadline ? deadline : nil
            publication.typicalResponseDays = hasResponseTime ? typicalResponseDays : nil
            publication.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            publication.modifiedDate = Date()
            
            // Handle reminder
            scheduleOrCancelReminder(for: publication)
        } else {
            // Create new
            let newPublication = Publication(
                name: finalName,
                type: selectedType,
                url: trimmedURL.isEmpty ? nil : trimmedURL,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                deadline: hasDeadline ? deadline : nil,
                project: project
            )
            newPublication.typicalResponseDays = hasResponseTime ? typicalResponseDays : nil
            modelContext.insert(newPublication)
            
            // Handle reminder for new publication
            if hasDeadline && setReminder {
                newPublication.reminderDate = reminderDate
                let pubName = finalName
                let remDate = reminderDate
                Task {
                    let granted = await NotificationReminderService.shared.requestPermission()
                    guard granted else { return }
                    let notifId = await NotificationReminderService.shared.scheduleDeadlineReminder(
                        publicationId: UUID().uuidString,
                        publicationName: pubName,
                        reminderDate: remDate
                    )
                    if let notifId = notifId {
                        await MainActor.run {
                            newPublication.reminderNotificationId = notifId
                        }
                    }
                }
            }
        }
        
        dismiss()
    }
    
    private func scheduleOrCancelReminder(for publication: Publication) {
        // Cancel existing reminder if any
        if let existingId = publication.reminderNotificationId {
            NotificationReminderService.shared.cancelReminder(notificationId: existingId)
            publication.reminderNotificationId = nil
        }
        
        if hasDeadline && setReminder {
            publication.reminderDate = reminderDate
            let pubName = publication.name
            let remDate = reminderDate
            Task {
                let granted = await NotificationReminderService.shared.requestPermission()
                guard granted else {
                    await MainActor.run { showReminderPermissionAlert = true }
                    return
                }
                let notifId = await NotificationReminderService.shared.scheduleDeadlineReminder(
                    publicationId: UUID().uuidString,
                    publicationName: pubName,
                    reminderDate: remDate
                )
                if let notifId = notifId {
                    await MainActor.run {
                        publication.reminderNotificationId = notifId
                    }
                }
            }
        } else {
            publication.reminderDate = nil
        }
    }
    
    private func hasDuplicateName(_ name: String) -> Bool {
        let projectID: UUID = project.id
        let editingID: UUID? = publication?.id
        let projectPublications: [Publication] = allPublications.filter { (pub: Publication) -> Bool in
            pub.project?.id == projectID && pub.id != editingID
        }
        return projectPublications.contains { (pub: Publication) -> Bool in pub.name.lowercased() == name.lowercased() }
    }
    
    private func makeUniqueName(_ baseName: String) -> String {
        let projectID: UUID = project.id
        let editingID: UUID? = publication?.id
        let projectPublications: [Publication] = allPublications.filter { (pub: Publication) -> Bool in
            pub.project?.id == projectID && pub.id != editingID
        }
        
        var counter = 1
        var uniqueName = "\(baseName)-1"
        
        while projectPublications.contains(where: { (pub: Publication) -> Bool in pub.name.lowercased() == uniqueName.lowercased() }) {
            counter += 1
            uniqueName = "\(baseName)-\(counter)"
        }
        
        return uniqueName
    }
    
    private func validateInput() -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate name
        if trimmedName.isEmpty {
            errorMessage = NSLocalizedString("publications.error.name.empty", comment: "Empty name error")
            showingError = true
            return false
        }
        
        if trimmedName.count > 100 {
            errorMessage = NSLocalizedString("publications.error.name.toolong", comment: "Name too long error")
            showingError = true
            return false
        }
        
        // Validate URL if provided
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedURL.isEmpty {
            if let url = URL(string: trimmedURL), url.scheme != nil {
                // Valid URL
            } else {
                errorMessage = NSLocalizedString("publications.error.url.invalid", comment: "Invalid URL error")
                showingError = true
                return false
            }
        }
        
        return true
    }
}
