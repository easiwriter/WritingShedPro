//
//  EPUBExportService.swift
//  Writing Shed Pro
//
//  Created on 8 December 2025.
//

import Foundation
import UIKit
import UniformTypeIdentifiers

/// Service for exporting content to EPUB format
class EPUBExportService {
    
    // MARK: - Export
    
    /// Export attributed string to EPUB format
    /// - Parameters:
    ///   - attributedString: The formatted content to export
    ///   - filename: Name for the document (used as title)
    ///   - author: Author name (optional)
    ///   - language: Language code (default: "en")
    /// - Returns: EPUB data as Data
    /// - Throws: Error if export fails
    static func exportToEPUB(
        _ attributedString: NSAttributedString,
        filename: String,
        author: String? = nil,
        language: String = "en"
    ) throws -> Data {
        
        // Convert content to HTML
        let htmlContent = try HTMLExportService.exportToHTML(
            attributedString,
            filename: filename,
            includeStyles: false // EPUB uses separate CSS
        )
        
        // Create EPUB structure
        let epub = try createEPUBPackage(
            htmlContent: htmlContent,
            title: filename,
            author: author,
            language: language
        )
        
        #if DEBUG
        print("📤 EPUBExportService: Exported '\(filename).epub'")
        #if DEBUG
        print("   EPUB size: \(epub.count) bytes")
        #endif
        #endif
        
        return epub
    }
    
    /// Structure to hold extracted image information
    private struct ExtractedImage {
        let imageData: Data
        let range: NSRange
        let displayWidthPts: Int  // Display width in CSS points
        let alignment: String
        let hasCaption: Bool
        let captionText: String?
        let imageSize: CGSize  // Natural image size in points
    }
    
    /// Export multiple attributed strings with page breaks between them
    /// - Parameters:
    ///   - attributedStrings: Array of formatted content to export
    ///   - filename: Name for the document (used as title)
    ///   - author: Author name (optional)
    ///   - language: Language code (default: "en")
    /// - Returns: EPUB data as Data
    /// - Throws: Error if export fails
    static func exportMultipleToEPUB(
        _ attributedStrings: [NSAttributedString],
        filename: String,
        author: String? = nil,
        language: String = "en"
    ) throws -> Data {
        
        // Extract all images from all attributed strings
        var allImages: [ExtractedImage] = []
        
        // Convert each attributed string to HTML body content with namespacing
        var htmlBodies: [String] = []
        var allStyles = ""  // Accumulate all unique styles
        
        for (index, attributedString) in attributedStrings.enumerated() {
            // Prepare content for export with explicit colors
            let exportReady = AttributedStringSerializer.prepareForExport(from: attributedString)
            
            // Extract images before conversion
            #if DEBUG
            print("🔍 EPUBExportService: Scanning file \(index + 1) for images (length: \(exportReady.length))")
            #endif
            
            exportReady.enumerateAttribute(.attachment, in: NSRange(location: 0, length: exportReady.length)) { value, range, _ in
                #if DEBUG
                print("🔍 Found attachment at range \(range): \(type(of: value))")
                #endif
                
                if let attachment = value as? ImageAttachment {
                    #if DEBUG
                    print("✅ ImageAttachment found!")
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
                    
                    if let imageData = attachment.imageData,
                       let image = attachment.image {
                        
                        // Calculate display width in CSS pixels (points) - same as HTML export
                        // image.size is already in points (accounting for @2x/@3x scale)
                        // scale represents what portion to display (e.g., 0.198 = fit to 406pt width)
                        let displayWidthPts = Int(image.size.width * attachment.scale)
                        
                        let extractedImage = ExtractedImage(
                            imageData: imageData,
                            range: range,
                            displayWidthPts: displayWidthPts,
                            alignment: attachment.alignment.rawValue,
                            hasCaption: attachment.hasCaption,
                            captionText: attachment.captionText,
                            imageSize: image.size
                        )
                        allImages.append(extractedImage)
                        
                        #if DEBUG
                        print("✅ Image extracted for EPUB (size: \(imageData.count) bytes, displayWidth: \(displayWidthPts)px)")
                        #endif
                    } else {
                        #if DEBUG
                        print("❌ ImageAttachment has no imageData or image")
                        #endif
                    }
                }
            }
            
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
                throw EPUBExportError.conversionFailed("Failed to convert attributed string to HTML")
            }
            
            // Extract iOS-generated styles and namespace them to avoid conflicts between files
            let filePrefix = "f\(index)_"
            if let styleStart = htmlString.range(of: "<style type=\"text/css\">"),
               let styleEnd = htmlString.range(of: "</style>") {
                var styleContent = String(htmlString[styleStart.upperBound..<styleEnd.lowerBound])
                
                // Namespace the CSS class names to prevent conflicts (e.g., .p1 -> .f0_p1)
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
                bodyContent = htmlString
            }
            
            // Namespace the class names in the body to match the CSS
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
            
            // Clean up the body content (same as HTML export)
            bodyContent = bodyContent.replacingOccurrences(of: "<br />", with: "<br>")
            bodyContent = bodyContent.replacingOccurrences(of: "<br/>", with: "<br>")
            bodyContent = bodyContent.replacingOccurrences(of: "</p>\n<p>", with: "</p><p>")
            bodyContent = bodyContent.replacingOccurrences(of: "</div>\n<div>", with: "</div><div>")
            bodyContent = bodyContent.replacingOccurrences(of: "<p>\n", with: "<p>")
            bodyContent = bodyContent.replacingOccurrences(of: "\n</p>", with: "</p>")
            bodyContent = bodyContent.replacingOccurrences(of: "<div>\n", with: "<div>")
            bodyContent = bodyContent.replacingOccurrences(of: "\n</div>", with: "</div>")
            bodyContent = bodyContent.replacingOccurrences(of: "<br>\n", with: "<br>")
            
            while bodyContent.contains("  ") {
                bodyContent = bodyContent.replacingOccurrences(of: "  ", with: " ")
            }
            
            htmlBodies.append(bodyContent)
        }
        
        // Replace attachment placeholders with image tags
        var combinedBodyWithImages = htmlBodies.joined(separator: "\n<div style=\"page-break-after: always;\"></div>\n")
        var currentImageIndex = 0
        
        #if DEBUG
        print("📝 EPUBExportService: Replacing \(allImages.count) images in combined body")
        #if DEBUG
        print("📝 Body contains unicode attachment chars: \(combinedBodyWithImages.contains("\u{FFFC}"))")
        #endif
        #if DEBUG
        print("📝 Body contains 'Attachment' text: \(combinedBodyWithImages.contains("Attachment"))")
        #endif
        if combinedBodyWithImages.contains("Attachment") {
            if let range = combinedBodyWithImages.range(of: "Attachment") {
                let start = combinedBodyWithImages.index(range.lowerBound, offsetBy: -20, limitedBy: combinedBodyWithImages.startIndex) ?? combinedBodyWithImages.startIndex
                let end = combinedBodyWithImages.index(range.upperBound, offsetBy: 20, limitedBy: combinedBodyWithImages.endIndex) ?? combinedBodyWithImages.endIndex
                #if DEBUG
                print("📝 Sample: ...\(combinedBodyWithImages[start..<end])...")
                #endif
            }
        }
        #endif
        
        // Replace each image placeholder (either unicode character or iOS-generated img tag)
        while currentImageIndex < allImages.count {
            let image = allImages[currentImageIndex]
            
            // Create image reference (images will be saved in OEBPS/images/)
            let imageSrc = "images/image\(currentImageIndex).png"
            
            // For EPUB, calculate width as percentage of typical content width
            // EPUB readers typically display content at ~300-400px width depending on device
            // Using 300px as baseline to match HTML display size
            let typicalEPUBContentWidth: CGFloat = 300.0
            let widthPercent = min(100, Int((CGFloat(image.displayWidthPts) / typicalEPUBContentWidth) * 100))
            
            let alignClass = "img-\(image.alignment)"
            var imageHTML = "<img src=\"\(imageSrc)\" class=\"\(alignClass)\" style=\"width: \(widthPercent)%; max-width: 100%; height: auto;\" alt=\"Image \(currentImageIndex)\" />"
            
            // Add caption if present
            if image.hasCaption, let captionText = image.captionText, !captionText.isEmpty {
                imageHTML += "\n<p class=\"image-caption\">\(captionText)</p>"
            }
            
            #if DEBUG
            print("🔄 Replacing EPUB image \(currentImageIndex + 1) with src='\(imageSrc)' (width: \(widthPercent)% = \(image.displayWidthPts)px / \(typicalEPUBContentWidth)px)")
            #endif
            
            var replaced = false
            
            // iOS HTML converter creates either:
            // 1. Unicode attachment character (U+FFFC)
            // 2. <img src="Attachment.tiff"> or similar placeholder
            
            // First try unicode attachment character
            let attachmentChar = "\u{FFFC}"
            if let range = combinedBodyWithImages.range(of: attachmentChar) {
                combinedBodyWithImages.replaceSubrange(range, with: imageHTML)
                currentImageIndex += 1
                replaced = true
                #if DEBUG
                print("✅ Replaced unicode attachment character")
                #endif
            } else {
                // Look for iOS-generated img tag placeholder
                // Match patterns like: <img src="file:///Attachment.tiff"...> or src="Attachment-1.tiff"
                let pattern = "<img[^>]*src=\"[^\"]*[Aa]ttachment[^\"]*\"[^>]*>"
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let nsRange = NSRange(combinedBodyWithImages.startIndex..., in: combinedBodyWithImages)
                    if let match = regex.firstMatch(in: combinedBodyWithImages, options: [], range: nsRange),
                       let range = Range(match.range, in: combinedBodyWithImages) {
                        #if DEBUG
                        print("✅ Found and replacing iOS img tag: \(combinedBodyWithImages[range])")
                        #endif
                        combinedBodyWithImages.replaceSubrange(range, with: imageHTML)
                        currentImageIndex += 1
                        replaced = true
                    } else {
                        // No more placeholders found, stop
                        #if DEBUG
                        print("❌ No more placeholders found, stopping at image \(currentImageIndex + 1)")
                        #endif
                        break
                    }
                } else {
                    // Regex failed, stop
                    #if DEBUG
                    print("❌ Regex failed for image \(currentImageIndex + 1)")
                    #endif
                    break
                }
            }
            
            #if DEBUG
            if !replaced {
                #if DEBUG
                print("❌ Could not find placeholder to replace for EPUB image \(currentImageIndex + 1)")
                #endif
            }
            #endif
        }
        
        #if DEBUG
        print("📊 EPUB: Replaced \(currentImageIndex) of \(allImages.count) images")
        #endif
        
        // Clean up HTML for EPUB/XHTML compatibility
        // EPUB requires well-formed XHTML, so fix common issues from iOS HTML converter
        combinedBodyWithImages = cleanHTMLForEPUB(combinedBodyWithImages)
        
        // Create complete HTML content (body only - styles will be passed separately)
        let htmlContent = """
        <html>
        <body>
        \(combinedBodyWithImages)
        </body>
        </html>
        """
        
        // Create EPUB structure with custom styles and images
        let epub = try createEPUBPackage(
            htmlContent: htmlContent,
            title: filename,
            author: author,
            language: language,
            customCSS: allStyles,  // Pass iOS-generated styles
            images: allImages.map { $0.imageData }  // Extract just the image data
        )
        
        #if DEBUG
        print("📤 EPUBExportService: Exported '\(filename).epub' with \(attributedStrings.count) files")
        #if DEBUG
        print("   EPUB size: \(epub.count) bytes")
        #endif
        #if DEBUG
        print("   Page breaks inserted: \(attributedStrings.count - 1)")
        #endif
        #endif
        
        return epub
    }
    
    // MARK: - HTML Cleanup
    
    /// Clean HTML to ensure EPUB/XHTML compatibility
    /// - Parameter html: Raw HTML from iOS converter
    /// - Returns: Cleaned HTML suitable for EPUB
    private static func cleanHTMLForEPUB(_ html: String) -> String {
        var cleaned = html
        
        // Fix self-closing tags - EPUB requires XHTML format
        // Replace <br> with <br/> (self-closing)
        cleaned = cleaned.replacingOccurrences(of: "<br>", with: "<br/>")
        cleaned = cleaned.replacingOccurrences(of: "<BR>", with: "<br/>")
        
        // Fix <img> tags to be self-closing if not already
        // Match <img...> that doesn't end with /> and replace with self-closing version
        if let regex = try? NSRegularExpression(pattern: "<img([^>]+)>", options: []) {
            let nsRange = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: nsRange,
                withTemplate: "<img$1 />"
            )
        }
        
        // Remove any empty <span></span> tags that might cause issues
        cleaned = cleaned.replacingOccurrences(of: "<span></span>", with: "")
        
        // Ensure proper paragraph structure - no <br/> directly inside <p> at end
        // Replace <p>...<br/></p> with just <p>...</p>
        if let regex = try? NSRegularExpression(pattern: "<p([^>]*)>([^<]*)<br\\s*/?>\\s*</p>", options: []) {
            let nsRange = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: nsRange,
                withTemplate: "<p$1>$2</p>"
            )
        }
        
        return cleaned
    }
    
    // MARK: - EPUB Package Creation
    
    /// Create an EPUB package (ZIP file with specific structure)
    private static func createEPUBPackage(
        htmlContent: String,
        title: String,
        author: String?,
        language: String,
        customCSS: String? = nil,
        images: [Data] = []
    ) throws -> Data {
        
        // Create a temporary directory for EPUB structure
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // Create EPUB structure
        try createMimetypeFile(in: tempDir)
        try createContainerXML(in: tempDir)
        try createContentOPF(in: tempDir, title: title, author: author, language: language, imageCount: images.count)
        try createTableOfContentsNCX(in: tempDir, title: title)
        try createContentHTML(in: tempDir, html: htmlContent, title: title)
        try createStyleCSS(in: tempDir, customCSS: customCSS)
        
        // Save images if any
        if !images.isEmpty {
            try createImagesDirectory(in: tempDir, images: images)
        }
        
        // Create ZIP archive
        let epubData = try zipDirectory(tempDir)
        
        return epubData
    }
    
    /// Create mimetype file (must be first file, uncompressed)
    private static func createMimetypeFile(in directory: URL) throws {
        let mimetypeURL = directory.appendingPathComponent("mimetype")
        let mimetype = "application/epub+zip"
        try mimetype.write(to: mimetypeURL, atomically: true, encoding: .ascii)
    }
    
    /// Create META-INF/container.xml
    private static func createContainerXML(in directory: URL) throws {
        let metaInfDir = directory.appendingPathComponent("META-INF")
        try FileManager.default.createDirectory(at: metaInfDir, withIntermediateDirectories: true)
        
        let containerXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
            <rootfiles>
                <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
            </rootfiles>
        </container>
        """
        
        let containerURL = metaInfDir.appendingPathComponent("container.xml")
        try containerXML.write(to: containerURL, atomically: true, encoding: .utf8)
    }
    
    /// Create OEBPS/content.opf (package document)
    private static func createContentOPF(in directory: URL, title: String, author: String?, language: String, imageCount: Int = 0) throws {
        let oebpsDir = directory.appendingPathComponent("OEBPS")
        try FileManager.default.createDirectory(at: oebpsDir, withIntermediateDirectories: true)
        
        let uuid = UUID().uuidString
        let date = ISO8601DateFormatter().string(from: Date())
        let authorMetadata = author.map { "<dc:creator>\($0)</dc:creator>" } ?? ""
        
        // Generate image manifest items
        var imageItems = ""
        for i in 0..<imageCount {
            imageItems += "\n                <item id=\"image\(i)\" href=\"images/image\(i).png\" media-type=\"image/png\"/>"
        }
        
        let contentOPF = """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid">
            <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:identifier id="uid">urn:uuid:\(uuid)</dc:identifier>
                <dc:title>\(escapeXML(title))</dc:title>
                \(authorMetadata)
                <dc:language>\(language)</dc:language>
                <meta property="dcterms:modified">\(date)</meta>
                <meta name="generator" content="Writing Shed Pro"/>
            </metadata>
            <manifest>
                <item id="toc" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
                <item id="content" href="content.html" media-type="application/xhtml+xml"/>
                <item id="style" href="style.css" media-type="text/css"/>\(imageItems)
            </manifest>
            <spine toc="toc">
                <itemref idref="content"/>
            </spine>
        </package>
        """
        
        let contentOPFURL = oebpsDir.appendingPathComponent("content.opf")
        try contentOPF.write(to: contentOPFURL, atomically: true, encoding: .utf8)
    }
    
    /// Create OEBPS/toc.ncx (table of contents for EPUB 2.0 compatibility)
    private static func createTableOfContentsNCX(in directory: URL, title: String) throws {
        let oebpsDir = directory.appendingPathComponent("OEBPS")
        
        let uuid = UUID().uuidString
        
        let tocNCX = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
            <head>
                <meta name="dtb:uid" content="urn:uuid:\(uuid)"/>
                <meta name="dtb:depth" content="1"/>
                <meta name="dtb:totalPageCount" content="0"/>
                <meta name="dtb:maxPageNumber" content="0"/>
            </head>
            <docTitle>
                <text>\(escapeXML(title))</text>
            </docTitle>
            <navMap>
                <navPoint id="content" playOrder="1">
                    <navLabel>
                        <text>\(escapeXML(title))</text>
                    </navLabel>
                    <content src="content.html"/>
                </navPoint>
            </navMap>
        </ncx>
        """
        
        let tocURL = oebpsDir.appendingPathComponent("toc.ncx")
        try tocNCX.write(to: tocURL, atomically: true, encoding: .utf8)
    }
    
    /// Create OEBPS/content.html (main content)
    private static func createContentHTML(in directory: URL, html: String, title: String) throws {
        let oebpsDir = directory.appendingPathComponent("OEBPS")
        
        // Extract body content from HTML if present
        var bodyContent = html
        if let bodyStart = html.range(of: "<body>"),
           let bodyEnd = html.range(of: "</body>") {
            bodyContent = String(html[bodyStart.upperBound..<bodyEnd.lowerBound])
        }
        
        // Convert page breaks to EPUB page break divs
        bodyContent = bodyContent.replacingOccurrences(of: "\u{000C}", with: "<div style=\"page-break-after: always;\"></div>")
        
        // Clean up excessive newlines and whitespace
        // The iOS HTML converter adds <br> tags and newlines
        
        // First, normalize all line break variations
        bodyContent = bodyContent.replacingOccurrences(of: "<br />", with: "<br>")
        bodyContent = bodyContent.replacingOccurrences(of: "<br/>", with: "<br>")
        
        // Remove newlines between closing and opening tags (but NOT spans - they mark style boundaries)
        bodyContent = bodyContent.replacingOccurrences(of: "</p>\n<p>", with: "</p><p>")
        bodyContent = bodyContent.replacingOccurrences(of: "</div>\n<div>", with: "</div><div>")
        
        // Remove newlines after opening tags and before closing tags
        bodyContent = bodyContent.replacingOccurrences(of: "<p>\n", with: "<p>")
        bodyContent = bodyContent.replacingOccurrences(of: "\n</p>", with: "</p>")
        bodyContent = bodyContent.replacingOccurrences(of: "<div>\n", with: "<div>")
        bodyContent = bodyContent.replacingOccurrences(of: "\n</div>", with: "</div>")
        
        // Remove newlines after br tags (these create double spacing)
        bodyContent = bodyContent.replacingOccurrences(of: "<br>\n", with: "<br>")
        
        // Clean up any multiple spaces that may have been created
        while bodyContent.contains("  ") {
            bodyContent = bodyContent.replacingOccurrences(of: "  ", with: " ")
        }
        
        let contentHTML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
        <head>
            <meta charset="UTF-8"/>
            <title></title>
            <link rel="stylesheet" type="text/css" href="style.css"/>
        </head>
        <body>
        \(bodyContent)
        </body>
        </html>
        """
        
        let contentURL = oebpsDir.appendingPathComponent("content.html")
        try contentHTML.write(to: contentURL, atomically: true, encoding: .utf8)
    }
    
    /// Create OEBPS/style.css
    private static func createStyleCSS(in directory: URL, customCSS: String? = nil) throws {
        let oebpsDir = directory.appendingPathComponent("OEBPS")
        
        var styleCSS = ""
        
        // Add custom CSS first (iOS-generated styles with namespacing)
        if let customCSS = customCSS, !customCSS.isEmpty {
            styleCSS += "/* iOS-generated styles (namespaced) */\n"
            styleCSS += customCSS
            styleCSS += "\n\n"
        }
        
        // Add our custom CSS
        styleCSS += """
        /* Base document styles */
        body {
            font-family: Georgia, serif;
            font-size: 1em;
            line-height: 1.6;
            margin: 1em;
            padding: 0;
            text-align: justify;
        }
        
        h1, h2, h3, h4, h5, h6 {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin-top: 1.5em;
            margin-bottom: 0.5em;
            font-weight: 600;
            text-align: left;
        }
        
        h1 {
            font-size: 2em;
            margin-top: 0;
        }
        
        h2 {
            font-size: 1.5em;
        }
        
        p {
            margin: 0 0 1em 0;
            text-indent: 0;
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
            margin-right: auto;
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
            margin-left: auto;
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
        }
        
        /* Text formatting */
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
        
        /* Page break support */
        div[style*="page-break-after"] {
            page-break-after: always;
            break-after: page;
        }
        """
        
        let styleURL = oebpsDir.appendingPathComponent("style.css")
        try styleCSS.write(to: styleURL, atomically: true, encoding: .utf8)
    }
    
    /// Create OEBPS/images/ directory and save images
    private static func createImagesDirectory(in directory: URL, images: [Data]) throws {
        let oebpsDir = directory.appendingPathComponent("OEBPS")
        let imagesDir = oebpsDir.appendingPathComponent("images")
        try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        
        for (index, imageData) in images.enumerated() {
            let imageURL = imagesDir.appendingPathComponent("image\(index).png")
            try imageData.write(to: imageURL)
        }
    }
    
    // MARK: - ZIP Utilities
    
    /// Create a ZIP archive from a directory
    private static func zipDirectory(_ directory: URL) throws -> Data {
        // Use FileManager to create zip (requires Foundation on iOS 16+)
        let coordinator = NSFileCoordinator()
        var error: NSError?
        var zipData: Data?
        
        coordinator.coordinate(readingItemAt: directory, options: [.forUploading], error: &error) { url in
            zipData = try? Data(contentsOf: url)
        }
        
        if let error = error {
            throw EPUBExportError.zipFailed(error.localizedDescription)
        }
        
        guard let data = zipData else {
            throw EPUBExportError.zipFailed("Failed to create ZIP archive")
        }
        
        return data
    }
    
    // MARK: - XML Utilities
    
    /// Escape XML special characters
    private static func escapeXML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
    
    // MARK: - Validation
    
    /// Check if EPUB export is available
    /// - Returns: True if EPUB export is supported
    static func isEPUBExportAvailable() -> Bool {
        return true // EPUB export is always available
    }
}

// MARK: - Error Types

enum EPUBExportError: LocalizedError {
    case conversionFailed(String)
    case zipFailed(String)
    case structureCreationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .conversionFailed(let reason):
            return NSLocalizedString("epubExport.error.conversionFailed", comment: "EPUB conversion failed") + ": \(reason)"
        case .zipFailed(let reason):
            return NSLocalizedString("epubExport.error.zipFailed", comment: "Failed to create EPUB package") + ": \(reason)"
        case .structureCreationFailed(let reason):
            return NSLocalizedString("epubExport.error.structureFailed", comment: "Failed to create EPUB structure") + ": \(reason)"
        }
    }
}
