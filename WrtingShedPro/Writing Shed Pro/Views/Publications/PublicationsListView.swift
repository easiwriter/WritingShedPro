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
    @Environment(\.editMode) private var editMode
    @State private var selectedPublicationIDs: Set<UUID> = []
    @State private var showDeleteConfirmation = false
    @State private var publicationsToDelete: [Publication] = []
    
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
    
    private var isEditMode: Bool {
        editMode?.wrappedValue == .active
    }
    
    private var selectedPublications: [Publication] {
        filteredPublications.filter { selectedPublicationIDs.contains($0.id) }
    }
    
    private var showToolbar: Bool {
        isEditMode && !selectedPublicationIDs.isEmpty
    }
    
    var body: some View {
        List {
            if filteredPublications.isEmpty {
                emptyStateView
            } else {
                ForEach(filteredPublications) { publication in
                    publicationRow(for: publication)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if !isEditMode {
                                Button(role: .destructive) {
                                    prepareDelete([publication])
                                } label: {
                                    Label("publications.button.delete", systemImage: "trash")
                                }
                            }
                        }
                }
                .onDelete(perform: handleDelete)
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
            
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
                    .accessibilityLabel(Text(isEditMode ? "button.done" : "button.edit"))
            }
            
            ToolbarItemGroup(placement: .bottomBar) {
                if showToolbar {
                    Button(role: .destructive) {
                        prepareDelete(selectedPublications)
                    } label: {
                        Label(
                            "Delete \(selectedPublications.count)",
                            systemImage: "trash"
                        )
                    }
                    .disabled(selectedPublications.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            PublicationFormView(project: project, publication: nil)
        }
        .sheet(item: $selectedPublication) { publication in
            PublicationDetailView(publication: publication)
        }
        .alert(
            "Delete \(publicationsToDelete.count) \(publicationsToDelete.count == 1 ? "publication" : "publications")?",
            isPresented: $showDeleteConfirmation
        ) {
            Button("button.cancel", role: .cancel) {
                publicationsToDelete = []
            }
            Button("publications.button.delete", role: .destructive) {
                confirmDelete()
            }
        } message: {
            Text("publications.delete.confirmation.message")
        }
        .onChange(of: editMode?.wrappedValue) { _, newValue in
            if newValue == .inactive {
                selectedPublicationIDs.removeAll()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("accessibility.publications.list"))
    }
    
    @ViewBuilder
    private func publicationRow(for publication: Publication) -> some View {
        PublicationRowView(publication: publication)
            .contentShape(Rectangle())
            .onTapGesture {
                if isEditMode {
                    toggleSelection(for: publication)
                } else {
                    selectedPublication = publication
                }
            }
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
    
    private func toggleSelection(for publication: Publication) {
        if selectedPublicationIDs.contains(publication.id) {
            selectedPublicationIDs.remove(publication.id)
        } else {
            selectedPublicationIDs.insert(publication.id)
        }
    }
    
    private func prepareDelete(_ publications: [Publication]) {
        publicationsToDelete = publications
        showDeleteConfirmation = true
    }
    
    private func confirmDelete() {
        for publication in publicationsToDelete {
            modelContext.delete(publication)
        }
        publicationsToDelete = []
        exitEditMode()
    }
    
    private func exitEditMode() {
        withAnimation {
            editMode?.wrappedValue = .inactive
        }
    }
    
    private func handleDelete(at offsets: IndexSet) {
        let publications = offsets.map { filteredPublications[$0] }
        prepareDelete(publications)
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
