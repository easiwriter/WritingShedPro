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
        print("   EPUB size: \(epub.count) bytes")
        #endif
        
        return epub
    }
    
    // MARK: - EPUB Package Creation
    
    /// Create an EPUB package (ZIP file with specific structure)
    private static func createEPUBPackage(
        htmlContent: String,
        title: String,
        author: String?,
        language: String
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
        try createContentOPF(in: tempDir, title: title, author: author, language: language)
        try createTableOfContentsNCX(in: tempDir, title: title)
        try createContentHTML(in: tempDir, html: htmlContent, title: title)
        try createStyleCSS(in: tempDir)
        
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
    private static func createContentOPF(in directory: URL, title: String, author: String?, language: String) throws {
        let oebpsDir = directory.appendingPathComponent("OEBPS")
        try FileManager.default.createDirectory(at: oebpsDir, withIntermediateDirectories: true)
        
        let uuid = UUID().uuidString
        let date = ISO8601DateFormatter().string(from: Date())
        let authorMetadata = author.map { "<dc:creator>\($0)</dc:creator>" } ?? ""
        
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
                <item id="style" href="style.css" media-type="text/css"/>
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
    }
    
    /// Create OEBPS/style.css
    private static func createStyleCSS(in directory: URL) throws {
        let oebpsDir = directory.appendingPathComponent("OEBPS")
        
        let styleCSS = """
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
            margin: 1em auto;
        }
        
        strong {
            font-weight: bold;
        }
        
        em {
            font-style: italic;
        }
        """
        
        let styleURL = oebpsDir.appendingPathComponent("style.css")
        try styleCSS.write(to: styleURL, atomically: true, encoding: .utf8)
    }
    
    // MARK: - ZIP Utilities
    
    /// Create a ZIP archive from a directory
    private static func zipDirectory(_ directory: URL) throws -> Data {
        let zipURL = directory.appendingPathExtension("zip")
        
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
