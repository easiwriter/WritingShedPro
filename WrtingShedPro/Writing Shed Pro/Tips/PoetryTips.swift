//
//  PoetryTips.swift
//  Writing Shed Pro
//
//  Feature 035: TipKit Tips
//  FR-4: Poetry Tips
//

import TipKit

// MARK: - FR-4.1: Poetry Form Tip
/// Shown when creating or editing a poem
struct PoetryFormTip: Tip {
    var title: Text {
        Text("Choose a Poetry Form")
    }
    
    var message: Text? {
        Text("Choose a poetry form to get guided structure with syllable counts and rhyme scheme hints.")
    }
    
    var image: Image? {
        Image(systemName: "text.alignleft")
    }
    
    static let guideSection: String? = "65-forms-and-templates"
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}

// MARK: - FR-4.2: Syllable Counter Tip
/// Shown when editing a poem with a form applied
struct SyllableCounterTip: Tip {
    var title: Text {
        Text("Syllable Counter")
    }
    
    var message: Text? {
        Text("The numbers on the right show your syllable count vs. the target for each line.")
    }
    
    var image: Image? {
        Image(systemName: "textformat.123")
    }
    
    static let guideSection: String? = "62-syllable-counting"
    
    @Parameter
    static var hasPoetryForm: Bool = false
    
    var rules: [Rule] {
        #Rule(Self.$hasPoetryForm) { $0 == true }
    }
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}

// MARK: - FR-4.3: CMU Dictionary Tip
/// Shown when a syllable count mismatch occurs
struct CMUDictionaryTip: Tip {
    var title: Text {
        Text("Syllable Alternatives")
    }
    
    var message: Text? {
        Text("The syllable counter uses the CMU Pronouncing Dictionary. Tap a line to see alternative pronunciations.")
    }
    
    var image: Image? {
        Image(systemName: "book")
    }
    
    static let guideSection: String? = "62-syllable-counting"
    
    @Parameter
    static var hasSyllableMismatch: Bool = false
    
    var rules: [Rule] {
        #Rule(Self.$hasSyllableMismatch) { $0 == true }
    }
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}
