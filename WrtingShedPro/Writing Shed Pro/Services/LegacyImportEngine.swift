//
//  LegacyImportEngine.swift
//  Writing Shed Pro
//
//  Created on 12 November 2025.
//  Feature 009: Database Import
//

import Foundation
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
        
        try progressTracker.setPhase("Connecting to legacy database...")
        try legacyService.connect()
        
        try progressTracker.setPhase("Loading projects...")
        let legacyProjects = try legacyService.fetchProjects()
        progressTracker.setTotal(legacyProjects.count)
        
        guard !legacyProjects.isEmpty else {
            progressTracker.setPhase("No projects found in legacy database")
            progressTracker.markComplete()
            return
        }
        
        // Import each project
        for legacyProject in legacyProjects {
            do {
                try importProject(legacyProject, modelContext: modelContext)
                progressTracker.incrementProcessed()
            } catch {
                errorHandler.addError("Failed to import project: \(error.localizedDescription)")
            }
        }
        
        // Save all changes
        try progressTracker.setPhase("Saving to database...")
        do {
            try modelContext.save()
            progressTracker.markComplete()
        } catch {
            errorHandler.addError("Failed to save imported data: \(error.localizedDescription)")
            try errorHandler.rollback(on: modelContext)
            throw error
        }
    }
    
    // MARK: - Project Import
    
    /// Import a single project and all its data
    private func importProject(
        _ legacyProject: NSManagedObject,
        modelContext: ModelContext
    ) throws {
        let projectName = legacyProject.value(forKey: "name") as? String ?? "Untitled Project"
        progressTracker.setCurrentItem(projectName)
        
        // Map project
        let newProject = try mapper.mapProject(legacyProject)
        modelContext.insert(newProject)
        
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
        try importCollections(
            legacyProject: legacyProject,
            newProject: newProject,
            modelContext: modelContext
        )
        
        // Import scenes (if project type supports it)
        if isNovelOrScriptProject(legacyProject) {
            try importSceneComponents(
                legacyProject: legacyProject,
                newProject: newProject,
                modelContext: modelContext
            )
        }
    }
    
    // MARK: - Folder Structure Creation
    
    /// Create folder structure from legacy groupName values
    private func importFolderStructure(
        legacyProject: NSManagedObject,
        newProject: Project,
        modelContext: ModelContext
    ) throws {
        // Get unique groupName values
        let legacyTexts = try legacyService.fetchTexts(for: legacyProject)
        var groupNames = Set<String>()
        
        for legacyText in legacyTexts {
            if let groupName = legacyText.value(forKey: "groupName") as? String, !groupName.isEmpty {
                groupNames.insert(groupName)
            }
        }
        
        // Create folders
        for groupName in groupNames {
            let folder = Folder(name: groupName, project: newProject)
            newProject.folders?.append(folder)
            modelContext.insert(folder)
        }
        
        // Create "Imported" folder for items without groupName
        let importedFolder = Folder(name: "Imported", project: newProject)
        newProject.folders?.append(importedFolder)
        modelContext.insert(importedFolder)
    }
    
    // MARK: - Text and Version Import
    
    /// Import texts and versions for a project
    private func importTextsAndVersions(
        legacyProject: NSManagedObject,
        newProject: Project,
        modelContext: ModelContext
    ) throws {
        let legacyTexts = try legacyService.fetchTexts(for: legacyProject)
        
        for legacyText in legacyTexts {
            do {
                // Get or create parent folder
                let groupName = legacyText.value(forKey: "groupName") as? String ?? ""
                let parentFolder: Folder
                
                if !groupName.isEmpty,
                   let folder = newProject.folders?.first(where: { $0.name == groupName }) {
                    parentFolder = folder
                } else {
                    // Use "Imported" folder
                    if let folder = newProject.folders?.first(where: { $0.name == "Imported" }) {
                        parentFolder = folder
                    } else {
                        let folder = Folder(name: "Imported", project: newProject)
                        newProject.folders?.append(folder)
                        parentFolder = folder
                    }
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
                
                // Import collected versions as SubmittedFiles
                let legacyCollectedVersions = try legacyService.fetchCollectedVersions(for: legacyCollection)
                for legacyCollectedVersion in legacyCollectedVersions {
                    if let newSubmittedFile = try mapper.mapCollectedVersion(
                        legacyCollectedVersion,
                        collection: newSubmission,
                        textFileMap: textFileMap,
                        versionMap: versionMap
                    ) {
                        modelContext.insert(newSubmittedFile)
                        if newSubmission.submittedFiles == nil {
                            newSubmission.submittedFiles = []
                        }
                        newSubmission.submittedFiles?.append(newSubmittedFile)
                    }
                }
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
