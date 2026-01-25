//
//  MarkdownImportService.swift
//  Writing Shed Pro
//
//  Created on 25 January 2026.
//

import Foundation
import UIKit

/// Errors that can occur during Markdown import
enum MarkdownImportError: Error, LocalizedError {
    case invalidFile
    case encodingError
    case emptyContent
    case parsingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFile:
            return NSLocalizedString("import.markdown.error.invalid", comment: "Invalid Markdown file")
        case .encodingError:
            return NSLocalizedString("import.markdown.error.encoding", comment: "Could not read file encoding")
        case .emptyContent:
            return NSLocalizedString("import.markdown.error.empty", comment: "File is empty")
        case .parsingFailed(let reason):
            return NSLocalizedString("import.markdown.error.parsing", comment: "Failed to parse Markdown") + ": \(reason)"
        }
    }
}

/// Service for importing Markdown files and converting to NSAttributedString
/// Maps Markdown syntax to project stylesheet styles where available
class MarkdownImportService {
    
    // MARK: - Style Mapping
    
    /// Markdown element to WSP style name mapping
    private static let markdownToStyleMap: [MarkdownElement: String] = [
        .heading1: "title1",
        .heading2: "title2",
        .heading3: "title3",
        .heading4: "headline",
        .heading5: "subheadline",
        .heading6: "caption1",
        .body: "body",
        .blockquote: "callout",
        .codeBlock: "caption2"
    ]
    
    /// Markdown elements we recognize
    enum MarkdownElement {
        case heading1
        case heading2
        case heading3
        case heading4
        case heading5
        case heading6
        case body
        case blockquote
        case codeBlock
    }
    
    // MARK: - Public Import Methods
    
    /// Import a Markdown file from URL
    /// - Parameters:
    ///   - url: URL to the .md file
    ///   - styleSheet: Optional stylesheet to use for styling (if nil, uses default formatting)
    /// - Returns: NSAttributedString with converted content
    static func importMarkdown(from url: URL, styleSheet: StyleSheet? = nil) throws -> NSAttributedString {
        let data = try Data(contentsOf: url)
        return try importMarkdown(from: data, styleSheet: styleSheet)
    }
    
    /// Import Markdown from data
    /// - Parameters:
    ///   - data: Markdown file data
    ///   - styleSheet: Optional stylesheet to use for styling
    /// - Returns: NSAttributedString with converted content
    static func importMarkdown(from data: Data, styleSheet: StyleSheet? = nil) throws -> NSAttributedString {
        // Try UTF-8 first, then fallback to other encodings
        guard let content = String(data: data, encoding: .utf8) ??
                           String(data: data, encoding: .utf16) ??
                           String(data: data, encoding: .isoLatin1) else {
            throw MarkdownImportError.encodingError
        }
        
        return try importMarkdown(from: content, styleSheet: styleSheet)
    }
    
    /// Import Markdown from string
    /// - Parameters:
    ///   - content: Markdown string content
    ///   - styleSheet: Optional stylesheet to use for styling
    /// - Returns: NSAttributedString with converted content
    static func importMarkdown(from content: String, styleSheet: StyleSheet? = nil) throws -> NSAttributedString {
        guard !content.isEmpty else {
            throw MarkdownImportError.emptyContent
        }
        
        let result = NSMutableAttributedString()
        let lines = content.components(separatedBy: .newlines)
        
        var inCodeBlock = false
        var codeBlockContent = ""
        var codeBlockLanguage: String?
        var previousLineWasBlank = true
        
        for (index, line) in lines.enumerated() {
            // Handle fenced code blocks
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // End of code block
                    let codeAttr = formatCodeBlock(codeBlockContent, language: codeBlockLanguage, styleSheet: styleSheet)
                    result.append(codeAttr)
                    result.append(NSAttributedString(string: "\n"))
                    inCodeBlock = false
                    codeBlockContent = ""
                    codeBlockLanguage = nil
                } else {
                    // Start of code block
                    inCodeBlock = true
                    let langPart = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
                    codeBlockLanguage = langPart.isEmpty ? nil : langPart
                }
                continue
            }
            
            if inCodeBlock {
                if !codeBlockContent.isEmpty {
                    codeBlockContent += "\n"
                }
                codeBlockContent += line
                continue
            }
            
            // Parse the line
            let parsedLine = parseLine(line, styleSheet: styleSheet, previousLineWasBlank: previousLineWasBlank)
            result.append(parsedLine)
            
            // Add newline (except for last line if it's empty)
            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n"))
            }
            
            previousLineWasBlank = line.trimmingCharacters(in: .whitespaces).isEmpty
        }
        
        return result
    }
    
    // MARK: - Line Parsing
    
    /// Parse a single line of Markdown
    private static func parseLine(_ line: String, styleSheet: StyleSheet?, previousLineWasBlank: Bool) -> NSAttributedString {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Empty line
        if trimmed.isEmpty {
            return NSAttributedString(string: "")
        }
        
        // Headings (# to ######)
        if let headingResult = parseHeading(trimmed, styleSheet: styleSheet) {
            return headingResult
        }
        
        // Horizontal rule
        if isHorizontalRule(trimmed) {
            return formatHorizontalRule()
        }
        
        // Blockquote
        if trimmed.hasPrefix(">") {
            return parseBlockquote(trimmed, styleSheet: styleSheet)
        }
        
        // Unordered list
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
            return parseUnorderedListItem(line, styleSheet: styleSheet)
        }
        
        // Ordered list
        if let orderedResult = parseOrderedListItem(line, styleSheet: styleSheet) {
            return orderedResult
        }
        
        // Regular paragraph with inline formatting
        return parseInlineFormatting(trimmed, styleSheet: styleSheet, element: .body)
    }
    
    // MARK: - Heading Parsing
    
    private static func parseHeading(_ line: String, styleSheet: StyleSheet?) -> NSAttributedString? {
        // Count leading hashes
        var hashCount = 0
        for char in line {
            if char == "#" {
                hashCount += 1
            } else {
                break
            }
        }
        
        guard hashCount > 0 && hashCount <= 6 else { return nil }
        
        // Must have space after hashes
        let afterHashes = line.dropFirst(hashCount)
        guard afterHashes.first == " " else { return nil }
        
        let content = String(afterHashes.dropFirst()).trimmingCharacters(in: .whitespaces)
        
        // Map heading level to element
        let element: MarkdownElement
        switch hashCount {
        case 1: element = .heading1
        case 2: element = .heading2
        case 3: element = .heading3
        case 4: element = .heading4
        case 5: element = .heading5
        default: element = .heading6
        }
        
        return parseInlineFormatting(content, styleSheet: styleSheet, element: element)
    }
    
    // MARK: - Inline Formatting
    
    /// Parse inline formatting (bold, italic, links, code, etc.)
    private static func parseInlineFormatting(_ text: String, styleSheet: StyleSheet?, element: MarkdownElement) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        // Get base attributes from stylesheet or default
        let baseAttributes = attributesForElement(element, styleSheet: styleSheet)
        
        var index = text.startIndex
        
        while index < text.endIndex {
            // Check for link [text](url)
            if let linkResult = parseLink(text, from: index, baseAttributes: baseAttributes) {
                result.append(linkResult.attributedString)
                index = linkResult.endIndex
                continue
            }
            
            // Check for image ![alt](url)
            if let imageResult = parseImage(text, from: index) {
                result.append(imageResult.attributedString)
                index = imageResult.endIndex
                continue
            }
            
            // Check for inline code `code`
            if let codeResult = parseInlineCode(text, from: index, baseAttributes: baseAttributes) {
                result.append(codeResult.attributedString)
                index = codeResult.endIndex
                continue
            }
            
            // Check for bold/italic combinations
            if let formattedResult = parseEmphasis(text, from: index, baseAttributes: baseAttributes) {
                result.append(formattedResult.attributedString)
                index = formattedResult.endIndex
                continue
            }
            
            // Check for strikethrough ~~text~~
            if let strikeResult = parseStrikethrough(text, from: index, baseAttributes: baseAttributes) {
                result.append(strikeResult.attributedString)
                index = strikeResult.endIndex
                continue
            }
            
            // Regular character
            let char = text[index]
            result.append(NSAttributedString(string: String(char), attributes: baseAttributes))
            index = text.index(after: index)
        }
        
        return result
    }
    
    // MARK: - Link Parsing
    
    struct ParseResult {
        let attributedString: NSAttributedString
        let endIndex: String.Index
    }
    
    private static func parseLink(_ text: String, from startIndex: String.Index, baseAttributes: [NSAttributedString.Key: Any]) -> ParseResult? {
        guard startIndex < text.endIndex, text[startIndex] == "[" else { return nil }
        
        // Find closing bracket
        var bracketIndex = text.index(after: startIndex)
        var bracketCount = 1
        
        while bracketIndex < text.endIndex {
            if text[bracketIndex] == "[" { bracketCount += 1 }
            if text[bracketIndex] == "]" { bracketCount -= 1 }
            if bracketCount == 0 { break }
            bracketIndex = text.index(after: bracketIndex)
        }
        
        guard bracketIndex < text.endIndex, text[bracketIndex] == "]" else { return nil }
        
        // Check for opening parenthesis
        let parenIndex = text.index(after: bracketIndex)
        guard parenIndex < text.endIndex, text[parenIndex] == "(" else { return nil }
        
        // Find closing parenthesis
        var closeParenIndex = text.index(after: parenIndex)
        while closeParenIndex < text.endIndex && text[closeParenIndex] != ")" {
            closeParenIndex = text.index(after: closeParenIndex)
        }
        
        guard closeParenIndex < text.endIndex else { return nil }
        
        let linkText = String(text[text.index(after: startIndex)..<bracketIndex])
        let urlString = String(text[text.index(after: parenIndex)..<closeParenIndex])
        
        var attrs = baseAttributes
        attrs[.foregroundColor] = UIColor.systemBlue
        attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        
        if let url = URL(string: urlString) {
            attrs[.link] = url
        } else {
            // Might be a relative link like "other-file.md"
            attrs[.link] = urlString
        }
        
        let attrString = NSAttributedString(string: linkText, attributes: attrs)
        return ParseResult(attributedString: attrString, endIndex: text.index(after: closeParenIndex))
    }
    
    // MARK: - Image Parsing
    
    private static func parseImage(_ text: String, from startIndex: String.Index) -> ParseResult? {
        guard startIndex < text.endIndex, text[startIndex] == "!" else { return nil }
        
        let nextIndex = text.index(after: startIndex)
        guard nextIndex < text.endIndex, text[nextIndex] == "[" else { return nil }
        
        // Find alt text
        var bracketIndex = text.index(after: nextIndex)
        while bracketIndex < text.endIndex && text[bracketIndex] != "]" {
            bracketIndex = text.index(after: bracketIndex)
        }
        
        guard bracketIndex < text.endIndex else { return nil }
        
        let parenIndex = text.index(after: bracketIndex)
        guard parenIndex < text.endIndex, text[parenIndex] == "(" else { return nil }
        
        var closeParenIndex = text.index(after: parenIndex)
        while closeParenIndex < text.endIndex && text[closeParenIndex] != ")" {
            closeParenIndex = text.index(after: closeParenIndex)
        }
        
        guard closeParenIndex < text.endIndex else { return nil }
        
        let altText = String(text[text.index(after: nextIndex)..<bracketIndex])
        let imagePath = String(text[text.index(after: parenIndex)..<closeParenIndex])
        
        // For now, represent images as placeholder text
        // TODO: Actually load and embed images
        let placeholder = "[Image: \(altText.isEmpty ? imagePath : altText)]"
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.secondaryLabel,
            .font: UIFont.italicSystemFont(ofSize: UIFont.systemFontSize)
        ]
        
        let attrString = NSAttributedString(string: placeholder, attributes: attrs)
        return ParseResult(attributedString: attrString, endIndex: text.index(after: closeParenIndex))
    }
    
    // MARK: - Inline Code Parsing
    
    private static func parseInlineCode(_ text: String, from startIndex: String.Index, baseAttributes: [NSAttributedString.Key: Any]) -> ParseResult? {
        guard startIndex < text.endIndex, text[startIndex] == "`" else { return nil }
        
        // Don't match triple backticks
        let nextIndex = text.index(after: startIndex)
        if nextIndex < text.endIndex && text[nextIndex] == "`" {
            return nil
        }
        
        // Find closing backtick
        var endIndex = nextIndex
        while endIndex < text.endIndex && text[endIndex] != "`" {
            endIndex = text.index(after: endIndex)
        }
        
        guard endIndex < text.endIndex else { return nil }
        
        let code = String(text[nextIndex..<endIndex])
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: UIFont.systemFontSize, weight: .regular),
            .backgroundColor: UIColor.systemGray6
        ]
        
        let attrString = NSAttributedString(string: code, attributes: attrs)
        return ParseResult(attributedString: attrString, endIndex: text.index(after: endIndex))
    }
    
    // MARK: - Emphasis Parsing (Bold/Italic)
    
    private static func parseEmphasis(_ text: String, from startIndex: String.Index, baseAttributes: [NSAttributedString.Key: Any]) -> ParseResult? {
        guard startIndex < text.endIndex else { return nil }
        let char = text[startIndex]
        guard char == "*" || char == "_" else { return nil }
        
        // Count consecutive markers
        var markerCount = 0
        var idx = startIndex
        while idx < text.endIndex && text[idx] == char {
            markerCount += 1
            idx = text.index(after: idx)
        }
        
        guard markerCount >= 1 && markerCount <= 3 else { return nil }
        
        // Find closing markers
        let contentStart = idx
        var contentEnd: String.Index?
        var searchIndex = contentStart
        
        while searchIndex < text.endIndex {
            if text[searchIndex] == char {
                // Count closing markers
                var closeCount = 0
                var closeIdx = searchIndex
                while closeIdx < text.endIndex && text[closeIdx] == char && closeCount < markerCount {
                    closeCount += 1
                    closeIdx = text.index(after: closeIdx)
                }
                
                if closeCount == markerCount {
                    contentEnd = searchIndex
                    break
                }
            }
            searchIndex = text.index(after: searchIndex)
        }
        
        guard let end = contentEnd else { return nil }
        
        let content = String(text[contentStart..<end])
        guard !content.isEmpty else { return nil }
        
        var attrs = baseAttributes
        let baseFont = (attrs[.font] as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
        var traits: UIFontDescriptor.SymbolicTraits = baseFont.fontDescriptor.symbolicTraits
        
        switch markerCount {
        case 1: // Italic
            traits.insert(.traitItalic)
        case 2: // Bold
            traits.insert(.traitBold)
        case 3: // Bold + Italic
            traits.insert(.traitBold)
            traits.insert(.traitItalic)
        default:
            break
        }
        
        if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(traits) {
            attrs[.font] = UIFont(descriptor: descriptor, size: baseFont.pointSize)
        }
        
        let attrString = NSAttributedString(string: content, attributes: attrs)
        
        // Calculate end position (content end + marker count)
        var finalEnd = end
        for _ in 0..<markerCount {
            if finalEnd < text.endIndex {
                finalEnd = text.index(after: finalEnd)
            }
        }
        
        return ParseResult(attributedString: attrString, endIndex: finalEnd)
    }
    
    // MARK: - Strikethrough Parsing
    
    private static func parseStrikethrough(_ text: String, from startIndex: String.Index, baseAttributes: [NSAttributedString.Key: Any]) -> ParseResult? {
        guard startIndex < text.endIndex, text[startIndex] == "~" else { return nil }
        
        let nextIndex = text.index(after: startIndex)
        guard nextIndex < text.endIndex, text[nextIndex] == "~" else { return nil }
        
        let contentStart = text.index(after: nextIndex)
        
        // Find closing ~~
        var searchIndex = contentStart
        while searchIndex < text.endIndex {
            if text[searchIndex] == "~" {
                let next = text.index(after: searchIndex)
                if next < text.endIndex && text[next] == "~" {
                    let content = String(text[contentStart..<searchIndex])
                    guard !content.isEmpty else { return nil }
                    
                    var attrs = baseAttributes
                    attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                    
                    let attrString = NSAttributedString(string: content, attributes: attrs)
                    return ParseResult(attributedString: attrString, endIndex: text.index(after: next))
                }
            }
            searchIndex = text.index(after: searchIndex)
        }
        
        return nil
    }
    
    // MARK: - Blockquote Parsing
    
    private static func parseBlockquote(_ line: String, styleSheet: StyleSheet?) -> NSAttributedString {
        var content = line
        
        // Remove leading > and space
        while content.hasPrefix(">") {
            content = String(content.dropFirst())
        }
        content = content.trimmingCharacters(in: .whitespaces)
        
        return parseInlineFormatting(content, styleSheet: styleSheet, element: .blockquote)
    }
    
    // MARK: - List Parsing
    
    private static func parseUnorderedListItem(_ line: String, styleSheet: StyleSheet?) -> NSAttributedString {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let content: String
        
        if trimmed.hasPrefix("- ") {
            content = String(trimmed.dropFirst(2))
        } else if trimmed.hasPrefix("* ") {
            content = String(trimmed.dropFirst(2))
        } else if trimmed.hasPrefix("+ ") {
            content = String(trimmed.dropFirst(2))
        } else {
            content = trimmed
        }
        
        let bullet = "• "
        let result = NSMutableAttributedString()
        
        let baseAttributes = attributesForElement(.body, styleSheet: styleSheet)
        result.append(NSAttributedString(string: bullet, attributes: baseAttributes))
        result.append(parseInlineFormatting(content, styleSheet: styleSheet, element: .body))
        
        return result
    }
    
    private static func parseOrderedListItem(_ line: String, styleSheet: StyleSheet?) -> NSAttributedString? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Match pattern like "1. " or "12. "
        guard let range = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) else {
            return nil
        }
        
        let number = String(trimmed[trimmed.startIndex..<range.upperBound])
        let content = String(trimmed[range.upperBound...])
        
        let result = NSMutableAttributedString()
        let baseAttributes = attributesForElement(.body, styleSheet: styleSheet)
        
        result.append(NSAttributedString(string: number, attributes: baseAttributes))
        result.append(parseInlineFormatting(content, styleSheet: styleSheet, element: .body))
        
        return result
    }
    
    // MARK: - Code Block Formatting
    
    private static func formatCodeBlock(_ code: String, language: String?, styleSheet: StyleSheet?) -> NSAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: UIFont.systemFontSize, weight: .regular),
            .backgroundColor: UIColor.systemGray6,
            .foregroundColor: UIColor.label
        ]
        
        return NSAttributedString(string: code, attributes: attrs)
    }
    
    // MARK: - Horizontal Rule
    
    private static func isHorizontalRule(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Must be at least 3 characters
        guard trimmed.count >= 3 else { return false }
        
        // Check for ---, ***, or ___
        if trimmed.allSatisfy({ $0 == "-" }) { return true }
        if trimmed.allSatisfy({ $0 == "*" }) { return true }
        if trimmed.allSatisfy({ $0 == "_" }) { return true }
        
        return false
    }
    
    private static func formatHorizontalRule() -> NSAttributedString {
        // Represent as a line of dashes
        let rule = "────────────────────────────────"
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.separator,
            .font: UIFont.systemFont(ofSize: UIFont.smallSystemFontSize)
        ]
        return NSAttributedString(string: rule, attributes: attrs)
    }
    
    // MARK: - Style Resolution
    
    /// Get attributes for a markdown element, using stylesheet if available
    private static func attributesForElement(_ element: MarkdownElement, styleSheet: StyleSheet?) -> [NSAttributedString.Key: Any] {
        // Try to get style from stylesheet
        if let styleSheet = styleSheet,
           let styleName = markdownToStyleMap[element],
           let textStyle = styleSheet.style(named: styleName) {
            return textStyle.generateAttributes()
        }
        
        // Fall back to default system styles
        return defaultAttributesForElement(element)
    }
    
    /// Default attributes when no stylesheet is available
    private static func defaultAttributesForElement(_ element: MarkdownElement) -> [NSAttributedString.Key: Any] {
        let textStyle: UIFont.TextStyle
        var extraAttributes: [NSAttributedString.Key: Any] = [:]
        
        switch element {
        case .heading1:
            textStyle = .largeTitle
            extraAttributes[.foregroundColor] = UIColor.label
        case .heading2:
            textStyle = .title1
            extraAttributes[.foregroundColor] = UIColor.label
        case .heading3:
            textStyle = .title2
            extraAttributes[.foregroundColor] = UIColor.label
        case .heading4:
            textStyle = .title3
            extraAttributes[.foregroundColor] = UIColor.label
        case .heading5:
            textStyle = .headline
            extraAttributes[.foregroundColor] = UIColor.label
        case .heading6:
            textStyle = .subheadline
            extraAttributes[.foregroundColor] = UIColor.secondaryLabel
        case .body:
            textStyle = .body
            extraAttributes[.foregroundColor] = UIColor.label
        case .blockquote:
            textStyle = .callout
            extraAttributes[.foregroundColor] = UIColor.secondaryLabel
            // Add left indent for blockquotes
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.headIndent = 20
            paragraphStyle.firstLineHeadIndent = 20
            extraAttributes[.paragraphStyle] = paragraphStyle
        case .codeBlock:
            return [
                .font: UIFont.monospacedSystemFont(ofSize: UIFont.systemFontSize, weight: .regular),
                .foregroundColor: UIColor.label,
                .backgroundColor: UIColor.systemGray6
            ]
        }
        
        var attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: textStyle)
        ]
        
        attrs.merge(extraAttributes) { _, new in new }
        
        return attrs
    }
}
