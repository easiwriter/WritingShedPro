//
//  UserGuideImportService.swift
//  Writing Shed Pro
//
//  Feature 027: WSP User Guide
//  Handles importing the bundled User Guide project into the user's projects
//

import Foundation
import SwiftData

/// Service for importing the bundled WSP User Guide project
@MainActor
final class UserGuideImportService {
    
    enum GuideImportError: LocalizedError {
        case guideNotFound
        case importFailed(String)
        case deleteFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .guideNotFound:
                return "The Writing Shed Pro Guide could not be found in app resources."
            case .importFailed(let reason):
                return "Failed to import guide: \(reason)"
            case .deleteFailed(let reason):
                return "Failed to replace existing guide: \(reason)"
            }
        }
    }
    
    /// Name of the bundled guide project file (without extension)
    static let guideProjectFileName = "Writing Shed Pro Guide"
    
    /// Name of the imported project as shown to user
    static let guideProjectName = "Writing Shed Pro Guide"
    
    /// File extension for WSP project files
    private static let wspExtension = "wsp"
    
    /// Imports the bundled User Guide into the user's projects
    /// - Parameters:
    ///   - modelContext: The SwiftData model context
    ///   - replaceExisting: If true, deletes existing guide first
    /// - Returns: The imported Project, or throws an error
    @discardableResult
    static func importGuide(modelContext: ModelContext, replaceExisting: Bool = false) throws -> Project {
        // Delete existing guide if requested
        if replaceExisting {
            try deleteExistingGuide(modelContext: modelContext)
        }
        
        // Locate the guide file in app bundle Resources
        guard let guideURL = Bundle.main.url(
            forResource: guideProjectFileName,
            withExtension: wspExtension
        ) else {
            throw GuideImportError.guideNotFound
        }
        
        // Use JSONImportService to import the WSP file
        // Use generateNewUUIDs: true to avoid CloudKit conflicts with original project
        let errorHandler = ImportErrorHandler()
        let importService = JSONImportService(
            modelContext: modelContext,
            errorHandler: errorHandler,
            generateNewUUIDs: true
        )
        
        do {
            let project = try importService.importFromJSON(fileURL: guideURL)
            
            // Ensure the project has the correct name
            project.name = guideProjectName
            
            // Fix content type for markdown files exported before contentTypeRaw was added.
            // The guide's files were originally created as markdown but the WSP export
            // didn't preserve contentTypeRaw, so they import as richText. Detect and fix.
            fixMarkdownContentTypes(in: project)
            
            try modelContext.save()
            
            #if DEBUG
            print("[UserGuideImport] Successfully imported guide: \(project.name ?? "unnamed")")
            if !errorHandler.warnings.isEmpty {
                print("[UserGuideImport] Warnings: \(errorHandler.warnings)")
            }
            #endif
            
            return project
        } catch {
            throw GuideImportError.importFailed(error.localizedDescription)
        }
    }
    
    /// Checks if the User Guide is already imported
    /// - Parameter modelContext: The SwiftData model context
    /// - Returns: True if a project named "Writing Shed Pro Guide" exists
    static func isGuideImported(modelContext: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.name == "Writing Shed Pro Guide" }
        )
        
        do {
            let count = try modelContext.fetchCount(descriptor)
            return count > 0
        } catch {
            return false
        }
    }
    
    /// Deletes the existing User Guide project
    /// - Parameter modelContext: The SwiftData model context
    private static func deleteExistingGuide(modelContext: ModelContext) throws {
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.name == "Writing Shed Pro Guide" }
        )
        
        do {
            let existingGuides = try modelContext.fetch(descriptor)
            for guide in existingGuides {
                modelContext.delete(guide)
            }
            try modelContext.save()
        } catch {
            throw GuideImportError.deleteFailed(error.localizedDescription)
        }
    }
    
    /// Detect and fix markdown files that lost their contentType during WSP export/import.
    /// Checks each file's plain text content for markdown syntax patterns.
    private static func fixMarkdownContentTypes(in project: Project) {
        guard let folders = project.folders else { return }
        
        func fixFilesInFolder(_ folder: Folder) {
            for file in folder.textFiles ?? [] {
                // Skip files that already have the correct type
                guard file.contentTypeRaw == "richText" || file.contentTypeRaw == nil else { continue }
                
                // Check the plain text content for markdown indicators
                let content = file.currentVersion?.content ?? ""
                if looksLikeMarkdown(content) {
                    file.contentTypeRaw = "markdown"
                    // Clear RTF formatted content — markdown files use plain text
                    if let version = file.currentVersion {
                        version.formattedContent = nil
                    }
                    #if DEBUG
                    print("[UserGuideImport] Fixed content type → markdown: \(file.name)")
                    #endif
                }
            }
            for subfolder in folder.subfolders ?? [] {
                fixFilesInFolder(subfolder)
            }
        }
        
        for folder in folders {
            fixFilesInFolder(folder)
        }
    }
    
    /// Heuristic: does this plain text content look like markdown?
    /// Returns true if it contains markdown heading syntax (lines starting with #).
    private static func looksLikeMarkdown(_ content: String) -> Bool {
        guard !content.isEmpty else { return false }
        let lines = content.components(separatedBy: .newlines)
        let headingCount = lines.filter { $0.hasPrefix("# ") || $0.hasPrefix("## ") || $0.hasPrefix("### ") }.count
        return headingCount >= 1
    }
}
