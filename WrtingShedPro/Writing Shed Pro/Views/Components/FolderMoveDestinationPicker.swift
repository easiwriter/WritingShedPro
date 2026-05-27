//
//  FolderMoveDestinationPicker.swift
//  Writing Shed Pro
//
//  Created on 2026-01-01.
//  Feature: Prose project folder movement
//

import SwiftUI
import SwiftData

/// Sheet for selecting destination folder when moving a folder or files in Prose projects.
/// Shows the full folder hierarchy and allows moving to any valid destination.
struct FolderMoveDestinationPicker: View {
    // MARK: - Properties
    
    /// The project containing the folders
    let project: Project
    
    /// Current folder (parent of items being moved)
    let currentFolder: Folder
    
    /// Folder being moved (nil if moving files)
    let folderToMove: Folder?
    
    /// Files being moved (empty if moving folder)
    let filesToMove: [TextFile]
    
    /// Callback when destination folder is selected
    let onDestinationSelected: (Folder) -> Void
    
    /// Callback when user cancels
    let onCancel: () -> Void
    
    // MARK: - State
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Computed Properties
    
    /// Get all folders in the project, organized by hierarchy
    private var allFolders: [Folder] {
        guard let folders = project.folders else { return [] }
        return folders
    }
    
    /// Get the "Folders" folder (the root container for user folders)
    private var foldersFolder: Folder? {
        allFolders.first { $0.name == "Folders" && $0.parentFolder == nil }
    }
    
    /// Get user-created folders that are inside "Folders" (siblings of the current folder)
    /// These are valid move destinations (excludes current folder, folder being moved, and descendants)
    private var siblingFolders: [Folder] {
        guard let foldersRoot = foldersFolder else { return [] }
        
        // Get direct children of "Folders" folder
        return (foldersRoot.folders ?? [])
            .filter { isValidDestination($0) }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
    }
    
    /// Whether we should show the "Root Level" section (moving to "Folders" folder)
    /// Only show if current folder is NOT the "Folders" folder itself
    private var showRootLevelOption: Bool {
        guard let foldersRoot = foldersFolder else { return false }
        // Show root level option if we're inside a subfolder (not at root)
        return currentFolder.id != foldersRoot.id && isValidDestination(foldersRoot)
    }
    
    /// Title text
    private var titleText: String {
        if folderToMove != nil {
            return NSLocalizedString("folderMoveDestination.moveFolder", comment: "Move Folder")
        } else {
            let count = filesToMove.count
            return count == 1 
                ? NSLocalizedString("folderMoveDestination.moveFile", comment: "Move File")
                : String(format: NSLocalizedString("folderMoveDestination.moveFiles", comment: "Move %d Files"), count)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            List {
                // Show "Folders" as a destination (root level) - only when moving from a subfolder
                if showRootLevelOption, let rootFolder = foldersFolder {
                    Section {
                        folderButton(for: rootFolder, indent: 0)
                    } header: {
                        Text(NSLocalizedString("folderMoveDestination.rootLevel", comment: "Root Level"))
                    }
                }
                
                // Show sibling folders (other user-created folders inside "Folders")
                if !siblingFolders.isEmpty {
                    Section {
                        ForEach(siblingFolders) { folder in
                            folderRow(for: folder, indent: 0)
                        }
                    } header: {
                        Text(NSLocalizedString("folderMoveDestination.selectDestination", comment: "Select Destination"))
                    }
                }
                
                // Empty state
                if siblingFolders.isEmpty && !showRootLevelOption {
                    emptyStateView
                }
            }
            .navigationTitle(titleText)
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
    }
    
    // MARK: - View Builders
    
    /// Recursive folder row with children
    private func folderRow(for folder: Folder, indent: Int) -> AnyView {
        let subfolders = (folder.folders ?? [])
            .filter { isValidDestination($0) }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
        
        return AnyView(
            Group {
                folderButton(for: folder, indent: indent)
                
                ForEach(subfolders) { subfolder in
                    self.folderRow(for: subfolder, indent: indent + 1)
                }
            }
        )
    }
    
    /// Button for each folder destination
    @ViewBuilder
    private func folderButton(for folder: Folder, indent: Int) -> some View {
        Button {
            onDestinationSelected(folder)
            dismiss()
        } label: {
            HStack(spacing: 8) {
                // Indentation
                if indent > 0 {
                    ForEach(0..<indent, id: \.self) { _ in
                        Color.clear.frame(width: 20)
                    }
                }
                
                Image(systemName: "folder")
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.name ?? NSLocalizedString("folderList.untitledFolder", comment: "Untitled"))
                        .font(.body)
                    
                    let fileCount = folder.textFiles?.count ?? 0
                    let folderCount = folder.folders?.count ?? 0
                    if fileCount > 0 || folderCount > 0 {
                        Text(itemCountText(files: fileCount, folders: folderCount))
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
    
    /// Empty state when no valid destinations
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text(NSLocalizedString("folderMoveDestination.noFolders.title", comment: "No Valid Destinations"))
                .font(.headline)
            
            Text(NSLocalizedString("folderMoveDestination.noFolders.message", comment: "No folders available"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Helpers
    
    /// Check if a folder is a valid destination
    private func isValidDestination(_ folder: Folder) -> Bool {
        // Never show Trash as a destination
        if folder.name == "Trash" {
            return false
        }
        
        // Can't move to current folder
        if folder.id == currentFolder.id {
            return false
        }
        
        // If moving a folder, can't move to itself or its descendants
        if let moving = folderToMove {
            if folder.id == moving.id {
                return false
            }
            if isDescendant(folder, of: moving) {
                return false
            }
        }
        
        return true
    }
    
    /// Check if potentialDescendant is a descendant of ancestor
    private func isDescendant(_ potentialDescendant: Folder, of ancestor: Folder) -> Bool {
        var current: Folder? = potentialDescendant.parentFolder
        while let parent = current {
            if parent.id == ancestor.id {
                return true
            }
            current = parent.parentFolder
        }
        return false
    }
    
    /// Format item count text
    private func itemCountText(files: Int, folders: Int) -> String {
        var parts: [String] = []
        if files > 0 {
            parts.append("\(files) \(files == 1 ? "file" : "files")")
        }
        if folders > 0 {
            parts.append("\(folders) \(folders == 1 ? "folder" : "folders")")
        }
        return parts.joined(separator: ", ")
    }
}
