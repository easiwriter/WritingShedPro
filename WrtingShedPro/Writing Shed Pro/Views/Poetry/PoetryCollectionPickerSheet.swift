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
    
    // MARK: - Properties
    
    let project: Project
    let selectedFiles: [TextFile]
    let onAssign: (PoetryCollection?) -> Void
    let onCancel: () -> Void
    
    // MARK: - Computed
    
    private var sortedCollections: [PoetryCollection] {
        (project.poetryCollections ?? []).sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
    }
    
    /// Check if all selected files are assigned to the same collection
    private var assignedCollection: PoetryCollection? {
        guard let firstCollection = selectedFiles.first?.poetryCollection else { return nil }
        let allSameCollection = selectedFiles.allSatisfy { $0.poetryCollection?.id == firstCollection.id }
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
                    // Files are unassigned — show list of collections
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
                                        
                                        let fileCount = collection.textFiles?.count ?? 0
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
            .navigationTitle(assignedCollection != nil ? NSLocalizedString("poetry.collection.assignment", comment: "Collection Assignment") : NSLocalizedString("poetry.collection.addTo", comment: "Add to Collection"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        onCancel()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
