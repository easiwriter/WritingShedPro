//
//  MoveDestinationPicker.swift
//  Writing Shed Pro
//
//  Created on 2025-11-08.
//  Feature: 008a-file-movement - Phase 3
//

import SwiftUI
import SwiftData

/// Sheet for selecting destination folder when moving files.
///
/// **Key Features:**
/// - Shows valid destination folders (Draft, Ready, Set Aside)
/// - Excludes current folder and Trash
/// - Displays folder name and file count
/// - Cancel and Done actions
///
/// **Usage:**
/// ```swift
/// .sheet(isPresented: $showMoveSheet) {
///     MoveDestinationPicker(
///         project: project,
///         currentFolder: currentFolder,
///         filesToMove: selectedFiles,
///         onDestinationSelected: { destination in
///             moveFiles(to: destination)
///         },
///         onCancel: {
///             showMoveSheet = false
///         }
///     )
/// }
/// ```
struct MoveDestinationPicker: View {
    // MARK: - Properties
    
    /// The project containing the files
    let project: Project
    
    /// Current folder to exclude from destinations
    let currentFolder: Folder
    
    /// Files being moved (for context/display)
    let filesToMove: [TextFile]
    
    /// Callback when destination folder is selected
    let onDestinationSelected: (Folder) -> Void
    
    /// Callback when user cancels
    let onCancel: () -> Void
    
    // MARK: - State
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Computed Properties
    
    /// Available destination folders (excluding current folder and Trash)
    private var availableFolders: [Folder] {
        guard let allFolders = project.folders else { return [] }
        
        return allFolders.filter { folder in
            // Exclude current folder
            guard folder.id != currentFolder.id else { return false }
            
            // Only include source folders (Draft, Ready, Set Aside)
            guard let folderName = folder.name?.lowercased() else { return false }
            
            return folderName == "draft" || 
                   folderName == "ready" || 
                   folderName == "set aside"
        }
        .sorted { ($0.name ?? "") < ($1.name ?? "") }
    }
    
    /// Title text showing file count
    private var titleText: String {
        let count = filesToMove.count
        return count == 1 ? "Move File" : "Move \(count) Files"
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if availableFolders.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(availableFolders) { folder in
                            folderButton(for: folder)
                        }
                    }
                } header: {
                    Text("moveDestination.selectDestination")
                } footer: {
                    if !filesToMove.isEmpty {
                        Text("Moving \(filesToMove.count) \(filesToMove.count == 1 ? "file" : "files")")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "")) {
                        onCancel()
                    }
                }
            }
        }
    }
    
    // MARK: - View Builders
    
    /// Empty state when no folders available
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text("moveDestination.noFolders.title")
                .font(.headline)
            
            Text("moveDestination.noFolders.message")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    /// Button for each folder destination
    @ViewBuilder
    private func folderButton(for folder: Folder) -> some View {
        Button {
            onDestinationSelected(folder)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.name ?? "Untitled")
                        .font(.body)
                    
                    if let fileCount = folder.textFiles?.count {
                        Text("\(fileCount) \(fileCount == 1 ? "file" : "files")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
}
