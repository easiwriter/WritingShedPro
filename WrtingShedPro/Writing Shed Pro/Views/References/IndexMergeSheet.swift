//
//  IndexMergeSheet.swift
//  Writing Shed Pro
//
//  Feature 033: Index Generation
//  Created by GitHub Copilot on 30/01/2026.
//
//  Sheet for selecting target entry when merging index entries
//

import SwiftUI
import SwiftData

/// Sheet view for selecting a target entry to merge into
struct IndexMergeSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    let sourceEntry: IndexEntry
    let availableTargets: [IndexEntry]
    
    /// Callback when merge is confirmed
    var onMerge: ((IndexEntry) -> Void)?
    
    /// Callback when cancelled
    var onCancel: (() -> Void)?
    
    // MARK: - State
    
    @State private var selectedTarget: IndexEntry?
    @State private var searchText: String = ""
    
    // MARK: - Computed Properties
    
    private var filteredTargets: [IndexEntry] {
        if searchText.isEmpty {
            return availableTargets.sorted { (a: IndexEntry, b: IndexEntry) -> Bool in a.keyword.localizedCaseInsensitiveCompare(b.keyword) == .orderedAscending }
        }
        let lowercasedSearch: String = searchText.lowercased()
        return availableTargets.filter { (entry: IndexEntry) -> Bool in
            entry.keyword.lowercased().contains(lowercasedSearch)
        }.sorted { (a: IndexEntry, b: IndexEntry) -> Bool in a.keyword.localizedCaseInsensitiveCompare(b.keyword) == .orderedAscending }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Source info
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("indexMerge.merging", comment: "Merging:"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "list.bullet.indent")
                            .foregroundColor(.purple)
                        Text(sourceEntry.keyword)
                            .font(.headline)
                        
                        if sourceEntry.referenceCount > 0 {
                            Text("(\(sourceEntry.referenceCount) refs)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(NSLocalizedString("indexMerge.description", comment: "References will be transferred to the target entry."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                
                Divider()
                
                // Target selection
                List {
                    Section {
                        ForEach(filteredTargets) { entry in
                            Button {
                                selectedTarget = entry
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.keyword)
                                            .foregroundColor(.primary)
                                        
                                        if entry.referenceCount > 0 {
                                            Text("\(entry.referenceCount) references")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedTarget?.id == entry.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text(NSLocalizedString("indexMerge.selectTarget", comment: "Select Target Entry"))
                    }
                }
                .listStyle(.insetGrouped)
                .searchable(text: $searchText, prompt: NSLocalizedString("indexMerge.search", comment: "Search entries"))
            }
            .navigationTitle(NSLocalizedString("indexMerge.title", comment: "Merge Entry"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        onCancel?()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("indexMerge.merge", comment: "Merge")) {
                        if let target = selectedTarget {
                            onMerge?(target)
                            dismiss()
                        }
                    }
                    .disabled(selectedTarget == nil)
                }
            }
        }
    }
}

// MARK: - Localization Keys

/*
 Add these to Localizable.strings:
 
 "indexMerge.title" = "Merge Entry";
 "indexMerge.merging" = "Merging:";
 "indexMerge.description" = "References will be transferred to the target entry.";
 "indexMerge.selectTarget" = "Select Target Entry";
 "indexMerge.search" = "Search entries";
 "indexMerge.merge" = "Merge";
 */
