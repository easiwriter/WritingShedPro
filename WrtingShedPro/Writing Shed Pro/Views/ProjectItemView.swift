import SwiftUI
import SwiftData

struct ProjectItemView: View {
    let project: Project
    let onInfoTapped: () -> Void
    let onPageSetupTapped: () -> Void
    var onManageFormsTapped: (() -> Void)? = nil
    var onPoetrySettingsTapped: (() -> Void)? = nil
    var onExportTapped: (() -> Void)? = nil
    
    @Environment(\.modelContext) var modelContext
    @Query(sort: \StyleSheet.name) private var allStyleSheets: [StyleSheet]
    
    /// Returns the display name for the project type, showing specific fiction class for fiction projects
    private var projectTypeDisplayName: String {
        if project.type == .fiction, let fictionClass = project.fictionClass {
            return fictionClass.localizedName
        }
        return project.type.rawValue.capitalized
    }
    
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
                Text(projectTypeDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            projectOptionsMenu
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Project: \(project.name ?? NSLocalizedString("projectItem.untitledProject", comment: "Untitled project"))")
        .accessibilityValue(projectTypeDisplayName)
        .accessibilityHint("Double tap to view project details")
    }
    
    private var projectOptionsMenu: some View {
        Menu {
                Button(action: onInfoTapped) {
                    Label(NSLocalizedString("projectItem.projectDetails", comment: "Show project details"), systemImage: "info.circle")
                }
                
                Button(action: onPageSetupTapped) {
                    Label("Page Setup", systemImage: "doc.richtext")
                }
                
                if project.type == .poetry, let onManageFormsTapped = onManageFormsTapped {
                    Button(action: onManageFormsTapped) {
                        Label(NSLocalizedString("poetryForms.picker.manageButton", comment: "Manage Forms"), systemImage: "slider.horizontal.3")
                    }
                }
                
                if project.type == .poetry, let onPoetrySettingsTapped = onPoetrySettingsTapped {
                    Button(action: onPoetrySettingsTapped) {
                        Label(NSLocalizedString("settings.poetrySettings", comment: "Poetry Settings"), systemImage: "waveform.path")
                    }
                }
                
                stylesheetSubmenu
                
                if let onExportTapped = onExportTapped {
                    Button(action: onExportTapped) {
                        Label(NSLocalizedString("projectItem.exportProject", comment: "Export project"), systemImage: "arrow.up.doc")
                    }
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
    
    @ViewBuilder
    private var stylesheetSubmenu: some View {
        Menu {
            ForEach(allStyleSheets, id: \.id) { (sheet: StyleSheet) in
                Button {
                    project.styleSheet = sheet
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ProjectStyleSheetChanged"),
                        object: nil,
                        userInfo: [
                            "projectId": project.id.uuidString,
                            "styleSheetId": sheet.id.uuidString
                        ]
                    )
                } label: {
                    let isCurrentSheet: Bool = project.styleSheet?.id == sheet.id
                    HStack {
                        Text(sheet.name)
                        if sheet.isSystemStyleSheet {
                            Image(systemName: "star.fill")
                                .font(.caption)
                        }
                        Spacer()
                        if isCurrentSheet {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("Select Stylesheet", systemImage: "textformat")
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
