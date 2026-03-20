//
//  DocumentInfoView.swift
//  WSP Reader
//
//  Displays document metadata and statistics.
//  Feature 026: WSP Reader App
//

import SwiftUI

struct DocumentInfoView: View {
    let document: WSPDocument
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Project info
                Section("Project") {
                    InfoRow(label: "Name", value: document.projectName)
                    InfoRow(label: "Type", value: formattedProjectType)
                    
                    if let date = document.exportDate {
                        InfoRow(label: "Exported", value: formattedDate(date))
                    }
                    
                    InfoRow(label: "Created With", value: "Writing Shed Pro \(document.appVersion)")
                }
                
                // Statistics
                Section("Statistics") {
                    InfoRow(label: "Folders", value: "\(document.folders.count)")
                    InfoRow(label: "Files", value: "\(document.allFiles.count)")
                    InfoRow(label: "Total Words", value: "\(totalWordCount)")
                }
                
                // File details
                Section("Files by Folder") {
                    ForEach(document.folders) { folder in
                        FolderInfoRow(folder: folder)
                    }
                }
                
                // Publications (if any)
                if !document.publications.isEmpty {
                    Section("Publications Referenced") {
                        ForEach(document.publications) { pub in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pub.name)
                                
                                if let type = pub.type {
                                    Text(type.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Document Info")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var formattedProjectType: String {
        switch document.projectType {
        case "poetry": return "Poetry"
        case "shortFiction": return "Short Fiction"
        case "fiction": return "Fiction"
        case "drama": return "Drama"
        case "manual": return "Manual"
        case "prose": return "Prose"
        default: return document.projectType.capitalized
        }
    }
    
    private var totalWordCount: Int {
        document.allFiles.reduce(0) { $0 + $1.wordCount }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}

// MARK: - Folder Info Row

struct FolderInfoRow: View {
    let folder: WSPReaderFolder
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: folder.iconName)
                    .foregroundStyle(.secondary)
                
                Text(folder.name)
                
                Spacer()
                
                Text("\(folder.files.count) files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if !folder.subfolders.isEmpty {
                Text("\(folder.subfolders.count) subfolders")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 24)
            }
        }
    }
}

#Preview {
    Text("Document Info Preview")
}
