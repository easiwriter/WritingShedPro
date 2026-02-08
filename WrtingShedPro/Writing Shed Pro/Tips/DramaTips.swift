//
//  DramaTips.swift
//  Writing Shed Pro
//
//  Feature 035: TipKit Tips
//  FR-6: Drama Tips
//

import TipKit

// MARK: - FR-6.1: Drama Structure Tip
/// Shown when opening a drama project
struct DramaStructureTip: Tip {
    var title: Text {
        Text("Drama Mode")
    }
    
    var message: Text? {
        Text("Drama projects use Acts and Scenes. Add stage directions and character dialogue using the formatting toolbar.")
    }
    
    var image: Image? {
        Image(systemName: "theatermasks")
    }
    
    static let guideSection: String? = "81-drama-mode-overview"
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}
