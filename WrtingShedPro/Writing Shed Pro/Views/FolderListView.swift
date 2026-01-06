import SwiftUI
import SwiftData

struct FolderListView: View {
    let project: Project
    let selectedFolder: Folder?
    
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showAddFolderSheet = false
    @State private var isLoadingFolders = true
    @State private var loadedFolders: [Folder] = []
    
    init(project: Project, selectedFolder: Folder? = nil) {
        self.project = project
        self.selectedFolder = selectedFolder
    }
    
    // Get all project folders in the correct order (not alphabetically!)
    var projectFolders: [Folder] {
        guard !isLoadingFolders else { return [] }
        let order = folderOrderForProjectType(project.type)
        
        // Filter to only top-level folders (no parent folder)
        let topLevelFolders = loadedFolders.filter { $0.parentFolder == nil }
        
        // Sort folders by predefined order
        return topLevelFolders.sorted { folder1, folder2 in
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
        case .generalPurpose:
            return ["Folders", "Trash"]
            
        case .poetry:
            return [
                // Workflow folders
                "All", "Draft", "Ready", "Submissions", "Set Aside", "Published", "Collections", "Manuscript",
                // Support
                "Research",
                // Publications
                "Magazines", "Competitions", "Commissions", "Other",
                // System
                "Trash"
            ]
            
        case .fiction:
            // Fiction folder order - Feature 022
            // Order: Workflow → Entity → Research → Publications → Trash
            // Publications vary by fiction class (Novel vs Short Fiction)
            return [
                // Workflow folders
                "All", "Draft", "Ready", "Submissions", "Set Aside",
                // Entity folders
                "Characters", "Locations", "Chapters", "Plot",
                // Support
                "Research",
                // Publications (all possible - some may not exist based on fiction class)
                "Publishers", "Agents", "Magazines", "Competitions", "Other",
                // System
                "Trash"
            ]
            
        case .drama:
            // Drama folder order - to be defined in spec 023
            return [
                // Workflow folders
                "All", "Draft", "Ready", "Set Aside",
                // Support
                "Research",
                // Publications
                "Competitions", "Commissions", "Other",
                // System
                "Trash"
            ]
        }
    }
    
    // Determines if spacing should be added after this folder
    private func shouldAddSpacingAfter(folder: Folder) -> Bool {
        // Don't add spacing for general purpose projects
        guard project.type != .generalPurpose else { return false }
        
        let folderName = folder.name ?? ""
        
        // Add spacing after "Research" (separates support from publications)
        // and after "Other" (separates publications from Trash)
        // For poetry, add spacing after "Manuscript" (separates workflow from support)
        // For fiction, add spacing after "Plot" (separates entity folders from support)
        if project.type == .poetry {
            return folderName == "Manuscript" || folderName == "Research" || folderName == "Other"
        }
        
        if project.type == .fiction {
            return folderName == "Plot" || folderName == "Research" || folderName == "Other"
        }
        
        return folderName == "Research" || folderName == "Other"
    }
    
    // Get subfolders for the selected folder
    var currentSubfolders: [Folder] {
        guard let selectedFolder = selectedFolder else { return [] }
        return (selectedFolder.folders ?? []).sorted(by: { ($0.name ?? "") < ($1.name ?? "") })
    }
    
    var body: some View {
        Group {
            if isLoadingFolders {
                // Show loading indicator while fetching folders
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                folderListContent
            }
        }
        .navigationTitle(selectedFolder?.name ?? project.name ?? NSLocalizedString("folderList.title", comment: "Folders title"))
        .navigationBarTitleDisplayMode(selectedFolder == nil ? .large : .inline)
        .navigationBarBackButtonHidden(selectedFolder != nil)
        .onPopToRoot {
            // Dismiss this view when pop-to-root is triggered
            dismiss()
        }
        .toolbar {
            // Only show custom back button when viewing a subfolder
            if selectedFolder != nil {
                ToolbarItem(placement: .topBarLeading) {
                    PopToRootBackButton()
                }
            }
        }
        .task {
            // Load folders asynchronously to avoid blocking navigation
            await loadFolders()
        }
    }
    
    @ViewBuilder
    private var folderListContent: some View {
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
                        } else if folderName == "Submissions" {
                            // Special handling for Submissions folder - show publication submissions
                            NavigationLink(destination: SubmissionsView(project: project)) {
                                FolderRowView(folder: folder)
                            }
                        } else if folderName == "Characters" && project.type == .fiction {
                            // Fiction: Characters folder navigates to CharacterListView
                            NavigationLink(destination: CharacterListView(project: project)) {
                                FolderRowView(folder: folder)
                            }
                        } else if folderName == "Locations" && project.type == .fiction {
                            // Fiction: Locations folder navigates to LocationListView
                            NavigationLink(destination: LocationListView(project: project)) {
                                FolderRowView(folder: folder)
                            }
                        } else if folderName == "Plot" && project.type == .fiction {
                            // Fiction: Plot folder navigates to PlotOutlineView
                            NavigationLink(destination: PlotOutlineView(project: project)) {
                                FolderRowView(folder: folder)
                            }
                        } else if folderName == "Chapters" && project.type == .fiction {
                            // Fiction (Novel): Chapters folder navigates to ChapterListView
                            NavigationLink(destination: ChapterListView(project: project)) {
                                FolderRowView(folder: folder)
                            }
                        } else if folderName == "Scenes" && project.type == .fiction {
                            // Fiction (Short Fiction): Scenes folder navigates to SceneListView
                            NavigationLink(destination: SceneListView(project: project)) {
                                FolderRowView(folder: folder)
                            }
                        } else {
                            // Navigate based on folder capabilities
                            let canAddSubfolder = FolderCapabilityService.canAddSubfolder(to: folder)
                            let canAddFile = FolderCapabilityService.canAddFile(to: folder)
                            
                            if canAddFile {
                                // Mixed content or file-only folders - navigate to FolderFilesView
                                // FolderFilesView handles both files and subfolders for mixed-content folders
                                NavigationLink(destination: FolderFilesView(folder: folder)) {
                                    FolderRowView(folder: folder)
                                }
                            } else if canAddSubfolder {
                                // Subfolder-only folders (Chapters, Acts, etc.) - navigate to FolderListView
                                NavigationLink(destination: FolderListView(project: project, selectedFolder: folder)) {
                                    FolderRowView(folder: folder)
                                }
                            } else {
                                // Read-only folders - navigate to FolderFilesView (view-only)
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
                            // Navigate based on folder capabilities
                            let canAddSubfolder = FolderCapabilityService.canAddSubfolder(to: subfolder)
                            let canAddFile = FolderCapabilityService.canAddFile(to: subfolder)
                            
                            if canAddFile {
                                // Mixed content or file-only folders - navigate to FolderFilesView
                                NavigationLink(destination: FolderFilesView(folder: subfolder)) {
                                    FolderRowView(folder: subfolder)
                                }
                            } else if canAddSubfolder {
                                // Subfolder-only folders - navigate to FolderListView
                                NavigationLink(destination: FolderListView(project: project, selectedFolder: subfolder)) {
                                    FolderRowView(folder: subfolder)
                                }
                            } else {
                                // Read-only folders - navigate to FolderFilesView
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // Show add button for folders only
                if let selectedFolder = selectedFolder {
                    let canAddFolder = FolderCapabilityService.canAddSubfolder(to: selectedFolder)
                    
                    if canAddFolder {
                        Button(action: { showAddFolderSheet = true }) {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("folderList.addFolder.accessibility")
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
    
    // Load folders asynchronously to avoid blocking UI
    private func loadFolders() async {
        // Access the folders relationship asynchronously
        loadedFolders = project.folders ?? []
        isLoadingFolders = false
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
    
    // Check if this is the Submissions folder
    private var isSubmissionsFolder: Bool {
        let name = folder.name ?? ""
        return name == "Submissions"
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
            submission.isCollection && submission.project?.id == project.id
        }.count
    }
    
    // Get submission count for Submissions folder
    private var submissionCount: Int {
        guard isSubmissionsFolder, let project = folder.project else { return 0 }
        
        return allSubmissions.filter { submission in
            !submission.isCollection && submission.project?.id == project.id
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
        } else if isSubmissionsFolder {
            count = submissionCount
        } else if isAllFolder {
            // All folder shows computed count from multiple folders
            count = fileCount  // Will be computed in .task
        } else if isTrashFolder {
            // Trash folder shows count of TrashItem objects
            count = fileCount  // Will be computed in .task
        } else if isMixedContentFolder {
            // For mixed-content folders (like "Folders"), show subfolder count only at project level
            count = subfolderCount
        } else if subfolderCount > 0 && fileCount > 0 {
            count = subfolderCount + fileCount
        } else if subfolderCount > 0 {
            count = subfolderCount
        } else {
            count = fileCount
        }
        
        return "\(baseName) (\(count))"
    }
    
    /// Check if this folder supports mixed content (both files and subfolders)
    private var isMixedContentFolder: Bool {
        FolderCapabilityService.canAddSubfolder(to: folder) && FolderCapabilityService.canAddFile(to: folder)
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
        case "Submissions":
            return "paperplane"
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
