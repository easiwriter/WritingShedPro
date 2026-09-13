//
//  MultiFileSearchView.swift
//  Writing Shed Pro
//
//  Created on 8 December 2025.
//  Extension of Feature 017: Multi-file search UI for folders and collections
//

import SwiftUI
import SwiftData

/// View for searching across multiple files (folder or collection)
struct MultiFileSearchView: View {
    private struct ResultNavigation: Identifiable, Hashable {
        enum Destination {
            case file
            case folder
        }

        let id = UUID()
        let file: TextFile
        let destination: Destination

        static func == (lhs: ResultNavigation, rhs: ResultNavigation) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    @State private var searchService = MultiFileSearchService()
    @State private var showReplaceConfirmation = false
    @State private var showNoMatchesAlert = false
    @State private var showReplaceSuccessAlert = false
    @State private var replacementCount = 0
    
    @State private var selectedResult: MultiFileSearchResult?
    @State private var resultNavigation: ResultNavigation?
    
    let title: String
    let folder: Folder?
    let collection: Submission?
    let files: [TextFile]?  // Explicit file list for virtual folders
    let onFileSelected: ((TextFile) -> Void)?
    
    init(folder: Folder, files: [TextFile]? = nil, onFileSelected: ((TextFile) -> Void)? = nil) {
        self.title = "Search in \(folder.name ?? "Folder")"
        self.folder = folder
        self.collection = nil
        self.files = files
        self.onFileSelected = onFileSelected
    }
    
    init(collection: Submission, onFileSelected: ((TextFile) -> Void)? = nil) {
        self.title = "Search in \(collection.name ?? "Collection")"
        self.folder = nil
        self.collection = collection
        self.files = nil
        self.onFileSelected = onFileSelected
    }
    
    var body: some View {
        NavigationStack {
            resultActionDialogContent
        }
    }

    private var navigationContent: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            searchResultsContent
        }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $resultNavigation) { navigation in
                resultDestination(for: navigation)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
    }

    private var alertContent: some View {
        navigationContent
            .alert("Replace Matches", isPresented: $showReplaceConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Replace", role: .destructive) {
                    performReplace()
                }
            } message: {
                Text("Replace \(searchService.totalMatchCount) matches in \(searchService.selectedResultsCount) selected files?")
            }
            .alert("No Matches Found", isPresented: $showNoMatchesAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("No matches were found in any files.")
            }
            .alert("Replace Complete", isPresented: $showReplaceSuccessAlert) {
                Button("OK", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Replaced \(replacementCount) matches successfully.")
            }
    }

    private var resultActionDialogContent: some View {
        alertContent
            .confirmationDialog(
                selectedResultTitle,
                isPresented: isResultActionDialogPresented,
                presenting: selectedResult
            ) { result in
                Button("Open File") {
                    resultNavigation = ResultNavigation(file: result.file, destination: .file)
                }
                Button("Show in Folder") {
                    resultNavigation = ResultNavigation(file: result.file, destination: .folder)
                }
                .disabled(result.file.parentFolder == nil)
                Button("Cancel", role: .cancel) { }
            } message: { result in
                Text(result.locationPath)
            }
    }

    private var isResultActionDialogPresented: Binding<Bool> {
        Binding(
            get: { selectedResult != nil },
            set: { if !$0 { selectedResult = nil } }
        )
    }

    @ViewBuilder
    private var searchResultsContent: some View {
        if searchService.isSearching {
            ProgressView("Searching...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = searchService.errorMessage {
            searchUnavailableView(title: "Error", message: errorMessage, systemImage: "exclamationmark.triangle")
        } else if let regexError = searchService.regexError {
            searchUnavailableView(title: "Invalid Pattern", message: regexError, systemImage: "exclamationmark.triangle")
        } else if searchService.hasResults {
            resultsView
        } else if !searchService.searchText.isEmpty {
            let message = searchService.searchTarget == .fileNames
                ? "No file names match your search"
                : "No matches found in any files"
            searchUnavailableView(title: "No Matches", message: message, systemImage: "magnifyingglass")
        } else {
            let message = searchService.searchTarget == .fileNames
                ? "Enter all or part of a file name"
                : "Enter text to search across all files"
            searchUnavailableView(title: "Search Files", message: message, systemImage: "magnifyingglass")
        }
    }

    private func searchUnavailableView(title: String, message: String, systemImage: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
    }
    
    // MARK: - Search Bar

    @ViewBuilder
    private func resultDestination(for navigation: ResultNavigation) -> some View {
        switch navigation.destination {
        case .file:
            FileEditViewWithSearch(
                file: navigation.file,
                searchText: searchService.searchText,
                replaceText: searchService.isReplaceMode ? searchService.replaceText : nil,
                isCaseSensitive: searchService.isCaseSensitive,
                isWholeWord: searchService.isWholeWord,
                isRegex: searchService.isRegex,
                highlightsContent: searchService.searchTarget == .contents
            )
        case .folder:
            folderDestination(for: navigation.file)
        }
    }

    @ViewBuilder
    private func folderDestination(for file: TextFile) -> some View {
        if let parentFolder = file.parentFolder {
            FolderFilesView(folder: parentFolder, highlightedFileID: file.id)
        } else {
            ContentUnavailableView(
                "Folder Unavailable",
                systemImage: "folder.badge.questionmark",
                description: Text("This file is not currently assigned to a folder.")
            )
        }
    }

    private var selectedResultTitle: String {
        guard let fileName = selectedResult?.file.name, !fileName.isEmpty else {
            return "Untitled"
        }
        return fileName
    }
    
    private var searchBar: some View {
        VStack(spacing: 12) {
            Picker("Search in", selection: $searchService.searchTarget) {
                Text("Contents").tag(MultiFileSearchTarget.contents)
                Text("File Names").tag(MultiFileSearchTarget.fileNames)
            }
            .pickerStyle(.segmented)
            .onChange(of: searchService.searchTarget) { _, target in
                searchService.results = []
                if target == .fileNames {
                    searchService.isReplaceMode = false
                }
            }

            // Search field row with inline options
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField(searchService.searchTarget == .fileNames ? "Search file names" : "Search contents", text: $searchService.searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        performSearch()
                    }
                
                if !searchService.searchText.isEmpty {
                    Button(action: {
                        searchService.searchText = ""
                        searchService.results = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                    .frame(height: 20)
                
                // Search options inline
                Button(action: {
                    searchService.isCaseSensitive.toggle()
                }) {
                    Image(systemName: "textformat")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 32, height: 32)
                        .background(searchService.isCaseSensitive ? Color.accentColor.opacity(0.2) : Color.clear)
                        .foregroundColor(searchService.isCaseSensitive ? .accentColor : .secondary)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Match case")
                
                Button(action: {
                    searchService.isWholeWord.toggle()
                }) {
                    Image(systemName: "w.square")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 32, height: 32)
                        .background(searchService.isWholeWord ? Color.accentColor.opacity(0.2) : Color.clear)
                        .foregroundColor(searchService.isWholeWord ? .accentColor : .secondary)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Match whole word")
                
                Button(action: {
                    searchService.isRegex.toggle()
                }) {
                    Image(systemName: "asterisk")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 32, height: 32)
                        .background(searchService.isRegex ? Color.accentColor.opacity(0.2) : Color.clear)
                        .foregroundColor(searchService.isRegex ? .accentColor : .secondary)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Use regular expression")
                
                Divider()
                    .frame(height: 20)
                
                Button("Search") {
                    performSearch()
                }
                .buttonStyle(.borderedProminent)
                .disabled(searchService.searchText.isEmpty)
            }
            
            // Replace field row (if replace mode)
            if searchService.isReplaceMode && searchService.searchTarget == .contents {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.secondary)
                    
                    TextField("Replace with", text: $searchService.replaceText)
                        .textFieldStyle(.plain)
                    
                    if !searchService.replaceText.isEmpty {
                        Button(action: {
                            searchService.replaceText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Bottom row: Replace toggle and results summary
            HStack(spacing: 16) {
                // Toggle replace mode
                if searchService.searchTarget == .contents {
                    Button(action: {
                        searchService.isReplaceMode.toggle()
                    }) {
                        Label("Replace", systemImage: searchService.isReplaceMode ? "chevron.down" : "chevron.right")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Results summary
                if searchService.hasResults {
                    Text(searchService.searchTarget == .fileNames
                         ? "\(searchService.fileCount) matching files"
                         : "\(searchService.totalMatchCount) matches in \(searchService.fileCount) files")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Results View
    
    private var resultsView: some View {
        VStack(spacing: 0) {
            // Selection controls
            if searchService.isReplaceMode {
                HStack {
                    Button(searchService.selectedResultsCount == searchService.fileCount ? "Deselect All" : "Select All") {
                        if searchService.selectedResultsCount == searchService.fileCount {
                            searchService.deselectAll()
                        } else {
                            searchService.selectAll()
                        }
                    }
                    .font(.caption)
                    
                    Spacer()
                    
                    Button("Replace in Selected Files") {
                        showReplaceConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(searchService.selectedResultsCount == 0)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                
                Divider()
            }
            
            // File results list
            List {
                ForEach(searchService.results) { result in
                    FileResultRow(
                        result: result,
                        isReplaceMode: searchService.isReplaceMode,
                        onToggleSelection: {
                            searchService.toggleSelection(for: result.id)
                        },
                        onOpenActions: {
                            selectedResult = result
                        },
                        isFileNameMatch: searchService.searchTarget == .fileNames
                    )
                }
            }
            .listStyle(.plain)
        }
    }
    
    // MARK: - Actions
    
    private func performSearch() {
        // Hide keyboard before showing results
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        if let files = files {
            // Use explicit file list for virtual folders
            searchService.searchInFiles(files)
        } else if let folder = folder {
            searchService.searchInFolder(folder)
        } else if let collection = collection {
            searchService.searchInCollection(collection)
        }
        
        // Show alert if no matches
        if !searchService.hasResults && !searchService.searchText.isEmpty {
            showNoMatchesAlert = true
        }
    }
    
    private func performReplace() {
        do {
            let count = try searchService.replaceInSelectedFiles()
            replacementCount = count
            showReplaceSuccessAlert = true
        } catch {
            searchService.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - File Result Row

struct FileResultRow: View {
    let result: MultiFileSearchResult
    let isReplaceMode: Bool
    let onToggleSelection: () -> Void
    let onOpenActions: () -> Void
    let isFileNameMatch: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            if isReplaceMode {
                Button(action: onToggleSelection) {
                    Image(systemName: result.isSelected ? "checkmark.square.fill" : "square")
                        .foregroundStyle(result.isSelected ? .blue : .secondary)
                }
                .buttonStyle(.plain)
            }

            Button(action: onOpenActions) {
                HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.file.name.isEmpty ? "Untitled" : result.file.name)
                        .font(.body)
                    
                    Text(isFileNameMatch ? "File name match" : "\(result.matchCount) matches")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label(result.locationPath, systemImage: "folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - FileEditView Wrapper with Search Context

/// Wrapper for FileEditView that automatically sets up search highlighting
struct FileEditViewWithSearch: View {
    let file: TextFile
    let searchText: String
    let replaceText: String?
    let isCaseSensitive: Bool
    let isWholeWord: Bool
    let isRegex: Bool
    let highlightsContent: Bool
    
    @State private var searchContext: SearchContext
    
    init(file: TextFile, searchText: String, replaceText: String?, isCaseSensitive: Bool, isWholeWord: Bool, isRegex: Bool, highlightsContent: Bool) {
        self.file = file
        self.searchText = searchText
        self.replaceText = replaceText
        self.isCaseSensitive = isCaseSensitive
        self.isWholeWord = isWholeWord
        self.isRegex = isRegex
        self.highlightsContent = highlightsContent
        
        _searchContext = State(initialValue: SearchContext(
            searchText: searchText,
            replaceText: replaceText,
            isCaseSensitive: isCaseSensitive,
            isWholeWord: isWholeWord,
            isRegex: isRegex
        ))
    }
    
    var body: some View {
        if highlightsContent {
            FileEditView(file: file)
                .environment(searchContext)
        } else {
            FileEditView(file: file)
        }
    }
}


