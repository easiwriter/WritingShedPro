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
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    @State private var searchService = MultiFileSearchService()
    @State private var showReplaceConfirmation = false
    @State private var showNoMatchesAlert = false
    @State private var showReplaceSuccessAlert = false
    @State private var replacementCount = 0
    
    // Navigation to file
    @State private var selectedFile: TextFile?
    
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
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                Divider()
                
                // Results area
                if searchService.isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = searchService.errorMessage {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    }
                } else if let regexError = searchService.regexError {
                    ContentUnavailableView {
                        Label("Invalid Pattern", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(regexError)
                    }
                } else if searchService.hasResults {
                    resultsView
                } else if !searchService.searchText.isEmpty {
                    ContentUnavailableView {
                        Label("No Matches", systemImage: "magnifyingglass")
                    } description: {
                        Text("No matches found in any files")
                    }
                } else {
                    ContentUnavailableView {
                        Label("Search Files", systemImage: "magnifyingglass")
                    } description: {
                        Text("Enter text to search across all files")
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
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
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        VStack(spacing: 12) {
            // Search field row with inline options
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search", text: $searchService.searchText)
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
            if searchService.isReplaceMode {
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
                Button(action: {
                    searchService.isReplaceMode.toggle()
                }) {
                    Label("Replace", systemImage: searchService.isReplaceMode ? "chevron.down" : "chevron.right")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Results summary
                if searchService.hasResults {
                    Text("\(searchService.totalMatchCount) matches in \(searchService.fileCount) files")
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
                        destination: FileEditViewWithSearch(
                            file: result.file,
                            searchText: searchService.searchText,
                            replaceText: searchService.isReplaceMode ? searchService.replaceText : nil,
                            isCaseSensitive: searchService.isCaseSensitive,
                            isWholeWord: searchService.isWholeWord,
                            isRegex: searchService.isRegex
                        )
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

struct FileResultRow<Destination: View>: View {
    let result: MultiFileSearchResult
    let isReplaceMode: Bool
    let onToggleSelection: () -> Void
    let destination: Destination
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                // Selection checkbox (replace mode only)
                if isReplaceMode {
                    Button(action: {
                        onToggleSelection()
                    }) {
                        Image(systemName: result.isSelected ? "checkmark.square.fill" : "square")
                            .foregroundStyle(result.isSelected ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)
                    .onTapGesture {
                        // Prevent navigation when tapping checkbox
                        onToggleSelection()
                    }
                }
                
                // File info (2 lines)
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.file.name.isEmpty ? "Untitled" : result.file.name)
                        .font(.body)
                    
                    Text("\(result.matchCount) matches")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
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
    
    @State private var searchContext: SearchContext
    
    init(file: TextFile, searchText: String, replaceText: String?, isCaseSensitive: Bool, isWholeWord: Bool, isRegex: Bool) {
        self.file = file
        self.searchText = searchText
        self.replaceText = replaceText
        self.isCaseSensitive = isCaseSensitive
        self.isWholeWord = isWholeWord
        self.isRegex = isRegex
        
        _searchContext = State(initialValue: SearchContext(
            searchText: searchText,
            replaceText: replaceText,
            isCaseSensitive: isCaseSensitive,
            isWholeWord: isWholeWord,
            isRegex: isRegex
        ))
    }
    
    var body: some View {
        FileEditView(file: file)
            .environment(searchContext)
    }
}


