import SwiftUI
import SwiftData

/// A simplified folder list view using reusable components
struct SimpleFolderListView: View {
    let project: Project
    let parentFolder: Folder?
    
    @Environment(\.modelContext) var modelContext
    @State private var showAddFolderSheet = false
    @State private var showAddFileSheet = false
    
    init(project: Project, parentFolder: Folder? = nil) {
        self.project = project
        self.parentFolder = parentFolder
    }
    
    // Use direct properties instead of predicates
    var currentFolders: [Folder] {
        if let parentFolder = parentFolder {
            return (parentFolder.folders ?? []).sorted(by: { ($0.name ?? "") < ($1.name ?? "") })
        } else {
            return (project.folders ?? []).sorted(by: { ($0.name ?? "") < ($1.name ?? "") })
        }
    }
    
    var currentFiles: [File] {
        if let parentFolder = parentFolder {
            return (parentFolder.files ?? []).sorted(by: { ($0.name ?? "") < ($1.name ?? "") })
        } else {
            return []  // Root level has no files
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Folders Section
            if !currentFolders.isEmpty {
                FolderEditableList(folders: currentFolders, project: project)
            }
            
            // Files Section (only if we're in a subfolder)
            if parentFolder != nil && !currentFiles.isEmpty {
                FileEditableList(files: currentFiles)
            }
            
            // Empty state
            if currentFolders.isEmpty && currentFiles.isEmpty {
                EmptyFolderContentView(parentFolder: parentFolder)
            }
        }
        .navigationTitle(parentFolder?.name ?? project.name ?? "Folders")
        .navigationBarTitleDisplayMode(parentFolder == nil ? .large : .inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { showAddFolderSheet = true }) {
                        Label(NSLocalizedString("folderList.addFolder", comment: "Add folder button"), systemImage: "folder.badge.plus")
                    }
                    
                    if parentFolder != nil {
                        Button(action: { showAddFileSheet = true }) {
                            Label(NSLocalizedString("folderList.addFile", comment: "Add file button"), systemImage: "doc.badge.plus")
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .accessibilityHidden(true)
                }
                .accessibilityLabel(NSLocalizedString("folderList.addAccessibility", comment: "Add button"))
                .accessibilityHint("Double tap to add a folder or file")
            }
        }
        .sheet(isPresented: $showAddFolderSheet) {
            AddFolderSheet(
                isPresented: $showAddFolderSheet,
                project: project,
                parentFolder: parentFolder,
                existingFolders: currentFolders
            )
        }
        .sheet(isPresented: $showAddFileSheet) {
            if let parentFolder = parentFolder {
                AddFileSheet(
                    isPresented: $showAddFileSheet,
                    parentFolder: parentFolder,
                    existingFiles: currentFiles
                )
            }
        }
    }
}

/// Empty state view for folders
struct EmptyFolderContentView: View {
    let parentFolder: Folder?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: parentFolder == nil ? "folder" : "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text(parentFolder == nil ? 
                 NSLocalizedString("folderList.emptyProject", comment: "This project has no folders yet") :
                 NSLocalizedString("folderList.emptyFolder", comment: "This folder is empty"))
                .font(.headline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}