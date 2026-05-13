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

    enum DetailSelection: Hashable {
        case file(WSPReaderFile)
        case manuscript
    }

    @State private var selection: DetailSelection?
    @State private var showSidebar: Bool = true
    @State private var showDocumentInfo: Bool = false
    @State private var statusFilter: String = "All"

    // Convenience for code that still needs the selected file
    private var selectedFile: WSPReaderFile? {
        if case .file(let f) = selection { return f }
        return nil
    }

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
        .onAppear {
            restoreSelectionIfNeeded()
        }
        .onChange(of: selection) {
            persistSelection()
        }
        .sheet(isPresented: $showDocumentInfo) {
            DocumentInfoView(document: document, isPresented: $showDocumentInfo)
        }
    }
    
    // MARK: - Sidebar
    
    @ViewBuilder
    private var sidebarContent: some View {
        if document.isManualProject {
            ManualNavigationView(document: document, selectedFile: Binding(
                get: { if case .file(let f) = selection { return f } else { return nil } },
                set: { selection = $0.map { .file($0) } }
            ))
                .navigationTitle(document.projectName)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                #if os(iOS) && !targetEnvironment(macCatalyst)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { appState.closeDocument() } label: {
                            Label("Back", systemImage: "chevron.backward")
                        }
                    }
                }
                #endif
        } else {
            standardSidebar
        }
    }
    
    @ViewBuilder
    private var standardSidebar: some View {
        List(selection: $selection) {
            Section("Reader") {
                Label("View Manuscript", systemImage: "eye")
                    .tag(DetailSelection.manuscript)

                ForEach(document.readerPrimaryFolders) { folder in
                    FolderSection(folder: folder, selection: $selection, statusFilter: statusFilter)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(document.projectName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if availableStatuses.count > 1 {
                statusFilterBar
            }
        }
        #if os(iOS) && !targetEnvironment(macCatalyst)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { appState.closeDocument() } label: {
                    Label("Back", systemImage: "chevron.backward")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showDocumentInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
        #endif
    }

    private var availableStatuses: [String] {
        let statuses = document.readerPrimaryFolders
            .flatMap { collectStatuses(from: $0) }
        let unique = Array(Set(statuses)).sorted()
        return unique.isEmpty ? [] : ["All"] + unique
    }

    private func collectStatuses(from folder: WSPReaderFolder) -> [String] {
        let fileStatuses = folder.files.compactMap { $0.workflowStatus }.filter { !$0.isEmpty }
        let subStatuses = folder.subfolders.flatMap { collectStatuses(from: $0) }
        return fileStatuses + subStatuses
    }

    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "draft":    return Color(UIColor.systemBlue)
        case "ready":    return Color(UIColor.systemGreen)
        case "setaside": return Color(UIColor.systemRed)
        case "all":      return .primary
        default:         return .primary
        }
    }

    private var statusFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableStatuses, id: \.self) { status in
                    let isSelected = statusFilter == status
                    let color = statusColor(for: status)
                    Button {
                        statusFilter = status
                    } label: {
                        Text(status.capitalized)
                            .font(.caption)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isSelected ? color.opacity(0.2) : Color.secondary.opacity(0.12))
                            .foregroundStyle(isSelected ? color : color.opacity(0.7))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(color, lineWidth: isSelected ? 1.5 : 0))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }


    
    // MARK: - Detail
    
    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .file(let file):
            FileReaderView(
                file: file,
                projectType: document.projectType,
                dramaScriptType: document.dramaScriptType,
                fontSize: appState.fontSize,
                onNavigateToFile: navigateToFile,
                onNavigatePrev: { navigateAdjacent(to: file, forward: false) },
                onNavigateNext: { navigateAdjacent(to: file, forward: true) }
            )
        case .manuscript:
            ManuscriptReaderView(
                title: document.manuscriptPreviewTitle,
                files: document.manuscriptPreviewFiles,
                projectType: document.projectType,
                dramaScriptType: document.dramaScriptType,
                fontSize: appState.fontSize,
                onNavigateToFile: navigateToFile
            )
            .navigationTitle("Manuscript")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        case nil:
            ContentUnavailableView(
                "Select a File",
                systemImage: "doc.text",
                description: Text("Choose a file from the sidebar to read")
            )
        }
    }
    
    // MARK: - Navigation
    
    private func navigateToFile(_ fileId: String) {
        if let file = document.findFile(byId: fileId) {
            selection = .file(file)
        }
    }

    private func navigateAdjacent(to file: WSPReaderFile, forward: Bool) {
        if let adjacent = document.adjacentFile(to: file, forward: forward) {
            selection = .file(adjacent)
        }
    }

    private func restoreSelectionIfNeeded() {
        guard selection == nil,
              let fileID = appState.readerSelectionFileID(for: document),
              let file = document.findFile(byId: fileID) else {
            return
        }

        selection = .file(file)
    }

    private func persistSelection() {
        if case .file(let file) = selection {
            appState.storeReaderSelection(fileID: file.id, for: document)
        }
    }

    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if targetEnvironment(macCatalyst)
        ToolbarItemGroup(placement: .automatic) {
            Button {
                appState.closeDocument()
            } label: {
                Image(systemName: "chevron.backward")
            }
            .help("Back to Home")

            Button {
                withAnimation { showSidebar.toggle() }
            } label: {
                Image(systemName: showSidebar ? "sidebar.left" : "sidebar.leading")
            }
            .help(showSidebar ? "Hide Sidebar" : "Show Sidebar")

            fontSizeControls

            Button {
                showDocumentInfo = true
            } label: {
                Image(systemName: "info.circle")
            }
        }
        #else
        ToolbarItem(placement: .automatic) {
            EmptyView()
        }
        #endif
    }
    
    private var fontSizePercent: Int {
        Int(round((appState.fontSize / 16.0) * 100))
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

/// Renders the full assembled manuscript (front matter + body + back matter) in a
/// single scrollable view, mirroring how FileReaderView renders individual files.
struct ManuscriptReaderView: View {
    let title: String
    let files: [WSPReaderFile]
    let projectType: String
    let dramaScriptType: String?
    let fontSize: CGFloat
    var onNavigateToFile: ((String) -> Void)? = nil

    @Environment(ReaderAppState.self) private var appState
    /// Combined attributed string built once and cached; rebuilt when fontSize changes.
    @State private var displayContent: NSAttributedString = NSAttributedString()

    var body: some View {
        Group {
            if files.isEmpty {
                ContentUnavailableView(
                    "No Manuscript Content",
                    systemImage: "doc.text",
                    description: Text("No files are marked for manuscript inclusion.")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        AttributedTextView(
                            attributedString: displayContent,
                            fontSize: fontSize,
                            onLinkTap: handleLinkTap
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer(minLength: 40)
                    }
                    .padding()
                    .frame(maxWidth: 700, alignment: .leading)
                }
                .background(readerBackground)
            }
        }
        .onAppear { displayContent = buildCombinedContent() }
        .onChange(of: fontSize) { displayContent = buildCombinedContent() }
    }

    // MARK: - Content Assembly

    /// Concatenate all manuscript files into one attributed string, scale fonts to
    /// match the user's font-size preference (identical to FileReaderView.buildScaledContent).
    private func buildCombinedContent() -> NSAttributedString {
        let isDrama = projectType.lowercased() == "drama"
        let combined = NSMutableAttributedString()

        for (index, file) in files.enumerated() {
            let fileContent: NSAttributedString
            if isDrama {
                fileContent = WSPDramaRenderer.shared.render(
                    source: file.plainContent,
                    scriptTypeRaw: dramaScriptType
                )
            } else {
                fileContent = file.attributedContent
            }

            combined.append(fileContent)

            // Separate files with a page-break character (not after the last file)
            if index < files.count - 1 {
                if !combined.string.hasSuffix("\n") {
                    combined.append(NSAttributedString(string: "\n"))
                }
                combined.append(NSAttributedString(string: "\u{000C}")) // form feed = page break
            }
        }

        // Scale all fonts to match user preference — same as FileReaderView.buildScaledContent()
        let scaleFactor = fontSize / 16.0
        combined.enumerateAttribute(.font, in: NSRange(location: 0, length: combined.length)) { value, range, _ in
#if canImport(UIKit)
            if let font = value as? UIFont {
                combined.addAttribute(.font, value: font.withSize(font.pointSize * scaleFactor), range: range)
            }
#elseif canImport(AppKit)
            if let font = value as? NSFont {
                let scaled = NSFont(descriptor: font.fontDescriptor, size: font.pointSize * scaleFactor)
                    ?? NSFont.systemFont(ofSize: font.pointSize * scaleFactor)
                combined.addAttribute(.font, value: scaled, range: range)
            }
#endif
        }

        return combined
    }

    // MARK: - Link Handling

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

    private var readerBackground: Color {
#if canImport(UIKit)
        Color(uiColor: .systemBackground)
#elseif canImport(AppKit)
        Color(nsColor: .textBackgroundColor)
#else
        Color.white
#endif
    }
}

// MARK: - Folder Section

struct FolderSection: View {
    let folder: WSPReaderFolder
    @Binding var selection: DocumentReaderView.DetailSelection?
    var statusFilter: String = "All"

    @State private var isExpanded: Bool = true

    private var visibleFiles: [WSPReaderFile] {
        guard statusFilter != "All" else { return folder.files }
        return folder.files.filter { ($0.workflowStatus ?? "").lowercased() == statusFilter.lowercased() }
    }

    private var visibleSubfolders: [WSPReaderFolder] {
        guard statusFilter != "All" else { return folder.subfolders }
        return folder.subfolders.filter { hasVisibleContent($0) }
    }

    private func hasVisibleContent(_ f: WSPReaderFolder) -> Bool {
        let hasFiles = f.files.contains { ($0.workflowStatus ?? "").lowercased() == statusFilter.lowercased() }
        return hasFiles || f.subfolders.contains { hasVisibleContent($0) }
    }

    var body: some View {
        if visibleFiles.isEmpty && visibleSubfolders.isEmpty {
            EmptyView()
        } else {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(visibleFiles) { file in
                    FileRow(file: file, isSelected: selection == .file(file))
                        .tag(DocumentReaderView.DetailSelection.file(file))
                }

                ForEach(visibleSubfolders) { subfolder in
                    FolderSection(folder: subfolder, selection: $selection, statusFilter: statusFilter)
                }
            } label: {
                Label(folder.name, systemImage: folder.iconName)
                    .foregroundStyle(.primary)
            }
        }
    }
}

// MARK: - File Row

struct FileRow: View {
    let file: WSPReaderFile
    let isSelected: Bool

    private var statusColor: Color {
        guard let status = file.workflowStatus else { return .primary }
        switch status.lowercased() {
        case "draft":     return Color(UIColor.systemBlue)
        case "ready":     return Color(UIColor.systemGreen)
        case "setaside":  return Color(UIColor.systemRed)
        default:          return .primary
        }
    }

    var body: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundStyle(isSelected ? .white : statusColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .foregroundStyle(isSelected ? .white : statusColor)
                    .lineLimit(1)

                Text("\(file.wordCount) words")
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor : Color.clear)
        .cornerRadius(6)
    }
}
