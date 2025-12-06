//
//  WordDocumentService.swift
//  Writing Shed Pro
//
//  Created on 6 December 2025.
//

import Foundation
import UIKit

/// Service for importing and exporting Word documents (.docx)
/// Uses iOS native NSAttributedString document type support
class WordDocumentService {
    
    // MARK: - Import
    
    /// Import a Word document (.docx) file
    /// - Parameter url: URL to the .docx file
    /// - Returns: Tuple of (plain text, formatted content as RTF data, original filename)
    /// - Throws: Error if import fails
    static func importWordDocument(from url: URL) throws -> (plainText: String, rtfData: Data?, filename: String) {
        // Ensure we can access the file
        guard url.startAccessingSecurityScopedResource() else {
            throw WordDocumentError.cannotAccessFile
        }
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        // Read the .docx file as NSAttributedString
        let documentAttributes: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.docx
        ]
        
        let attributedString: NSAttributedString
        do {
            let data = try Data(contentsOf: url)
            attributedString = try NSAttributedString(
                data: data,
                options: documentAttributes,
                documentAttributes: nil
            )
        } catch {
            throw WordDocumentError.importFailed(error.localizedDescription)
        }
        
        // Extract plain text
        let plainText = attributedString.string
        
        // Convert to RTF for storage (our internal format)
        let rtfData = AttributedStringSerializer.toRTF(attributedString)
        
        // Get filename without extension
        let filename = url.deletingPathExtension().lastPathComponent
        
        #if DEBUG
        print("📄 WordDocumentService: Imported '\(filename)'")
        print("   Text length: \(plainText.count) characters")
        print("   RTF size: \(rtfData?.count ?? 0) bytes")
        print("   Has formatting: \(rtfData != nil)")
        #endif
        
        return (plainText, rtfData, filename)
    }
    
    // MARK: - Export
    
    /// Export content as a Word document (.docx)
    /// - Parameters:
    ///   - attributedString: The formatted content to export
    ///   - filename: Name for the exported file (without extension)
    /// - Returns: Data for the .docx file
    /// - Throws: Error if export fails
    static func exportToWordDocument(
        _ attributedString: NSAttributedString,
        filename: String
    ) throws -> Data {
        let documentAttributes: [NSAttributedString.DocumentAttributeKey: Any] = [
            .documentType: NSAttributedString.DocumentType.docx
        ]
        
        do {
            let range = NSRange(location: 0, length: attributedString.length)
            let docxData = try attributedString.data(
                from: range,
                documentAttributes: documentAttributes
            )
            
            #if DEBUG
            print("📤 WordDocumentService: Exported '\(filename).docx'")
            print("   File size: \(docxData.count) bytes")
            #endif
            
            return docxData
        } catch {
            throw WordDocumentError.exportFailed(error.localizedDescription)
        }
    }
    
    /// Export content as RTF (Rich Text Format)
    /// RTF can be opened by Word and other word processors
    /// - Parameters:
    ///   - attributedString: The formatted content to export
    ///   - filename: Name for the exported file (without extension)
    /// - Returns: Data for the .rtf file
    /// - Throws: Error if export fails
    static func exportToRTF(
        _ attributedString: NSAttributedString,
        filename: String
    ) throws -> Data {
        guard let rtfData = AttributedStringSerializer.toRTF(attributedString) else {
            throw WordDocumentError.exportFailed("RTF conversion failed")
        }
        
        #if DEBUG
        print("📤 WordDocumentService: Exported '\(filename).rtf'")
        print("   File size: \(rtfData.count) bytes")
        #endif
        
        return rtfData
    }
    
    // MARK: - Share Sheet Helpers
    
    /// Present share sheet to export as Word document
    /// - Parameters:
    ///   - attributedString: The content to export
    ///   - filename: Name for the file (without extension)
    ///   - from: View controller to present from
    static func shareAsWordDocument(
        _ attributedString: NSAttributedString,
        filename: String,
        from viewController: UIViewController
    ) {
        do {
            let docxData = try exportToWordDocument(attributedString, filename: filename)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(filename).docx")
            
            try docxData.write(to: tempURL)
            
            let activityVC = UIActivityViewController(
                activityItems: [tempURL],
                applicationActivities: nil
            )
            
            // For iPad - set source view
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(
                    x: viewController.view.bounds.midX,
                    y: viewController.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }
            
            viewController.present(activityVC, animated: true)
            
        } catch {
            print("❌ Failed to share Word document: \(error.localizedDescription)")
        }
    }
    
    /// Present share sheet to export as RTF
    /// - Parameters:
    ///   - attributedString: The content to export
    ///   - filename: Name for the file (without extension)
    ///   - from: View controller to present from
    static func shareAsRTF(
        _ attributedString: NSAttributedString,
        filename: String,
        from viewController: UIViewController
    ) {
        do {
            let rtfData = try exportToRTF(attributedString, filename: filename)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(filename).rtf")
            
            try rtfData.write(to: tempURL)
            
            let activityVC = UIActivityViewController(
                activityItems: [tempURL],
                applicationActivities: nil
            )
            
            // For iPad - set source view
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(
                    x: viewController.view.bounds.midX,
                    y: viewController.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }
            
            viewController.present(activityVC, animated: true)
            
        } catch {
            print("❌ Failed to share RTF: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Validation
    
    /// Check if a file is a Word document
    /// - Parameter url: URL to check
    /// - Returns: True if the file is a .docx file
    static func isWordDocument(_ url: URL) -> Bool {
        return url.pathExtension.lowercased() == "docx"
    }
    
    /// Check if a file is an RTF document
    /// - Parameter url: URL to check
    /// - Returns: True if the file is a .rtf file
    static func isRTFDocument(_ url: URL) -> Bool {
        return url.pathExtension.lowercased() == "rtf"
    }
}

// MARK: - Error Types

enum WordDocumentError: LocalizedError {
    case cannotAccessFile
    case importFailed(String)
    case exportFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .cannotAccessFile:
            return "Cannot access the file. Please check permissions."
        case .importFailed(let reason):
            return "Failed to import Word document: \(reason)"
        case .exportFailed(let reason):
            return "Failed to export Word document: \(reason)"
        }
    }
}
