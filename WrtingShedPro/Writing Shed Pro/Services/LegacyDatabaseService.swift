//
//  LegacyDatabaseService.swift
//  Writing Shed Pro
//
//  Created on 12 November 2025.
//  Feature 009: Database Import
//

import Foundation
import CoreData

/// Service for reading legacy Writing Shed Core Data database
/// Provides access to all entity types needed for import
class LegacyDatabaseService {
    
    // MARK: - Properties
    
    private var persistentContainer: NSPersistentContainer?
    private var managedObjectContext: NSManagedObjectContext?
    private let legacyDatabaseURL: URL
    
    // MARK: - Initialization
    
    init(databaseURL: URL? = nil) {
        // Use provided URL or compute default location
        if let url = databaseURL {
            self.legacyDatabaseURL = url
        } else {
            // The legacy Writing Shed app:
            // - macOS bundle ID: com.writing-shed.osx-writing-shed
            // - iOS bundle ID: www.writing-shed.comuk.Writing-Shed
            // - Filename: Writing-Shed.sqlite
            
            let possibleFilenames = ["Writing-Shed.sqlite"]
            let legacyBundleIDs = [
                "com.writing-shed.osx-writing-shed",  // Official macOS Writing Shed
                "com.appworks.WriteBang"               // Developer's test build
            ]
            let fileManager = FileManager.default
            
            #if targetEnvironment(macCatalyst) || os(macOS)
            // For Mac: Check both sandboxed and non-sandboxed locations
            // (App Store apps run in sandbox with Library/Containers/{bundleID}/Data/ prefix)
            let userName = NSUserName()
            var foundURL: URL? = nil
            
            // Try all combinations: sandboxed first, then non-sandboxed
            for bundleID in legacyBundleIDs {
                for filename in possibleFilenames {
                    // Check sandboxed location first (App Store apps)
                    let sandboxedPath = "/Users/\(userName)/Library/Containers/\(bundleID)/Data/Library/Application Support/\(bundleID)/\(filename)"
                    if fileManager.fileExists(atPath: sandboxedPath) {
                        print("[LegacyDatabaseService] Found database at (sandboxed): \(sandboxedPath)")
                        foundURL = URL(fileURLWithPath: sandboxedPath)
                        break
                    }
                    
                    // Check non-sandboxed location
                    let normalPath = "/Users/\(userName)/Library/Application Support/\(bundleID)/\(filename)"
                    if fileManager.fileExists(atPath: normalPath) {
                        print("[LegacyDatabaseService] Found database at: \(normalPath)")
                        foundURL = URL(fileURLWithPath: normalPath)
                        break
                    }
                }
                if foundURL != nil { break }
            }
            
            if let url = foundURL {
                self.legacyDatabaseURL = url
            } else {
                // Fallback to sandboxed path (will fail during connect() with clear error)
                let fallbackPath = "/Users/\(userName)/Library/Containers/\(legacyBundleIDs[0])/Data/Library/Application Support/\(legacyBundleIDs[0])/\(possibleFilenames[0])"
                print("[LegacyDatabaseService] Using fallback path: \(fallbackPath)")
                self.legacyDatabaseURL = URL(fileURLWithPath: fallbackPath)
            }
            
            #else
            // iOS: Use application support directory
            let supportURL = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            
            let iosBundleID = "www.writing-shed.comuk.Writing-Shed"
            var foundURL: URL? = nil
            
            for filename in possibleFilenames {
                let url = supportURL
                    .appendingPathComponent(iosBundleID, isDirectory: true)
                    .appendingPathComponent(filename, isDirectory: false)
                
                if fileManager.fileExists(atPath: url.path) {
                    print("[LegacyDatabaseService] Found database at: \(url.path)")
                    foundURL = url
                    break
                }
            }
            
            if let url = foundURL {
                self.legacyDatabaseURL = url
            } else {
                // Use first filename as fallback
                self.legacyDatabaseURL = supportURL
                    .appendingPathComponent(iosBundleID, isDirectory: true)
                    .appendingPathComponent(possibleFilenames[0], isDirectory: false)
            }
            #endif
        }
    }
    
    // MARK: - Connection Management
    
    /// Connect to legacy Core Data database
    /// - Throws: ImportError if connection fails
    func connect() throws {
        // Verify database file exists
        guard FileManager.default.fileExists(atPath: legacyDatabaseURL.path) else {
            throw ImportError.databaseNotFound(legacyDatabaseURL.path)
        }
        
        // Load the Core Data model
        guard let modelURL = Bundle.main.url(forResource: "Writing_Shed", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            throw ImportError.modelNotFound
        }
        
        // Create persistent store coordinator
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        
        do {
            // Add persistent store with migration support
            // Note: We don't use NSReadOnlyPersistentStoreOption because Core Data needs write access
            // to perform schema migration. The import process itself is read-only, but the store
            // connection requires write permission for migration.
            let options = [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true
            ] as [String: Any]
            
            try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: legacyDatabaseURL,
                options: options
            )
            
            // Create managed object context
            let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            context.persistentStoreCoordinator = coordinator
            context.mergePolicy = NSErrorMergePolicy
            
            self.managedObjectContext = context
        } catch {
            throw ImportError.connectionFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Entity Fetching
    
    /// Fetch all projects from legacy database
    /// - Throws: ImportError if fetch fails
    /// - Returns: Array of WS_Project_Entity managed objects
    func fetchProjects() throws -> [NSManagedObject] {
        guard let context = managedObjectContext else {
            throw ImportError.notConnected
        }
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "WS_Project_Entity")
        fetchRequest.returnsObjectsAsFaults = false
        
        do {
            let projects = try context.fetch(fetchRequest)
            return projects
        } catch {
            throw ImportError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Fetch all texts (files) for a given project
    /// - Parameters:
    ///   - project: The WS_Project_Entity to fetch texts for
    /// - Throws: ImportError if fetch fails
    /// - Returns: Array of WS_Text_Entity managed objects
    func fetchTexts(for project: NSManagedObject) throws -> [NSManagedObject] {
        guard let context = managedObjectContext else {
            throw ImportError.notConnected
        }
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "WS_Text_Entity")
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.predicate = NSPredicate(format: "project == %@", project)
        
        do {
            let texts = try context.fetch(fetchRequest)
            return texts
        } catch {
            throw ImportError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Fetch all versions for a given text
    /// - Parameters:
    ///   - text: The WS_Text_Entity to fetch versions for
    /// - Throws: ImportError if fetch fails
    /// - Returns: Array of WS_Version_Entity managed objects, sorted by date
    func fetchVersions(for text: NSManagedObject) throws -> [NSManagedObject] {
        guard let context = managedObjectContext else {
            throw ImportError.notConnected
        }
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "WS_Version_Entity")
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.predicate = NSPredicate(format: "text == %@", text)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        do {
            let versions = try context.fetch(fetchRequest)
            return versions
        } catch {
            throw ImportError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Fetch TextString (content) for a given version
    /// - Parameters:
    ///   - version: The WS_Version_Entity to fetch content for
    /// - Throws: ImportError if fetch fails
    /// - Returns: NSAttributedString or nil if not found
    func fetchTextString(for version: NSManagedObject) throws -> NSAttributedString? {
        guard let context = managedObjectContext else {
            throw ImportError.notConnected
        }
        
        // Get the related textString entity
        guard let textStringEntity = version.value(forKey: "textString") as? NSManagedObject else {
            return nil
        }
        
        // Extract NSAttributedString from transformable attribute
        guard let attributedString = textStringEntity.value(forKey: "textFile") as? NSAttributedString else {
            return nil
        }
        
        return attributedString
    }
    
    /// Fetch all collections for a given project
    /// - Parameters:
    ///   - project: The WS_Project_Entity to fetch collections for
    /// - Throws: ImportError if fetch fails
    /// - Returns: Array of WS_Collection_Entity managed objects
    func fetchCollections(for project: NSManagedObject) throws -> [NSManagedObject] {
        guard let context = managedObjectContext else {
            throw ImportError.notConnected
        }
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "WS_Collection_Entity")
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.predicate = NSPredicate(format: "project == %@", project)
        
        do {
            let collections = try context.fetch(fetchRequest)
            return collections
        } catch {
            throw ImportError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Fetch collection components (for collection metadata)
    /// - Parameters:
    ///   - collection: The WS_Collection_Entity to fetch components for
    /// - Throws: ImportError if fetch fails
    /// - Returns: Array of WS_CollectionComponent_Entity managed objects
    func fetchCollectionComponents(for collection: NSManagedObject) throws -> [NSManagedObject] {
        guard let context = managedObjectContext else {
            throw ImportError.notConnected
        }
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "WS_CollectionComponent_Entity")
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.predicate = NSPredicate(format: "collection == %@", collection)
        
        do {
            let components = try context.fetch(fetchRequest)
            return components
        } catch {
            throw ImportError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Fetch all collected versions for a given collection
    /// - Parameters:
    ///   - collection: The WS_Collection_Entity to fetch collected versions for
    /// - Throws: ImportError if fetch fails
    /// - Returns: Array of WS_CollectedVersion_Entity managed objects
    func fetchCollectedVersions(for collection: NSManagedObject) throws -> [NSManagedObject] {
        guard let context = managedObjectContext else {
            throw ImportError.notConnected
        }
        
        // Collections have collected versions through WS_TextCollection_Entity
        // First fetch the text collection for this collection
        let textCollectionRequest = NSFetchRequest<NSManagedObject>(entityName: "WS_TextCollection_Entity")
        textCollectionRequest.returnsObjectsAsFaults = false
        textCollectionRequest.predicate = NSPredicate(format: "collection == %@", collection)
        
        do {
            let textCollections = try context.fetch(textCollectionRequest)
            
            // Now fetch collected versions from the text collection
            var allCollectedVersions: [NSManagedObject] = []
            for textCollection in textCollections {
                if let collectedVersions = textCollection.value(forKey: "collectedVersions") as? NSSet {
                    allCollectedVersions.append(contentsOf: collectedVersions.allObjects as? [NSManagedObject] ?? [])
                }
            }
            
            return allCollectedVersions
        } catch {
            throw ImportError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Fetch all collection submissions for a given collection
    /// - Parameters:
    ///   - collection: The WS_Collection_Entity to fetch submissions for
    /// - Throws: ImportError if fetch fails
    /// - Returns: Array of WS_CollectionSubmission_Entity managed objects
    func fetchCollectionSubmissions(for collection: NSManagedObject) throws -> [NSManagedObject] {
        guard let context = managedObjectContext else {
            throw ImportError.notConnected
        }
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "WS_CollectionSubmission_Entity")
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.predicate = NSPredicate(format: "collection == %@", collection)
        
        do {
            let submissions = try context.fetch(fetchRequest)
            return submissions
        } catch {
            throw ImportError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Fetch all scenes for a given project
    /// - Parameters:
    ///   - project: The WS_Project_Entity to fetch scenes for
    /// - Throws: ImportError if fetch fails
    /// - Returns: Array of WS_Scene_Entity managed objects
    func fetchScenes(for project: NSManagedObject) throws -> [NSManagedObject] {
        guard let context = managedObjectContext else {
            throw ImportError.notConnected
        }
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "WS_Scene_Entity")
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.predicate = NSPredicate(format: "project == %@", project)
        
        do {
            let scenes = try context.fetch(fetchRequest)
            return scenes
        } catch {
            throw ImportError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Fetch all characters for a given project
    /// - Parameters:
    ///   - project: The WS_Project_Entity to fetch characters for
    /// - Throws: ImportError if fetch fails
    /// - Returns: Array of WS_Character_Entity managed objects
    func fetchCharacters(for project: NSManagedObject) throws -> [NSManagedObject] {
        guard let context = managedObjectContext else {
            throw ImportError.notConnected
        }
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "WS_Character_Entity")
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.predicate = NSPredicate(format: "project == %@", project)
        
        do {
            let characters = try context.fetch(fetchRequest)
            return characters
        } catch {
            throw ImportError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Fetch all locations for a given project
    /// - Parameters:
    ///   - project: The WS_Project_Entity to fetch locations for
    /// - Throws: ImportError if fetch fails
    /// - Returns: Array of WS_Location_Entity managed objects
    func fetchLocations(for project: NSManagedObject) throws -> [NSManagedObject] {
        guard let context = managedObjectContext else {
            throw ImportError.notConnected
        }
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "WS_Location_Entity")
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.predicate = NSPredicate(format: "project == %@", project)
        
        do {
            let locations = try context.fetch(fetchRequest)
            return locations
        } catch {
            throw ImportError.fetchFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Utility Methods
    
    /// Check if legacy database file exists at the expected location
    func databaseExists() -> Bool {
        FileManager.default.fileExists(atPath: legacyDatabaseURL.path)
    }
    
    /// Get the path to the legacy database
    var databasePath: String {
        legacyDatabaseURL.path
    }
}

// MARK: - Import Errors

enum ImportError: Error, LocalizedError {
    case databaseNotFound(String)
    case modelNotFound
    case notConnected
    case connectionFailed(String)
    case fetchFailed(String)
    case missingContent
    case invalidUUID
    case corruptedData
    case invalidProjectType
    case mappingFailed(String)
    case rollbackFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .databaseNotFound(let path):
            return "Legacy database not found at: \(path)"
        case .modelNotFound:
            return "Core Data model file not found"
        case .notConnected:
            return "Not connected to legacy database"
        case .connectionFailed(let reason):
            return "Failed to connect to legacy database: \(reason)"
        case .fetchFailed(let reason):
            return "Failed to fetch data: \(reason)"
        case .missingContent:
            return "Content data is missing"
        case .invalidUUID:
            return "Invalid UUID format"
        case .corruptedData:
            return "Data appears corrupted"
        case .invalidProjectType:
            return "Unknown project type"
        case .mappingFailed(let reason):
            return "Mapping failed: \(reason)"
        case .rollbackFailed(let reason):
            return "Rollback failed: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .databaseNotFound:
            return "Ensure the legacy Writing Shed is installed on this machine"
        case .notConnected:
            return "Call connect() before accessing the database"
        case .connectionFailed:
            return "Try again later or contact support"
        default:
            return "Please try the import again"
        }
    }
}
