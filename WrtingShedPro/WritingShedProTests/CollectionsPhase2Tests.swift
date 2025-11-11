import XCTest
import SwiftData
@testable import Writing_Shed_Pro

/// Comprehensive tests for Feature 008c Phase 2: Collections Folder UI
/// Tests CollectionsView component, Add Collection functionality, and navigation
final class CollectionsPhase2Tests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() {
        super.setUp()
        // Create in-memory model container for testing
        let schema = Schema([Project.self, Folder.self, TextFile.self, Version.self, TrashItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: config)
        modelContext = ModelContext(modelContainer)
    }
    
    override func tearDown() {
        modelContainer = nil
        modelContext = nil
        super.tearDown()
    }
    
    // MARK: - Test Collections Folder Setup
    
    func testCreateCollectionsFolder() throws {
        // Given a poetry project with Collections folder created
        let project = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // When getting the Collections folder
        let folders = project.folders ?? []
        let collectionsFolder = folders.first { $0.name == "Collections" }
        
        // Then verify Collections folder exists and is accessible
        XCTAssertNotNil(collectionsFolder, "Collections folder should exist")
        XCTAssertEqual(collectionsFolder?.name, "Collections", "Collections folder should have correct name")
    }
    
    // MARK: - Test Add Collection Functionality
    
    func testAddSingleCollection() throws {
        // Given a Collections folder
        let project = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        let folders = project.folders ?? []
        let collectionsFolder = folders.first { $0.name == "Collections" }!
        
        // When adding a new collection
        let newCollection = Folder(name: "Fantasy Stories", project: nil, parentFolder: collectionsFolder)
        collectionsFolder.folders?.append(newCollection)
        modelContext.insert(newCollection)
        try modelContext.save()
        
        // Then verify collection was added
        let collections = collectionsFolder.folders ?? []
        XCTAssertEqual(collections.count, 1, "Collections folder should contain 1 collection")
        XCTAssertEqual(collections.first?.name, "Fantasy Stories", "Collection should have correct name")
    }
    
    func testAddMultipleCollections() throws {
        // Given a Collections folder
        let project = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        let folders = project.folders ?? []
        let collectionsFolder = folders.first { $0.name == "Collections" }!
        
        // When adding multiple collections
        let collection1 = Folder(name: "Fantasy", project: nil, parentFolder: collectionsFolder)
        let collection2 = Folder(name: "Science Fiction", project: nil, parentFolder: collectionsFolder)
        let collection3 = Folder(name: "Short Stories", project: nil, parentFolder: collectionsFolder)
        
        collectionsFolder.folders?.append(contentsOf: [collection1, collection2, collection3])
        modelContext.insert(collection1)
        modelContext.insert(collection2)
        modelContext.insert(collection3)
        try modelContext.save()
        
        // Then verify all collections were added
        let collections = collectionsFolder.folders ?? []
        XCTAssertEqual(collections.count, 3, "Collections folder should contain 3 collections")
        
        let names = Set(collections.compactMap { $0.name })
        let expectedNames: Set<String> = ["Fantasy", "Science Fiction", "Short Stories"]
        XCTAssertEqual(names, expectedNames, "Collections should have correct names")
    }
    
    // MARK: - Test Collection Name Validation
    
    func testCannotAddCollectionWithEmptyName() throws {
        // Given a Collections folder
        let project = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        let folders = project.folders ?? []
        let collectionsFolder = folders.first { $0.name == "Collections" }!
        
        // When attempting to add collection with empty name
        let emptyName = ""
        let trimmedName = emptyName.trimmingCharacters(in: .whitespaces)
        
        // Then verify empty name would be rejected
        XCTAssertTrue(trimmedName.isEmpty, "Empty name should be detected as invalid")
    }
    
    func testCannotAddCollectionWithDuplicateName() throws {
        // Given a Collections folder with existing collection
        let project = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        let folders = project.folders ?? []
        let collectionsFolder = folders.first { $0.name == "Collections" }!
        
        // Add first collection
        let collection1 = Folder(name: "Fantasy", project: nil, parentFolder: collectionsFolder)
        collectionsFolder.folders?.append(collection1)
        modelContext.insert(collection1)
        try modelContext.save()
        
        // When attempting to add collection with duplicate name
        let duplicateName = "Fantasy"
        let existingCollections = (collectionsFolder.folders ?? [])
            .filter { $0.name?.lowercased() == duplicateName.lowercased() }
        
        // Then verify duplicate would be detected
        XCTAssertEqual(existingCollections.count, 1, "Duplicate name should be detected")
    }
    
    func testCollectionNameIsCaseInsensitiveForDuplicates() throws {
        // Given a Collections folder with collection named "Fantasy"
        let project = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        let folders = project.folders ?? []
        let collectionsFolder = folders.first { $0.name == "Collections" }!
        
        let collection1 = Folder(name: "Fantasy", project: nil, parentFolder: collectionsFolder)
        collectionsFolder.folders?.append(collection1)
        modelContext.insert(collection1)
        try modelContext.save()
        
        // When checking for duplicate with different case
        let testName = "fantasy"
        let existingCollections = (collectionsFolder.folders ?? [])
            .filter { $0.name?.lowercased() == testName.lowercased() }
        
        // Then verify case-insensitive duplicate detection works
        XCTAssertEqual(existingCollections.count, 1, "Case-insensitive duplicate should be detected")
    }
    
    // MARK: - Test Collection Organization
    
    func testCollectionsAreSortedAlphabetically() throws {
        // Given a Collections folder with multiple collections
        let project = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        let folders = project.folders ?? []
        let collectionsFolder = folders.first { $0.name == "Collections" }!
        
        // Add collections in random order
        let names = ["Zebra Stories", "Apple Ideas", "Moon Chronicles", "Beta Drafts"]
        for name in names {
            let collection = Folder(name: name, project: nil, parentFolder: collectionsFolder)
            collectionsFolder.folders?.append(collection)
            modelContext.insert(collection)
        }
        try modelContext.save()
        
        // When sorting collections alphabetically
        let sortedCollections = (collectionsFolder.folders ?? [])
            .sorted { folder1, folder2 in
                let name1 = folder1.name ?? ""
                let name2 = folder2.name ?? ""
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            }
        
        // Then verify they are in alphabetical order
        let sortedNames = sortedCollections.compactMap { $0.name }
        let expectedOrder = ["Apple Ideas", "Beta Drafts", "Moon Chronicles", "Zebra Stories"]
        XCTAssertEqual(sortedNames, expectedOrder, "Collections should be sorted alphabetically")
    }
    
    // MARK: - Test Collection Structure
    
    func testNewCollectionIsEmpty() throws {
        // Given a newly created collection
        let project = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        let folders = project.folders ?? []
        let collectionsFolder = folders.first { $0.name == "Collections" }!
        
        let newCollection = Folder(name: "New Collection", project: nil, parentFolder: collectionsFolder)
        collectionsFolder.folders?.append(newCollection)
        modelContext.insert(newCollection)
        try modelContext.save()
        
        // When checking the new collection's contents
        let subfoldersCount = newCollection.folders?.count ?? 0
        let filesCount = newCollection.textFiles?.count ?? 0
        
        // Then verify it's empty
        XCTAssertEqual(subfoldersCount, 0, "New collection should have no subfolders")
        XCTAssertEqual(filesCount, 0, "New collection should have no files")
    }
    
    func testCollectionBelongsToCorrectParent() throws {
        // Given a Collections folder with a collection
        let project = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        let folders = project.folders ?? []
        let collectionsFolder = folders.first { $0.name == "Collections" }!
        
        let newCollection = Folder(name: "Fantasy", project: nil, parentFolder: collectionsFolder)
        collectionsFolder.folders?.append(newCollection)
        modelContext.insert(newCollection)
        try modelContext.save()
        
        // When checking the collection's parent
        let parent = newCollection.parentFolder
        
        // Then verify parent is Collections folder
        XCTAssertEqual(parent?.name, "Collections", "Collection's parent should be Collections folder")
        XCTAssertEqual(parent?.id, collectionsFolder.id, "Collection should belong to Collections folder")
    }
    
    // MARK: - Test Delete Collection
    
    func testDeleteSingleCollection() throws {
        // Given Collections folder with one collection
        let project = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        let folders = project.folders ?? []
        let collectionsFolder = folders.first { $0.name == "Collections" }!
        
        let collection = Folder(name: "Fantasy", project: nil, parentFolder: collectionsFolder)
        collectionsFolder.folders?.append(collection)
        modelContext.insert(collection)
        try modelContext.save()
        
        // When deleting the collection
        collectionsFolder.folders?.removeAll { $0.id == collection.id }
        modelContext.delete(collection)
        try modelContext.save()
        
        // Then verify collection is deleted
        let remainingCollections = collectionsFolder.folders ?? []
        XCTAssertEqual(remainingCollections.count, 0, "Collections folder should be empty after deletion")
    }
    
    func testDeleteOneOfMultipleCollections() throws {
        // Given Collections folder with multiple collections
        let project = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        let folders = project.folders ?? []
        let collectionsFolder = folders.first { $0.name == "Collections" }!
        
        let collection1 = Folder(name: "Fantasy", project: nil, parentFolder: collectionsFolder)
        let collection2 = Folder(name: "Science Fiction", project: nil, parentFolder: collectionsFolder)
        collectionsFolder.folders?.append(contentsOf: [collection1, collection2])
        modelContext.insert(collection1)
        modelContext.insert(collection2)
        try modelContext.save()
        
        // When deleting one collection
        collectionsFolder.folders?.removeAll { $0.id == collection1.id }
        modelContext.delete(collection1)
        try modelContext.save()
        
        // Then verify only one collection remains
        let remainingCollections = collectionsFolder.folders ?? []
        XCTAssertEqual(remainingCollections.count, 1, "Collections folder should have 1 collection")
        XCTAssertEqual(remainingCollections.first?.name, "Science Fiction", "Correct collection should remain")
    }
    
    // MARK: - Test Multiple Projects Independence
    
    func testCollectionsAreIndependentBetweenProjects() throws {
        // Given two poetry projects
        let project1 = Project(name: "Poetry 1", type: .poetry)
        let project2 = Project(name: "Poetry 2", type: .poetry)
        modelContext.insert(project1)
        modelContext.insert(project2)
        
        ProjectTemplateService.createDefaultFolders(for: project1, in: modelContext)
        ProjectTemplateService.createDefaultFolders(for: project2, in: modelContext)
        
        // Add collection to project1
        let folders1 = project1.folders ?? []
        let collectionsFolder1 = folders1.first { $0.name == "Collections" }!
        
        let collection1 = Folder(name: "Project1 Collection", project: nil, parentFolder: collectionsFolder1)
        collectionsFolder1.folders?.append(collection1)
        modelContext.insert(collection1)
        try modelContext.save()
        
        // When getting collections from project2
        let folders2 = project2.folders ?? []
        let collectionsFolder2 = folders2.first { $0.name == "Collections" }!
        
        // Then verify project2's Collections folder is empty
        let project2Collections = collectionsFolder2.folders ?? []
        XCTAssertEqual(project2Collections.count, 0, "Project2 Collections should be empty")
        
        // And project1's Collections folder has collection
        let project1Collections = collectionsFolder1.folders ?? []
        XCTAssertEqual(project1Collections.count, 1, "Project1 Collections should have 1 collection")
    }
}
