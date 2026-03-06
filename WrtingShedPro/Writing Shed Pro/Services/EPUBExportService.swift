//
//  EPUBExportService.swift
//  Writing Shed Pro
//
//  Created on 8 December 2025.
//

import Foundation
import UIKit
import UniformTypeIdentifiers
import Compression

/// Service for exporting content to EPUB format
class EPUBExportService {
    
    // MARK: - Types
    
    /// A table-of-contents entry extracted from semantic headings
    private struct TOCEntry {
        let id: String      // anchor id e.g. "toc-1"
        let title: String   // plain-text heading
        let level: Int      // 1–6
    }
    
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
        language: String = "en",
        coverImageData: Data? = nil,
        isPoetry: Bool = false
    ) throws -> Data {
        
        // The iOS NSAttributedString → HTML converter may strip or mangle the
        // form feed character (\u{000C}).  To guarantee page breaks survive,
        // replace every form feed with a unique text marker BEFORE conversion,
        // then swap the marker for a proper <div> in the resulting HTML.
        let pageBreakMarker = "EPUB_PAGE_BREAK_79f3a1"
        
        // Build a mutable copy and replace form feeds with our marker
        let mutable = NSMutableAttributedString(attributedString: attributedString)
        let plainString = mutable.string as NSString
        // Replace in reverse so ranges stay valid
        var searchRange = NSRange(location: 0, length: plainString.length)
        var formFeedLocations: [Int] = []
        while true {
            let found = plainString.range(of: "\u{000C}", options: [], range: searchRange)
            if found.location == NSNotFound { break }
            formFeedLocations.append(found.location)
            searchRange = NSRange(location: found.location + found.length,
                                  length: plainString.length - found.location - found.length)
        }
        
        #if DEBUG
        print("📦 EPUB: Found \(formFeedLocations.count) form feed characters to convert")
        #endif
        
        // Replace in reverse order
        for loc in formFeedLocations.reversed() {
            mutable.replaceCharacters(in: NSRange(location: loc, length: 1),
                                       with: NSAttributedString(string: pageBreakMarker))
        }
        
        // Convert to HTML (the marker is plain text so the iOS converter will keep it)
        let htmlContent = try HTMLExportService.exportToHTML(
            mutable,
            filename: filename,
            includeStyles: false
        )
        
        // Extract iOS-generated CSS from the HTML
        var iOSCSS: String?
        if let styleStart = htmlContent.range(of: "<style type=\"text/css\">"),
           let styleEnd = htmlContent.range(of: "</style>") {
            iOSCSS = String(htmlContent[styleStart.upperBound..<styleEnd.lowerBound])
        }
        
        #if DEBUG
        print("📦 EPUB: coverImageData \(coverImageData == nil ? "nil" : "\(coverImageData!.count) bytes"), isPoetry=\(isPoetry), iOSCSS=\(iOSCSS == nil ? "nil" : "\(iOSCSS!.count) chars")")
        #endif
        
        // Create EPUB structure
        let epub = try createEPUBPackage(
            htmlContent: htmlContent,
            title: filename,
            author: author,
            language: language,
            customCSS: iOSCSS,
            coverImageData: coverImageData,
            isPoetry: isPoetry
        )
        
        #if DEBUG
        print("📤 EPUBExportService: Exported '\(filename).epub'")
        print("   EPUB size: \(epub.count) bytes")
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
        language: String = "en",
        coverImageData: Data? = nil
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
            images: allImages.map { $0.imageData },  // Extract just the image data
            coverImageData: coverImageData
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
        // Match <img...> that doesn't already end with /> and replace with self-closing version
        if let regex = try? NSRegularExpression(pattern: "<img([^>]*[^/])>", options: []) {
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
        
        // Remove trailing <br/> before </p> (handles paragraphs with nested span tags too)
        // This prevents double-spacing on Kindle where <br/></p> adds an extra blank line
        if let regex = try? NSRegularExpression(pattern: "<br\\s*/?>\\s*</p>", options: []) {
            let nsRange = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: nsRange,
                withTemplate: "</p>"
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
        images: [Data] = [],
        coverImageData: Data? = nil,
        isPoetry: Bool = false
    ) throws -> Data {
        
        // Create a temporary directory for EPUB structure
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // Create EPUB structure
        let hasCover = coverImageData != nil
        try createMimetypeFile(in: tempDir)
        try createContainerXML(in: tempDir)
        try createContentOPF(in: tempDir, title: title, author: author, language: language, imageCount: images.count, hasCover: hasCover)
        let tocEntries = try createContentHTML(in: tempDir, html: htmlContent, title: title, css: customCSS)
        try createTableOfContentsNCX(in: tempDir, title: title, entries: tocEntries)
        try createNavigationDocument(in: tempDir, title: title, hasCover: hasCover, entries: tocEntries)
        try createStyleCSS(in: tempDir, customCSS: customCSS, isPoetry: isPoetry)
        
        // Save cover image if provided
        if let coverData = coverImageData {
            try createCoverPage(in: tempDir, title: title)
            try saveCoverImage(in: tempDir, imageData: coverData)
        }
        
        // Save images if any
        if !images.isEmpty {
            try createImagesDirectory(in: tempDir, images: images)
        }
        
        // Create EPUB-compliant ZIP archive (mimetype first, uncompressed)
        let epubData = try createEPUBZip(from: tempDir)
        
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
    private static func createContentOPF(in directory: URL, title: String, author: String?, language: String, imageCount: Int = 0, hasCover: Bool = false) throws {
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
        
        // Cover image metadata and manifest items
        var coverMeta = ""
        var coverManifestItems = ""
        var coverSpineItem = ""
        var guideElement = ""
        if hasCover {
            coverMeta = "\n                <meta name=\"cover\" content=\"cover-image\"/>"
            coverManifestItems = "\n                <item id=\"cover-image\" href=\"images/cover.jpg\" media-type=\"image/jpeg\" properties=\"cover-image\"/>"
            coverManifestItems += "\n                <item id=\"cover\" href=\"cover.html\" media-type=\"application/xhtml+xml\"/>"
            coverSpineItem = "\n                <itemref idref=\"cover\"/>"
            // Kindle requires <guide> element to recognize the cover page
            guideElement = "\n    <guide>\n        <reference type=\"cover\" title=\"Cover\" href=\"cover.html\"/>\n    </guide>"
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
                <meta name="generator" content="Writing Shed Pro"/>\(coverMeta)
            </metadata>
            <manifest>
                <item id="toc" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
                <item id="content" href="content.html" media-type="application/xhtml+xml"/>
                <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
                <item id="style" href="style.css" media-type="text/css"/>\(coverManifestItems)\(imageItems)
            </manifest>
            <spine toc="toc">\(coverSpineItem)
                <itemref idref="content"/>
            </spine>\(guideElement)
        </package>
        """
        
        let contentOPFURL = oebpsDir.appendingPathComponent("content.opf")
        try contentOPF.write(to: contentOPFURL, atomically: true, encoding: .utf8)
    }
    
    /// Create OEBPS/toc.ncx (table of contents for EPUB 2.0 compatibility)
    private static func createTableOfContentsNCX(in directory: URL, title: String, entries: [TOCEntry] = []) throws {
        let oebpsDir = directory.appendingPathComponent("OEBPS")
        
        let uuid = UUID().uuidString
        let maxDepth = entries.map(\.level).max() ?? 1
        
        var navPoints = ""
        if entries.isEmpty {
            navPoints = """
                        <navPoint id="content" playOrder="1">
                            <navLabel>
                                <text>\(escapeXML(title))</text>
                            </navLabel>
                            <content src="content.html"/>
                        </navPoint>
            """
        } else {
            for (index, entry) in entries.enumerated() {
                navPoints += """
                            <navPoint id="navpoint-\(index + 1)" playOrder="\(index + 1)">
                                <navLabel>
                                    <text>\(escapeXML(entry.title))</text>
                                </navLabel>
                                <content src="content.html#\(entry.id)"/>
                            </navPoint>\n
                """
            }
        }
        
        let tocNCX = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
            <head>
                <meta name="dtb:uid" content="urn:uuid:\(uuid)"/>
                <meta name="dtb:depth" content="\(maxDepth)"/>
                <meta name="dtb:totalPageCount" content="0"/>
                <meta name="dtb:maxPageNumber" content="0"/>
            </head>
            <docTitle>
                <text>\(escapeXML(title))</text>
            </docTitle>
            <navMap>
        \(navPoints)
            </navMap>
        </ncx>
        """
        
        let tocURL = oebpsDir.appendingPathComponent("toc.ncx")
        try tocNCX.write(to: tocURL, atomically: true, encoding: .utf8)
    }
    
    /// Create OEBPS/content.html (main content)
    /// Returns extracted TOC entries from detected headings.
    @discardableResult
    private static func createContentHTML(in directory: URL, html: String, title: String, css: String? = nil) throws -> [TOCEntry] {
        let oebpsDir = directory.appendingPathComponent("OEBPS")
        
        // Extract body content from HTML if present
        var bodyContent = html
        if let bodyStart = html.range(of: "<body>"),
           let bodyEnd = html.range(of: "</body>") {
            bodyContent = String(html[bodyStart.upperBound..<bodyEnd.lowerBound])
        }
        
        // Convert page-break markers to EPUB page-break divs.
        // exportToEPUB() replaces form feed chars with the text "EPUB_PAGE_BREAK_79f3a1"
        // BEFORE the iOS HTML converter runs.  The converter wraps them in <p>/<span>,
        // producing something like:
        //   <p class="p3"><span class="s1">EPUB_PAGE_BREAK_79f3a1</span></p>
        // We need to replace the whole enclosing <p>…</p> with a standalone <div>.
        
        let pageBreakMarker = "EPUB_PAGE_BREAK_79f3a1"
        
        // Match a <p> whose only content is the marker (optionally wrapped in <span> tags)
        if let markerInPRegex = try? NSRegularExpression(
            pattern: "<p[^>]*>(?:\\s*<span[^>]*>)*\\s*\(NSRegularExpression.escapedPattern(for: pageBreakMarker))\\s*(?:</span>\\s*)*</p>",
            options: []
        ) {
            let range = NSRange(bodyContent.startIndex..., in: bodyContent)
            bodyContent = markerInPRegex.stringByReplacingMatches(
                in: bodyContent,
                options: [],
                range: range,
                withTemplate: "<div class=\"page-break\"></div>"
            )
        }
        
        // Also replace any bare marker text that wasn't inside a <p> tag
        bodyContent = bodyContent.replacingOccurrences(of: pageBreakMarker, with: "<div class=\"page-break\"></div>")
        
        // Clean up any remaining raw form feeds (belt-and-suspenders)
        bodyContent = bodyContent.replacingOccurrences(of: "\u{000C}", with: "<div class=\"page-break\"></div>")
        
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
        
        // Convert <br> to XHTML self-closing form (EPUB requires valid XHTML)
        bodyContent = bodyContent.replacingOccurrences(of: "<br>", with: "<br/>")
        
        // Strip inline line-height from style attributes — iOS converter adds these
        // and they override our CSS, causing double-spacing on Kindle
        if let lhInlineRegex = try? NSRegularExpression(pattern: "line-height\\s*:\\s*[^;\"]+;?", options: []) {
            let range = NSRange(bodyContent.startIndex..., in: bodyContent)
            bodyContent = lhInlineRegex.stringByReplacingMatches(in: bodyContent, options: [], range: range, withTemplate: "")
        }
        
        // Clean up any multiple spaces that may have been created
        while bodyContent.contains("  ") {
            bodyContent = bodyContent.replacingOccurrences(of: "  ", with: " ")
        }
        
        // Convert heading-style paragraphs to semantic <h1>–<h6> and extract TOC
        let (processedBody, tocEntries) = convertHeadingsAndBuildTOC(bodyHTML: bodyContent, css: css)
        bodyContent = processedBody
        
        #if DEBUG
        print("📖 EPUB: Extracted \(tocEntries.count) TOC entries from headings")
        for entry in tocEntries.prefix(10) {
            print("   h\(entry.level): \(entry.title)")
        }
        #endif
        
        let contentHTML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
        <head>
            <meta charset="UTF-8"/>
            <title>\(escapeXML(title))</title>
            <link rel="stylesheet" type="text/css" href="style.css"/>
        </head>
        <body>
        \(bodyContent)
        </body>
        </html>
        """
        
        let contentURL = oebpsDir.appendingPathComponent("content.html")
        try contentHTML.write(to: contentURL, atomically: true, encoding: .utf8)
        return tocEntries
    }
    
    /// Create OEBPS/style.css
    private static func createStyleCSS(in directory: URL, customCSS: String? = nil, isPoetry: Bool = false) throws {
        let oebpsDir = directory.appendingPathComponent("OEBPS")
        
        var styleCSS = ""
        
        // Add custom CSS first (iOS-generated styles with namespacing)
        if var customCSS = customCSS, !customCSS.isEmpty {
            // Strip line-height from iOS-generated styles — let our base CSS control spacing
            // iOS converter emits values like "line-height: 1.80" which cause double-spacing on Kindle
            if let lhRegex = try? NSRegularExpression(pattern: "line-height\\s*:\\s*[^;]+;", options: []) {
                let range = NSRange(customCSS.startIndex..., in: customCSS)
                customCSS = lhRegex.stringByReplacingMatches(in: customCSS, options: [], range: range, withTemplate: "")
            }
            // Broaden iOS selectors like "p.p2" to also match heading tags "h1.p2, h2.p2, ..."
            // After heading conversion, <p class="p2"> becomes <h2 class="p2"> but the iOS CSS
            // rule "p.p2 { font: bold 22px ... }" won't match. Add ".p2" (class-only) variants.
            if let pClassRegex = try? NSRegularExpression(pattern: "p\\.(p\\d+)\\s*\\{", options: []) {
                let range = NSRange(customCSS.startIndex..., in: customCSS)
                let matches = pClassRegex.matches(in: customCSS, range: range)
                // Process in reverse so ranges stay valid
                for match in matches.reversed() {
                    guard let fullRange = Range(match.range, in: customCSS),
                          let classRange = Range(match.range(at: 1), in: customCSS) else { continue }
                    let className = String(customCSS[classRange])
                    // Replace "p.p2 {" with "p.p2, h1.p2, h2.p2, h3.p2, h4.p2 {"
                    let broadened = "p.\(className), h1.\(className), h2.\(className), h3.\(className), h4.\(className) {"
                    customCSS.replaceSubrange(fullRange, with: broadened)
                }
            }
            styleCSS += "/* iOS-generated styles */\n"
            styleCSS += customCSS
            styleCSS += "\n\n"
        }
        
        // Add our custom CSS
        styleCSS += """
        /* Base document styles */
        body {
            font-family: Georgia, serif;
            font-size: 1em;
            line-height: 1.5;
            margin: 1em;
            padding: 0;
            text-align: justify;
        }
        
        h1, h2, h3, h4, h5, h6 {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin-top: 1.5em;
            margin-bottom: 0.5em;
            /* !important overrides iOS CSS font shorthand which implicitly resets font-weight */
            font-weight: bold !important;
            text-align: left;
        }
        
        h1 {
            font-size: 2em;
            margin-top: 0;
        }
        
        h2 {
            font-size: 1.5em;
        }
        
        /* Force page break before each heading (except the very first) for file separation */
        h1, h2, h3, h4 {
            page-break-before: always;
            break-before: page;
        }
        /* Suppress break only on the genuinely first element in <body> */
        body > :first-child {
            page-break-before: auto;
            break-before: auto;
        }
        
        p {
            margin: 0;
            padding: 0;
            text-indent: 1.5em;
        }
        
        /* First paragraph after a heading or page break: no indent */
        h1 + p, h2 + p, h3 + p, h4 + p, h5 + p, h6 + p,
        .page-break + p {
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
        
        /* Page break support — a zero-height div that triggers a page break after it */
        .page-break {
            page-break-after: always;
            break-after: page;
            height: 0;
            margin: 0;
            padding: 0;
        }
        """
        
        // Poetry projects: remove paragraph indent and spacing so each line
        // sits directly under the previous one (lines end with paragraph breaks
        // but should render as verse lines, not spaced-out paragraphs)
        if isPoetry {
            styleCSS += """
            
            /* Poetry overrides — verse lines are separate <p> elements */
            p {
                text-indent: 0;
                margin: 0;
                padding: 0;
            }
            body {
                text-align: left;
            }
            """
        }
        
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
    
    /// Create OEBPS/cover.html (cover page XHTML)
    private static func createCoverPage(in directory: URL, title: String) throws {
        let oebpsDir = directory.appendingPathComponent("OEBPS")
        
        let coverHTML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
        <head>
            <meta charset="UTF-8"/>
            <title>\(escapeXML(title))</title>
            <style type="text/css">
                body { margin: 0; padding: 0; text-align: center; }
                div.cover { width: 100%; height: 100%; text-align: center; }
                img { max-width: 100%; max-height: 100%; }
            </style>
        </head>
        <body>
            <div class="cover">
                <img src="images/cover.jpg" alt="\(escapeXML(title))" />
            </div>
        </body>
        </html>
        """
        
        let coverURL = oebpsDir.appendingPathComponent("cover.html")
        try coverHTML.write(to: coverURL, atomically: true, encoding: .utf8)
    }
    
    /// Save cover image as JPEG in OEBPS/images/
    private static func saveCoverImage(in directory: URL, imageData: Data) throws {
        let oebpsDir = directory.appendingPathComponent("OEBPS")
        let imagesDir = oebpsDir.appendingPathComponent("images")
        try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        
        // Convert to JPEG for maximum e-reader compatibility
        var jpegData: Data
        if let uiImage = UIImage(data: imageData) {
            jpegData = uiImage.jpegData(compressionQuality: 0.9) ?? imageData
        } else {
            jpegData = imageData
        }
        
        let coverURL = imagesDir.appendingPathComponent("cover.jpg")
        try jpegData.write(to: coverURL)
    }
    
    /// Create OEBPS/nav.xhtml (EPUB 3 navigation document - REQUIRED)
    private static func createNavigationDocument(in directory: URL, title: String, hasCover: Bool, entries: [TOCEntry] = []) throws {
        let oebpsDir = directory.appendingPathComponent("OEBPS")
        
        var navItems = ""
        if hasCover {
            navItems += "\n                <li><a href=\"cover.html\">Cover</a></li>"
        }
        
        if entries.isEmpty {
            navItems += "\n                <li><a href=\"content.html\">\(escapeXML(title))</a></li>"
        } else {
            for entry in entries {
                navItems += "\n                <li><a href=\"content.html#\(entry.id)\">\(escapeXML(entry.title))</a></li>"
            }
        }
        
        let navXHTML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
        <head>
            <meta charset="UTF-8"/>
            <title>Table of Contents</title>
        </head>
        <body>
            <nav epub:type="toc" id="toc">
                <h1>Table of Contents</h1>
                <ol>\(navItems)
                </ol>
            </nav>
        </body>
        </html>
        """
        
        let navURL = oebpsDir.appendingPathComponent("nav.xhtml")
        try navXHTML.write(to: navURL, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Heading Detection & TOC Extraction
    
    /// Parse iOS-generated CSS to identify paragraph classes that represent headings.
    /// Returns a mapping of className → heading level (1–6).
    ///
    /// The iOS `NSAttributedString` HTML converter outputs paragraph styles as
    /// numbered CSS classes (`.p1`, `.p2`, …) with `font:` shorthand.  Heading
    /// styles have a significantly larger font-size than body text.
    private static func detectHeadingClasses(from css: String?) -> [String: Int] {
        guard let css = css else { return [:] }
        
        // Match  p.pN { ... }  rules
        let rulePattern = "p\\.(p\\d+)\\s*\\{([^}]+)\\}"
        guard let ruleRegex = try? NSRegularExpression(pattern: rulePattern) else { return [:] }
        
        var classFontSizes: [(className: String, fontSize: Double, isBold: Bool)] = []
        let cssRange = NSRange(css.startIndex..., in: css)
        
        for match in ruleRegex.matches(in: css, range: cssRange) {
            guard let classRange = Range(match.range(at: 1), in: css),
                  let bodyRange  = Range(match.range(at: 2), in: css) else { continue }
            
            let className = String(css[classRange])
            let body      = String(css[bodyRange])
            
            // Extract font-size from  font: [bold] SIZEpx  or  font-size: SIZEpx
            // The regex must skip optional keywords (bold, italic, normal) that appear
            // before the numeric size in a CSS font shorthand.
            let sizePattern = "font(?:-size)?:\\s*(?:[a-zA-Z-]+\\s+)*(\\d+\\.?\\d*)px"
            guard let sizeRegex = try? NSRegularExpression(pattern: sizePattern),
                  let sizeMatch = sizeRegex.firstMatch(in: body, range: NSRange(body.startIndex..., in: body)),
                  let sizeRange = Range(sizeMatch.range(at: 1), in: body),
                  let fontSize  = Double(body[sizeRange]) else { continue }
            
            let bodyLower = body.lowercased()
            let isBold = bodyLower.contains("font-weight: bold") || bodyLower.contains("font-weight:bold")
                      || bodyLower.contains("bold")  // catches font shorthand "font: bold 22px" and family names like ".AppleSystemUIFontBold"
            
            classFontSizes.append((className, fontSize, isBold))
        }
        
        guard classFontSizes.count >= 2 else { return [:] }
        
        // Determine body text size as the most-common font-size
        let sizeCounts = Dictionary(grouping: classFontSizes.map(\.fontSize), by: { $0 })
            .mapValues(\.count)
        let bodySize = sizeCounts.max(by: { $0.value < $1.value })?.key
                     ?? classFontSizes.map(\.fontSize).min()
                     ?? 12.0
        
        // Heading = font-size > body × 1.25  (catches Title2 at 22px vs body 12–14px)
        let headingThreshold = bodySize * 1.25
        let headingCandidates = classFontSizes
            .filter { $0.fontSize >= headingThreshold }
            .sorted { $0.fontSize > $1.fontSize }
        
        guard !headingCandidates.isEmpty else { return [:] }
        
        // Assign heading levels:  largest → h1, next distinct size → h2, …
        var result: [String: Int] = [:]
        var currentLevel = 1
        var lastSize: Double?
        
        for candidate in headingCandidates {
            if let last = lastSize, candidate.fontSize < last - 0.5 {
                currentLevel += 1
            }
            result[candidate.className] = min(currentLevel, 6)
            lastSize = candidate.fontSize
            
            #if DEBUG
            print("📖 EPUB heading class: .\(candidate.className) → h\(min(currentLevel, 6))  (font-size: \(candidate.fontSize)px, bold: \(candidate.isBold))")
            #endif
        }
        
        return result
    }
    
    /// Convert heading-style `<p class="pN">` elements to semantic `<hX>` tags
    /// and extract a flat list of TOC entries with anchor IDs.
    private static func convertHeadingsAndBuildTOC(
        bodyHTML: String,
        css: String?
    ) -> (html: String, tocEntries: [TOCEntry]) {
        
        let headingClasses = detectHeadingClasses(from: css)
        guard !headingClasses.isEmpty else { return (bodyHTML, []) }
        
        var result = bodyHTML
        var tocEntries: [TOCEntry] = []
        var headingIndex = 0
        
        // Process each heading class, sorted by level (h1 first) then className
        let sortedClasses = headingClasses.sorted { a, b in
            if a.value != b.value { return a.value < b.value }
            return a.key < b.key
        }
        
        for (className, level) in sortedClasses {
            // Match <p class="className">…</p>  (content may contain nested <span> tags)
            let escapedClass = NSRegularExpression.escapedPattern(for: className)
            let pattern = "<p class=\"\(escapedClass)\">(.*?)</p>"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else { continue }
            
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: nsRange)
            
            // Replace in reverse order so ranges stay valid
            for match in matches.reversed() {
                guard let fullRange    = Range(match.range, in: result),
                      let contentRange = Range(match.range(at: 1), in: result) else { continue }
                
                let innerHTML = String(result[contentRange])
                
                // Strip tags for plain-text TOC title
                let plainText = innerHTML
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                guard !plainText.isEmpty else { continue }
                
                let tocId = "toc-\(headingIndex)"
                headingIndex += 1
                
                let hTag = "h\(min(level, 6))"
                // Preserve the original CSS class so iOS font-weight/size styles still apply
                let replacement = "<\(hTag) id=\"\(tocId)\" class=\"\(className)\">\(innerHTML)</\(hTag)>"
                result.replaceSubrange(fullRange, with: replacement)
                
                // Insert at beginning since we're iterating in reverse
                tocEntries.insert(TOCEntry(id: tocId, title: plainText, level: level), at: 0)
            }
        }
        
        return (result, tocEntries)
    }
    
    // MARK: - ZIP Utilities
    
    /// Create an EPUB-compliant ZIP archive from a directory
    /// EPUB requires: mimetype file FIRST, UNCOMPRESSED, with no extra field in its local header
    private static func createEPUBZip(from directory: URL) throws -> Data {
        let fm = FileManager.default
        
        // Enumerate all files, putting mimetype first
        var relativePaths: [String] = ["mimetype"]
        
        // Add META-INF files
        let metaInfDir = directory.appendingPathComponent("META-INF")
        if let enumerator = fm.enumerator(at: metaInfDir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            while let url = enumerator.nextObject() as? URL {
                if (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true {
                    let rel = url.path.replacingOccurrences(of: directory.path + "/", with: "")
                    relativePaths.append(rel)
                }
            }
        }
        
        // Add OEBPS files
        let oebpsDir = directory.appendingPathComponent("OEBPS")
        if let enumerator = fm.enumerator(at: oebpsDir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            while let url = enumerator.nextObject() as? URL {
                if (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true {
                    let rel = url.path.replacingOccurrences(of: directory.path + "/", with: "")
                    relativePaths.append(rel)
                }
            }
        }
        
        var zipData = Data()
        var centralDir = Data()
        var entryCount: UInt16 = 0
        
        for path in relativePaths {
            let fileURL = directory.appendingPathComponent(path)
            let fileData = try Data(contentsOf: fileURL)
            let isMimetype = (path == "mimetype")
            
            // CRC32
            let crc = crc32Checksum(fileData)
            
            // Compress non-mimetype files using DEFLATE
            var compressedData: Data
            var method: UInt16 = 0 // stored
            
            if !isMimetype, let deflated = deflateData(fileData), deflated.count < fileData.count {
                compressedData = deflated
                method = 8 // deflated
            } else {
                compressedData = fileData
            }
            
            let nameData = Data(path.utf8)
            let offset = UInt32(zipData.count)
            
            // Local file header (30 bytes + filename)
            zipData.append(contentsOf: [0x50, 0x4B, 0x03, 0x04]) // PK\x03\x04
            zipData.appendLE(UInt16(20)) // version needed to extract
            zipData.appendLE(UInt16(0))  // general purpose bit flag
            zipData.appendLE(method)
            zipData.appendLE(UInt16(0))  // last mod file time
            zipData.appendLE(UInt16(0))  // last mod file date
            zipData.appendLE(crc)
            zipData.appendLE(UInt32(compressedData.count))
            zipData.appendLE(UInt32(fileData.count))
            zipData.appendLE(UInt16(nameData.count))
            zipData.appendLE(UInt16(0))  // extra field length (MUST be 0 for mimetype)
            zipData.append(nameData)
            zipData.append(compressedData)
            
            // Central directory entry (46 bytes + filename)
            centralDir.append(contentsOf: [0x50, 0x4B, 0x01, 0x02]) // PK\x01\x02
            centralDir.appendLE(UInt16(20)) // version made by
            centralDir.appendLE(UInt16(20)) // version needed
            centralDir.appendLE(UInt16(0))  // general purpose bit flag
            centralDir.appendLE(method)
            centralDir.appendLE(UInt16(0))  // last mod file time
            centralDir.appendLE(UInt16(0))  // last mod file date
            centralDir.appendLE(crc)
            centralDir.appendLE(UInt32(compressedData.count))
            centralDir.appendLE(UInt32(fileData.count))
            centralDir.appendLE(UInt16(nameData.count))
            centralDir.appendLE(UInt16(0))  // extra field length
            centralDir.appendLE(UInt16(0))  // file comment length
            centralDir.appendLE(UInt16(0))  // disk number start
            centralDir.appendLE(UInt16(0))  // internal file attributes
            centralDir.appendLE(UInt32(0))  // external file attributes
            centralDir.appendLE(offset)     // relative offset of local header
            centralDir.append(nameData)
            
            entryCount += 1
        }
        
        let cdOffset = UInt32(zipData.count)
        zipData.append(centralDir)
        
        // End of central directory record
        zipData.append(contentsOf: [0x50, 0x4B, 0x05, 0x06]) // PK\x05\x06
        zipData.appendLE(UInt16(0))  // number of this disk
        zipData.appendLE(UInt16(0))  // disk where central directory starts
        zipData.appendLE(entryCount) // entries on this disk
        zipData.appendLE(entryCount) // total entries
        zipData.appendLE(UInt32(centralDir.count)) // size of central directory
        zipData.appendLE(cdOffset)   // offset of start of central directory
        zipData.appendLE(UInt16(0))  // comment length
        
        return zipData
    }
    
    /// Calculate CRC-32 checksum (standard polynomial 0xEDB88320)
    private static func crc32Checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc >> 1) ^ (crc & 1 != 0 ? 0xEDB88320 : 0)
            }
        }
        return crc ^ 0xFFFFFFFF
    }
    
    /// Deflate data using raw DEFLATE compression (no zlib headers)
    private static func deflateData(_ input: Data) -> Data? {
        guard !input.isEmpty else { return Data() }
        let bufferSize = max(input.count + 512, 128)
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }
        
        let compressedSize = input.withUnsafeBytes { sourceBuffer -> Int in
            guard let sourcePtr = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
            return compression_encode_buffer(
                destinationBuffer, bufferSize,
                sourcePtr, input.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
        
        guard compressedSize > 0 else { return nil }
        return Data(bytes: destinationBuffer, count: compressedSize)
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

// MARK: - Data Extension for ZIP Binary Writing

private extension Data {
    /// Append a UInt16 in little-endian byte order
    mutating func appendLE(_ value: UInt16) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
    
    /// Append a UInt32 in little-endian byte order
    mutating func appendLE(_ value: UInt32) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
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
