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
/// Shown when a folder contains 5+ files
struct FolderOrganisationTip: Tip {
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
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}

// MARK: - FR-2.6: Create Project Popover Tip
/// Popover tip pointing at the + button on first launch
struct CreateProjectTip: Tip {
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
    
    /// Only show on the first app launch (count == 0)
    @Parameter
    static var appLaunchCount: Int = 0
    
    var rules: [Rule] {
        #Rule(Self.$appLaunchCount) { $0 == 0 }
    }
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}

// MARK: - FR-2.7: Settings Popover Tip
/// Popover tip pointing at the settings gear on second launch
struct SettingsTip: Tip {
    var title: Text {
        Text("Settings & More")
    }
    
    var message: Text? {
        Text("Import projects, customise stylesheets, set up page layout, and contact support.")
    }
    
    var image: Image? {
        Image(systemName: "gearshape")
    }
    
    static let guideSection: String? = "25-application-settings"
    
    /// Only show on the second app launch (count == 1)
    @Parameter
    static var appLaunchCount: Int = 0
    
    var rules: [Rule] {
        #Rule(Self.$appLaunchCount) { $0 == 1 }
    }
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
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
