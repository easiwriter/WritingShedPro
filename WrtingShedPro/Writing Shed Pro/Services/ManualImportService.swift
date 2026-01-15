//
//  ManualImportService.swift
//  Writing Shed Pro
//
//  Feature 027: WSP Manual
//  Handles importing the bundled Manual Project into the user's projects
//

import Foundation
import SwiftData

/// Service for importing the bundled WSP Manual project
@MainActor
final class ManualImportService {
    
    enum ManualImportError: LocalizedError {
        case manualNotFound
        case importFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .manualNotFound:
                return "The Manual Project could not be found in app resources."
            case .importFailed(let reason):
                return "Failed to import Manual Project: \(reason)"
            }
        }
    }
    
    /// Name of the bundled manual project file (without extension)
    private static let manualProjectFileName = "Manual Project"
    
    /// File extension for WSP project files
    private static let wspExtension = "wsp"
    
    /// Imports the bundled Manual Project into the user's projects
    /// - Parameter modelContext: The SwiftData model context
    /// - Returns: The imported Project, or throws an error
    @discardableResult
    static func importManualProject(modelContext: ModelContext) throws -> Project {
        // TODO: Implement manual import
        // 1. Locate "Manual Project.wsp" in app bundle Resources
        // 2. Use existing WSP import functionality to import the project
        // 3. Return the imported project
        
        guard let manualURL = Bundle.main.url(
            forResource: manualProjectFileName,
            withExtension: wspExtension
        ) else {
            throw ManualImportError.manualNotFound
        }
        
        // Stub: For now, just verify the file exists
        // When implemented, this will call the existing JSONImportService or similar
        
        // Placeholder - throw not found until properly implemented
        throw ManualImportError.importFailed("Import functionality not yet implemented")
    }
    
    /// Checks if the Manual Project is already imported
    /// - Parameter modelContext: The SwiftData model context
    /// - Returns: True if a project named "Manual Project" exists
    static func isManualProjectImported(modelContext: ModelContext) -> Bool {
        // TODO: Check if a project with the manual's identifier exists
        // Could check by name or by a special marker/flag
        
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.name == "Manual Project" }
        )
        
        do {
            let count = try modelContext.fetchCount(descriptor)
            return count > 0
        } catch {
            return false
        }
    }
}
