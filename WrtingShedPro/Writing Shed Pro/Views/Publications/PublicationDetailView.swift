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
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                // Info section
                Section {
                    LabeledContent(NSLocalizedString("publications.form.name.label", comment: "Name")) {
                        Text(publication.name)
                    }
                    
                    LabeledContent(NSLocalizedString("publications.form.type.label", comment: "Type")) {
                        HStack {
                            if let type = publication.type {
                                Text(type.icon)
                                Text(type.displayName)
                            }
                        }
                    }
                    
                    if let url = publication.url, let urlObject = URL(string: url) {
                        LabeledContent(NSLocalizedString("publications.form.url.label", comment: "URL")) {
                            Link(url, destination: urlObject)
                                .lineLimit(1)
                        }
                    }
                }
                
                // Deadline section
                if publication.hasDeadline {
                    Section {
                        LabeledContent(NSLocalizedString("publications.form.deadline.label", comment: "Deadline")) {
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
                        Text(notes)
                    } header: {
                        Text(NSLocalizedString("publications.form.notes.label", comment: "Notes"))
                    }
                }
                
                // Submissions section (placeholder for Phase 3)
                Section {
                    if let submissions = publication.submissions, !submissions.isEmpty {
                        Text(String(
                            format: NSLocalizedString("publications.submissions.count", comment: "Submissions count"),
                            submissions.count
                        ))
                    } else {
                        Text(NSLocalizedString("publications.submissions.none", comment: "No submissions"))
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(NSLocalizedString("publications.submissions.title", comment: "Submissions title"))
                }
                
                // Delete section
                Section {
                    Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                        Label(
                            NSLocalizedString("publications.button.delete", comment: "Delete button"),
                            systemImage: "trash"
                        )
                    }
                    .accessibilityLabel(Text(NSLocalizedString("accessibility.delete.publication", comment: "Delete publication")))
                    .accessibilityHint(Text(NSLocalizedString("accessibility.delete.publication.hint", comment: "Delete hint")))
                }
            }
            .navigationTitle(Text(NSLocalizedString("publications.detail.title", comment: "Detail title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(NSLocalizedString("publications.button.edit", comment: "Edit button")) {
                        showingEditSheet = true
                    }
                    .accessibilityLabel(Text(NSLocalizedString("accessibility.edit.publication", comment: "Edit publication")))
                    .accessibilityHint(Text(NSLocalizedString("accessibility.edit.publication.hint", comment: "Edit hint")))
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                if let project = publication.project {
                    PublicationFormView(project: project, publication: publication)
                }
            }
            .confirmationDialog(
                String(format: NSLocalizedString("publications.delete.title", comment: "Delete title"), publication.name),
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(
                    NSLocalizedString("publications.delete.confirm", comment: "Delete confirm"),
                    role: .destructive
                ) {
                    deletePublication()
                }
            } message: {
                Text(NSLocalizedString("publications.delete.message", comment: "Delete message"))
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
    
    private func deletePublication() {
        modelContext.delete(publication)
        dismiss()
    }
}

#Preview("Magazine with deadline") {
    let publication = Publication(
        name: "Test Magazine",
        type: .magazine,
        url: "https://example.com",
        notes: "This is a test magazine with a deadline approaching.",
        deadline: Calendar.current.date(byAdding: .day, value: 5, to: Date())
    )
    return NavigationStack {
        PublicationDetailView(publication: publication)
    }
    .modelContainer(for: [Project.self, Publication.self], inMemory: true)
}

#Preview("Competition past deadline") {
    let publication = Publication(
        name: "Writing Competition",
        type: .competition,
        deadline: Calendar.current.date(byAdding: .day, value: -5, to: Date())
    )
    return NavigationStack {
        PublicationDetailView(publication: publication)
    }
    .modelContainer(for: [Project.self, Publication.self], inMemory: true)
}
