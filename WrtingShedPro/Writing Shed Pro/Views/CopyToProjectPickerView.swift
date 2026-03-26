import SwiftUI
import SwiftData

/// Picker view for selecting a destination project when copying files between projects.
/// Only shows projects of the same type as the source, excluding the source project.
struct CopyToProjectPickerView: View {
    let sourceProject: Project
    let filesToCopy: [TextFile]
    let onProjectSelected: (Project) -> Void
    let onCancel: () -> Void
    
    @Query private var allProjects: [Project]

    private func isPoetryCompatible(_ project: Project) -> Bool {
        project.type == .poetry || (project.type == .fiction && project.fictionClass == .verseNovel)
    }
    
    /// Filtered list: same type, not trashed, not the source project
    private var eligibleProjects: [Project] {
        DeduplicationService.presentedProjects(from: allProjects.filter { project in
            (
                project.type == sourceProject.type ||
                (isPoetryCompatible(sourceProject) && isPoetryCompatible(project))
            ) &&
            !project.isTrashed &&
            project.id != sourceProject.id
        })
        .sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if eligibleProjects.isEmpty {
                    ContentUnavailableView {
                        Label(
                            NSLocalizedString("copyToProject.noProjects.title", comment: "No Projects Available"),
                            systemImage: "folder.badge.questionmark"
                        )
                    } description: {
                        Text(String(format: NSLocalizedString("copyToProject.noProjects.message", comment: "No other projects of type"), sourceProject.type.localizedName))
                    }
                } else {
                    List {
                        Section {
                            ForEach(eligibleProjects) { project in
                                Button {
                                    onProjectSelected(project)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(project.name ?? NSLocalizedString("common.untitled", comment: "Untitled"))
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            if let details = project.details, !details.isEmpty {
                                                Text(details)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        } header: {
                            Text(String(format: NSLocalizedString("copyToProject.section.header", comment: "Copy %d file(s) to:"), filesToCopy.count))
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("copyToProject.title", comment: "Copy to Project"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        onCancel()
                    }
                }
            }
        }
    }
}
