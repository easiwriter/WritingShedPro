//
//  HTMLExportService.swift
//  Writing Shed Pro
//
//  Created on 8 December 2025.
//

import Foundation
import UIKit

/// Service for exporting content to HTML format
class HTMLExportService {
    
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
                        img {
                            max-width: 100%;
                            height: auto;
                            display: block;
                            margin: 1em 0;
                        }
                        @media print {
                            body {
                                max-width: none;
                                padding: 0;
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
