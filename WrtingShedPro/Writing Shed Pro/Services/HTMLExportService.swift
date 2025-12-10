//
//  HTMLExportService.swift
//  Writing Shed Pro
//
//  Created on 8 December 2025.
//

import Foundation
import UIKit

/// Information about an extracted image from NSAttributedString
struct ExtractedImage {
    let imageData: Data
    let range: NSRange
    let scale: CGFloat
    let alignment: String
    let hasCaption: Bool
    let captionText: String?
}

/// Service for exporting content to HTML format
class HTMLExportService {
    
    // MARK: - Image Extraction
    
    /// Extract images from an attributed string
    /// - Parameter attributedString: The string to scan for images
    /// - Returns: Array of extracted images with metadata
    private static func extractImages(from attributedString: NSAttributedString) -> [ExtractedImage] {
        var images: [ExtractedImage] = []
        let range = NSRange(location: 0, length: attributedString.length)
        
        #if DEBUG
        print("🔍 HTMLExportService: Scanning for images in attributed string (length: \(attributedString.length))")
        #endif
        
        attributedString.enumerateAttribute(.attachment, in: range, options: []) { value, range, _ in
            #if DEBUG
            print("🔍 Found attachment at range \(range): \(type(of: value))")
            #endif
            
            if let attachment = value as? ImageAttachment {
                #if DEBUG
                print("✅ ImageAttachment found!")
                print("   - Has image: \(attachment.image != nil)")
                print("   - Has imageData: \(attachment.imageData != nil)")
                print("   - Scale: \(attachment.scale)")
                print("   - Alignment: \(attachment.alignment.rawValue)")
                #endif
                
                // Try to get image data from attachment
                var imageData: Data?
                if let data = attachment.imageData {
                    imageData = data
                } else if let image = attachment.image {
                    imageData = image.pngData()
                }
                
                if let imageData = imageData {
                    let extractedImage = ExtractedImage(
                        imageData: imageData,
                        range: range,
                        scale: attachment.scale,
                        alignment: attachment.alignment.rawValue,
                        hasCaption: attachment.hasCaption,
                        captionText: attachment.captionText
                    )
                    images.append(extractedImage)
                    #if DEBUG
                    print("✅ Image extracted successfully (size: \(imageData.count) bytes)")
                    #endif
                } else {
                    #if DEBUG
                    print("❌ Could not get image data from attachment")
                    #endif
                }
            }
        }
        
        #if DEBUG
        print("📊 Total images extracted: \(images.count)")
        #endif
        
        return images
    }
    
    // MARK: - Export
    
    /// Export attributed string to HTML
    /// - Parameters:
    ///   - attributedString: The formatted content to export
    ///   - filename: Name for the document (used in title)
    ///   - includeStyles: Whether to include CSS styling (default: true)
    /// - Returns: HTML string
    /// - Throws: Error if export fails
    static func exportToHTML(
        _ attributedString: NSAttributedString,
        filename: String,
        includeStyles: Bool = true
    ) throws -> String {
        
        // Convert NSAttributedString to HTML using native iOS/macOS support
        // Use HTML document type to preserve text attributes like bold, italic, etc.
        let documentAttributes: [NSAttributedString.DocumentAttributeKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        guard let htmlData = try? attributedString.data(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: documentAttributes
        ) else {
            throw HTMLExportError.conversionFailed("Failed to convert attributed string to HTML")
        }
        
        #if DEBUG
        // Debug: Check what HTML is being generated
        if let debugHTML = String(data: htmlData, encoding: .utf8) {
            print("📝 Raw HTML conversion sample: \(debugHTML.prefix(500))")
        }
        #endif
        
        guard var htmlString = String(data: htmlData, encoding: .utf8) else {
            throw HTMLExportError.conversionFailed("Failed to decode HTML data")
        }
        
        // Clean up the HTML output
        htmlString = cleanupHTML(htmlString, filename: filename, includeStyles: includeStyles)
        
        #if DEBUG
        print("📤 HTMLExportService: Exported '\(filename).html'")
        print("   HTML size: \(htmlString.count) characters")
        #endif
        
        return htmlString
    }
    
    /// Export attributed string to HTML data
    /// - Parameters:
    ///   - attributedString: The formatted content to export
    ///   - filename: Name for the document
    ///   - includeStyles: Whether to include CSS styling
    /// - Returns: HTML data encoded as UTF-8
    /// - Throws: Error if export fails
    static func exportToHTMLData(
        _ attributedString: NSAttributedString,
        filename: String,
        includeStyles: Bool = true
    ) throws -> Data {
        let htmlString = try exportToHTML(attributedString, filename: filename, includeStyles: includeStyles)
        
        guard let data = htmlString.data(using: .utf8) else {
            throw HTMLExportError.conversionFailed("Failed to encode HTML as UTF-8")
        }
        
        return data
    }
    
    /// Export multiple attributed strings with page breaks between them
    /// - Parameters:
    ///   - attributedStrings: Array of formatted content to export
    ///   - filename: Name for the document
    ///   - includeStyles: Whether to include CSS styling
    /// - Returns: HTML data encoded as UTF-8
    /// - Throws: Error if export fails
    static func exportMultipleToHTMLData(
        _ attributedStrings: [NSAttributedString],
        filename: String,
        includeStyles: Bool = true
    ) throws -> Data {
        // Convert each attributed string to HTML body content
        var htmlBodies: [String] = []
        var allStyles = ""  // Accumulate all unique styles
        
        for (index, attributedString) in attributedStrings.enumerated() {
            // Extract images before HTML conversion
            let extractedImages = extractImages(from: attributedString)
            
            // Convert to HTML
            let documentAttributes: [NSAttributedString.DocumentAttributeKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
            
            guard let htmlData = try? attributedString.data(
                from: NSRange(location: 0, length: attributedString.length),
                documentAttributes: documentAttributes
            ),
            let htmlString = String(data: htmlData, encoding: .utf8) else {
                throw HTMLExportError.conversionFailed("Failed to convert attributed string to HTML")
            }
            
            #if DEBUG
            // Debug: Check what HTML is being generated for each file
            print("📝 Raw HTML conversion sample (file \(index + 1)): \(htmlString.prefix(500))")
            #endif
            
            // Extract iOS-generated styles and namespace them to avoid conflicts between files
            let filePrefix = "f\(index)_"
            if let styleStart = htmlString.range(of: "<style type=\"text/css\">"),
               let styleEnd = htmlString.range(of: "</style>") {
                var styleContent = String(htmlString[styleStart.upperBound..<styleEnd.lowerBound])
                
                #if DEBUG
                print("📋 Original CSS for file \(index + 1):")
                print(styleContent.prefix(300))
                #endif
                
                // Namespace the CSS class names to prevent conflicts (e.g., .p1 -> .f0_p1)
                // Match class selectors and add prefix
                let classPattern = "\\.([ps]\\d+)"
                if let regex = try? NSRegularExpression(pattern: classPattern, options: []) {
                    let range = NSRange(styleContent.startIndex..., in: styleContent)
                    styleContent = regex.stringByReplacingMatches(
                        in: styleContent,
                        options: [],
                        range: range,
                        withTemplate: ".\(filePrefix)$1"
                    )
                }
                
                allStyles += styleContent + "\n"
            }
            
            // Extract just the body content (between <body> tags)
            var bodyContent: String
            if let bodyStart = htmlString.range(of: "<body>"),
               let bodyEnd = htmlString.range(of: "</body>") {
                bodyContent = String(htmlString[bodyStart.upperBound..<bodyEnd.lowerBound])
            } else {
                // If no body tags, use the whole content
                bodyContent = htmlString
            }
            
            // Namespace the class names in the body to match the CSS (e.g., class="p1" -> class="f0_p1")
            // filePrefix already defined above
            let classPattern = "class=\"([ps]\\d+)\""
            if let regex = try? NSRegularExpression(pattern: classPattern, options: []) {
                let range = NSRange(bodyContent.startIndex..., in: bodyContent)
                bodyContent = regex.stringByReplacingMatches(
                    in: bodyContent,
                    options: [],
                    range: range,
                    withTemplate: "class=\"\(filePrefix)$1\""
                )
            }
            
            // Clean up the body content (remove extra newlines iOS adds)
            // iOS's HTML converter adds <br> tags and newlines which create double spacing
            // IMPORTANT: Don't remove newlines between spans - they mark style boundaries
            
            // First, normalize all line break variations
            bodyContent = bodyContent.replacingOccurrences(of: "<br />", with: "<br>")
            bodyContent = bodyContent.replacingOccurrences(of: "<br/>", with: "<br>")
            
            // Remove newlines between paragraph and div tags
            bodyContent = bodyContent.replacingOccurrences(of: "</p>\n<p>", with: "</p><p>")
            bodyContent = bodyContent.replacingOccurrences(of: "</div>\n<div>", with: "</div><div>")
            
            // Remove newlines after opening paragraph/div tags and before closing tags
            bodyContent = bodyContent.replacingOccurrences(of: "<p>\n", with: "<p>")
            bodyContent = bodyContent.replacingOccurrences(of: "\n</p>", with: "</p>")
            bodyContent = bodyContent.replacingOccurrences(of: "<div>\n", with: "<div>")
            bodyContent = bodyContent.replacingOccurrences(of: "\n</div>", with: "</div>")
            
            // Remove newlines after br tags (these create double spacing)
            bodyContent = bodyContent.replacingOccurrences(of: "<br>\n", with: "<br>")
            
            // Clean up any excessive multiple spaces created by removals
            while bodyContent.contains("  ") {
                bodyContent = bodyContent.replacingOccurrences(of: "  ", with: " ")
            }
            
            // Replace image placeholders with actual <img> tags with base64 data URIs
            #if DEBUG
            print("📝 Body content contains \(extractedImages.count) images to replace")
            print("📝 Checking for unicode attachment chars: \(bodyContent.contains("\u{FFFC}"))")
            print("📝 Checking for 'Attachment' text: \(bodyContent.contains("Attachment"))")
            if bodyContent.contains("Attachment") {
                // Show sample of where Attachment appears
                if let range = bodyContent.range(of: "Attachment") {
                    let start = bodyContent.index(range.lowerBound, offsetBy: -20, limitedBy: bodyContent.startIndex) ?? bodyContent.startIndex
                    let end = bodyContent.index(range.upperBound, offsetBy: 20, limitedBy: bodyContent.endIndex) ?? bodyContent.endIndex
                    print("📝 Sample: ...\(bodyContent[start..<end])...")
                }
            }
            #endif
            
            for (imgIndex, image) in extractedImages.enumerated() {
                // Create base64 data URI
                let base64String = image.imageData.base64EncodedString()
                let dataURI = "data:image/png;base64,\(base64String)"
                
                // Create img tag with proper styling
                let alignClass = "img-\(image.alignment)"
                let widthPercent = Int(image.scale * 100)
                var imgTag = "<img src=\"\(dataURI)\" class=\"\(alignClass)\" style=\"width: \(widthPercent)%; max-width: 100%; height: auto;\" alt=\"Image\" />"
                
                // Add caption if present
                if image.hasCaption, let caption = image.captionText, !caption.isEmpty {
                    imgTag += "<p class=\"image-caption\" style=\"text-align: center; font-size: 0.9em; font-style: italic; margin-top: 0.5em; color: #666;\">\(caption)</p>"
                }
                
                #if DEBUG
                print("🔄 Replacing image \(imgIndex + 1) with base64 data (size: \(base64String.count) chars)")
                #endif
                
                // iOS HTML converter creates either:
                // 1. Unicode attachment character (U+FFFC)
                // 2. <img src="Attachment.tiff"> or similar placeholder
                // We need to replace both
                
                var replaced = false
                
                // First try to replace attachment character
                let attachmentChar = "\u{FFFC}"
                if let range = bodyContent.range(of: attachmentChar) {
                    bodyContent = bodyContent.replacingCharacters(in: range, with: imgTag)
                    replaced = true
                    #if DEBUG
                    print("✅ Replaced unicode attachment character")
                    #endif
                } else {
                    // If no attachment character, look for iOS-generated img tag placeholder
                    // Match patterns like: <img src="file:///Attachment.tiff"...> or src="Attachment-1.tiff"
                    // The pattern needs to match file:// URLs as well
                    let pattern = "<img[^>]*src=\"[^\"]*[Aa]ttachment[^\"]*\"[^>]*>"
                    if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                        let nsRange = NSRange(bodyContent.startIndex..., in: bodyContent)
                        if let match = regex.firstMatch(in: bodyContent, options: [], range: nsRange),
                           let range = Range(match.range, in: bodyContent) {
                            #if DEBUG
                            print("✅ Found and replacing iOS img tag: \(bodyContent[range])")
                            #endif
                            bodyContent = bodyContent.replacingCharacters(in: range, with: imgTag)
                            replaced = true
                        }
                    }
                }
                
                #if DEBUG
                if !replaced {
                    print("❌ Could not find placeholder to replace for image \(imgIndex + 1)")
                }
                #endif
            }
            
            htmlBodies.append(bodyContent)
        }
        
        // Join with page break divs
        let combinedBody = htmlBodies.joined(separator: "\n<div class=\"page-break\"></div>\n")
        
        // Create complete HTML document
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(filename)</title>
        
        """
        
        if includeStyles {
            // First, add iOS-generated styles (namespaced to prevent conflicts between files)
            if !allStyles.isEmpty {
                html += "<style type=\"text/css\">\n"
                html += allStyles
                html += "</style>\n"
            }
            
            // Then add our custom CSS
            html += """
                <style>
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                        line-height: 1.6;
                        max-width: 800px;
                        margin: 0 auto;
                        padding: 20px;
                        color: #333;
                        background-color: #fff;
                    }
                    h1, h2, h3, h4, h5, h6 {
                        margin-top: 1.5em;
                        margin-bottom: 0.5em;
                        font-weight: 600;
                    }
                    p {
                        margin-bottom: 1em;
                    }
                    b, strong {
                        font-weight: bold;
                    }
                    i, em {
                        font-style: italic;
                    }
                    u {
                        text-decoration: underline;
                    }
                    /* Support for inline styles from iOS HTML converter */
                    span[style*="font-weight: bold"],
                    span[style*="font-weight:bold"],
                    span[style*="font-weight: 700"],
                    span[style*="font-weight:700"] {
                        font-weight: bold;
                    }
                    span[style*="font-style: italic"],
                    span[style*="font-style:italic"] {
                        font-style: italic;
                    }
                    span[style*="text-decoration: underline"],
                    span[style*="text-decoration:underline"] {
                        text-decoration: underline;
                    }
                    img {
                        max-width: 100%;
                        height: auto;
                        display: block;
                        margin: 1em 0;
                    }
                    .img-left {
                        float: left;
                        margin-right: 1em;
                        margin-bottom: 1em;
                    }
                    .img-center {
                        display: block;
                        margin-left: auto;
                        margin-right: auto;
                    }
                    .img-right {
                        float: right;
                        margin-left: 1em;
                        margin-bottom: 1em;
                    }
                    .img-inline {
                        display: inline-block;
                        vertical-align: middle;
                    }
                    .image-caption {
                        text-align: center;
                        font-size: 0.9em;
                        font-style: italic;
                        margin-top: 0.5em;
                        color: #666;
                    }
                    .page-break {
                        page-break-after: always;
                        break-after: page;
                        margin: 3em 0;
                        padding: 2em 0;
                        border-bottom: 2px dashed #ccc;
                        text-align: center;
                        color: #999;
                        font-size: 0.9em;
                    }
                    .page-break::after {
                        content: "• • •";
                        display: block;
                        margin-top: 1em;
                    }
                    @media print {
                        body {
                            max-width: none;
                            padding: 0;
                        }
                        .page-break {
                            page-break-after: always;
                            border: none;
                            margin: 0;
                            padding: 0;
                        }
                        .page-break::after {
                            display: none;
                        }
                    }
                    @media (prefers-color-scheme: dark) {
                        body {
                            color: #e0e0e0;
                            background-color: #1a1a1a;
                        }
                    }
                </style>
            
"""
        }
        
        html += """
        </head>
        <body>
        \(combinedBody)
        </body>
        </html>
        """
        
        guard let data = html.data(using: .utf8) else {
            throw HTMLExportError.conversionFailed("Failed to encode HTML as UTF-8")
        }
        
        #if DEBUG
        print("📤 HTMLExportService: Exported '\(filename).html' with \(attributedStrings.count) files")
        print("   HTML size: \(html.count) characters")
        print("   Page breaks inserted: \(attributedStrings.count - 1)")
        #endif
        
        return data
    }
    
    // MARK: - HTML Cleanup
    
    /// Clean up and enhance the generated HTML
    private static func cleanupHTML(_ html: String, filename: String, includeStyles: Bool) -> String {
        var cleaned = html
        
        // Add proper HTML5 doctype if not present
        if !cleaned.contains("<!DOCTYPE") {
            cleaned = "<!DOCTYPE html>\n" + cleaned
        }
        
        // Enhance the head section
        if let headRange = cleaned.range(of: "<head>") {
            let insertPosition = cleaned.index(after: headRange.upperBound)
            var headContent = "\n"
            headContent += "    <meta charset=\"UTF-8\">\n"
            headContent += "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n"
            headContent += "    <title></title>\n"
            
            if includeStyles {
                headContent += """
                    <style>
                        body {
                            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                            line-height: 1.6;
                            max-width: 800px;
                            margin: 0 auto;
                            padding: 20px;
                            color: #333;
                            background-color: #fff;
                        }
                        h1, h2, h3, h4, h5, h6 {
                            margin-top: 1.5em;
                            margin-bottom: 0.5em;
                            font-weight: 600;
                        }
                        p {
                            margin-bottom: 1em;
                        }
                        b, strong {
                            font-weight: bold;
                        }
                        i, em {
                            font-style: italic;
                        }
                        u {
                            text-decoration: underline;
                        }
                        /* Support for inline styles from iOS HTML converter */
                        span[style*="font-weight: bold"],
                        span[style*="font-weight:bold"],
                        span[style*="font-weight: 700"],
                        span[style*="font-weight:700"] {
                            font-weight: bold;
                        }
                        span[style*="font-style: italic"],
                        span[style*="font-style:italic"] {
                            font-style: italic;
                        }
                        span[style*="text-decoration: underline"],
                        span[style*="text-decoration:underline"] {
                            text-decoration: underline;
                        }
                        img {
                            max-width: 100%;
                            height: auto;
                            display: block;
                            margin: 1em 0;
                        }
                        .page-break {
                            page-break-after: always;
                            break-after: page;
                            margin: 3em 0;
                            padding: 2em 0;
                            border-bottom: 2px dashed #ccc;
                            text-align: center;
                            color: #999;
                            font-size: 0.9em;
                        }
                        .page-break::after {
                            content: "• • •";
                            display: block;
                            margin-top: 1em;
                        }
                        @media print {
                            body {
                                max-width: none;
                                padding: 0;
                            }
                            .page-break {
                                page-break-after: always;
                                border: none;
                                margin: 0;
                                padding: 0;
                            }
                            .page-break::after {
                                display: none;
                            }
                        }
                        @media (prefers-color-scheme: dark) {
                            body {
                                color: #e0e0e0;
                                background-color: #1a1a1a;
                            }
                        }
                    </style>
                
"""
            }
            
            cleaned.insert(contentsOf: headContent, at: insertPosition)
        }
        
        // Convert form feed (page break) characters to HTML page breaks
        // Use a div with class for better styling (visible in browser, hidden in print)
        cleaned = cleaned.replacingOccurrences(of: "\u{000C}", with: "<div class=\"page-break\"></div>")
        
        // Clean up extra whitespace and formatting
        cleaned = cleaned.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        
        return cleaned
    }
    
    // MARK: - Validation
    
    /// Check if HTML export is available
    /// - Returns: True if HTML export is supported
    static func isHTMLExportAvailable() -> Bool {
        return true // HTML export is always available on iOS/macOS
    }
}

// MARK: - Error Types

enum HTMLExportError: LocalizedError {
    case conversionFailed(String)
    case encodingFailed
    
    var errorDescription: String? {
        switch self {
        case .conversionFailed(let reason):
            return NSLocalizedString("htmlExport.error.conversionFailed", comment: "HTML conversion failed") + ": \(reason)"
        case .encodingFailed:
            return NSLocalizedString("htmlExport.error.encodingFailed", comment: "Failed to encode HTML")
        }
    }
}
