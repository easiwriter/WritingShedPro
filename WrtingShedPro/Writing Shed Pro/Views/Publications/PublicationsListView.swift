//
//  PublicationsListView.swift
//  Writing Shed Pro
//
//  Feature 008b Phase 2: Publications Management UI
//

import SwiftUI
import SwiftData

struct PublicationsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Publication.name) private var publications: [Publication]
    
    let project: Project
    let publicationType: PublicationType? // nil = show all, non-nil = filter by type
    
    @State private var showingAddSheet = false
    @State private var selectedPublication: Publication?
    
    // Filter publications by type and project
    private var filteredPublications: [Publication] {
        publications.filter { publication in
            // Check project match
            let projectMatches = publication.project?.id == project.id
            
            // Check type match (if filter specified)
            let typeMatches = publicationType == nil || publication.type == publicationType
            
            return projectMatches && typeMatches
        }
    }
    
    var body: some View {
        List {
            if filteredPublications.isEmpty {
                emptyStateView
            } else {
                ForEach(filteredPublications) { publication in
                    PublicationRowView(publication: publication)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedPublication = publication
                        }
                }
                .onDelete(perform: deletePublications)
            }
        }
        .navigationTitle(Text(navigationTitle))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddSheet = true }) {
                    Label(
                        NSLocalizedString("publications.button.add", comment: "Add publication button"),
                        systemImage: "plus"
                    )
                }
                .accessibilityLabel(Text(NSLocalizedString("accessibility.add.publication", comment: "Add publication button")))
                .accessibilityHint(Text(NSLocalizedString("accessibility.add.publication.hint", comment: "Opens form to create new publication")))
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            PublicationFormView(project: project, publication: nil)
        }
        .sheet(item: $selectedPublication) { publication in
            PublicationDetailView(publication: publication)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(NSLocalizedString("accessibility.publications.list", comment: "Publications list")))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text(NSLocalizedString("publications.empty.title", comment: "Empty state title"))
                .font(.headline)
            
            Text(NSLocalizedString("publications.empty.message", comment: "Empty state message"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    private var navigationTitle: String {
        if let type = publicationType {
            switch type {
            case .magazine:
                return NSLocalizedString("publications.magazines.title", comment: "Magazines title")
            case .competition:
                return NSLocalizedString("publications.competitions.title", comment: "Competitions title")
            case .commission:
                return NSLocalizedString("publications.commissions.title", comment: "Commissions title")
            case .other:
                return NSLocalizedString("publications.other.title", comment: "Other title")
            }
        }
        return NSLocalizedString("publications.title", comment: "Publications title")
    }
    
    private func deletePublications(at offsets: IndexSet) {
        let publicationsToDelete = offsets.map { filteredPublications[$0] }
        for publication in publicationsToDelete {
            modelContext.delete(publication)
        }
    }
}

#Preview("All Publications") {
    NavigationStack {
        PublicationsListView(project: Project(name: "Test Project"), publicationType: nil)
            .modelContainer(for: [Project.self, Publication.self, Submission.self, SubmittedFile.self], inMemory: true)
    }
}

#Preview("Magazines Only") {
    NavigationStack {
        PublicationsListView(project: Project(name: "Test Project"), publicationType: .magazine)
            .modelContainer(for: [Project.self, Publication.self, Submission.self, SubmittedFile.self], inMemory: true)
    }
}
