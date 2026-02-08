//
//  ImportExportTips.swift
//  Writing Shed Pro
//
//  Feature 035: TipKit Tips
//  FR-7: Import/Export Tips
//

import TipKit

// MARK: - FR-7.1: Word Import Tip
/// Shown when a Prose/Scenes folder is empty
struct WordImportTip: Tip {
    var title: Text {
        Text("Import Word Documents")
    }
    
    var message: Text? {
        Text("You can import .docx files — tap the + button and choose Import Word Document.")
    }
    
    var image: Image? {
        Image(systemName: "arrow.down.doc")
    }
    
    static let guideSection: String? = "91-export-options"
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}

// MARK: - FR-7.2: Manuscript Assembly Tip
/// Shown when a fiction project has 3+ chapters
struct ManuscriptAssemblyTip: Tip {
    var title: Text {
        Text("Compile Your Manuscript")
    }
    
    var message: Text? {
        Text("Ready to compile? Use Manuscript Assembly to combine your chapters into a single document for export.")
    }
    
    var image: Image? {
        Image(systemName: "doc.on.doc")
    }
    
    static let guideSection: String? = "74-manuscript-formatting"
    
    @Parameter
    static var hasEnoughChapters: Bool = false
    
    var rules: [Rule] {
        #Rule(Self.$hasEnoughChapters) { $0 == true }
    }
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}

// MARK: - FR-7.3: PDF Export Tip
/// Shown after using Page Preview
struct PDFExportTip: Tip {
    var title: Text {
        Text("Export as PDF")
    }
    
    var message: Text? {
        Text("You can export your paginated document as a PDF from the share menu.")
    }
    
    var image: Image? {
        Image(systemName: "square.and.arrow.up")
    }
    
    static let guideSection: String? = "92-pdf-export"
    
    static let pagePreviewUsed = Event(id: "pagePreviewUsed")
    
    var rules: [Rule] {
        #Rule(Self.pagePreviewUsed) { $0.donations.count >= 1 }
    }
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}
