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
                    if let submissions = publication.submissions?.sorted(by: { $0.submittedDate > $1.submittedDate }), !submissions.isEmpty {
                        ForEach(submissions) { submission in
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
