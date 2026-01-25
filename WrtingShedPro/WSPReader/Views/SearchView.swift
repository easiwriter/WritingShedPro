//
//  SearchView.swift
//  WSP Reader
//
//  Search within the current document.
//  Feature 026: WSP Reader App
//

import SwiftUI

struct SearchView: View {
    let document: WSPDocument
    @Binding var isPresented: Bool
    @Binding var selectedFile: WSPReaderFile?
    
    @State private var searchText: String = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Search in document...", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .background(.quaternary.opacity(0.5))
                
                Divider()
                
                // Results
                if isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else if searchResults.isEmpty {
                    ContentUnavailableView(
                        "Search Document",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Enter text to search across all files")
                    )
                } else {
                    List(searchResults) { result in
                        SearchResultRow(result: result) {
                            selectedFile = result.file
                            isPresented = false
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        searchResults = []
        
        let query = searchText.lowercased()
        
        // Search all files
        for file in document.allFiles {
            let content = file.plainContent.lowercased()
            
            if content.contains(query) {
                // Find all occurrences and extract context
                var matches: [SearchMatch] = []
                var searchRange = content.startIndex..<content.endIndex
                
                while let range = content.range(of: query, options: .caseInsensitive, range: searchRange) {
                    // Extract context around the match
                    let contextStart = content.index(range.lowerBound, offsetBy: -40, limitedBy: content.startIndex) ?? content.startIndex
                    let contextEnd = content.index(range.upperBound, offsetBy: 40, limitedBy: content.endIndex) ?? content.endIndex
                    
                    var contextText = String(content[contextStart..<contextEnd])
                    
                    // Add ellipsis if truncated
                    if contextStart != content.startIndex {
                        contextText = "..." + contextText
                    }
                    if contextEnd != content.endIndex {
                        contextText = contextText + "..."
                    }
                    
                    matches.append(SearchMatch(context: contextText))
                    
                    // Move search range forward
                    searchRange = range.upperBound..<content.endIndex
                    
                    // Limit matches per file
                    if matches.count >= 5 {
                        break
                    }
                }
                
                if !matches.isEmpty {
                    searchResults.append(SearchResult(
                        file: file,
                        matchCount: matches.count,
                        matches: matches
                    ))
                }
            }
        }
        
        isSearching = false
    }
}

// MARK: - Search Result

struct SearchResult: Identifiable {
    let id = UUID()
    let file: WSPReaderFile
    let matchCount: Int
    let matches: [SearchMatch]
}

struct SearchMatch: Identifiable {
    let id = UUID()
    let context: String
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: SearchResult
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                    
                    Text(result.file.name)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(result.matchCount) match\(result.matchCount == 1 ? "" : "es")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                ForEach(result.matches.prefix(2)) { match in
                    Text(match.context)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    Text("Search Preview")
}
