//
//  ShareService.swift
//  Writing Shed Pro
//
//  Handles sharing of exported files via system share sheet
//

import Foundation
import UniformTypeIdentifiers

class ShareService {
    static let shared = ShareService()
    
    private init() {}
    
    /// Creates a shareable file from export data
    /// - Parameters:
    ///   - data: The file data to share
    ///   - filename: The desired filename
    ///   - contentType: The UTType of the file
    /// - Returns: URL to the temporary file, or nil if creation fails
    func createShareableFile(
        data: Data,
        filename: String,
        contentType: UTType
    ) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        
        // Add file extension based on content type
        let fileExtension = contentType.preferredFilenameExtension ?? "txt"
        let filenameWithExtension = filename.hasSuffix("." + fileExtension)
            ? filename
            : "\(filename).\(fileExtension)"
        
        let fileURL = tempDir.appendingPathComponent(filenameWithExtension)
        
        do {
            // Write the data to the temporary file
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            #if DEBUG
            print("❌ [ShareService] Failed to write shareable file: \(error)")
            #endif
            return nil
        }
    }
    
    /// Creates multiple shareable files for sharing
    /// - Parameters:
    ///   - items: Array of (data, filename, contentType) tuples
    /// - Returns: URLs to the temporary files, or empty array if creation fails
    func createMultipleShareableFiles(
        items: [(data: Data, filename: String, contentType: UTType)]
    ) -> [URL] {
        items.compactMap { item in
            createShareableFile(
                data: item.data,
                filename: item.filename,
                contentType: item.contentType
            )
        }
    }
    
    /// Cleans up temporary files created for sharing
    /// Note: System may clean these up automatically, but explicitly cleaning ensures cleanup
    /// - Parameter urls: URLs of files to clean up
    func cleanupTemporaryFiles(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
