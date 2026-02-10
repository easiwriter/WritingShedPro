//
//  ProjectTips.swift
//  Writing Shed Pro
//
//  Feature 035: TipKit Tips
//  FR-2: Project & Navigation Tips
//

import TipKit

// MARK: - FR-2.1: First Project Tip
/// Shown when the project list is empty
struct FirstProjectTip: Tip {
    var title: Text {
        Text("Create Your First Project")
    }
    
    var message: Text? {
        Text("Tap + to create your first writing project. Choose from Prose, Poetry, Fiction, or Drama.")
    }
    
    var image: Image? {
        Image(systemName: "plus.circle")
    }
    
    static let guideSection: String? = "22-creating-your-first-project"
    
    @Parameter
    static var hasNoProjects: Bool = true
    
    var rules: [Rule] {
        #Rule(Self.$hasNoProjects) { $0 == true }
    }
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}

// MARK: - FR-2.2: Project Types Tip
/// Shown in AddProjectSheet when choosing a project type
struct ProjectTypesTip: Tip {
    var title: Text {
        Text("Choose a Project Type")
    }
    
    var message: Text? {
        Text("Each type provides specialised folders and tools. Prose for essays, Fiction for novels with chapters and scenes, Poetry with verse forms, and Drama with acts and stage directions.")
    }
    
    var image: Image? {
        Image(systemName: "square.stack.3d.up")
    }
    
    static let guideSection: String? = "31-project-types-overview"
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}

// MARK: - FR-2.3: Long-Press Back Tip
/// Shown when navigating 2+ levels deep in fiction/drama
struct LongPressBackTip: Tip {
    var title: Text {
        Text("Jump Back to Project List")
    }
    
    var message: Text? {
        Text("Long-press the back button to jump straight back to the project list.")
    }
    
    var image: Image? {
        Image(systemName: "arrow.uturn.backward")
    }
    
    static let guideSection: String? = nil
}

// MARK: - FR-2.4: Folder Organisation Tip
/// Shown when a folder contains files, after the FileListToolbarTip is dismissed.
/// Uses a Tips.Event rule so it appears as a follow-on tip.
struct FolderOrganisationTip: Tip {
    /// Donated when the FileListToolbarTip is dismissed/invalidated.
    static let fileListToolbarTipDismissed = Tips.Event(id: "fileListToolbarTipDismissed")
    
    var title: Text {
        Text("Organise Your Files")
    }
    
    var message: Text? {
        Text("Use the workflow filters above to focus on Drafts or Ready files. Tap the \(Image(systemName: "ellipsis.circle")) button on any file for more options.")
    }
    
    var image: Image? {
        Image(systemName: "line.3.horizontal.decrease.circle")
    }
    
    static let guideSection: String? = "35-organizing-your-work"
    
    var rules: [Rule] {
        #Rule(Self.fileListToolbarTipDismissed) { $0.donations.count >= 1 }
    }
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}

// MARK: - FR-2.8: File List Toolbar Guide Tip
/// Inline tip describing the file list toolbar buttons.
/// Shown when a user first enters a file list view; on dismissal, triggers
/// the FolderOrganisationTip via Tips.Event.
struct FileListToolbarTip: Tip {
    var title: Text {
        Text("Your File List Toolbar")
    }
    
    var message: Text? {
        Text("\(Image(systemName: "magnifyingglass")) Search — find and replace across files\n\(Image(systemName: "square.and.arrow.down")) Import — bring in Word or Markdown files\n\(Image(systemName: "rectangle.and.pencil.and.ellipsis")) Headers & Footers — edit page headers and footers\n\(Image(systemName: "plus")) Add — create a new file\nEdit — select files to delete or reorder")
            .font(.callout)
            .foregroundStyle(.primary)
    }
    
    var image: Image? {
        Image(systemName: "hammer")
    }
}

// MARK: - FR-2.9: Scene List Toolbar Guide Tip (Drama)
/// Variant of the file list toolbar tip for drama/fiction scene lists.
struct SceneListToolbarTip: Tip {
    var title: Text {
        Text("Your Scene List Toolbar")
    }
    
    var message: Text? {
        Text("\(Image(systemName: "magnifyingglass")) Search — find and replace across scenes\n\(Image(systemName: "square.and.arrow.down")) Import — bring in Word or Markdown files\n\(Image(systemName: "rectangle.and.pencil.and.ellipsis")) Headers & Footers — edit page headers and footers\n\(Image(systemName: "plus")) Add — create a new scene\nEdit — select scenes to delete or reorder")
            .font(.callout)
            .foregroundStyle(.primary)
    }
    
    var image: Image? {
        Image(systemName: "hammer")
    }
}

// MARK: - FR-2.6: Create Project Popover Tip
/// Popover tip pointing at the + button, shown after the ToolbarGuideTip is dismissed.
/// Uses a Tips.Event rule so TipKit controls the sequencing natively.
struct CreateProjectTip: Tip {
    /// Donated when the ToolbarGuideTip is dismissed/invalidated.
    static let toolbarTipDismissed = Tips.Event(id: "toolbarTipDismissed")
    
    var title: Text {
        Text("Create a Project")
    }
    
    var message: Text? {
        Text("Tap here to create your first writing project.")
    }
    
    var image: Image? {
        Image(systemName: "plus.circle")
    }
    
    static let guideSection: String? = "22-creating-your-first-project"
    
    var rules: [Rule] {
        #Rule(Self.toolbarTipDismissed) { $0.donations.count >= 1 }
    }
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}

// MARK: - FR-2.7: Toolbar Guide Tip
/// Inline tip describing all toolbar buttons, shown on first launch.
/// Display timing is controlled by the view via UserDefaults ("tipkit.appLaunchCount"),
/// not by TipKit @Parameter rules (which have unreliable persistence timing).
struct ToolbarGuideTip: Tip {
    var title: Text {
        Text("Your Toolbar")
    }
    
    var message: Text? {
        Text("\(Image(systemName: "gearshape")) Settings — import, stylesheets, page setup\n\(Image(systemName: "questionmark.circle")) Help — open the user guide\n\(Image(systemName: "plus")) New project — create a writing project\n\(Image(systemName: "arrow.up.arrow.down")) Sort — change the project list order\nEdit — select projects to delete")
            .font(.callout)
            .foregroundStyle(.primary)
    }
    
    var image: Image? {
        Image(systemName: "hammer")
    }
    
    var actions: [Action] {
        Action(id: "interface-tour", title: "Interface Tour")
        Action(id: "settings-guide", title: "Settings Guide")
    }
}

// MARK: - FR-2.5: New File Tip
/// Shown when adding a file
struct NewFileTip: Tip {
    var title: Text {
        Text("Create a New File")
    }
    
    var message: Text? {
        Text("Give your file a name and tap Add. You can change the name later from the file's context menu.")
    }
    
    var image: Image? {
        Image(systemName: "doc.badge.plus")
    }
    
    static let guideSection: String? = "35-organizing-your-work"
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}
