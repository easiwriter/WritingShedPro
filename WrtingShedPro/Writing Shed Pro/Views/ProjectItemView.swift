import SwiftUI
import SwiftData

struct ProjectItemView: View {
    let project: Project
    let onOpenTapped: () -> Void
    let onInfoTapped: () -> Void
    let onPageSetupTapped: () -> Void
    var onManageFormsTapped: (() -> Void)? = nil
    var onPoetrySettingsTapped: (() -> Void)? = nil
    var onDuplicateTapped: (() -> Void)? = nil
    var onExportTapped: (() -> Void)? = nil
    var isDuplicate: Bool = false
    
    @Environment(\.modelContext) var modelContext
    @Query(sort: \StyleSheet.name) private var allStyleSheets: [StyleSheet]

    private var uniqueStyleSheetsForMenu: [StyleSheet] {
        var grouped: [String: [StyleSheet]] = [:]

        for sheet in allStyleSheets {
            let normalized = sheet.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            grouped[normalized, default: []].append(sheet)
        }

        return grouped.values.compactMap { group in
            if group.count == 1 {
                return group.first
            }

            if let current = project.styleSheet,
               let match = group.first(where: { $0.id == current.id }) {
                return match
            }

            return group.sorted { lhs, rhs in
                if lhs.isSystemStyleSheet != rhs.isSystemStyleSheet {
                    return lhs.isSystemStyleSheet
                }
                return lhs.createdDate <= rhs.createdDate
            }.first
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    /// Returns the display name for the project type, showing specific fiction class for fiction projects
    private var projectTypeDisplayName: String {
        if project.type == .fiction, let fictionClass = project.fictionClass {
            return fictionClass.localizedName
        }
        return project.type.rawValue.capitalized
    }

    /// Poetry settings apply to Poetry projects and Verse Novel fiction projects.
    private var supportsPoetrySettings: Bool {
        project.type == .poetry || (project.type == .fiction && project.fictionClass == .verseNovel)
    }
    
    var body: some View {
        HStack {
            Button(action: onOpenTapped) {
                HStack {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "archivebox")
                            .imageScale(.large)
                            .foregroundStyle(.blue)
                            .accessibilityHidden(true)
                        if isDuplicate {
                            Image(systemName: "2.square.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                                .offset(x: 4, y: -4)
                                .accessibilityLabel(NSLocalizedString("projectItem.duplicate", comment: "Duplicate project indicator"))
                        }
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text(project.name ?? NSLocalizedString("projectItem.untitledProject", comment: "Untitled project"))
                            .font(.headline)
                            .lineLimit(.max)
                        Text(projectTypeDisplayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
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
                
                if supportsPoetrySettings, let onPoetrySettingsTapped = onPoetrySettingsTapped {
                    Button(action: onPoetrySettingsTapped) {
                        Label(NSLocalizedString("settings.poetrySettings", comment: "Poetry Settings"), systemImage: "waveform.path")
                    }
                }
                
                stylesheetSubmenu

                if let onDuplicateTapped = onDuplicateTapped {
                    Button(action: onDuplicateTapped) {
                        Label(NSLocalizedString("projectItem.duplicateProject", comment: "Duplicate project"), systemImage: "plus.square.on.square")
                    }
                }
                
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
            ForEach(uniqueStyleSheetsForMenu, id: \.id) { (sheet: StyleSheet) in
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
