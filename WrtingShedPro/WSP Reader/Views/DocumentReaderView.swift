//
//  DocumentReaderView.swift
//  WSP Reader
//
//  Main document reading view with sidebar and content.
//  Feature 026: WSP Reader App
//

import SwiftUI

struct DocumentReaderView: View {
    @Environment(ReaderAppState.self) var appState
    var document: WSPDocument
    
    @State private var selectedFile: WSPReaderFile?
    @State private var showSidebar: Bool = true
    @State private var searchText: String = ""
    @State private var showSearch: Bool = false
    @State private var showDocumentInfo: Bool = false
    @State private var showManuscriptSheet: Bool = false
    
    var body: some View {
        NavigationSplitView(columnVisibility: .constant(showSidebar ? .all : .detailOnly)) {
            sidebarContent
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            toolbarContent
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showSearch) {
            SearchView(document: document, isPresented: $showSearch, selectedFile: $selectedFile)
        }
        .sheet(isPresented: $showDocumentInfo) {
            DocumentInfoView(document: document)
        }
        .sheet(isPresented: $showManuscriptSheet) {
            NavigationStack {
                ManuscriptReaderView(
                    title: document.manuscriptPreviewTitle,
                    files: document.manuscriptPreviewFiles,
                    fontSize: appState.fontSize,
                    onNavigateToFile: navigateToFile
                )
                .navigationTitle("Manuscript")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showManuscriptSheet = false }
                    }
                }
            }
        }
    }
    
    // MARK: - Sidebar
    
    @ViewBuilder
    private var sidebarContent: some View {
        if document.isManualProject {
            // Manual projects use special TOC navigation
            ManualNavigationView(document: document, selectedFile: $selectedFile)
        } else {
            // Standard projects use folder/file list
            standardSidebar
        }
    }
    
    @ViewBuilder
    private var standardSidebar: some View {
        List(selection: $selectedFile) {
            // Project header
            Section {
                HStack {
                    Image(systemName: projectIcon)
                        .foregroundStyle(.brown)
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        Text(document.projectName)
                            .font(.headline)
                        
                        Text(projectTypeLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Reader") {
                Button {
                    appState.showFilePicker = true
                } label: {
                    Label("Open Another Project", systemImage: "folder.badge.plus")
                }

                Button {
                    showManuscriptSheet = true
                } label: {
                    Label("View Manuscript", systemImage: "eye")
                }
            }
            
            // Primary work folders only (container + file folder)
            Section("Folders") {
                ForEach(document.readerPrimaryFolders) { folder in
                    FolderSection(folder: folder, selectedFile: $selectedFile)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Contents")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .searchable(text: $searchText, prompt: "Search files")
    }
    
    // MARK: - Detail
    
    @ViewBuilder
    private var detailContent: some View {
        if let file = selectedFile {
            FileReaderView(
                file: file, 
                fontSize: appState.fontSize,
                onNavigateToFile: navigateToFile
            )
        } else {
            ContentUnavailableView(
                "Select a File",
                systemImage: "doc.text",
                description: Text("Choose a file from the sidebar to read")
            )
        }
    }
    
    // MARK: - Navigation
    
    private func navigateToFile(_ fileId: String) {
        // Find file by ID anywhere in the document
        if let file = document.findFile(byId: fileId) {
            showManuscriptSheet = false
            selectedFile = file
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            HStack {
                Button {
                    appState.showFilePicker = true
                } label: {
                    Label("Open", systemImage: "folder.badge.plus")
                }

                Button("Close") {
                    appState.closeDocument()
                }
            }
        }
        
        #if os(iOS)
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                // Full-screen reading toggle
                Button {
                    withAnimation {
                        showSidebar.toggle()
                    }
                } label: {
                    Label(showSidebar ? "Full Screen Reading" : "Show Contents", 
                          systemImage: showSidebar ? "arrow.up.left.and.arrow.down.right" : "sidebar.left")
                }
                
                Divider()
                
                fontSizeControls
                
                Divider()
                
                Button {
                    showSearch.toggle()
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                
                Divider()

                Button {
                    showManuscriptSheet = true
                } label: {
                    Label("View Manuscript", systemImage: "eye")
                }

                Divider()
                
                Button {
                    showDocumentInfo = true
                } label: {
                    Label("Document Info", systemImage: "info.circle")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        #else
        ToolbarItemGroup(placement: .automatic) {
            Button {
                appState.showFilePicker = true
            } label: {
                Image(systemName: "folder.badge.plus")
            }
            .help("Open Another Project")

            Button {
                withAnimation {
                    showSidebar.toggle()
                }
            } label: {
                Image(systemName: showSidebar ? "sidebar.left" : "sidebar.leading")
            }
            .help(showSidebar ? "Hide Sidebar" : "Show Sidebar")

            Button {
                showManuscriptSheet = true
            } label: {
                Image(systemName: "eye")
            }
            .help("View Manuscript")
            
            fontSizeControls
            
            Button {
                showSearch.toggle()
            } label: {
                Image(systemName: "magnifyingglass")
            }
            
            Button {
                showDocumentInfo = true
            } label: {
                Image(systemName: "info.circle")
            }
        }
        #endif
    }
    
    @ViewBuilder
    private var fontSizeControls: some View {
        Button {
            appState.fontSize = max(12, appState.fontSize - 2)
        } label: {
            Label("Smaller", systemImage: "textformat.size.smaller")
        }
        
        Button {
            appState.fontSize = min(32, appState.fontSize + 2)
        } label: {
            Label("Larger", systemImage: "textformat.size.larger")
        }
        
        Button {
            appState.fontSize = 16
        } label: {
            Label("Reset Size", systemImage: "arrow.counterclockwise")
        }
    }
    
    // MARK: - Helpers
    
    private var projectIcon: String {
        switch document.projectType {
        case "poetry": return "text.quote"
        case "shortFiction", "fiction": return "book"
        case "drama": return "theatermasks"
        case "manual": return "books.vertical"
        default: return "doc.text"
        }
    }
    
    private var projectTypeLabel: String {
        switch document.projectType {
        case "poetry": return "Poetry"
        case "shortFiction": return "Short Fiction"
        case "fiction": return "Fiction"
        case "drama": return "Drama"
        case "manual": return "Manual"
        case "prose": return "Prose"
        default: return "Document"
        }
    }
}

// MARK: - Manuscript Reader

struct ManuscriptReaderView: View {
    let title: String
    let files: [WSPReaderFile]
    let fontSize: CGFloat
    var onNavigateToFile: ((String) -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)

                if files.isEmpty {
                    ContentUnavailableView(
                        "No Manuscript Content",
                        systemImage: "doc.text",
                        description: Text("No files are marked for manuscript inclusion.")
                    )
                } else {
                    ForEach(files) { file in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(file.name)
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            AttributedTextView(
                                attributedString: scaledContent(for: file),
                                fontSize: fontSize,
                                onLinkTap: handleLinkTap
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.bottom, 12)

                        if file.id != files.last?.id {
                            Divider()
                                .padding(.bottom, 8)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: 760, alignment: .leading)
        }
    }

    private func scaledContent(for file: WSPReaderFile) -> NSAttributedString {
        let original = file.attributedContent
        let mutable = NSMutableAttributedString(attributedString: original)

        mutable.enumerateAttribute(.font, in: NSRange(location: 0, length: mutable.length)) { value, range, _ in
            #if canImport(UIKit)
            if let font = value as? UIFont {
                let scaleFactor = fontSize / 16.0
                let newSize = font.pointSize * scaleFactor
                let newFont = font.withSize(newSize)
                mutable.addAttribute(.font, value: newFont, range: range)
            }
            #elseif canImport(AppKit)
            if let font = value as? NSFont {
                let scaleFactor = fontSize / 16.0
                let newSize = font.pointSize * scaleFactor
                let newFont = NSFont(descriptor: font.fontDescriptor, size: newSize) ?? NSFont.systemFont(ofSize: newSize)
                mutable.addAttribute(.font, value: newFont, range: range)
            }
            #endif
        }

        return mutable
    }

    private func handleLinkTap(_ url: URL) -> Bool {
        if url.scheme == "wsp" {
            onNavigateToFile?(url.lastPathComponent)
            return true
        }

        if url.absoluteString.contains("file-reference:") {
            let fileId = url.absoluteString.replacingOccurrences(of: "file-reference:", with: "")
            onNavigateToFile?(fileId)
            return true
        }

        return false
    }
}

// MARK: - Folder Section

struct FolderSection: View {
    let folder: WSPReaderFolder
    @Binding var selectedFile: WSPReaderFile?

    @State private var isExpanded: Bool = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(folder.files) { file in
                FileRow(file: file, isSelected: selectedFile?.id == file.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedFile = file
                    }
            }

            ForEach(folder.subfolders) { subfolder in
                FolderSection(folder: subfolder, selectedFile: $selectedFile)
            }
        } label: {
            Label(folder.name, systemImage: folder.iconName)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - File Row

struct FileRow: View {
    let file: WSPReaderFile
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundStyle(isSelected ? .white : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)

                Text("\(file.wordCount) words")
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }

            if let status = file.workflowStatus, !status.isEmpty {
                Text(status.capitalized)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
                    .foregroundStyle(isSelected ? .white : .secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor : Color.clear)
        .cornerRadius(6)
    }
}

#Preview {
    Text("Document Reader Preview")
}
