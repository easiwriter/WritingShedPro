import SwiftUI
import SwiftData

struct FolderListView: View {
    let project: Project
    let selectedFolder: Folder?
    
    @Environment(\.modelContext) var modelContext
    @State private var showAddFolderSheet = false
    
    init(project: Project, selectedFolder: Folder? = nil) {
        self.project = project
        self.selectedFolder = selectedFolder
    }
    
    // Get all project folders in the correct order (not alphabetically!)
    var projectFolders: [Folder] {
        let folders = project.folders ?? []
        let order = folderOrderForProjectType(project.type)
        
        // Sort folders by predefined order
        return folders.sorted { folder1, folder2 in
            let name1 = folder1.name ?? ""
            let name2 = folder2.name ?? ""
            let index1 = order.firstIndex(of: name1) ?? Int.max
            let index2 = order.firstIndex(of: name2) ?? Int.max
            return index1 < index2
        }
    }
    
    // Define the display order for each project type
    private func folderOrderForProjectType(_ type: ProjectType) -> [String] {
        switch type {
        case .blank:
            return ["Files", "Trash"]
            
        case .poetry, .shortStory:
            return [
                "All", "Draft", "Ready", "Set Aside", "Published",
                "Collections", "Submissions", "Research",
                "Magazines", "Competitions", "Commissions", "Other",
                "Trash"
            ]
            
        case .novel:
            return [
                "Novel", "Chapters", "Scenes", "Characters", "Locations",
                "Set Aside", "Research",
                "Competitions", "Commissions", "Other",
                "Trash"
            ]
            
        case .script:
            return [
                "Script", "Acts", "Scenes", "Characters", "Locations",
                "Set Aside", "Research",
                "Competitions", "Commissions", "Other",
                "Trash"
            ]
        }
    }
    
    // Determines if spacing should be added after this folder
    private func shouldAddSpacingAfter(folder: Folder) -> Bool {
        // Don't add spacing for blank projects
        guard project.type != .blank else { return false }
        
        let folderName = folder.name ?? ""
        
        // Add spacing after "Research" (separates writing folders from organizational folders)
        // and after "Other" (separates organizational folders from Trash)
        return folderName == "Research" || folderName == "Other"
    }
    
    // Get subfolders for the selected folder
    var currentSubfolders: [Folder] {
        guard let selectedFolder = selectedFolder else { return [] }
        return (selectedFolder.folders ?? []).sorted(by: { ($0.name ?? "") < ($1.name ?? "") })
    }
    
    var body: some View {
        List {
            if selectedFolder == nil {
                // Show all project folders in a simple list
                ForEach(projectFolders) { folder in
                    // Navigate to subfolders OR to file list based on folder capabilities
                    let canAddFolder = FolderCapabilityService.canAddSubfolder(to: folder)
                    let canAddFile = FolderCapabilityService.canAddFile(to: folder)
                    
                    if canAddFolder {
                        // This folder contains subfolders - navigate to FolderListView
                        NavigationLink(destination: FolderListView(project: project, selectedFolder: folder)) {
                            FolderRowView(folder: folder)
                        }
                    } else if canAddFile {
                        // This folder contains files - navigate to FileEditableList
                        NavigationLink(destination: FileEditableList(folder: folder)) {
                            FolderRowView(folder: folder)
                        }
                    } else {
                        // Read-only folder - navigate to FileEditableList
                        NavigationLink(destination: FileEditableList(folder: folder)) {
                            FolderRowView(folder: folder)
                        }
                    }
                    
                    // Add spacing before Trash folder (except for blank projects)
                    if shouldAddSpacingAfter(folder: folder) {
                        Divider()
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    }
                }
            } else {
                // Show subfolders if any exist
                if !currentSubfolders.isEmpty {
                    Section {
                        ForEach(currentSubfolders) { subfolder in
                            // Navigate to subfolders OR to file list based on folder capabilities
                            let canAddFolder = FolderCapabilityService.canAddSubfolder(to: subfolder)
                            let canAddFile = FolderCapabilityService.canAddFile(to: subfolder)
                            
                            if canAddFolder {
                                // This folder contains subfolders - navigate to FolderListView
                                NavigationLink(destination: FolderListView(project: project, selectedFolder: subfolder)) {
                                    FolderRowView(folder: subfolder)
                                }
                            } else if canAddFile {
                                // This folder contains files - navigate to FileEditableList
                                NavigationLink(destination: FileEditableList(folder: subfolder)) {
                                    FolderRowView(folder: subfolder)
                                }
                            } else {
                                // Read-only folder - navigate to FileEditableList
                                NavigationLink(destination: FileEditableList(folder: subfolder)) {
                                    FolderRowView(folder: subfolder)
                                }
                            }
                        }
                    } header: {
                        Text(NSLocalizedString("folderList.foldersHeader", comment: "Folders section header"))
                    }
                }
                
                // Show empty state only if no subfolders
                if currentSubfolders.isEmpty {
                    EmptyFolderView(folder: selectedFolder!)
                }
            }
        }
        .navigationTitle(selectedFolder?.name ?? project.name ?? "Folders")
        .navigationBarTitleDisplayMode(selectedFolder == nil ? .large : .inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // Show add button for folders only
                if let selectedFolder = selectedFolder {
                    let canAddFolder = FolderCapabilityService.canAddSubfolder(to: selectedFolder)
                    
                    if canAddFolder {
                        Button(action: { showAddFolderSheet = true }) {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel(NSLocalizedString("folderList.addFolder", comment: "Add folder button"))
                    }
                }
            }
        }
        .sheet(isPresented: $showAddFolderSheet) {
            AddFolderSheet(
                isPresented: $showAddFolderSheet,
                project: project,
                parentFolder: selectedFolder,
                existingFolders: selectedFolder != nil ? currentSubfolders : projectFolders
            )
        }
    }
}



// MARK: - Folder Row View

struct FolderRowView: View {
    let folder: Folder
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: folderIcon)
                .foregroundStyle(.blue)
                .font(.title2)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(folder.name ?? NSLocalizedString("folderList.untitledFolder", comment: "Untitled folder"))
                    .font(.body)
                
                if let count = folderContentCount {
                    Text(count)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
    
    private var folderIcon: String {
        let name = folder.name ?? ""
        
        // Root level folder icons
        if name.contains("Your") {
            return "globe"
        } else if name == "Publications" {
            return "suitcase.cart"
        } else if name == "Trash" {
            return "trash"
        }
        
        // Type-specific subfolder icons
        switch name {
        case "All":
            return "globe"
        case "Files":
            return "globe"
        case "Draft":
            return "doc.badge.ellipsis"
        case "Ready":
            return "checkmark.circle"
        case "Set Aside":
            return "archivebox"
        case "Published":
            return "book.circle"
        case "Collections":
            return "books.vertical"
        case "Submissions":
            return "paperplane"
        case "Research":
            return "magnifyingglass"
        case "Magazines":
            return "magazine"
        case "Competitions":
            return "medal"
        case "Commissions":
            return "person.2"
        case "Other":
            return "tray"
        // Novel-specific folders
        case "Novel":
            return "book.closed.fill"
        case "Chapters":
            return "document.on.document"
        case "Scenes":
            return "document.badge.plus"
        case "Characters":
            return "person.circle"
        case "Locations":
            return "mountain.2"
        // Script-specific folders  
        case "Script":
            return "book.closed.fill"
        case "Acts":
            return "document.on.document"
        default:
            let fileCount = folder.files?.count ?? 0
            
            if fileCount > 0 {
                return "folder.fill"
            } else {
                return "folder"
            }
        }
    }
    
    private var folderContentCount: String? {
        let fileCount = folder.files?.count ?? 0
        let subfolderCount = folder.folders?.count ?? 0
        
        if subfolderCount > 0 && fileCount > 0 {
            let format = NSLocalizedString("folderList.mixedCount", comment: "Folder and file count")
            return String(format: format, subfolderCount, fileCount)
        } else if subfolderCount > 0 {
            let format = NSLocalizedString("folderList.folderCount", comment: "Folder count")
            return String(format: format, subfolderCount)
        } else if fileCount > 0 {
            let format = NSLocalizedString("folderList.fileCount", comment: "File count")
            return String(format: format, fileCount)
        } else {
            return nil
        }
    }
    
    private var accessibilityLabel: String {
        var label = folder.name ?? NSLocalizedString("folderList.untitledFolder", comment: "Untitled folder")
        
        if let content = folderContentCount {
            label += ". \(content)"
        }
        
        return label
    }
}

// MARK: - Empty State View

struct EmptyFolderView: View {
    let folder: Folder
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text(NSLocalizedString("folderList.emptyFolder", comment: "Empty folder message"))
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Text(NSLocalizedString("folderList.tapAddContentHint", comment: "Tap + to add content hint"))
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .listRowBackground(Color.clear)
    }
}
