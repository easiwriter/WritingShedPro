import SwiftUI
import SwiftData

struct FolderListView: View {
    let project: Project
    let selectedFolder: Folder?
    
    @Environment(\.modelContext) var modelContext
    @State private var showAddFolderSheet = false
    @State private var showAddFileSheet = false
    
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
            return ["All", "Trash"]
            
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
    
    // Get files for the selected folder
    var currentFiles: [File] {
        guard let selectedFolder = selectedFolder else { return [] }
        return (selectedFolder.files ?? []).sorted(by: { ($0.name ?? "") < ($1.name ?? "") })
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
                    NavigationLink(destination: FolderListView(project: project, selectedFolder: folder)) {
                        FolderRowView(folder: folder)
                    }
                }
            } else {
                // Show subfolders if any exist
                if !currentSubfolders.isEmpty {
                    Section {
                        ForEach(currentSubfolders) { subfolder in
                            NavigationLink(destination: FolderListView(project: project, selectedFolder: subfolder)) {
                                FolderRowView(folder: subfolder)
                            }
                        }
                    } header: {
                        Text(NSLocalizedString("folderList.foldersHeader", comment: "Folders section header"))
                    }
                }
                
                // Show files within the selected folder
                if !currentFiles.isEmpty {
                    Section {
                        ForEach(currentFiles) { file in
                            FileRowView(file: file)
                        }
                    } header: {
                        Text(NSLocalizedString("folderList.filesHeader", comment: "Files section header"))
                    }
                }
                
                // Show empty state only if no subfolders and no files
                if currentSubfolders.isEmpty && currentFiles.isEmpty {
                    EmptyFolderView(folder: selectedFolder!)
                }
            }
        }
        .navigationTitle(selectedFolder?.name ?? project.name ?? "Folders")
        .navigationBarTitleDisplayMode(selectedFolder == nil ? .large : .inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // Show add buttons based on folder capabilities
                if let selectedFolder = selectedFolder {
                    let canAddFolder = FolderCapabilityService.canAddSubfolder(to: selectedFolder)
                    let canAddFile = FolderCapabilityService.canAddFile(to: selectedFolder)
                    
                    if canAddFolder && canAddFile {
                        // Both operations allowed - show menu
                        Menu {
                            Button(action: { showAddFolderSheet = true }) {
                                Label(NSLocalizedString("folderList.addFolder", comment: "Add folder button"), systemImage: "folder.badge.plus")
                            }
                            
                            Button(action: { showAddFileSheet = true }) {
                                Label(NSLocalizedString("folderList.addFile", comment: "Add file button"), systemImage: "doc.badge.plus")
                            }
                        } label: {
                            Image(systemName: "plus")
                                .accessibilityHidden(true)
                        }
                        .accessibilityLabel(NSLocalizedString("folderList.addAccessibility", comment: "Add button"))
                        .accessibilityHint("Double tap to add a folder or file")
                    } else if canAddFolder {
                        // Only folders allowed
                        Button(action: { showAddFolderSheet = true }) {
                            Image(systemName: "folder.badge.plus")
                        }
                        .accessibilityLabel(NSLocalizedString("folderList.addFolder", comment: "Add folder button"))
                    } else if canAddFile {
                        // Only files allowed
                        Button(action: { showAddFileSheet = true }) {
                            Image(systemName: "doc.badge.plus")
                        }
                        .accessibilityLabel(NSLocalizedString("folderList.addFile", comment: "Add file button"))
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
        .sheet(isPresented: $showAddFileSheet) {
            if let selectedFolder = selectedFolder {
                AddFileSheet(
                    isPresented: $showAddFileSheet,
                    parentFolder: selectedFolder,
                    existingFiles: currentFiles
                )
            }
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

// MARK: - File Row View

struct FileRowView: View {
    let file: File
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .foregroundStyle(.gray)
                .font(.title2)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name ?? NSLocalizedString("folderList.untitledFile", comment: "Untitled file"))
                    .font(.body)
                
                if let content = file.content, !content.isEmpty {
                    Text(contentPreview(content))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(file.name ?? NSLocalizedString("folderList.untitledFile", comment: "Untitled file"))
    }
    
    private func contentPreview(_ content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? NSLocalizedString("folderList.emptyFile", comment: "Empty file") : trimmed
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
