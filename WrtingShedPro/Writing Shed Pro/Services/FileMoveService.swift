//
//  FileMoveService.swift
//  Writing Shed Pro
//
//  Created by GitHub Copilot on 2025-11-07.
//  Feature 008a: File Movement System
//

import Foundation
import SwiftData

/// Service for managing file movement operations between folders
/// Handles move, delete to trash, and put back operations
class FileMoveService {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Move Operations
    
    /// Moves a single file to a destination folder
    /// - Parameters:
    ///   - file: The TextFile to move
    ///   - destination: The destination Folder
    /// - Throws: FileMoveError if the move is invalid
    func moveFile(_ file: TextFile, to destination: Folder) throws {
        try validateMove(file, to: destination)
        
        // Perform the move
        file.parentFolder = destination
        file.modifiedDate = Date()
        
        try modelContext.save()
    }
    
    /// Moves multiple files to a destination folder
    /// - Parameters:
    ///   - files: Array of TextFiles to move
    ///   - destination: The destination Folder
    /// - Throws: FileMoveError if any move is invalid
    func moveFiles(_ files: [TextFile], to destination: Folder) throws {
        // Validate all files first (atomic - all succeed or all fail)
        for file in files {
            try validateMove(file, to: destination)
        }
        
        // Perform all moves
        for file in files {
            file.parentFolder = destination
            file.modifiedDate = Date()
        }
        
        try modelContext.save()
    }
    
    // MARK: - Delete to Trash Operations
    
    /// Deletes a file by moving it to Trash
    /// Creates a TrashItem to track the original location for Put Back
    /// - Parameter file: The TextFile to delete
    /// - Throws: FileMoveError if the file or project is invalid
    func deleteFile(_ file: TextFile) throws {
        guard let originalFolder = file.parentFolder else {
            throw FileMoveError.invalidSourceFolder
        }
        
        guard let project = originalFolder.project else {
            throw FileMoveError.projectNotFound
        }
        
        // Create TrashItem before modifying file
        let trashItem = TrashItem(
            textFile: file,
            originalFolder: originalFolder,
            project: project
        )
        modelContext.insert(trashItem)
        
        // Remove from original folder
        file.parentFolder = nil
        file.modifiedDate = Date()
        
        try modelContext.save()
    }
    
    /// Deletes multiple files by moving them to Trash
    /// - Parameter files: Array of TextFiles to delete
    /// - Throws: FileMoveError if any file is invalid
    func deleteFiles(_ files: [TextFile]) throws {
        // Validate all files first
        for file in files {
            guard file.parentFolder != nil else {
                throw FileMoveError.invalidSourceFolder
            }
        }
        
        // Create TrashItems and delete all files
        for file in files {
            guard let originalFolder = file.parentFolder,
                  let project = originalFolder.project else {
                throw FileMoveError.projectNotFound
            }
            
            let trashItem = TrashItem(
                textFile: file,
                originalFolder: originalFolder,
                project: project
            )
            modelContext.insert(trashItem)
            
            file.parentFolder = nil
            file.modifiedDate = Date()
        }
        
        try modelContext.save()
    }
    
    // MARK: - Put Back from Trash Operations
    
    /// Restores a file from Trash to its original folder
    /// Falls back to Draft folder if original folder no longer exists
    /// - Parameter trashItem: The TrashItem to restore
    /// - Throws: FileMoveError if restoration fails
    /// - Returns: (restoredToOriginal: Bool, folder: Folder) - indicates if restored to original or Draft
    @discardableResult
    func putBack(_ trashItem: TrashItem) throws -> (restoredToOriginal: Bool, folder: Folder) {
        guard let file = trashItem.textFile else {
            throw FileMoveError.fileNotFound
        }
        
        guard let project = trashItem.project else {
            throw FileMoveError.projectNotFound
        }
        
        // Try to restore to original folder
        if let originalFolder = trashItem.originalFolder {
            // Original folder still exists - restore there
            file.parentFolder = originalFolder
            file.modifiedDate = Date()
            modelContext.delete(trashItem)
            try modelContext.save()
            return (true, originalFolder)
        } else {
            // Original folder deleted - restore to Draft as fallback
            let draftFolder = try findDraftFolder(in: project)
            
            file.parentFolder = draftFolder
            file.modifiedDate = Date()
            modelContext.delete(trashItem)
            try modelContext.save()
            return (false, draftFolder)
        }
    }
    
    /// Restores multiple files from Trash
    /// - Parameter trashItems: Array of TrashItems to restore
    /// - Throws: FileMoveError if any restoration fails
    /// - Returns: Array of (restoredToOriginal, folder) tuples for each restored file
    @discardableResult
    func putBackMultiple(_ trashItems: [TrashItem]) throws -> [(restoredToOriginal: Bool, folder: Folder)] {
        var results: [(Bool, Folder)] = []
        
        for trashItem in trashItems {
            let result = try putBack(trashItem)
            results.append(result)
        }
        
        return results
    }
    
    // MARK: - Validation
    
    /// Validates whether a file can be moved to a destination folder
    /// - Parameters:
    ///   - file: The TextFile to move
    ///   - destination: The destination Folder
    /// - Throws: FileMoveError if the move is invalid
    func validateMove(_ file: TextFile, to destination: Folder) throws {
        // Check if file exists
        guard file.parentFolder != nil else {
            throw FileMoveError.fileNotFound
        }
        
        // Check if destination is valid
        guard destination.project != nil else {
            throw FileMoveError.invalidDestinationFolder
        }
        
        // Check for cross-project move (not allowed)
        guard file.parentFolder?.project === destination.project else {
            throw FileMoveError.crossProjectMove
        }
        
        // Check if moving to same folder (no-op, but not an error)
        if file.parentFolder === destination {
            // Silent no-op - moving to same folder is harmless
            return
        }
        
        // Check if destination is Trash (can't manually move to Trash - use deleteFile instead)
        if isTrashFolder(destination) {
            throw FileMoveError.cannotMoveToTrash
        }
        
        // Check for name conflict
        if let conflictingFile = destination.textFiles?.first(where: { $0.name == file.name && $0.id != file.id }) {
            // Generate suggested name
            let suggestedName = generateUniqueName(baseName: file.name, in: destination)
            throw FileMoveError.nameConflict(suggestedName: suggestedName)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Finds the Draft folder in a project
    /// - Parameter project: The Project to search
    /// - Returns: The Draft Folder, or nil if not found
    func findDraftFolder(in project: Project) throws -> Folder {
        guard let draftFolder = project.folders?.first(where: { $0.name?.lowercased() == "draft" }) else {
            throw FileMoveError.noDraftFolder
        }
        return draftFolder
    }
    
    /// Checks if a folder is the Trash folder
    /// - Parameter folder: The Folder to check
    /// - Returns: True if folder is Trash
    func isTrashFolder(_ folder: Folder) -> Bool {
        return folder.name?.lowercased() == "trash"
    }
    
    /// Generates a unique name for a file in a folder
    /// Appends (2), (3), etc. until a unique name is found
    /// - Parameters:
    ///   - baseName: The original file name
    ///   - folder: The destination folder
    /// - Returns: A unique name
    func generateUniqueName(baseName: String, in folder: Folder) -> String {
        var counter = 2
        var newName = baseName
        
        // Extract name and extension
        let nameComponents = baseName.split(separator: ".", maxSplits: 1)
        let name = String(nameComponents.first ?? "")
        let ext = nameComponents.count > 1 ? ".\(nameComponents.last!)" : ""
        
        while folder.textFiles?.contains(where: { $0.name == newName }) == true {
            newName = "\(name) (\(counter))\(ext)"
            counter += 1
        }
        
        return newName
    }
}

// MARK: - FileMoveError

/// Errors that can occur during file movement operations
enum FileMoveError: LocalizedError, Equatable {
    case fileNotFound
    case folderNotFound
    case projectNotFound
    case invalidSourceFolder
    case invalidDestinationFolder
    case crossProjectMove
    case nameConflict(suggestedName: String)
    case cannotMoveToTrash
    case noDraftFolder
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "File not found"
        case .folderNotFound:
            return "Folder not found"
        case .projectNotFound:
            return "Project not found"
        case .invalidSourceFolder:
            return "File is not in a folder"
        case .invalidDestinationFolder:
            return "Invalid destination folder"
        case .crossProjectMove:
            return "Cannot move files between different projects"
        case .nameConflict(let suggestedName):
            return "A file with this name already exists. Suggested name: \(suggestedName)"
        case .cannotMoveToTrash:
            return "Cannot move files directly to Trash. Use the Delete action instead."
        case .noDraftFolder:
            return "Could not find Draft folder for file restoration"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .crossProjectMove:
            return "Files can only be moved within the same project."
        case .nameConflict(let suggestedName):
            return "Rename the file to '\(suggestedName)' or choose a different name."
        case .cannotMoveToTrash:
            return "Use the Delete button to move files to Trash."
        case .noDraftFolder:
            return "File will be restored to Draft folder, but Draft folder could not be found. Please create a Draft folder in your project."
        default:
            return nil
        }
    }
}
