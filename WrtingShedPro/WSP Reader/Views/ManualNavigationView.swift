//
//  ManualNavigationView.swift
//  WSP Reader
//
//  Special navigation view for Manual project type with TOC.
//  Feature 026: WSP Reader App (per 025-manual-project-type)
//

import SwiftUI

struct ManualNavigationView: View {
    let document: WSPDocument
    @Binding var selectedFile: WSPReaderFile?
    
    var body: some View {
        List(selection: $selectedFile) {
            // Title section
            Section {
                HStack {
                    Image(systemName: "books.vertical.fill")
                        .foregroundStyle(.brown)
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        Text(document.projectName)
                            .font(.headline)
                        
                        Text("User Manual")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Table of Contents
            Section("Contents") {
                ForEach(document.folders) { folder in
                    ManualChapterSection(folder: folder, selectedFile: $selectedFile)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Contents")
    }
}

// MARK: - Chapter Section

struct ManualChapterSection: View {
    let folder: WSPReaderFolder
    @Binding var selectedFile: WSPReaderFile?
    
    @State private var isExpanded: Bool = true
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(folder.files) { file in
                ManualFileRow(file: file, isSelected: selectedFile?.id == file.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedFile = file
                    }
            }
            
            ForEach(folder.subfolders) { subfolder in
                ManualSubsection(folder: subfolder, selectedFile: $selectedFile)
            }
        } label: {
            Label {
                Text(folder.name)
                    .fontWeight(.medium)
            } icon: {
                Image(systemName: chapterIcon)
                    .foregroundStyle(.brown)
            }
        }
    }
    
    private var chapterIcon: String {
        let name = folder.name.lowercased()
        if name.contains("welcome") || name.contains("intro") { return "hand.wave" }
        if name.contains("getting started") { return "figure.walk" }
        if name.contains("project") { return "folder" }
        if name.contains("writing") || name.contains("editor") { return "pencil" }
        if name.contains("poetry") { return "text.quote" }
        if name.contains("fiction") { return "book" }
        if name.contains("drama") { return "theatermasks" }
        if name.contains("publish") || name.contains("export") { return "square.and.arrow.up" }
        if name.contains("advanced") { return "gearshape.2" }
        if name.contains("reference") { return "list.bullet.rectangle" }
        if name.contains("appendix") || name.contains("appendices") { return "doc.append" }
        return "doc.text"
    }
}

// MARK: - Subsection

struct ManualSubsection: View {
    let folder: WSPReaderFolder
    @Binding var selectedFile: WSPReaderFile?
    
    @State private var isExpanded: Bool = false
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(folder.files) { file in
                ManualFileRow(file: file, isSelected: selectedFile?.id == file.id, indented: true)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedFile = file
                    }
            }
        } label: {
            Text(folder.name)
                .font(.subheadline)
        }
    }
}

// MARK: - File Row

struct ManualFileRow: View {
    let file: WSPReaderFile
    let isSelected: Bool
    var indented: Bool = false
    
    var body: some View {
        HStack {
            Text(displayName)
                .foregroundStyle(isSelected ? .white : .primary)
            
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.leading, indented ? 16 : 8)
        .padding(.trailing, 8)
        .background(isSelected ? Color.accentColor : Color.clear)
        .cornerRadius(6)
    }
    
    private var displayName: String {
        // Remove numeric prefix from filename for cleaner display
        var name = file.name
        
        // Remove .md extension if present
        if name.hasSuffix(".md") {
            name = String(name.dropLast(3))
        }
        
        // Remove numeric prefix like "01-" or "1. "
        if let range = name.range(of: #"^\d+[-.\s]+"#, options: .regularExpression) {
            name = String(name[range.upperBound...])
        }
        
        // Convert kebab-case to title case
        name = name.replacingOccurrences(of: "-", with: " ")
        name = name.capitalized
        
        return name
    }
}
