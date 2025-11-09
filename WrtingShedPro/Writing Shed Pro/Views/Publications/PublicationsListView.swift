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
    
    @State private var showingAddSheet = false
    @State private var selectedPublication: Publication?
    
    var body: some View {
        List {
            if publications.isEmpty {
                emptyStateView
            } else {
                ForEach(publications) { publication in
                    PublicationRowView(publication: publication)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedPublication = publication
                        }
                }
                .onDelete(perform: deletePublications)
            }
        }
        .navigationTitle(Text(NSLocalizedString("publications.title", comment: "Publications screen title")))
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
            PublicationFormView(project: project)
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
    
    private func deletePublications(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(publications[index])
        }
    }
}

#Preview {
    NavigationStack {
        PublicationsListView(project: Project(name: "Test Project"))
            .modelContainer(for: [Project.self, Publication.self, Submission.self, SubmittedFile.self], inMemory: true)
    }
}
