//
//  DramaMarkupRenderer.swift
//  Writing Shed Pro
//
//  Feature 023: Smart Drama Creation
//  Renderer for Drama Markup Language (DML) - converts parsed elements to styled text
//

import Foundation
import UIKit

/// Renderer for Drama Markup Language (DML)
/// Converts parsed DMLDocument elements to NSAttributedString for display
final class DramaMarkupRenderer {
    
    // MARK: - Singleton
    
    static let shared = DramaMarkupRenderer()
    
    private init() {}
    
    // MARK: - Configuration
    
    /// The page width for text wrapping (in points)
    var pageWidth: CGFloat = 612  // US Letter width
    
    // MARK: - Public API
    
    /// Render a DMLDocument to attributed string for display
    /// - Parameters:
    ///   - document: The parsed DML document
    ///   - scriptType: Film or Stage format
    ///   - viewMode: Source, Formatted, or Print
    ///   - showNotes: Whether to show notes (hidden in formatted/print modes by default)
    /// - Returns: Styled NSAttributedString
    func render(
        _ document: DMLDocument,
        scriptType: DramaScriptType,
        viewMode: DramaViewMode,
        showNotes: Bool = false
    ) -> NSAttributedString {
        
        switch viewMode {
        case .source:
            return renderSource(document)
        case .formatted, .print:
            return renderFormatted(document, scriptType: scriptType, showNotes: showNotes)
        }
    }
    
    /// Render DML source text directly (for editing)
    /// - Parameter source: Raw DML text
    /// - Returns: Syntax-highlighted attributed string
    func renderSource(_ source: String) -> NSAttributedString {
        let document = DramaMarkupParser.shared.parse(source)
        return renderSource(document)
    }
    
    // MARK: - Source Mode Rendering
    
    /// Render source mode with syntax highlighting
    private func renderSource(_ document: DMLDocument) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        // Base font for source mode (monospace)
        let baseFont = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        let baseParagraphStyle = NSMutableParagraphStyle()
        baseParagraphStyle.lineSpacing = 2
        
        // Colors for syntax highlighting
        let colors: [DMLElementType: UIColor] = [
            .sceneHeading: .systemBlue,
            .locationMeta: .systemPurple,
            .timeMeta: .systemPurple,
            .action: .systemGreen,
            .transition: .systemOrange,
            .character: .systemBrown,
            .parenthetical: .systemGray,
            .dialogue: .label,
            .note: .systemYellow,
            .blank: .label
        ]
        
        var previousLineNumber = 0
        
        for element in document.elements {
            // Add newline if not first element
            if previousLineNumber > 0 {
                result.append(NSAttributedString(string: "\n"))
            }
            
            let color = colors[element.type] ?? .label
            let attributes: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: color,
                .paragraphStyle: baseParagraphStyle
            ]
            
            result.append(NSAttributedString(string: element.rawLine, attributes: attributes))
            previousLineNumber = element.lineNumber
        }
        
        return result
    }
    
    // MARK: - Formatted Mode Rendering
    
    /// Render formatted mode with proper screenplay/stage play styling
    private func renderFormatted(
        _ document: DMLDocument,
        scriptType: DramaScriptType,
        showNotes: Bool
    ) -> NSAttributedString {
        
        let result = NSMutableAttributedString()
        var previousType: DMLElementType?
        
        for element in document.elements {
            // Skip notes if not showing them
            if element.type == .note && !showNotes {
                continue
            }
            
            // Skip blank lines but track for spacing
            if element.type == .blank {
                previousType = .blank
                continue
            }
            
            // Add spacing between elements
            if previousType != nil && previousType != .blank {
                let spacing = spacingBefore(element.type, previousType: previousType!, scriptType: scriptType)
                if spacing > 0 {
                    let spacer = NSAttributedString(string: "\n", attributes: [
                        .font: DMLFormattingConstants.scriptFont
                    ])
                    for _ in 0..<spacing {
                        result.append(spacer)
                    }
                }
            } else if previousType == .blank && result.length > 0 {
                // Blank line creates paragraph break
                result.append(NSAttributedString(string: "\n"))
            }
            
            // Render the element
            let rendered = renderElement(element, scriptType: scriptType, document: document)
            result.append(rendered)
            
            previousType = element.type
        }
        
        return result
    }
    
    /// Render a single element according to script type
    private func renderElement(
        _ element: DMLElement,
        scriptType: DramaScriptType,
        document: DMLDocument
    ) -> NSAttributedString {
        
        switch scriptType {
        case .film:
            return renderFilmElement(element, document: document)
        case .stage:
            return renderStageElement(element, document: document)
        }
    }
    
    // MARK: - Film/Screenplay Rendering
    
    private func renderFilmElement(_ element: DMLElement, document: DMLDocument) -> NSAttributedString {
        let font = DMLFormattingConstants.scriptFont
        let boldFont = DMLFormattingConstants.scriptFontBold
        
        switch element.type {
        case .sceneHeading:
            return renderFilmSceneHeading(element, document: document, font: boldFont)
            
        case .action:
            return renderFilmAction(element, font: font)
            
        case .character:
            return renderFilmCharacter(element, font: font)
            
        case .parenthetical:
            return renderFilmParenthetical(element, font: font)
            
        case .dialogue:
            return renderFilmDialogue(element, font: font)
            
        case .transition:
            return renderFilmTransition(element, font: font)
            
        case .locationMeta, .timeMeta:
            // Metadata is used to construct scene heading, not shown separately
            return NSAttributedString()
            
        case .note:
            return renderNote(element, font: font)
            
        case .blank:
            return NSAttributedString()
        }
    }
    
    private func renderFilmSceneHeading(_ element: DMLElement, document: DMLDocument, font: UIFont) -> NSAttributedString {
        // Check if the heading already looks like INT./EXT. format
        var heading = element.content
        
        if !heading.hasPrefix("INT.") && !heading.hasPrefix("EXT.") && !heading.hasPrefix("INT/EXT") {
            // Construct from metadata if available
            if let location = document.location, let time = document.timeAtmosphere {
                heading = "INT. \(location.uppercased()) - \(time.uppercased())"
            } else if let location = document.location {
                heading = "INT. \(location.uppercased()) - DAY"
            }
        }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = DMLFormattingConstants.Film.sceneHeadingLeftMargin
        paragraphStyle.headIndent = DMLFormattingConstants.Film.sceneHeadingLeftMargin
        paragraphStyle.paragraphSpacingBefore = 24
        paragraphStyle.paragraphSpacing = 12
        
        return NSAttributedString(string: heading + "\n", attributes: [
            .font: font,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ])
    }
    
    private func renderFilmAction(_ element: DMLElement, font: UIFont) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = DMLFormattingConstants.Film.actionLeftMargin
        paragraphStyle.headIndent = DMLFormattingConstants.Film.actionLeftMargin
        paragraphStyle.tailIndent = -DMLFormattingConstants.Film.actionRightMargin
        paragraphStyle.paragraphSpacing = 12
        
        return NSAttributedString(string: element.content + "\n", attributes: [
            .font: font,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ])
    }
    
    private func renderFilmCharacter(_ element: DMLElement, font: UIFont) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = DMLFormattingConstants.Film.characterLeftMargin
        paragraphStyle.headIndent = DMLFormattingConstants.Film.characterLeftMargin
        paragraphStyle.paragraphSpacingBefore = 12
        
        return NSAttributedString(string: element.content + "\n", attributes: [
            .font: font,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ])
    }
    
    private func renderFilmParenthetical(_ element: DMLElement, font: UIFont) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = DMLFormattingConstants.Film.parentheticalLeftMargin
        paragraphStyle.headIndent = DMLFormattingConstants.Film.parentheticalLeftMargin
        paragraphStyle.tailIndent = -DMLFormattingConstants.Film.parentheticalRightMargin
        
        return NSAttributedString(string: element.content + "\n", attributes: [
            .font: font,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ])
    }
    
    private func renderFilmDialogue(_ element: DMLElement, font: UIFont) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = DMLFormattingConstants.Film.dialogueLeftMargin
        paragraphStyle.headIndent = DMLFormattingConstants.Film.dialogueLeftMargin
        paragraphStyle.tailIndent = -DMLFormattingConstants.Film.dialogueRightMargin
        paragraphStyle.paragraphSpacing = 0
        
        return NSAttributedString(string: element.content + "\n", attributes: [
            .font: font,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ])
    }
    
    private func renderFilmTransition(_ element: DMLElement, font: UIFont) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        paragraphStyle.tailIndent = -DMLFormattingConstants.Film.transitionRightMargin
        paragraphStyle.paragraphSpacingBefore = 12
        paragraphStyle.paragraphSpacing = 12
        
        return NSAttributedString(string: element.content + "\n", attributes: [
            .font: font,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ])
    }
    
    // MARK: - Stage Play Rendering
    
    private func renderStageElement(_ element: DMLElement, document: DMLDocument) -> NSAttributedString {
        let font = DMLFormattingConstants.scriptFont
        let italicFont = DMLFormattingConstants.scriptFontItalic
        
        switch element.type {
        case .sceneHeading:
            return renderStageSceneHeading(element, font: font)
            
        case .action:
            return renderStageDirection(element, font: italicFont)
            
        case .character:
            return renderStageCharacter(element, font: font)
            
        case .parenthetical:
            return renderStageParenthetical(element, font: italicFont)
            
        case .dialogue:
            return renderStageDialogue(element, font: font)
            
        case .transition:
            return renderStageTransition(element, font: italicFont)
            
        case .locationMeta, .timeMeta:
            // Metadata shown as stage direction in stage plays
            return renderStageDirection(
                DMLElement(type: .action, content: element.content, rawLine: element.rawLine, lineNumber: element.lineNumber),
                font: italicFont
            )
            
        case .note:
            return renderNote(element, font: font)
            
        case .blank:
            return NSAttributedString()
        }
    }
    
    private func renderStageSceneHeading(_ element: DMLElement, font: UIFont) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = DMLFormattingConstants.Stage.sceneHeadingLeftMargin
        paragraphStyle.headIndent = DMLFormattingConstants.Stage.sceneHeadingLeftMargin
        paragraphStyle.alignment = .center
        paragraphStyle.paragraphSpacingBefore = 24
        paragraphStyle.paragraphSpacing = 12
        
        return NSAttributedString(string: element.content + "\n", attributes: [
            .font: font,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ])
    }
    
    private func renderStageDirection(_ element: DMLElement, font: UIFont) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = DMLFormattingConstants.Stage.stageDirectionLeftMargin
        paragraphStyle.headIndent = DMLFormattingConstants.Stage.stageDirectionLeftMargin
        paragraphStyle.tailIndent = -DMLFormattingConstants.Stage.stageDirectionRightMargin
        paragraphStyle.paragraphSpacing = 12
        
        // Wrap in parentheses for stage play convention
        let text = "(\(element.content))\n"
        
        return NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ])
    }
    
    private func renderStageCharacter(_ element: DMLElement, font: UIFont) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = DMLFormattingConstants.Stage.characterLeftMargin
        paragraphStyle.headIndent = DMLFormattingConstants.Stage.characterLeftMargin
        paragraphStyle.paragraphSpacingBefore = 12
        
        return NSAttributedString(string: element.content + "\n", attributes: [
            .font: font,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ])
    }
    
    private func renderStageParenthetical(_ element: DMLElement, font: UIFont) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = DMLFormattingConstants.Stage.dialogueLeftMargin
        paragraphStyle.headIndent = DMLFormattingConstants.Stage.dialogueLeftMargin
        
        return NSAttributedString(string: "    " + element.content + "\n", attributes: [
            .font: font,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ])
    }
    
    private func renderStageDialogue(_ element: DMLElement, font: UIFont) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = DMLFormattingConstants.Stage.dialogueLeftMargin
        paragraphStyle.headIndent = DMLFormattingConstants.Stage.dialogueLeftMargin
        paragraphStyle.tailIndent = -DMLFormattingConstants.Stage.dialogueRightMargin
        paragraphStyle.paragraphSpacing = 0
        
        return NSAttributedString(string: "    " + element.content + "\n", attributes: [
            .font: font,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ])
    }
    
    private func renderStageTransition(_ element: DMLElement, font: UIFont) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = DMLFormattingConstants.Stage.stageDirectionLeftMargin
        paragraphStyle.headIndent = DMLFormattingConstants.Stage.stageDirectionLeftMargin
        paragraphStyle.paragraphSpacingBefore = 12
        paragraphStyle.paragraphSpacing = 12
        
        // Convert film transitions to stage equivalents
        var content = element.content
        if content.contains("CUT TO") || content.contains("DISSOLVE") {
            content = "BLACKOUT"
        }
        
        return NSAttributedString(string: "(\(content))\n", attributes: [
            .font: font,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ])
    }
    
    // MARK: - Common Rendering
    
    private func renderNote(_ element: DMLElement, font: UIFont) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = 72
        paragraphStyle.headIndent = 72
        paragraphStyle.paragraphSpacing = 6
        
        // Yellow background for notes
        return NSAttributedString(string: element.content + "\n", attributes: [
            .font: font,
            .foregroundColor: UIColor.darkGray,
            .backgroundColor: UIColor.systemYellow.withAlphaComponent(0.3),
            .paragraphStyle: paragraphStyle
        ])
    }
    
    // MARK: - Spacing Logic
    
    /// Determine how many blank lines to add before an element
    private func spacingBefore(_ type: DMLElementType, previousType: DMLElementType, scriptType: DramaScriptType) -> Int {
        switch type {
        case .sceneHeading:
            return 2  // Double space before scene headings
        case .character:
            return previousType == .dialogue || previousType == .parenthetical ? 1 : 0
        case .action:
            return previousType == .dialogue || previousType == .character ? 1 : 0
        case .transition:
            return 1
        default:
            return 0
        }
    }
}
