//
//  SubmissionsView.swift
//  Writing Shed Pro
//
//  Feature: Submissions Folder
//  Displays Submission objects (where publication != nil) organized in the Submissions folder
//  These are collections that have been submitted to publications
//

import SwiftUI
import SwiftData

/// View for displaying Submissions in the Submissions folder
/// Submissions are Submission objects with a publication attached
struct SubmissionsView: View {
    let project: Project
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    
    // State for sorting
    @State private var sortOrder: SubmissionSortOrder = .bySubmittedDate
    
    // Query all Submissions for this project where publication is not nil
    @Query private var allSubmissions: [Submission]
    
    init(project: Project) {
        self.project = project
        
        // Configure query to fetch only Submissions (isCollection = false)
        // Note: Using isCollection flag because SwiftData predicates cannot handle optional relationships
        // We filter by project in the sortedSubmissions computed property
        _allSubmissions = Query(
            filter: #Predicate<Submission> { submission in
                submission.isCollection == false
            },
            sort: [SortDescriptor(\Submission.name, order: .forward)]
        )
    }
    
    // Submissions sorted by user preference
    // Additional filtering to ensure ONLY submissions for THIS project appear
    private var sortedSubmissions: [Submission] {
        let submissionsForProject = allSubmissions.filter { 
            !$0.isCollection && $0.project?.id == project.id
        }
        
        switch sortOrder {
        case .bySubmittedDate:
            return submissionsForProject.sorted { ($0.submittedDate) > ($1.submittedDate) }
        case .byName:
            return submissionsForProject.sorted { ($0.name ?? "") < ($1.name ?? "") }
        case .byPublication:
            return submissionsForProject.sorted { ($0.publication?.name ?? "") < ($1.publication?.name ?? "") }
        }
    }
    
    var body: some View {
        Group {
            if !sortedSubmissions.isEmpty {
                // Show list of submissions
                List {
                    ForEach(sortedSubmissions) { submission in
                        submissionRow(for: submission)
                    }
                }
                .listStyle(.plain)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Picker("Sort by", selection: $sortOrder) {
                                ForEach(SubmissionSortOrder.allCases, id: \.self) { order in
                                    Text(order.displayName).tag(order)
                                }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }
                    }
                }
            } else {
                // Show empty state
                emptyStateView
            }
        }
        .navigationTitle("Submissions")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Submission Row
    
    @ViewBuilder
    private func submissionRow(for submission: Submission) -> some View {
        NavigationLink(destination: CollectionDetailView(submission: submission)) {
            VStack(alignment: .leading, spacing: 4) {
                // Submission name
                Text(submission.name ?? "Untitled Submission")
                    .font(.headline)
                
                // File count
                let fileCount = submission.submittedFiles?.count ?? 0
                Text("\(fileCount) \(fileCount == 1 ? "file" : "files")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Submissions")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Submissions from collections to publications will appear here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Sort Order

enum SubmissionSortOrder: String, CaseIterable {
    case bySubmittedDate = "submittedDate"
    case byName = "name"
    case byPublication = "publication"
    
    var displayName: String {
        switch self {
        case .bySubmittedDate:
            return "Submitted Date"
        case .byName:
            return "Name"
        case .byPublication:
            return "Publication"
        }
    }
}
