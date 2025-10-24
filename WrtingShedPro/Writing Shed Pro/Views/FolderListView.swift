import SwiftUI
import SwiftData

struct FolderListView: View {
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
    
    // Organize root folders into sections
    var rootFolderSections: [(title: String, folders: [Folder])] {
        guard parentFolder == nil else { return [] }
        
        let rootFolders = project.folders ?? []
        let typeFolder = rootFolders.first { ($0.name ?? "").contains("Your") }
        let publicationsFolder = rootFolders.first { $0.name == "Publications" }
        let trashFolder = rootFolders.first { $0.name == "Trash" }
        
        var sections: [(String, [Folder])] = []
        
        if let typeFolder = typeFolder {
            let typeName = (typeFolder.name ?? "Items").replacingOccurrences(of: "Your ", with: "")
            sections.append((typeName.uppercased(), [typeFolder]))
        }
        
        if let publicationsFolder = publicationsFolder {
            sections.append(("PUBLICATIONS", [publicationsFolder]))
        }
        
        if let trashFolder = trashFolder {
            sections.append(("", [trashFolder]))  // Empty string for no header
        }
        
        return sections
    }
    
    var body: some View {
        List {
            // Root level: show all sections with all their contents
            if parentFolder == nil {
                ForEach(rootFolderSections, id: \.title) { section in
                    Section {
                        ForEach(section.folders) { rootFolder in
                            RootFolderSectionContent(folder: rootFolder)
                        }
                    } header: {
                        if !section.title.isEmpty {
                            Text(section.title)
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                    }
                }
            } else {
                // Subfolder level: show all items in this folder in a grouped list
                if let parentFolder = parentFolder {
                    let subfolders = (parentFolder.folders ?? []).sorted(by: { ($0.name ?? "") < ($1.name ?? "") })
                    let files = (parentFolder.files ?? []).sorted(by: { ($0.name ?? "") < ($1.name ?? "") })
                    
                    if !subfolders.isEmpty {
                        Section {
                            ForEach(subfolders) { subfolder in
                                FolderRowView(folder: subfolder)
                            }
                        } header: {
                            Text(NSLocalizedString("folderList.foldersHeader", comment: "Folders section header"))
                        }
                    }
                    
                    if !files.isEmpty {
                        Section {
                            ForEach(files) { file in
                                FileRowView(file: file)
                            }
                        } header: {
                            Text(NSLocalizedString("folderList.filesHeader", comment: "Files section header"))
                        }
                    }
                    
                    if subfolders.isEmpty && files.isEmpty {
                        EmptyFolderView(parentFolder: parentFolder)
                    }
                }
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

// MARK: - Root Folder Section Content

struct RootFolderSectionContent: View {
    let folder: Folder
    
    // Define the desired order for subfolders
    let poetrySubfolderOrder = ["All", "Draft", "Ready", "Set Aside", "Published", "Collections", "Submissions", "Research"]
    let novelSubfolderOrder = ["Novel", "Chapters", "Scenes", "Characters", "Locations", "Set Aside", "Research"]
    let scriptSubfolderOrder = ["Script", "Acts", "Scenes", "Characters", "Locations", "Set Aside", "Research"]
    let publicationsSubfolderOrder = ["Magazines", "Competitions", "Commissions", "Other"]
    
    var orderedSubfolders: [Folder] {
        let subfolders = folder.folders ?? []
        
        // Determine which ordering to use based on parent folder name
        let order: [String]
        if folder.name == "Publications" {
            order = publicationsSubfolderOrder
        } else if folder.name?.contains("NOVEL") == true {
            order = novelSubfolderOrder
        } else if folder.name?.contains("SCRIPT") == true {
            order = scriptSubfolderOrder
        } else {
            // Default to poetry/short story order for "YOUR POETRY" and "YOUR STORIES"
            order = poetrySubfolderOrder
        }
        
        // Return subfolders sorted by the specified order
        return order.compactMap { desiredName in
            subfolders.first { ($0.name ?? "") == desiredName }
        }
    }
    
    var body: some View {
        if folder.name == "Trash" {
            FolderRowView(folder: folder)
        } else {
            let subfolders = orderedSubfolders
            let files = (folder.files ?? []).sorted(by: { ($0.name ?? "") < ($1.name ?? "") })
            
            if !subfolders.isEmpty {
                ForEach(subfolders) { subfolder in
                    HStack(spacing: 16) {
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        FolderRowView(folder: subfolder)
                    }
                }
            }
            
            if !files.isEmpty {
                ForEach(files) { file in
                    HStack(spacing: 16) {
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        FileRowView(file: file)
                    }
                }
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
            let subfolderCount = folder.folders?.count ?? 0
            let fileCount = folder.files?.count ?? 0
            
            if subfolderCount > 0 || fileCount > 0 {
                return "folder.fill"
            } else {
                return "folder"
            }
        }
    }
    
    private var folderContentCount: String? {
        let subfolderCount = folder.folders?.count ?? 0
        let fileCount = folder.files?.count ?? 0
        
        guard subfolderCount > 0 || fileCount > 0 else { return nil }
        
        var parts: [String] = []
        
        if subfolderCount > 0 {
            let format = NSLocalizedString("folderList.folderCount", comment: "Folder count")
            parts.append(String(format: format, subfolderCount))
        }
        
        if fileCount > 0 {
            let format = NSLocalizedString("folderList.fileCount", comment: "File count")
            parts.append(String(format: format, fileCount))
        }
        
        return parts.joined(separator: ", ")
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
    let parentFolder: Folder?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: parentFolder == nil ? "folder" : "doc.text")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text(emptyMessage)
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Text(emptyHint)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .listRowBackground(Color.clear)
    }
    
    private var emptyMessage: String {
        if parentFolder == nil {
            return NSLocalizedString("folderList.noFoldersYet", comment: "No folders message")
        } else {
            return NSLocalizedString("folderList.emptyFolder", comment: "Empty folder message")
        }
    }
    
    private var emptyHint: String {
        if parentFolder == nil {
            return NSLocalizedString("folderList.tapAddFolderHint", comment: "Tap + to add folder hint")
        } else {
            return NSLocalizedString("folderList.tapAddContentHint", comment: "Tap + to add content hint")
        }
    }
}
