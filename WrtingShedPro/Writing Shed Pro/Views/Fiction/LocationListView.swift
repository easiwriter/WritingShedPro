//
//  LocationListView.swift
//  Writing Shed Pro
//
//  Feature 022: Smart Fiction Creation - Location management
//

import SwiftUI
import SwiftData

/// List view showing all locations for a fiction project
struct LocationListView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    
    // MARK: - State
    
    @State private var showAddLocation = false
    @State private var selectedLocation: Location?
    @State private var showDeleteConfirmation = false
    @State private var locationToDelete: Location?
    
    // MARK: - Computed
    
    private var sortedLocations: [Location] {
        (project.locations ?? []).sorted { 
            ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if sortedLocations.isEmpty {
                emptyState
            } else {
                locationList
            }
        }
        .navigationTitle(NSLocalizedString("fiction.locations.title", comment: "Locations"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onPopToRoot {
            dismiss()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                PopToRootBackButton()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddLocation = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(NSLocalizedString("fiction.locations.add", comment: "Add location"))
            }
        }
        .sheet(isPresented: $showAddLocation) {
            AddLocationSheet(project: project)
        }
        .sheet(item: $selectedLocation) { location in
            LocationDetailView(location: location)
        }
        .alert(
            NSLocalizedString("fiction.locations.deleteConfirm.title", comment: "Delete location?"),
            isPresented: $showDeleteConfirmation,
            presenting: locationToDelete
        ) { location in
            Button(NSLocalizedString("button.delete", comment: "Delete"), role: .destructive) {
                deleteLocation(location)
            }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
        } message: { location in
            Text(String(format: NSLocalizedString("fiction.locations.deleteConfirm.message", comment: "Delete message"), location.name ?? ""))
        }
    }
    
    // MARK: - Location List
    
    private var locationList: some View {
        List {
            ForEach(sortedLocations) { location in
                LocationRowView(location: location)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedLocation = location
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            locationToDelete = location
                            showDeleteConfirmation = true
                        } label: {
                            Label(NSLocalizedString("button.delete", comment: "Delete"), systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("fiction.locations.empty.title", comment: "No locations"))
                .font(.headline)
            
            Text(NSLocalizedString("fiction.locations.empty.message", comment: "Empty message"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showAddLocation = true
            } label: {
                Label(NSLocalizedString("fiction.locations.add", comment: "Add location"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func deleteLocation(_ location: Location) {
        modelContext.delete(location)
        try? modelContext.save()
    }
}

// MARK: - Location Row View

struct LocationRowView: View {
    let location: Location
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(location.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
                .font(.headline)
            
            if let description = location.locationDescription, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Show scene count if any
            if let scenes = location.scenes, !scenes.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "film")
                        .font(.caption)
                    Text(String(format: NSLocalizedString("fiction.location.sceneCount", comment: "Scene count"), scenes.count))
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
