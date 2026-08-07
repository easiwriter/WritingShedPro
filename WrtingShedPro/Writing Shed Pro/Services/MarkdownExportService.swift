//
//  MarkdownExportService.swift
//  Writing Shed Pro
//
//  Created on 25 January 2026.
//

import Foundation
import UIKit

/// Errors that can occur during Markdown export
enum MarkdownExportError: Error, LocalizedError {
    case conversionFailed(String)
    case emptyContent
    
    var errorDescription: String? {
        switch self {
        case .conversionFailed(let reason):
            return NSLocalizedString("export.markdown.error.conversion", comment: "Markdown conversion failed") + ": \(reason)"
        case .emptyContent:
            return NSLocalizedString("export.markdown.error.empty", comment: "No content to export")
        }
    }
}

/// Service for exporting content to Markdown format
class MarkdownExportService {
    
    // MARK: - Public Export Methods
    
    /// Export attributed string to Markdown string
    /// - Parameters:
    ///   - attributedString: The formatted content to export
    ///   - filename: Name for the document (used for title)
    /// - Returns: Markdown formatted string
    /// - Throws: Error if export fails
    static func exportToMarkdown(
        _ attributedString: NSAttributedString,
        filename: String,
        footnotes: [FootnoteModel]? = nil
    ) throws -> String {
        
        guard attributedString.length > 0 else {
            throw MarkdownExportError.emptyContent
        }
        
        var markdown = ""
        let footnotesByAttachmentID = footnotes.map { footnotes in
            Dictionary(footnotes.map { ($0.attachmentID, $0) }, uniquingKeysWith: { first, _ in first })
        } ?? [:]
        
        // Process the attributed string paragraph by paragraph
        let string = attributedString.string
        var currentIndex = string.startIndex
        
        while currentIndex < string.endIndex {
            // Find the end of the current paragraph
            let paragraphRange = string.paragraphRange(for: currentIndex..<currentIndex)
            let nsRange = NSRange(paragraphRange, in: string)
            
            // Get the attributed substring for this paragraph
            let paragraphAttrString = attributedString.attributedSubstring(from: nsRange)
            
            // Convert the paragraph to Markdown
            let paragraphMarkdown = convertParagraphToMarkdown(paragraphAttrString, footnotesByAttachmentID: footnotesByAttachmentID)
            markdown += paragraphMarkdown
            
            // Move to next paragraph
            currentIndex = paragraphRange.upperBound
        }
        
        #if DEBUG
        print("📤 MarkdownExportService: Exported '\(filename).md'")
        print("   Markdown size: \(markdown.count) characters")
        #endif
        
        return markdown
    }
    
    /// Export attributed string to Markdown data
    /// - Parameters:
    ///   - attributedString: The formatted content to export
    ///   - filename: Name for the document
    /// - Returns: Markdown data encoded as UTF-8
    /// - Throws: Error if export fails
    static func exportToMarkdownData(
        _ attributedString: NSAttributedString,
        filename: String,
        footnotes: [FootnoteModel]? = nil
    ) throws -> Data {
        let markdownString = try exportToMarkdown(attributedString, filename: filename, footnotes: footnotes)
        
        guard let data = markdownString.data(using: .utf8) else {
            throw MarkdownExportError.conversionFailed("Failed to encode Markdown as UTF-8")
        }
        
        return data
    }
    
    /// Export multiple attributed strings with separators between them
    /// - Parameters:
    ///   - attributedStrings: Array of formatted content to export
    ///   - filename: Name for the document
    /// - Returns: Markdown data encoded as UTF-8
    /// - Throws: Error if export fails
    static func exportMultipleToMarkdownData(
        _ attributedStrings: [NSAttributedString],
        filename: String
    ) throws -> Data {
        #if DEBUG
        print("📝 MarkdownExportService.exportMultipleToMarkdownData() called")
        print("   - Number of attributed strings: \(attributedStrings.count)")
        #endif
        
        var combinedMarkdown = ""
        
        for (index, attributedString) in attributedStrings.enumerated() {
            if index > 0 {
                // Add page break separator between documents
                combinedMarkdown += "\n\n---\n\n"
            }
            
            let markdown = try exportToMarkdown(attributedString, filename: "\(filename)_\(index + 1)")
            combinedMarkdown += markdown
        }
        
        guard let data = combinedMarkdown.data(using: .utf8) else {
            throw MarkdownExportError.conversionFailed("Failed to encode Markdown as UTF-8")
        }
        
        return data
    }
    
    // MARK: - Private Conversion Methods
    
    /// Detect heading level from font text style or font characteristics
    private static func detectHeadingLevel(from font: UIFont) -> Int {
        // First, try to detect from font descriptor's text style (most reliable)
        if let textStyleRaw = font.fontDescriptor.object(forKey: .textStyle) as? String {
            switch textStyleRaw {
            case "UICTFontTextStyleLargeTitle", "UICTFontTextStyleTitle0":
                return 1
            case "UICTFontTextStyleTitle1":
                return 2
            case "UICTFontTextStyleTitle2":
                return 3
            case "UICTFontTextStyleTitle3":
                return 4
            case "UICTFontTextStyleHeadline":
                return 5
            case "UICTFontTextStyleSubhead", "UICTFontTextStyleSubheadline":
                return 6
            default:
                break
            }
        }
        
        // Fallback: Check font size and weight heuristics
        let pointSize = font.pointSize
        let isBold = font.fontDescriptor.symbolicTraits.contains(.traitBold)
        
        if isBold || pointSize >= 17 {
            if pointSize >= 34 { return 1 }       // Large Title ~34pt
            if pointSize >= 28 { return 2 }       // Title 1 ~28pt
            if pointSize >= 22 { return 3 }       // Title 2 ~22pt
            if pointSize >= 20 { return 4 }       // Title 3 ~20pt
            if pointSize >= 17 && isBold { return 5 }  // Headline ~17pt bold
        }
        
        return 0  // Not a heading
    }
    
    /// Convert a paragraph's attributed string to Markdown
    private static func convertParagraphToMarkdown(
        _ attributedString: NSAttributedString,
        footnotesByAttachmentID: [UUID: FootnoteModel]
    ) -> String {
        let string = attributedString.string
        
        // If empty or just whitespace, return as-is
        if string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return string
        }
        
        // Check for horizontal rule (visual representation from MarkdownImportService)
        // The import converts --- to ────────────────────────────────
        if isVisualHorizontalRule(string) {
            return "---\n"
        }
        
        var result = ""
        let fullRange = NSRange(location: 0, length: attributedString.length)
        
        // Check for paragraph-level formatting (headers, etc.)
        var isHeader = false
        var headerLevel = 0
        
        // Detect heading from font text style
        if let font = attributedString.attribute(.font, at: 0, effectiveRange: nil) as? UIFont {
            headerLevel = detectHeadingLevel(from: font)
            isHeader = headerLevel > 0
        }
        
        // Process inline formatting
        attributedString.enumerateAttributes(in: fullRange, options: []) { attributes, range, _ in
            let text = (string as NSString).substring(with: range)
            
            if let attachment = attributes[.attachment] as? NSTextAttachment {
                if let attachmentMarkdown = markdownForAttachment(attachment, footnotesByAttachmentID: footnotesByAttachmentID) {
                    result += attachmentMarkdown
                }
                return
            }
            
            var formattedText = text
            
            // Check for bold
            var isBold = false
            var isItalic = false
            
            if let font = attributes[.font] as? UIFont {
                let traits = font.fontDescriptor.symbolicTraits
                isBold = traits.contains(.traitBold)
                isItalic = traits.contains(.traitItalic)
            }
            
            // Check for strikethrough
            let hasStrikethrough = (attributes[.strikethroughStyle] as? Int ?? 0) != 0
            
            // Check for links
            if let url = attributes[.link] as? URL {
                formattedText = "[\(text)](\(url.absoluteString))"
            } else if let urlString = attributes[.link] as? String {
                formattedText = "[\(text)](\(urlString))"
            } else {
                // Apply text formatting
                // Don't apply bold formatting if this is a header (headers are already bold visually)
                if isBold && isItalic && !isHeader {
                    formattedText = "***\(text)***"
                } else if isBold && !isHeader {
                    formattedText = "**\(text)**"
                } else if isItalic {
                    formattedText = "*\(text)*"
                }
                
                if hasStrikethrough {
                    formattedText = "~~\(formattedText)~~"
                }
            }
            
            result += formattedText
        }
        
        // Add header prefix if detected
        if isHeader && headerLevel > 0 {
            let prefix = String(repeating: "#", count: headerLevel) + " "
            result = prefix + result.trimmingCharacters(in: .whitespaces)
            // Ensure newline after header
            if !result.hasSuffix("\n") {
                result += "\n"
            }
        }
        
        return result
    }
    
    private static func markdownForAttachment(
        _ attachment: NSTextAttachment,
        footnotesByAttachmentID: [UUID: FootnoteModel]
    ) -> String? {
        if let footnoteAttachment = attachment as? FootnoteAttachment {
            guard let footnote = footnotesByAttachmentID[footnoteAttachment.footnoteID] else { return nil }
            let text = footnote.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return " [Footnote \(footnoteAttachment.displayString): \(text)]"
        }
        
        return nil
    }
    
    // MARK: - Image Handling
    
    /// Extract images and convert to Markdown image syntax
    /// Images are embedded as base64 data URIs or referenced by filename
    private static func extractImagesAsMarkdown(from attributedString: NSAttributedString) -> [(range: NSRange, markdown: String)] {
        var images: [(range: NSRange, markdown: String)] = []
        let fullRange = NSRange(location: 0, length: attributedString.length)
        
        attributedString.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
            if let attachment = value as? NSTextAttachment {
                var imageData: Data?
                var altText = "Image"
                
                // Try to get image from attachment
                if let image = attachment.image {
                    imageData = image.pngData()
                } else if let data = attachment.fileWrapper?.regularFileContents {
                    imageData = data
                }
                
                // Check for ImageAttachment with caption
                if let imageAttachment = value as? ImageAttachment {
                    if let caption = imageAttachment.captionText, !caption.isEmpty {
                        altText = caption
                    }
                }
                
                if let data = imageData {
                    // For Markdown, we'll use a data URI (base64)
                    let base64 = data.base64EncodedString()
                    let markdown = "![\(altText)](data:image/png;base64,\(base64))"
                    images.append((range: range, markdown: markdown))
                }
            }
        }
        
        return images
    }
    
    // MARK: - Horizontal Rule Detection
    
    /// Check if a string is a visual horizontal rule (from MarkdownImportService)
    /// The import service converts markdown --- to visual ──────────────────────── characters
    private static func isVisualHorizontalRule(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Must have at least 3 characters
        guard trimmed.count >= 3 else { return false }
        
        // Check for box-drawing horizontal line characters (U+2500, U+2501, U+2504, etc.)
        // MarkdownImportService uses "─" (U+2500 BOX DRAWINGS LIGHT HORIZONTAL)
        if trimmed.allSatisfy({ $0 == "─" || $0 == "━" || $0 == "—" || $0 == "-" }) {
            return true
        }
        
        return false
    }
}
