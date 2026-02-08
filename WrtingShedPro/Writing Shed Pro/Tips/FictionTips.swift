//
//  FictionTips.swift
//  Writing Shed Pro
//
//  Feature 035: TipKit Tips
//  FR-5: Fiction Tips
//

import TipKit

// MARK: - FR-5.1: Scenes & Chapters Tip
/// Shown when opening a fiction project for the first time
struct ScenesAndChaptersTip: Tip {
    var title: Text {
        Text("Build Your Story")
    }
    
    var message: Text? {
        Text("Add scenes to build your story, then organise them into chapters. Scenes can be moved between chapters freely.")
    }
    
    var image: Image? {
        Image(systemName: "text.book.closed")
    }
    
    static let guideSection: String? = "73-scene-organization"
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}

// MARK: - FR-5.2: Plot Elements Tip
/// Shown when the Plot folder is first opened
struct PlotElementsTip: Tip {
    var title: Text {
        Text("Track Your Story Elements")
    }
    
    var message: Text? {
        Text("Track characters, locations, and plot threads here. Link them to scenes to see where each element appears.")
    }
    
    var image: Image? {
        Image(systemName: "person.3")
    }
    
    static let guideSection: String? = "71-fiction-mode-overview"
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}

// MARK: - FR-5.3: Scene Info Tip
/// Shown when viewing the scene list
struct SceneInfoTip: Tip {
    var title: Text {
        Text("Scene Details")
    }
    
    var message: Text? {
        Text("Tap the info button on any scene to add a synopsis, set status, or link plot elements.")
    }
    
    var image: Image? {
        Image(systemName: "info.circle")
    }
    
    static let guideSection: String? = "73-scene-organization"
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}

// MARK: - FR-5.4: Verse Novel Tip
/// Shown when creating a Verse Novel fiction project
struct VerseNovelTip: Tip {
    var title: Text {
        Text("Verse Novel Mode")
    }
    
    var message: Text? {
        Text("In a Verse Novel, chapters are called Books and scenes are Episodes. Episodes use the poetry editor.")
    }
    
    var image: Image? {
        Image(systemName: "text.book.closed.fill")
    }
    
    static let guideSection: String? = "71-fiction-mode-overview"
    
    @Parameter
    static var isVerseNovel: Bool = false
    
    var rules: [Rule] {
        #Rule(Self.$isVerseNovel) { $0 == true }
    }
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}
