//
//  GuideNavigationService.swift
//  Writing Shed Pro
//
//  Feature 035: TipKit Tips
//  FR-9: Guide link buttons — navigates to guide sections from tip "Learn More" actions
//

import SwiftUI
import SwiftData

/// Service that navigates to a specific section in the Writing Shed Pro Guide project.
///
/// When a user taps "Learn More" on a tip, this service finds the guide project,
/// locates the file matching the section identifier, and posts a notification
/// to navigate there.
@MainActor
@Observable
class GuideNavigationService {
    static let shared = GuideNavigationService()
    
    /// Notification posted when a guide section should be opened
    static let openGuideSectionNotification = Notification.Name("openGuideSection")
    
    /// The guide project name (must match UserGuideImportService)
    private let guideProjectName = "Writing Shed Pro Guide"
    
    /// Opens a guide section by finding the matching file in the guide project.
    /// - Parameters:
    ///   - sectionId: The section identifier (e.g., "42-text-formatting")
    ///   - modelContext: The SwiftData model context
    func openGuideSection(_ sectionId: String, modelContext: ModelContext) {
        // 1. Find the guide project
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.name == "Writing Shed Pro Guide" }
        )
        
        guard let guideProject = try? modelContext.fetch(descriptor).first else {
            #if DEBUG
            print("[GuideNav] Guide project not found — user may not have imported it")
            #endif
            return
        }
        
        // 2. Search all files in the guide project for one matching the section ID
        guard let guideFile = findGuideFile(sectionId: sectionId, in: guideProject) else {
            #if DEBUG
            print("[GuideNav] Guide file for section '\(sectionId)' not found")
            #endif
            return
        }
        
        // 3. Post notification with project and file info for navigation
        NotificationCenter.default.post(
            name: Self.openGuideSectionNotification,
            object: nil,
            userInfo: [
                "project": guideProject,
                "file": guideFile
            ]
        )
    }
    
    /// Checks whether the guide project is installed
    /// - Parameter modelContext: The SwiftData model context
    /// - Returns: True if the guide project exists
    func isGuideInstalled(modelContext: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.name == "Writing Shed Pro Guide" }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }
    
    /// Finds a TextFile in the guide project whose name starts with the section ID
    private func findGuideFile(sectionId: String, in project: Project) -> TextFile? {
        // Search through all folders in the project
        guard let folders = project.folders else { return nil }
        
        for folder in folders {
            if let file = searchFolder(folder, for: sectionId) {
                return file
            }
        }
        
        return nil
    }
    
    /// Recursively searches a folder and its subfolders for a file matching the section ID
    private func searchFolder(_ folder: Folder, for sectionId: String) -> TextFile? {
        // Check files in this folder
        if let files = folder.files {
            for file in files {
                if let name = file.name, name.hasPrefix(sectionId) {
                    return file
                }
            }
        }
        
        // Check subfolders
        if let subfolders = folder.subfolders {
            for subfolder in subfolders {
                if let file = searchFolder(subfolder, for: sectionId) {
                    return file
                }
            }
        }
        
        return nil
    }
}
