//
//  LegacyProjectPickerView.swift
//  Writing Shed Pro
//
//  Multi-select list for choosing legacy projects to import
//  Feature 019: Settings Menu - Smart Import
//

import SwiftUI

struct LegacyProjectPickerView: View {
    let availableProjects: [LegacyProjectData]
    @Binding var isPresented: Bool
    let onImport: ([LegacyProjectData]) -> Void
    
    @State private var selectedProjects: Set<String> = []
    
    /// Clean project name by removing timestamp data after <>
    private func cleanProjectName(_ name: String) -> String {
        if let range = name.range(of: "<>") {
            return String(name[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return name
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if availableProjects.isEmpty {
                    ContentUnavailableView(
                        "No Projects Available",
                        systemImage: "tray",
                        description: Text("All legacy projects have already been imported")
                    )
                } else {
                    List(availableProjects, id: \.objectID, selection: $selectedProjects) { project in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(cleanProjectName(project.name))
                                    .font(.headline)
                                
                                HStack(spacing: 12) {
                                    Label(project.projectType.capitalized, systemImage: "doc.text")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Label(project.createdOn.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if selectedProjects.contains(project.objectID) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleSelection(project.objectID)
                        }
                    }
                    #if os(iOS)
                    .environment(\.editMode, .constant(.active))
                    #endif
                    
                    // Selection summary bar
                    if !selectedProjects.isEmpty {
                        HStack {
                            Text("\(selectedProjects.count) project\(selectedProjects.count == 1 ? "" : "s") selected")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Button("Select All") {
                                selectAll()
                            }
                            .buttonStyle(.borderless)
                            .disabled(selectedProjects.count == availableProjects.count)
                            
                            Button("Clear") {
                                selectedProjects.removeAll()
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                    }
                }
            }
            .navigationTitle("Import from Writing Shed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        importSelected()
                    }
                    .disabled(selectedProjects.isEmpty)
                }
            }
            .onAppear {
                // Pre-select all projects by default
                selectAll()
            }
        }
    }
    
    private func toggleSelection(_ projectID: String) {
        if selectedProjects.contains(projectID) {
            selectedProjects.remove(projectID)
        } else {
            selectedProjects.insert(projectID)
        }
    }
    
    private func selectAll() {
        selectedProjects = Set(availableProjects.map { $0.objectID })
    }
    
    private func importSelected() {
        let projectsToImport = availableProjects.filter { selectedProjects.contains($0.objectID) }
        onImport(projectsToImport)
        isPresented = false
    }
}

#Preview {
    LegacyProjectPickerView(
        availableProjects: [
            LegacyProjectData(
                objectID: "1",
                name: "My Novel",
                projectType: "novel",
                createdOn: Date()
            ),
            LegacyProjectData(
                objectID: "2",
                name: "Poetry Collection",
                projectType: "poetry",
                createdOn: Date().addingTimeInterval(-86400 * 30)
            ),
            LegacyProjectData(
                objectID: "3",
                name: "Short Stories",
                projectType: "shortStory",
                createdOn: Date().addingTimeInterval(-86400 * 60)
            )
        ],
        isPresented: .constant(true),
        onImport: { projects in
            print("Importing \(projects.count) projects")
        }
    )
}
