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
        Text("Drag files to reorder them, or use the sort options in the toolbar.")
    }
    
    var image: Image? {
        Image(systemName: "arrow.up.arrow.down.circle")
    }
    
    static let guideSection: String? = "35-organizing-your-work"
    
    @Parameter
    static var folderHasManyFiles: Bool = false
    
    var rules: [Rule] {
        #Rule(Self.$folderHasManyFiles) { $0 == true }
    }
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}
