//
//  IndexOccurrenceFinderSheet.swift
//  Writing Shed Pro
//
//  Feature 029: Find and mark index entry occurrences across the project
//

import SwiftUI
import SwiftData

/// Represents a found occurrence of an index keyword in the project
struct IndexOccurrence: Identifiable {
    let id = UUID()
    let file: TextFile
    let range: NSRange
    let contextBefore: String
    let matchedText: String
    let contextAfter: String
    var isSelected: Bool = true
    var isAlreadyMarked: Bool = false
}

/// Sheet for finding and marking occurrences of an index entry keyword
struct IndexOccurrenceFinderSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let entry: IndexEntry
    let project: Project
    let onMarkersAdded: () -> Void
    
    // MARK: - State
    
    @State private var occurrences: [IndexOccurrence] = []
    @State private var isSearching = true
    @State private var searchError: String?
    @State private var markingInProgress = false
    @State private var markedCount = 0
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    searchingView
                } else if let error = searchError {
                    errorView(error)
                } else if occurrences.isEmpty {
                    noOccurrencesView
                } else {
                    occurrencesList
                }
            }
            .navigationTitle(NSLocalizedString("indexOccurrences.title", comment: "Find Occurrences"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if !occurrences.isEmpty && !isSearching {
                        Button {
                            markSelectedOccurrences()
                        } label: {
                            if markingInProgress {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text(NSLocalizedString("indexOccurrences.markSelected", comment: "Mark Selected"))
                            }
                        }
                        .disabled(selectedCount == 0 || markingInProgress)
                    }
                }
            }
        }
        .task {
            await searchForOccurrences()
        }
    }
    
    // MARK: - Subviews
    
    private var searchingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(NSLocalizedString("indexOccurrences.searching", comment: "Searching for occurrences..."))
                .foregroundStyle(.secondary)
        }
    }
    
    private func errorView(_ error: String) -> some View {
        ContentUnavailableView {
            Label(NSLocalizedString("indexOccurrences.error.title", comment: "Search Error"), systemImage: "exclamationmark.triangle")
        } description: {
            Text(error)
        }
    }
    
    private var noOccurrencesView: some View {
        ContentUnavailableView {
            Label(NSLocalizedString("indexOccurrences.none.title", comment: "No Occurrences Found"), systemImage: "doc.text.magnifyingglass")
        } description: {
            Text(String(format: NSLocalizedString("indexOccurrences.none.message", comment: ""), entry.keyword))
        }
    }
    
    private var occurrencesList: some View {
        VStack(spacing: 0) {
            // Summary header
            HStack {
                Text(String(format: NSLocalizedString("indexOccurrences.found", comment: "Found %d occurrences"), occurrences.count))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    toggleSelectAll()
                } label: {
                    Text(allSelected ? NSLocalizedString("indexOccurrences.deselectAll", comment: "Deselect All") : NSLocalizedString("indexOccurrences.selectAll", comment: "Select All"))
                        .font(.subheadline)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // Occurrences list
            List {
                ForEach($occurrences) { $occurrence in
                    OccurrenceRow(occurrence: $occurrence)
                }
            }
            .listStyle(.plain)
            
            // Footer with selection count
            HStack {
                Text(String(format: NSLocalizedString("indexOccurrences.selected", comment: "%d selected"), selectedCount))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if markedCount > 0 {
                    Text(String(format: NSLocalizedString("indexOccurrences.alreadyMarked", comment: "%d already marked"), markedCount))
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))
        }
    }
    
    // MARK: - Computed Properties
    
    private var selectedCount: Int {
        occurrences.filter { $0.isSelected && !$0.isAlreadyMarked }.count
    }
    
    private var allSelected: Bool {
        occurrences.filter { !$0.isAlreadyMarked }.allSatisfy { $0.isSelected }
    }
    
    // MARK: - Actions
    
    private func toggleSelectAll() {
        let newValue = !allSelected
        for i in occurrences.indices {
            if !occurrences[i].isAlreadyMarked {
                occurrences[i].isSelected = newValue
            }
        }
    }
    
    @MainActor
    private func searchForOccurrences() async {
        isSearching = true
        searchError = nil
        
        do {
            var found: [IndexOccurrence] = []
            let keyword = entry.keyword
            
            // Get all body files from the project
            let bodyFiles = getBodyFiles()
            
            for file in bodyFiles {
                guard let version = file.currentVersion,
                      let content = version.attributedContent else {
                    continue
                }
                
                let text = content.string
                let nsText = text as NSString
                
                // Find all occurrences of the keyword (case-insensitive)
                var searchRange = NSRange(location: 0, length: nsText.length)
                
                while searchRange.location < nsText.length {
                    let foundRange = nsText.range(
                        of: keyword,
                        options: [.caseInsensitive],
                        range: searchRange
                    )
                    
                    if foundRange.location == NSNotFound {
                        break
                    }
                    
                    // Check if this position already has an index marker
                    let isAlreadyMarked = checkForExistingMarker(in: content, near: foundRange)
                    
                    // Extract context (up to 30 chars before and after)
                    let contextStart = max(0, foundRange.location - 30)
                    let contextEnd = min(nsText.length, NSMaxRange(foundRange) + 30)
                    
                    let beforeRange = NSRange(location: contextStart, length: foundRange.location - contextStart)
                    let afterRange = NSRange(location: NSMaxRange(foundRange), length: contextEnd - NSMaxRange(foundRange))
                    
                    var contextBefore = nsText.substring(with: beforeRange)
                    var contextAfter = nsText.substring(with: afterRange)
                    
                    // Clean up context (remove newlines, trim)
                    contextBefore = contextBefore.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
                    contextAfter = contextAfter.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
                    
                    // Add ellipsis if truncated
                    if contextStart > 0 {
                        contextBefore = "…" + contextBefore
                    }
                    if contextEnd < nsText.length {
                        contextAfter = contextAfter + "…"
                    }
                    
                    let occurrence = IndexOccurrence(
                        file: file,
                        range: foundRange,
                        contextBefore: contextBefore,
                        matchedText: nsText.substring(with: foundRange),
                        contextAfter: contextAfter,
                        isSelected: !isAlreadyMarked,
                        isAlreadyMarked: isAlreadyMarked
                    )
                    found.append(occurrence)
                    
                    // Move search range past this occurrence
                    searchRange.location = NSMaxRange(foundRange)
                    searchRange.length = nsText.length - searchRange.location
                }
            }
            
            occurrences = found
            markedCount = found.filter { $0.isAlreadyMarked }.count
            
        } catch {
            searchError = error.localizedDescription
        }
        
        isSearching = false
    }
    
    /// Get all body files (excluding front/back matter)
    private func getBodyFiles() -> [TextFile] {
        let assemblyService = ManuscriptAssemblyService(context: modelContext)
        let sections = assemblyService.getSections(for: project)
        
        var files: [TextFile] = []
        for section in sections {
            if section.sectionType == .body {
                files.append(contentsOf: section.files)
            }
        }
        return files
    }
    
    /// Check if there's already an index marker near this position
    private func checkForExistingMarker(in content: NSAttributedString, near range: NSRange) -> Bool {
        // Check a small range around the found text for existing markers
        let checkStart = max(0, range.location - 1)
        let checkEnd = min(content.length, NSMaxRange(range) + 1)
        let checkRange = NSRange(location: checkStart, length: checkEnd - checkStart)
        
        var hasMarker = false
        content.enumerateAttribute(.attachment, in: checkRange) { value, _, stop in
            if let attachment = value as? ReferenceAttachment,
               attachment.referenceType == .index,
               attachment.entryID == entry.id {
                hasMarker = true
                stop.pointee = true
            }
        }
        return hasMarker
    }
    
    /// Mark selected occurrences with index markers
    private func markSelectedOccurrences() {
        markingInProgress = true
        
        // Group occurrences by file, sorted by position (reverse order to maintain offsets)
        let selectedOccurrences = occurrences.filter { $0.isSelected && !$0.isAlreadyMarked }
        let groupedByFile = Dictionary(grouping: selectedOccurrences) { $0.file.id }
        
        var totalMarked = 0
        
        for (fileID, fileOccurrences) in groupedByFile {
            guard let file = fileOccurrences.first?.file,
                  let version = file.currentVersion,
                  let content = version.attributedContent else {
                continue
            }
            
            // Sort by position descending (so we can insert without affecting earlier positions)
            let sorted = fileOccurrences.sorted { $0.range.location > $1.range.location }
            
            let mutableContent = NSMutableAttributedString(attributedString: content)
            
            for occurrence in sorted {
                // Create index marker attachment
                let attachment = ReferenceAttachment(
                    indexEntryID: entry.id,
                    isPrimary: false
                )
                let attachmentString = NSAttributedString(attachment: attachment)
                
                // Insert marker right after the matched text
                let insertPosition = NSMaxRange(occurrence.range)
                mutableContent.insert(attachmentString, at: insertPosition)
                
                totalMarked += 1
            }
            
            // Save the modified content back to the version
            version.attributedContent = mutableContent
            
            // Update reference count
            entry.referenceCount += sorted.count
            
            // Track file reference
            entry.addReferencingFile(fileID)
        }
        
        // Save changes
        do {
            try modelContext.save()
            
            #if DEBUG
            print("📑 Marked \(totalMarked) occurrences of '\(entry.keyword)'")
            #endif
            
            onMarkersAdded()
            dismiss()
            
        } catch {
            #if DEBUG
            print("❌ Error saving index markers: \(error)")
            #endif
            searchError = error.localizedDescription
        }
        
        markingInProgress = false
    }
}

// MARK: - Occurrence Row

struct OccurrenceRow: View {
    @Binding var occurrence: IndexOccurrence
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox
            Button {
                if !occurrence.isAlreadyMarked {
                    occurrence.isSelected.toggle()
                }
            } label: {
                Image(systemName: occurrence.isAlreadyMarked ? "checkmark.circle.fill" : (occurrence.isSelected ? "checkmark.circle.fill" : "circle"))
                    .foregroundStyle(occurrence.isAlreadyMarked ? .orange : (occurrence.isSelected ? .blue : .secondary))
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .disabled(occurrence.isAlreadyMarked)
            
            VStack(alignment: .leading, spacing: 4) {
                // File name
                Text(occurrence.file.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Context with highlighted match
                HStack(spacing: 0) {
                    Text(occurrence.contextBefore)
                        .foregroundStyle(.secondary)
                    Text(occurrence.matchedText)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(occurrence.contextAfter)
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
                .lineLimit(2)
                
                if occurrence.isAlreadyMarked {
                    Text(NSLocalizedString("indexOccurrences.alreadyMarkedLabel", comment: "Already marked"))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if !occurrence.isAlreadyMarked {
                occurrence.isSelected.toggle()
            }
        }
    }
}

#Preview {
    // Preview not available without SwiftData context
    Text("IndexOccurrenceFinderSheet")
}
