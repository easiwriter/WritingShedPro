//
//  WSPDramaRenderer.swift
//  WSP Reader
//
//  Lightweight DML renderer for drama projects in the reader.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum WSPDramaScriptType: String {
    case film
    case stage
}

enum WSPDramaFormattingConstants {
    enum Film {
        static let actionLeftMargin: CGFloat = 108
        static let characterLeftMargin: CGFloat = 252
        static let dialogueLeftMargin: CGFloat = 180
        static let parentheticalLeftMargin: CGFloat = 216
        static let transitionRightMargin: CGFloat = 72
        static let sceneHeadingLeftMargin: CGFloat = 108
    }

    enum Stage {
        static let stageDirectionLeftMargin: CGFloat = 72
        static let characterLeftMargin: CGFloat = 72
        static let dialogueLeftMargin: CGFloat = 144
        static let sceneHeadingLeftMargin: CGFloat = 72
    }

    static let scriptFont = UIFont(name: "Courier", size: 12) ?? UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    static let scriptFontBold = UIFont(name: "Courier-Bold", size: 12) ?? UIFont.monospacedSystemFont(ofSize: 12, weight: .bold)
    static let scriptFontItalic = UIFont(name: "Courier-Oblique", size: 12) ?? UIFont.italicSystemFont(ofSize: 12)
}

final class WSPDramaRenderer {
    static let shared = WSPDramaRenderer()

    private init() {}

    func render(source: String, scriptTypeRaw: String?) -> NSAttributedString {
        let scriptType = WSPDramaScriptType(rawValue: scriptTypeRaw?.lowercased() ?? "") ?? .film
        let lines = source.components(separatedBy: .newlines)
        let result = NSMutableAttributedString()

        var pendingLocation: String?
        var pendingTime: String?

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if index > 0 {
                result.append(NSAttributedString(string: "\n"))
            }

            if trimmed.isEmpty {
                continue
            }

            if trimmed.hasPrefix("[[") && trimmed.hasSuffix("]]" ) {
                continue
            }

            if trimmed.hasPrefix("@ LOCATION:") {
                pendingLocation = trimmed.replacingOccurrences(of: "@ LOCATION:", with: "").trimmingCharacters(in: .whitespaces)
                continue
            }

            if trimmed.hasPrefix("=") {
                pendingTime = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                continue
            }

            if trimmed.hasPrefix("#") {
                let sceneHeading = buildSceneHeading(from: trimmed, location: pendingLocation, time: pendingTime, scriptType: scriptType)
                result.append(sceneHeading)
                pendingLocation = nil
                pendingTime = nil
                continue
            }

            if trimmed.hasPrefix(">>") {
                result.append(renderTransition(String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces), scriptType: scriptType))
                continue
            }

            if trimmed.hasPrefix(">") {
                result.append(renderAction(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces), scriptType: scriptType))
                continue
            }

            if trimmed.hasPrefix("(") && trimmed.hasSuffix(")") {
                result.append(renderParenthetical(trimmed, scriptType: scriptType))
                continue
            }

            if isCharacterCue(trimmed) {
                result.append(renderCharacter(trimmed, scriptType: scriptType))
                continue
            }

            result.append(renderDialogue(trimmed, scriptType: scriptType))
        }

        return result
    }

    private func buildSceneHeading(from line: String, location: String?, time: String?, scriptType: WSPDramaScriptType) -> NSAttributedString {
        let raw = line.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        let heading: String

        if raw.hasPrefix("INT.") || raw.hasPrefix("EXT.") || raw.hasPrefix("INT/EXT") {
            heading = raw
        } else if let location, let time, !location.isEmpty, !time.isEmpty {
            heading = "INT. \(location.uppercased()) - \(time.uppercased())"
        } else if let location, !location.isEmpty {
            heading = "INT. \(location.uppercased()) - DAY"
        } else {
            heading = raw.uppercased()
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = scriptType == .film ? WSPDramaFormattingConstants.Film.sceneHeadingLeftMargin : WSPDramaFormattingConstants.Stage.sceneHeadingLeftMargin
        paragraphStyle.headIndent = paragraphStyle.firstLineHeadIndent
        paragraphStyle.paragraphSpacingBefore = 24
        paragraphStyle.paragraphSpacing = 12

        return NSAttributedString(string: heading, attributes: [
            .font: WSPDramaFormattingConstants.scriptFontBold,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ])
    }

    private func renderAction(_ text: String, scriptType: WSPDramaScriptType) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = scriptType == .film ? WSPDramaFormattingConstants.Film.actionLeftMargin : WSPDramaFormattingConstants.Stage.stageDirectionLeftMargin
        paragraphStyle.headIndent = paragraphStyle.firstLineHeadIndent
        paragraphStyle.tailIndent = -72
        paragraphStyle.paragraphSpacing = 12

        return NSAttributedString(string: text, attributes: [
            .font: WSPDramaFormattingConstants.scriptFont,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ])
    }

    private func renderCharacter(_ text: String, scriptType: WSPDramaScriptType) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = scriptType == .film ? WSPDramaFormattingConstants.Film.characterLeftMargin : WSPDramaFormattingConstants.Stage.characterLeftMargin
        paragraphStyle.headIndent = paragraphStyle.firstLineHeadIndent
        paragraphStyle.paragraphSpacingBefore = 12
        paragraphStyle.paragraphSpacing = 0

        return NSAttributedString(string: text.uppercased(), attributes: [
            .font: WSPDramaFormattingConstants.scriptFontBold,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ])
    }

    private func renderParenthetical(_ text: String, scriptType: WSPDramaScriptType) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = scriptType == .film ? WSPDramaFormattingConstants.Film.parentheticalLeftMargin : WSPDramaFormattingConstants.Stage.dialogueLeftMargin
        paragraphStyle.headIndent = paragraphStyle.firstLineHeadIndent
        paragraphStyle.paragraphSpacing = 0

        return NSAttributedString(string: text, attributes: [
            .font: WSPDramaFormattingConstants.scriptFontItalic,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ])
    }

    private func renderDialogue(_ text: String, scriptType: WSPDramaScriptType) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = scriptType == .film ? WSPDramaFormattingConstants.Film.dialogueLeftMargin : WSPDramaFormattingConstants.Stage.dialogueLeftMargin
        paragraphStyle.headIndent = paragraphStyle.firstLineHeadIndent
        paragraphStyle.tailIndent = -72
        paragraphStyle.paragraphSpacing = 12

        return NSAttributedString(string: text, attributes: [
            .font: WSPDramaFormattingConstants.scriptFont,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ])
    }

    private func renderTransition(_ text: String, scriptType: WSPDramaScriptType) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        paragraphStyle.firstLineHeadIndent = scriptType == .film ? WSPDramaFormattingConstants.Film.sceneHeadingLeftMargin : WSPDramaFormattingConstants.Stage.sceneHeadingLeftMargin
        paragraphStyle.headIndent = paragraphStyle.firstLineHeadIndent
        paragraphStyle.paragraphSpacingBefore = 12
        paragraphStyle.paragraphSpacing = 12

        return NSAttributedString(string: text.uppercased(), attributes: [
            .font: WSPDramaFormattingConstants.scriptFont,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ])
    }

    private func isCharacterCue(_ text: String) -> Bool {
        guard text.count >= 2 else { return false }
        let allowed = CharacterSet.uppercaseLetters
            .union(.decimalDigits)
            .union(CharacterSet(charactersIn: " .'-"))
        return text.uppercased() == text && text.rangeOfCharacter(from: allowed.inverted) == nil
    }
}