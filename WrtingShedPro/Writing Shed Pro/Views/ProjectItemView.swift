import SwiftUI
import SwiftData

struct ProjectItemView: View {
    let project: Project
    let onInfoTapped: () -> Void
    
    @Environment(\.modelContext) var modelContext
    @State private var showPageSetup = false
    
    var body: some View {
        HStack {
            Image(systemName: "archivebox")
                .imageScale(.large)
                .foregroundStyle(.blue)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(project.name ?? NSLocalizedString("projectItem.untitledProject", comment: "Untitled project"))
                    .font(.headline)
                    .lineLimit(.max)
                Text(project.type.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Menu {
                Button(action: onInfoTapped) {
                    Label(NSLocalizedString("projectItem.projectDetails", comment: "Show project details"), systemImage: "info.circle")
                }
                
                Button(action: {}) {
                    Label(NSLocalizedString("projectItem.exportProject", comment: "Export project"), systemImage: "arrow.up.doc")
                }
                
                Button(action: { showPageSetup = true }) {
                    Label(NSLocalizedString("projectItem.pageSetup", comment: "Page setup"), systemImage: "doc.richtext")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .imageScale(.large)
                    .foregroundStyle(.blue)
                    .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 0))
                    .accessibilityHidden(true)
            }
            .accessibilityLabel(NSLocalizedString("projectItem.projectOptions", comment: "Project options menu"))
            .accessibilityHint("Double tap to open options for this project")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Project: \(project.name ?? NSLocalizedString("projectItem.untitledProject", comment: "Untitled project"))")
        .accessibilityValue(project.type.rawValue.capitalized)
        .accessibilityHint("Double tap to view project details")
        .sheet(isPresented: $showPageSetup) {
            PageSetupForm(project: project)
        }
    }
}

//#Preview {
//    let config = ModelConfiguration(isStoredInMemoryOnly: true)
//    let container = try! ModelContainer(for: Project.self, configurations: config)
//    
//    let sampleProject = Project(
//        name: "My Novel",
//        type: .prose
//    )
//    
//    ProjectItemView(
//        project: sampleProject,
//        onInfoTapped: {}
//    )
//    .modelContainer(container)
//}
