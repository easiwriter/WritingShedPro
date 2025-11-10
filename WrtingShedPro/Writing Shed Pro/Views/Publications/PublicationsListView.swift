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
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddSheet = true }) {
                    Label("publications.button.add", systemImage: "plus")
                }
                .accessibilityLabel(Text("accessibility.add.publication"))
                .accessibilityHint(Text("accessibility.add.publication.hint"))
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            PublicationFormView(project: project, publication: nil)
        }
        .sheet(item: $selectedPublication) { publication in
            PublicationDetailView(publication: publication)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("accessibility.publications.list"))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("publications.empty.title")
                .font(.headline)
            
            Text("publications.empty.message")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    private var navigationTitle: LocalizedStringKey {
        if let type = publicationType {
            switch type {
            case .magazine:
                return "publications.magazines.title"
            case .competition:
                return "publications.competitions.title"
            case .commission:
                return "publications.commissions.title"
            case .other:
                return "publications.other.title"
            }
        }
        return "publications.title"
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
