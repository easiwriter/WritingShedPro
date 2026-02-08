//
//  WorkflowTips.swift
//  Writing Shed Pro
//
//  Feature 035: TipKit Tips
//  FR-8: Workflow Tips
//

import TipKit

// MARK: - FR-8.1: Collections Tip
/// Shown after creating 10+ files across folders
struct CollectionsTip: Tip {
    var title: Text {
        Text("Group Related Files")
    }
    
    var message: Text? {
        Text("Use Collections to group related files from different folders — great for tracking submissions or thematic groupings.")
    }
    
    var image: Image? {
        Image(systemName: "tray.2")
    }
    
    static let guideSection: String? = "104-collections"
    
    static let fileCreated = Event(id: "fileCreated")
    
    var rules: [Rule] {
        #Rule(Self.fileCreated) { $0.donations.count >= 10 }
    }
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}

// MARK: - FR-8.2: Submissions Tip
/// Shown when the Submissions folder is first opened
struct SubmissionsTip: Tip {
    var title: Text {
        Text("Track Submissions")
    }
    
    var message: Text? {
        Text("Track your submissions to publishers and agents here. Record dates, responses, and link to the files you submitted.")
    }
    
    var image: Image? {
        Image(systemName: "paperplane")
    }
    
    static let guideSection: String? = "95-submission-tracking"
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}

// MARK: - FR-8.3: Comments Tip
/// Shown after 3+ editing sessions
struct CommentsTip: Tip {
    var title: Text {
        Text("Add Comments")
    }
    
    var message: Text? {
        Text("You can add comments to your text — select a passage and choose Add Comment from the context menu.")
    }
    
    var image: Image? {
        Image(systemName: "text.bubble")
    }
    
    static let guideSection: String? = "46-comments"
    
    static let editingSession = Event(id: "commentsEditingSession")
    
    var rules: [Rule] {
        #Rule(Self.editingSession) { $0.donations.count >= 3 }
    }
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}

// MARK: - FR-8.4: Footnotes Tip
/// Shown when editing an academic or non-fiction file
struct FootnotesTip: Tip {
    var title: Text {
        Text("Add Footnotes")
    }
    
    var message: Text? {
        Text("Add footnotes from the Insert menu. They auto-number and appear at the bottom of each page in Page Preview.")
    }
    
    var image: Image? {
        Image(systemName: "note.text")
    }
    
    static let guideSection: String? = "45-footnotes"
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}

// MARK: - FR-8.5: Search & Replace Tip
/// Shown after 5+ editing sessions
struct SearchReplaceTip: Tip {
    var title: Text {
        Text("Find & Replace")
    }
    
    var message: Text? {
        Text("Use ⌘F to search within a file, or use the project-wide search to find text across all files.")
    }
    
    var image: Image? {
        Image(systemName: "magnifyingglass")
    }
    
    static let guideSection: String? = "101-search-and-replace"
    
    static let editingSession = Event(id: "searchEditingSession")
    
    var rules: [Rule] {
        #Rule(Self.editingSession) { $0.donations.count >= 5 }
    }
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}
