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
    let imageSize: CGSize  // Size in points
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
        
        // ALWAYS print
        #if DEBUG
        print("🔍 HTMLExportService: Scanning for images in attributed string (length: \(attributedString.length))")
        #endif
        
        // Check for any attachments at all
        var attachmentCount = 0
        attributedString.enumerateAttribute(.attachment, in: range, options: []) { value, _, _ in
            if value != nil {
                attachmentCount += 1
            }
        }
        #if DEBUG
        print("🔍 Total attachments found: \(attachmentCount)")
        #endif
        
        attributedString.enumerateAttribute(.attachment, in: range, options: []) { value, range, _ in
            if value != nil {
                #if DEBUG
                print("🔍 Found attachment at range \(range): \(type(of: value!))")
                #endif
            }
            
            if let attachment = value as? ImageAttachment {
                #if DEBUG
                print("✅ ImageAttachment found!")
                #if DEBUG
                print("   - Has image: \(attachment.image != nil)")
                #endif
                #if DEBUG
                print("   - Has imageData: \(attachment.imageData != nil)")
                #endif
                #if DEBUG
                print("   - Scale: \(attachment.scale)")
                #endif
                #if DEBUG
                print("   - Alignment: \(attachment.alignment.rawValue)")
                #endif
                #endif
                
                // Try to get image data from attachment
                var imageData: Data?
                if let data = attachment.imageData {
                    imageData = data
                } else if let image = attachment.image {
                    imageData = image.pngData()
                }
                
                // Get image size (attachment.displaySize already accounts for scale)
                let imageSize = attachment.image?.size ?? CGSize(width: 100, height: 100)
                
                if let imageData = imageData {
                    let extractedImage = ExtractedImage(
                        imageData: imageData,
                        range: range,
                        scale: attachment.scale,
                        alignment: attachment.alignment.rawValue,
                        hasCaption: attachment.hasCaption,
                        captionText: attachment.captionText,
                        imageSize: imageSize
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
            #if DEBUG
            print("📝 Raw HTML conversion sample: \(debugHTML.prefix(500))")
            #endif
        }
        #endif
        
        guard var htmlString = String(data: htmlData, encoding: .utf8) else {
            throw HTMLExportError.conversionFailed("Failed to decode HTML data")
        }
        
        // Clean up the HTML output
        htmlString = cleanupHTML(htmlString, filename: filename, includeStyles: includeStyles)
        
        #if DEBUG
        print("📤 HTMLExportService: Exported '\(filename).html'")
        #if DEBUG
        print("   HTML size: \(htmlString.count) characters")
        #endif
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
        // ALWAYS print, not just in DEBUG
        #if DEBUG
        print("🌐 HTMLExportService.exportMultipleToHTMLData() called")
        #endif
        #if DEBUG
        print("   - Number of attributed strings: \(attributedStrings.count)")
        #endif
        for (index, attrString) in attributedStrings.enumerated() {
            #if DEBUG
            print("   - String \(index + 1): length=\(attrString.length)")
            #endif
        }
        
        // Convert each attributed string to HTML body content
        var htmlBodies: [String] = []
        var allStyles = ""  // Accumulate all unique styles
        
        for (index, attributedString) in attributedStrings.enumerated() {
            #if DEBUG
            print("🔍 Processing attributed string \(index + 1) of \(attributedStrings.count)")
            #endif
            #if DEBUG
            print("   - Length: \(attributedString.length)")
            #endif
            #if DEBUG
            print("   - String preview: \(attributedString.string.prefix(100))...")
            #endif
            
            // Prepare content for HTML export (removes adaptive/white colors, allows CSS dark mode)
            let exportReady = AttributedStringSerializer.prepareForHTMLExport(from: attributedString)
            
            // Extract images before HTML conversion
            let extractedImages = extractImages(from: exportReady)
            #if DEBUG
            print("📸 File \(index + 1): Found \(extractedImages.count) images")
            #endif
            
            // Convert to HTML
            let documentAttributes: [NSAttributedString.DocumentAttributeKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
            
            guard let htmlData = try? exportReady.data(
                from: NSRange(location: 0, length: exportReady.length),
                documentAttributes: documentAttributes
            ),
            let htmlString = String(data: htmlData, encoding: .utf8) else {
                throw HTMLExportError.conversionFailed("Failed to convert attributed string to HTML")
            }
            
            #if DEBUG
            // Debug: Check what HTML is being generated for each file
            #if DEBUG
            print("📝 Raw HTML conversion sample (file \(index + 1)): \(htmlString.prefix(500))")
            #endif
            
            // Debug: Show where images appear in the raw HTML
            if htmlString.contains("Attachment") {
                let lines = htmlString.components(separatedBy: "\n")
                for (lineIdx, line) in lines.enumerated() {
                    if line.contains("Attachment") || line.contains("</style>") {
                        #if DEBUG
                        print("📝 Line \(lineIdx): \(line)")
                        #endif
                        if lineIdx < lines.count - 1 {
                            #if DEBUG
                            print("📝 Line \(lineIdx + 1): \(lines[lineIdx + 1])")
                            #endif
                        }
                        if lineIdx < lines.count - 2 {
                            #if DEBUG
                            print("📝 Line \(lineIdx + 2): \(lines[lineIdx + 2])")
                            #endif
                        }
                    }
                }
            }
            #endif
            
            // Extract iOS-generated styles and namespace them to avoid conflicts between files
            let filePrefix = "f\(index)_"
            if let styleStart = htmlString.range(of: "<style type=\"text/css\">"),
               let styleEnd = htmlString.range(of: "</style>") {
                var styleContent = String(htmlString[styleStart.upperBound..<styleEnd.lowerBound])
                
                #if DEBUG
                print("📋 Original CSS for file \(index + 1):")
                #if DEBUG
                print(styleContent.prefix(300))
                #endif
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
            #if DEBUG
            print("📝 Checking for unicode attachment chars: \(bodyContent.contains("\u{FFFC}"))")
            #endif
            #if DEBUG
            print("📝 Checking for 'Attachment' text: \(bodyContent.contains("Attachment"))")
            #endif
            if bodyContent.contains("Attachment") {
                // Show sample of where Attachment appears
                if let range = bodyContent.range(of: "Attachment") {
                    let start = bodyContent.index(range.lowerBound, offsetBy: -20, limitedBy: bodyContent.startIndex) ?? bodyContent.startIndex
                    let end = bodyContent.index(range.upperBound, offsetBy: 20, limitedBy: bodyContent.endIndex) ?? bodyContent.endIndex
                    #if DEBUG
                    print("📝 Sample: ...\(bodyContent[start..<end])...")
                    #endif
                }
            }
            #endif
            
            for (imgIndex, image) in extractedImages.enumerated() {
                // Create base64 data URI
                let base64String = image.imageData.base64EncodedString()
                let dataURI = "data:image/png;base64,\(base64String)"
                
                // Calculate the display width in CSS pixels (points) based on image's natural size and scale
                // image.imageSize is already in points (accounting for @3x scale)
                // scale represents what portion of the image to display (e.g., 0.198 = fit to 406pt width)
                let displayWidthPts = Int(image.imageSize.width * image.scale)
                
                // Create img tag with proper styling using explicit pixel width
                let alignClass = "img-\(image.alignment)"
                var imgTag = "<img src=\"\(dataURI)\" class=\"\(alignClass)\" style=\"width: \(displayWidthPts)px; max-width: 100%; height: auto;\" alt=\"Image\" />"
                
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
                    #if DEBUG
                    print("❌ Could not find placeholder to replace for image \(imgIndex + 1)")
                    #endif
                }
                #endif
            }
            
            // Wrap each file's content in a page container
            // Apply page-break-after to the container so content breaks after each file
            let wrappedContent = "<div class=\"file-page\">\(bodyContent)</div>"
            htmlBodies.append(wrappedContent)
            
            #if DEBUG
            print("📦 File \(index + 1) wrapped in file-page div (length: \(bodyContent.count) chars)")
            #endif
        }
        
        // Join all files (page breaks will be applied via CSS to .file-page elements)
        let combinedBody = htmlBodies.joined(separator: "\n")
        
        #if DEBUG
        print("📊 HTMLExportService: Created \(htmlBodies.count) file-page divs")
        #endif
        #if DEBUG
        print("   - Total HTML body length: \(combinedBody.count) characters")
        #endif
        
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
                    
                    /* Dark mode support */
                    @media (prefers-color-scheme: dark) {
                        body {
                            color: #e0e0e0;
                            background-color: #1a1a1a;
                        }
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
                        page-break-before: auto;
                        page-break-after: auto;
                        page-break-inside: auto;
                    }
                    .img-left {
                        display: block;
                        margin-right: auto; /* Left align by removing right auto margin */
                        margin-left: 0;
                        margin-top: 1em;
                        margin-bottom: 1em;
                    }
                    .img-center {
                        display: block;
                        margin-left: auto;
                        margin-right: auto;
                    }
                    .img-right {
                        display: block;
                        margin-left: auto; /* Right align */
                        margin-right: 0;
                        margin-top: 1em;
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
                        page-break-inside: avoid;
                    }
                    
                    /* File page container - each file's content */
                    .file-page {
                        page-break-after: always;
                        break-after: page;
                        -webkit-column-break-after: always;
                        page-break-inside: auto;
                        break-inside: auto;
                        clear: both; /* Clear any floats from previous pages */
                        display: flow-root; /* Create block formatting context to contain floats */
                    }
                    
                    /* Visual separator line between files (on screen only) */
                    .file-page:not(:last-child) {
                        padding-bottom: 2em;
                        border-bottom: 2px dashed #ccc;
                        margin-bottom: 3em;
                    }
                    
                    /* Ensure floated images are cleared before page break */
                    .file-page:not(:last-child)::after {
                        content: "";
                        display: table;
                        clear: both;
                    }
                    
                    /* Remove page break and margin from last page */
                    .file-page:last-child {
                        page-break-after: auto;
                        break-after: auto;
                        margin-bottom: 0;
                        padding-bottom: 0;
                    }
                    }
                    
                    @media print {
                        body {
                            max-width: none;
                            padding: 0;
                            margin: 0;
                        }
                        
                        /* Hide visual separators in print */
                        .file-page {
                            page-break-after: always !important;
                            break-after: page !important;
                            border: none !important;
                            margin: 0 !important;
                            padding: 0 !important;
                        }
                        
                        .file-page::after {
                            display: none !important;
                        }
                        
                        .file-page:last-child {
                            page-break-after: auto !important;
                        }
                        
                        img {
                            page-break-inside: avoid !important;
                            page-break-before: auto;
                            page-break-after: auto;
                            break-inside: avoid !important;
                        }
                        p {
                            orphans: 3;
                            widows: 3;
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
        #if DEBUG
        print("   HTML size: \(html.count) characters")
        #endif
        #if DEBUG
        print("   Page breaks inserted: \(attributedStrings.count - 1)")
        #endif
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
        
        // Fix invalid nesting: iOS converter wraps form feeds in <p> tags, producing
        // <p class="pN"><div class="page-break"></div></p> — a <div> inside <p> is invalid HTML.
        // Replace the entire <p>…</p> wrapper with just the <div>.
        if let pbInPRegex = try? NSRegularExpression(
            pattern: "<p[^>]*>\\s*<div class=\"page-break\"></div>\\s*</p>",
            options: []
        ) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = pbInPRegex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: range,
                withTemplate: "<div class=\"page-break\"></div>"
            )
        }
        
        // Clean up extra whitespace and formatting
        cleaned = cleaned.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        
        return cleaned
    }
    
    // MARK: - Markdown to HTML
    
    /// Convert Markdown text to HTML
    /// - Parameters:
    ///   - markdown: The Markdown content to convert
    ///   - filename: Document title
    /// - Returns: Complete HTML document string
    static func markdownToHTML(_ markdown: String, filename: String) -> String {
        var html = markdown
        
        // Process file anchor markers first (%%FILEANCHOR:id%%)
        html = html.replacingOccurrences(
            of: "%%FILEANCHOR:([^%]+)%%",
            with: "<a id=\"$1\"></a>",
            options: .regularExpression
        )
        
        // Process code blocks first (to protect them from other conversions)
        var codeBlocks: [String: String] = [:]
        var codeBlockIndex = 0
        let codeBlockPattern = "```([a-zA-Z]*)\\n([\\s\\S]*?)```"
        if let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: []) {
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            for match in matches.reversed() {
                if let range = Range(match.range, in: html),
                   let langRange = Range(match.range(at: 1), in: html),
                   let codeRange = Range(match.range(at: 2), in: html) {
                    let lang = String(html[langRange])
                    let code = String(html[codeRange])
                    let placeholder = "%%CODEBLOCK\(codeBlockIndex)%%"
                    let langClass = lang.isEmpty ? "" : " class=\"language-\(lang)\""
                    codeBlocks[placeholder] = "<pre><code\(langClass)>\(escapeHTML(code))</code></pre>"
                    html.replaceSubrange(range, with: placeholder)
                    codeBlockIndex += 1
                }
            }
        }
        
        // Inline code
        html = html.replacingOccurrences(of: "`([^`]+)`", with: "<code>$1</code>", options: .regularExpression)
        
        // Headers with IDs for anchor links (must be at start of line)
        html = addHeadingIDs(html, level: 6)
        html = addHeadingIDs(html, level: 5)
        html = addHeadingIDs(html, level: 4)
        html = addHeadingIDs(html, level: 3)
        html = addHeadingIDs(html, level: 2)
        html = addHeadingIDs(html, level: 1)
        
        // Bold and italic
        html = html.replacingOccurrences(of: "\\*\\*\\*([^*]+)\\*\\*\\*", with: "<strong><em>$1</em></strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\*([^*]+)\\*", with: "<em>$1</em>", options: .regularExpression)
        
        // Links - process and fix hrefs
        html = processLinks(html)
        
        // Unordered lists
        html = html.replacingOccurrences(of: "(?m)^- (.+)$", with: "<li>$1</li>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(<li>.*</li>\\n)+", with: "<ul>\n$0</ul>\n", options: .regularExpression)
        
        // Ordered lists
        html = html.replacingOccurrences(of: "(?m)^\\d+\\. (.+)$", with: "<li>$1</li>", options: .regularExpression)
        
        // Blockquotes
        html = html.replacingOccurrences(of: "(?m)^> (.+)$", with: "<blockquote>$1</blockquote>", options: .regularExpression)
        
        // Horizontal rules - add "Back to Contents" link before each
        html = html.replacingOccurrences(
            of: "(?m)^---+$",
            with: "<p class=\"back-to-top\"><a href=\"#contents\">↑ Back to Contents</a></p>\n<hr>",
            options: .regularExpression
        )
        html = html.replacingOccurrences(of: "(?m)^\\*\\*\\*+$", with: "<hr>", options: .regularExpression)
        
        // Tables (basic support)
        let lines = html.components(separatedBy: "\n")
        var result: [String] = []
        var inTable = false
        var headerProcessed = false
        
        for line in lines {
            if line.contains("|") && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !inTable {
                    result.append("<table>")
                    inTable = true
                    headerProcessed = false
                }
                
                // Skip separator line (|---|---|)
                if line.contains("---") {
                    headerProcessed = true
                    continue
                }
                
                let cells = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                let tag = !headerProcessed ? "th" : "td"
                let row = "<tr>" + cells.map { "<\(tag)>\($0)</\(tag)>" }.joined() + "</tr>"
                result.append(row)
            } else {
                if inTable {
                    result.append("</table>")
                    inTable = false
                }
                result.append(line)
            }
        }
        if inTable {
            result.append("</table>")
        }
        html = result.joined(separator: "\n")
        
        // Restore code blocks
        for (placeholder, codeBlock) in codeBlocks {
            html = html.replacingOccurrences(of: placeholder, with: codeBlock)
        }
        
        // Paragraphs (wrap remaining text blocks)
        html = html.replacingOccurrences(of: "(?m)^([^<\\n].+)$", with: "<p>$1</p>", options: .regularExpression)
        
        // Clean up empty paragraphs
        html = html.replacingOccurrences(of: "<p></p>", with: "")
        html = html.replacingOccurrences(of: "<p>\\s*</p>", with: "", options: .regularExpression)
        
        // Build complete HTML document
        let css = """
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 800px;
            margin: 40px auto;
            padding: 20px;
            line-height: 1.6;
            color: #333;
        }
        h1, h2, h3, h4, h5, h6 { margin-top: 1.5em; margin-bottom: 0.5em; }
        h1 { font-size: 2em; border-bottom: 1px solid #eee; padding-bottom: 0.3em; }
        h2 { font-size: 1.5em; border-bottom: 1px solid #eee; padding-bottom: 0.3em; }
        code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; font-family: monospace; }
        pre { background: #f4f4f4; padding: 16px; border-radius: 6px; overflow-x: auto; }
        pre code { background: none; padding: 0; }
        blockquote { border-left: 4px solid #ddd; margin-left: 0; padding-left: 16px; color: #666; }
        table { border-collapse: collapse; width: 100%; margin: 1em 0; }
        th, td { border: 1px solid #ddd; padding: 8px 12px; text-align: left; }
        th { background: #f4f4f4; font-weight: bold; }
        ul, ol { padding-left: 2em; }
        a { color: #0066cc; }
        hr { border: none; border-top: 1px solid #ddd; margin: 2em 0; }
        /* Back to Contents link */
        .back-to-top {
            text-align: right;
            font-size: 0.9em;
            margin: 1.5em 0 0.5em 0;
        }
        .back-to-top a {
            color: #666;
            text-decoration: none;
        }
        .back-to-top a:hover {
            color: #0066cc;
            text-decoration: underline;
        }
        @media (prefers-color-scheme: dark) {
            body { background: #1a1a1a; color: #e0e0e0; }
            code, pre { background: #2d2d2d; }
            th { background: #2d2d2d; }
            th, td { border-color: #444; }
            blockquote { border-color: #555; color: #aaa; }
            h1, h2 { border-color: #444; }
            a { color: #4da3ff; }
            .back-to-top a { color: #999; }
        }
        """
        
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(escapeHTML(filename))</title>
            <style>\(css)</style>
        </head>
        <body>
        \(html)
        </body>
        </html>
        """
    }
    
    /// Escape HTML special characters
    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
    
    /// Generate a slug/ID from heading text
    private static func slugify(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s-]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
    
    /// Add IDs to headings for anchor link support
    private static func addHeadingIDs(_ html: String, level: Int) -> String {
        let hashes = String(repeating: "#", count: level)
        let pattern = "(?m)^\(hashes) (.+)$"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return html
        }
        
        var result = html
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        
        // Process in reverse to maintain ranges
        for match in matches.reversed() {
            if let range = Range(match.range, in: result),
               let textRange = Range(match.range(at: 1), in: result) {
                let headingText = String(result[textRange])
                let id = slugify(headingText)
                let replacement = "<h\(level) id=\"\(id)\">\(headingText)</h\(level)>"
                result.replaceSubrange(range, with: replacement)
            }
        }
        
        return result
    }
    
    /// Process links - add target="_blank" for external links, fix internal links
    private static func processLinks(_ html: String) -> String {
        let linkPattern = "\\[([^\\]]+)\\]\\(([^)]+)\\)"
        
        guard let regex = try? NSRegularExpression(pattern: linkPattern, options: []) else {
            return html.replacingOccurrences(of: linkPattern, with: "<a href=\"$2\">$1</a>", options: .regularExpression)
        }
        
        var result = html
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        
        // Process in reverse to maintain ranges
        for match in matches.reversed() {
            if let range = Range(match.range, in: result),
               let textRange = Range(match.range(at: 1), in: result),
               let hrefRange = Range(match.range(at: 2), in: result) {
                let linkText = String(result[textRange])
                let href = String(result[hrefRange])
                
                // Determine link type and build appropriate anchor tag
                var attrs: String
                
                if href.hasPrefix("http://") || href.hasPrefix("https://") {
                    // External link - open in new tab
                    attrs = "href=\"\(href)\" target=\"_blank\" rel=\"noopener noreferrer\""
                } else if href.hasSuffix(".md") {
                    // Link to another .md file - convert to anchor based on filename
                    // Extract just the filename without path and extension
                    let filename = (href as NSString).lastPathComponent
                    let anchor = filename
                        .replacingOccurrences(of: ".md", with: "")
                        .lowercased()
                        .replacingOccurrences(of: " ", with: "-")
                        .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
                    attrs = "href=\"#\(anchor)\""
                } else if href.hasPrefix("#") {
                    // Already an anchor link - slugify to match heading IDs
                    let anchorText = String(href.dropFirst())
                    attrs = "href=\"#\(slugify(anchorText))\""
                } else if href.hasPrefix("mailto:") {
                    // Email link
                    attrs = "href=\"\(href)\""
                } else {
                    // Other relative link - try to make it work as anchor
                    let anchor = slugify(href)
                    attrs = "href=\"#\(anchor)\""
                }
                
                let replacement = "<a \(attrs)>\(linkText)</a>"
                result.replaceSubrange(range, with: replacement)
            }
        }
        
        return result
    }
    
    /// Export Markdown content to HTML data
    /// - Parameters:
    ///   - markdown: The Markdown content
    ///   - filename: Document title
    /// - Returns: HTML data
    static func exportMarkdownToHTMLData(_ markdown: String, filename: String) throws -> Data {
        let html = markdownToHTML(markdown, filename: filename)
        guard let data = html.data(using: .utf8) else {
            throw HTMLExportError.encodingFailed
        }
        return data
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
