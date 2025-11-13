//
//  LegacyImportEngine.swift
//  Writing Shed Pro
//
//  Created on 12 November 2025.
//  Feature 009: Database Import
//

import Foundation
import CoreData
import SwiftData

/// Orchestrates the complete import process
class LegacyImportEngine {
    
    // MARK: - Properties
    
    private let legacyService: LegacyDatabaseService
    private let mapper: DataMapper
    private let errorHandler: ImportErrorHandler
    private let progressTracker: ImportProgressTracker
    
    // MARK: - Caching for Relationships
    
    private var textFileMap: [NSManagedObject: TextFile] = [:]
    private var versionMap: [NSManagedObject: Version] = [:]
    private var collectionMap: [NSManagedObject: Submission] = [:]
    
    // MARK: - Initialization
    
    init(
        legacyService: LegacyDatabaseService,
        mapper: DataMapper,
        errorHandler: ImportErrorHandler,
        progressTracker: ImportProgressTracker
    ) {
        self.legacyService = legacyService
        self.mapper = mapper
        self.errorHandler = errorHandler
        self.progressTracker = progressTracker
    }
    
    // MARK: - Main Import Orchestration
    
    /// Execute complete import process
    /// - Parameters:
    ///   - modelContext: SwiftData ModelContext for saving
    /// - Throws: ImportError if fatal error occurs
    func executeImport(modelContext: ModelContext) throws {
        progressTracker.reset()
        errorHandler.reset()
        
        progressTracker.setPhase("Connecting to legacy database...")
        try legacyService.connect()
        
        progressTracker.setPhase("Loading projects...")
        let legacyProjects = try legacyService.fetchProjects()
        progressTracker.setTotal(legacyProjects.count)
        print("[LegacyImportEngine] Fetched \(legacyProjects.count) projects from legacy database")
        
        guard !legacyProjects.isEmpty else {
            progressTracker.setPhase("No projects found in legacy database")
            progressTracker.markComplete()
            return
        }
        
        // Import each project with batch saves to prevent memory issues
        let batchSize = 5
        for (index, legacyProjectData) in legacyProjects.enumerated() {
            print("[LegacyImportEngine] Processing project \(index + 1)/\(legacyProjects.count): '\(legacyProjectData.name)'")
            do {
                try importProject(legacyProjectData, modelContext: modelContext)
                progressTracker.incrementProcessed()
                
                // Batch save every N projects to prevent memory accumulation
                if (index + 1) % batchSize == 0 {
                    try modelContext.save()
                    clearCaches()
                }
            } catch {
                errorHandler.addError("Failed to import project: \(error.localizedDescription)")
            }
        }
        
        // Final save for remaining projects
        progressTracker.setPhase("Saving to database...")
        do {
            try modelContext.save()
            clearCaches()
            progressTracker.markComplete()
        } catch {
            errorHandler.addError("Failed to save imported data: \(error.localizedDescription)")
            try errorHandler.rollback(on: modelContext)
            throw error
        }
    }
    
    /// Clear all cached references to prevent memory issues
    private func clearCaches() {
        textFileMap.removeAll()
        versionMap.removeAll()
        collectionMap.removeAll()
    }
    
    // MARK: - Project Import
    
    /// Import a single project and all its data
    private func importProject(
        _ legacyProjectData: LegacyProjectData,
        modelContext: ModelContext
    ) throws {
        let projectName = legacyProjectData.name
        progressTracker.setCurrentItem(projectName)
        
        // Check if project already exists (by name and creation date)
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { project in
                project.name == projectName
            }
        )
        
        if let existingProjects = try? modelContext.fetch(descriptor), !existingProjects.isEmpty {
            print("[LegacyImportEngine] Project '\(projectName)' already exists, skipping")
            return
        }
        
        // Map project
        let newProject: Project
        do {
            newProject = try mapper.mapProject(legacyProjectData)
            newProject.status = .legacy // Mark as legacy import for development re-import
            modelContext.insert(newProject)
            print("[LegacyImportEngine] Imported project: '\(projectName)' (status: legacy)")
        } catch {
            print("[LegacyImportEngine] Failed to map project '\(projectName)': \(error)")
            throw error
        }
        
        // Get the NSManagedObject for this project to fetch related entities
        guard let legacyProject = try legacyService.getProject(byObjectID: legacyProjectData.objectID) else {
            print("[LegacyImportEngine] Warning: Could not retrieve NSManagedObject for project '\(projectName)', skipping content import")
            return
        }
        
        // Create folder structure
        try importFolderStructure(
            legacyProject: legacyProject,
            newProject: newProject,
            modelContext: modelContext
        )
        
        // Import texts and versions
        try importTextsAndVersions(
            legacyProject: legacyProject,
            newProject: newProject,
            modelContext: modelContext
        )
        
        // Import collections
        // try importCollections(
        //     legacyProjectData: legacyProjectData,
        //     newProject: newProject,
        //     modelContext: modelContext
        // )
        
        // Import scenes (if project type supports it)
        // if isNovelOrScriptProject(legacyProjectData) {
        //     try importSceneComponents(
        //         legacyProjectData: legacyProjectData,
        //         newProject: newProject,
        //         modelContext: modelContext
        //     )
        // }
    }
    
    // MARK: - Folder Structure Creation
    
    /// Map legacy groupName values to standard folder system
    /// The project already has standard folders from ProjectTemplateService.createDefaultFolders()
    /// We just need to find the right folder for each text based on its groupName
    private func importFolderStructure(
        legacyProject: NSManagedObject,
        newProject: Project,
        modelContext: ModelContext
    ) throws {
        // Standard folders should already exist from project creation
        // No need to create additional folders - just use the existing ones
        // The mapping will happen in importTextsAndVersions when assigning parentFolder
        
        // If for some reason standard folders don't exist, create them now
        if newProject.folders == nil || newProject.folders?.isEmpty == true {
            print("[LegacyImportEngine] Warning: Project has no folders, creating standard folders")
            ProjectTemplateService.createDefaultFolders(for: newProject, in: modelContext)
        }
    }
    
    // MARK: - Text and Version Import
    
    /// Map legacy groupName to standard folder name
    private func mapLegacyFolderName(_ legacyGroupName: String) -> String {
        // Map legacy Writing Shed folder names to new standard folder names
        switch legacyGroupName.lowercased() {
        case "draft":
            return "Draft"
        case "ready":
            return "Ready"
        case "set aside":
            return "Set Aside"
        case "accepted", "published":
            return "Published"  // Accepted was renamed to Published
        case "collection", "collections":
            return "Collections"
        case "submissions", "submitted":
            return "Submissions"
        case "research":
            return "Research"
        case "trash":
            return "Trash"
        default:
            // If unrecognized, default to Draft
            return "Draft"
        }
    }
    
    /// Import texts and versions for a project
    private func importTextsAndVersions(
        legacyProject: NSManagedObject,
        newProject: Project,
        modelContext: ModelContext
    ) throws {
        let legacyTexts = try legacyService.fetchTexts(for: legacyProject)
        
        for legacyText in legacyTexts {
            do {
                // Get legacy groupName and map to standard folder
                let legacyGroupName = legacyText.value(forKey: "groupName") as? String ?? ""
                let standardFolderName = legacyGroupName.isEmpty ? "Draft" : mapLegacyFolderName(legacyGroupName)
                
                // Find the standard folder (should always exist)
                guard let parentFolder = newProject.folders?.first(where: { $0.name == standardFolderName }) else {
                    print("[LegacyImportEngine] Warning: Standard folder '\(standardFolderName)' not found, skipping text")
                    continue
                }
                
                // Map text file
                let newTextFile = try mapper.mapTextFile(legacyText, parentFolder: parentFolder)
                modelContext.insert(newTextFile)
                textFileMap[legacyText] = newTextFile
                
                // Import versions
                let legacyVersions = try legacyService.fetchVersions(for: legacyText)
                for (index, legacyVersion) in legacyVersions.enumerated() {
                    let newVersion = try mapper.mapVersion(
                        legacyVersion,
                        file: newTextFile,
                        versionNumber: index + 1
                    )
                    modelContext.insert(newVersion)
                    versionMap[legacyVersion] = newVersion
                    
                    if newTextFile.versions == nil {
                        newTextFile.versions = []
                    }
                    newTextFile.versions?.append(newVersion)
                }
            } catch {
                errorHandler.addWarning("Failed to import text: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Collection Import
    
    /// Import collections and their submitted files
    private func importCollections(
        legacyProject: NSManagedObject,
        newProject: Project,
        modelContext: ModelContext
    ) throws {
        let legacyCollections = try legacyService.fetchCollections(for: legacyProject)
        
        for legacyCollection in legacyCollections {
            do {
                // Map collection to Submission
                let newSubmission = try mapper.mapCollection(legacyCollection, project: newProject)
                modelContext.insert(newSubmission)
                collectionMap[legacyCollection] = newSubmission
                
                // NOTE: Collection submissions (WS_CollectionSubmission_Entity) are not yet implemented
                // Collections have:
                // - collectionSubmissions relationship → WS_CollectionSubmission_Entity
                // - textCollection relationship → WS_TextCollection_Entity
                // - texts relationship → WS_Text_Entity
                // These would need separate mapping logic
                
                // TODO: Implement collection submission mapping in Phase 2
            } catch {
                errorHandler.addWarning("Failed to import collection: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Scene Component Import
    
    /// Import scenes, characters, and locations
    private func importSceneComponents(
        legacyProject: NSManagedObject,
        newProject: Project,
        modelContext: ModelContext
    ) throws {
        // Create auto-folders for scenes, characters, locations
        let scenesFolder = Folder(name: "\(newProject.name ?? "Project")/Scenes", project: newProject)
        let charactersFolder = Folder(name: "\(newProject.name ?? "Project")/Characters", project: newProject)
        let locationsFolder = Folder(name: "\(newProject.name ?? "Project")/Locations", project: newProject)
        
        newProject.folders?.append(scenesFolder)
        newProject.folders?.append(charactersFolder)
        newProject.folders?.append(locationsFolder)
        
        modelContext.insert(scenesFolder)
        modelContext.insert(charactersFolder)
        modelContext.insert(locationsFolder)
        
        // Import scenes
        let legacyScenes = try legacyService.fetchScenes(for: legacyProject)
        for legacyScene in legacyScenes {
            do {
                let newScene = try mapper.mapScene(legacyScene, parentFolder: scenesFolder)
                modelContext.insert(newScene)
            } catch {
                errorHandler.addWarning("Failed to import scene: \(error.localizedDescription)")
            }
        }
        
        // Import characters
        let legacyCharacters = try legacyService.fetchCharacters(for: legacyProject)
        for legacyCharacter in legacyCharacters {
            do {
                let newCharacter = try mapper.mapCharacter(legacyCharacter, parentFolder: charactersFolder)
                modelContext.insert(newCharacter)
            } catch {
                errorHandler.addWarning("Failed to import character: \(error.localizedDescription)")
            }
        }
        
        // Import locations
        let legacyLocations = try legacyService.fetchLocations(for: legacyProject)
        for legacyLocation in legacyLocations {
            do {
                let newLocation = try mapper.mapLocation(legacyLocation, parentFolder: locationsFolder)
                modelContext.insert(newLocation)
            } catch {
                errorHandler.addWarning("Failed to import location: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if project is Novel or Script type
    private func isNovelOrScriptProject(_ legacyProject: NSManagedObject) -> Bool {
        if let typeString = legacyProject.value(forKey: "projectType") as? String {
            return typeString.lowercased() == "novel" || typeString.lowercased() == "script"
        }
        return false
    }
    
    /// Get current import report
    func getImportReport() -> ImportReport {
        errorHandler.generateReport(successCount: progressTracker.processedItems)
    }
}
