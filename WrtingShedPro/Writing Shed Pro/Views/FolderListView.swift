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
                "All", "Draft", "Ready", "Collections", "Set Aside", "Published",
                "Research",
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
                    // Special handling for Trash folder
                    if folder.name == "Trash" {
                        NavigationLink(destination: TrashView(project: project)) {
                            FolderRowView(folder: folder)
                        }
                    } else {
                        // Check if this is a publication folder (Magazines, Competitions, Commissions, Other)
                        let folderName = folder.name ?? ""
                        if let publicationType = publicationTypeForFolder(folderName) {
                            // Navigate to publications list filtered by type
                            NavigationLink(destination: PublicationsListView(project: project, publicationType: publicationType)) {
                                FolderRowView(folder: folder)
                            }
                        } else if folderName == "Collections" {
                            // Special handling for Collections folder - show Collections (Submissions)
                            NavigationLink(destination: CollectionsView(project: project)) {
                                FolderRowView(folder: folder)
                            }
                        } else {
                            // Navigate to subfolders OR to file list based on folder capabilities
                            let canAddFolder = FolderCapabilityService.canAddSubfolder(to: folder)
                            let _ = FolderCapabilityService.canAddFile(to: folder)
                            
                            if canAddFolder {
                                // This folder contains subfolders - navigate to FolderListView
                                NavigationLink(destination: FolderListView(project: project, selectedFolder: folder)) {
                                    FolderRowView(folder: folder)
                                }
                            } else {
                                // This folder contains files - navigate to FolderFilesView
                                NavigationLink(destination: FolderFilesView(folder: folder)) {
                                    FolderRowView(folder: folder)
                                }
                            }
                        }
                    }
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
                            let _ = FolderCapabilityService.canAddFile(to: subfolder)
                            
                            if canAddFolder {
                                // This folder contains subfolders - navigate to FolderListView
                                NavigationLink(destination: FolderListView(project: project, selectedFolder: subfolder)) {
                                    FolderRowView(folder: subfolder)
                                }
                            } else {
                                // This folder contains files - navigate to FolderFilesView
                                NavigationLink(destination: FolderFilesView(folder: subfolder)) {
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
    
    // Helper function to map folder names to publication types
    private func publicationTypeForFolder(_ folderName: String) -> PublicationType? {
        switch folderName {
        case "Magazines":
            return .magazine
        case "Competitions":
            return .competition
        case "Commissions":
            return .commission
        case "Other":
            return .other
        default:
            return nil
        }
    }
}



// MARK: - Folder Row View

struct FolderRowView: View {
    let folder: Folder
    
    @Query private var allPublications: [Publication]
    @Query private var allSubmissions: [Submission]
    @Query private var allFolders: [Folder]
    @Query private var allTrashItems: [TrashItem]
    
    @State private var fileCount: Int = 0
    @State private var subfolderCount: Int = 0
    
    // Check if this is a publication folder
    private var isPublicationFolder: Bool {
        let name = folder.name ?? ""
        return ["Magazines", "Competitions", "Commissions", "Other"].contains(name)
    }
    
    // Check if this is the Collections folder
    private var isCollectionsFolder: Bool {
        let name = folder.name ?? ""
        return name == "Collections"
    }
    
    // Check if this is the All folder (virtual folder)
    private var isAllFolder: Bool {
        let name = folder.name ?? ""
        return name == "All"
    }
    
    // Check if this is the Trash folder
    private var isTrashFolder: Bool {
        let name = folder.name ?? ""
        return name == "Trash"
    }
    
    // Get collection count for Collections folder
    private var collectionCount: Int {
        guard isCollectionsFolder, let project = folder.project else { return 0 }
        
        return allSubmissions.filter { submission in
            submission.publication == nil && submission.project?.id == project.id
        }.count
    }
    
    // Get publication count for this folder type
    private var publicationCount: Int {
        guard isPublicationFolder, let project = folder.project else { return 0 }
        
        let folderName = folder.name ?? ""
        var publicationType: PublicationType?
        
        switch folderName {
        case "Magazines":
            publicationType = .magazine
        case "Competitions":
            publicationType = .competition
        case "Commissions":
            publicationType = .commission
        case "Other":
            publicationType = .other
        default:
            return 0
        }
        
        return allPublications.filter { pub in
            pub.project?.id == project.id && pub.type == publicationType
        }.count
    }
    
    // Folder display name with count in brackets
    private var folderDisplayName: String {
        let baseName = folder.name ?? NSLocalizedString("folderList.untitledFolder", comment: "Untitled folder")
        let count: Int
        
        if isPublicationFolder {
            count = publicationCount
        } else if isCollectionsFolder {
            count = collectionCount
        } else if isAllFolder {
            // All folder shows computed count from multiple folders
            count = fileCount  // Will be computed in .task
        } else if isTrashFolder {
            // Trash folder shows count of TrashItem objects
            count = fileCount  // Will be computed in .task
        } else if subfolderCount > 0 && fileCount > 0 {
            count = subfolderCount + fileCount
        } else if subfolderCount > 0 {
            count = subfolderCount
        } else {
            count = fileCount
        }
        
        return "\(baseName) (\(count))"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: folderIcon)
                .foregroundStyle(.blue)
                .font(.title2)
                .accessibilityHidden(true)
            
            // Show folder name with count in brackets
            Text(folderDisplayName)
                .font(.body)
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .task {
            if isAllFolder, let project = folder.project {
                // For "All" folder, compute total files from target folders
                let projectFolders = allFolders.filter { $0.project?.id == project.id }
                let targetFolderNames = ["Draft", "Ready", "Set Aside", "Published"]
                
                var totalCount = 0
                for folder in projectFolders where targetFolderNames.contains(folder.name ?? "") {
                    totalCount += folder.textFiles?.count ?? 0
                }
                fileCount = totalCount
                subfolderCount = 0
            } else if isTrashFolder, let project = folder.project {
                // For "Trash" folder, count TrashItem objects (not files in folder)
                fileCount = allTrashItems.filter { $0.project?.id == project.id }.count
                subfolderCount = 0
            } else {
                fileCount = folder.textFiles?.count ?? 0
                subfolderCount = folder.folders?.count ?? 0
            }
        }
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
        case "Collections":
            return "tray.2"
        case "Set Aside":
            return "archivebox"
        case "Published":
            return "book.circle"
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
            if fileCount > 0 {
                return "folder.fill"
            } else {
                return "folder"
            }
        }
    }
    
    private var accessibilityLabel: String {
        return folderDisplayName
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
