//
//  PoetryCollectionPickerSheet.swift
//  Writing Shed Pro
//
//  Feature 036: Sheet for assigning poems to a poetry collection
//

import SwiftUI
import SwiftData

/// Sheet for picking a poetry collection to assign selected poems to
struct PoetryCollectionPickerSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    @Query private var allCollections: [PoetryCollection]
    @Query private var allCollectionLinks: [TextFileCollectionLink]
    
    // MARK: - Properties
    
    let project: Project
    let selectedFiles: [TextFile]
    let onAssign: (PoetryCollection?) -> Void
    let onCancel: () -> Void
    
    // MARK: - Computed
    
    private var sortedCollections: [PoetryCollection] {
        allCollections
            .filter { $0.project?.id == project.id }
            .sorted { lhs, rhs in
                let lhsOrder = lhs.userOrder ?? Int.max
                let rhsOrder = rhs.userOrder ?? Int.max
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
                return (lhs.name ?? "").localizedCaseInsensitiveCompare(rhs.name ?? "") == .orderedAscending
            }
    }

    private func liveFileCount(for collection: PoetryCollection) -> Int {
        allCollectionLinks.reduce(into: 0) { count, link in
            if link.poetryCollectionID == collection.id || link.poetryCollection?.id == collection.id {
                count += 1
            }
        }
    }

    private var hasAnyAssignedCollection: Bool {
        let selectedFileIDs = Set(selectedFiles.map(\.id))
        return allCollectionLinks.contains { link in
            let textFileID = link.textFileID ?? link.textFile?.id
            let collectionID = link.poetryCollectionID ?? link.poetryCollection?.id
            return textFileID.map { selectedFileIDs.contains($0) } == true && collectionID != nil
        }
    }
    
    /// Check if all selected files are assigned to the same collection
    private var assignedCollection: PoetryCollection? {
        guard let firstFileID = selectedFiles.first?.id,
              let firstCollectionID = allCollectionLinks.first(where: { $0.textFileID == firstFileID || $0.textFile?.id == firstFileID })?.poetryCollectionID ??
                allCollectionLinks.first(where: { $0.textFileID == firstFileID || $0.textFile?.id == firstFileID })?.poetryCollection?.id,
              let firstCollection = sortedCollections.first(where: { $0.id == firstCollectionID }) else { return nil }
        let allSameCollection = selectedFiles.allSatisfy { file in
            let collectionID = allCollectionLinks.first(where: { $0.textFileID == file.id || $0.textFile?.id == file.id })?.poetryCollectionID ??
                allCollectionLinks.first(where: { $0.textFileID == file.id || $0.textFile?.id == file.id })?.poetryCollection?.id
            return collectionID == firstCollectionID
        }
        return allSameCollection ? firstCollection : nil
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            List {
                if let collection = assignedCollection {
                    // All files assigned to same collection — show remove option
                    Section {
                        Button {
                            onAssign(nil)
                        } label: {
                            HStack {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.red)
                                Text(String(format: NSLocalizedString("poetry.collection.removeFromNamed", comment: "Remove from Collection X"), collection.name ?? NSLocalizedString("poetry.collection.untitled", comment: "Untitled")))
                                    .foregroundColor(.primary)
                            }
                        }
                    } header: {
                        Text(NSLocalizedString("poetry.collection.currentAssignment", comment: "Current Assignment"))
                    } footer: {
                        Text(String(format: NSLocalizedString("poetry.collection.assignedTo", comment: "Assigned to collection"), collection.name ?? NSLocalizedString("poetry.collection.untitled", comment: "Untitled")))
                    }
                } else {
                    if hasAnyAssignedCollection {
                        unassignedSection
                    }
                    collectionsSection
                }
            }
            .navigationTitle(assignedCollection != nil ? NSLocalizedString("poetry.collection.assignment", comment: "Collection Assignment") : NSLocalizedString("poetry.collection.addTo", comment: "Add to Collection"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var unassignedSection: some View {
        Section {
            Button {
                onAssign(nil)
            } label: {
                HStack {
                    Image(systemName: "tray")
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("poetry.collection.unassigned", comment: "Unassigned"))
                        .foregroundColor(.primary)
                }
            }
        } header: {
            Text(NSLocalizedString("poetry.collection.currentAssignment", comment: "Current Assignment"))
        }
    }

    private var collectionsSection: some View {
        Section {
            if sortedCollections.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)

                    Text(NSLocalizedString("poetry.collections.empty.title", comment: "No Collections Yet"))
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text(NSLocalizedString("poetry.collections.picker.createHint", comment: "Create collections in the Collections folder"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                ForEach(sortedCollections) { collection in
                    Button {
                        onAssign(collection)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(collection.name ?? NSLocalizedString("poetry.collection.untitled", comment: "Untitled"))
                                    .foregroundColor(.primary)
                            }

                            Spacer()

                            let fileCount = liveFileCount(for: collection)
                            Text("\(fileCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        } header: {
            Text(NSLocalizedString("poetry.collections.title", comment: "Collections"))
        } footer: {
            if !sortedCollections.isEmpty {
                Text(String(format: NSLocalizedString("poetry.collection.assignCount", comment: "Assign count"), selectedFiles.count))
            }
        }
    }
}
