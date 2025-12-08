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
    @State private var navigateToFile = false
    
    let title: String
    let folder: Folder?
    let collection: Submission?
    
    init(folder: Folder) {
        self.title = "Search in \(folder.name ?? "Folder")"
        self.folder = folder
        self.collection = nil
    }
    
    init(collection: Submission) {
        self.title = "Search in \(collection.name ?? "Collection")"
        self.folder = nil
        self.collection = collection
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
            // Search field row
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
            
            // Options row
            HStack(spacing: 16) {
                // Toggle replace mode
                Button(action: {
                    searchService.isReplaceMode.toggle()
                }) {
                    Label("Replace", systemImage: searchService.isReplaceMode ? "chevron.down" : "chevron.right")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                
                Divider()
                    .frame(height: 20)
                
                // Search options
                Toggle("Aa", isOn: $searchService.isCaseSensitive)
                    .toggleStyle(.button)
                    .font(.caption)
                    .help("Case sensitive")
                
                Toggle("\\b", isOn: $searchService.isWholeWord)
                    .toggleStyle(.button)
                    .font(.caption)
                    .help("Whole word")
                
                Toggle(".*", isOn: $searchService.isRegex)
                    .toggleStyle(.button)
                    .font(.caption)
                    .help("Regular expression")
                
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
                        onNavigate: {
                            selectedFile = result.file
                            dismiss()
                        }
                    )
                }
            }
            .listStyle(.plain)
        }
    }
    
    // MARK: - Actions
    
    private func performSearch() {
        if let folder = folder {
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
    let onNavigate: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox (replace mode only)
            if isReplaceMode {
                Button(action: onToggleSelection) {
                    Image(systemName: result.isSelected ? "checkmark.square.fill" : "square")
                        .foregroundStyle(result.isSelected ? .blue : .secondary)
                }
                .buttonStyle(.plain)
            }
            
            // File icon
            Image(systemName: "doc.text")
                .foregroundStyle(.secondary)
            
            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(result.file.name.isEmpty ? "Untitled" : result.file.name)
                    .font(.body)
                
                Text("\(result.matchCount) matches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Show first few matches as preview
                ForEach(result.matches.prefix(3)) { match in
                    Text(match.context)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                
                if result.matches.count > 3 {
                    Text("+ \(result.matches.count - 3) more...")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            // Navigate button
            Button(action: onNavigate) {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            if isReplaceMode {
                onToggleSelection()
            } else {
                onNavigate()
            }
        }
    }
}


