//
//  SectionPickerSheet.swift
//  Writing Shed Pro
//
//  Sheet for selecting a section to assign files to (Prose projects)
//

import SwiftUI
import SwiftData

/// Sheet for picking a section to assign selected files to
struct SectionPickerSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    let selectedFiles: [TextFile]
    let onAssign: (ProseSection?) -> Void
    let onCancel: () -> Void
    
    // MARK: - Computed
    
    private var sortedSections: [ProseSection] {
        (project.sections ?? []).sorted(by: ContainerDisplayOrder.isOrdered)
    }
    
    /// Check if all selected files are assigned to the same section
    private var assignedSection: ProseSection? {
        // Get the section of the first file
        guard let firstSection = selectedFiles.first?.section else { return nil }
        // Check if all files are assigned to the same section
        let allSameSection = selectedFiles.allSatisfy { $0.section?.id == firstSection.id }
        return allSameSection ? firstSection : nil
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            List {
                // If all files are assigned to the same section, only show remove option
                if let section = assignedSection {
                    Section {
                        Button {
                            onAssign(nil)
                        } label: {
                            HStack {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.red)
                                Text(String(format: NSLocalizedString("prose.files.removeFromSectionNamed", comment: "Remove from Section X"), section.name ?? NSLocalizedString("prose.untitled", comment: "Untitled")))
                                    .foregroundColor(.primary)
                            }
                        }
                    } header: {
                        Text(NSLocalizedString("prose.files.currentAssignment", comment: "Current Assignment"))
                    } footer: {
                        Text(String(format: NSLocalizedString("prose.files.assignedToSection", comment: "Assigned to section"), section.name ?? NSLocalizedString("prose.untitled", comment: "Untitled")))
                    }
                } else {
                    // Files are unassigned - show list of sections to assign to
                    Section {
                        if sortedSections.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                
                                Text(NSLocalizedString("prose.sections.empty.title", comment: "No Sections Yet"))
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text(NSLocalizedString("prose.sections.picker.createHint", comment: "Create sections in the Sections folder"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        } else {
                            ForEach(sortedSections) { section in
                                Button {
                                    onAssign(section)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            if let userOrder = section.userOrder {
                                                Text(String(format: NSLocalizedString("prose.section.number", comment: "Section X"), userOrder + 1))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Text(section.name ?? NSLocalizedString("prose.untitled", comment: "Untitled"))
                                                .foregroundColor(.primary)
                                        }
                                        
                                        Spacer()
                                        
                                        // Show file count in this section
                                        let fileCount = section.textFiles?.count ?? 0
                                        Text("\(fileCount)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(.secondarySystemBackground))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    } header: {
                        Text(NSLocalizedString("prose.sections.title", comment: "Sections"))
                    } footer: {
                        if !sortedSections.isEmpty {
                            Text(String(format: NSLocalizedString("prose.files.assignCount", comment: "Assign count"), selectedFiles.count))
                        }
                    }
                }
            }
            .navigationTitle(assignedSection != nil ? NSLocalizedString("prose.files.sectionAssignment", comment: "Section Assignment") : NSLocalizedString("prose.files.addToSection", comment: "Add to Section"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
