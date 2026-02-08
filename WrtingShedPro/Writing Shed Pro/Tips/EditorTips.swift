//
//  EditorTips.swift
//  Writing Shed Pro
//
//  Feature 035: TipKit Tips
//  FR-3: Editor Tips
//

import TipKit

// MARK: - FR-3.1: Formatting Toolbar Tip
/// Shown on first file open
struct FormattingToolbarTip: Tip {
    var title: Text {
        Text("Format Your Text")
    }
    
    var message: Text? {
        Text("Use the toolbar below to apply styles. Tap the paragraph style button (¶) to set headings, block quotes, and more.")
    }
    
    var image: Image? {
        Image(systemName: "textformat")
    }
    
    static let guideSection: String? = "42-text-formatting"
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}

// MARK: - FR-3.2: Markdown Toggle Tip
/// Shown on first RTF file open (non-Poetry, non-Drama)
struct MarkdownToggleTip: Tip {
    var title: Text {
        Text("Switch Between Formats")
    }
    
    var message: Text? {
        Text("You can switch between Rich Text and Markdown views using the format toggle in the toolbar menu.")
    }
    
    var image: Image? {
        Image(systemName: "arrow.left.arrow.right")
    }
    
    static let guideSection: String? = "96-markdown-features"
    
    @Parameter
    static var supportsMarkdown: Bool = false
    
    var rules: [Rule] {
        #Rule(Self.$supportsMarkdown) { $0 == true }
    }
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}

// MARK: - FR-3.3: Stylesheet Tip
/// Shown after the user first applies a paragraph style
struct StylesheetTip: Tip {
    var title: Text {
        Text("Customise Your Styles")
    }
    
    var message: Text? {
        Text("Styles come from your project's stylesheet. You can customise fonts, sizes, and colours in the Stylesheet Editor.")
    }
    
    var image: Image? {
        Image(systemName: "paintbrush")
    }
    
    static let guideSection: String? = "102-stylesheet-editor"
    
    static let styleApplied = Event(id: "styleApplied")
    
    var rules: [Rule] {
        #Rule(Self.styleApplied) { $0.donations.count >= 1 }
    }
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}

// MARK: - FR-3.4: Page Preview Tip
/// Shown after editing for 5+ sessions without using pagination
struct PagePreviewTip: Tip {
    var title: Text {
        Text("Preview Your Pages")
    }
    
    var message: Text? {
        Text("Want to see how your work looks on the page? Try Page Preview mode from the toolbar menu.")
    }
    
    var image: Image? {
        Image(systemName: "doc.richtext")
    }
    
    static let guideSection: String? = "103-page-setup"
    
    static let editingSession = Event(id: "editingSession")
    
    var rules: [Rule] {
        #Rule(Self.editingSession) { $0.donations.count >= 5 }
    }
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}

// MARK: - FR-3.5: Word Count Tip
/// Shown on first file open
struct WordCountTip: Tip {
    var title: Text {
        Text("Track Your Progress")
    }
    
    var message: Text? {
        Text("Tap the word count bar at the bottom to see detailed statistics including reading time and line count.")
    }
    
    var image: Image? {
        Image(systemName: "number")
    }
    
    static let guideSection: String? = "47-word-count-and-statistics"
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}
