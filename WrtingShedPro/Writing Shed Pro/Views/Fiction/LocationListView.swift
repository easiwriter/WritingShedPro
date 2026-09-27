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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddLocation = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(NSLocalizedString("fiction.locations.add", comment: "Add location"))
            }
        }
        #if targetEnvironment(macCatalyst)
        .overlay { locationOverlay }
        #else
        .sheet(isPresented: $showAddLocation) {
            AddLocationSheet(project: project) { showAddLocation = false }
        }
        .sheet(item: $selectedLocation) { location in
            LocationDetailView(location: location) { selectedLocation = nil }
        }
        #endif
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

    #if targetEnvironment(macCatalyst)
    @ViewBuilder
    private var locationOverlay: some View {
        if showAddLocation || selectedLocation != nil {
            GeometryReader { geometry in
                ZStack {
                    Color.black.opacity(0.28).ignoresSafeArea()
                    Group {
                        if showAddLocation {
                            AddLocationSheet(project: project) { showAddLocation = false }
                        } else if let location = selectedLocation {
                            LocationDetailView(location: location) { selectedLocation = nil }
                        }
                    }
                    .frame(width: min(620, max(320, geometry.size.width - 48)), height: min(720, max(420, geometry.size.height - 48)))
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 12)
                }
            }
            .zIndex(1000)
        }
    }
    #endif
    
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
        guard EntitlementManager.shared.canModifyContent else { return }
        modelContext.delete(location)
        location.project?.modifiedDate = Date()
        WriteCoalescer.shared?.requestSave(reason: "location-list-delete")
        WriteCoalescer.shared?.flush()
    }
}

// MARK: - Location Row View

struct LocationRowView: View {
    let location: Location
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(location.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
                .font(.body)
                .fontWeight(.semibold)
            
            if let detail = location.detail, !detail.isEmpty {
                Text(detail)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Show scene count if any
            if let scenes = location.scenes, !scenes.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "film")
                        .font(.footnote)
                    Text(String(format: NSLocalizedString("fiction.location.sceneCount", comment: "Scene count"), scenes.count))
                        .font(.footnote)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
